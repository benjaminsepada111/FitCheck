const express = require('express');
const multer = require('multer');
const ffmpeg = require('fluent-ffmpeg');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

const PORT = process.env.PORT || 5000;
const UPLOAD_DIR = path.join(__dirname, 'uploads');
const VIDEO_DIR = path.join(__dirname, 'videos');
const TEMP_DIR = path.join(__dirname, 'temp');

// Create directories if they don't exist
[UPLOAD_DIR, VIDEO_DIR, TEMP_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '';
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB per file
});

const PUBLIC_BASE_OVERRIDE = process.env.BASE_URL || null;

// In-memory render status storage
const renderJobs = new Map();

app.use('/uploads', express.static(UPLOAD_DIR));
app.use('/videos', express.static(VIDEO_DIR));

app.get('/', (req, res) => res.send('Milestone Video API with FFmpeg is running'));

/**
 * POST /api/generate-video
 * Creates video using FFmpeg instead of Shotstack
 */
app.post(
  '/api/generate-video',
  upload.fields([
    { name: 'images', maxCount: 50 },
    { name: 'music', maxCount: 1 }
  ]),
  async (req, res) => {
    try {
      console.log('📥 Received generate-video request');

      const durationPerImage = parseInt(req.body.duration ?? '2', 10) || 2;
      let musicPath = null;

      const baseUrl = PUBLIC_BASE_OVERRIDE || `${req.protocol}://${req.get('host')}`;

      // Handle uploaded images
      const imageFiles = req.files?.['images'] || [];
      if (!imageFiles.length) {
        console.error('❌ No images provided');
        return res.status(400).json({ success: false, error: 'No images provided' });
      }

      console.log(`🖼️ Total images: ${imageFiles.length}`);

      // Handle music upload or URL
      const musicFiles = req.files?.['music'] || [];
      if (musicFiles.length > 0) {
        musicPath = musicFiles[0].path;
      } else if (req.body.musicUrl) {
        const axios = require('axios');
        const musicUrl = req.body.musicUrl;
        console.log(`🎵 Downloading music from: ${musicUrl}`);
        try {
          const musicResponse = await axios.get(musicUrl, { responseType: 'arraybuffer' });
          const musicExt = path.extname(new URL(musicUrl).pathname) || '.mp3';
          musicPath = path.join(TEMP_DIR, `music-${Date.now()}${musicExt}`);
          fs.writeFileSync(musicPath, Buffer.from(musicResponse.data));
          console.log(`✅ Music downloaded to: ${musicPath}`);
        } catch (err) {
          console.error('⚠️ Failed to download music:', err.message);
        }
      }

      // Reverse order (last milestone first)
      const reversedImages = [...imageFiles].reverse();

      // Generate unique render ID
      const renderId = uuidv4();
      const outputFileName = `video-${renderId}.mp4`;
      const outputPath = path.join(VIDEO_DIR, outputFileName);
      const outputUrl = `${baseUrl}/videos/${outputFileName}`;

      // Initialize render job status
      renderJobs.set(renderId, {
        status: 'queued',
        progress: 0,
        url: null,
        error: null,
        createdAt: new Date()
      });

      console.log(`🎬 Starting FFmpeg render: ${renderId}`);

      // Return render ID immediately (non-blocking)
      res.json({
        success: true,
        data: {
          response: { id: renderId, message: 'Video render queued' }
        }
      });

      // Process video asynchronously
      processVideoWithFFmpeg(
        reversedImages,
        durationPerImage,
        musicPath,
        outputPath,
        outputUrl,
        renderId
      );

    } catch (err) {
      console.error('❌ Generate-video error:', err.message);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * Process video with FFmpeg
 */
async function processVideoWithFFmpeg(imageFiles, durationPerImage, musicPath, outputPath, outputUrl, renderId) {
  try {
    renderJobs.set(renderId, {
      ...renderJobs.get(renderId),
      status: 'rendering',
      progress: 10
    });

    console.log(`🎥 Creating video from ${imageFiles.length} images...`);

    const filterComplex = buildFilterComplex(imageFiles.length, durationPerImage);
    const totalDuration = imageFiles.length * durationPerImage;

    const command = ffmpeg();
    imageFiles.forEach((file) => command.input(file.path));

    let hasAudio = false;
    if (musicPath && fs.existsSync(musicPath)) {
      command.input(musicPath);
      hasAudio = true;
    }

    // 🧠 FIXED: removed -vf (scale/pad already handled in filterComplex)
    command
      .complexFilter(filterComplex)
      .outputOptions([
        '-map', '[outv]',
        ...(hasAudio ? [
          '-map', `${imageFiles.length}:a`,
          '-shortest',
          '-c:a', 'aac',
          '-b:a', '128k',
          `-af`, `afade=t=in:st=0:d=1,afade=t=out:st=${Math.max(totalDuration - 1, 1)}:d=1,volume=0.5`
        ] : ['-an']),
        '-c:v', 'libx264',
        '-preset', 'medium',
        '-crf', '23',
        '-pix_fmt', 'yuv420p',
        '-r', '30',
        '-movflags', '+faststart'
      ])
      .output(outputPath)
      .on('start', cmd => console.log('🎬 FFmpeg command:', cmd))
      .on('progress', progress => {
        const percent = Math.min(Math.round(progress.percent || 0), 95);
        console.log(`⏳ Processing: ${percent}%`);
        renderJobs.set(renderId, { ...renderJobs.get(renderId), progress: percent });
      })
      .on('end', () => {
        console.log(`✅ Video created successfully: ${outputPath}`);
        renderJobs.set(renderId, {
          status: 'done',
          progress: 100,
          url: outputUrl,
          error: null,
          createdAt: renderJobs.get(renderId).createdAt
        });

        // Auto cleanup after 5 minutes
        setTimeout(() => {
          imageFiles.forEach(file => {
            try { if (fs.existsSync(file.path)) fs.unlinkSync(file.path); } catch {}
          });
          if (musicPath && musicPath.includes(TEMP_DIR)) {
            try { if (fs.existsSync(musicPath)) fs.unlinkSync(musicPath); } catch {}
          }
        }, 5 * 60 * 1000);
      })
      .on('error', err => {
        console.error('❌ FFmpeg error:', err.message);
        renderJobs.set(renderId, {
          status: 'failed',
          progress: 0,
          url: null,
          error: err.message,
          createdAt: renderJobs.get(renderId).createdAt
        });
      })
      .run();

  } catch (err) {
    console.error('❌ Video processing error:', err.message);
    renderJobs.set(renderId, {
      status: 'failed',
      progress: 0,
      url: null,
      error: err.message,
      createdAt: renderJobs.get(renderId).createdAt
    });
  }
}

/**
 * Build FFmpeg filter complex for crossfade transitions
 * KEY FIX: Images must be looped before trimming to create video duration
 */
function buildFilterComplex(imageCount, durationPerImage) {
  if (imageCount === 1) {
    // Single image: loop it for the full duration
    return [
      `[0:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,loop=loop=-1:size=1:start=0,trim=duration=${durationPerImage},setpts=PTS-STARTPTS,format=yuv420p[outv]`
    ];
  }

  const filters = [];
  const fadeDuration = 0.5; // seconds

  // First, prepare each image with proper looping and duration
  for (let i = 0; i < imageCount; i++) {
    // loop=-1 means infinite loop, size=1 means loop 1 frame at a time
    // trim cuts the looped video to the desired duration
    // setpts resets timestamps to start from 0
    filters.push(
      `[${i}:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,loop=loop=-1:size=1:start=0,trim=duration=${durationPerImage},setpts=PTS-STARTPTS,format=yuv420p[v${i}]`
    );
  }

  // Then apply crossfade transitions between consecutive clips
  let current = 'v0';
  for (let i = 1; i < imageCount; i++) {
    const offset = (durationPerImage * i) - fadeDuration;
    const next = i === imageCount - 1 ? 'outv' : `v${i}tmp`;
    filters.push(`[${current}][v${i}]xfade=transition=fade:duration=${fadeDuration}:offset=${offset}[${next}]`);
    current = next;
  }

  return filters;
}

/**
 * GET /api/render-status/:id
 */
app.get('/api/render-status/:id', async (req, res) => {
  const id = req.params.id;
  const job = renderJobs.get(id);

  if (!job) {
    return res.status(404).json({ success: false, error: 'Render ID not found' });
  }

  console.log(`🔍 Checking status for ${id}: ${job.status} (${job.progress}%)`);
  return res.json({
    success: true,
    data: { response: job }
  });
});

/**
 * GET /api/health
 */
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    ffmpeg_available: true,
    active_renders: renderJobs.size,
    timestamp: new Date().toISOString()
  });
});

// Clean up old render jobs hourly
setInterval(() => {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  for (const [id, job] of renderJobs.entries()) {
    if (job.createdAt < oneHourAgo) {
      console.log(`🧹 Cleaning up old render job: ${id}`);
      renderJobs.delete(id);
    }
  }
}, 60 * 60 * 1000);

app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 Milestone Video API with FFmpeg started');
  console.log(`📍 Port: ${PORT}`);
  console.log(`🎥 FFmpeg: Enabled ✅`);
});
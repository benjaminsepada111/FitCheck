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

      // 🆕 Parse text logs from request body
      let textLogs = [];
      if (req.body.textLogs) {
        try {
          textLogs = JSON.parse(req.body.textLogs);
          console.log(`📝 Received ${textLogs.length} text logs`);
        } catch (e) {
          console.warn('⚠️ Failed to parse textLogs:', e.message);
          textLogs = [];
        }
      }

      // Ensure text logs match image count (pad with empty strings if needed)
      while (textLogs.length < imageFiles.length) {
        textLogs.push('');
      }

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
      const reversedTextLogs = [...textLogs].reverse();

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

      console.log(`🎬 Starting FFmpeg render with text overlays: ${renderId}`);

      // Return render ID immediately (non-blocking)
      res.json({
        success: true,
        data: {
          response: { id: renderId, message: 'Video render queued' }
        }
      });

      // Process video asynchronously with text logs
      processVideoWithFFmpeg(
        reversedImages,
        reversedTextLogs,  // 🆕 Pass text logs
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
async function processVideoWithFFmpeg(imageFiles, textLogs, durationPerImage, musicPath, outputPath, outputUrl, renderId) {
  try {
    renderJobs.set(renderId, {
      ...renderJobs.get(renderId),
      status: 'rendering',
      progress: 10
    });

    console.log(`🎥 Creating video from ${imageFiles.length} images with text overlays...`);

    // 🆕 Use the new function with text support
    const filterComplex = buildFilterComplexWithText(imageFiles, textLogs, durationPerImage);
    const totalDuration = imageFiles.length * durationPerImage;

    const command = ffmpeg();
    imageFiles.forEach((file) => command.input(file.path));

    let hasAudio = false;
    if (musicPath && fs.existsSync(musicPath)) {
      command.input(musicPath);
      hasAudio = true;
    }

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
        console.log(`✅ Video created successfully with text overlays: ${outputPath}`);
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
 * CRITICAL FIX: Last image duration extended to compensate for crossfade time loss
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

  // Calculate total fade time lost: Each crossfade loses 0.5s
  // With 3 images, we have 2 crossfades, so we lose 1s total
  const totalFadeTimeLost = (imageCount - 1) * fadeDuration;

  // Prepare each image with proper looping and duration
  for (let i = 0; i < imageCount; i++) {
    // Last image gets extended duration to compensate for all crossfade time loss
    // This ensures the video reaches the expected total duration
    const clipDuration = (i === imageCount - 1)
      ? durationPerImage + totalFadeTimeLost
      : durationPerImage;

    // loop=-1 means infinite loop, size=1 means loop 1 frame at a time
    // trim cuts the looped video to the desired duration
    // setpts resets timestamps to start from 0
    filters.push(
      `[${i}:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,loop=loop=-1:size=1:start=0,trim=duration=${clipDuration},setpts=PTS-STARTPTS,format=yuv420p[v${i}]`
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

/**
 * Escape special characters for FFmpeg drawtext filter
 */
function escapeFFmpegText(text) {
  if (!text) return '';

  return text
    .replace(/\\/g, '\\\\\\\\')    // Backslash (needs 4 backslashes for FFmpeg)
    .replace(/'/g, "'\\\\''")      // Single quote
    .replace(/:/g, '\\:')          // Colon
    .replace(/\n/g, '\\n')         // Newline (FFmpeg will render as line break)
    .replace(/\r/g, '')            // Remove carriage return
    .replace(/[^\x20-\x7E\n]/g, '') // Remove non-printable characters except newline
    .substring(0, 250);            // Limit length to prevent overflow
}

/**
 * Build FFmpeg filter complex with text overlays for each image
 */
function buildFilterComplexWithText(imageFiles, textLogs, durationPerImage) {
  const imageCount = imageFiles.length;

  if (imageCount === 1) {
    const textContent = escapeFFmpegText(textLogs[0] || '');
    const hasText = textContent.length > 0;

    let filter = `[0:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,loop=loop=-1:size=1:start=0,trim=duration=${durationPerImage},setpts=PTS-STARTPTS,format=yuv420p`;

    if (hasText) {
      filter += `,drawtext=text='${textContent}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.75:boxborderw=10:x=(w-text_w)/2:y=h-th-100:alpha='if(lt(t,0.8),t/0.8,if(lt(t,${durationPerImage-0.8}),1,(${durationPerImage}-t)/0.8))'`;
    }

    filter += `[outv]`;
    return [filter];
  }

  const filters = [];
  const fadeDuration = 0.5;
  const totalFadeTimeLost = (imageCount - 1) * fadeDuration;

  // Prepare each image with text overlay
  for (let i = 0; i < imageCount; i++) {
    const clipDuration = (i === imageCount - 1)
      ? durationPerImage + totalFadeTimeLost
      : durationPerImage;

    const textContent = escapeFFmpegText(textLogs[i] || '');
    const hasText = textContent.length > 0;

    // Base video processing
    let filter = `[${i}:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,loop=loop=-1:size=1:start=0,trim=duration=${clipDuration},setpts=PTS-STARTPTS,format=yuv420p`;

    // Add text overlay if text exists
    if (hasText) {
      filter += `,drawtext=text='${textContent}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=22:fontcolor=white:box=1:boxcolor=black@0.75:boxborderw=8:x=(w-text_w)/2:y=h-th-80:alpha='if(lt(t,0.8),t/0.8,if(lt(t,${clipDuration-0.8}),1,(${clipDuration}-t)/0.8))'`;
    }

    filter += `[v${i}]`;
    filters.push(filter);
  }

  // Apply crossfade transitions
  let current = 'v0';
  for (let i = 1; i < imageCount; i++) {
    const offset = (durationPerImage * i) - fadeDuration;
    const next = i === imageCount - 1 ? 'outv' : `v${i}tmp`;
    filters.push(`[${current}][v${i}]xfade=transition=fade:duration=${fadeDuration}:offset=${offset}[${next}]`);
    current = next;
  }

  return filters;
}

app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 Milestone Video API with FFmpeg started');
  console.log(`📍 Port: ${PORT}`);
  console.log(`🎥 FFmpeg: Enabled ✅`);
});
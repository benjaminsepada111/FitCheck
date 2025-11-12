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
        return res.status(400).json({
          success: false,
          error: 'No images provided'
        });
      }

      console.log(`🖼️ Total images: ${imageFiles.length}`);

      // Handle music
      const musicFiles = req.files?.['music'] || [];
      if (musicFiles.length > 0) {
        musicPath = musicFiles[0].path;
        console.log(`🎵 Music file: ${musicPath}`);
      } else if (req.body.musicUrl) {
        // Download music from URL to temp folder
        const musicUrl = req.body.musicUrl;
        console.log(`🎵 Downloading music from: ${musicUrl}`);

        try {
          const axios = require('axios');
          const musicResponse = await axios.get(musicUrl, { responseType: 'arraybuffer' });
          const musicExt = path.extname(new URL(musicUrl).pathname) || '.mp3';
          musicPath = path.join(TEMP_DIR, `music-${Date.now()}${musicExt}`);
          fs.writeFileSync(musicPath, Buffer.from(musicResponse.data));
          console.log(`✅ Music downloaded to: ${musicPath}`);
        } catch (err) {
          console.error('⚠️ Failed to download music:', err.message);
        }
      }

      // Reverse order (last milestone first) to match old Shotstack behavior
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

      // Return immediately with render ID (like Shotstack)
      res.json({
        success: true,
        data: {
          response: {
            id: renderId,
            message: 'Video render queued'
          }
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
      return res.status(500).json({
        success: false,
        error: err.message
      });
    }
  }
);

/**
 * Process video with FFmpeg
 */
async function processVideoWithFFmpeg(
  imageFiles,
  durationPerImage,
  musicPath,
  outputPath,
  outputUrl,
  renderId
) {
  try {
    // Update status to rendering
    renderJobs.set(renderId, {
      ...renderJobs.get(renderId),
      status: 'rendering',
      progress: 10
    });

    console.log(`🎥 Creating video from ${imageFiles.length} images...`);

    // Create filter complex for crossfade transitions
    const filterComplex = buildFilterComplex(imageFiles.length, durationPerImage);
    const totalDuration = imageFiles.length * durationPerImage;

    // Build FFmpeg command
    const command = ffmpeg();

    // Add all images as inputs
    imageFiles.forEach((file) => {
      command.input(file.path);
    });

    // Add music if provided
    let hasAudio = false;
    if (musicPath && fs.existsSync(musicPath)) {
      command.input(musicPath);
      hasAudio = true;
    }

    // Apply filter complex for crossfade transitions
    command
      .complexFilter(filterComplex)
      .outputOptions([
        '-map', '[outv]', // Map the final video output
        ...(hasAudio ? [
          '-map', `${imageFiles.length}:a`, // Map audio from music file
          '-shortest', // Cut to shortest stream (video or audio)
          '-c:a', 'aac',
          '-b:a', '128k',
          '-af', 'afade=t=in:st=0:d=1,afade=t=out:st=' + (totalDuration - 1) + ':d=1,volume=0.5'
        ] : ['-an']), // No audio if no music
        '-c:v', 'libx264',
        '-preset', 'medium',
        '-crf', '23',
        '-pix_fmt', 'yuv420p',
        '-vf', 'scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2', // 9:16 aspect ratio
        '-r', '30', // 30 fps
        '-movflags', '+faststart'
      ])
      .output(outputPath)
      .on('start', (commandLine) => {
        console.log('🎬 FFmpeg command:', commandLine);
      })
      .on('progress', (progress) => {
        const percent = progress.percent || 0;
        console.log(`⏳ Processing: ${Math.round(percent)}%`);

        // Update progress
        renderJobs.set(renderId, {
          ...renderJobs.get(renderId),
          progress: Math.min(Math.round(percent), 95)
        });
      })
      .on('end', () => {
        console.log(`✅ Video created successfully: ${outputPath}`);

        // Update status to done
        renderJobs.set(renderId, {
          status: 'done',
          progress: 100,
          url: outputUrl,
          error: null,
          createdAt: renderJobs.get(renderId).createdAt
        });

        // Clean up uploaded images after 5 minutes
        setTimeout(() => {
          imageFiles.forEach(file => {
            try {
              if (fs.existsSync(file.path)) fs.unlinkSync(file.path);
            } catch (err) {
              console.error('Error deleting file:', err);
            }
          });

          // Clean up downloaded music
          if (musicPath && musicPath.includes(TEMP_DIR)) {
            try {
              if (fs.existsSync(musicPath)) fs.unlinkSync(musicPath);
            } catch (err) {
              console.error('Error deleting music:', err);
            }
          }
        }, 5 * 60 * 1000);
      })
      .on('error', (err) => {
        console.error('❌ FFmpeg error:', err.message);

        // Update status to failed
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
 */
function buildFilterComplex(imageCount, durationPerImage) {
  if (imageCount === 1) {
    return [
      `[0:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p[outv]`
    ];
  }

  const filters = [];
  const fadeDuration = 0.5; // 0.5 second crossfade

  // Scale and pad each image
  for (let i = 0; i < imageCount; i++) {
    filters.push(
      `[${i}:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p,trim=duration=${durationPerImage}[v${i}]`
    );
  }

  // Create crossfade transitions
  let currentOutput = 'v0';
  for (let i = 1; i < imageCount; i++) {
    const offset = (durationPerImage * i) - fadeDuration;
    const nextOutput = i === imageCount - 1 ? 'outv' : `v${i}tmp`;

    filters.push(
      `[${currentOutput}][v${i}]xfade=transition=fade:duration=${fadeDuration}:offset=${offset}[${nextOutput}]`
    );

    currentOutput = nextOutput;
  }

  return filters;
}

/**
 * GET /api/render-status/:id
 * Check render status (mimics Shotstack API response)
 */
app.get('/api/render-status/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const job = renderJobs.get(id);

    if (!job) {
      return res.status(404).json({
        success: false,
        error: 'Render ID not found'
      });
    }

    console.log(`🔍 Checking status for ${id}: ${job.status} (${job.progress}%)`);

    // Return response in Shotstack-compatible format
    return res.json({
      success: true,
      data: {
        response: {
          id: id,
          status: job.status,
          progress: job.progress,
          url: job.url,
          error: job.error
        }
      }
    });
  } catch (err) {
    console.error('❌ Status check error:', err.message);
    return res.status(500).json({
      success: false,
      error: err.message
    });
  }
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

// Clean up old render jobs every hour
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
  console.log(`📁 Upload directory: ${UPLOAD_DIR}`);
  console.log(`📁 Video directory: ${VIDEO_DIR}`);
  console.log(`🎬 Video Mode: FFmpeg (Local Processing)`);
  console.log(`🔄 Order: REVERSED (Last → First milestone)`);
  console.log('---');
});
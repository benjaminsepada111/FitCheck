const express = require('express');
const multer = require('multer');
const ffmpeg = require('fluent-ffmpeg');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const sharp = require('sharp'); // For image preprocessing
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

const PORT = process.env.PORT || 5000;
const UPLOAD_DIR = path.join(__dirname, 'uploads');
const VIDEO_DIR = path.join(__dirname, 'videos');
const TEMP_DIR = path.join(__dirname, 'temp');
const PROCESSED_DIR = path.join(__dirname, 'processed');

[UPLOAD_DIR, VIDEO_DIR, TEMP_DIR, PROCESSED_DIR].forEach(dir => {
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
  limits: { fileSize: 10 * 1024 * 1024 }
});

const PUBLIC_BASE_OVERRIDE = process.env.BASE_URL || null;

// ✅ MEMORY OPTIMIZATION: Single render at a time
const MAX_CONCURRENT_RENDERS = 1;
let activeRenders = 0;

const renderJobs = new Map();

app.use('/uploads', express.static(UPLOAD_DIR));
app.use('/videos', express.static(VIDEO_DIR));

app.get('/', (req, res) => res.send('Milestone Video API - Memory Optimized'));

// ✅ NEW: Preprocess images to reduce memory footprint
async function preprocessImage(inputPath, outputPath) {
  try {
    await sharp(inputPath)
      .resize(540, 960, {
        fit: 'contain',
        background: { r: 0, g: 0, b: 0, alpha: 1 }
      })
      .jpeg({ quality: 80, progressive: true })
      .toFile(outputPath);

    return true;
  } catch (err) {
    console.error(`⚠️ Failed to preprocess image: ${err.message}`);
    return false;
  }
}

app.post(
  '/api/generate-video',
  upload.fields([
    { name: 'images', maxCount: 50 },
    { name: 'music', maxCount: 1 }
  ]),
  async (req, res) => {
    try {
      console.log('📥 Received generate-video request');

      const memBefore = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
      console.log(`💾 Memory before processing: ${memBefore}MB`);

      // ✅ Reject if too many concurrent renders
      if (activeRenders >= MAX_CONCURRENT_RENDERS) {
        console.log('⚠️ Server busy, rejecting request');
        return res.status(503).json({
          success: false,
          error: 'Server is processing another video. Please try again in a moment.'
        });
      }

      const durationPerImage = parseInt(req.body.duration ?? '2', 10) || 2;
      let musicPath = null;

      const baseUrl = PUBLIC_BASE_OVERRIDE || `${req.protocol}://${req.get('host')}`;

      const imageFiles = req.files?.['images'] || [];
      if (!imageFiles.length) {
        console.error('❌ No images provided');
        return res.status(400).json({ success: false, error: 'No images provided' });
      }

      console.log(`🖼️ Total images: ${imageFiles.length}`);

      // ✅ CRITICAL: Preprocess images to reduce size
      console.log('🔄 Preprocessing images to 540x960...');
      const processedImages = [];

      for (let i = 0; i < imageFiles.length; i++) {
        const processed = path.join(PROCESSED_DIR, `processed-${Date.now()}-${i}.jpg`);
        const success = await preprocessImage(imageFiles[i].path, processed);

        if (success) {
          processedImages.push(processed);
          // Delete original to free memory
          try { fs.unlinkSync(imageFiles[i].path); } catch {}
        } else {
          // Fallback to original if preprocessing fails
          processedImages.push(imageFiles[i].path);
        }
      }

      console.log(`✅ Preprocessed ${processedImages.length} images`);

      // Parse text logs
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

      while (textLogs.length < processedImages.length) {
        textLogs.push('');
      }

      // Handle music
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
          console.log(`✅ Music downloaded`);
        } catch (err) {
          console.error('⚠️ Failed to download music:', err.message);
        }
      }

      const renderId = uuidv4();
      const outputFileName = `video-${renderId}.mp4`;
      const outputPath = path.join(VIDEO_DIR, outputFileName);
      const outputUrl = `${baseUrl}/videos/${outputFileName}`;

      renderJobs.set(renderId, {
        status: 'queued',
        progress: 0,
        url: null,
        error: null,
        createdAt: new Date()
      });

      console.log(`🎬 Starting render: ${renderId}`);

      res.json({
        success: true,
        data: {
          response: { id: renderId, message: 'Video render queued' }
        }
      });

      // Process video (don't await - runs in background)
      processVideoWithFFmpeg(
        processedImages,
        textLogs,
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

async function processVideoWithFFmpeg(imagePaths, textLogs, durationPerImage, musicPath, outputPath, outputUrl, renderId) {
  activeRenders++;
  console.log(`🎥 Active renders: ${activeRenders}/${MAX_CONCURRENT_RENDERS}`);

  // Force garbage collection if available
  if (global.gc) {
    global.gc();
    console.log('♻️ Forced garbage collection');
  }

  try {
    renderJobs.set(renderId, {
      ...renderJobs.get(renderId),
      status: 'rendering',
      progress: 10
    });

    console.log(`🎥 Creating video from ${imagePaths.length} images...`);

    const filterComplex = buildFilterComplexWithText(imagePaths, textLogs, durationPerImage);
    const totalDuration = imagePaths.length * durationPerImage;

    const command = ffmpeg();

    // Add images as inputs
    imagePaths.forEach((imgPath) => command.input(imgPath));

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
          '-map', `${imagePaths.length}:a`,
          '-shortest',
          '-c:a', 'aac',
          '-b:a', '96k', // Lower audio bitrate
          `-af`, `afade=t=in:st=0:d=1,afade=t=out:st=${Math.max(totalDuration - 1, 1)}:d=1,volume=0.5`
        ] : ['-an']),
        '-c:v', 'libx264',
        '-preset', 'ultrafast', // Fastest preset for memory-constrained env
        '-crf', '28', // Higher CRF = smaller file, less memory
        '-pix_fmt', 'yuv420p',
        '-r', '24', // Lower framerate
        '-movflags', '+faststart',
        '-threads', '1', // Single thread to control memory
        '-max_muxing_queue_size', '512', // Reduced queue
        '-bufsize', '500k' // Limit buffer size
      ])
      .output(outputPath)
      .on('start', cmd => {
        console.log('🎬 FFmpeg started');
        const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
        console.log(`💾 Memory: ${mem}MB`);
      })
      .on('stderr', (stderrLine) => {
        if (stderrLine.includes('Error') || stderrLine.includes('Failed')) {
          console.error('⚠️ FFmpeg:', stderrLine);
        }
      })
      .on('progress', progress => {
        const percent = Math.min(Math.round(progress.percent || 0), 95);
        renderJobs.set(renderId, { ...renderJobs.get(renderId), progress: percent });

        if (percent % 25 === 0) {
          const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
          console.log(`⏳ ${percent}% | Memory: ${mem}MB`);
        }
      })
      .on('end', () => {
        console.log(`✅ Video created: ${outputPath}`);
        const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
        console.log(`💾 Final memory: ${mem}MB`);

        renderJobs.set(renderId, {
          status: 'done',
          progress: 100,
          url: outputUrl,
          error: null,
          createdAt: renderJobs.get(renderId).createdAt
        });

        activeRenders--;

        // Clean up files after 5 minutes
        setTimeout(() => {
          imagePaths.forEach(path => {
            try { if (fs.existsSync(path)) fs.unlinkSync(path); } catch {}
          });
          if (musicPath && musicPath.includes(TEMP_DIR)) {
            try { if (fs.existsSync(musicPath)) fs.unlinkSync(musicPath); } catch {}
          }

          // Force GC after cleanup
          if (global.gc) global.gc();
        }, 5 * 60 * 1000);
      })
      .on('error', err => {
        console.error('❌ FFmpeg error:', err.message);
        const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
        console.log(`💾 Memory at error: ${mem}MB`);

        renderJobs.set(renderId, {
          status: 'failed',
          progress: 0,
          url: null,
          error: err.message,
          createdAt: renderJobs.get(renderId).createdAt
        });

        activeRenders--;

        // Clean up on error
        imagePaths.forEach(path => {
          try { if (fs.existsSync(path)) fs.unlinkSync(path); } catch {}
        });
      })
      .run();

  } catch (err) {
    console.error('❌ Processing error:', err.message);
    renderJobs.set(renderId, {
      status: 'failed',
      progress: 0,
      url: null,
      error: err.message,
      createdAt: renderJobs.get(renderId).createdAt
    });

    activeRenders--;
  }
}

app.get('/api/render-status/:id', async (req, res) => {
  const id = req.params.id;
  const job = renderJobs.get(id);

  if (!job) {
    return res.status(404).json({ success: false, error: 'Render ID not found' });
  }

  return res.json({
    success: true,
    data: { response: job }
  });
});

app.get('/api/health', (req, res) => {
  const memUsage = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
  const memTotal = Math.round(process.memoryUsage().heapTotal / 1024 / 1024);

  res.json({
    status: 'ok',
    ffmpeg_available: true,
    active_renders: activeRenders,
    memory_used_mb: memUsage,
    memory_total_mb: memTotal,
    max_concurrent_renders: MAX_CONCURRENT_RENDERS,
    resolution: '540x960',
    timestamp: new Date().toISOString()
  });
});

// Cleanup old jobs every hour
setInterval(() => {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  for (const [id, job] of renderJobs.entries()) {
    if (job.createdAt < oneHourAgo) {
      console.log(`🧹 Cleaning up old job: ${id}`);
      renderJobs.delete(id);
    }
  }

  // Force GC during cleanup
  if (global.gc) global.gc();
}, 60 * 60 * 1000);

function escapeFFmpegText(text) {
  if (!text) return '';

  return text
    .replace(/\\/g, '\\\\\\\\')
    .replace(/'/g, "\u2019")
    .replace(/:/g, '\\:')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]')
    .replace(/\(/g, '\\(')
    .replace(/\)/g, '\\)')
    .replace(/\n/g, ' ')
    .replace(/\r/g, '')
    .replace(/×/g, 'x')
    .replace(/•/g, '-')
    .trim();
}

function splitTextIntoLines(text, maxCharsPerLine = 40) {
  if (!text || text.trim().length === 0) return [];

  const lines = [];
  const paragraphs = text.split('\n').filter(p => p.trim().length > 0);

  paragraphs.forEach(paragraph => {
    const trimmed = paragraph.trim();

    if (trimmed.length <= maxCharsPerLine) {
      lines.push(trimmed);
    } else {
      const words = trimmed.split(' ').filter(w => w.length > 0);
      let currentLine = '';

      words.forEach(word => {
        const testLine = currentLine.length > 0 ? `${currentLine} ${word}` : word;

        if (testLine.length <= maxCharsPerLine) {
          currentLine = testLine;
        } else {
          if (currentLine.length > 0) {
            lines.push(currentLine);
          }
          currentLine = word;
        }
      });

      if (currentLine.length > 0) {
        lines.push(currentLine);
      }
    }
  });

  return lines.slice(0, 12); // Limit lines to reduce memory
}

function buildFilterComplexWithText(imagePaths, textLogs, durationPerImage) {
  const imageCount = imagePaths.length;

  console.log(`🎬 Building filter (${imageCount} images, ${durationPerImage}s each)`);

  while (textLogs.length < imageCount) {
    textLogs.push('');
  }

  // Single image case
  if (imageCount === 1) {
    const textContent = textLogs[0] || '';
    const hasText = textContent.trim().length > 0;

    // Images are already 540x960, just format them
    let filter = `[0:v]setsar=1,fps=24,format=yuv420p`;

    if (hasText) {
      const lines = splitTextIntoLines(textContent, 40);
      console.log(`📝 Adding ${lines.length} text lines`);

      lines.forEach((line, index) => {
        const escapedLine = escapeFFmpegText(line);
        const isHeader = index === 0;

        const baseY = 120;
        const lineSpacing = 24;
        const yPosition = `h-${baseY + (lines.length - 1 - index) * lineSpacing}`;
        const fontSize = isHeader ? 20 : 16;

        filter += `,drawtext=text='${escapedLine}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=${fontSize}:fontcolor=white:borderw=2:bordercolor=black:x=30:y=${yPosition}:shadowcolor=black@0.8:shadowx=2:shadowy=2`;
      });
    }

    filter += `[outv]`;
    return [filter];
  }

  // Multiple images
  const filters = [];
  const fadeDuration = 0.5;

  for (let i = 0; i < imageCount; i++) {
    const textContent = textLogs[i] || '';
    const hasText = textContent.trim().length > 0;

    // Images are already 540x960
    let filter = `[${i}:v]setsar=1,fps=24,format=yuv420p`;

    if (hasText) {
      const lines = splitTextIntoLines(textContent, 40);

      lines.forEach((line, index) => {
        if (!line || line.trim().length === 0) return;

        const escapedLine = escapeFFmpegText(line);
        const isHeader = index === 0;

        const baseY = 120;
        const lineSpacing = 24;
        const yPosition = `h-${baseY + (lines.length - 1 - index) * lineSpacing}`;
        const fontSize = isHeader ? 20 : 16;

        filter += `,drawtext=text='${escapedLine}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=${fontSize}:fontcolor=white:borderw=2:bordercolor=black:x=30:y=${yPosition}:shadowcolor=black@0.8:shadowx=2:shadowy=2`;
      });
    }

    const clipDuration = durationPerImage;
    filter += `,loop=loop=-1:size=1:start=0,trim=duration=${clipDuration},setpts=PTS-STARTPTS[v${i}]`;

    filters.push(filter);
  }

  // Chain with xfade
  let current = 'v0';
  for (let i = 1; i < imageCount; i++) {
    const offset = i * (durationPerImage - fadeDuration);
    const next = i === imageCount - 1 ? 'outv' : `v${i}tmp`;

    filters.push(`[${current}][v${i}]xfade=transition=fade:duration=${fadeDuration}:offset=${offset}[${next}]`);
    current = next;
  }

  console.log(`✅ Filter built: ${filters.length} filters`);
  return filters;
}

app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 Milestone Video API - OPTIMIZED');
  console.log(`📍 Port: ${PORT}`);
  console.log(`📐 Resolution: 540x960 (memory-optimized)`);
  console.log(`🎥 Max concurrent: ${MAX_CONCURRENT_RENDERS}`);
  console.log(`💾 Memory limit: 512MB target`);
  console.log(`⚡ Preset: ultrafast (low memory usage)`);
  console.log(`📝 Text: Optimized overlay system`);
});
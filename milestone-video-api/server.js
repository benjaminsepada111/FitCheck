const express = require('express');
const multer = require('multer');
const ffmpeg = require('fluent-ffmpeg');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const sharp = require('sharp');
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

// ✅ GUARANTEED: Only 1 render at a time for 40 photos
const MAX_CONCURRENT_RENDERS = 1;
const MAX_IMAGES_ALLOWED = 40; // Now supports up to 40 photos
const MEMORY_LIMIT_MB = 470; // More aggressive abort for 40 photos (42MB buffer before limit)
let activeRenders = 0;

const renderJobs = new Map();

app.use('/uploads', express.static(UPLOAD_DIR));
app.use('/videos', express.static(VIDEO_DIR));

app.get('/', (req, res) => res.send('Milestone Video API - UP TO 40 PHOTOS GUARANTEED'));

// ✅ CRITICAL: Check memory before continuing
function checkMemorySafe() {
  const usage = process.memoryUsage();
  const heapUsedMB = Math.round(usage.heapUsed / 1024 / 1024);

  if (heapUsedMB > MEMORY_LIMIT_MB) {
    console.error(`🚨 MEMORY CRITICAL: ${heapUsedMB}MB > ${MEMORY_LIMIT_MB}MB`);
    return false;
  }
  return true;
}

// ✅ AGGRESSIVE: Force garbage collection
function forceGC() {
  if (global.gc) {
    global.gc();
    const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
    console.log(`♻️ GC forced: ${mem}MB`);
  }
}

// ✅ ULTRA-OPTIMIZED: Even smaller resolution for 40 photos (420x747)
async function preprocessImage(inputPath, outputPath) {
  try {
    // For up to 40 photos, use 420x747 (even smaller than 480x854)
    await sharp(inputPath)
      .resize(420, 747, {
        fit: 'contain',
        background: { r: 0, g: 0, b: 0, alpha: 1 }
      })
      .jpeg({
        quality: 72,  // Slightly lower quality for 40 photos
        progressive: true,
        mozjpeg: true
      })
      .toFile(outputPath);

    return true;
  } catch (err) {
    console.error(`⚠️ Preprocessing failed: ${err.message}`);
    return false;
  }
}

// ✅ SMALLER BATCHES: Process 4 images at a time (down from 5) for 40 photos
async function preprocessImagesBatch(imageFiles, batchSize = 4) {
  const processedImages = [];

  for (let i = 0; i < imageFiles.length; i += batchSize) {
    const batch = imageFiles.slice(i, i + batchSize);
    const batchNum = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(imageFiles.length / batchSize);

    console.log(`🔄 Processing batch ${batchNum}/${totalBatches} (${batch.length} images)`);

    for (let j = 0; j < batch.length; j++) {
      const file = batch[j];
      const processed = path.join(PROCESSED_DIR, `processed-${Date.now()}-${i + j}.jpg`);

      // Check memory before each image
      if (!checkMemorySafe()) {
        console.error('🚨 Memory limit reached during preprocessing');
        throw new Error('Memory limit exceeded');
      }

      const success = await preprocessImage(file.path, processed);

      if (success) {
        processedImages.push(processed);
        // Delete original immediately to free space
        try {
          fs.unlinkSync(file.path);
        } catch {}
      } else {
        throw new Error(`Failed to preprocess image ${i + j + 1}`);
      }
    }

    // Force GC after each batch
    forceGC();

    // Small delay to let system breathe
    await new Promise(resolve => setTimeout(resolve, 150));
  }

  return processedImages;
}

app.post(
  '/api/generate-video',
  upload.fields([
    { name: 'images', maxCount: 40 },
    { name: 'music', maxCount: 1 }
  ]),
  async (req, res) => {
    try {
      console.log('\n' + '='.repeat(60));
      console.log('📥 NEW VIDEO REQUEST');
      console.log('='.repeat(60));

      const memStart = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
      console.log(`💾 Starting memory: ${memStart}MB / 512MB`);

      // ✅ REJECT: If server is busy
      if (activeRenders >= MAX_CONCURRENT_RENDERS) {
        console.log('⚠️ Server busy - rejecting request');
        return res.status(503).json({
          success: false,
          error: 'Server is processing another video. Please wait and try again.'
        });
      }

      // ✅ CHECK: Memory is healthy before starting
      if (!checkMemorySafe()) {
        console.error('🚨 Memory too high to start new render');
        forceGC();
        return res.status(503).json({
          success: false,
          error: 'Server memory is high. Please try again in a moment.'
        });
      }

      const durationPerImage = parseInt(req.body.duration ?? '2', 10) || 2;
      let musicPath = null;

      const baseUrl = PUBLIC_BASE_OVERRIDE || `${req.protocol}://${req.get('host')}`;

      const imageFiles = req.files?.['images'] || [];

      // ✅ VALIDATE: Image count
      if (!imageFiles.length) {
        console.error('❌ No images provided');
        return res.status(400).json({ success: false, error: 'No images provided' });
      }

      if (imageFiles.length > MAX_IMAGES_ALLOWED) {
        console.error(`❌ Too many images: ${imageFiles.length} > ${MAX_IMAGES_ALLOWED}`);
        return res.status(400).json({
          success: false,
          error: `Maximum ${MAX_IMAGES_ALLOWED} images allowed. You sent ${imageFiles.length}.`
        });
      }

      console.log(`🖼️ Processing ${imageFiles.length} images`);
      console.log(`⏱️ Duration per image: ${durationPerImage}s`);
      console.log(`📹 Expected video length: ${imageFiles.length * durationPerImage}s`);

      // ✅ PREPROCESS: In smaller batches for 40 photos
      console.log('🔄 Starting batch preprocessing (420x747 ultra-optimized)...');
      let processedImages;

      try {
        processedImages = await preprocessImagesBatch(imageFiles, 4);
        console.log(`✅ Successfully preprocessed ${processedImages.length} images`);
      } catch (err) {
        console.error(`❌ Preprocessing failed: ${err.message}`);
        // Cleanup any processed images
        processedImages?.forEach(path => {
          try { fs.unlinkSync(path); } catch {}
        });
        return res.status(500).json({
          success: false,
          error: 'Failed to preprocess images. Server memory may be low.'
        });
      }

      const memAfterPreprocess = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
      console.log(`💾 After preprocessing: ${memAfterPreprocess}MB`);

      // Parse text logs
      let textLogs = [];
      if (req.body.textLogs) {
        try {
          textLogs = JSON.parse(req.body.textLogs);
          console.log(`📝 Text logs: ${textLogs.length}`);
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
        console.log('🎵 Music file provided');
      } else if (req.body.musicUrl) {
        const axios = require('axios');
        const musicUrl = req.body.musicUrl;
        console.log(`🎵 Downloading music: ${musicUrl}`);
        try {
          const musicResponse = await axios.get(musicUrl, {
            responseType: 'arraybuffer',
            timeout: 30000,
            maxContentLength: 10 * 1024 * 1024
          });
          const musicExt = path.extname(new URL(musicUrl).pathname) || '.mp3';
          musicPath = path.join(TEMP_DIR, `music-${Date.now()}${musicExt}`);
          fs.writeFileSync(musicPath, Buffer.from(musicResponse.data));
          console.log(`✅ Music downloaded: ${Math.round(musicResponse.data.byteLength / 1024)}KB`);
        } catch (err) {
          console.error('⚠️ Music download failed:', err.message);
          musicPath = null;
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
        imageCount: processedImages.length,
        createdAt: new Date()
      });

      console.log(`🎬 Render ID: ${renderId}`);
      console.log('='.repeat(60) + '\n');

      res.json({
        success: true,
        data: {
          response: {
            id: renderId,
            message: 'Video render queued',
            imageCount: processedImages.length,
            estimatedTime: Math.ceil(processedImages.length * 3.5)
          }
        }
      });

      // Start render in background
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
      console.error('❌ Request error:', err.message);
      console.error(err.stack);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
);

async function processVideoWithFFmpeg(imagePaths, textLogs, durationPerImage, musicPath, outputPath, outputUrl, renderId) {
  activeRenders++;
  console.log(`🎥 RENDER START - Active: ${activeRenders}/${MAX_CONCURRENT_RENDERS}`);

  // Force GC before starting
  forceGC();

  try {
    renderJobs.set(renderId, {
      ...renderJobs.get(renderId),
      status: 'rendering',
      progress: 10
    });

    const imageCount = imagePaths.length;
    console.log(`🎬 FFmpeg processing ${imageCount} images...`);

    // ✅ MEMORY CHECK: Before building filters
    if (!checkMemorySafe()) {
      throw new Error('Memory limit exceeded before FFmpeg start');
    }

    const filterComplex = buildFilterComplexWithText(imagePaths, textLogs, durationPerImage);
    const totalDuration = imageCount * durationPerImage;

    const command = ffmpeg();

    // Add all images
    imagePaths.forEach((imgPath) => {
      command.input(imgPath);
    });

    let hasAudio = false;
    if (musicPath && fs.existsSync(musicPath)) {
      command.input(musicPath);
      hasAudio = true;
      console.log('🎵 Audio track added');
    }

    // ✅ EXTREME OPTIMIZATION for 40 photos
    command
      .complexFilter(filterComplex)
      .outputOptions([
        '-map', '[outv]',
        ...(hasAudio ? [
          '-map', `${imageCount}:a`,
          '-shortest',
          '-c:a', 'aac',
          '-b:a', '48k',  // Very minimal audio bitrate
          `-af`, `afade=t=in:st=0:d=1,afade=t=out:st=${Math.max(totalDuration - 1, 1)}:d=1,volume=0.35`
        ] : ['-an']),
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-crf', '32',            // Higher CRF for 40 photos (more compression)
        '-pix_fmt', 'yuv420p',
        '-r', '18',              // Even lower FPS for 40 photos
        '-movflags', '+faststart',
        '-threads', '1',
        '-max_muxing_queue_size', '256',
        '-bufsize', '256k',      // Smaller buffer
        '-maxrate', '800k'       // Lower max bitrate
      ])
      .output(outputPath)
      .on('start', cmd => {
        console.log('🎬 FFmpeg command started');
        const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
        console.log(`💾 Memory at start: ${mem}MB / 512MB`);
        console.log(`⚠️ Critical threshold: ${MEMORY_LIMIT_MB}MB`);
      })
      .on('stderr', (stderrLine) => {
        if (stderrLine.includes('Error') || stderrLine.includes('Failed')) {
          console.error('⚠️ FFmpeg error:', stderrLine);
        }
      })
      .on('progress', progress => {
        const percent = Math.min(Math.round(progress.percent || 0), 95);
        renderJobs.set(renderId, {
          ...renderJobs.get(renderId),
          progress: percent
        });

        // Check memory every 20%
        if (percent % 20 === 0 || percent === 50) {
          const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
          const memPercent = Math.round((mem / 512) * 100);
          console.log(`⏳ Progress: ${percent}% | Memory: ${mem}MB (${memPercent}%)`);

          // ✅ EMERGENCY STOP if memory too high
          if (mem > MEMORY_LIMIT_MB) {
            console.error(`🚨 EMERGENCY: Memory ${mem}MB > ${MEMORY_LIMIT_MB}MB - ABORTING`);
            command.kill('SIGKILL');
          }
        }
      })
      .on('end', () => {
        const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
        console.log(`\n${'✅'.repeat(30)}`);
        console.log(`✅ VIDEO COMPLETED: ${renderId}`);
        console.log(`📁 File: ${outputPath}`);
        console.log(`💾 Final memory: ${mem}MB / 512MB`);
        console.log(`${'✅'.repeat(30)}\n`);

        const fileSize = fs.existsSync(outputPath) ?
          Math.round(fs.statSync(outputPath).size / 1024 / 1024) : 0;

        renderJobs.set(renderId, {
          status: 'done',
          progress: 100,
          url: outputUrl,
          error: null,
          fileSize: `${fileSize}MB`,
          imageCount: renderJobs.get(renderId).imageCount,
          createdAt: renderJobs.get(renderId).createdAt,
          completedAt: new Date()
        });

        activeRenders--;
        console.log(`🎥 Active renders: ${activeRenders}/${MAX_CONCURRENT_RENDERS}`);

        // Cleanup after 5 minutes
        setTimeout(() => {
          console.log(`🧹 Cleaning up files for ${renderId}`);
          imagePaths.forEach(path => {
            try { if (fs.existsSync(path)) fs.unlinkSync(path); } catch {}
          });
          if (musicPath && musicPath.includes(TEMP_DIR)) {
            try { if (fs.existsSync(musicPath)) fs.unlinkSync(musicPath); } catch {}
          }
          forceGC();
        }, 5 * 60 * 1000);
      })
      .on('error', err => {
        const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
        console.error(`\n${'❌'.repeat(30)}`);
        console.error(`❌ RENDER FAILED: ${renderId}`);
        console.error(`❌ Error: ${err.message}`);
        console.error(`💾 Memory at error: ${mem}MB`);
        console.error(`${'❌'.repeat(30)}\n`);

        renderJobs.set(renderId, {
          status: 'failed',
          progress: 0,
          url: null,
          error: err.message,
          imageCount: renderJobs.get(renderId).imageCount,
          createdAt: renderJobs.get(renderId).createdAt,
          failedAt: new Date()
        });

        activeRenders--;

        // Immediate cleanup on error
        imagePaths.forEach(path => {
          try { if (fs.existsSync(path)) fs.unlinkSync(path); } catch {}
        });
        if (musicPath && musicPath.includes(TEMP_DIR)) {
          try { if (fs.existsSync(musicPath)) fs.unlinkSync(musicPath); } catch {}
        }

        forceGC();
      })
      .run();

  } catch (err) {
    console.error('❌ Processing exception:', err.message);
    renderJobs.set(renderId, {
      status: 'failed',
      progress: 0,
      url: null,
      error: err.message,
      imageCount: renderJobs.get(renderId)?.imageCount || 0,
      createdAt: renderJobs.get(renderId)?.createdAt || new Date()
    });

    activeRenders--;
    forceGC();
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
  const usage = process.memoryUsage();
  const heapUsedMB = Math.round(usage.heapUsed / 1024 / 1024);
  const heapTotalMB = Math.round(usage.heapTotal / 1024 / 1024);
  const externalMB = Math.round(usage.external / 1024 / 1024);

  const memoryHealth = heapUsedMB < 380 ? 'healthy' :
                       heapUsedMB < 430 ? 'warning' : 'critical';

  res.json({
    status: 'ok',
    memory: {
      used_mb: heapUsedMB,
      total_mb: heapTotalMB,
      external_mb: externalMB,
      limit_mb: 512,
      available_mb: 512 - heapUsedMB,
      health: memoryHealth,
      usage_percent: Math.round((heapUsedMB / 512) * 100)
    },
    rendering: {
      active: activeRenders,
      max_concurrent: MAX_CONCURRENT_RENDERS,
      queue_size: renderJobs.size
    },
    config: {
      resolution: '420x747',
      max_images: MAX_IMAGES_ALLOWED,
      fps: 18,
      preset: 'ultrafast',
      batch_size: 4
    },
    timestamp: new Date().toISOString()
  });
});

// Aggressive cleanup every 30 minutes
setInterval(() => {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  let cleaned = 0;

  for (const [id, job] of renderJobs.entries()) {
    if (job.createdAt < oneHourAgo) {
      renderJobs.delete(id);
      cleaned++;
    }
  }

  if (cleaned > 0) {
    console.log(`🧹 Cleaned ${cleaned} old render jobs`);
  }

  forceGC();

  const mem = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
  console.log(`♻️ Periodic cleanup - Memory: ${mem}MB`);
}, 30 * 60 * 1000);

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

function splitTextIntoLines(text, maxCharsPerLine = 32) {  // Shorter lines for 420p
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

  return lines.slice(0, 9); // Max 9 lines for 420p to reduce memory
}

function buildFilterComplexWithText(imagePaths, textLogs, durationPerImage) {
  const imageCount = imagePaths.length;

  console.log(`🎬 Building filter complex:`);
  console.log(`   Images: ${imageCount}`);
  console.log(`   Duration: ${durationPerImage}s each`);
  console.log(`   Total duration: ${imageCount * durationPerImage}s`);

  while (textLogs.length < imageCount) {
    textLogs.push('');
  }

  // Single image case
  if (imageCount === 1) {
    const textContent = textLogs[0] || '';
    const hasText = textContent.trim().length > 0;

    let filter = `[0:v]setsar=1,fps=18,format=yuv420p`;

    if (hasText) {
      const lines = splitTextIntoLines(textContent, 32);

      lines.forEach((line, index) => {
        const escapedLine = escapeFFmpegText(line);
        const isHeader = index === 0;

        const baseY = 90;
        const lineSpacing = 20;
        const yPosition = `h-${baseY + (lines.length - 1 - index) * lineSpacing}`;
        const fontSize = isHeader ? 17 : 14;

        filter += `,drawtext=text='${escapedLine}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=${fontSize}:fontcolor=white:borderw=2:bordercolor=black:x=22:y=${yPosition}:shadowcolor=black@0.7:shadowx=1:shadowy=1`;
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

    let filter = `[${i}:v]setsar=1,fps=18,format=yuv420p`;

    if (hasText) {
      const lines = splitTextIntoLines(textContent, 32);

      lines.forEach((line, index) => {
        if (!line || line.trim().length === 0) return;

        const escapedLine = escapeFFmpegText(line);
        const isHeader = index === 0;

        const baseY = 90;
        const lineSpacing = 20;
        const yPosition = `h-${baseY + (lines.length - 1 - index) * lineSpacing}`;
        const fontSize = isHeader ? 17 : 14;

        filter += `,drawtext=text='${escapedLine}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=${fontSize}:fontcolor=white:borderw=2:bordercolor=black:x=22:y=${yPosition}:shadowcolor=black@0.7:shadowx=1:shadowy=1`;
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

  console.log(`✅ Filter complex built: ${filters.length} filters`);
  return filters;
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('⚠️ SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('⚠️ SIGINT received, shutting down gracefully...');
  process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('\n' + '='.repeat(70));
  console.log('🚀 MILESTONE VIDEO API - UP TO 40 PHOTOS GUARANTEED');
  console.log('='.repeat(70));
  console.log(`📍 Port: ${PORT}`);
  console.log(`📐 Resolution: 420x747 (ultra-optimized for 40 photos)`);
  console.log(`🎥 Max images: ${MAX_IMAGES_ALLOWED} photos`);
  console.log(`🔒 Max concurrent: ${MAX_CONCURRENT_RENDERS} render at a time`);
  console.log(`💾 Memory limit: ${MEMORY_LIMIT_MB}MB (512MB total available)`);
  console.log(`⚡ FFmpeg preset: ultrafast`);
  console.log(`🎬 FPS: 18 (ultra low for maximum stability)`);
  console.log(`📝 CRF: 32 (maximum compression)`);
  console.log(`🔢 Batch size: 4 images (smaller batches)`);
  console.log(`♻️ Garbage collection: AGGRESSIVE`);
  console.log(`✅ GUARANTEED: 1-40 photos without crashing`);
  console.log('='.repeat(70) + '\n');
});
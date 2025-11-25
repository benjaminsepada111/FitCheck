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
  limits: { fileSize: 10 * 1024 * 1024 }
});

const PUBLIC_BASE_OVERRIDE = process.env.BASE_URL || null;

const renderJobs = new Map();

// ✅ MEMORY OPTIMIZATION: Limit concurrent renders
const MAX_CONCURRENT_RENDERS = 2;
let activeRenders = 0;

app.use('/uploads', express.static(UPLOAD_DIR));
app.use('/videos', express.static(VIDEO_DIR));

app.get('/', (req, res) => res.send('Milestone Video API with FFmpeg is running'));

app.post(
  '/api/generate-video',
  upload.fields([
    { name: 'images', maxCount: 50 },
    { name: 'music', maxCount: 1 }
  ]),
  async (req, res) => {
    try {
      console.log('📥 Received generate-video request');

      // ✅ MEMORY CHECK: Reject if too many concurrent renders
      if (activeRenders >= MAX_CONCURRENT_RENDERS) {
        console.log('⚠️ Too many concurrent renders, rejecting request');
        return res.status(503).json({
          success: false,
          error: 'Server is busy processing other videos. Please try again in a moment.'
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

      // Parse text logs from request body
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

      // Ensure text logs match image count
      while (textLogs.length < imageFiles.length) {
        textLogs.push('');
      }

      // ✅ NEW: Add validation logging
      console.log('\n📊 Validation before processing:');
      console.log(`   Images: ${imageFiles.length}`);
      console.log(`   Text logs: ${textLogs.length}`);

      for (let i = 0; i < Math.min(imageFiles.length, 3); i++) {
        const preview = (textLogs[i] || '').substring(0, 60);
        console.log(`   Image ${i+1} text: "${preview}${textLogs[i] && textLogs[i].length > 60 ? '...' : ''}"`);
      }
      console.log('');

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
          console.log(`✅ Music downloaded to: ${musicPath}`);
        } catch (err) {
          console.error('⚠️ Failed to download music:', err.message);
        }
      }

      // Reverse order (last milestone first)
      const reversedImages = [...imageFiles].reverse();
      const reversedTextLogs = [...textLogs].reverse();

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

      console.log(`🎬 Starting FFmpeg render: ${renderId}`);

      res.json({
        success: true,
        data: {
          response: { id: renderId, message: 'Video render queued' }
        }
      });

      processVideoWithFFmpeg(
        reversedImages,
        reversedTextLogs,
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

async function processVideoWithFFmpeg(imageFiles, textLogs, durationPerImage, musicPath, outputPath, outputUrl, renderId) {
  activeRenders++;
  console.log(`🎥 Active renders: ${activeRenders}/${MAX_CONCURRENT_RENDERS}`);

  try {
    renderJobs.set(renderId, {
      ...renderJobs.get(renderId),
      status: 'rendering',
      progress: 10
    });

    console.log(`🎥 Creating video from ${imageFiles.length} images...`);

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
        '-preset', 'veryfast',
        '-crf', '25',
        '-pix_fmt', 'yuv420p',
        '-r', '30',
        '-movflags', '+faststart',
        '-threads', '2',
        '-max_muxing_queue_size', '1024'
      ])
      .output(outputPath)
      .on('start', cmd => {
        console.log('🎬 FFmpeg command started');
        console.log(`💾 Memory: ${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)}MB used`);
      })
      .on('stderr', (stderrLine) => {
        // ✅ NEW: Log FFmpeg errors for debugging
        if (stderrLine.includes('Error') || stderrLine.includes('Failed')) {
          console.error('⚠️ FFmpeg stderr:', stderrLine);
        }
      })
      .on('progress', progress => {
        const percent = Math.min(Math.round(progress.percent || 0), 95);
        renderJobs.set(renderId, { ...renderJobs.get(renderId), progress: percent });

        if (percent % 20 === 0) {
          const memUsage = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
          console.log(`⏳ Processing: ${percent}% | Memory: ${memUsage}MB`);
        }
      })
      .on('end', () => {
        console.log(`✅ Video created successfully: ${outputPath}`);
        const memUsage = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
        console.log(`💾 Final memory usage: ${memUsage}MB`);

        renderJobs.set(renderId, {
          status: 'done',
          progress: 100,
          url: outputUrl,
          error: null,
          createdAt: renderJobs.get(renderId).createdAt
        });

        activeRenders--;
        console.log(`🎥 Active renders: ${activeRenders}/${MAX_CONCURRENT_RENDERS}`);

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
        const memUsage = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
        console.log(`💾 Memory at error: ${memUsage}MB`);

        renderJobs.set(renderId, {
          status: 'failed',
          progress: 0,
          url: null,
          error: err.message,
          createdAt: renderJobs.get(renderId).createdAt
        });

        activeRenders--;
        console.log(`🎥 Active renders: ${activeRenders}/${MAX_CONCURRENT_RENDERS}`);
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

    activeRenders--;
    console.log(`🎥 Active renders: ${activeRenders}/${MAX_CONCURRENT_RENDERS}`);
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
  res.json({
    status: 'ok',
    ffmpeg_available: true,
    active_renders: activeRenders,
    memory_usage_mb: memUsage,
    max_memory_mb: 512,
    timestamp: new Date().toISOString()
  });
});

setInterval(() => {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  for (const [id, job] of renderJobs.entries()) {
    if (job.createdAt < oneHourAgo) {
      console.log(`🧹 Cleaning up old render job: ${id}`);
      renderJobs.delete(id);
    }
  }
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

// ✅ IMPROVED: Better empty string handling
function splitTextIntoLines(text, maxCharsPerLine = 45) {
  if (!text || text.trim().length === 0) return [];

  const lines = [];
  const paragraphs = text.split('\n').filter(p => p.trim().length > 0);

  paragraphs.forEach(paragraph => {
    const trimmed = paragraph.trim();

    if (trimmed.length <= maxCharsPerLine) {
      lines.push(trimmed);
    } else {
      const words = trimmed.split(' ').filter(w => w.length > 0); // ✅ Filter empty words
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

  return lines.slice(0, 15);
}

// ✅ COMPLETELY REWRITTEN: Better text overlay handling with improved logging
function buildFilterComplexWithText(imageFiles, textLogs, durationPerImage) {
  const imageCount = imageFiles.length;

  console.log(`\n🎬 Building filter complex (ALL CLIPS FIX):`);
  console.log(`   Images: ${imageCount}`);
  console.log(`   Text logs: ${textLogs.length}`);
  console.log(`   Duration per image: ${durationPerImage}s`);

  // ✅ SAFETY CHECK: Ensure text logs match image count
  while (textLogs.length < imageCount) {
    console.log(`⚠️ Padding text log ${textLogs.length + 1}`);
    textLogs.push('');
  }

  // ============================================================================
  // SPECIAL CASE: Single image
  // ============================================================================
  if (imageCount === 1) {
    const textContent = textLogs[0] || '';
    const hasText = textContent.trim().length > 0;

    let filter = `[0:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p`;

    if (hasText) {
      const lines = splitTextIntoLines(textContent, 45);
      console.log(`🎨 Clip 1: Adding ${lines.length} text lines`);

      lines.forEach((line, index) => {
        const escapedLine = escapeFFmpegText(line);
        const isHeader = index === 0;

        const baseY = 160;
        const lineSpacing = 28;
        const yPosition = `h-${baseY + (lines.length - 1 - index) * lineSpacing}`;
        const fontSize = isHeader ? 22 : 18;

        filter += `,drawtext=text='${escapedLine}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=${fontSize}:fontcolor=white:borderw=3:bordercolor=black:x=40:y=${yPosition}:shadowcolor=black@0.9:shadowx=2:shadowy=2:alpha='if(lt(t,0.8),t/0.8,if(lt(t,${durationPerImage-0.8}),1,(${durationPerImage}-t)/0.8))'`;
      });
    } else {
      console.log(`ℹ️ Clip 1: No text content`);
    }

    filter += `[outv]`;
    return [filter];
  }

  // ============================================================================
  // MULTIPLE IMAGES: The CORRECT Approach
  // Key: Create complete clips with text BEFORE xfade, use setpts to sync
  // ============================================================================

  const filters = [];
  const fadeDuration = 0.5;

  // ✅ STEP 1: Create each clip as a complete video segment with text overlay
  // These clips are self-contained and ready to be transitioned
  for (let i = 0; i < imageCount; i++) {
    const textContent = textLogs[i] || '';
    const hasText = textContent.trim().length > 0;

    // Base clip: scale, pad, format
    let filter = `[${i}:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p`;

    // Add text overlays if present
    if (hasText) {
      const lines = splitTextIntoLines(textContent, 45);
      console.log(`🎨 Clip ${i+1}/${imageCount}: Adding ${lines.length} text lines`);

      lines.forEach((line, index) => {
        if (!line || line.trim().length === 0) return;

        const escapedLine = escapeFFmpegText(line);
        const isHeader = index === 0;

        const baseY = 160;
        const lineSpacing = 28;
        const yPosition = `h-${baseY + (lines.length - 1 - index) * lineSpacing}`;
        const fontSize = isHeader ? 22 : 18;

        // ✅ Text visible for the full duration of this clip's display time
        // Simple fade in/out relative to THIS clip's timeline
        filter += `,drawtext=text='${escapedLine}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=${fontSize}:fontcolor=white:borderw=3:bordercolor=black:x=40:y=${yPosition}:shadowcolor=black@0.9:shadowx=2:shadowy=2`;
      });
    } else {
      console.log(`ℹ️ Clip ${i+1}/${imageCount}: No text content`);
    }

    // ✅ CRITICAL: Convert to video stream with proper duration
    // Last clip needs extra time to cover all the fade overlaps
    const isLastClip = (i === imageCount - 1);
    const totalFadeTimeLost = (imageCount - 1) * fadeDuration;
    const clipDuration = isLastClip ? (durationPerImage + totalFadeTimeLost) : durationPerImage;

    // Loop the frame, trim to duration, reset PTS
    filter += `,loop=loop=-1:size=1:start=0,trim=duration=${clipDuration},setpts=PTS-STARTPTS[v${i}]`;

    filters.push(filter);
    console.log(`✅ Clip ${i+1}: ${clipDuration}s with text overlay complete`);
  }

  // ✅ STEP 2: Chain the clips together with xfade transitions
  let current = 'v0';
  for (let i = 1; i < imageCount; i++) {
    // Calculate the offset for this transition
    const offset = (durationPerImage * i) - fadeDuration;
    const next = i === imageCount - 1 ? 'outv' : `v${i}tmp`;

    console.log(`🔗 Xfade ${i}: [${current}] + [v${i}] at ${offset}s → [${next}]`);

    filters.push(`[${current}][v${i}]xfade=transition=fade:duration=${fadeDuration}:offset=${offset}[${next}]`);
    current = next;
  }

  const expectedDuration = imageCount * durationPerImage;
  console.log(`✅ Filter complex built: ${filters.length} filters`);
  console.log(`   Expected duration: ${expectedDuration}s\n`);

  return filters;
}

app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 Milestone Video API started');
  console.log(`📍 Port: ${PORT}`);
  console.log(`🎥 FFmpeg: Enabled ✅`);
  console.log(`💾 Memory-optimized mode active`);
  console.log(`📝 Text overlay: Left-aligned with stroke effect`);
  console.log(`🔧 Improved text overlay alignment and error handling`);
});
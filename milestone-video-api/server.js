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
          console.log(`📄 First log sample: ${textLogs[0]?.substring(0, 100)}...`);

          // 🐛 DEBUG: Check for newlines
          if (textLogs[0]) {
            console.log('🐛 DEBUG - First text log analysis:');
            console.log('   Length:', textLogs[0].length);
            console.log('   Has newlines:', textLogs[0].includes('\n'));
            console.log('   Newline count:', (textLogs[0].match(/\n/g) || []).length);
          }
        } catch (e) {
          console.warn('⚠️ Failed to parse textLogs:', e.message);
          textLogs = [];
        }
      }

      // Ensure text logs match image count
      while (textLogs.length < imageFiles.length) {
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

      console.log(`🎬 Starting FFmpeg render with FULL text overlays: ${renderId}`);

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
  try {
    renderJobs.set(renderId, {
      ...renderJobs.get(renderId),
      status: 'rendering',
      progress: 10
    });

    console.log(`🎥 Creating video from ${imageFiles.length} images with FULL text overlays...`);

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
        console.log(`✅ Video created successfully with FULL text overlays: ${outputPath}`);
        renderJobs.set(renderId, {
          status: 'done',
          progress: 100,
          url: outputUrl,
          error: null,
          createdAt: renderJobs.get(renderId).createdAt
        });

        setTimeout(() => {
          // Cleanup images
          imageFiles.forEach(file => {
            try { if (fs.existsSync(file.path)) fs.unlinkSync(file.path); } catch {}
          });

          // Cleanup music
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

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    ffmpeg_available: true,
    active_renders: renderJobs.size,
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

/**
 * ✅ FIXED: Escape special characters for FFmpeg drawtext filter
 * Properly handles multi-line text with newlines
 */
function escapeFFmpegText(text) {
  if (!text) return '';

  return text
    .replace(/\\/g, '\\\\\\\\')           // Escape backslashes
    .replace(/'/g, "\u2019")              // Replace single quotes with right single quotation mark
    .replace(/:/g, '\\:')                 // Escape colons
    .replace(/\n/g, '\\n')                // Convert newlines to FFmpeg format
    .replace(/\r/g, '')                   // Remove carriage returns
    .trim()                               // Remove leading/trailing whitespace
    .substring(0, 600);                   // Increased limit to 600 chars
}

/**
 * ✅ FIXED: Build FFmpeg filter complex with proper multi-line text overlays
 * Uses inline text with correct escaping for newlines
 */
function buildFilterComplexWithText(imageFiles, textLogs, durationPerImage) {
  const imageCount = imageFiles.length;

  // Single image case
  if (imageCount === 1) {
    const textContent = textLogs[0] || '';
    const hasText = textContent.length > 0;

    let filter = `[0:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,loop=loop=-1:size=1:start=0,trim=duration=${durationPerImage},setpts=PTS-STARTPTS,format=yuv420p`;

    if (hasText) {
      const escapedText = escapeFFmpegText(textContent);
      console.log(`🎨 Adding text overlay (${escapedText.length} chars, ${(escapedText.match(/\\\\n/g) || []).length} lines)`);

      filter += `,drawtext=text='${escapedText}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=13:fontcolor=white:box=1:boxcolor=black@0.85:boxborderw=10:x=(w-text_w)/2:y=h-th-60:line_spacing=3:alpha='if(lt(t,0.8),t/0.8,if(lt(t,${durationPerImage-0.8}),1,(${durationPerImage}-t)/0.8))'`;
    }

    filter += `[outv]`;
    return [filter];
  }

  // Multiple images case
  const filters = [];
  const fadeDuration = 0.5;
  const totalFadeTimeLost = (imageCount - 1) * fadeDuration;

  for (let i = 0; i < imageCount; i++) {
    const clipDuration = (i === imageCount - 1)
      ? durationPerImage + totalFadeTimeLost
      : durationPerImage;

    const textContent = textLogs[i] || '';
    const hasText = textContent.length > 0;

    // Base video processing
    let filter = `[${i}:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,loop=loop=-1:size=1:start=0,trim=duration=${clipDuration},setpts=PTS-STARTPTS,format=yuv420p`;

    // Add text overlay
    if (hasText) {
      const escapedText = escapeFFmpegText(textContent);
      console.log(`🎨 Adding text overlay to clip ${i+1} (${escapedText.length} chars, ${(escapedText.match(/\\\\n/g) || []).length} lines)`);

      filter += `,drawtext=text='${escapedText}':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:fontsize=13:fontcolor=white:box=1:boxcolor=black@0.85:boxborderw=10:x=(w-text_w)/2:y=h-th-60:line_spacing=3:alpha='if(lt(t,0.8),t/0.8,if(lt(t,${clipDuration-0.8}),1,(${clipDuration}-t)/0.8))'`;
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
  console.log(`🎥 FFmpeg: Enabled with FULL text overlay support ✅`);
});
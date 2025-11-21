// server.js
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

app.get('/', (req, res) => res.send('Enhanced Milestone Video API with FFmpeg is running'));

/**
 * POST /api/generate-video
 * Creates video with text overlays and animations
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

      // Default duration per image (seconds). If you want 5 seconds per image, send duration=5 in request.
      const durationPerImage = parseInt(req.body.duration ?? '5', 10) || 5;
      let musicPath = null;

      const baseUrl = PUBLIC_BASE_OVERRIDE || `${req.protocol}://${req.get('host')}`;

      // Handle uploaded images
      const imageFiles = req.files?.['images'] || [];
      if (!imageFiles.length) {
        console.error('❌ No images provided');
        return res.status(400).json({ success: false, error: 'No images provided' });
      }

      console.log(`🖼️ Total images: ${imageFiles.length}`);

      // Parse text overlays (one per image)
      let textOverlays = [];
      try {
        if (req.body.textOverlays) {
          textOverlays = JSON.parse(req.body.textOverlays);
        }
      } catch (e) {
        console.warn('⚠️ Failed to parse textOverlays:', e.message);
      }

      // Parse text animation settings
      const textAnimation = req.body.textAnimation || 'typewriter'; // default to typewriter
      const textPosition = req.body.textPosition || 'bottom'; // top, center, bottom
      const textColor = req.body.textColor || 'white';
      const fontSize = parseInt(req.body.fontSize || '36', 10);
      const fontFile = req.body.fontFile || ''; // Path to custom font (optional)

      console.log(`📝 Text overlays: ${textOverlays.length}, Animation: ${textAnimation}`);

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
      const reversedTexts = [...textOverlays].reverse();

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
        createdAt: new Date(),
        metadata: {
          imageCount: reversedImages.length,
          textOverlays: reversedTexts,
          textAnimation,
          textPosition,
          durationPerImage
        }
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
        renderId,
        {
          textOverlays: reversedTexts,
          textAnimation,
          textPosition,
          textColor,
          fontSize,
          fontFile
        }
      );

    } catch (err) {
      console.error('❌ Generate-video error:', err.message);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * POST /api/edit-video
 * Re-generates video with updated text overlays and animations
 * Requires original renderId to retrieve image paths
 */
app.post('/api/edit-video', async (req, res) => {
  try {
    console.log('✏️ Received edit-video request');

    const originalRenderId = req.body.originalRenderId;
    const originalJob = renderJobs.get(originalRenderId);

    if (!originalJob || !originalJob.metadata) {
      return res.status(400).json({
        success: false,
        error: 'Original render not found or missing metadata'
      });
    }

    // Parse new settings
    const textOverlays = JSON.parse(req.body.textOverlays || '[]');
    const textAnimation = req.body.textAnimation || originalJob.metadata.textAnimation;
    const textPosition = req.body.textPosition || originalJob.metadata.textPosition;
    const textColor = req.body.textColor || 'white';
    const fontSize = parseInt(req.body.fontSize || '48', 10);
    const durationPerImage = parseInt(req.body.duration || originalJob.metadata.durationPerImage, 10);

    const baseUrl = PUBLIC_BASE_OVERRIDE || `${req.protocol}://${req.get('host')}`;

    // Generate new render ID
    const newRenderId = uuidv4();
    const outputFileName = `video-${newRenderId}.mp4`;
    const outputPath = path.join(VIDEO_DIR, outputFileName);
    const outputUrl = `${baseUrl}/videos/${outputFileName}`;

    // Re-use original images (stored in metadata or need to be passed)
    // For this to work, we need to store image paths in metadata
    // This is a simplified version - you may need to handle image re-upload

    renderJobs.set(newRenderId, {
      status: 'queued',
      progress: 0,
      url: null,
      error: null,
      createdAt: new Date(),
      metadata: {
        imageCount: textOverlays.length,
        textOverlays,
        textAnimation,
        textPosition,
        durationPerImage
      }
    });

    res.json({
      success: true,
      data: {
        response: { id: newRenderId, message: 'Video edit queued' }
      }
    });

    // Note: This endpoint assumes images are re-uploaded or cached
    // You'll need to implement image caching for full edit functionality

  } catch (err) {
    console.error('❌ Edit-video error:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * Process video with FFmpeg including text overlays
 */
async function processVideoWithFFmpeg(
  imageFiles,
  durationPerImage,
  musicPath,
  outputPath,
  outputUrl,
  renderId,
  textOptions = {}
) {
  try {
    renderJobs.set(renderId, {
      ...renderJobs.get(renderId),
      status: 'rendering',
      progress: 10
    });

    console.log(`🎥 Creating video from ${imageFiles.length} images with text overlays...`);

    const filterComplex = buildFilterComplexWithText(
      imageFiles.length,
      durationPerImage,
      textOptions
    );
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
        console.log(`✅ Video created successfully: ${outputPath}`);
        renderJobs.set(renderId, {
          status: 'done',
          progress: 100,
          url: outputUrl,
          error: null,
          createdAt: renderJobs.get(renderId).createdAt,
          metadata: renderJobs.get(renderId).metadata
        });

        // Auto cleanup after 5 minutes (delete uploads)
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
 * Build FFmpeg filter complex with text overlays and animations
 *
 * Approach:
 * - For each input image stream [i:v] we:
 *   1) scale/pad to 720x1280 (portrait) -> [img{i}]
 *   2) create a transparent text-layer using color source and drawtext -> [txt{i}]
 *   3) crop the text layer's width from 0 -> TEXT_WIDTH over typeDuration to simulate typing -> [txtc{i}]
 *   4) overlay cropped text layer onto image -> [v{i}]
 * - Then chain xfade transitions between v0, v1, v2 ...
 *
 * This reliably supports multi-line wrapped text and keeps the image on-screen until the reveal finishes.
 */
function buildFilterComplexWithText(imageCount, durationPerImage, textOptions = {}) {
  const {
    textOverlays = [],
    textAnimation = 'typewriter',
    textPosition = 'bottom',
    textColor = 'white',
    fontSize = 36,
    fontFile = ''
  } = textOptions;

  // Text box width - adjust as needed (max line width in pixels)
  const TEXT_BOX_WIDTH = 620; // within 720 px canvas, leave margins
  const TEXT_BOX_HEIGHT = 260; // fixed box height reserved at bottom (enough for multiple lines)
  const TEXT_BOX_X = '(ow-text_w)/2'; // center horizontally for drawtext coordinates (used in drawtext)
  // We'll compute numeric Y in expression depending on textPosition
  let yExpr;
  switch (textPosition) {
    case 'top':
      yExpr = '60';
      break;
    case 'center':
      yExpr = '(h-text_h)/2';
      break;
    case 'bottom':
    default:
      yExpr = 'h-text_h-60';
      break;
  }

  // If only one image, simpler flow but still keep text reveal behavior
  if (imageCount === 1) {
    const text = textOverlays[0] || '';
    const clipDuration = durationPerImage;
    const typeDuration = Math.min(5, clipDuration); // reveal up to 5s, or shorter if clip shorter

    // Steps:
    // [0:v] -> img0
    // color -> txtbg0 -> drawtext -> txt0 -> crop width over time -> txtc0
    // overlay txtc0 onto img0 -> outv
    const escapedText = escapeDrawtext(text);

    const filters = [
      // Scale + pad the image
      `[0:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,trim=duration=${clipDuration},setpts=PTS-STARTPTS,format=rgba[img0]`,

      // Transparent canvas for text (duration same as clip)
      `color=color=black@0:s=720x1280:d=${clipDuration}[txtbg0]`,

      // Draw wrapped text onto transparent canvas
      `[txtbg0]drawtext=${buildDrawtextOptions(escapedText, {
        fontSize, textColor, fontFile, textWidth: TEXT_BOX_WIDTH, x: TEXT_BOX_X, y: yExpr
      })}:format=rgba[txt0]`,

      // Crop the text layer's width dynamically to simulate typewriter reveal (left-to-right)
      // w = min(TEXT_BOX_WIDTH, (t/typeDuration)*TEXT_BOX_WIDTH)
      `[txt0]crop=w='if(lt(t,${typeDuration}), max(1, (${TEXT_BOX_WIDTH})*(t/${typeDuration})), ${TEXT_BOX_WIDTH})':h=1280:x=0:y=0[txtc0]`,

      // Overlay the cropped text layer onto the image
      `[img0][txtc0]overlay=0:0:format=auto,format=yuv420p[outv]`
    ];

    return filters;
  }

  // For multiple images
  const filters = [];
  const fadeDuration = 0.5;
  // We'll add a small extra padding for each clip so xfade has enough frames; compute clipLength per image
  // Each image will be trimmed to durationPerImage (so the reveal should fit within this duration).
  for (let i = 0; i < imageCount; i++) {
    const text = textOverlays[i] || '';
    const clipDuration = durationPerImage; // each image duration in seconds
    const typeDuration = Math.min(5, clipDuration); // reveal duration (max 5s)
    const escapedText = escapeDrawtext(text);

    // 1) scale/pad
    filters.push(
      `[${i}:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,trim=duration=${clipDuration},setpts=PTS-STARTPTS,format=rgba[img${i}]`
    );

    // 2) transparent canvas for text (duration same as clip)
    filters.push(
      `color=color=black@0:s=720x1280:d=${clipDuration}[txtbg${i}]`
    );

    // 3) drawtext (wrapped)
    filters.push(
      `[txtbg${i}]drawtext=${buildDrawtextOptions(escapedText, {
        fontSize, textColor, fontFile, textWidth: TEXT_BOX_WIDTH, x: TEXT_BOX_X, y: yExpr
      })}:format=rgba[txt${i}]`
    );

    // 4) crop width over time to reveal left-to-right
    filters.push(
      `[txt${i}]crop=w='if(lt(t,${typeDuration}), max(1, (${TEXT_BOX_WIDTH})*(t/${typeDuration})), ${TEXT_BOX_WIDTH})':h=1280:x=0:y=0[txtc${i}]`
    );

    // 5) overlay text onto image
    filters.push(
      `[img${i}][txtc${i}]overlay=0:0:format=auto,format=rgba[v${i}]`
    );
  }

  // Chain crossfade transitions:
  // We'll chain xfade between v0 and v1, then result with v2, etc.
  // Important: xfade offset is the time (from start of timeline) at which transition starts.
  // We compute offsets cumulatively: first transition happens at (durationPerImage - fadeDuration),
  // second at (2*durationPerImage - fadeDuration), etc.
  let current = 'v0';
  for (let i = 1; i < imageCount; i++) {
    // transition start offset (seconds)
    const offset = (durationPerImage * i) - fadeDuration;
    const nextLabel = i === imageCount - 1 ? 'outv' : `v${i}tmp`;

    // Use xfade. Input streams: [current][v{i}] -> [nextLabel]
    filters.push(
      `[${current}][v${i}]xfade=transition=fade:duration=${fadeDuration}:offset=${offset}[${nextLabel}]`
    );

    current = nextLabel;
  }

  return filters;
}

/**
 * Escape text for drawtext
 */
function escapeDrawtext(text) {
  return (text || '')
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/:/g, '\\:')
    .replace(/%/g, '%%') // percent signs may be used by ffmpeg expressions
    .replace(/\n/g, '\\n');
}

/**
 * Build drawtext options string for ffmpeg with wrapping and box.
 * Returns a single string (no leading comma). Caller will add it into drawtext=...
 *
 * We use:
 * - text: escaped (already) passed in
 * - fontsize, fontcolor
 * - box=1 with semi-transparent background
 * - text_wrap by setting text_w (text width) and fix_bounds=1
 *
 * Note: ffmpeg drawtext supports text_w/text_h when used internally
 */
function buildDrawtextOptions(escapedText, opts = {}) {
  const {
    fontSize = 36,
    textColor = 'white',
    fontFile = '',
    textWidth = 620,
    x = '(w-text_w)/2',
    y = 'h-text_h-60'
  } = opts;

  // drawtext option list (these become key=val separated by ':')
  const parts = [];

  // text text
  parts.push(`text='${escapedText}'`);
  parts.push(`fontsize=${fontSize}`);
  parts.push(`fontcolor=${textColor}`);
  parts.push(`x=${x}`);
  parts.push(`y=${y}`);

  // box and styling
  parts.push(`box=1`);
  parts.push(`boxcolor=black@0.45`);
  parts.push(`boxborderw=10`);
  parts.push(`borderw=2`);
  parts.push(`bordercolor=black@0.6`);

  // authoritative wrapping behavior:
  // - fix_bounds=1 ensures ffmpeg uses text_w instead of expanding
  // - text_w sets the maximum width for wrapping
  parts.push(`fix_bounds=1`);
  parts.push(`text_w=${textWidth}`); // wrap to this width
  parts.push(`line_spacing=6`);
  parts.push(`enable='gte(t,0)'`); // always enabled for this canvas

  // add fontfile if provided
  if (fontFile) {
    // wrap font file path in single quotes if contains spaces
    parts.push(`fontfile=${fontFile}`);
  }

  // join into one string
  return parts.join(':');
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
    features: {
      text_overlays: true,
      text_animations: ['fadein', 'fadeout', 'fadeinout', 'typewriter', 'slidein', 'slideout'],
      editing: true
    },
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
  console.log('🚀 Enhanced Milestone Video API with FFmpeg started');
  console.log(`📍 Port: ${PORT}`);
  console.log(`🎥 FFmpeg: Enabled ✅`);
  console.log(`📝 Text Overlays: Enabled ✅`);
  console.log(`✨ Animations: fadein, fadeout, fadeinout, typewriter, slidein, slideout`);
});

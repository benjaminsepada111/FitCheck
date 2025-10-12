const express = require('express');
const multer = require('multer');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

const PORT = process.env.PORT || 5000;
const UPLOAD_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '';
    cb(null, `${Date.now()}-${Math.round(Math.random()*1e9)}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB per file
});

const SHOTSTACK_KEY = process.env.SHOTSTACK_API_KEY;
const SHOTSTACK_BASE = process.env.SHOTSTACK_BASE || 'https://api.shotstack.io/stage';
const PUBLIC_BASE_OVERRIDE = process.env.BASE_URL || null;

app.use('/uploads', express.static(UPLOAD_DIR));

app.get('/', (req, res) => res.send('Milestone Video API is running'));

/**
 * POST /api/generate-video
 * - Accepts multipart images files (field name = 'images')
 * - Accepts optional music file (field name = 'music')
 * - Optional fields:
 *   - notes: JSON array string (["note1","note2",...])
 *   - duration: seconds per image (number)
 *   - musicUrl: external music file URL (optional)
 */
app.post('/api/generate-video',
  upload.fields([
    { name: 'images', maxCount: 50 },
    { name: 'music', maxCount: 1 }
  ]),
  async (req, res) => {
    try {
      console.log('📥 Received generate-video request');

      if (!SHOTSTACK_KEY) {
        console.error('❌ Missing SHOTSTACK_API_KEY');
        return res.status(500).json({
          success: false,
          error: 'Missing SHOTSTACK_API_KEY in server configuration'
        });
      }

      // Parse fields
      let notes = [];
      if (req.body.notes) {
        try {
          notes = JSON.parse(req.body.notes);
        } catch (e) {
          notes = String(req.body.notes).split(',');
        }
      }

      const durationPerImage = parseInt(req.body.duration ?? '2', 10) || 2;
      let musicUrl = req.body.musicUrl || null;

      console.log(`📋 Config: ${notes.length} notes, duration: ${durationPerImage}s`);

      // Build accessible URLs for uploaded files
      const baseUrl = PUBLIC_BASE_OVERRIDE || `${req.protocol}://${req.get('host')}`;

      // Handle uploaded images
      const imageFiles = req.files?.['images'] || [];
      const uploadedUrls = imageFiles.map(f => {
        const url = `${baseUrl}/uploads/${f.filename}`;
        console.log(`✅ Uploaded image: ${url}`);
        return url;
      });

      // Handle uploaded music file (takes priority over musicUrl)
      const musicFiles = req.files?.['music'] || [];
      if (musicFiles.length > 0) {
        const musicFile = musicFiles[0];
        musicUrl = `${baseUrl}/uploads/${musicFile.filename}`;
        console.log(`🎵 Uploaded music file: ${musicUrl}`);
      } else if (musicUrl) {
        console.log(`🎵 Using music URL: ${musicUrl}`);
      } else {
        console.log(`🎵 No music provided`);
      }

      if (!uploadedUrls.length) {
        console.error('❌ No images provided');
        return res.status(400).json({
          success: false,
          error: 'No images provided'
        });
      }

      console.log(`🖼️ Total images to process: ${uploadedUrls.length}`);

      // Build Shotstack timeline
      const imageClips = uploadedUrls.map((src, i) => ({
        asset: {
          type: 'image',
          src
        },
        start: i * durationPerImage,
        length: durationPerImage,
        transition: {
          in: 'fade',
          out: 'fade'
        },
        fit: 'contain',
        scale: 1.0
      }));

      // Only add title clips for notes that exist
      const titleClips = uploadedUrls
        .map((src, i) => {
          const noteText = notes[i] || '';
          if (!noteText || noteText.trim() === '') return null;

          return {
            asset: {
              type: 'title',
              text: noteText.trim(),
              style: 'minimal',
              position: 'bottom',
              size: 'small',
              color: '#ffffff',
              background: "#000000B3"
            },
            start: i * durationPerImage,
            length: durationPerImage
          };
        })
        .filter(clip => clip !== null);

      const tracks = [
        { clips: imageClips }
      ];

      // Only add title track if there are titles
      if (titleClips.length > 0) {
        tracks.push({ clips: titleClips });
      }

      const payload = {
        timeline: {
          background: '#000000',
          tracks,
          ...(musicUrl ? {
            soundtrack: {
              src: musicUrl,
              effect: 'fadeInFadeOut',
              volume: 0.5
            }
          } : {})
        },
        output: {
          format: 'mp4',
          resolution: 'sd',
          quality: 'medium',
          aspectRatio: '9:16' // 👈 This line forces portrait video
        }
      };


      console.log('📤 Sending request to Shotstack API...');
      console.log('🎬 Timeline:', JSON.stringify(payload.timeline, null, 2));

      // Send to Shotstack render endpoint
      const response = await axios.post(
        `${SHOTSTACK_BASE}/render`,
        payload,
        {
          headers: {
            'x-api-key': SHOTSTACK_KEY,
            'Content-Type': 'application/json'
          },
          timeout: 30000
        }
      );

      console.log('✅ Shotstack response:', JSON.stringify(response.data, null, 2));

      return res.json({
        success: true,
        data: response.data,
        message: 'Video render started successfully'
      });

    } catch (err) {
      console.error('❌ Generate-video error:', err.message);
      if (err.response) {
        console.error('Response data:', err.response.data);
        console.error('Response status:', err.response.status);
      }

      return res.status(500).json({
        success: false,
        error: err.message,
        details: err.response?.data || null
      });
    }
  }
);

/**
 * GET /api/render-status/:id
 */
app.get('/api/render-status/:id', async (req, res) => {
  try {
    if (!SHOTSTACK_KEY) {
      return res.status(500).json({
        success: false,
        error: 'Missing SHOTSTACK_API_KEY'
      });
    }

    const id = req.params.id;
    console.log(`🔍 Checking render status for: ${id}`);

    const response = await axios.get(
      `${SHOTSTACK_BASE}/render/${id}`,
      {
        headers: { 'x-api-key': SHOTSTACK_KEY },
        timeout: 10000
      }
    );

    const status = response.data?.response?.status;
    const url = response.data?.response?.url;

    console.log(`📊 Render ${id} status: ${status}${url ? ` | URL: ${url}` : ''}`);

    return res.json({
      success: true,
      data: response.data
    });

  } catch (err) {
    console.error('❌ Status check error:', err.message);
    if (err.response) {
      console.error('Response data:', err.response.data);
    }

    return res.status(500).json({
      success: false,
      error: err.message,
      details: err.response?.data || null
    });
  }
});

/**
 * GET /api/health
 */
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    shotstack_configured: !!SHOTSTACK_KEY,
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 Milestone Video API started');
  console.log(`📍 Port: ${PORT}`);
  console.log(`🔑 Shotstack API: ${SHOTSTACK_KEY ? 'Configured ✅' : 'Missing ❌'}`);
  console.log(`🌐 Endpoint: ${SHOTSTACK_BASE}`);
  console.log(`📁 Upload directory: ${UPLOAD_DIR}`);
  console.log('---');
});
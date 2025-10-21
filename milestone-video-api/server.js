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
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
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
 * - Accepts multipart image files (field name = 'images')
 * - Accepts optional music file (field name = 'music')
 * - Optional fields:
 *   - duration: seconds per image (number)
 *   - musicUrl: external music file URL (optional)
 *
 * Videos now play milestones in REVERSE order
 * - Last milestone photo appears first
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

      if (!SHOTSTACK_KEY) {
        console.error('❌ Missing SHOTSTACK_API_KEY');
        return res.status(500).json({
          success: false,
          error: 'Missing SHOTSTACK_API_KEY in server configuration'
        });
      }

      const durationPerImage = parseInt(req.body.duration ?? '2', 10) || 2;
      let musicUrl = req.body.musicUrl || null;

      console.log(`📋 Duration per image: ${durationPerImage}s`);

      const baseUrl = PUBLIC_BASE_OVERRIDE || `${req.protocol}://${req.get('host')}`;

      // Handle uploaded images
      const imageFiles = req.files?.['images'] || [];
      const uploadedUrls = imageFiles.map(f => `${baseUrl}/uploads/${f.filename}`);

      // Handle uploaded music file
      const musicFiles = req.files?.['music'] || [];
      if (musicFiles.length > 0) {
        const musicFile = musicFiles[0];
        musicUrl = `${baseUrl}/uploads/${musicFile.filename}`;
        console.log(`🎵 Uploaded music file: ${musicUrl}`);
      } else if (musicUrl) {
        console.log(`🎵 Using provided music URL: ${musicUrl}`);
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
      console.log('🔄 Reversing milestone order for video generation...');

      // Reverse order (last milestone first)
      const reversedUrls = [...uploadedUrls].reverse();

      // Build image clips (no text)
      const imageClips = reversedUrls.map((src, i) => ({
        asset: { type: 'image', src },
        start: i * durationPerImage,
        length: durationPerImage,
        transition: { in: 'fade', out: 'fade' },
        fit: 'contain',
        scale: 1.0
      }));

      const tracks = [{ clips: imageClips }];

      const payload = {
        timeline: {
          background: '#000000',
          tracks,
          ...(musicUrl
            ? {
                soundtrack: {
                  src: musicUrl,
                  effect: 'fadeInFadeOut',
                  volume: 0.5
                }
              }
            : {})
        },
        output: {
          format: 'mp4',
          resolution: 'sd',
          quality: 'medium',
          aspectRatio: '9:16'
        }
      };

      console.log('📤 Sending request to Shotstack API...');

      const response = await axios.post(`${SHOTSTACK_BASE}/render`, payload, {
        headers: {
          'x-api-key': SHOTSTACK_KEY,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      });

      console.log('✅ Shotstack response:', JSON.stringify(response.data, null, 2));

      return res.json({
        success: true,
        data: response.data,
        message: 'Video render started successfully (images only)'
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

    const response = await axios.get(`${SHOTSTACK_BASE}/render/${id}`, {
      headers: { 'x-api-key': SHOTSTACK_KEY },
      timeout: 10000
    });
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
  console.log('🎬 Video Mode: IMAGES ONLY (no text)');
  console.log('🔄 Order: REVERSED (Last → First milestone)');
  console.log('---');
});

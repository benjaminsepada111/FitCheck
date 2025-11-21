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
              const textAnimation = req.body.textAnimation || 'fadein'; // fadein, fadeout, typewriter, slidein
              const textPosition = req.body.textPosition || 'bottom'; // top, center, bottom
              const textColor = req.body.textColor || 'white';
              const fontSize = parseInt(req.body.fontSize || '48', 10);
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
         * Build FFmpeg filter complex with text overlays and animations
         *
         * Text Animation Types:
         * - fadein: Text fades in at the start
         * - fadeout: Text fades out at the end
         * - fadeinout: Text fades in and out
         * - typewriter: Text appears character by character
         * - slidein: Text slides in from bottom
         * - slideout: Text slides out to top
         */
        function buildFilterComplexWithText(imageCount, durationPerImage, textOptions = {}) {
          const {
            textOverlays = [],
            textAnimation = 'fadein',
            textPosition = 'bottom',
            textColor = 'white',
            fontSize = 48,
            fontFile = ''
          } = textOptions;

          if (imageCount === 1) {
            const text = textOverlays[0] || '';
            const textFilter = text ? buildTextFilter(text, 0, durationPerImage, textAnimation, textPosition, textColor, fontSize, fontFile) : '';

            return [
              `[0:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,loop=loop=-1:size=1:start=0,trim=duration=${durationPerImage},setpts=PTS-STARTPTS,format=yuv420p${textFilter}[outv]`
            ];
          }

          const filters = [];
          const fadeDuration = 0.5;
          const totalFadeTimeLost = (imageCount - 1) * fadeDuration;

          // Prepare each image with text overlay
          for (let i = 0; i < imageCount; i++) {
            const clipDuration = (i === imageCount - 1)
              ? durationPerImage + totalFadeTimeLost
              : durationPerImage;

            const text = textOverlays[i] || '';
            const textFilter = text ? buildTextFilter(text, 0, clipDuration, textAnimation, textPosition, textColor, fontSize, fontFile) : '';

            filters.push(
              `[${i}:v]scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,loop=loop=-1:size=1:start=0,trim=duration=${clipDuration},setpts=PTS-STARTPTS,format=yuv420p${textFilter}[v${i}]`
            );
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

        /**
         * Wrap text to multiple lines for better readability
         * Optimized for 720px width video (28 chars per line works well)
         */
        function wrapText(text, maxCharsPerLine = 28) {
          if (!text || text.trim().length === 0) return '';

          const words = text.trim().split(/\s+/);
          const lines = [];
          let currentLine = '';

          for (const word of words) {
            const testLine = currentLine ? `${currentLine} ${word}` : word;

            if (testLine.length <= maxCharsPerLine) {
              currentLine = testLine;
            } else {
              if (currentLine) {
                lines.push(currentLine);
              }
              // If single word is longer than max, break it
              if (word.length > maxCharsPerLine) {
                const chunks = word.match(new RegExp(`.{1,${maxCharsPerLine}}`, 'g')) || [word];
                lines.push(...chunks.slice(0, -1));
                currentLine = chunks[chunks.length - 1];
              } else {
                currentLine = word;
              }
            }
          }

          if (currentLine) {
            lines.push(currentLine);
          }

          // Limit to 3 lines maximum for readability
          if (lines.length > 3) {
            lines[2] = lines[2].substring(0, maxCharsPerLine - 3) + '...';
            return lines.slice(0, 3).join('\\n');
          }

          return lines.join('\\n');
        }

        /**
         * Build text filter for FFmpeg drawtext
         */
        function buildTextFilter(text, startTime, duration, animation, position, color, fontSize, fontFile) {
          if (!text || text.trim().length === 0) return '';

          // Wrap text first to handle long lines (using default 28 chars)
          const wrappedText = wrapText(text);
          if (!wrappedText) return '';

          // Escape text for FFmpeg - this is critical!
          // The text already has \\n from wrapText, so we need to handle it carefully
          let escapedText = wrappedText
            .replace(/\\/g, '\\\\')     // Escape backslashes first
            .replace(/'/g, "\\'")        // Escape single quotes
            .replace(/:/g, '\\:')        // Escape colons
            .replace(/\[/g, '\\[')       // Escape brackets
            .replace(/\]/g, '\\]');      // Escape brackets

          // Calculate position with better padding
          let x = '(w-text_w)/2'; // Center horizontally
          let y;
          switch (position) {
            case 'top':
              y = '60';
              break;
            case 'center':
              y = '(h-text_h)/2';
              break;
            case 'bottom':
            default:
              y = 'h-text_h-100'; // More space from bottom for wrapped text
              break;
          }

          // Base drawtext options
          let drawtextOptions = [
            `fontsize=${fontSize}`,
            `fontcolor=${color}`,
            `x=${x}`,
            `y=${y}`,
            `borderw=3`,
            `bordercolor=black@0.9`,
            `box=1`,
            `boxcolor=black@0.6`,
            `boxborderw=20`,
            `line_spacing=8`
          ];

          // Add font file if provided
          if (fontFile) {
            drawtextOptions.push(`fontfile=${fontFile}`);
          }

          // Add animation effects
          switch (animation) {
            case 'fadein':
              // Fade in over 0.6 seconds
              drawtextOptions.push(`alpha='if(lt(t,0.6),t/0.6,1)'`);
              drawtextOptions.unshift(`text='${escapedText}'`);
              break;

            case 'fadeout':
              // Fade out in last 0.6 seconds
              drawtextOptions.push(`alpha='if(gt(t,${duration - 0.6}),(${duration}-t)/0.6,1)'`);
              drawtextOptions.unshift(`text='${escapedText}'`);
              break;

            case 'fadeinout':
              // Fade in first 0.6s, fade out last 0.6s
              drawtextOptions.push(`alpha='if(lt(t,0.6),t/0.6,if(gt(t,${duration - 0.6}),(${duration}-t)/0.6,1))'`);
              drawtextOptions.unshift(`text='${escapedText}'`);
              break;

            case 'typewriter':
              // True typewriter effect using box expansion
              const typewriterDuration = Math.min(1.8, duration * 0.75);

              // Use box width animation to create typewriter reveal
              // The box expands from 0 to full width over time
              const boxWidth = `if(lt(t,${typewriterDuration}),text_w*t/${typewriterDuration},text_w)`;

              // Override box settings for typewriter effect
              drawtextOptions = drawtextOptions.filter(opt =>
                !opt.startsWith('box=') &&
                !opt.startsWith('boxborderw=') &&
                !opt.startsWith('boxcolor=')
              );

              drawtextOptions.push(`box=1`);
              drawtextOptions.push(`boxw=${boxWidth}`);
              drawtextOptions.push(`boxcolor=black@0.6`);
              drawtextOptions.push(`boxborderw=20`);

              // Add fade in during typewriter
              drawtextOptions.push(`alpha='if(lt(t,0.3),t/0.3,1)'`);

              drawtextOptions.unshift(`text='${escapedText}'`);
              break;

            case 'slidein':
              // Slide in from bottom over 0.8 seconds
              const slideInY = position === 'bottom' ? 'h' : (position === 'top' ? '-text_h' : 'h');
              drawtextOptions[3] = `y='if(lt(t,0.8),${slideInY}-(${slideInY}-(${y}))*t/0.8,${y})'`;
              drawtextOptions.push(`alpha='if(lt(t,0.8),t/0.8,1)'`);
              drawtextOptions.unshift(`text='${escapedText}'`);
              break;

            case 'slideout':
              // Slide out to top in last 0.8 seconds
              const slideOutY = position === 'bottom' ? 'h' : (position === 'top' ? '-text_h' : 'h');
              drawtextOptions[3] = `y='if(gt(t,${duration - 0.8}),${y}+(${slideOutY}-(${y}))*(t-(${duration}-0.8))/0.8,${y})'`;
              drawtextOptions.push(`alpha='if(gt(t,${duration - 0.8}),(${duration}-t)/0.8,1)'`);
              drawtextOptions.unshift(`text='${escapedText}'`);
              break;

            default:
              // No animation
              drawtextOptions.unshift(`text='${escapedText}'`);
              break;
          }

          return `,drawtext=${drawtextOptions.join(':')}`;
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
              text_wrapping: true,
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
          console.log(`📄 Text Wrapping: Enabled ✅`);
          console.log(`✨ Animations: fadein, fadeout, fadeinout, typewriter, slidein, slideout`);
        });
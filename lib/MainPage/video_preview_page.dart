import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/services/api_service.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ============================================================================
// MAIN VIDEO EDITOR PAGE
// ============================================================================
class VideoEditorPage extends StatefulWidget {
  final String videoUrl;
  final String? videoTitle;
  final String? thumbnailUrl;
  final List<Milestone>? milestones;
  final Duration? slideshowInterval;
  final List<String>? textLogs;

  const VideoEditorPage({
    required this.videoUrl,
    this.videoTitle,
    this.thumbnailUrl,
    this.milestones,
    this.slideshowInterval,
    this.textLogs,
    super.key,
  });

  @override
  State<VideoEditorPage> createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends State<VideoEditorPage>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  List<String>? _textLogs;
  ChewieController? _chewieController;

  bool _isInitialized = false;
  bool _hasError = false;
  bool _isDownloading = false;
  bool _isReRendering = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  File? _selectedMusicFile;
  String? _selectedMusicUrl;
  late String _currentVideoUrl;

  // Active tool
  String? _activeTool;

  // Theme colors
  static const Color _darkBg = Color(0xFF0A0A0A);
  static const Color _surfaceColor = Color(0xFF1A1A1A);
  static const Color _cardColor = Color(0xFF202020);

  @override
  void initState() {
    super.initState();
    _currentVideoUrl = widget.videoUrl;
    _textLogs = widget.textLogs;
    _loadCachedMusicVideo();
  }

  // ======================
  // MUSIC VIDEO CACHE MANAGEMENT
  // ======================

  String _getMusicVideoCacheKey() {
    return 'music_video_${widget.videoUrl.hashCode}';
  }

  String _getMusicVideoTextLogsCacheKey() {
    return 'music_video_logs_${widget.videoUrl.hashCode}';
  }

  Future<void> _loadCachedMusicVideo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getMusicVideoCacheKey();
      final textLogsCacheKey = _getMusicVideoTextLogsCacheKey();

      print('🎵 Checking for cached music-enhanced video...');

      final cachedMusicVideoUrl = prefs.getString(cacheKey);
      final cachedLogsJson = prefs.getString(textLogsCacheKey);

      if (cachedMusicVideoUrl != null && cachedMusicVideoUrl.isNotEmpty) {
        print('✅ Found cached music-enhanced video!');

        if (cachedLogsJson != null) {
          try {
            _textLogs = List<String>.from(jsonDecode(cachedLogsJson));
            print('📝 Loaded ${_textLogs?.length} cached text logs');
          } catch (e) {
            print('⚠️ Failed to decode cached text logs: $e');
          }
        }

        setState(() {
          _currentVideoUrl = cachedMusicVideoUrl;
        });

        await _initializeVideo();

        if (mounted) {
          _showSnackBar('🎵 Loaded video with your music');
        }
      } else {
        print('ℹ️ No cached music-enhanced video found, using original');
        await _initializeVideo();
      }
    } catch (e) {
      print('❌ Error loading cached music video: $e');
      await _initializeVideo();
    }
  }

  Future<void> _saveMusicVideoCache(String musicVideoUrl, List<String> textLogs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getMusicVideoCacheKey();
      final textLogsCacheKey = _getMusicVideoTextLogsCacheKey();

      await prefs.setString(cacheKey, musicVideoUrl);
      await prefs.setString(textLogsCacheKey, jsonEncode(textLogs));

      print('✅ Cached music-enhanced video URL');
      print('   Original video: ${widget.videoUrl}');
      print('   Music video: $musicVideoUrl');
    } catch (e) {
      print('❌ Error saving music video cache: $e');
    }
  }

  Future<void> _clearMusicVideoCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getMusicVideoCacheKey();
      final textLogsCacheKey = _getMusicVideoTextLogsCacheKey();

      await prefs.remove(cacheKey);
      await prefs.remove(textLogsCacheKey);

      print('✅ Cleared music video cache');
    } catch (e) {
      print('❌ Error clearing music video cache: $e');
    }
  }

  Future<void> _initializeVideo() async {
    await _initializeVideoWithUrl(_currentVideoUrl, autoPlay: false);
  }

  Future<bool> _requestAudioPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.audio.request();

        if (status.isDenied) {
          final shouldOpenSettings = await _showPermissionExplanationDialog(
            'Audio Access Required',
            'This app needs access to your audio files to add music to your video.',
          );
          if (shouldOpenSettings) {
            await openAppSettings();
          }
          return false;
        }

        if (status.isPermanentlyDenied) {
          await openAppSettings();
          return false;
        }

        return status.isGranted;
      } else {
        final status = await Permission.storage.request();

        if (status.isDenied) {
          final shouldOpenSettings = await _showPermissionExplanationDialog(
            'Storage Access Required',
            'This app needs storage access to select music files.',
          );
          if (shouldOpenSettings) {
            await openAppSettings();
          }
          return false;
        }

        if (status.isPermanentlyDenied) {
          await openAppSettings();
          return false;
        }

        return status.isGranted;
      }
    }
    return true;
  }

  Future<bool> _showPermissionExplanationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Open Settings', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _initializeVideoWithUrl(String videoUrl,
      {bool autoPlay = false}) async {
    try {
      if (mounted) {
        setState(() {
          _hasError = false;
          _isInitialized = false;
        });
      }

      try {
        _videoController.removeListener(_videoListener);
      } catch (_) {}
      try {
        await _videoController.pause();
      } catch (_) {}
      try {
        _videoController.dispose();
      } catch (_) {}
      try {
        _chewieController?.dispose();
      } catch (_) {}

      _currentVideoUrl = videoUrl;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: autoPlay,
        looping: false,
        allowFullScreen: false,
        allowMuting: true,
        showControls: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.secondary,
          handleColor: AppColors.secondary,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.grey.shade700,
        ),
        placeholder: Container(color: _darkBg),
      );

      _videoController.addListener(_videoListener);

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    if (!_videoController.value.isInitialized) return;
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
      } else {
        _videoController.play();
      }
    });
  }

  // ============================================================================
  // MUSIC SELECTION
  // ============================================================================

  Future<void> _removeMusicFromVideo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Music?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will restore the original video without background music.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _clearMusicVideoCache();

      setState(() {
        _currentVideoUrl = widget.videoUrl;
        _textLogs = widget.textLogs;
      });

      await _initializeVideoWithUrl(widget.videoUrl, autoPlay: true);
      _showSnackBar('✅ Music removed, original video restored');
    } catch (e) {
      _showSnackBar('Failed to remove music: ${e.toString()}');
    }
  }

  Future<void> _addMusicToVideo() async {
    setState(() => _activeTool = 'music');

    if (widget.milestones == null || widget.milestones!.isEmpty) {
      _showSnackBar('Cannot add music: No milestone data available');
      return;
    }

    final musicChoice = await _showMusicSelectionDialog();
    if (musicChoice == null) return;

    if (musicChoice == false && _selectedMusicFile == null && _selectedMusicUrl == null) {
      _showSnackBar('No music selected');
      return;
    }

    setState(() => _isReRendering = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final List<File> filesToUpload = [];

      final List<String> textLogsToSend = _textLogs ?? [];

      print('📝 Re-rendering with ${textLogsToSend.length} CACHED text logs');
      if (textLogsToSend.isNotEmpty) {
        print('📄 First log preview: ${textLogsToSend.first.substring(0, textLogsToSend.first.length > 100 ? 100 : textLogsToSend.first.length)}...');
      }

      _showLoadingDialog('Preparing to re-render video with music...');

      for (int i = 0; i < widget.milestones!.length; i++) {
        final m = widget.milestones![i];

        if (m.imagePath != null) {
          final f = File(m.imagePath!);
          if (await f.exists()) {
            filesToUpload.add(f);
            continue;
          }
        }

        if (m.imageUrl != null) {
          try {
            final resp = await http
                .get(Uri.parse(m.imageUrl!), headers: {'Accept': 'image/*'})
                .timeout(const Duration(seconds: 15));

            if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
              final ext = _getImageExtensionFromUrl(m.imageUrl!) ?? '.jpg';
              final saved = File('${tempDir.path}/milestone_${i + 1}$ext');
              await saved.writeAsBytes(resp.bodyBytes);
              filesToUpload.add(saved);
            }
          } catch (e) {
            print('Error downloading image: $e');
          }
        }
      }

      if (filesToUpload.isEmpty) {
        if (mounted) Navigator.pop(context);
        _showSnackBar('No image files available');
        setState(() => _isReRendering = false);
        return;
      }

      while (textLogsToSend.length < filesToUpload.length) {
        textLogsToSend.add('');
      }

      if (mounted) {
        Navigator.pop(context);
        _showLoadingDialog('Re-rendering video with music and original text logs...');
      }

      final response = await ApiService.generateVideo(
        images: filesToUpload,
        notes: textLogsToSend,
        musicFile: _selectedMusicFile,
        musicUrl: _selectedMusicUrl,
        durationPerImage: widget.slideshowInterval?.inSeconds ?? 2,
      );

      String? renderId;
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map) {
          final responseObj = data['response'];
          if (responseObj is Map && responseObj['id'] != null) {
            renderId = responseObj['id'].toString();
          }
        }
      }

      if (renderId == null || renderId.isEmpty) {
        if (mounted) Navigator.pop(context);
        throw Exception('Could not get render ID from response');
      }

      if (mounted) {
        Navigator.pop(context);
        _showRenderProgressDialog(renderId);
      }

      String? resultUrl;
      int maxAttempts = 90;
      int attempt = 0;

      while (attempt < maxAttempts && mounted) {
        await Future.delayed(const Duration(seconds: 3));
        attempt++;

        try {
          final statusResp = await ApiService.checkRenderStatus(renderId);

          if (statusResp['success'] == true) {
            final data = statusResp['data'];
            if (data is Map) {
              final responseObj = data['response'];
              if (responseObj is Map) {
                final status = responseObj['status']?.toString();
                final url = responseObj['url']?.toString();

                if (status == 'done' && url != null && url.isNotEmpty) {
                  resultUrl = url;
                  break;
                } else if (status == 'failed') {
                  final error = responseObj['error'] ?? 'Unknown error';
                  throw Exception('Render failed: $error');
                }
              }
            }
          }
        } catch (e) {
          if (attempt >= maxAttempts - 1) {
            throw Exception('Failed to check render status: $e');
          }
        }
      }

      if (mounted) Navigator.pop(context);

      if (resultUrl != null && resultUrl.isNotEmpty) {
        setState(() => _isReRendering = false);
        _currentVideoUrl = resultUrl;

        // ✅ CRITICAL: Save the music-enhanced video URL to cache for persistence
        await _saveMusicVideoCache(resultUrl, textLogsToSend);

        await _initializeVideoWithUrl(resultUrl, autoPlay: true);
        _showSnackBar('✅ Music added successfully with original text logs!');
      } else {
        _showSnackBar('Render timeout. Please try again.');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showSnackBar('Failed to add music: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isReRendering = false);
    }
  }

  Future<bool?> _showMusicSelectionDialog() async {
    final List<Map<String, String>> freeMusicOptions = [
      {'name': '🎸 Happy Ukulele', 'url': 'https://www.bensound.com/bensound-music/bensound-ukulele.mp3'},
      {'name': '☀️ Summer Vibes', 'url': 'https://www.bensound.com/bensound-music/bensound-summer.mp3'},
      {'name': '🎵 Upbeat Energy', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'},
      {'name': '🎶 Cheerful Melody', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'},
    ];

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Background Music?', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose music for your video:', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.upload_file, color: AppColors.secondary),
                  title: const Text('Upload Music File', style: TextStyle(color: Colors.white)),
                  subtitle: _selectedMusicFile != null
                      ? Text(_selectedMusicFile!.path.split('/').last,
                      style: TextStyle(fontSize: 12, color:AppColors.secondary))
                      : const Text('MP3, WAV, M4A, AAC', style: TextStyle(color: Colors.white60)),
                  trailing: _selectedMusicFile != null
                      ? Icon(Icons.check_circle, color: AppColors.secondary)
                      : null,
                  onTap: () async {
                    final hasPermission = await _requestAudioPermission();
                    if (!hasPermission) {
                      _showSnackBar('Storage permission is required to select music files');
                      return;
                    }

                    try {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.audio,
                        allowMultiple: false,
                      );

                      if (result != null && result.files.single.path != null) {
                        setState(() {
                          _selectedMusicFile = File(result.files.single.path!);
                          _selectedMusicUrl = null;
                        });
                        Navigator.pop(context, true);
                        _showSnackBar('🎵 Music file selected: ${result.files.single.name}');
                      }
                    } catch (e) {
                      _showSnackBar('Error selecting file: $e');
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Or choose free music:', style: TextStyle(fontSize: 14, color: Colors.white60)),
              const SizedBox(height: 8),
              ...freeMusicOptions.map((music) {
                final isSelected = _selectedMusicUrl == music['url'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.secondary.withOpacity(0.1) : _surfaceColor,
                    border: Border.all(color: isSelected ? AppColors.secondary : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.music_note,
                      color: isSelected ? AppColors.secondary : Colors.white60,
                    ),
                    title: Text(music['name']!,
                        style: TextStyle(
                            color: isSelected ? AppColors.secondary : Colors.white,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                    onTap: () {
                      setState(() {
                        _selectedMusicUrl = music['url'];
                        _selectedMusicFile = null;
                      });
                      Navigator.pop(context, true);
                      _showSnackBar('🎵 Selected: ${music['name']}');
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedMusicFile = null;
                _selectedMusicUrl = null;
              });
              Navigator.pop(context, false);
            },
            child: const Text('No Music', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // DOWNLOAD & SHARE
  // ============================================================================
  Future<void> _downloadVideo() async {
    if (_isDownloading) return;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        PermissionStatus status;

        if (androidInfo.version.sdkInt >= 33) {
          status = await Permission.videos.request();
        } else {
          status = await Permission.storage.request();
        }

        if (!status.isGranted) {
          _showSnackBar('Storage permission is required to save video to gallery');
          return;
        }
      }

      setState(() => _isDownloading = true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Downloading Video', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: _surfaceColor,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 20),
                  Text('${(_downloadProgress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  const Text('Saving to gallery...', style: TextStyle(fontSize: 12, color: Colors.white60)),
                ],
              ),
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final fileName = 'milestone_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final savePath = '${tempDir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        _currentVideoUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      await Gal.putVideo(savePath, album: 'Milestones');

      if (mounted) Navigator.pop(context);

      _showSuccessDialog('Download Complete! 🎉', 'Video saved to your gallery successfully!',
          'You can find it in your Photos/Videos app.');

      try {
        final file = File(savePath);
        if (await file.exists()) await file.delete();
      } catch (e) {}
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showSnackBar('Download failed: ${e.toString()}');
    } finally {
      setState(() {
        _downloadProgress = 0.0;
        _isDownloading = false;
      });
    }
  }

  Future<void> _shareVideo() async {
    try {
      _showSnackBar('Preparing video to share...');

      final tempDir = await getTemporaryDirectory();
      final fileName = 'milestone_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final savePath = '${tempDir.path}/$fileName';

      final dio = Dio();
      await dio.download(_currentVideoUrl, savePath);

      final result = await Share.shareXFiles(
        [XFile(savePath)],
        text: 'Check out my milestone journey! 🎉',
        subject: 'My Milestone Journey Video',
      );

      if (result.status == ShareResultStatus.success) {
        _showSnackBar('Video shared successfully! ✅');
      }

      Future.delayed(const Duration(seconds: 3), () async {
        try {
          final file = File(savePath);
          if (await file.exists()) await file.delete();
        } catch (e) {}
      });
    } catch (e) {
      _showSnackBar('Share failed: ${e.toString()}');
      try {
        await Share.share(
          'Check out my milestone journey video: $_currentVideoUrl',
          subject: 'My Milestone Journey Video',
        );
      } catch (fallbackError) {}
    }
  }

  Future<void> _shareVideoWithOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Video',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Share Video File', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Share to Facebook, WhatsApp, etc.', style: TextStyle(color: Colors.white60)),
              onTap: () {
                Navigator.pop(context);
                _shareVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.green),
              title: const Text('Share Video Link', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Copy link or share URL', style: TextStyle(color: Colors.white60)),
              onTap: () async {
                Navigator.pop(context);
                await Share.share(
                  'Check out my milestone journey video: $_currentVideoUrl',
                  subject: 'My Milestone Journey Video',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.orange),
              title: const Text('Copy Link', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Copy video URL to clipboard', style: TextStyle(color: Colors.white60)),
              onTap: () async {
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: _currentVideoUrl));
                _showSnackBar('Video link copied to clipboard! 📋');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================
  String? _getImageExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final segments = path.split('/');
      if (segments.isNotEmpty) {
        final fileName = segments.last.split('?').first;
        if (fileName.contains('.')) {
          return '.${fileName.split('.').last}';
        }
      }
    } catch (e) {}
    return null;
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FitCheckLoader(),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenderProgressDialog(String renderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Creating Your Video', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FitCheckLoader(),
              const SizedBox(height: 20),
              const Text('Please wait while we process your video...',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message, String details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color:AppColors.secondary, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
            const SizedBox(height: 16),
            Text(details, style: const TextStyle(fontSize: 14, color: Colors.white60)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    try {
      _videoController.removeListener(_videoListener);
    } catch (_) {}
    try {
      _videoController.dispose();
    } catch (_) {}
    try {
      _chewieController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  // ============================================================================
  // BUILD UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildVideoSection()),
            _buildGooglePhotosTimeline(),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    // Check if currently showing music-enhanced video
    final hasMusic = _currentVideoUrl != widget.videoUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Spacer(),
          // Music indicator badge
          if (hasMusic)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.music_note, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Music',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (_isInitialized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatDuration(_videoController.value.position) +
                    ' / ' +
                    _formatDuration(_videoController.value.duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    if (_hasError) return _buildErrorWidget();
    if (!_isInitialized) return _buildLoadingWidget();

    return Center(
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: AspectRatio(
          aspectRatio: _videoController.value.aspectRatio,
          child: Stack(
            children: [
              _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : Container(color: Colors.black),
              Center(
                child: AnimatedOpacity(
                  opacity: _videoController.value.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    child: const Icon(Icons.play_arrow, size: 48, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGooglePhotosTimeline() {
    final milestones = widget.milestones ?? [];
    final videoDuration = _isInitialized ? _videoController.value.duration : Duration.zero;
    final currentPosition = _isInitialized ? _videoController.value.position : Duration.zero;
    final slideshowDuration = widget.slideshowInterval ?? const Duration(seconds: 2);

    const double thumbnailWidth = 80.0;
    const double thumbnailGap = 4.0;
    const double horizontalPadding = 8.0;

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: milestones.isEmpty
                ? Center(
              child: Text(
                'No milestone photos',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
            )
                : Stack(
              children: [
                ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: horizontalPadding, top: 8, bottom: 8),
                  itemCount: milestones.length,
                  itemBuilder: (context, index) {
                    final milestone = milestones[index];
                    final startTime = slideshowDuration * index;
                    final endTime = slideshowDuration * (index + 1);
                    final isActive = currentPosition >= startTime && currentPosition < endTime;

                    return GestureDetector(
                      onTap: () => _videoController.seekTo(startTime),
                      child: Container(
                        width: thumbnailWidth,
                        margin: EdgeInsets.only(right: index < milestones.length - 1 ? thumbnailGap : 0),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive ? AppColors.secondary : Colors.white24,
                            width: isActive ? 3 : 1.5,
                          ),
                          boxShadow: isActive
                              ? [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                              : null,
                          image: milestone.imageUrl != null
                              ? DecorationImage(
                            image: NetworkImage(milestone.imageUrl!),
                            fit: BoxFit.cover,
                          )
                              : milestone.imagePath != null
                              ? DecorationImage(
                            image: FileImage(File(milestone.imagePath!)),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: milestone.imageUrl == null && milestone.imagePath == null
                            ? Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.white.withOpacity(0.3),
                            size: 32,
                          ),
                        )
                            : null,
                      ),
                    );
                  },
                ),
                if (_isInitialized && videoDuration.inMilliseconds > 0 && milestones.isNotEmpty)
                  Positioned(
                    left: horizontalPadding +
                        (currentPosition.inMilliseconds / videoDuration.inMilliseconds) *
                            (milestones.length * thumbnailWidth + (milestones.length - 1) * thumbnailGap),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    // Check if currently showing music-enhanced video
    final hasMusic = _currentVideoUrl != widget.videoUrl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Music button (Add or Remove)
          Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: IconButton(
              icon: Icon(
                hasMusic ? Icons.music_off : Icons.music_note,
                color: Colors.white,
              ),
              onPressed: hasMusic ? _removeMusicFromVideo : _addMusicToVideo,
              tooltip: hasMusic ? 'Remove Music' : 'Add Music',
            ),
          ),
          const SizedBox(width: 8),
          // Share button
          Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareVideoWithOptions,
              tooltip: 'Share',
            ),
          ),
          const SizedBox(width: 12),
          // Save button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _downloadVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FitCheckLoader(),
          const SizedBox(height: 24),
          const Text('Loading video...', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
          const SizedBox(height: 24),
          const Text('Failed to load video', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _initializeVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
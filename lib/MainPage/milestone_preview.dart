import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/services/milestone_service.dart';


class MilestonePreviewPage extends StatefulWidget {
  final List<Milestone> milestones;
  final int initialIndex;
  final VoidCallback? onMilestonesChanged;
  final String challengeId;

  const MilestonePreviewPage({
    super.key,
    required this.milestones,
    this.initialIndex = 0,
    this.onMilestonesChanged,
    required this.challengeId,
  });

  @override
  State<MilestonePreviewPage> createState() => _MilestonePreviewPageState();
}

class _MilestonePreviewPageState extends State<MilestonePreviewPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isSlideshow = false;
  bool _isExporting = false;
  Duration _slideshowInterval = const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _stopSlideshow();
    _pageController.dispose();
    super.dispose();
  }

  void _startSlideshow() {
    if (_isSlideshow) return;

    setState(() {
      _isSlideshow = true;
    });

    _runSlideshow();
  }

  void _runSlideshow() async {
    while (_isSlideshow && mounted) {
      await Future.delayed(_slideshowInterval);
      if (_isSlideshow && mounted) {
        int nextIndex = (_currentIndex + 1) % widget.milestones.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _stopSlideshow() {
    setState(() {
      _isSlideshow = false;
    });
  }

  void _toggleSlideshow() {
    if (_isSlideshow) {
      _stopSlideshow();
    } else {
      _startSlideshow();
    }
  }

  Future<void> _exportMilestones() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Use app's cache directory (no permissions needed)
      final directory = await getTemporaryDirectory();

      // Create a milestone export folder with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final String exportPath = '${directory.path}/MilestoneExport_$timestamp';
      final exportDir = Directory(exportPath);
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      List<XFile> exportedFiles = [];

      // Copy all milestone images to export folder
      for (int i = 0; i < widget.milestones.length; i++) {
        final milestone = widget.milestones[i];
        final originalFile = milestone.imagePath != null ? File(milestone.imagePath!) : null;

        if (originalFile != null && await originalFile.exists()) {
          final date = milestone.date;
          final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(date);
          final fileName = 'milestone_${i + 1}_$dateStr.jpg';
          final newPath = '$exportPath/$fileName';

          // Copy file to temp directory
          await originalFile.copy(newPath);
          exportedFiles.add(XFile(newPath));
        }
      }

      // Create a summary text file
      final summaryFile = File('$exportPath/milestone_summary.txt');
      StringBuffer summary = StringBuffer();
      summary.writeln('=== MILESTONE JOURNEY EXPORT ===\n');
      summary.writeln('Export Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}\n');
      summary.writeln('Total Milestones: ${widget.milestones.length}\n');

      for (int i = 0; i < widget.milestones.length; i++) {
        final milestone = widget.milestones[i];
        final date = milestone.date;
        final note = milestone.notes ?? '';

        summary.writeln('--- Milestone ${i + 1} ---');
        summary.writeln('Date: ${DateFormat('MMM d, yyyy - HH:mm').format(date)}');
        if (note.isNotEmpty) {
          summary.writeln('Note: $note');
        }
        summary.writeln('File: milestone_${i + 1}_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(date)}.jpg');
        summary.writeln('');
      }

      await summaryFile.writeAsString(summary.toString());
      exportedFiles.add(XFile(summaryFile.path));

      // Share the exported files
      if (exportedFiles.isNotEmpty) {
        // For single file sharing (works better on most devices)
        if (exportedFiles.length == 1) {
          await Share.shareXFiles(
            [exportedFiles.first],
            text: 'My Milestone Journey',
            subject: 'Milestone Journey Export',
          );
        } else {
          // For multiple files, share them one by one or as a batch
          await Share.shareXFiles(
            exportedFiles,
            text: 'My Milestone Journey - ${widget.milestones.length} milestones',
            subject: 'Milestone Journey Export',
          );
        }

        _showSnackBar('Successfully exported ${widget.milestones.length} milestones!');
      } else {
        _showSnackBar('No images found to export');
      }

    } catch (e) {
      _showSnackBar('Export failed: ${e.toString()}');
      print('Export error: $e'); // For debugging
    }

    setState(() {
      _isExporting = false;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSlideshowSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Slideshow Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Slide Interval',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                _buildIntervalChip(const Duration(seconds: 1), '1s'),
                _buildIntervalChip(const Duration(seconds: 2), '2s'),
                _buildIntervalChip(const Duration(seconds: 3), '3s'),
                _buildIntervalChip(const Duration(seconds: 5), '5s'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startSlideshow();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Start Slideshow',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalChip(Duration duration, String label) {
    bool isSelected = _slideshowInterval == duration;
    return GestureDetector(
      onTap: () {
        setState(() {
          _slideshowInterval = duration;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final milestones = widget.milestones;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${_currentIndex + 1} of ${milestones.length} · "
              "${DateFormat("MMM d, yyyy").format(milestones[_currentIndex].date)}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          // Slideshow button
          IconButton(
            icon: Icon(
              _isSlideshow ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _isSlideshow ? _stopSlideshow : () => _showSlideshowSettings(),
          ),
          // Burger menu with options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_image',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Change Image'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_image',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete Image', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share, size: 20),
                    const SizedBox(width: 12),
                    Text(_isExporting ? 'Exporting...' : 'Export All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: milestones.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                return Stack(
                  children: [
                    Center(
                      child: milestone.imageUrl != null
                        ? Image.network(
                            milestone.imageUrl!,
                            fit: BoxFit.contain,
                          )
                        : milestone.imagePath != null
                          ? Image.file(
                              File(milestone.imagePath!),
                              fit: BoxFit.contain,
                            )
                          : const Icon(Icons.image_not_supported, size: 100),
                    ),
                    // Show slideshow indicator
                    if (_isSlideshow)
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.slideshow,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_slideshowInterval.inSeconds}s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Show note if available
                    if (milestone.notes != null && milestone.notes!.isNotEmpty)
                      Positioned(
                        bottom: 110,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            milestone.notes!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: milestones.length,
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                return GestureDetector(
                  onTap: () {
                    _pageController.jumpToPage(index);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _currentIndex == index
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageWidget(milestone),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    if (_isExporting && action != 'export') return; // Prevent actions during export

    switch (action) {
      case 'change_image':
        _changeCurrentImage();
        break;
      case 'delete_image':
        _deleteCurrentImage();
        break;
      case 'export':
        _exportMilestones();
        break;
    }
  }

  void _changeCurrentImage() async {
    if (widget.milestones.isEmpty) return;

    final milestone = widget.milestones[_currentIndex];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _pickImageForChange(ImageSource.camera, milestone),
                ),
                _buildImageSourceButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _pickImageForChange(ImageSource.gallery, milestone),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  void _pickImageForChange(ImageSource source, Milestone milestone) async {
    Navigator.pop(context); // Close bottom sheet

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

      if (pickedFile != null) {
        // Show loading indicator
        setState(() => _isExporting = true);

        // Update milestone with new image
        final updatedMilestone = milestone.copyWith(
          imagePath: pickedFile.path,
          updatedAt: DateTime.now(),
        );

        // Save to Firebase with new image
        final success = await MilestoneService.updateMilestone(
          updatedMilestone,
          challengeId: widget.challengeId,
          newImageFile: File(pickedFile.path),
        );

        if (success) {
          // Update local list
          setState(() {
            widget.milestones[_currentIndex] = updatedMilestone;
          });

          // Notify parent to refresh
          widget.onMilestonesChanged?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _deleteCurrentImage() {
    if (widget.milestones.isEmpty) return;

    final milestone = widget.milestones[_currentIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this milestone image? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _confirmDelete(milestone),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Milestone milestone) async {
    Navigator.pop(context); // Close dialog

    try {
      setState(() => _isExporting = true);

      // Delete from Firebase
      final success = await MilestoneService.deleteMilestone(milestone.id, challengeId: widget.challengeId);

      if (success) {
        // Remove from local list
        setState(() {
          final index = _currentIndex;
          widget.milestones.removeAt(index);

          // Adjust current index if needed
          if (widget.milestones.isEmpty) {
            Navigator.pop(context); // Close preview if no more images
            return;
          } else if (index >= widget.milestones.length) {
            _currentIndex = widget.milestones.length - 1;
            _pageController.animateToPage(
              _currentIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });

        // Notify parent to refresh
        widget.onMilestonesChanged?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Widget _buildImageWidget(Milestone milestone) {
    if (milestone.imageUrl != null) {
      return Image.network(
        milestone.imageUrl!,
        width: 60,
        height: 80,
        fit: BoxFit.cover,
      );
    } else if (milestone.imagePath != null) {
      return Image.file(
        File(milestone.imagePath!),
        width: 60,
        height: 80,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        width: 60,
        height: 80,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported),
      );
    }
  }
}
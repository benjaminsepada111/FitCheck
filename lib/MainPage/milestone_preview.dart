import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MilestonePreviewPage extends StatefulWidget {
  final List<Map<String, dynamic>> milestones;
  final int initialIndex;

  const MilestonePreviewPage({
    super.key,
    required this.milestones,
    this.initialIndex = 0,
  });

  @override
  State<MilestonePreviewPage> createState() => _MilestonePreviewPageState();
}

class _MilestonePreviewPageState extends State<MilestonePreviewPage> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
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
              "${DateFormat("MMM d, yyyy").format(milestones[_currentIndex]["date"])}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            onPressed: () {
              // TODO: implement slideshow autoplay
            },
          ),
          TextButton.icon(
            onPressed: () {
              // TODO: implement export feature
            },
            icon: const Icon(Icons.ios_share, color: Colors.white),
            label: const Text("EXPORT", style: TextStyle(color: Colors.white)),
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
                return Center(
                  child: Image.file(
                    File(milestone["file"] as String), // 👈 Fixed: Create File from String path
                    fit: BoxFit.contain,
                  ),
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
                      child: Image.file(
                        File(milestone["file"] as String), // 👈 Fixed: Create File from String path
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
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
}
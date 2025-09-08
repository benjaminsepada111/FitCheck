import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Slide5 extends StatefulWidget {
  const Slide5({super.key});

  @override
  State<Slide5> createState() => _Slide5State();
}

class _Slide5State extends State<Slide5> {
  int selectedHeight = 165;

  @override
  Widget build(BuildContext context) {
    return HeightSelectionPage(
      selectedHeight: selectedHeight,
      onHeightChanged: (value) {
        setState(() {
          selectedHeight = value;
        });
      },
    );
  }
}

class HeightSelectionPage extends StatefulWidget {
  final int selectedHeight;
  final ValueChanged<int> onHeightChanged;

  const HeightSelectionPage({
    super.key,
    required this.selectedHeight,
    required this.onHeightChanged,
  });

  @override
  State<HeightSelectionPage> createState() => _HeightSelectionPageState();
}

class _HeightSelectionPageState extends State<HeightSelectionPage> {
  late FixedExtentScrollController _scrollController;
  late FixedExtentScrollController _labelsController;

  @override
  void initState() {
    super.initState();
    int initialIndex = widget.selectedHeight - 100;
    _scrollController = FixedExtentScrollController(initialItem: initialIndex);
    _labelsController = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _labelsController.dispose();
    super.dispose();
  }

  void _onScrollChanged(int index) {
    int newHeight = 100 + index;
    if (newHeight >= 100 && newHeight <= 220) {
      HapticFeedback.selectionClick();
      widget.onHeightChanged(newHeight);

      if (_labelsController.selectedItem != index) {
        _labelsController.jumpToItem(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "Height",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Enter your height in cm.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Selected height
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${widget.selectedHeight}",
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  "cm",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Labels
                  SizedBox(
                    width: 60,
                    height: 300,
                    child: ListWheelScrollView.useDelegate(
                      controller: _labelsController,
                      itemExtent: 28,
                      physics: const NeverScrollableScrollPhysics(),
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, index) {
                          int height = 100 + index;
                          bool isSelected = height == widget.selectedHeight;
                          bool showLabel = height % 5 == 0;

                          return showLabel
                              ? Text(
                            height.toString(),
                            style: TextStyle(
                              fontSize: isSelected ? 22 : 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey[500],
                            ),
                          )
                              : const SizedBox();
                        },
                        childCount: 121,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Ruler
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        width: 100,
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListWheelScrollView.useDelegate(
                          controller: _scrollController,
                          itemExtent: 20,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: _onScrollChanged,
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (context, index) {
                              int height = 100 + index;
                              bool isMainMark = height % 10 == 0;
                              bool isSubMark = height % 5 == 0;
                              bool isSelected =
                                  height == widget.selectedHeight;

                              double tickWidth;
                              Color tickColor;

                              if (isSelected && isMainMark) {
                                tickWidth = 60;
                                tickColor = Colors.black;
                              } else if (isMainMark) {
                                tickWidth = 50;
                                tickColor = Colors.black87;
                              } else if (isSubMark) {
                                tickWidth = 35;
                                tickColor = Colors.grey[700]!;
                              } else {
                                tickWidth = 25;
                                tickColor = Colors.grey[500]!;
                              }

                              return Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: tickWidth,
                                  height: 2,
                                  color: tickColor,
                                ),
                              );
                            },
                            childCount: 121,
                          ),
                        ),
                      ),

                      // Arrow indicator
                      Positioned(
                        left: 105,
                        child: SvgPicture.asset(
                          "assets/icons/arrow_left.svg",
                          height: 30,
                          width: 30,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

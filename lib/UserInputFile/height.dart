import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/color/colors.dart';

class HeightSelectorPage extends StatefulWidget {
  const HeightSelectorPage({super.key});

  @override
  State<HeightSelectorPage> createState() => _HeightSelectorPageState();
}

class _HeightSelectorPageState extends State<HeightSelectorPage> {
  int selectedHeight = 165;

  void _onHeightChanged(int newHeight) {
    setState(() {
      selectedHeight = newHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            const Text(
              "Height",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Enter your height in cm.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 20),
            // Selected height
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  selectedHeight.toString(),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  "cm",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Number slider + vertical ruler with compressed spacing
            Expanded(
              child: Row(
                children: [
                  // Add left margin to compress number slider
                  const SizedBox(width: 16),

                  // Number slider - reduced flex to compress it
                  Expanded(
                    flex: 3,
                    child: HeightNumberSlider(
                      selectedHeight: selectedHeight,
                      onHeightChanged: _onHeightChanged,
                    ),
                  ),

                  // Minimal spacing before arrow
                  const SizedBox(width: 8),

                  // Arrow indicator - moved closer to slider
                  Transform.rotate(
                    angle: -90 * 3.1415926535 / 180,
                    child: SvgPicture.asset(
                      "assets/icons/weight_arrow.svg",
                      width: 20, // Made even smaller
                      color: AppColors.secondary[700],
                    ),
                  ),

                  // Very minimal spacing between arrow and ruler
                  const SizedBox(width: 2),

                  // Vertical ruler - positioned more to the left
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      width: 90, // Made narrower
                      decoration: BoxDecoration(

                        border: Border.all(color: AppColors.secondary[700]!, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4), // Further reduced horizontal padding
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ListView.builder(
                              scrollDirection: Axis.vertical,
                              itemCount: 200,
                              itemBuilder: (context, index) {
                                bool isMajorTick = index % 10 == 0;
                                bool isHalfTick = index % 5 == 0;

                                double lineWidth = isMajorTick
                                    ? 40 // Further reduced
                                    : isHalfTick
                                    ? 28 // Further reduced
                                    : 16; // Further reduced

                                return Container(
                                  height: 12,
                                  alignment: Alignment.center,
                                  child: Container(
                                    height: 2,
                                    width: lineWidth,
                                    color: Colors.black54,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Larger right margin to balance the layout
                  const SizedBox(width: 50),
                ],
              ),
            ),


          ],
        ),
      ),
    );
  }
}

class HeightNumberSlider extends StatefulWidget {
  final int selectedHeight;
  final ValueChanged<int> onHeightChanged;

  const HeightNumberSlider({
    super.key,
    required this.selectedHeight,
    required this.onHeightChanged,
  });

  @override
  State<HeightNumberSlider> createState() => _HeightNumberSliderState();
}

class _HeightNumberSliderState extends State<HeightNumberSlider> {
  late FixedExtentScrollController _scrollController;

  final int minHeight = 100;
  final int maxHeight = 220;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(
      initialItem: widget.selectedHeight - minHeight,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _scrollController,
      itemExtent: 50,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) {
        int newHeight = minHeight + index;
        widget.onHeightChanged(newHeight);
        HapticFeedback.selectionClick();
      },
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          int height = minHeight + index;
          bool isSelected = height == widget.selectedHeight;

          return Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  height.toString(),
                  style: TextStyle(
                    fontSize: isSelected ? 36 : 22,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.grey,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  const Text(
                    "cm",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        childCount: maxHeight - minHeight + 1,
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

class WeightSelectorPage extends StatefulWidget {
  const WeightSelectorPage({Key? key}) : super(key: key);

  @override
  State<WeightSelectorPage> createState() => _WeightSelectorPageState();
}

class _WeightSelectorPageState extends State<WeightSelectorPage> {
  int selectedWeight = 75;

  void _onWeightChanged(int newWeight) {
    setState(() {
      selectedWeight = newWeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: SafeArea(
        child: Column(
          children: [
            // Removed header with back button 👋

            Expanded(
              child: WeightSelectionPage(
                selectedWeight: selectedWeight,
                onWeightChanged: _onWeightChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeightSelectionPage extends StatefulWidget {
  final int selectedWeight;
  final ValueChanged<int> onWeightChanged;

  const WeightSelectionPage({
    super.key,
    required this.selectedWeight,
    required this.onWeightChanged,
  });

  @override
  State<WeightSelectionPage> createState() => _WeightSelectionPageState();
}

class _WeightSelectionPageState extends State<WeightSelectionPage> {
  late PageController _pageController;
  late ScrollController _rulerController;

  final int minWeight = 40;
  final int maxWeight = 120;
  bool _isUpdatingFromRuler = false;

  @override
  void initState() {
    super.initState();
    int initialIndex = widget.selectedWeight - minWeight;
    _pageController = PageController(
      initialPage: initialIndex,
      viewportFraction: 0.2,
    );
    _rulerController = ScrollController(
      initialScrollOffset: initialIndex * 40.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rulerController.dispose();
    super.dispose();
  }

  void _onWeightChanged(int index) {
    int newWeight = minWeight + index;
    if (newWeight >= minWeight && newWeight <= maxWeight) {
      HapticFeedback.selectionClick();
      widget.onWeightChanged(newWeight);

      if (!_isUpdatingFromRuler) {
        _rulerController.animateTo(
          index * 40.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _onRulerScroll(double delta) {
    _isUpdatingFromRuler = true;

    double currentOffset = _rulerController.offset;
    double newOffset = currentOffset + delta;

    _rulerController.jumpTo(
      newOffset.clamp(0.0, (maxWeight - minWeight) * 40.0),
    );

    int newIndex = (newOffset / 40.0).round();
    newIndex = newIndex.clamp(0, maxWeight - minWeight);

    int newWeight = minWeight + newIndex;
    if (newWeight != widget.selectedWeight) {
      HapticFeedback.selectionClick();
      widget.onWeightChanged(newWeight);

      _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      _isUpdatingFromRuler = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Center(
          child: Text(
            "How Chonky Are You?",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 90),

        SizedBox(
          height: 80,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onWeightChanged,
            itemCount: maxWeight - minWeight + 1,
            itemBuilder: (context, index) {
              int weight = minWeight + index;
              bool isSelected = weight == widget.selectedWeight;

              return Center(
                child: Text(
                  weight.toString(),
                  style: TextStyle(
                    fontSize: isSelected ? 36 : 29,
                    color: isSelected ? Colors.black87 : Colors.grey[400],
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),
        SvgPicture.asset(
          "assets/icons/arrow_down.svg",
          height: 30,
          width: 30,
        ),
        const SizedBox(height: 20),

        GestureDetector(
          onPanUpdate: (details) {
            _onRulerScroll(-details.delta.dx * 2);
          },
          child: Container(
            height: 90,
            color: Colors.blue[100],
            child: Stack(
              children: [
                ListView.builder(
                  controller: _rulerController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: (maxWeight - minWeight + 1) * 10,
                  itemBuilder: (context, index) {
                    int weightIndex = index ~/ 10;
                    int subIndex = index % 5;
                    int weight = minWeight + weightIndex;

                    bool isMajorTick = subIndex == 0;
                    bool isSelected = weight == widget.selectedWeight && subIndex == 0;

                    double tickHeight;
                    Color tickColor;

                    if (isSelected) {
                      tickHeight = 38;
                      tickColor = Colors.blue[600]!;
                    } else if (isMajorTick) {
                      tickHeight = 40;
                      tickColor = Colors.blue[600]!;
                    } else {
                      tickHeight = 25;
                      tickColor = Colors.blue[400]!;
                    }

                    return Container(
                      width: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 2,
                          height: tickHeight,
                          decoration: BoxDecoration(
                            color: tickColor,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),






        const Spacer(),
      ],
    );
  }
}

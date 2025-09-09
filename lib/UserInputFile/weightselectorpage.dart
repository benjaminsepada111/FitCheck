import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/color/colors.dart';

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
            const SizedBox(height: 30),
            const Text(
              "Weight",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter your current weight in kg.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 40),

            // Selected weight
            Text(
              selectedWeight.toString(),
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const Text(
              "kg",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),

            // Number slider + ruler
            Expanded(
              child: WeightRuler(
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

class WeightRuler extends StatefulWidget {
  final int selectedWeight;
  final ValueChanged<int> onWeightChanged;

  const WeightRuler({
    super.key,
    required this.selectedWeight,
    required this.onWeightChanged,
  });

  @override
  State<WeightRuler> createState() => _WeightRulerState();
}

class _WeightRulerState extends State<WeightRuler> {
  late PageController _pageController;

  final int minWeight = 40;
  final int maxWeight = 120;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.selectedWeight - minWeight,
      viewportFraction: 0.25, // shows neighboring numbers
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Number slider
        SizedBox(
          height: 80,
          child: PageView.builder(
            controller: _pageController,
            itemCount: maxWeight - minWeight + 1,
            onPageChanged: (index) {
              int newWeight = minWeight + index;
              widget.onWeightChanged(newWeight);
              HapticFeedback.selectionClick();
            },
            itemBuilder: (context, index) {
              int weight = minWeight + index;
              bool isSelected = weight == widget.selectedWeight;

              return Center(
                child: Text(
                  weight.toString(),
                  style: TextStyle(
                    fontSize: isSelected ? 36 : 24,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),


        Positioned(
          top: 0,
          bottom: 60,
          child: SvgPicture.asset(
            "assets/icons/weight_arrow.svg",
            height: 20, // adjust size
            color: AppColors.secondary[800], // optional tint
          ),
        ),

        const SizedBox(height: 10),
        // Ruler below the numbers
        Container(
          height: 80,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.secondary[700]!, width: 2),
              bottom: BorderSide(color: AppColors.secondary[700]!, width: 2),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Tick marks
              ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (maxWeight - minWeight + 1) * 10,
                itemBuilder: (context, index) {
                  bool isMajorTick = index % 10 == 0;
                  bool isHalfTick = index % 5 == 0;

                  return Container(
                    width: 8,
                    alignment: Alignment.center,
                    child: Container(
                      width: 2,
                      height: isMajorTick
                          ? 30
                          : isHalfTick
                          ? 20
                          : 12,
                      color: Colors.black54,
                    ),
                  );
                },
              ),

              // Center indicator arrow (SVG)

            ],
          ),
        ),

      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

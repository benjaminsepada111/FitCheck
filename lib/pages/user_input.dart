import 'package:flutter/material.dart';
import '../widgets/page_content_wrapper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import '../main_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const OnboardingCarousel(),
    );
  }
}

class OnboardingCarousel extends StatefulWidget {
  const OnboardingCarousel({super.key});

  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Age, Weight, Height state
  int _selectedAge = 20;
  int _selectedWeight = 75;
  int _selectedHeight = 165;

  @override
  Widget build(BuildContext context) {
    // ✅ define total number of pages here
    final totalPages = 5;

    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ Added AppBar with Back button
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.black),
          onPressed: () {
            if (_currentPage == 0) {
              Navigator.pop(context); // Exit onboarding if on first page
            } else {
              _controller.previousPage(
                // Go to previous page
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          icon: const Icon(Icons.arrow_back, size: 22),
          label: const Text(
            "Back",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      body: Stack(
        children: [
          // PAGES
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(totalPages, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 29 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Colors.blue
                              : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Continue / Finish button

                ],
              ),
            ),
          ),

          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: [
              PageContentWrapper(child: SexSelectionPage()),
              PageContentWrapper(
                child: AgeSelectionPage(
                  selectedAge: _selectedAge,
                  onAgeChanged: (age) {
                    setState(() => _selectedAge = age);
                  },
                ),
              ),
              PageContentWrapper(
                child: WeightSelectionPage(
                  selectedWeight: _selectedWeight,
                  onWeightChanged: (weight) {
                    setState(() => _selectedWeight = weight);
                  },
                ),
              ),
              PageContentWrapper(
                child: HeightSelectionPage(
                  selectedHeight: _selectedHeight,
                  onHeightChanged: (height) {
                    setState(() => _selectedHeight = height);
                  },
                ),
              ),
              const PageContentWrapper(child: ProfileFormPage()),
            ],
          ),

          // ✅ Carousel Indicator + Button (duplicate section in your code)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(totalPages, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 25 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Colors.blue
                              : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blue.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        if (_currentPage < totalPages - 1) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const MainPage()), // your main page
                          );
                        }
                      },

                      child: Text(
                        _currentPage == totalPages - 1 ? "Finish" : "Continue",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🔹 Sex Selection Page
class SexSelectionPage extends StatefulWidget {
  const SexSelectionPage({super.key});

  @override
  State<SexSelectionPage> createState() => _SexSelectionPageState();
}

class _SexSelectionPageState extends State<SexSelectionPage> {
  String? selectedSex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          const Text(
            "What's Your Sex?",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 40),

          // ✅ Now passing IconData
          _buildSexOption("MALE", Icons.male, Colors.blue, "male"),

          const SizedBox(height: 50),

          _buildSexOption("FEMALE", Icons.female, Colors.pink, "female"),
        ],
      ),
    );
  }

  Widget _buildSexOption(
    String label,
    IconData icon,
    Color color,
    String value,
  ) {
    return GestureDetector(
      onTap: () => setState(() => selectedSex = value),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: selectedSex == value ? color : Colors.blueGrey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, size: 70, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔹 Age Selection Page

class AgeSelectionPage extends StatelessWidget {
  final int selectedAge;
  final ValueChanged<int> onAgeChanged;

  const AgeSelectionPage({
    super.key,
    required this.selectedAge,
    required this.onAgeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pageController = PageController(initialPage: selectedAge - 10);

    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),

          // Title
          const Text(
            "How Old Are You?",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 80),

          // Age Display
          Column(
            children: [
              Text(
                selectedAge.toString(),
                style: const TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              // 🔽 Custom SVG arrow
              SvgPicture.asset(
                "assets/icons/arrow_down.svg",
                height: 20,
                width: 20,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ✅ Horizontal Scroll Picker
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 🔹 Blue highlight box
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600.withOpacity(0.5),
                  ),
                ),

                // 🔹 PageView for sliding ages
                PageView.builder(
                  controller: PageController(
                    viewportFraction: 0.28, // ⬅️ controls spacing
                    initialPage: selectedAge - 10,
                  ),
                  itemCount: 91, // ages 10 - 100
                  onPageChanged: (index) {
                    onAgeChanged(index + 10);
                  },
                  itemBuilder: (context, index) {
                    final age = index + 10;
                    final isSelected = age == selectedAge;

                    return Center(
                      child: Text(
                        age.toString(),
                        style: TextStyle(
                          fontSize: isSelected ? 42 : 28, // selected bigger
                          fontWeight: FontWeight.bold, // ✅ always bold
                          color: isSelected ? Colors.white : Colors.black,
                          shadows: isSelected
                              ? [
                                  Shadow(
                                    blurRadius: 8,
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                      ),
                    );
                  },
                ),

                // 🔹 Optional vertical highlight lines
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.5 - 70,
                  child: Container(width: 2, height: 120, color: Colors.blue),
                ),
                Positioned(
                  right: MediaQuery.of(context).size.width * 0.5 - 70,
                  child: Container(width: 2, height: 120, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




// 🔹 Weight Selection Page
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
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                  const Text(
                    'Back',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Use your WeightSelectionPage component
            Expanded(
              child: WeightSelectionPage(
                selectedWeight: selectedWeight,
                onWeightChanged: _onWeightChanged,
              ),
            ),

            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == 2 ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == 2 ? Colors.blue[600] : Colors.blue[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 40),

            // Continue button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    print('Selected weight: $selectedWeight kg');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Weight selected: ${selectedWeight}kg'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
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
  late ScrollController _rulerController; // Added ruler scroll controller

  final int minWeight = 40;
  final int maxWeight = 120;
  bool _isUpdatingFromRuler = false; // Added flag to prevent circular updates

  @override
  void initState() {
    super.initState();
    int initialIndex = widget.selectedWeight - minWeight;
    _pageController = PageController(
      initialPage: initialIndex,
      viewportFraction: 0.2, // Show 5 items at once
    );

    _rulerController = ScrollController(
      initialScrollOffset: initialIndex * 40.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rulerController.dispose(); // Dispose ruler controller
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
    _isUpdatingFromRuler = true; // Set flag to prevent circular updates

    double currentOffset = _rulerController.offset;
    double newOffset = currentOffset + delta;

    _rulerController.jumpTo(newOffset.clamp(0.0, (maxWeight - minWeight) * 40.0));

    // Calculate which weight this corresponds to
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
          height: 50,
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

        GestureDetector(
          onPanUpdate: (details) {
            _onRulerScroll(-details.delta.dx * 2);
          },
          child: Container(
            height: 80,
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

        SvgPicture.asset(
          "assets/icons/arrow_down.svg",
          height: 30,
          width: 30,
        ),
        const SizedBox(height: 10),

        // Current weight display (large)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                widget.selectedWeight.toString(),
                key: ValueKey(widget.selectedWeight),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Text(
                'kg',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),

        const Spacer(),
      ],
    );
  }
}





// 🔹 Height Selection Page
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
        _labelsController.animateToItem(
          index,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "How Tall Are You?",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),

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

            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 300,
                    child: ListWheelScrollView.useDelegate(
                      controller: _labelsController,
                      itemExtent: 28,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: _onScrollChanged,
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, index) {
                          int height = 100 + index;
                          bool isSelected = height == widget.selectedHeight;
                          bool showLabel = height % 5 == 0;

                          return Container(
                            alignment: Alignment.centerRight,
                            child: showLabel
                                ? Text(
                              height.toString(),
                              style: TextStyle(
                                fontSize: isSelected ? 26 : 20,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.black : Colors.grey[500],
                              ),
                            )
                                : const SizedBox(),
                          );
                        },
                        childCount: 121,
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        width: 100,
                        height: 350,
                        decoration: BoxDecoration(
                          color: Colors.blue[100], // Changed from dark blue to light blue like weight selector
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListWheelScrollView.useDelegate(
                          controller: _scrollController,
                          itemExtent: 40,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            if (_labelsController.selectedItem != index) {
                              _labelsController.animateToItem(
                                index,
                                duration: const Duration(milliseconds: 100),
                                curve: Curves.easeOut,
                              );
                            }
                            _onScrollChanged(index);
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (context, index) {
                              int height = 100 + index;
                              bool isMainMark = height % 10 == 0;
                              bool isSubMark = height % 5 == 0;
                              bool isSelected = height == widget.selectedHeight;

                              double tickWidth;
                              Color tickColor;

                              if (isSelected && isMainMark) {
                                tickWidth = 60;
                                tickColor = Colors.blue[600]!;
                              } else if (isMainMark) {
                                tickWidth = 56;
                                tickColor = Colors.blue[600]!;
                              } else if (isSubMark) {
                                tickWidth = 35;
                                tickColor = Colors.blue[400]!;
                              } else {
                                tickWidth = 25;
                                tickColor = Colors.blue[400]!;
                              }

                              return Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: tickWidth,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: tickColor,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              );
                            },
                            childCount: 121,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(left: 110), // adjust here
                        child: SvgPicture.asset(
                          "assets/icons/arrow_left.svg",
                          height: 40,
                          width: 40,
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 150),
          ],
        ),
      ),
    );
  }
}























// 🔹 Profile Form Page (Page 5)
class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final TextEditingController _fullNameController = TextEditingController(
    text: "Benjamin Sepada III",
  );
  final TextEditingController _nicknameController = TextEditingController(
    text: "Benjamin",
  );
  final TextEditingController _emailController = TextEditingController(
    text: "benjaminIII@example.com",
  );
  final TextEditingController _mobileController = TextEditingController(
    text: "+123 567 89000",
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [

          const Text(
            "Fill Your Profile",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),

          // Profile picture with edit button
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(
                radius: 60,
                backgroundImage: AssetImage(
                  "assets/images/welcome_bg.jpg",
                ), // replace with your asset
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
                child: const Icon(Icons.edit, size: 18, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Full Name
          _buildTextField("Full name", _fullNameController),

          const SizedBox(height: 15),

          // Nickname
          _buildTextField("Nickname", _nicknameController),

          const SizedBox(height: 15),

          // Email
          _buildTextField(
            "Email",
            _emailController,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 15),

          // Mobile
          _buildTextField(
            "Mobile Number",
            _mobileController,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.blue,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }
}

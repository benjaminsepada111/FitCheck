import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'weightselectorpage.dart';

class BirthdatePage extends StatefulWidget {
  const BirthdatePage({super.key});

  @override
  State<BirthdatePage> createState() => _BirthdatePageState();
}

class _BirthdatePageState extends State<BirthdatePage> with TickerProviderStateMixin {
  bool _isLoading = false;
  int selectedMonth = 1;
  int selectedDay = 1;
  int selectedYear = 2000;

  final List<int> months = List.generate(12, (i) => i + 1);
  final List<int> days = List.generate(31, (i) => i + 1);
  final List<int> years = List.generate(100, (i) => 2023 - i);

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      _slideController.forward();
    });

    _loadSavedDate();
  }

  Future<void> _loadSavedDate() async {
    final userData = await UserDataService.loadUserData();
    if (userData?.birthDate != null) {
      setState(() {
        selectedYear = userData!.birthDate!.year;
        selectedMonth = userData.birthDate!.month;
        selectedDay = userData.birthDate!.day;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (_isLoading) return;

    // Validate age (must be at least 13)
    if (calculatedAge < 13) {
      _showErrorSnackBar('You must be at least 13 years old to use this app.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final birthDate = DateTime(selectedYear, selectedMonth, selectedDay);
      final success = await UserDataService.updateUserData(birthDate: birthDate);

      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WeightSelectorPage()),
        );
      } else if (mounted) {
        _showErrorSnackBar('Failed to save birth date. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  int get calculatedAge {
    final now = DateTime.now();
    final birthDate = DateTime(selectedYear, selectedMonth, selectedDay);
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              child: Column(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ).createShader(bounds),
                    child: const Text(
                      "Birthday",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    "Enter your date of birth",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.secondary.shade600,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cake_outlined,
                      color: AppColors.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Age: $calculatedAge years",
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            SlideTransition(
              position: _slideAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Month Picker - CORRECT
                    buildPicker(
                      label: "Month",
                      values: months,
                      selectedValue: selectedMonth,
                      onSelected: (val) {
                        setState(() => selectedMonth = val);
                      },
                      displayValue: (val) => monthNames[val - 1],
                    ),

                    // Day Picker - FIXED: was setting selectedMonth
                    buildPicker(
                      label: "Day",
                      values: days,
                      selectedValue: selectedDay,
                      onSelected: (val) {
                        setState(() => selectedDay = val);
                      },
                      displayValue: (val) => val.toString().padLeft(2, '0'),
                    ),

                    // Year Picker - FIXED: was setting selectedMonth
                    buildPicker(
                      label: "Year",
                      values: years,
                      selectedValue: selectedYear,
                      onSelected: (val) {
                        setState(() => selectedYear = val);
                      },
                      displayValue: (val) => val.toString(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.secondary.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.secondary.shade200,
                    width: 1,
                  ),
                ),
                child: Text(
                  "${monthNames[selectedMonth - 1]} ${selectedDay.toString().padLeft(2, '0')}, $selectedYear",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Continue Button
            SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'CONTINUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget buildPicker({
    required String label,
    required List<int> values,
    required int selectedValue,
    required ValueChanged<int> onSelected,
    required String Function(int) displayValue,
  }) {
    final controller = FixedExtentScrollController(
      initialItem: values.indexOf(selectedValue),
    );

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          width: 85,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 55,
                left: 4,
                right: 4,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListWheelScrollView.useDelegate(
                  controller: controller,
                  itemExtent: 40,
                  perspective: 0.002,
                  diameterRatio: 2.0,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    onSelected(values[index]);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      final isSelected = values[index] == selectedValue;

                      return Container(
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style: TextStyle(
                            fontSize: isSelected ? 18 : 16,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.secondary
                                : AppColors.secondary.shade500,
                            letterSpacing: 0.2,
                          ),
                          child: Text(
                            displayValue(values[index]),
                          ),
                        ),
                      );
                    },
                    childCount: values.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
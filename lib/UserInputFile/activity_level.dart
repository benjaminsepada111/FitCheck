import 'package:flutter/material.dart';
import '../color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';

Future<void> _saveActivityLevel(String level) async {
  try {
    await UserDataService.updateUserData(activityLevel: level);
    print('Activity level saved: $level');
  } catch (e) {
    print('Error saving activity level: $e');
  }
}

class ActivityLevelPage extends StatefulWidget {
  const ActivityLevelPage({super.key});

  @override
  State<ActivityLevelPage> createState() => _ActivityLevelPageState();
}

class _ActivityLevelPageState extends State<ActivityLevelPage> with TickerProviderStateMixin {
  String? _selectedLevel;
  late AnimationController _fadeController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> activityLevels = [
    {
      "label": "Sedentary",
      "desc": "Little or no exercise",
      "icon": Icons.chair_outlined,
      "detail": "Office job, minimal physical activity"
    },
    {
      "label": "Light",
      "desc": "Light exercise/sports 1–3 days/week",
      "icon": Icons.directions_walk_outlined,
      "detail": "Walking, light yoga, casual sports"
    },
    {
      "label": "Moderate",
      "desc": "Moderate exercise 3–5 days/week",
      "icon": Icons.directions_run_outlined,
      "detail": "Regular gym, jogging, swimming"
    },
    {
      "label": "Active",
      "desc": "Hard exercise 6–7 days/week",
      "icon": Icons.fitness_center_outlined,
      "detail": "Daily workouts, intensive training"
    },
    {
      "label": "Very Active",
      "desc": "Hard daily exercise or physical job",
      "icon": Icons.sports_outlined,
      "detail": "Athletic training, physical labor"
    },
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _listController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "How active are you?",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Select your typical activity level for accurate calculations",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Enhanced Activity List
          Expanded(
            child: SlideTransition(
              position: _slideAnimation,
              child: ListView.builder(
                itemCount: activityLevels.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final item = activityLevels[index];
                  final isSelected = _selectedLevel == item["label"];

                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200 + (index * 50)),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      elevation: isSelected ? 4 : 1,
                      shadowColor: isSelected
                          ? AppColors.secondary.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() => _selectedLevel = item["label"]);
                          _saveActivityLevel(item["label"]!);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.secondary.withOpacity(0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.secondary.withOpacity(0.4)
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Activity Icon
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.secondary
                                      : AppColors.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item["icon"] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.secondary,
                                  size: 24,
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item["label"]!,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.primary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item["desc"]!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item["detail"]!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Enhanced Radio Button
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: Transform.scale(
                                  scale: 1.1,
                                  child: Radio<String>(
                                    value: item["label"]!,
                                    groupValue: _selectedLevel,
                                    activeColor: AppColors.secondary,
                                    fillColor: MaterialStateProperty.resolveWith(
                                          (states) {
                                        if (states.contains(MaterialState.selected)) {
                                          return AppColors.secondary;
                                        }
                                        return Colors.grey.shade400;
                                      },
                                    ),
                                    onChanged: (value) {
                                      setState(() => _selectedLevel = value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        ],
      ),
    );
  }
}
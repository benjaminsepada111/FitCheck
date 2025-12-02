// Temporary test page for calorie adjustment logic
// TODO: Remove this file before production release

import 'package:flutter/material.dart';
import 'package:capstone_project/services/calorie_calculator.dart';
import 'package:capstone_project/models/user_data.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';

class CalorieAdjustmentTestPage extends StatefulWidget {
  const CalorieAdjustmentTestPage({super.key});

  @override
  State<CalorieAdjustmentTestPage> createState() => _CalorieAdjustmentTestPageState();
}

class _CalorieAdjustmentTestPageState extends State<CalorieAdjustmentTestPage> {
  // User data inputs
  final TextEditingController _ageController = TextEditingController(text: '30');
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _heightController = TextEditingController(text: '170');
  final TextEditingController _previousWeightController = TextEditingController(text: '72');
  final TextEditingController _currentCalorieGoalController = TextEditingController(text: '2000');
  
  String _gender = 'male';
  String _activityLevel = 'lightly_active';
  String _goal = 'lose_fat';
  
  // Results
  Map<String, dynamic>? _result;
  bool _isCalculating = false;

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _previousWeightController.dispose();
    _currentCalorieGoalController.dispose();
    super.dispose();
  }

  void _runTest() {
    setState(() {
      _isCalculating = true;
      _result = null;
    });

    try {
      final age = int.tryParse(_ageController.text) ?? 30;
      final weight = double.tryParse(_weightController.text) ?? 70.0;
      final height = double.tryParse(_heightController.text) ?? 170.0;
      final previousWeight = double.tryParse(_previousWeightController.text) ?? 72.0;
      final currentCalorieGoal = int.tryParse(_currentCalorieGoalController.text) ?? 2000;

      // Create test user data (UserData uses int for weight, so round it)
      final birthDate = DateTime.now().subtract(Duration(days: age * 365));
      final userData = UserData(
        gender: _gender,
        birthDate: birthDate,
        weight: weight.round(), // UserData uses int, so round for storage
        height: height.round(), // UserData uses int, so round for storage
        activityLevel: _activityLevel,
        goal: _goal,
      );

      // Calculate adjustment (use double precision for calculation)
      final result = CalorieCalculator.calculateAdaptiveAdjustment(
        userData: userData,
        currentWeight: weight, // Use double precision
        previousWeight: previousWeight, // Use double precision
        currentCalorieGoal: currentCalorieGoal,
        activityLevel: _activityLevel,
        goal: _goal,
      );

      setState(() {
        _result = result;
        _isCalculating = false;
      });
    } catch (e) {
      setState(() {
        _isCalculating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calorie Adjustment Test'),
        backgroundColor: Colors.blue.shade50,
      ),
      body: SingleChildScrollView(
        padding: r.padding(all: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning banner
            Container(
              padding: r.padding(all: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(r.size(8)),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: r.size(20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Temporary test page - Remove before production',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: r.font(12, min: 10, max: 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ResponsiveGap.vertical(20),

            // Input section
            _buildSection(
              title: 'User Data',
              children: [
                _buildTextField(
                  label: 'Age',
                  controller: _ageController,
                  hint: '30',
                ),
                ResponsiveGap.vertical(12),
                _buildTextField(
                  label: 'Height (cm)',
                  controller: _heightController,
                  hint: '170',
                ),
                ResponsiveGap.vertical(12),
                _buildTextField(
                  label: 'Current Weight (kg)',
                  controller: _weightController,
                  hint: '70.0 (supports decimals)',
                ),
                ResponsiveGap.vertical(12),
                _buildTextField(
                  label: 'Previous Weight (kg)',
                  controller: _previousWeightController,
                  hint: '72.0 (supports decimals)',
                ),
                ResponsiveGap.vertical(12),
                _buildTextField(
                  label: 'Current Calorie Goal (kcal)',
                  controller: _currentCalorieGoalController,
                  hint: '2000',
                ),
                ResponsiveGap.vertical(16),
                _buildDropdown<String>(
                  label: 'Gender',
                  value: _gender,
                  items: const ['male', 'female'],
                  onChanged: (value) => setState(() => _gender = value!),
                ),
                ResponsiveGap.vertical(12),
                _buildDropdown<String>(
                  label: 'Activity Level',
                  value: _activityLevel,
                  items: const [
                    'lightly_active',
                    'active',
                    'very_active',
                    'extra_active',
                  ],
                  onChanged: (value) => setState(() => _activityLevel = value!),
                ),
                ResponsiveGap.vertical(12),
                _buildDropdown<String>(
                  label: 'Goal',
                  value: _goal,
                  items: const [
                    'lose_fat',
                    'maintain_weight',
                    'gain_muscle',
                  ],
                  onChanged: (value) => setState(() => _goal = value!),
                ),
              ],
            ),

            ResponsiveGap.vertical(24),

            // Calculate button
            ElevatedButton(
              onPressed: _isCalculating ? null : _runTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: r.paddingSymmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.size(12)),
                ),
              ),
              child: _isCalculating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Calculate Adjustment',
                      style: TextStyle(
                        fontSize: r.font(16, min: 14, max: 18),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            if (_result != null) ...[
              ResponsiveGap.vertical(24),
              _buildResultsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    final r = context.responsive;
    return Container(
      padding: r.padding(all: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(r.size(12)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: r.font(18, min: 16, max: 20),
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          ResponsiveGap.vertical(12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    final r = context.responsive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: r.font(14, min: 12, max: 16),
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        ResponsiveGap.vertical(4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.size(8)),
            ),
            contentPadding: r.paddingSymmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    final r = context.responsive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: r.font(14, min: 12, max: 16),
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        ResponsiveGap.vertical(4),
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString().replaceAll('_', ' ').toUpperCase()),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.size(8)),
            ),
            contentPadding: r.paddingSymmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    final r = context.responsive;
    if (_result == null) return const SizedBox.shrink();

    final newCalorieGoal = _result!['newCalorieGoal'] as int;
    final adjustment = _result!['adjustment'] as int;
    final interpretation = _result!['interpretation'] as String;
    final reason = _result!['reason'] as String;
    final weightChange = _result!['weightChange'] as double;

    // Calculate weight change percentage
    final previousWeight = double.tryParse(_previousWeightController.text) ?? 72.0;
    final weightChangePercent = (weightChange / previousWeight) * 100;

    return _buildSection(
      title: 'Results',
      children: [
        _buildResultCard(
          label: 'Weight Change',
          value: '${weightChange > 0 ? '+' : ''}${weightChange.toStringAsFixed(3)} kg',
          subtitle: '${weightChangePercent > 0 ? '+' : ''}${weightChangePercent.toStringAsFixed(3)}% of body weight',
          color: weightChange > 0.3
              ? Colors.orange
              : weightChange < -0.3
                  ? Colors.green
                  : Colors.grey,
        ),
        ResponsiveGap.vertical(12),
        _buildResultCard(
          label: 'Current Calorie Goal',
          value: '${int.tryParse(_currentCalorieGoalController.text) ?? 2000} kcal',
          color: Colors.blue,
        ),
        ResponsiveGap.vertical(12),
        _buildResultCard(
          label: 'New Calorie Goal',
          value: '$newCalorieGoal kcal',
          color: Colors.purple,
        ),
        ResponsiveGap.vertical(12),
        _buildResultCard(
          label: 'Adjustment',
          value: '${adjustment > 0 ? '+' : ''}$adjustment kcal',
          subtitle: adjustment == 0
              ? 'No change'
              : adjustment > 0
                  ? 'Increased'
                  : 'Decreased',
          color: adjustment == 0
              ? Colors.grey
              : adjustment > 0
                  ? Colors.green
                  : Colors.red,
        ),
        ResponsiveGap.vertical(12),
        _buildResultCard(
          label: 'Interpretation',
          value: interpretation.replaceAll('_', ' ').toUpperCase(),
          color: Colors.teal,
        ),
        ResponsiveGap.vertical(16),
        Container(
          padding: r.padding(all: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(r.size(8)),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reason:',
                style: TextStyle(
                  fontSize: r.font(14, min: 12, max: 16),
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              ResponsiveGap.vertical(4),
              Text(
                reason,
                style: TextStyle(
                  fontSize: r.font(13, min: 11, max: 15),
                  color: Colors.blue.shade800,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required String label,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    final r = context.responsive;
    
    // Convert Color to MaterialColor shades
    Color getShade50(Color baseColor) {
      if (baseColor == Colors.orange) return Colors.orange.shade50;
      if (baseColor == Colors.green) return Colors.green.shade50;
      if (baseColor == Colors.grey) return Colors.grey.shade50;
      if (baseColor == Colors.blue) return Colors.blue.shade50;
      if (baseColor == Colors.purple) return Colors.purple.shade50;
      if (baseColor == Colors.red) return Colors.red.shade50;
      if (baseColor == Colors.teal) return Colors.teal.shade50;
      return Colors.grey.shade50;
    }
    
    Color getShade200(Color baseColor) {
      if (baseColor == Colors.orange) return Colors.orange.shade200;
      if (baseColor == Colors.green) return Colors.green.shade200;
      if (baseColor == Colors.grey) return Colors.grey.shade200;
      if (baseColor == Colors.blue) return Colors.blue.shade200;
      if (baseColor == Colors.purple) return Colors.purple.shade200;
      if (baseColor == Colors.red) return Colors.red.shade200;
      if (baseColor == Colors.teal) return Colors.teal.shade200;
      return Colors.grey.shade200;
    }
    
    Color getShade600(Color baseColor) {
      if (baseColor == Colors.orange) return Colors.orange.shade600;
      if (baseColor == Colors.green) return Colors.green.shade600;
      if (baseColor == Colors.grey) return Colors.grey.shade600;
      if (baseColor == Colors.blue) return Colors.blue.shade600;
      if (baseColor == Colors.purple) return Colors.purple.shade600;
      if (baseColor == Colors.red) return Colors.red.shade600;
      if (baseColor == Colors.teal) return Colors.teal.shade600;
      return Colors.grey.shade600;
    }
    
    Color getShade700(Color baseColor) {
      if (baseColor == Colors.orange) return Colors.orange.shade700;
      if (baseColor == Colors.green) return Colors.green.shade700;
      if (baseColor == Colors.grey) return Colors.grey.shade700;
      if (baseColor == Colors.blue) return Colors.blue.shade700;
      if (baseColor == Colors.purple) return Colors.purple.shade700;
      if (baseColor == Colors.red) return Colors.red.shade700;
      if (baseColor == Colors.teal) return Colors.teal.shade700;
      return Colors.grey.shade700;
    }
    
    Color getShade900(Color baseColor) {
      if (baseColor == Colors.orange) return Colors.orange.shade900;
      if (baseColor == Colors.green) return Colors.green.shade900;
      if (baseColor == Colors.grey) return Colors.grey.shade900;
      if (baseColor == Colors.blue) return Colors.blue.shade900;
      if (baseColor == Colors.purple) return Colors.purple.shade900;
      if (baseColor == Colors.red) return Colors.red.shade900;
      if (baseColor == Colors.teal) return Colors.teal.shade900;
      return Colors.grey.shade900;
    }
    
    return Container(
      padding: r.padding(all: 12),
      decoration: BoxDecoration(
        color: getShade50(color),
        borderRadius: BorderRadius.circular(r.size(8)),
        border: Border.all(color: getShade200(color)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: r.font(12, min: 10, max: 14),
              color: getShade700(color),
              fontWeight: FontWeight.w500,
            ),
          ),
          ResponsiveGap.vertical(4),
          Text(
            value,
            style: TextStyle(
              fontSize: r.font(18, min: 16, max: 20),
              fontWeight: FontWeight.bold,
              color: getShade900(color),
            ),
          ),
          if (subtitle != null) ...[
            ResponsiveGap.vertical(2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: r.font(11, min: 9, max: 13),
                color: getShade600(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


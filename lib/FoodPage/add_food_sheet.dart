import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/services/usda_api_service.dart';

class AddFoodSheet extends StatefulWidget {
  final String mealName;
  final Function(String foodName, int calories)? onFoodAdded;

  const AddFoodSheet({
    super.key,
    required this.mealName,
    this.onFoodAdded,
  });

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _gramsController = TextEditingController();
  final TextEditingController _manualFoodController = TextEditingController();
  final TextEditingController _manualCaloriesController = TextEditingController();

  List<FoodSearchResult> _searchResults = [];
  FoodSearchResult? _selectedFood;
  bool _isLoading = false;
  bool _isManualEntry = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    _gramsController.dispose();
    _manualFoodController.dispose();
    _manualCaloriesController.dispose();
    super.dispose();
  }

  Future<void> _searchFoods(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedFood = null;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await USDAApiService.searchFoods(
        query: query,
        pageSize: 10,
      );

      setState(() {
        _searchResults = response.foods;
        _selectedFood = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching foods: ${e.toString()}';
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  void _selectFood(FoodSearchResult food) {
    setState(() {
      _selectedFood = food;
      _searchController.text = USDAApiService.formatFoodDescription(food);
    });
  }

  void _toggleEntryMode() {
    setState(() {
      _isManualEntry = !_isManualEntry;
      _selectedFood = null;
      _searchResults = [];
      _searchController.clear();
      _gramsController.clear();
      _manualFoodController.clear();
      _manualCaloriesController.clear();
      _errorMessage = null;
    });
  }

  void _saveFood() {
    if (_isManualEntry) {
      _saveManualFood();
    } else {
      _saveSelectedFood();
    }
  }

  void _saveSelectedFood() {
    if (_selectedFood == null) {
      _showError('Please select a food item first');
      return;
    }

    final grams = double.tryParse(_gramsController.text);
    if (grams == null || grams <= 0) {
      _showError('Please enter a valid amount in grams');
      return;
    }

    final nutrition = USDAApiService.calculateNutritionForAmount(
      food: _selectedFood!,
      grams: grams,
    );

    final calories = nutrition['calories']!.round();
    final foodName = USDAApiService.formatFoodDescription(_selectedFood!);

    if (widget.onFoodAdded != null) {
      widget.onFoodAdded!(foodName, calories);
    }

    Navigator.pop(context);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Added ${grams}g $foodName ($calories calories) to ${widget.mealName}'
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _saveManualFood() {
    final foodName = _manualFoodController.text.trim();
    final calories = int.tryParse(_manualCaloriesController.text);

    if (foodName.isEmpty) {
      _showError('Please enter a food name');
      return;
    }

    if (calories == null || calories <= 0) {
      _showError('Please enter valid calories');
      return;
    }

    if (widget.onFoodAdded != null) {
      widget.onFoodAdded!(foodName, calories);
    }

    Navigator.pop(context);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $foodName ($calories calories) to ${widget.mealName}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildNutritionPreview() {
    if (_selectedFood == null || _gramsController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final grams = double.tryParse(_gramsController.text);
    if (grams == null || grams <= 0) return const SizedBox.shrink();

    final nutrition = USDAApiService.calculateNutritionForAmount(
      food: _selectedFood!,
      grams: grams,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition for ${grams.toStringAsFixed(0)}g:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNutrientInfo('Calories', '${nutrition['calories']!.round()}'),
              _buildNutrientInfo('Protein', '${nutrition['protein']!.toStringAsFixed(1)}g'),
              _buildNutrientInfo('Carbs', '${nutrition['carbs']!.toStringAsFixed(1)}g'),
              _buildNutrientInfo('Fat', '${nutrition['totalFat']!.toStringAsFixed(1)}g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientInfo(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Add ${widget.mealName}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF666666), size: 24),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE0E0E0)),
            const SizedBox(height: 14),

            // Toggle buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isManualEntry ? _toggleEntryMode : null,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Search Foods'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isManualEntry ? AppColors.secondary : Colors.grey.shade200,
                      foregroundColor: !_isManualEntry ? Colors.white : Colors.grey.shade600,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !_isManualEntry ? _toggleEntryMode : null,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Manual Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isManualEntry ? AppColors.secondary : Colors.grey.shade200,
                      foregroundColor: _isManualEntry ? Colors.white : Colors.grey.shade600,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content
            Expanded(
              child: _isManualEntry ? _buildManualEntry() : _buildFoodSearch(),
            ),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveFood,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add Food', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodSearch() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (value) {
              if (value.length > 2) {
                _searchFoods(value);
              }
            },
            decoration: InputDecoration(
              hintText: "Search for foods (e.g., 'chicken breast', 'apple')",
              prefixIcon: const Icon(Icons.search, color: Color(0xFF666666)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700))),
                ],
              ),
            ),
          ],

          // Search Results
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Search Results:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...List.generate(_searchResults.length, (index) {
              final food = _searchResults[index];
              final isSelected = _selectedFood?.fdcId == food.fdcId;
              return Card(
                color: isSelected ? AppColors.secondary.withOpacity(0.1) : null,
                child: ListTile(
                  title: Text(
                    USDAApiService.formatFoodDescription(food),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text('${food.calories.toStringAsFixed(0)} cal per 100g'),
                  trailing: isSelected ? Icon(Icons.check_circle, color: AppColors.secondary) : null,
                  onTap: () => _selectFood(food),
                ),
              );
            }),
          ],

          if (_selectedFood != null) ...[
            const SizedBox(height: 20),
            const Text('Amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _gramsController,
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}), // Trigger nutrition preview update
              decoration: InputDecoration(
                hintText: "Enter amount in grams",
                suffixText: 'g',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.secondary, width: 2),
                ),
              ),
            ),
            _buildNutritionPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Food Name:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _manualFoodController,
            decoration: InputDecoration(
              hintText: "Enter food name",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Calories:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _manualCaloriesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "Enter total calories",
              suffixText: 'cal',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
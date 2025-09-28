import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/services/usda_api_service.dart';

class AddFoodSheet extends StatefulWidget {
  final String mealName;
  final Function(String foodName, int calories, {double? grams})? onFoodAdded;

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
  void initState() {
    super.initState();
  }

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
        query: query.trim(),
        pageSize: 15,
      );

      if (response.foods.isEmpty) {
        setState(() {
          _searchResults = [];
          _selectedFood = null;
          _isLoading = false;
          _errorMessage = 'No foods found for "$query". Try a different search term.';
        });
      } else {
        setState(() {
          _searchResults = response.foods;
          _selectedFood = null;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      // Log error (replace with proper logging framework in production)
      debugPrint('USDA API Error: $e');
      String errorMessage = 'Unable to search foods. ';

      if (e.toString().contains('Failed to search foods: 400')) {
        errorMessage += 'Please check your search term.';
      } else if (e.toString().contains('Failed to search foods: 403')) {
        errorMessage += 'API access denied. Please try again later.';
      } else if (e.toString().contains('Failed to search foods: 429')) {
        errorMessage += 'Too many requests. Please wait and try again.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        errorMessage += 'Please check your internet connection.';
      } else {
        errorMessage += 'Please try again later.';
      }

      setState(() {
        _errorMessage = errorMessage;
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

  void _saveSelectedFood() async {
    if (_selectedFood == null) {
      _showError('Please select a food item first');
      return;
    }

    final gramsText = _gramsController.text.trim();
    if (gramsText.isEmpty) {
      _showError('Please enter the amount in grams');
      return;
    }

    final grams = double.tryParse(gramsText);
    if (grams == null || grams <= 0) {
      _showError('Please enter a valid amount greater than 0');
      return;
    }

    if (grams > 5000) {
      _showError('Amount seems too large. Please enter a reasonable amount.');
      return;
    }

    // Check if food has calorie data
    if (_selectedFood!.calories <= 0) {
      _showError('This food item doesn\'t have calorie information available');
      return;
    }

    final calories = USDAApiService.calculateCaloriesForAmount(
      food: _selectedFood!,
      grams: grams,
    ).round();
    final foodName = USDAApiService.formatFoodDescription(_selectedFood!);

    // Call the callback without storing here (parent will handle storage)
    if (widget.onFoodAdded != null) {
      widget.onFoodAdded!(foodName, calories, grams: grams);
    }

    Navigator.pop(context);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Added ${grams.toStringAsFixed(0)}g $foodName ($calories calories) to ${widget.mealName}'
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _saveManualFood() async {
    final foodName = _manualFoodController.text.trim();
    final caloriesText = _manualCaloriesController.text.trim();

    if (foodName.isEmpty) {
      _showError('Please enter a food name');
      return;
    }

    if (foodName.length < 2) {
      _showError('Food name must be at least 2 characters');
      return;
    }

    if (caloriesText.isEmpty) {
      _showError('Please enter the calories');
      return;
    }

    final calories = int.tryParse(caloriesText);
    if (calories == null || calories <= 0) {
      _showError('Please enter valid calories greater than 0');
      return;
    }

    if (calories > 10000) {
      _showError('Calories seem too high. Please enter a reasonable amount.');
      return;
    }

    // Call the callback without storing here (parent will handle storage)
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

  Widget _buildCaloriePreview() {
    if (_selectedFood == null || _gramsController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final grams = double.tryParse(_gramsController.text);
    if (grams == null || grams <= 0) return const SizedBox.shrink();

    final calories = USDAApiService.calculateCaloriesForAmount(
      food: _selectedFood!,
      grams: grams,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calories for ${grams.toStringAsFixed(0)}g:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${calories.round()} calories',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
              fontSize: 18,
            ),
          ),
        ],
      ),
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
              } else if (value.length <= 2) {
                // Clear results when search is too short
                setState(() {
                  _searchResults = [];
                  _selectedFood = null;
                  _errorMessage = null;
                });
              }
            },
            onSubmitted: (value) {
              if (value.length > 2) {
                _searchFoods(value);
              }
            },
            decoration: InputDecoration(
              hintText: "Search for foods (e.g., 'chicken breast', 'apple')",
              prefixIcon: const Icon(Icons.search, color: Color(0xFF666666)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF666666)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _selectedFood = null;
                          _errorMessage = null;
                        });
                      },
                    )
                  : null,
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

          // Search Results or Suggestions
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Search Results:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...List.generate(_searchResults.length, (index) {
              final food = _searchResults[index];
              final isSelected = _selectedFood?.fdcId == food.fdcId;
              return Card(
                color: isSelected ? AppColors.secondary.withValues(alpha: 0.1) : null,
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
          ] else if (_searchController.text.isEmpty && !_isLoading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Popular searches:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      'chicken breast', 'apple', 'banana', 'rice', 'egg',
                      'salmon', 'broccoli', 'oatmeal', 'yogurt', 'almonds'
                    ].map((suggestion) => GestureDetector(
                      onTap: () {
                        _searchController.text = suggestion;
                        _searchFoods(suggestion);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          suggestion,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],

          if (_selectedFood != null) ...[
            const SizedBox(height: 20),
            const Text('Amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _gramsController,
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}), // Trigger calorie preview update
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
            _buildCaloriePreview(),
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
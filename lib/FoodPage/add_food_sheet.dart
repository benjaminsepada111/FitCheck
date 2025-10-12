import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/services/usda_api_service.dart';
import 'package:image_picker/image_picker.dart';

class AddFoodSheet extends StatefulWidget {
  final String mealName;
  final Function(String foodName, int calories, {double? grams, String? imageBase64})? onFoodAdded;

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
  final ImagePicker _picker = ImagePicker();

  List<FoodSearchResult> _searchResults = [];
  FoodSearchResult? _selectedFood;
  bool _isLoading = false;
  bool _isManualEntry = false;
  String? _errorMessage;
  File? _selectedImage;
  String? _imageBase64;

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final bytes = await imageFile.readAsBytes();
        setState(() {
          _selectedImage = imageFile;
          _imageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showError('Failed to pick image');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageBase64 = null;
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
      _selectedImage = null;
      _imageBase64 = null;
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

    if (_selectedFood!.calories <= 0) {
      _showError('This food item doesn\'t have calorie information available');
      return;
    }

    final calories = USDAApiService.calculateCaloriesForAmount(
      food: _selectedFood!,
      grams: grams,
    ).round();
    final foodName = USDAApiService.formatFoodDescription(_selectedFood!);

    if (widget.onFoodAdded != null) {
      widget.onFoodAdded!(foodName, calories, grams: grams, imageBase64: _imageBase64);
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Added ${grams.toStringAsFixed(0)}g $foodName to ${widget.mealName}'),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    if (widget.onFoodAdded != null) {
      widget.onFoodAdded!(foodName, calories, imageBase64: _imageBase64);
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Added $foodName to ${widget.mealName}')),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_fire_department,
              color: AppColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Calories',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${calories.round()} cal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${grams.toStringAsFixed(0)}g',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
                fontSize: 14,
              ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: AppColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Add ${widget.mealName}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF666666), size: 24),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Modern Toggle Buttons
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _isManualEntry ? _toggleEntryMode : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isManualEntry ? AppColors.secondary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !_isManualEntry
                              ? [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 18,
                              color: !_isManualEntry ? Colors.white : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Search Foods',
                              style: TextStyle(
                                color: !_isManualEntry ? Colors.white : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: !_isManualEntry ? _toggleEntryMode : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isManualEntry ? AppColors.secondary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _isManualEntry
                              ? [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: _isManualEntry ? Colors.white : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Manual Entry',
                              style: TextStyle(
                                color: _isManualEntry ? Colors.white : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isManualEntry ? _buildManualEntry() : _buildFoodSearch(),
            ),

            const SizedBox(height: 16),

            // Enhanced Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saveFood,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add Food',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
          // Enhanced Search Field
          TextField(
            controller: _searchController,
            onChanged: (value) {
              if (value.length > 2) {
                _searchFoods(value);
              } else if (value.length <= 2) {
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
              hintText: "Search foods (e.g., chicken, apple)...",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, color: AppColors.secondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey.shade400),
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
              filled: true,
              fillColor: Colors.grey.shade50,
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
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 32),
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Search Results with constrained height
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Results',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  '${_searchResults.length} items',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  final food = _searchResults[index];
                  final isSelected = _selectedFood?.fdcId == food.fdcId;
                  return Container(
                    color: isSelected ? AppColors.secondary.withOpacity(0.08) : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        USDAApiService.formatFoodDescription(food),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${food.calories.toStringAsFixed(0)} cal per 100g',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      trailing: isSelected
                          ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                          : null,
                      onTap: () => _selectFood(food),
                    ),
                  );
                },
              ),
            ),
          ] else if (_searchController.text.isEmpty && !_isLoading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.08),
                    AppColors.secondary.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.secondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Popular Searches',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'chicken breast', 'apple', 'banana', 'rice', 'egg',
                      'salmon', 'broccoli', 'oatmeal', 'yogurt', 'almonds'
                    ].map((suggestion) => GestureDetector(
                      onTap: () {
                        _searchController.text = suggestion;
                        _searchFoods(suggestion);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.secondary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          suggestion,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
            const SizedBox(height: 24),
            Text(
              'Enter Amount',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _gramsController,
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Enter amount in grams",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                suffixText: 'grams',
                suffixStyle: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
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
                  borderSide: BorderSide(color: AppColors.secondary, width: 2),
                ),
              ),
            ),
            _buildCaloriePreview(),
          ],

          // Image Upload Section
          const SizedBox(height: 24),
          _buildImageUploadSection(),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Food Photo (Optional)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),

        if (_selectedImage == null) ...[
          // Image picker buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // Image preview with remove button
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _removeImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildManualEntry() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Food Name',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _manualFoodController,
            decoration: InputDecoration(
              hintText: "Enter food name",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade50,
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
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Total Calories',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _manualCaloriesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "Enter total calories",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              suffixText: 'cal',
              suffixStyle: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
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
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),

          // Image Upload Section for Manual Entry
          const SizedBox(height: 20),
          _buildImageUploadSection(),
        ],
      ),
    );
  }
}
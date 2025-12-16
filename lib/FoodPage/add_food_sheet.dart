import 'dart:io';
import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/services/usda_api_service.dart';
import 'package:capstone_project/services/food_cache_service.dart';
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'package:capstone_project/services/user_food_preferences_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AddFoodSheet extends StatefulWidget {
  final String mealName;
  final String? challengeId;
  final DateTime selectedDate;
  final Function(
      String foodName,
      int calories, {
      double? grams,
      String? imageUrl,
      double? servingSize,
      String? unit,
      })?
  onFoodAdded;

  const AddFoodSheet({
    super.key,
    required this.mealName,
    this.challengeId,
    required this.selectedDate,
    this.onFoodAdded,
  });

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _manualFoodController = TextEditingController();
  final TextEditingController _manualCaloriesController = TextEditingController();
  final TextEditingController _manualServingSizeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<FoodSearchResult> _searchResults = [];
  FoodSearchResult? _selectedFood;
  bool _isLoading = false;
  bool _isManualEntry = false;
  String? _errorMessage;
  File? _selectedImage;
  String? _imageUrl;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  List<String> _recentSearches = [];
  List<FoodSearchResult> _recentManualFoods = [];

  String _manualUnit = 'grams';

  Map<int, Map<String, dynamic>> _manualFoodServingInfo = {};

  @override
  void initState() {
    super.initState();
    _loadRecentData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _manualFoodController.dispose();
    _manualCaloriesController.dispose();
    _manualServingSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentData() async {
    try {
      final recentSearches = await UserFoodPreferencesService.getRecentSearches(
        limit: 10,
      );
      final recentManualFoods = await UserFoodPreferencesService.getManualFoods(
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _recentSearches = recentSearches;
          _recentManualFoods = recentManualFoods.take(10).toList();
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _searchFoods(String query, {bool saveToRecent = false}) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedFood = null;
        _errorMessage = null;
      });
      return;
    }

    if (saveToRecent) {
      await UserFoodPreferencesService.saveRecentSearch(query);
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await FoodCacheService.searchFoods(query.trim());

      _manualFoodServingInfo.clear();
      for (final food in results) {
        if (food.fdcId < 0) {
          final servingInfo = await UserFoodPreferencesService.getManualFoodServingInfo(food.fdcId);
          if (servingInfo != null) {
            _manualFoodServingInfo[food.fdcId] = servingInfo;
          }
        }
      }

      if (results.isEmpty) {
        setState(() {
          _searchResults = [];
          _selectedFood = null;
          _isLoading = false;
          _errorMessage = 'No foods found for "$query". Try a different search term.';
        });
      } else {
        setState(() {
          _searchResults = results;
          _selectedFood = null;
          _isLoading = false;
          _errorMessage = null;
        });
      }

      if (saveToRecent) {
        _loadRecentData();
      }
    } catch (e) {
      String errorMessage = 'Unable to search foods. ';

      if (e.toString().contains('Failed to search foods: 400')) {
        errorMessage += 'Please check your search term.';
      } else if (e.toString().contains('Failed to search foods: 403')) {
        errorMessage += 'API access denied. Please try again later.';
      } else if (e.toString().contains('Failed to search foods: 429')) {
        errorMessage += 'Too many requests. Please wait and try again.';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
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

  void _selectFood(FoodSearchResult food) async {
    final currentQuery = _searchController.text.trim();

    if (food.fdcId < 0 && !_manualFoodServingInfo.containsKey(food.fdcId)) {
      final servingInfo = await UserFoodPreferencesService.getManualFoodServingInfo(food.fdcId);
      if (servingInfo != null) {
        _manualFoodServingInfo[food.fdcId] = servingInfo;
      }
    }

    setState(() {
      _selectedFood = food;
      _searchController.text = USDAApiService.formatFoodDescription(food);
      // Set default quantity to 1
      _quantityController.text = '1';
    });

    if (currentQuery.isNotEmpty && currentQuery.length > 2) {
      await UserFoodPreferencesService.saveRecentSearch(currentQuery);
      _loadRecentData();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        if (Platform.isAndroid) {
          var status = await Permission.camera.request();
          if (!status.isGranted) {
            if (!mounted) return;
            _showError("Camera permission denied");
            return;
          }
        } else if (Platform.isIOS) {
          var status = await Permission.camera.status;
          if (status.isDenied || status.isRestricted) {
            status = await Permission.camera.request();
            if (!status.isGranted) {
              if (!mounted) return;
              if (status.isPermanentlyDenied) {
                final shouldOpen = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Camera Permission Required'),
                    content: const Text(
                      'Camera permission is required to take photos. Please enable it in Settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                );
                if (shouldOpen == true) {
                  await openAppSettings();
                }
              } else {
                _showError("Camera permission denied");
              }
              return;
            }
          }
        }
      } else if (source == ImageSource.gallery) {
        PermissionStatus status;

        if (Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;

          if (androidInfo.version.sdkInt >= 33) {
            status = await Permission.photos.request();
          } else {
            status = await Permission.storage.request();
          }

          if (!status.isGranted) {
            if (!mounted) return;
            _showError("Photos permission is required to select images");
            return;
          }
        }
      }

      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        setState(() {
          _selectedImage = imageFile;
          _imageUrl = null;
        });
      }
    } catch (e) {
      _showError('Failed to pick image');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageUrl = null;
    });
  }

  void _toggleEntryMode() {
    setState(() {
      _isManualEntry = !_isManualEntry;
      _selectedFood = null;
      _searchResults = [];
      _searchController.clear();
      _quantityController.clear();
      _manualFoodController.clear();
      _manualCaloriesController.clear();
      _manualServingSizeController.clear();
      _errorMessage = null;
      _selectedImage = null;
      _imageUrl = null;
      _manualUnit = 'grams';
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

    final servingInfo = _manualFoodServingInfo[_selectedFood!.fdcId];
    final isManualFood = servingInfo != null || _selectedFood!.fdcId < 0;

    double? servingSize;
    String? unit;
    int calories;
    String foodName;
    double quantity;

    // ✅ Both food types now require quantity input
    final quantityText = _quantityController.text.trim();
    if (quantityText.isEmpty) {
      _showError('Please enter the quantity');
      return;
    }

    final parsedQuantity = double.tryParse(quantityText);
    if (parsedQuantity == null || parsedQuantity <= 0) {
      _showError('Please enter a valid quantity greater than 0');
      return;
    }

    quantity = parsedQuantity;

    if (quantity > 50) {
      _showError('Quantity seems too large. Please enter a reasonable amount.');
      return;
    }

    if (isManualFood && servingInfo != null) {
      // Manual food with quantity
      servingSize = servingInfo['servingSize'] as double;
      unit = servingInfo['unit'] as String;
      final baseCalories = servingInfo['calories'] as int;
      calories = (baseCalories * quantity).round(); // ✅ Multiply by quantity
      foodName = _selectedFood!.description;
    } else {
      // USDA food with quantity
      if (_selectedFood!.calories <= 0) {
        _showError('This food item doesn\'t have calorie information available');
        return;
      }

      // For USDA foods, 1 serving = 100g
      servingSize = 100.0 * quantity;
      calories = (_selectedFood!.calories * quantity).round();
      foodName = USDAApiService.formatFoodDescription(_selectedFood!);
      unit = 'serving';
    }

    setState(() => _isSaving = true);

    try {
      String? uploadedImageUrl;
      if (_selectedImage != null && widget.challengeId != null) {
        setState(() => _isUploadingImage = true);

        uploadedImageUrl = await ImageStorageService.uploadFoodImage(
          _selectedImage!,
          challengeId: widget.challengeId!,
        );

        setState(() => _isUploadingImage = false);

        if (uploadedImageUrl == null) {
          _showError(
            'Failed to upload image. Food will be saved without photo.',
          );
        }
      } else if (_selectedImage != null && widget.challengeId == null) {
        _showError('Cannot upload image without an active challenge.');
      }

      try {
        await UserAchievementService.trackMealLogging(calories: calories);
      } catch (e) {
        // Don't block
      }

      if (widget.onFoodAdded != null) {
        widget.onFoodAdded!(
          foodName,
          calories,
          grams: servingSize,
          imageUrl: uploadedImageUrl,
          servingSize: servingSize,
          unit: unit,
        );
      }

      if (!mounted) return;

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
                child: Text(
                  'Added ${quantity == 1.0 ? '1 serving' : '${quantity.toStringAsFixed(1)} servings'} of $foodName to ${widget.mealName}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Failed to add food. Please try again.');
    }
  }

  void _saveManualFood() async {
    final foodName = _manualFoodController.text.trim();
    final caloriesText = _manualCaloriesController.text.trim();
    final servingSizeText = _manualServingSizeController.text.trim();

    if (foodName.isEmpty) {
      _showError('Please enter a food name');
      return;
    }

    if (foodName.length < 2) {
      _showError('Food name must be at least 2 characters');
      return;
    }

    if (caloriesText.isEmpty) {
      _showError('Please enter the total calories per serving');
      return;
    }

    final totalCalories = int.tryParse(caloriesText);
    if (totalCalories == null || totalCalories <= 0) {
      _showError('Please enter valid calories greater than 0');
      return;
    }

    if (totalCalories > 10000) {
      _showError('Calories seem too high. Please enter a reasonable amount.');
      return;
    }

    if (servingSizeText.isEmpty) {
      _showError('Please enter the serving size');
      return;
    }

    final servingSize = double.tryParse(servingSizeText);
    if (servingSize == null || servingSize <= 0) {
      _showError('Please enter a valid serving size greater than 0');
      return;
    }

    if (servingSize > 10000) {
      _showError('Serving size seems too large. Please enter a reasonable amount.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? uploadedImageUrl;
      if (_selectedImage != null && widget.challengeId != null) {
        setState(() => _isUploadingImage = true);

        uploadedImageUrl = await ImageStorageService.uploadFoodImage(
          _selectedImage!,
          challengeId: widget.challengeId!,
        );

        setState(() => _isUploadingImage = false);

        if (uploadedImageUrl == null) {
          _showError(
            'Failed to upload image. Food will be saved without photo.',
          );
        }
      } else if (_selectedImage != null && widget.challengeId == null) {
        _showError('Cannot upload image without an active challenge.');
      }

      await UserFoodPreferencesService.saveManualFood(
        foodName: foodName,
        calories: totalCalories,
        servingSize: servingSize,
        imageUrl: uploadedImageUrl,
        unit: _manualUnit,
      );

      try {
        await UserAchievementService.trackMealLogging(calories: totalCalories);
      } catch (e) {
        // Don't block
      }

      if (widget.onFoodAdded != null) {
        widget.onFoodAdded!(
          foodName,
          totalCalories,
          imageUrl: uploadedImageUrl,
          servingSize: servingSize,
          unit: _manualUnit,
        );
      }

      if (!mounted) return;

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Failed to add food. Please try again.');
    }
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
    if (_selectedFood == null || _quantityController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) return const SizedBox.shrink();

    // ✅ Calculate calories based on food type
    final servingInfo = _manualFoodServingInfo[_selectedFood!.fdcId];
    final isManualFood = servingInfo != null || _selectedFood!.fdcId < 0;

    final calories = isManualFood && servingInfo != null
        ? (servingInfo['calories'] as int) * quantity
        : _selectedFood!.calories * quantity;

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
              quantity == 1.0 ? '1 serving' : '${quantity.toStringAsFixed(1)} servings',
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
      height: MediaQuery.of(context).size.height * 0.95,
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
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFF666666),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

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
                          color: !_isManualEntry
                              ? AppColors.secondary
                              : Colors.transparent,
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
                              color: !_isManualEntry
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Search Foods',
                              style: TextStyle(
                                color: !_isManualEntry
                                    ? Colors.white
                                    : Colors.grey.shade600,
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
                          color: _isManualEntry
                              ? AppColors.secondary
                              : Colors.transparent,
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
                              color: _isManualEntry
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Manual Entry',
                              style: TextStyle(
                                color: _isManualEntry
                                    ? Colors.white
                                    : Colors.grey.shade600,
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

            Expanded(
              child: _isManualEntry ? _buildManualEntry() : _buildFoodSearch(),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveFood,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: AppColors.secondary.withValues(
                        alpha: 0.6,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                        : const Text(
                      'Add Food',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
          TextField(
            controller: _searchController,
            onChanged: (value) {
              if (value.length > 2) {
                _searchFoods(value, saveToRecent: false);
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
                _searchFoods(value, saveToRecent: true);
              }
            },
            decoration: InputDecoration(
              hintText: "Search foods...",
              hintStyle: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.search, color: AppColors.secondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Color(0xFFAAAAAA)),
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
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
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
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 22,
                  ),
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
            // Show "Add Manually" button when no results found
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleEntryMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text(
                  'Add Food Manually',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

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
              constraints: const BoxConstraints(
                maxHeight: 300,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final food = _searchResults[index];
                  final isSelected = _selectedFood?.fdcId == food.fdcId;
                  return Container(
                    color: isSelected
                        ? AppColors.secondary.withOpacity(0.08)
                        : Colors.white,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(
                        USDAApiService.formatFoodDescription(food),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Builder(
                        builder: (context) {
                          String calorieText;
                          final servingInfo = _manualFoodServingInfo[food.fdcId];
                          final isManualFood = servingInfo != null || food.fdcId < 0;

                          if (servingInfo != null) {
                            final servingSize = servingInfo['servingSize'] as double;
                            final unit = servingInfo['unit'] as String;
                            final calories = servingInfo['calories'] as int;
                            calorieText = '$calories kcal per ${servingSize.toStringAsFixed(0)} $unit';
                          } else {
                            calorieText = '${food.calories.toStringAsFixed(0)} cal per serving (100g)';
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  size: 12,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  calorieText,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isManualFood
                                        ? AppColors.secondary.withOpacity(0.1)
                                        : Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isManualFood
                                          ? AppColors.secondary.withOpacity(0.3)
                                          : Colors.blue.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    isManualFood ? 'Manual' : 'USDA',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isManualFood
                                          ? AppColors.secondary
                                          : Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      trailing: isSelected
                          ? Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      )
                          : null,
                      onTap: () => _selectFood(food),
                    ),
                  );
                },
              ),
            ),
          ],

          if (_searchController.text.isEmpty && !_isLoading) ...[
            if (_recentSearches.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Recent Searches',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentSearches.length.clamp(0, 10),
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final suggestion = _recentSearches[index];
                    return GestureDetector(
                      onTap: () {
                        _searchController.text = suggestion;
                        _searchFoods(suggestion, saveToRecent: true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.secondary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            suggestion,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],

          if (_selectedFood != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Enter Quantity',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Enter quantity (e.g., 1, 2, 0.5)",
                    hintStyle: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 14,
                    ),
                    suffixText: 'serving(s)',
                    suffixStyle: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.secondary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                _buildCaloriePreview(),
              ],
            ),
          ],

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
        const Text(
          'Food Photo (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),

        if (_selectedImage == null) ...[
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.camera),
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.secondary.shade200,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 32,
                            color: AppColors.secondary.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Take Photo",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Use camera",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.secondary.shade200,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.photo_library,
                            size: 32,
                            color: AppColors.secondary.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Gallery",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Choose photo",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  ),

                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Food Photo",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
          const Text(
            'Food Name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _manualFoodController,
            decoration: InputDecoration(
              hintText: "Enter food name",
              hintStyle: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Total Calories',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _manualCaloriesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "Enter total calories per serving",
              hintStyle: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 14,
              ),
              suffixText: 'cal',
              suffixStyle: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Serving Size',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _manualServingSizeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter serving size",
                        hintStyle: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.secondary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _manualUnit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.secondary, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'grams',
                          child: Text('g'),
                        ),
                        DropdownMenuItem(
                          value: 'ml',
                          child: Text('ml'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _manualUnit = value;
                          });
                        }
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey.shade600,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      menuMaxHeight: 100,
                      alignment: AlignmentDirectional.bottomStart,
                      itemHeight: 48,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildImageUploadSection(),
        ],
      ),
    );
  }
}
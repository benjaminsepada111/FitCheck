import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized access to environment variables loaded from `.env`.
class EnvConfig {
  static String get spoonacularApiKey =>
      dotenv.env['SPOONACULAR_API_KEY']?.trim() ?? '';

  static String get usdaApiKey => dotenv.env['USDA_API_KEY']?.trim() ?? '';

  static bool get hasSpoonacularKey => spoonacularApiKey.isNotEmpty;

  static bool get hasUsdaKey => usdaApiKey.isNotEmpty;
}

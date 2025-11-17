import 'package:flutter/widgets.dart';

/// Provides responsive sizing utilities based on target device sizes.
///
/// This class helps create mobile-first responsive layouts that work across
/// Android and iOS devices with different screen sizes.
///
/// Target device sizes (logical pixels):
/// - Android Small/Medium: 360x780, 360x800, 360x820
/// - iPhone 13/14: 390x844
/// - iPhone 15/15 Pro: 393x852
/// - Pixel 7/8: 393x873
/// - Samsung S22/S23/S24: 412x915
/// - Xiaomi 12/13/14: 412x919
/// - iPhone Pro Max: 428x926
/// - iPhone 15 Pro Max: 430x932
class Responsive {
  final BuildContext context;
  final double deviceWidth;
  final double deviceHeight;

  /// Baseline width used for scaling calculations (iPhone 13/14 width)
  static const double baseWidth = 390.0;

  /// Baseline height used for vertical scaling calculations
  static const double baseHeight = 844.0;

  /// Breakpoints for different device categories
  static const double mobileSmall = 360.0;
  static const double mobileMedium = 390.0;
  static const double mobileLarge = 412.0;
  static const double mobileXLarge = 430.0;
  static const double tablet = 600.0;
  static const double desktop = 900.0;

  Responsive(this.context)
      : deviceWidth = MediaQuery.of(context).size.width,
        deviceHeight = MediaQuery.of(context).size.height;

  /// Width scale factor relative to base width
  double get scale => deviceWidth / baseWidth;

  /// Height scale factor relative to base height
  double get scaleHeight => deviceHeight / baseHeight;

  /// Get the smaller of width or height scale (useful for uniform scaling)
  double get scaleMin => scale < scaleHeight ? scale : scaleHeight;

  /// Get the larger of width or height scale
  double get scaleMax => scale > scaleHeight ? scale : scaleHeight;

  /// Responsive size for spacing, padding, margins, and other dimensions
  /// Uses width-based scaling by default
  double size(double value) => value * scale;

  /// Responsive size based on height (useful for vertical spacing)
  double sizeH(double value) => value * scaleHeight;

  /// Responsive size using the minimum scale factor (uniform scaling)
  /// Good for maintaining aspect ratios
  double sizeMin(double value) => value * scaleMin;

  /// Responsive font scaling with min/max clamps to ensure readability
  ///
  /// [fontSize] - Base font size at 390px width
  /// [min] - Minimum font size (default 12sp for accessibility)
  /// [max] - Maximum font size (default 32sp to prevent giant text)
  double font(double fontSize, {double min = 12, double max = 32}) {
    final scaledSize = fontSize * scale;
    if (scaledSize < min) return min;
    if (scaledSize > max) return max;
    return scaledSize;
  }

  /// Get responsive padding based on device width
  EdgeInsets padding({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    if (all != null) {
      return EdgeInsets.all(size(all));
    }

    return EdgeInsets.only(
      left: size(left ?? horizontal ?? 0),
      top: size(top ?? vertical ?? 0),
      right: size(right ?? horizontal ?? 0),
      bottom: size(bottom ?? vertical ?? 0),
    );
  }

  /// Get responsive symmetric padding
  EdgeInsets paddingSymmetric({double horizontal = 0, double vertical = 0}) {
    return EdgeInsets.symmetric(
      horizontal: size(horizontal),
      vertical: size(vertical),
    );
  }

  /// Get responsive border radius
  BorderRadius borderRadius(double radius) {
    return BorderRadius.circular(size(radius));
  }

  /// Check if device is in a specific size category
  bool get isSmallMobile => deviceWidth < mobileMedium;
  bool get isMediumMobile => deviceWidth >= mobileMedium && deviceWidth < mobileLarge;
  bool get isLargeMobile => deviceWidth >= mobileLarge && deviceWidth < tablet;
  bool get isTablet => deviceWidth >= tablet && deviceWidth < desktop;
  bool get isDesktop => deviceWidth >= desktop;

  /// Check if device is mobile (any size)
  bool get isMobile => deviceWidth < tablet;

  /// Get screen orientation
  bool get isPortrait => deviceHeight > deviceWidth;
  bool get isLandscape => deviceWidth > deviceHeight;

  /// Safe area padding (for notches, status bars, navigation bars)
  EdgeInsets get safeAreaPadding => MediaQuery.of(context).padding;

  /// Viewport insets (for keyboard, etc.)
  EdgeInsets get viewInsets => MediaQuery.of(context).viewInsets;

  /// Get a responsive width percentage
  /// [percentage] - Value between 0 and 1 (e.g., 0.9 for 90%)
  double widthPercent(double percentage) => deviceWidth * percentage;

  /// Get a responsive height percentage
  /// [percentage] - Value between 0 and 1 (e.g., 0.5 for 50%)
  double heightPercent(double percentage) => deviceHeight * percentage;

  /// Minimum tap target size (44x44 dp as per accessibility guidelines)
  static const double minTapTarget = 44.0;

  /// Ensure a value meets minimum tap target requirements
  double tapTarget(double value) {
    final scaled = size(value);
    return scaled < minTapTarget ? minTapTarget : scaled;
  }
}

/// Extension on num for quick responsive sizing inside widgets
///
/// Usage:
/// ```dart
/// Container(
///   width: 100.w(context),  // Responsive width
///   height: 50.h(context),   // Responsive height
///   padding: EdgeInsets.all(16.s(context)), // Responsive padding
/// )
/// ```
extension ResponsiveNum on num {
  /// Get width-based responsive size
  double w(BuildContext context) => Responsive(context).size(toDouble());

  /// Get height-based responsive size
  double h(BuildContext context) => Responsive(context).sizeH(toDouble());

  /// Get uniform responsive size (uses min scale)
  double s(BuildContext context) => Responsive(context).sizeMin(toDouble());

  /// Get responsive font size
  double sp(BuildContext context, {double min = 12, double max = 32}) {
    return Responsive(context).font(toDouble(), min: min, max: max);
  }

  /// Get percentage of screen width
  double get sw => this / 100;

  /// Get percentage of screen height
  double get sh => this / 100;
}

/// Extension on BuildContext for quick access to Responsive instance
extension ResponsiveContext on BuildContext {
  Responsive get responsive => Responsive(this);

  /// Quick access to common responsive values
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get safeAreaPadding => MediaQuery.of(this).padding;
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;

  /// Check device categories
  bool get isSmallMobile => Responsive(this).isSmallMobile;
  bool get isMediumMobile => Responsive(this).isMediumMobile;
  bool get isLargeMobile => Responsive(this).isLargeMobile;
  bool get isTablet => Responsive(this).isTablet;
  bool get isDesktop => Responsive(this).isDesktop;
  bool get isMobile => Responsive(this).isMobile;

  /// Orientation checks
  bool get isPortrait => Responsive(this).isPortrait;
  bool get isLandscape => Responsive(this).isLandscape;
}

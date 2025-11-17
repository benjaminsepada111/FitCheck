# FitCheck - Responsive Design Implementation Guide

## Overview

This document provides comprehensive guidelines for implementing and testing responsive design in the FitCheck Flutter application. The app is designed to work seamlessly across all modern Android and iOS devices with different screen sizes.

## Table of Contents

1. [Target Device Sizes](#target-device-sizes)
2. [Responsive Utilities](#responsive-utilities)
3. [Responsive Widgets](#responsive-widgets)
4. [Usage Examples](#usage-examples)
5. [Testing Guidelines](#testing-guidelines)
6. [Migration Guide](#migration-guide)
7. [Best Practices](#best-practices)

---

## Target Device Sizes

All dimensions are in **logical pixels (dp)** - the canvas size Flutter sees, not raw hardware resolution.

### Android Devices

#### Small/Medium
- **360 × 780** (Common budget phones)
- **360 × 800** (Samsung Galaxy A series)
- **360 × 820** (Standard compact phones)

#### Modern Flagships
- **393 × 873** (Google Pixel 7, Pixel 8)
- **412 × 915** (Samsung S22, S23, S24)
- **412 × 919** (Xiaomi 12, 13, 14)

### iOS Devices

#### Standard iPhones
- **390 × 844** (iPhone 13, iPhone 14)
- **393 × 852** (iPhone 15, iPhone 15 Pro)

#### Pro Max Models
- **428 × 926** (iPhone 13 Pro Max, iPhone 14 Pro Max)
- **430 × 932** (iPhone 15 Pro Max)

### Design Baseline
- **Base Width:** 390 dp (iPhone 13/14)
- **Base Height:** 844 dp (iPhone 13/14)

All responsive calculations scale relative to this baseline.

---

## Responsive Utilities

### Core Utility: `Responsive` Class

Located in: `lib/utils/responsive_utils.dart`

```dart
final r = Responsive(context);
// or using extension:
final r = context.responsive;
```

#### Key Properties

| Property | Description | Example |
|----------|-------------|---------|
| `scale` | Width-based scale factor | `r.scale` → 1.08 on iPhone 15 Pro Max |
| `scaleHeight` | Height-based scale factor | `r.scaleHeight` |
| `scaleMin` | Smaller of width/height scale | `r.scaleMin` |
| `deviceWidth` | Screen width in dp | `r.deviceWidth` → 390.0 |
| `deviceHeight` | Screen height in dp | `r.deviceHeight` → 844.0 |

#### Key Methods

##### Sizing
```dart
// Width-based responsive sizing
double size(double value) → r.size(16) // 16dp scaled

// Height-based responsive sizing
double sizeH(double value) → r.sizeH(100) // 100dp scaled vertically

// Uniform scaling (maintains aspect ratio)
double sizeMin(double value) → r.sizeMin(50)
```

##### Font Scaling
```dart
// Responsive font with min/max clamps
double font(double fontSize, {double min = 12, double max = 32})

// Example:
r.font(16, min: 14, max: 20) // 16sp scaled, clamped between 14-20
```

##### Padding & Spacing
```dart
// Get responsive padding
EdgeInsets padding({
  double? all,
  double? horizontal,
  double? vertical,
  double? left,
  double? top,
  double? right,
  double? bottom,
})

// Examples:
r.padding(all: 16)
r.paddingSymmetric(horizontal: 20, vertical: 16)
```

##### Border Radius
```dart
BorderRadius borderRadius(double radius)

// Example:
r.borderRadius(12) // 12dp radius, scaled
```

##### Breakpoint Checks
```dart
bool get isSmallMobile  // < 390dp
bool get isMediumMobile // 390-412dp
bool get isLargeMobile  // 412-600dp
bool get isTablet       // 600-900dp
bool get isDesktop      // > 900dp
bool get isMobile       // < 600dp
```

##### Percentage-based Sizing
```dart
double widthPercent(double percentage)  // 0.0 - 1.0
double heightPercent(double percentage) // 0.0 - 1.0

// Examples:
r.widthPercent(0.9)  // 90% of screen width
r.heightPercent(0.5) // 50% of screen height
```

##### Tap Target Sizing
```dart
// Ensures minimum 44×44 dp tap target (accessibility)
double tapTarget(double value)

// Example:
r.tapTarget(40) // Returns 44 if scaled value < 44
```

### Extension Methods

#### On `num`
```dart
100.w(context)  // Width-based scaling
50.h(context)   // Height-based scaling
24.s(context)   // Uniform scaling
16.sp(context)  // Font scaling
```

#### On `BuildContext`
```dart
context.responsive       // Get Responsive instance
context.screenWidth      // Screen width
context.screenHeight     // Screen height
context.safeAreaPadding  // Safe area insets
context.isSmallMobile    // Breakpoint check
context.isMobile         // Is mobile device
context.isPortrait       // Orientation check
```

---

## Responsive Widgets

Located in: `lib/widgets/responsive_widgets.dart`

### ResponsiveText

Auto-scaling text with font size constraints.

```dart
ResponsiveText(
  'Hello World',
  baseFontSize: 16,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  minFontSize: 14,
  maxFontSize: 20,
)
```

### ResponsiveButton

Button with minimum 44×44 dp tap target.

```dart
ResponsiveButton(
  onPressed: () {},
  backgroundColor: Colors.blue,
  foregroundColor: Colors.white,
  borderRadius: 12,
  child: Text('Click Me'),
)
```

### ResponsiveTextButton

Text button with responsive sizing and tap target.

```dart
ResponsiveTextButton(
  onPressed: () {},
  foregroundColor: Colors.blue,
  child: Text('Learn More'),
)
```

### ResponsiveIconButton

Icon button with proper tap target size.

```dart
ResponsiveIconButton(
  icon: Icons.settings,
  onPressed: () {},
  iconSize: 24,
  minTapTarget: 44,
)
```

### ResponsiveContainer

Container with auto-scaled dimensions.

```dart
ResponsiveContainer(
  width: 200,
  height: 100,
  padding: EdgeInsets.all(16),
  margin: EdgeInsets.symmetric(vertical: 8),
  borderRadius: 12,
  color: Colors.blue,
  child: Text('Scaled Container'),
)
```

### ResponsiveSizedBox

Sized box with responsive dimensions.

```dart
ResponsiveSizedBox(
  width: 100,
  height: 50,
  child: MyWidget(),
)
```

### ResponsiveGap

Spacing widget for vertical/horizontal gaps.

```dart
ResponsiveGap(16)                    // Vertical gap
ResponsiveGap.vertical(20)           // Vertical gap
ResponsiveGap.horizontal(12)         // Horizontal gap
```

### ResponsivePadding

Padding wrapper with auto-scaling.

```dart
ResponsivePadding.all(16, child: MyWidget())

ResponsivePadding.symmetric(
  horizontal: 20,
  vertical: 16,
  child: MyWidget(),
)

ResponsivePadding.only(
  left: 16,
  top: 24,
  right: 16,
  bottom: 8,
  child: MyWidget(),
)
```

### ResponsiveCard

Card with responsive padding and border radius.

```dart
ResponsiveCard(
  borderRadius: 12,
  padding: EdgeInsets.all(16),
  color: Colors.white,
  onTap: () {},
  child: MyContent(),
)
```

### ResponsiveScaffold

Adaptive scaffold that changes layout based on screen size.

```dart
ResponsiveScaffold(
  appBar: AppBar(title: Text('My App')),
  body: MainContent(),
  secondary: SidebarContent(), // Shows on tablet/desktop
  bottomNavigationBar: MyBottomNav(),
)
```

- **Mobile (< 600dp):** Single column, body only
- **Tablet (600-900dp):** Two columns side-by-side
- **Desktop (> 900dp):** Two columns with 2:1 flex ratio

### ResponsiveGrid

Auto-adaptive grid with dynamic column count.

```dart
ResponsiveGrid(
  children: [
    GridItem1(),
    GridItem2(),
    GridItem3(),
  ],
  minItemWidth: 150,
  spacing: 16,
  runSpacing: 16,
)
```

---

## Usage Examples

### Example 1: Converting Fixed Layout to Responsive

**Before (Fixed):**
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  margin: const EdgeInsets.only(bottom: 24),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    'Hello',
    style: TextStyle(fontSize: 16),
  ),
)
```

**After (Responsive):**
```dart
final r = context.responsive;

Container(
  padding: r.paddingSymmetric(horizontal: 20, vertical: 16),
  margin: EdgeInsets.only(bottom: r.size(24)),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(r.size(20)),
  ),
  child: Text(
    'Hello',
    style: TextStyle(fontSize: r.font(16)),
  ),
)
```

**Or using ResponsiveContainer:**
```dart
ResponsiveContainer(
  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  margin: EdgeInsets.only(bottom: 24),
  borderRadius: 20,
  child: ResponsiveText('Hello', baseFontSize: 16),
)
```

### Example 2: Adaptive Layout by Breakpoint

```dart
Widget build(BuildContext context) {
  final r = context.responsive;

  if (r.isTablet || r.isDesktop) {
    // Two-column layout for larger screens
    return Row(
      children: [
        Expanded(flex: 2, child: MainContent()),
        Expanded(flex: 1, child: Sidebar()),
      ],
    );
  }

  // Single column for mobile
  return Column(
    children: [
      MainContent(),
      Sidebar(),
    ],
  );
}
```

### Example 3: Responsive Grid

```dart
GridView.count(
  crossAxisCount: context.isSmallMobile ? 2 :
                  context.isTablet ? 3 : 4,
  crossAxisSpacing: 12.w(context),
  mainAxisSpacing: 12.h(context),
  children: items,
)
```

### Example 4: Font Scaling with Constraints

```dart
Text(
  'Headline',
  style: TextStyle(
    fontSize: r.font(32, min: 24, max: 40),
    fontWeight: FontWeight.bold,
  ),
)
```

---

## Testing Guidelines

### Manual Testing Checklist

Test the app on the following device configurations:

#### Android Emulators/Devices

1. **Small Phone (360×780)**
   - Create emulator: Pixel 3a or Generic Phone
   - Set size: 360×780 dp

2. **Medium Phone (393×873)**
   - Device: Pixel 7 or Pixel 8

3. **Large Phone (412×915)**
   - Device: Samsung Galaxy S22, S23, or S24

4. **Extra Large (430×932)**
   - Device: Pixel 6 Pro or similar

#### iOS Simulators/Devices

1. **iPhone 13/14 (390×844)**
   - Standard reference device

2. **iPhone 15 (393×852)**
   - Modern compact size

3. **iPhone 15 Pro Max (430×932)**
   - Largest iPhone

### Test Cases

For each device size, verify:

#### ✅ Layout Tests
- [ ] No horizontal overflow (no yellow/black stripes)
- [ ] No vertical overflow on main screens
- [ ] All content visible without unnecessary scrolling
- [ ] Proper spacing between elements
- [ ] Text doesn't wrap unexpectedly
- [ ] Images maintain aspect ratio

#### ✅ Typography Tests
- [ ] All text readable (minimum 14sp)
- [ ] Headings appropriately sized
- [ ] No text clipping or truncation
- [ ] Line heights appropriate
- [ ] Letter spacing looks good

#### ✅ Touch Target Tests
- [ ] All buttons at least 44×44 dp
- [ ] Icon buttons tappable (44×44 dp)
- [ ] List items easy to tap
- [ ] Input fields have adequate size
- [ ] Bottom navigation items properly sized

#### ✅ Safe Area Tests
- [ ] Content doesn't overlap with notch (iPhone)
- [ ] Content respects status bar
- [ ] Bottom navigation clears gesture bar
- [ ] Keyboard doesn't cover input fields

#### ✅ Orientation Tests
- [ ] Portrait mode works correctly
- [ ] Landscape mode (if supported) looks good
- [ ] Orientation change doesn't break layout

#### ✅ Visual Consistency
- [ ] Colors render correctly
- [ ] Shadows/elevations look appropriate
- [ ] Border radius scales proportionally
- [ ] Padding/margins feel balanced

### Automated Testing

Create widget tests for responsive behavior:

```dart
testWidgets('ResponsiveText scales correctly', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(360, 780)),
        child: ResponsiveText('Test', baseFontSize: 16),
      ),
    ),
  );

  final textWidget = tester.widget<Text>(find.byType(Text));
  expect(textWidget.style?.fontSize, lessThan(16)); // Scaled down on 360dp
});
```

### Using Flutter Device Preview Package

Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  device_preview: ^1.1.0
```

In `main.dart`:
```dart
import 'package:device_preview/device_preview.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      // ... rest of your app
    );
  }
}
```

### Testing Commands

```bash
# Run on specific device
flutter run -d <device_id>

# Run on all connected devices
flutter run -d all

# Run with specific screen size (custom emulator)
flutter emulators --launch <emulator_name>

# Check for overflow issues
flutter run --profile
```

---

## Migration Guide

### Step-by-Step Migration Process

#### Step 1: Import Responsive Utils
```dart
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';
```

#### Step 2: Add Responsive Instance
```dart
@override
Widget build(BuildContext context) {
  final r = context.responsive; // Add this line
  // ... rest of build
}
```

#### Step 3: Replace Fixed Values

| Fixed | Responsive |
|-------|-----------|
| `const EdgeInsets.all(16)` | `r.padding(all: 16)` |
| `const EdgeInsets.symmetric(h: 20)` | `r.paddingSymmetric(horizontal: 20)` |
| `BorderRadius.circular(12)` | `BorderRadius.circular(r.size(12))` |
| `fontSize: 16` | `fontSize: r.font(16)` |
| `const SizedBox(height: 20)` | `ResponsiveGap(20)` |
| `width: 100` | `width: r.size(100)` |

#### Step 4: Update Widgets

Replace standard widgets with responsive equivalents:
- `Text` → `ResponsiveText`
- `ElevatedButton` → `ResponsiveButton`
- `Container` → `ResponsiveContainer`
- `SizedBox` → `ResponsiveSizedBox`
- `Card` → `ResponsiveCard`

#### Step 5: Test on Multiple Devices

Run through the testing checklist above.

### Priority Files to Migrate

Based on project analysis, focus on these high-traffic screens first:

1. **lib/main_page.dart** - Dashboard
2. **lib/food_page.dart** - Food tracking
3. **lib/MainPage/trackers.dart** - Calorie/workout trackers
4. **lib/FoodPage/mealsection.dart** - Meal display
5. **lib/MainPage/custom_bottom_navbar.dart** - Navigation
6. **lib/profile.dart** - User profile
7. **lib/MainPage/milestone_journey.dart** - Progress milestones

---

## Best Practices

### 1. Mobile-First Design
Always design for the smallest target size (360×780) first, then scale up.

```dart
// Good: Design for small, enhance for large
if (r.isSmallMobile) {
  return CompactLayout();
} else {
  return ExpandedLayout();
}

// Bad: Design for large, squeeze for small
```

### 2. Use Relative Sizing
Prefer proportions over absolute values.

```dart
// Good
width: r.widthPercent(0.9), // 90% of screen width

// Bad
width: r.size(350), // Might overflow on small devices
```

### 3. Clamp Critical Dimensions
Add min/max constraints for critical UI elements.

```dart
// Good
fontSize: r.font(16, min: 14, max: 20),
minHeight: r.size(44).clamp(44, 60),

// Bad
fontSize: r.font(16), // Could be too small or too large
```

### 4. Respect Safe Areas
Always use SafeArea or check MediaQuery.padding.

```dart
// Good
SafeArea(
  child: MyContent(),
)

// Or manually:
padding: EdgeInsets.only(
  top: context.safeAreaPadding.top,
  bottom: context.safeAreaPadding.bottom,
)
```

### 5. Test on Real Devices
Emulators are good, but test on actual devices when possible, especially for:
- Touch target sizes
- Text readability
- Performance
- Gesture interactions

### 6. Maintain Minimum Tap Targets
**Always** ensure interactive elements are at least 44×44 dp.

```dart
// Good
ResponsiveIconButton(
  icon: Icons.close,
  onPressed: () {},
  minTapTarget: 44, // Explicit minimum
)

// Good
IconButton(
  icon: Icon(Icons.close),
  iconSize: r.size(24),
  constraints: BoxConstraints(
    minWidth: r.tapTarget(44),
    minHeight: r.tapTarget(44),
  ),
  onPressed: () {},
)
```

### 7. Use LayoutBuilder for Complex Layouts
When you need to make decisions based on available space:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      return WideLayout();
    }
    return NarrowLayout();
  },
)
```

### 8. Avoid Hard-coded Breakpoints in UI Code
Use the provided breakpoint helpers instead.

```dart
// Good
if (r.isTablet) {
  return TwoColumnLayout();
}

// Bad
if (MediaQuery.of(context).size.width > 600) {
  return TwoColumnLayout();
}
```

### 9. Keep Aspect Ratios Consistent
Use `r.sizeMin()` for elements that should scale uniformly.

```dart
// Square avatar that maintains aspect ratio
Container(
  width: r.sizeMin(60),
  height: r.sizeMin(60),
  decoration: BoxDecoration(shape: BoxShape.circle),
)
```

### 10. Document Responsive Decisions
Add comments explaining breakpoint choices:

```dart
// Show 2 columns on small phones, 3 on medium, 4 on large
int columnCount = r.isSmallMobile ? 2 :
                  r.isMediumMobile ? 3 : 4;
```

---

## Example: Complete Screen Migration

### Before (Fixed)
```dart
class FoodPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Food Tracker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Daily Calories',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              child: Text('Add Food'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### After (Responsive)
```dart
class FoodPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: ResponsiveText(
          'Food Tracker',
          baseFontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: ResponsivePadding.all(
        16,
        child: Column(
          children: [
            ResponsiveContainer(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              borderRadius: 12,
              color: Colors.blue,
              child: ResponsiveText(
                'Daily Calories',
                baseFontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            ResponsiveGap(24),
            ResponsiveButton(
              onPressed: () {},
              child: ResponsiveText('Add Food', baseFontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Resources

### Documentation
- [Flutter Responsive Design](https://flutter.dev/docs/development/ui/layout/responsive)
- [Material Design - Layout](https://material.io/design/layout/responsive-layout-grid.html)
- [iOS Human Interface Guidelines - Layout](https://developer.apple.com/design/human-interface-guidelines/layout)

### Tools
- Flutter DevTools
- Device Preview Package
- Flutter Inspector

### Reference Files
- `lib/utils/responsive_utils.dart` - Core utilities
- `lib/widgets/responsive_widgets.dart` - Reusable components
- `lib/examples/responsive_scaffold_example.dart` - Complete example

---

## Support

For questions or issues:
1. Check this documentation
2. Review example file: `lib/examples/responsive_scaffold_example.dart`
3. Test on target device sizes listed above
4. Consult Flutter documentation

---

**Last Updated:** 2025-11-18
**Version:** 1.0
**Author:** FitCheck Development Team

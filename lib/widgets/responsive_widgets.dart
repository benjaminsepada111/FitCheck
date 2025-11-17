import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Responsive text widget that automatically scales font size based on screen width
///
/// Usage:
/// ```dart
/// ResponsiveText(
///   'Hello World',
///   baseFontSize: 16,
///   fontWeight: FontWeight.w600,
/// )
/// ```
class ResponsiveText extends StatelessWidget {
  final String text;
  final double baseFontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? letterSpacing;
  final double? height;
  final TextDecoration? decoration;
  final double minFontSize;
  final double maxFontSize;

  const ResponsiveText(
    this.text, {
    Key? key,
    this.baseFontSize = 16,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.letterSpacing,
    this.height,
    this.decoration,
    this.minFontSize = 12,
    this.maxFontSize = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontSize: r.font(baseFontSize, min: minFontSize, max: maxFontSize),
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      ),
    );
  }
}

/// Responsive button with minimum tap target of 44x44 dp
///
/// Usage:
/// ```dart
/// ResponsiveButton(
///   onPressed: () {},
///   child: Text('Click Me'),
/// )
/// ```
class ResponsiveButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double minHeight;
  final double? width;

  const ResponsiveButton({
    Key? key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
    this.padding,
    this.minHeight = 44,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: r.tapTarget(minHeight),
        minWidth: r.tapTarget(80),
      ),
      child: SizedBox(
        width: width,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            minimumSize: Size(double.infinity, r.tapTarget(minHeight)),
            padding: padding ??
                EdgeInsets.symmetric(
                  vertical: r.size(12),
                  horizontal: r.size(16),
                ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius != null ? r.size(borderRadius!) : r.size(12),
              ),
            ),
          ),
          onPressed: onPressed,
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: r.font(16)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Responsive text button with minimum tap target
class ResponsiveTextButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final double minHeight;

  const ResponsiveTextButton({
    Key? key,
    required this.child,
    required this.onPressed,
    this.foregroundColor,
    this.padding,
    this.minHeight = 44,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: r.tapTarget(minHeight),
        minWidth: r.tapTarget(44),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          minimumSize: Size(r.tapTarget(44), r.tapTarget(minHeight)),
          padding: padding ??
              EdgeInsets.symmetric(
                vertical: r.size(8),
                horizontal: r.size(12),
              ),
        ),
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: r.font(16)),
          child: child,
        ),
      ),
    );
  }
}

/// Responsive icon button with minimum tap target
class ResponsiveIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final double minTapTarget;

  const ResponsiveIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.iconSize = 24,
    this.minTapTarget = 44,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: r.tapTarget(minTapTarget),
        minWidth: r.tapTarget(minTapTarget),
      ),
      child: IconButton(
        icon: Icon(icon),
        iconSize: r.size(iconSize),
        color: color,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minHeight: r.tapTarget(minTapTarget),
          minWidth: r.tapTarget(minTapTarget),
        ),
      ),
    );
  }
}

/// Responsive container with scaled padding, margin, and dimensions
class ResponsiveContainer extends StatelessWidget {
  final Widget? child;
  final Color? color;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;
  final double? borderRadius;
  final AlignmentGeometry? alignment;

  const ResponsiveContainer({
    Key? key,
    this.child,
    this.color,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.decoration,
    this.borderRadius,
    this.alignment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    Decoration? finalDecoration = decoration;
    if (decoration == null && (color != null || borderRadius != null)) {
      finalDecoration = BoxDecoration(
        color: color,
        borderRadius: borderRadius != null
            ? BorderRadius.circular(r.size(borderRadius!))
            : null,
      );
    }

    return Container(
      width: width != null ? r.size(width!) : null,
      height: height != null ? r.size(height!) : null,
      padding: padding != null ? _scaleEdgeInsets(r, padding!) : null,
      margin: margin != null ? _scaleEdgeInsets(r, margin!) : null,
      decoration: finalDecoration,
      alignment: alignment,
      child: child,
    );
  }

  EdgeInsetsGeometry _scaleEdgeInsets(
      Responsive r, EdgeInsetsGeometry insets) {
    if (insets is EdgeInsets) {
      return EdgeInsets.only(
        left: r.size(insets.left),
        top: r.size(insets.top),
        right: r.size(insets.right),
        bottom: r.size(insets.bottom),
      );
    }
    return insets;
  }
}

/// Responsive sized box with scaled dimensions
class ResponsiveSizedBox extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget? child;

  const ResponsiveSizedBox({
    Key? key,
    this.width,
    this.height,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return SizedBox(
      width: width != null ? r.size(width!) : null,
      height: height != null ? r.size(height!) : null,
      child: child,
    );
  }
}

/// Responsive gap for spacing (vertical or horizontal)
class ResponsiveGap extends StatelessWidget {
  final double size;
  final bool vertical;

  const ResponsiveGap(
    this.size, {
    Key? key,
    this.vertical = true,
  }) : super(key: key);

  /// Create a vertical gap
  const ResponsiveGap.vertical(
    this.size, {
    Key? key,
  })  : vertical = true,
        super(key: key);

  /// Create a horizontal gap
  const ResponsiveGap.horizontal(
    this.size, {
    Key? key,
  })  : vertical = false,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final scaledSize = r.size(size);
    return SizedBox(
      width: vertical ? null : scaledSize,
      height: vertical ? scaledSize : null,
    );
  }
}

/// Responsive padding wrapper widget
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final double? all;
  final double? horizontal;
  final double? vertical;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;

  const ResponsivePadding({
    Key? key,
    required this.child,
    this.all,
    this.horizontal,
    this.vertical,
    this.left,
    this.top,
    this.right,
    this.bottom,
  }) : super(key: key);

  const ResponsivePadding.all(
    double value, {
    Key? key,
    required this.child,
  })  : all = value,
        horizontal = null,
        vertical = null,
        left = null,
        top = null,
        right = null,
        bottom = null,
        super(key: key);

  const ResponsivePadding.symmetric({
    Key? key,
    required this.child,
    double horizontal = 0,
    double vertical = 0,
  })  : all = null,
        horizontal = horizontal,
        vertical = vertical,
        left = null,
        top = null,
        right = null,
        bottom = null,
        super(key: key);

  const ResponsivePadding.only({
    Key? key,
    required this.child,
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  })  : all = null,
        horizontal = null,
        vertical = null,
        left = left,
        top = top,
        right = right,
        bottom = bottom,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Padding(
      padding: r.padding(
        all: all,
        horizontal: horizontal,
        vertical: vertical,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
      child: child,
    );
  }
}

/// Responsive card with scaled padding and border radius
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final VoidCallback? onTap;

  const ResponsiveCard({
    Key? key,
    required this.child,
    this.color,
    this.borderRadius = 12,
    this.padding,
    this.margin,
    this.boxShadow,
    this.border,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    final cardContent = Container(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: r.size(16),
            vertical: r.size(12),
          ),
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(r.size(borderRadius)),
        boxShadow: boxShadow,
        border: border,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.size(borderRadius)),
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// Responsive scaffold with adaptive layout capabilities
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? secondary;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool useSafeArea;
  final double tabletBreakpoint;
  final double desktopBreakpoint;

  const ResponsiveScaffold({
    Key? key,
    this.appBar,
    required this.body,
    this.secondary,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.useSafeArea = true,
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 900,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    Widget responsiveBody;

    // Desktop layout: two-pane side by side
    if (width >= desktopBreakpoint && secondary != null) {
      responsiveBody = Row(
        children: [
          Expanded(flex: 2, child: body),
          Expanded(flex: 1, child: secondary!),
        ],
      );
    }
    // Tablet layout: side by side when secondary is provided
    else if (width >= tabletBreakpoint && secondary != null) {
      responsiveBody = Row(
        children: [
          Expanded(child: body),
          Expanded(child: secondary!),
        ],
      );
    }
    // Mobile layout: single column
    else {
      responsiveBody = body;
    }

    if (useSafeArea) {
      responsiveBody = SafeArea(child: responsiveBody);
    }

    return Scaffold(
      appBar: appBar,
      body: responsiveBody,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      backgroundColor: backgroundColor,
    );
  }
}

/// Responsive grid view with adaptive column count
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.minItemWidth = 150,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final scaledMinWidth = r.size(minItemWidth);
    final scaledSpacing = r.size(spacing);
    final scaledRunSpacing = r.size(runSpacing);

    return Padding(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: r.size(16),
            vertical: r.size(8),
          ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount =
              (constraints.maxWidth / (scaledMinWidth + scaledSpacing))
                  .floor()
                  .clamp(1, 6);

          return GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: scaledSpacing,
            mainAxisSpacing: scaledRunSpacing,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: children,
          );
        },
      ),
    );
  }
}

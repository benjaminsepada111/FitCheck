import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';
import '../widgets/responsive_widgets.dart';

/// Example demonstrating responsive scaffold usage across different breakpoints
///
/// This example shows:
/// - Responsive layouts that adapt from mobile to tablet to desktop
/// - Proper use of responsive utilities and widgets
/// - Safe area handling
/// - Adaptive column counts based on screen width
class ResponsiveScaffoldExample extends StatelessWidget {
  const ResponsiveScaffoldExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: const ResponsiveText(
          'Responsive Example',
          baseFontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          ResponsiveIconButton(
            icon: Icons.settings,
            onPressed: () {},
          ),
        ],
      ),
      body: const _ResponsiveBody(),
      bottomNavigationBar: const _ResponsiveBottomNav(),
    );
  }
}

class _ResponsiveBody extends StatelessWidget {
  const _ResponsiveBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePadding(
        horizontal: 16,
        vertical: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            ResponsiveText(
              'Welcome to FitCheck',
              baseFontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            const ResponsiveGap(8),
            ResponsiveText(
              'Your fitness journey starts here',
              baseFontSize: 16,
              color: Colors.grey[600],
            ),
            const ResponsiveGap(24),

            // Device Info Card (for testing)
            _DeviceInfoCard(),
            const ResponsiveGap(24),

            // Responsive Grid Example
            ResponsiveText(
              'Quick Stats',
              baseFontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            const ResponsiveGap(16),
            _StatsGrid(),
            const ResponsiveGap(24),

            // Responsive Cards Example
            ResponsiveText(
              'Recent Activity',
              baseFontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            const ResponsiveGap(16),
            _ActivityCards(),
            const ResponsiveGap(24),

            // Responsive Buttons Example
            ResponsiveText(
              'Actions',
              baseFontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            const ResponsiveGap(16),
            _ButtonExamples(),
            const ResponsiveGap(24),

            // Breakpoint-specific Layout
            _BreakpointLayout(),
          ],
        ),
      ),
    );
  }
}

/// Device info card showing current screen dimensions and breakpoint
class _DeviceInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    String deviceCategory = 'Unknown';
    if (r.isSmallMobile) deviceCategory = 'Small Mobile (< 390dp)';
    if (r.isMediumMobile) deviceCategory = 'Medium Mobile (390-412dp)';
    if (r.isLargeMobile) deviceCategory = 'Large Mobile (412-600dp)';
    if (r.isTablet) deviceCategory = 'Tablet (600-900dp)';
    if (r.isDesktop) deviceCategory = 'Desktop (> 900dp)';

    return ResponsiveCard(
      color: Colors.blue[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveText(
            'Device Information',
            baseFontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          const ResponsiveGap(8),
          ResponsiveText(
            'Width: ${r.deviceWidth.toStringAsFixed(1)} dp',
            baseFontSize: 14,
          ),
          const ResponsiveGap(4),
          ResponsiveText(
            'Height: ${r.deviceHeight.toStringAsFixed(1)} dp',
            baseFontSize: 14,
          ),
          const ResponsiveGap(4),
          ResponsiveText(
            'Scale: ${r.scale.toStringAsFixed(2)}x',
            baseFontSize: 14,
          ),
          const ResponsiveGap(4),
          ResponsiveText(
            'Category: $deviceCategory',
            baseFontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          const ResponsiveGap(4),
          ResponsiveText(
            'Orientation: ${r.isPortrait ? "Portrait" : "Landscape"}',
            baseFontSize: 14,
          ),
        ],
      ),
    );
  }
}

/// Responsive grid of stat cards
class _StatsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = context.responsive;

        // Adaptive column count based on screen width
        int crossAxisCount = 2;
        if (r.deviceWidth >= 600) {
          crossAxisCount = 3;
        }
        if (r.deviceWidth >= 900) {
          crossAxisCount = 4;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: r.size(12),
          mainAxisSpacing: r.size(12),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          children: [
            _StatCard(
              title: 'Calories',
              value: '1,847',
              icon: Icons.local_fire_department,
              color: Colors.orange,
            ),
            _StatCard(
              title: 'Workouts',
              value: '12',
              icon: Icons.fitness_center,
              color: Colors.blue,
            ),
            _StatCard(
              title: 'Streak',
              value: '7 days',
              icon: Icons.star,
              color: Colors.amber,
            ),
            _StatCard(
              title: 'Weight',
              value: '75 kg',
              icon: Icons.scale,
              color: Colors.green,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return ResponsiveCard(
      color: color.withOpacity(0.1),
      padding: EdgeInsets.all(r.size(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: r.size(32),
            color: color,
          ),
          const ResponsiveGap(8),
          ResponsiveText(
            value,
            baseFontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          const ResponsiveGap(4),
          ResponsiveText(
            title,
            baseFontSize: 12,
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }
}

/// Activity cards with responsive layout
class _ActivityCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActivityCard(
          title: 'Morning Run',
          subtitle: '5.2 km • 32 min',
          icon: Icons.directions_run,
          time: '7:30 AM',
        ),
        const ResponsiveGap(12),
        _ActivityCard(
          title: 'Breakfast',
          subtitle: '420 calories',
          icon: Icons.breakfast_dining,
          time: '8:45 AM',
        ),
        const ResponsiveGap(12),
        _ActivityCard(
          title: 'Gym Session',
          subtitle: 'Upper body • 45 min',
          icon: Icons.fitness_center,
          time: '6:00 PM',
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String time;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return ResponsiveCard(
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: r.size(48),
            height: r.size(48),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.size(12)),
            ),
            child: Icon(
              icon,
              size: r.size(24),
              color: Colors.blue,
            ),
          ),
          ResponsiveSizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveText(
                  title,
                  baseFontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                const ResponsiveGap(4),
                ResponsiveText(
                  subtitle,
                  baseFontSize: 14,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
          ResponsiveText(
            time,
            baseFontSize: 12,
            color: Colors.grey[500],
          ),
        ],
      ),
    );
  }
}

/// Button examples showing responsive sizing
class _ButtonExamples extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveButton(
          onPressed: () {},
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          child: const ResponsiveText(
            'Log New Workout',
            baseFontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const ResponsiveGap(12),
        ResponsiveButton(
          onPressed: () {},
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
          child: const ResponsiveText(
            'View Progress',
            baseFontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
        const ResponsiveGap(12),
        Row(
          children: [
            Expanded(
              child: ResponsiveTextButton(
                onPressed: () {},
                child: const ResponsiveText(
                  'Cancel',
                  baseFontSize: 14,
                ),
              ),
            ),
            ResponsiveSizedBox(width: 12),
            Expanded(
              child: ResponsiveTextButton(
                onPressed: () {},
                foregroundColor: Colors.blue,
                child: const ResponsiveText(
                  'Save',
                  baseFontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Layout that changes based on breakpoint
class _BreakpointLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (r.isTablet || r.isDesktop) {
      // Two-column layout for larger screens
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _FeatureCard(
              title: 'Track Nutrition',
              description: 'Log your meals and monitor your calorie intake',
              icon: Icons.restaurant,
            ),
          ),
          ResponsiveSizedBox(width: 16),
          Expanded(
            child: _FeatureCard(
              title: 'Track Workouts',
              description: 'Record your exercises and track your progress',
              icon: Icons.fitness_center,
            ),
          ),
        ],
      );
    }

    // Single column layout for mobile
    return Column(
      children: [
        _FeatureCard(
          title: 'Track Nutrition',
          description: 'Log your meals and monitor your calorie intake',
          icon: Icons.restaurant,
        ),
        const ResponsiveGap(16),
        _FeatureCard(
          title: 'Track Workouts',
          description: 'Record your exercises and track your progress',
          icon: Icons.fitness_center,
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return ResponsiveCard(
      color: Colors.grey[100],
      padding: EdgeInsets.all(r.size(20)),
      child: Column(
        children: [
          Icon(
            icon,
            size: r.size(48),
            color: Colors.blue,
          ),
          const ResponsiveGap(12),
          ResponsiveText(
            title,
            baseFontSize: 18,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
          const ResponsiveGap(8),
          ResponsiveText(
            description,
            baseFontSize: 14,
            color: Colors.grey[600],
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Responsive bottom navigation bar
class _ResponsiveBottomNav extends StatelessWidget {
  const _ResponsiveBottomNav();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      height: r.size(60).clamp(60.0, 80.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home, label: 'Home', isActive: true),
            _NavItem(icon: Icons.restaurant, label: 'Food'),
            _NavItem(icon: Icons.fitness_center, label: 'Workout'),
            _NavItem(icon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final color = isActive ? Colors.blue : Colors.grey[600];

    return InkWell(
      onTap: () {},
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.size(12),
          vertical: r.size(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: r.size(24),
              color: color,
            ),
            ResponsiveSizedBox(height: 4),
            ResponsiveText(
              label,
              baseFontSize: 12,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

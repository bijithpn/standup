UI Redesign Plan: Minimal macOS Experience

 Context

 The goal is to transform the current "heavy" glassmorphic UI into a refined, professional, and minimal macOS
 experience. This includes improving information density, connecting visualizations to real data, and enhancing
 the overall "feel" through micro-interactions and strict adherence to macOS HIG.

 Implementation Steps

 1. Theme and Base Styles Update

 Refine the glassmorphic aesthetic to be more subtle and professional.
 - File: lib/shared/theme/app_theme.dart
 - Changes:
   - Reduce glassContainer and glassCardDecoration opacity.
   - Soften border colors and shadows.
   - Refine sectionTitle and subHeaderStyle for better hierarchy and reduced visual noise.

 2. Window Constraints Enforcement

 Strictly enforce window size restrictions to prevent UI breakage in narrow mode.
 - File: lib/main.dart
 - Changes:
   - Verify and tighten minimumSize in WindowOptions.
   - Optimize default size for the redesigned dashboard.

 3. Navigation and Shell Refinement

 Replace the Material-based narrow layout with a native macOS feel.
 - File: lib/app/main_layout.dart
 - Changes:
   - Replace Drawer and AppBar in _buildNarrowLayout with a refined custom navigation system.
   - Implement AnimatedSwitcher for seamless transitions between wide and narrow modes.
   - Add hover states and subtle animations to SidebarItem.

 4. Dashboard Overhaul

 Create a high-value, minimal companion view.
 - File: lib/features/companion/presentation/companion_dashboard.dart
 - Changes:
   - Integrate AnimatedNumber (in lib/shared/widgets/animated_number.dart) for the Health Score and Streak.
   - Implement a "Score Breakdown" section to explain how the health score is calculated.
   - Transition from a simple list to a structured, responsive grid for analytics and wellness cards.
   - Refine _buildMainStatus for a more integrated, low-profile timer.

 5. Data Visualization Upgrade

 Connect charts to real-time data and improve their visual quality.
 - Files:
   - lib/features/analytics/presentation/widgets/productivity_trend_chart.dart
   - lib/features/analytics/widgets/stats_chart.dart
   - lib/features/analytics/stats_service.dart
       - lib/features/analytics/widgets/stats_chart.dart
       - lib/features/analytics/stats_service.dart
     - Changes:
       - Bind ProductivityTrendChart to StatsService.getWeeklyStats(), replacing hardcoded data.
       - Add X-axis labels (day names) and a "Target Productivity" reference band.
       - Implement custom tooltips for data points in both charts.
       - Smooth out line curves and gradient fills.

     6. Micro-interactions and Polish

     Add the "final 10%" of polish that makes an app feel premium.
     - File: lib/features/companion/presentation/companion_dashboard.dart
     - Changes:
       - Add staggered fade-in/slide-up animations for dashboard cards.
       - Implement subtle scale and brightness shifts on card hover.
       - Add a "press-down" effect to action buttons.

     Verification Plan

     1. Window Scaling: Resize the window from 1100px down to 400px to ensure the layout transition is smooth and
     no elements overlap.
     2. Data Accuracy: Verify that the productivity trend chart reflects actual weekly data from the StatsService.
     3. Interaction Check: Hover and click on all dashboard elements to ensure micro-interactions feel responsive
     and natural.
     4. Theme Audit: Compare the new "subtle glass" look against macOS system apps to ensure the feel is native.

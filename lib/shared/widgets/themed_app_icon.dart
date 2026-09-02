import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/config/flavor_config.dart';
import 'package:breakmate/features/themes/application/theme_controller.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// A widget that renders the BreakMate app SVG icon and dynamically updates
/// its colors whenever the active theme or custom accent color changes.
class ThemedAppIcon extends StatelessWidget {
  /// The SVG path data for the right wing/glyph of the logo.
  static const String rightGlyphPath =
      'M357.628 91.0922C364.647 90.5834 372.098 92.4897 378.499 95.328'
      'C382.966 97.3599 387.094 100.065 390.741 103.348C397.556 109.388 401.336 115.988 404.035 124.709'
      'C405.086 128.105 405.867 131.969 407.059 135.253C409.842 142.989 414.529 149.898 420.686 155.344'
      'C424.991 159.113 431.465 163.038 436.891 164.802C447.378 168.211 454.681 169.296 463.564 176.717'
      'C482.799 192.784 486.279 222.631 469.898 241.959C463.885 249.053 456.03 254.707 454.284 264.567'
      'C452.842 272.538 454.647 280.685 459.871 286.963C464.13 292.083 469.118 296.192 472.82 301.767'
      'C477.067 308.188 479.575 315.602 480.099 323.284C481.758 342.74 471.137 361.173 453.474 369.495'
      'C447.315 372.39 440.675 373.401 434.436 376.036C427.524 378.955 421.304 383.411 416.382 389.08'
      'C412.524 393.565 409.495 398.701 407.435 404.246C403.368 415.082 403.443 422.517 394.649 432.632'
      'C386.515 441.914 375.034 447.592 362.722 448.425C350.313 449.327 338.065 445.189 328.746 436.945'
      'C318.072 427.436 313.329 415.691 312.514 401.679C311.934 388.694 312.429 372.605 312.386 359.366'
      'L312.309 341.001C312.295 337.315 312.157 332.168 312.576 328.602C312.956 325.135 314.014 321.776 315.69 318.717'
      'C321.532 308.104 334.954 303.427 345.967 308.296C350.958 310.502 356.474 313.919 361.278 316.635'
      'L397.434 337.43C397.398 328.807 397.422 320.184 397.505 311.561C387.169 305.074 376.389 299.214 365.848 293.068'
      'C362.933 291.369 359.818 289.666 357.19 287.564C355.06 285.868 353.267 283.789 351.902 281.434'
      'C348.645 275.917 347.896 270.669 349.368 264.387C352.116 252.657 362.704 248.703 371.967 242.984'
      'C374.969 241.131 378.278 239.467 381.382 237.729C386.775 234.679 392.127 231.559 397.439 228.37'
      'L397.459 202.324C394.744 203.687 391.339 205.856 388.573 207.396C379.618 212.321 370.739 217.382 361.939 222.579'
      'C356.922 225.503 352.099 228.448 346.881 231.018C331.374 238.653 313.638 227.804 312.607 210.75'
      'C312.349 206.474 312.384 202.374 312.383 198.079L312.38 177.642L312.337 153.225'
      'C312.326 145.528 312.057 135.965 313.685 128.567C315.302 121.152 318.683 114.236 323.54 108.404'
      'C332.598 97.5941 343.76 92.3166 357.628 91.0922Z';

  /// The SVG path data for the left wing/glyph of the logo.
  static const String leftGlyphPath =
      'M239.134 90.7796C247.882 90.0146 254.858 91.1847 262.86 94.8834'
      'C274.501 100.31 283.487 110.169 287.817 122.261C289.244 126.174 290.172 130.251 290.579 134.396'
      'C291.091 139.881 290.991 146.368 290.97 151.921L290.874 175.077L290.894 196.664'
      'C290.901 203.8 291.495 212.748 288.399 219.245C285.516 225.177 280.37 229.701 274.118 231.8'
      'C261.378 236.153 252.494 227.839 241.882 222.217C229.868 215.852 218.164 207.961 205.989 201.989'
      'C205.636 210.333 205.811 219.42 205.831 227.827C214.395 233.002 223.362 237.737 231.935 242.93'
      'C236.947 246.225 243.754 248.999 247.854 253.429C253.841 259.897 255.924 268.16 253.15 276.467'
      'C249.552 287.237 241.641 290.119 232.789 295.277L215.866 305.155C212.592 307.023 208.329 309.064 205.776 311.752'
      'C205.613 320.103 205.805 328.491 205.807 336.854C211.755 334.077 218.122 329.962 223.895 326.73'
      'C229.985 323.32 236.071 319.845 242.092 316.348C246.107 314.016 254.386 308.959 258.391 307.434'
      'C261.005 306.459 263.776 305.973 266.566 306.002C277.432 306.099 287.761 313.347 289.933 323.994'
      'C291.534 331.847 290.91 343.633 290.914 351.908L290.919 394.166C290.752 407.449 290.008 416.525 281.961 427.988'
      'C274.945 437.984 263.007 445.895 250.79 447.704C230.315 450.744 210.277 439.963 201.53 421.201'
      'C199.833 417.646 198.405 413.058 197.483 409.201C194.435 396.463 186.491 385.873 175.39 378.916'
      'C164.561 372.13 152.399 372.677 142.075 364.443C131.403 355.931 125.14 346.298 123.252 332.56'
      'C121.448 319.516 125.437 306.336 134.171 296.482C137.403 292.802 141.36 289.637 144.277 285.745'
      'C151.81 275.695 150.753 259.704 142.014 250.68C139.435 248.017 136.688 245.572 134.234 242.775'
      'C114.16 219.909 121.89 183.232 149.228 170.079C156.427 166.615 164.554 165.496 171.803 162.037'
      'C177.459 159.337 182.156 155.623 186.398 151.038C191.209 145.776 194.77 139.495 196.817 132.665'
      'C199.687 122.866 200.533 117.407 207.262 108.742C215.091 98.7724 226.552 92.3132 239.134 90.7796Z';

  /// Total width/height of the widget.
  final double size;

  /// Explicit icon color override. If null, uses [AppTheme.accentColor].
  final Color? color;

  /// Explicit background color override for container/badge mode.
  final Color? backgroundColor;

  /// Whether to render a styled container badge around the icon.
  final bool isBadge;

  /// Optional custom size for the inner icon when [isBadge] is true.
  final double? innerIconSize;

  /// Custom border radius for badge mode.
  final BorderRadius? borderRadius;

  /// Custom box shadow for badge mode.
  final List<BoxShadow>? shadows;

  /// Whether to show the DEV badge overlay in dev flavor.
  final bool showDevBadge;

  const ThemedAppIcon({
    super.key,
    this.size = 60,
    this.color,
    this.backgroundColor,
    this.isBadge = false,
    this.innerIconSize,
    this.borderRadius,
    this.shadows,
    this.showDevBadge = false,
  });

  /// Factory for a styled badge container (like in MainLayout sidebar and About section).
  const ThemedAppIcon.badge({
    super.key,
    this.size = 72,
    double? iconSize,
    this.color,
    this.backgroundColor,
    this.borderRadius,
    this.shadows,
    this.showDevBadge = true,
  })  : isBadge = true,
        innerIconSize = iconSize ?? (size * 0.58);

  static String generateSvgString({required Color color}) {
    final hex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    return '<svg xmlns="http://www.w3.org/2000/svg" width="599" height="554" viewBox="0 0 599 554">'
        '<path fill="$hex" d="$rightGlyphPath"/>'
        '<path fill="$hex" d="$leftGlyphPath"/>'
        '</svg>';
  }

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes if ThemeController is available in context
    Color resolvedAccent = color ?? AppTheme.accentColor;
    try {
      final themeCtrl = context.watch<ThemeController?>();
      if (themeCtrl != null && color == null) {
        resolvedAccent = themeCtrl.activeAccent;
      }
    } catch (_) {
      // Fallback to static AppTheme.accentColor
    }

    final effectiveColor = resolvedAccent;
    final effectiveBg = backgroundColor ?? AppTheme.surfaceElevated;
    final radius = borderRadius ?? BorderRadius.circular(size * 0.1);

    final iconWidget = TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: effectiveColor, end: effectiveColor),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, animatedColor, _) {
        final currentColor = animatedColor ?? effectiveColor;
        return SvgPicture.string(
          generateSvgString(color: currentColor),
          width: isBadge ? (innerIconSize ?? size * 0.58) : size,
          height: isBadge ? (innerIconSize ?? size * 0.58) : size,
          fit: BoxFit.contain,
        );
      },
    );

    if (!isBadge) {
      return SizedBox(
        width: size,
        height: size,
        child: iconWidget,
      );
    }

    bool isDev = false;
    if (showDevBadge) {
      try {
        isDev = FlavorConfig.isDevelopment;
      } catch (_) {
        isDev = false;
      }
    }

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: effectiveColor, end: effectiveColor),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, animatedAccent, _) {
        final accent = animatedAccent ?? effectiveColor;
        final defaultShadows = [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.20),
                accent.withValues(alpha: 0.05),
              ],
            ),
            boxShadow: shadows ?? defaultShadows,
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background surface
                Container(
                  color: effectiveBg.withValues(alpha: 0.85),
                ),
                // Themed SVG logo
                Center(child: iconWidget),
                // Dev badge if development flavor
                // if (isDev)
                //   Positioned(
                //     bottom: 2,
                //     right: 4,
                //     child: Container(
                //       padding: const EdgeInsets.symmetric(
                //         horizontal: 4,
                //         vertical: 1,
                //       ),
                //       decoration: BoxDecoration(
                //         color: const Color(0xFFEF4444),
                //         borderRadius: BorderRadius.circular(4),
                //       ),
                //       child: const Text(
                //         'DEV',
                //         style: TextStyle(
                //           color: Colors.white,
                //           fontSize: 8,
                //           fontWeight: FontWeight.bold,
                //           letterSpacing: 0.5,
                //         ),
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
        );
      },
    );
  }
}

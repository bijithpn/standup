# Design System Usage Guide

Quick reference for using the new BreakMate design system.

---

## Colors

### Using Colors
```dart
import 'package:standup/shared/theme/app_theme.dart';

// Primary colors
Container(color: AppTheme.primary)
Container(color: AppTheme.primaryLight)
Container(color: AppTheme.primaryDark)

// Break colors
Container(color: AppTheme.shortBreak)  // Cyan
Container(color: AppTheme.longBreak)   // Purple

// Surfaces
Container(color: AppTheme.surface)          // Main background
Container(color: AppTheme.surfaceCard)      // Cards
Container(color: AppTheme.surfaceElevated)  // Elevated elements

// Text
Text('Hello', style: TextStyle(color: AppTheme.textPrimary))
Text('Hello', style: TextStyle(color: AppTheme.textSecondary))
Text('Hello', style: TextStyle(color: AppTheme.textMuted))

// Semantic
Container(color: AppTheme.success)  // Green
Container(color: AppTheme.warning)  // Amber
Container(color: AppTheme.error)    // Red
Container(color: AppTheme.info)     // Blue
```

---

## Typography

### Using Text Styles
```dart
// Display (large timer)
Text(
  '05:00',
  style: TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w200,
    color: AppTheme.textPrimary,
  ),
)

// Title
Text(
  'Rest Your Eyes',
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
  ),
)

// Body
Text(
  'Look at something 20 feet away',
  style: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppTheme.textSecondary,
  ),
)

// Caption
Text(
  'EYE REST',
  style: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppTheme.shortBreak,
    letterSpacing: 1.2,
  ),
)
```

---

## Icons

### Using Lucide Icons
```dart
import 'package:lucide_icons/lucide_icons.dart';

// Common icons
Icon(LucideIcons.eye, size: 16, color: AppTheme.shortBreak)
Icon(LucideIcons.coffee, size: 16, color: AppTheme.longBreak)
Icon(LucideIcons.clock, size: 16, color: AppTheme.warning)
Icon(LucideIcons.wind, size: 16, color: AppTheme.longBreak)
Icon(LucideIcons.zap, size: 16, color: AppTheme.success)
Icon(LucideIcons.target, size: 16, color: AppTheme.info)
Icon(LucideIcons.chevronRight, size: 14, color: AppTheme.textSecondary)
Icon(LucideIcons.quote, size: 16, color: AppTheme.textMuted)
```

---

## Containers

### Card Container
```dart
Container(
  decoration: AppTheme.cardDecoration(),
  padding: EdgeInsets.all(24),
  child: YourWidget(),
)

// Elevated card
Container(
  decoration: AppTheme.cardDecoration(elevated: true),
  padding: EdgeInsets.all(24),
  child: YourWidget(),
)
```

### Glass Effect
```dart
Container(
  decoration: AppTheme.glassDecoration(opacity: 0.05),
  padding: EdgeInsets.all(24),
  child: YourWidget(),
)
```

### Custom Container
```dart
Container(
  decoration: BoxDecoration(
    color: AppTheme.surfaceCard,
    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    border: Border.all(color: AppTheme.borderSubtle),
  ),
  child: YourWidget(),
)
```

---

## Badges

### Break Type Badge
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: AppTheme.shortBreak.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    border: Border.all(
      color: AppTheme.shortBreak.withValues(alpha: 0.2),
    ),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(LucideIcons.eye, size: 12, color: AppTheme.shortBreak),
      SizedBox(width: 6),
      Text(
        'EYE REST',
        style: TextStyle(
          color: AppTheme.shortBreak,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    ],
  ),
)
```

---

## Buttons

### Primary Button
```dart
MouseRegion(
  cursor: SystemMouseCursors.click,
  child: GestureDetector(
    onTap: () {},
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        'Continue',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ),
)
```

### Secondary Button
```dart
MouseRegion(
  cursor: SystemMouseCursors.click,
  child: GestureDetector(
    onTap: () {},
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.gray800,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Skip',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 6),
          Icon(
            LucideIcons.chevronRight,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    ),
  ),
)
```

---

## Progress Indicators

### Circular Progress
```dart
SizedBox(
  width: 240,
  height: 240,
  child: Stack(
    alignment: Alignment.center,
    children: [
      // Background ring
      SizedBox(
        width: 240,
        height: 240,
        child: CircularProgressIndicator(
          value: 1.0,
          strokeWidth: 2,
          color: AppTheme.gray800,
        ),
      ),
      // Progress ring
      SizedBox(
        width: 240,
        height: 240,
        child: CircularProgressIndicator(
          value: 0.75,
          strokeWidth: 2,
          color: AppTheme.shortBreak,
          strokeCap: StrokeCap.round,
        ),
      ),
      // Center content
      Text('05:00'),
    ],
  ),
)
```

### Linear Progress
```dart
Container(
  width: 400,
  height: 4,
  decoration: BoxDecoration(
    color: AppTheme.gray800,
    borderRadius: BorderRadius.circular(2),
  ),
  child: FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: 0.75,
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.shortBreak,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  ),
)
```

---

## Spacing

### Border Radius
```dart
BorderRadius.circular(AppTheme.radiusXs)  // 4px
BorderRadius.circular(AppTheme.radiusSm)  // 8px
BorderRadius.circular(AppTheme.radiusMd)  // 12px
BorderRadius.circular(AppTheme.radiusLg)  // 16px
BorderRadius.circular(AppTheme.radiusXl)  // 24px
```

### Padding
```dart
EdgeInsets.all(8)   // Tight
EdgeInsets.all(12)  // Compact
EdgeInsets.all(16)  // Normal
EdgeInsets.all(24)  // Comfortable
EdgeInsets.all(32)  // Spacious
EdgeInsets.all(48)  // Extra spacious
```

---

## Gradients

### Radial Gradient
```dart
Container(
  decoration: BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.topCenter,
      radius: 1.5,
      colors: [
        AppTheme.shortBreak.withValues(alpha: 0.03),
        AppTheme.gray950,
      ],
    ),
  ),
)
```

### Linear Gradient
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.gray900,
        AppTheme.gray950,
      ],
    ),
  ),
)
```

---

## Shadows

### Card Shadow
```dart
BoxDecoration(
  color: AppTheme.surfaceCard,
  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 40,
      offset: Offset(0, 20),
    ),
  ],
)
```

---

## Complete Examples

### Modal Card
```dart
Container(
  width: 400,
  padding: EdgeInsets.all(32),
  decoration: BoxDecoration(
    color: AppTheme.surfaceElevated,
    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
    border: Border.all(color: AppTheme.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.5),
        blurRadius: 40,
        offset: Offset(0, 20),
      ),
    ],
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Icon
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.clock,
          color: AppTheme.warning,
          size: 28,
        ),
      ),
      SizedBox(height: 24),
      // Title
      Text(
        'Break Starting Soon',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(height: 8),
      // Description
      Text(
        'Time to rest in 20 seconds',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
      ),
    ],
  ),
)
```

### Info Card
```dart
Container(
  padding: EdgeInsets.all(24),
  decoration: AppTheme.cardDecoration(),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(LucideIcons.info, size: 16, color: AppTheme.info),
          SizedBox(width: 8),
          Text(
            'Tip',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      SizedBox(height: 12),
      Text(
        'Look at something 20 feet away for 20 seconds',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    ],
  ),
)
```

---

## Best Practices

### Do ✅
- Use semantic color names (`AppTheme.success` not `Colors.green`)
- Use consistent spacing (8, 12, 16, 24, 32, 48)
- Use border radius constants (`AppTheme.radiusMd`)
- Use Lucide icons for consistency
- Use Inter font family
- Use tabular figures for numbers

### Don't ❌
- Don't use hardcoded colors
- Don't use random spacing values
- Don't mix icon sets
- Don't use heavy blur effects
- Don't use complex gradients
- Don't add unnecessary visual effects

---

## Migration from Old Theme

### Color Changes
```dart
// Old → New
AppTheme.accentColor → AppTheme.primary
AppTheme.sidebarBackground → AppTheme.surface
AppTheme.contentBackground → AppTheme.surface
AppTheme.cardBackground → AppTheme.surfaceCard
AppTheme.shortBreakColor → AppTheme.shortBreak
AppTheme.longBreakColor → AppTheme.longBreak
```

### Icon Changes
```dart
// Old → New
CupertinoIcons.timer → LucideIcons.clock
CupertinoIcons.eye → LucideIcons.eye
CupertinoIcons.wind → LucideIcons.coffee
CupertinoIcons.arrow_right → LucideIcons.chevronRight
```

---

**For more details, see `DESIGN_SYSTEM.md`**

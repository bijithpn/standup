# BreakMate Design System Update

## Overview
Complete redesign of BreakMate with a minimal, modern, and clean aesthetic focused on user-friendliness and premium feel.

---

## Key Changes

### 1. **Typography**
- **Old**: Satoshi font family
- **New**: Inter font family (modern, clean, widely used)
- Weights: Regular (400), Medium (500), SemiBold (600), Bold (700)
- Better readability and professional appearance

### 2. **Icon System**
- **Old**: Material Icons / Cupertino Icons
- **New**: Lucide Icons
- Minimal, consistent, modern icon set
- Perfect match for the new minimal UI theme

### 3. **Color Palette**

#### Primary Colors
- **Primary**: `#6366F1` (Indigo) - Modern, professional
- **Short Break**: `#06B6D4` (Cyan) - Eye rest indicator
- **Long Break**: `#8B5CF6` (Purple) - Deep break indicator

#### Neutral Grays (Dark Mode)
- **Surface**: `#18181B` - Main background
- **Surface Card**: `#1F1F23` - Card backgrounds
- **Surface Elevated**: `#27272A` - Elevated elements
- **Border**: `#3F3F46` - Borders
- **Border Subtle**: `#27272A` - Subtle borders

#### Text Colors
- **Primary**: `#FAFAFA` - Main text
- **Secondary**: `#A1A1AA` - Secondary text
- **Muted**: `#71717A` - Muted text

#### Semantic Colors
- **Success**: `#10B981` (Green)
- **Warning**: `#F59E0B` (Amber)
- **Error**: `#EF4444` (Red)
- **Info**: `#3B82F6` (Blue)

### 4. **Border Radius System**
- **XS**: 4px - Small elements
- **SM**: 8px - Buttons, badges
- **MD**: 12px - Cards
- **LG**: 16px - Large containers
- **XL**: 24px - Hero elements

---

## Updated Components

### Break Overlay Templates

#### 1. **Minimal Focus Template**
- Clean centered layout
- Large circular progress ring (240px)
- Minimal timer display with tabular figures
- Subtle radial gradient background
- Badge indicator for break type
- Bottom bar with time and skip button
- **Design**: Ultra-minimal, distraction-free

#### 2. **Zen Mode Template**
- Box breathing animation (16s cycle)
- Pulsing circle with breathing instructions
- Inspirational zen quotes
- Minimal card design
- **Design**: Calm, meditative, focused

#### 3. **Productivity HUD Template**
- Dashboard-style layout
- Large timer (72px, ultra-light weight)
- Horizontal progress bar
- Stats display (Focus, Energy)
- Grid pattern background (subtle)
- **Design**: Information-rich but clean

#### 4. **Pre-Break Warning Overlay**
- Centered modal card
- Warning icon with amber accent
- Clear messaging
- Subtle backdrop blur
- **Design**: Non-intrusive, informative

---

## Installation Steps

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Download Inter Font
Run the batch script:
```bash
cd assets/fonts/Inter
download_font.bat
```

Or download manually from [Google Fonts](https://fonts.google.com/specimen/Inter) and place these files in `assets/fonts/Inter/`:
- Inter-Regular.ttf
- Inter-Medium.ttf
- Inter-SemiBold.ttf
- Inter-Bold.ttf

### 3. Run the App
```bash
flutter run
```

---

## Design Principles

### Minimalism
- Remove unnecessary elements
- Focus on essential information
- Clean whitespace usage
- Subtle visual hierarchy

### Modern Aesthetics
- Contemporary color palette
- Smooth animations
- Consistent spacing
- Professional typography

### User-Friendly
- Clear visual feedback
- Intuitive interactions
- Readable text sizes
- Accessible contrast ratios

### Premium Feel
- Subtle gradients
- Smooth transitions
- Quality typography
- Refined details

---

## File Changes

### Modified Files
1. `pubspec.yaml` - Added lucide_icons, Inter font
2. `lib/shared/theme/app_theme.dart` - Complete redesign
3. `lib/features/break_overlay/presentation/templates/minimal_focus_template.dart`
4. `lib/features/break_overlay/presentation/templates/zen_mode_template.dart`
5. `lib/features/break_overlay/presentation/templates/productivity_hud_template.dart`
6. `lib/features/break_system/presentation/pre_break_warning_overlay.dart`

### New Files
1. `assets/fonts/Inter/README.md` - Font installation guide
2. `assets/fonts/Inter/download_font.bat` - Automated font download script

---

## Usage Examples

### Using the New Theme
```dart
import 'package:standup/shared/theme/app_theme.dart';

// Access colors
AppTheme.primary
AppTheme.textPrimary
AppTheme.shortBreak

// Use card decoration
Container(
  decoration: AppTheme.cardDecoration(),
  child: YourWidget(),
)

// Use glass decoration
Container(
  decoration: AppTheme.glassDecoration(opacity: 0.05),
  child: YourWidget(),
)
```

### Using Lucide Icons
```dart
import 'package:lucide_icons/lucide_icons.dart';

Icon(LucideIcons.eye, size: 16, color: AppTheme.primary)
Icon(LucideIcons.coffee, size: 16, color: AppTheme.longBreak)
Icon(LucideIcons.clock, size: 16, color: AppTheme.warning)
```

---

## Next Steps

1. **Test all templates** - Verify each overlay template displays correctly
2. **Update remaining UI** - Apply new theme to dashboard, settings, etc.
3. **Accessibility audit** - Ensure contrast ratios meet WCAG standards
4. **Performance check** - Verify smooth animations on target devices
5. **User feedback** - Gather feedback on new design

---

## Notes

- The design maintains backward compatibility with existing features
- All animations are optimized for performance
- Color palette supports both light and dark modes (currently dark mode only)
- Typography uses system font fallback if Inter is not available

---

**Design System Version**: 2.0  
**Last Updated**: May 23, 2026  
**Designer**: AI Assistant

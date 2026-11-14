import 'package:breakmate/features/settings/notification_intensity.dart';
import 'first_break_demo.dart';
import 'package:breakmate/features/settings/widgets/notification_intensity_picker.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/break_profile.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/shared/widgets/themed_app_icon.dart';

/// First-run wizard (intro, break profile, strictness, companion); nothing is saved until the last step.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;
  String _goal = 'rhythm';

  // Choices accumulate here and are persisted once in [_finishOnboarding], which also flips hasCompletedOnboarding.
  late SettingsModel _pendingSettings;

  @override
  void initState() {
    super.initState();
    _pendingSettings = NotificationIntensity.balanced.apply(
      _withProfile(sl<SettingsRepository>().currentSettings),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_saving) return;
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _saving = true);
    try {
      await sl<SettingsRepository>().save(
        _pendingSettings.copyWith(hasCompletedOnboarding: true),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save setup. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildIntroStep(),
                _buildBreakProfileStep(),
                _buildStrictnessStep(),
                _buildCompanionStep(),
                _buildDemoStep(),
              ],
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(child: _buildNavigation()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              child: Text(
                'Back',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            const SizedBox(width: 60),

          Expanded(
            child: Center(
              child: FittedBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) => _buildDot(index)),
                ),
              ),
            ),
          ),

          _PrimaryButton(
            onTap: _nextPage,
            label: _saving
                ? 'Saving…'
                : _currentPage == 4
                ? AppStrings.getStarted
                : AppStrings.continueButton,
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.accent : AppTheme.border,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              child,
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroStep() {
    return _buildStepContainer(
      title: AppStrings.welcomeTitle,
      subtitle: AppStrings.welcomeSubtitle,
      child: const ThemedAppIcon.badge(
        size: 120,
        iconSize: 72,
        showDevBadge: false,
      ),
    );
  }

  static const _workOptions = {
    'coding': 'Coding',
    'creative': 'Writing & design',
    'meetings': 'Meetings & calls',
    'study': 'Studying',
  };
  static const _hourOptions = {
    4: 'Under 5 hours',
    6: '5–8 hours',
    9: '8+ hours',
  };

  String _work = 'coding';
  int _hours = 6;

  BreakProfile get _recommendedProfile {
    final id = switch (_goal) {
      'eyes' => 'health',
      'movement' => 'developer',
      'focus' => 'deep_work',
      _ => null,
    };
    return id == null
        ? BreakProfile.recommend(work: _work, hours: _hours)
        : BreakProfile.presets.firstWhere((p) => p.id == id);
  }

  SettingsModel _withProfile(SettingsModel s) {
    final p = _recommendedProfile;
    return s.copyWith(
      selectedProfileId: p.id,
      shortBreakIntervalMinutes: p.shortIntervalMinutes,
      shortBreakDurationSeconds: p.shortDurationSeconds,
      longBreakIntervalMinutes: p.longIntervalMinutes,
      longBreakDurationMinutes: p.longDurationMinutes,
    );
  }

  void _pickProfile({String? work, int? hours}) {
    _work = work ?? _work;
    _hours = hours ?? _hours;
    setState(() => _pendingSettings = _withProfile(_pendingSettings));
  }

  Widget _chips<T>(Map<T, String> options, T selected, ValueChanged<T> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: e.key == selected,
            onSelected: (_) => onTap(e.key),
          ),
      ],
    );
  }

  Widget _buildBreakProfileStep() {
    final p = _recommendedProfile;
    return _buildStepContainer(
      title: AppStrings.chooseRhythm,
      subtitle: AppStrings.rhythmSubtitle,
      child: Column(
        children: [
          Text(
            'What would you like help with?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          _chips(
            const {
              'rhythm': 'A regular rhythm',
              'eyes': 'Eye rest',
              'movement': 'Moving more',
              'focus': 'Longer focus',
            },
            _goal,
            (value) {
              _goal = value;
              _pickProfile();
            },
          ),
          const SizedBox(height: 24),
          Text(
            'What do you mostly do?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          _chips(_workOptions, _work, (v) => _pickProfile(work: v)),
          const SizedBox(height: 24),
          Text(
            'Time at the screen per day',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          _chips(_hourOptions, _hours, (v) => _pickProfile(hours: v)),
          const SizedBox(height: 24),
          _ProfileOption(
            title: '${p.name} (recommended)',
            description:
                'Break every ${p.shortIntervalMinutes} min, '
                'long break every ${p.longIntervalMinutes} min.',
            isSelected: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildStrictnessStep() {
    return _buildStepContainer(
      title: 'How should we remind you?',
      subtitle:
          'Choose warning, sound and display behavior. Change it anytime in Notifications.',
      child: NotificationIntensityPicker(
        settings: _pendingSettings,
        onChanged: (settings) => setState(() => _pendingSettings = settings),
      ),
    );
  }

  Widget _buildDemoStep() => _buildStepContainer(
    title: 'Try your first break',
    subtitle:
        'Practice a 20-second eye rest, or get started now. Your first scheduled break follows your chosen rhythm.',
    child: Column(
      children: [
        Text(
          'Break every ${_pendingSettings.shortBreakIntervalMinutes} minutes · ${_pendingSettings.shortBreakDurationSeconds} seconds',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const FirstBreakDemo(),
          ),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Try a 20-second demo'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Optional. The demo does not count toward your daily goals.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _buildCompanionStep() {
    return _buildStepContainer(
      title: AppStrings.pickBuddy,
      subtitle: AppStrings.buddySubtitle,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PetOption(
            icon: Icons.pets_rounded,
            label: 'Enable Companion',
            isSelected: _pendingSettings.companionEnabled,
            onTap: () => setState(
              () => _pendingSettings = _pendingSettings.copyWith(
                companionEnabled: true,
              ),
            ),
          ),
          const SizedBox(width: 24),
          _PetOption(
            icon: Icons.close_rounded,
            label: 'No Thanks',
            isSelected: !_pendingSettings.companionEnabled,
            onTap: () => setState(
              () => _pendingSettings = _pendingSettings.copyWith(
                companionEnabled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.1)
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppTheme.accent),
          ],
        ),
      ),
    );
  }
}

class _PetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PetOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accent.withValues(alpha: 0.1)
                  : AppTheme.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.accent : AppTheme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _PrimaryButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.accent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_strings.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late SettingsModel _pendingSettings;

  @override
  void initState() {
    super.initState();
    _pendingSettings = sl<SettingsRepository>().currentSettings;
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    // Apply pending settings before completing
    final repo = sl<SettingsRepository>();
    await repo.save(_pendingSettings.copyWith(hasCompletedOnboarding: true));
    // Actually, save already handles notifyListeners, but let's be explicit
    // Rebuild is handled by Consumer in lib/app/app.dart
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
              child: const Text(
                'Back',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            const SizedBox(width: 60),

          Row(children: List.generate(4, (index) => _buildDot(index))),

          _PrimaryButton(
            onTap: _nextPage,
            label: _currentPage == 3
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            child,
            const SizedBox(height: 100), // Space for navigation
          ],
        ),
      ),
    );
  }

  Widget _buildIntroStep() {
    return _buildStepContainer(
      title: AppStrings.welcomeTitle,
      subtitle: AppStrings.welcomeSubtitle,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          size: 64,
          color: AppTheme.accent,
        ),
      ),
    );
  }

  Widget _buildBreakProfileStep() {
    return _buildStepContainer(
      title: AppStrings.chooseRhythm,
      subtitle: AppStrings.rhythmSubtitle,
      child: Column(
        children: [
          _ProfileOption(
            title: 'Balanced',
            description: 'Short break every 20m. Great for eye health.',
            isSelected: _pendingSettings.shortBreakIntervalMinutes == 20,
            onTap: () => setState(
              () => _pendingSettings = _pendingSettings.copyWith(
                shortBreakIntervalMinutes: 20,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ProfileOption(
            title: 'Deep Work',
            description: 'Short break every 45m. For focused sessions.',
            isSelected: _pendingSettings.shortBreakIntervalMinutes == 45,
            onTap: () => setState(
              () => _pendingSettings = _pendingSettings.copyWith(
                shortBreakIntervalMinutes: 45,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ProfileOption(
            title: 'Pomodoro',
            description: 'Break every 25m. The classic productivity cycle.',
            isSelected: _pendingSettings.shortBreakIntervalMinutes == 25,
            onTap: () => setState(
              () => _pendingSettings = _pendingSettings.copyWith(
                shortBreakIntervalMinutes: 25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrictnessStep() {
    return _buildStepContainer(
      title: AppStrings.setBoundaries,
      subtitle: AppStrings.boundariesSubtitle,
      child: Column(
        children: [
          _ProfileOption(
            title: 'Strict Mode',
            description: 'Breaks cannot be skipped. Recommended for results.',
            isSelected: _pendingSettings.strictMode,
            onTap: () => setState(
              () => _pendingSettings = _pendingSettings.copyWith(
                strictMode: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ProfileOption(
            title: 'Gentle Mode',
            description: 'Breaks can be skipped or postponed easily.',
            isSelected: !_pendingSettings.strictMode,
            onTap: () => setState(
              () => _pendingSettings = _pendingSettings.copyWith(
                strictMode: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
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

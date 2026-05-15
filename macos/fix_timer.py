import os
import re

path = '../lib/core/services/timer_engine.dart'
with open(path, 'r') as f:
    content = f.read()

# Add _shortBreaksSinceLongBreak
if 'int _shortBreaksSinceLongBreak = 0;' not in content:
    content = content.replace('int _countdownSeconds = 0;', 'int _countdownSeconds = 0;\n  int _shortBreaksSinceLongBreak = 0;')

# Modify _triggerBreak
new_trigger = """  void _triggerBreak() {
    _state = TimerState.breakActive;
    _workElapsed = Duration.zero;
    
    final settings = _settingsRepository.currentSettings;
    
    // Every 4th break is a long break
    bool isLongBreak = _shortBreaksSinceLongBreak >= 3;
    
    if (isLongBreak) {
      _countdownSeconds = settings.longBreakDurationMinutes * 60;
      _activeBreak = BreakModel(
        type: BreakType.long,
        durationSeconds: _countdownSeconds,
        title: 'LONG BREAK',
        tip: 'Time to stand, stretch, and mentally reset. Step away from your desk.',
      );
      _shortBreaksSinceLongBreak = 0;
    } else {
      final suggestedDuration = _adaptiveBreakService?.getSuggestedBreakDuration() ?? 
          settings.shortBreakDurationSeconds;
          
      _countdownSeconds = suggestedDuration;
      _activeBreak = BreakModel(
        type: BreakType.short,
        durationSeconds: _countdownSeconds,
        title: 'Rest Time',
        tip: _randomTip(AppConstants.shortBreakTips),
      );
      _shortBreaksSinceLongBreak++;
    }

    _notificationService.showBreakStarted(breakTitle: _activeBreak!.title);
    _logger.info('Break triggered: ${_activeBreak!.title}');
  }"""

content = re.sub(r'  void _triggerBreak\(\)\s*\{(?:[^{}]*|\{(?:[^{}]*|\{[^{}]*\})*\})*\}', new_trigger, content, flags=re.DOTALL)

with open(path, 'w') as f:
    f.write(content)

part of 'break_appearance_settings.dart';

const _soundscapeLabels = {
  'silence': 'Silence',
  'rain': 'Rain',
  'ocean': 'Ocean',
  'forest': 'Forest',
};

const _displayModeLabels = {
  'compact': 'Compact',
  'immersive': 'Immersive',
  'automatic': 'Automatic',
};

const _cornerLabels = {
  'topLeft': 'Top left',
  'topRight': 'Top right',
  'bottomLeft': 'Bottom left',
  'bottomRight': 'Bottom right',
};

String _intensityLabel(double v) => v < 0.34
    ? 'Subtle'
    : v < 0.67
    ? 'Balanced'
    : 'Expressive';

Widget _labelledDropdown(
  String label,
  String value,
  Map<String, String> options,
  ValueChanged<String> onChanged,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      AppDropdown<String>(
        value: value,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: [
          for (final e in options.entries)
            AppDropdownItem<String>(value: e.key, label: e.value),
        ],
      ),
    ],
  ),
);

extension _BreakAppearanceSections on _BreakAppearanceSettingsState {
  List<Widget> _buildControls() {
    final s = widget.settings;
    final intensity = _intensity ?? s.motionIntensity;
    return [
      sectionHeader('Motion and sound'),
      buildCard([
        sliderRow(
          'Motion intensity · ${_intensityLabel(intensity)}',
          intensity,
          (v) => _setDrag(intensity: v),
          onChangeEnd: (v) {
            _setDrag();
            widget.onSave(s.copyWith(motionIntensity: v));
          },
        ),
        divider(),
        _labelledDropdown(
          'Soundscape',
          s.soundscape,
          _soundscapeLabels,
          (v) => widget.onSave(s.copyWith(soundscape: v)),
        ),
        if (s.soundscape != Soundscape.silence.name) ...[
          divider(),
          sliderRow(
            'Soundscape volume',
            _volume ?? s.soundscapeVolume,
            (v) => _setDrag(volume: v),
            onChangeEnd: (v) {
              _setDrag();
              widget.onSave(s.copyWith(soundscapeVolume: v));
            },
          ),
        ],
      ]),
      sectionHeader('Display'),
      buildCard([
        _labelledDropdown(
          'Display mode',
          s.breakDisplayMode,
          _displayModeLabels,
          (v) => widget.onSave(s.copyWith(breakDisplayMode: v)),
        ),
        if (s.breakDisplayMode == BreakDisplayMode.automatic.name) ...[
          divider(),
          toggleRow(
            'Use full screen for long breaks',
            'Short breaks stay compact',
            s.longBreaksImmersive,
            (v) => widget.onSave(s.copyWith(longBreaksImmersive: v)),
          ),
        ],
        divider(),
        toggleRow(
          'Follow the time of day',
          'Colors warm slightly in the evening',
          s.adaptToTimeOfDay,
          (v) => widget.onSave(s.copyWith(adaptToTimeOfDay: v)),
        ),
        divider(),
        SettingsField(
          title: 'Compact corner',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _cornerLabels.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: s.compactCorner == e.key,
                  onSelected: (_) =>
                      widget.onSave(s.copyWith(compactCorner: e.key)),
                ),
            ],
          ),
        ),
      ]),
      sectionHeader('Break preferences'),
      buildCard([
        toggleRow(
          'Completion chime',
          '',
          s.breakChimeEnabled,
          (v) => widget.onSave(s.copyWith(breakChimeEnabled: v)),
        ),
      ]),
    ];
  }
}

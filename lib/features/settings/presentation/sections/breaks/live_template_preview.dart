part of 'break_appearance_settings.dart';

class _LiveTemplatePreview extends StatefulWidget {
  final String id;
  final SettingsModel? settings;

  const _LiveTemplatePreview({required this.id, this.settings});

  @override
  State<_LiveTemplatePreview> createState() => _LiveTemplatePreviewState();
}

class _LiveTemplatePreviewState extends State<_LiveTemplatePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kenBurnsController;

  static const _previewBreak = BreakModel(
    type: BreakType.short,
    durationSeconds: 60,
    title: 'Rest Your Eyes',
    tip: 'Look 20 feet away for 20 seconds.',
  );
  static const _fallbackPreviewSettings = SettingsModel(strictMode: true);

  @override
  void initState() {
    super.initState();
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void dispose() {
    _kenBurnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSettings = widget.settings ?? _fallbackPreviewSettings;

    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: double.infinity,
          height: 120,
          child: LayoutBuilder(
            builder: (context, c) {
              // Lay the template out at its design width but with the
              // thumbnail's aspect ratio, so nothing is cropped at the edges.
              const designWidth = 1280.0;
              final aspect = c.maxHeight / c.maxWidth;
              return FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: designWidth,
                  height: designWidth * aspect,
                  child: BreakPreviewScope(
                    child: BreakTemplateSwitcher(
                      breakTemplate: widget.id,
                      breakInfo: _previewBreak,
                      settings: effectiveSettings,
                      // ~35 % elapsed: a representative mid-break frame.
                      remaining: 39,
                      total: 60,
                      onSkip: null,
                      currentTemplate: '',
                      kenBurnsController: _kenBurnsController,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

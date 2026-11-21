part of 'break_appearance_settings.dart';

const _cardHeight = 232.0;
const _previewHeight = 128.0;

class _TemplateCard extends StatefulWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final WellnessTemplate template;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final selected = widget.selected;
    final Widget preview = widget.compact
        ? t.preview(context, compact: true)
        : FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1280,
              height: 720,
              child: t.preview(context, compact: false),
            ),
          );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TapTarget(
        semanticLabel: '${t.name}. ${t.description}',
        selected: selected,
        onTap: widget.onTap,
        child: Container(
          height: _cardHeight,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.contentBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.accentColor
                  : _hovered
                  ? AppTheme.textSecondary.withValues(alpha: 0.5)
                  : AppTheme.borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _previewHeight,
                width: double.infinity,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColoredBox(
                        color: t.palette.canvas,
                        child: RepaintBoundary(child: preview),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      size: 16,
                      color: AppTheme.accentColor,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  t.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _TemplateGallery on _BreakAppearanceSettingsState {
  Widget _buildGallery() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 280,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      mainAxisExtent: _cardHeight,
    ),
    itemCount: wellnessTemplates.length,
    itemBuilder: (_, i) {
      final t = wellnessTemplates[i];
      return _TemplateCard(
        template: t,
        selected: t.id == _selectedTemplateId,
        compact: _compactPreview,
        onTap: () => _select(t.id),
      );
    },
  );

  Widget _buildLivePreview(BuildContext context) {
    final t = wellnessTemplateById(_selectedTemplateId);
    final s = widget.settings;
    final tier = resolveTier(
      animationsEnabled: s.enableAnimations,
      reduceMotionPref: s.reduceMotion,
      osReduce: MediaQuery.disableAnimationsOf(context),
    );
    final session = BreakSession(
      totalSeconds: 300,
      remainingSeconds: 195,
      startedAtMs: _liveStartMs,
      tier: tier,
      intensity: _intensity ?? s.motionIntensity,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.contentBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: MotionScope(
            startedAtMs: _liveStartMs,
            tier: tier,
            builder: (c, clock) => _compactPreview
                ? Align(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: AspectRatio(
                        aspectRatio: 340 / 244,
                        child: CompactBreakCard(
                          template: t,
                          session: session,
                          clock: clock,
                        ),
                      ),
                    ),
                  )
                : AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: 1280,
                          height: 720,
                          child: t.immersive(c, session, clock),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

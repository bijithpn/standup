part of 'avatar_customizer_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Preview
// ─────────────────────────────────────────────────────────────────────────────

class _StudioPreview extends StatelessWidget {
  const _StudioPreview({
    required this.definition,
    required this.engine,
    required this.backdrop,
    required this.onBackdropChanged,
    required this.onRandomize,
    required this.onReset,
  });

  final AvatarDefinition definition;
  final PetBehaviorEngine engine;
  final Color backdrop;
  final ValueChanged<Color> onBackdropChanged;
  final VoidCallback onRandomize;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              // The engine works in whatever space its viewport is given. Here
              // that is the preview's own box, so local pointer positions can
              // be fed straight in.
              engine.setViewport(Rect.fromLTWH(0, 0, width, height));
              final stageSize = math.min(width, height) * 0.62;

              return MouseRegion(
                onHover: (event) => engine.pointerMoved(event.localPosition),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: ColoredBox(
                        color: backdrop == kSceneAuthoredBackground
                            ? AppTheme.gray950
                            : backdrop,
                      ),
                    ),
                    Center(
                      child: AnimatedBuilder(
                        animation: engine,
                        builder: (context, _) => PetStage(
                          snapshot: engine.snapshot,
                          size: stageSize,
                          definition: definition,
                          background: backdrop,
                          showShadow: false,
                          onTap: engine.pet,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: AnimatedBuilder(
                        animation: engine,
                        builder: (context, _) =>
                            _ActivityChip(label: engine.snapshot.activity.name),
                      ),
                    ),
                    const Positioned(
                      right: 16,
                      bottom: 16,
                      child: _PreviewHint(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _PreviewToolbar(
          backdrop: backdrop,
          onBackdropChanged: onBackdropChanged,
          onRandomize: onRandomize,
          onReset: onReset,
        ),
      ],
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHint extends StatelessWidget {
  const _PreviewHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: const Text(
        'Move your cursor to get its attention · click to pet',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({
    required this.backdrop,
    required this.onBackdropChanged,
    required this.onRandomize,
    required this.onReset,
  });

  final Color backdrop;
  final ValueChanged<Color> onBackdropChanged;
  final VoidCallback onRandomize;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'BACKDROP',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          for (final color in _backdrops) ...<Widget>[
            _BackdropSwatch(
              color: color,
              isSelected: color.toARGB32() == backdrop.toARGB32(),
              onTap: () => onBackdropChanged(color),
            ),
            const SizedBox(width: 6),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 15),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: onRandomize,
            icon: const Icon(Icons.shuffle_rounded, size: 15),
            label: const Text('Surprise me'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accent,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropSwatch extends StatelessWidget {
  const _BackdropSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

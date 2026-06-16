import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

// Displays a single selectable thumbnail for an asset path.
// Loads the image asynchronously and renders it pixel-perfect.
class AssetPickerTile extends StatefulWidget {
  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;
  // Optional label shown below the thumbnail (derived from filename if absent).
  final String? label;

  const AssetPickerTile({
    super.key,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
    this.label,
  });

  @override
  State<AssetPickerTile> createState() => _AssetPickerTileState();
}

class _AssetPickerTileState extends State<AssetPickerTile> {
  ui.Image? _image;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load(widget.assetPath);
  }

  @override
  void didUpdateWidget(covariant AssetPickerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _image = null;
      _load(widget.assetPath);
    }
  }

  Future<void> _load(String path) async {
    if (path == 'none') return;
    if (_loading) return;
    _loading = true;
    try {
      // Use cached sync accessor first to avoid async delay for already-cached images.
      final cached = PetAssetLoader.getImageSync(path);
      if (cached != null) {
        if (mounted) setState(() => _image = cached);
        return;
      }
      final img = await PetAssetLoader.loadImage(path);
      if (mounted) setState(() => _image = img);
    } catch (_) {
      // Image will remain null; fallback placeholder renders instead.
    } finally {
      _loading = false;
    }
  }

  String _deriveLabel() {
    if (widget.assetPath == 'none') return 'None';
    if (widget.label != null) return widget.label!;
    final raw = widget.assetPath.split('/').last;
    final noExt = raw.contains('.')
        ? raw.substring(0, raw.lastIndexOf('.'))
        : raw;
    return noExt.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 72,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.12)
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.18),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF111113),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(7),
                ),
              ),
              child: _buildThumbnail(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 5, 4, 6),
              child: Text(
                _deriveLabel(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontFamily: 'Inter',
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (widget.assetPath == 'none') {
      return Center(
        child: Icon(
          Icons.block_outlined,
          size: 20,
          color: widget.isSelected ? AppTheme.accent : AppTheme.textMuted,
        ),
      );
    }
    if (_image != null) {
      final cfg = EnvironmentAssetCatalogue.findByPath(widget.assetPath);
      if (cfg != null && cfg.isSpriteSheet) {
        final int frameToShow = cfg.frameCount > 1
            ? (cfg.frameCount / 2).floor()
            : 0;
        final double srcX = cfg.srcX + (frameToShow * cfg.spriteWidth);
        final src = Rect.fromLTWH(
          srcX,
          cfg.srcY,
          cfg.spriteWidth,
          cfg.spriteHeight,
        );
        return SizedBox.expand(
          child: CustomPaint(
            painter: _SpritesheetPainter(image: _image!, srcRect: src),
          ),
        );
      }
      return RawImage(
        image: _image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      );
    }
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppTheme.textMuted,
          ),
        ),
      );
    }
    // Placeholder for assets that failed to load.
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 20,
        color: AppTheme.textMuted,
      ),
    );
  }
}

class _SpritesheetPainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;

  const _SpritesheetPainter({required this.image, required this.srcRect});

  @override
  void paint(Canvas canvas, Size size) {
    final double srcWidth = srcRect.width;
    final double srcHeight = srcRect.height;

    final double scaleX = size.width / srcWidth;
    final double scaleY = size.height / srcHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double drawWidth = srcWidth * scale;
    final double drawHeight = srcHeight * scale;

    final double dx = (size.width - drawWidth) / 2;
    final double dy = (size.height - drawHeight) / 2;

    final dstRect = Rect.fromLTWH(dx, dy, drawWidth, drawHeight);
    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant _SpritesheetPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.srcRect != srcRect;
  }
}

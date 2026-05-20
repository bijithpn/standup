import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:standup/features/companion/domain/animation_row_config.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';

class CatAssetLoader {
  // Cache decoded images to prevent multiple loads of the same file
  static final Map<String, ui.Image> _imageCache = {};

  /// Loads a native Flutter ui.Image from the root assets bundle.
  static Future<ui.Image> _loadImage(String path) async {
    if (_imageCache.containsKey(path)) {
      return _imageCache[path]!;
    }
    try {
      final ByteData data = await rootBundle.load(path);
      final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo fi = await codec.getNextFrame();
      _imageCache[path] = fi.image;
      return fi.image;
    } catch (e) {
      throw Exception('Failed to load cat asset: $path, error: $e');
    }
  }

  /// Extracts the idle frame of the selected companion as a PNG file and returns its absolute path.
  static Future<String> extractCatIconPath(CatTheme theme) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/bm_selected_cat_${theme.id}.png');

    // If already extracted, return cached path
    if (await file.exists()) {
      return file.path;
    }

    try {
      ui.Image sourceImage;
      double size = theme.spriteSize.toDouble();
      double sourceX = 0;
      double sourceY = 0;

      if (theme.type == CatType.composite) {
        sourceImage = await _loadImage(theme.basePath);
        final config = theme.animations[CatAnimationState.idle];
        double row = config is AnimationRowConfig ? config.row.toDouble() : 1.0;
        sourceY = row * size;
      } else {
        final config = theme.animations[CatAnimationState.idle];
        final String fileName = config is SeparateAnimationConfig ? config.fileName : 'idle.png';
        sourceImage = await _loadImage('${theme.basePath}$fileName');
      }

      const double targetSize = 128.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

      canvas.drawImageRect(
        sourceImage,
        ui.Rect.fromLTWH(sourceX, sourceY, size, size),
        const ui.Rect.fromLTWH(0, 0, targetSize, targetSize),
        paint,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes != null) {
        await file.writeAsBytes(pngBytes.buffer.asUint8List());
        return file.path;
      }
    } catch (e) {
      // Fallback
    }

    return '';
  }

  /// Extracts a specific frame of a companion's animation state as an 18x18 PNG file for the status bar tray.
  static Future<String> extractCatFramePath({
    required CatTheme theme,
    required CatAnimationState state,
    required int frameIndex,
  }) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/bm_frame_${theme.id}_${state.name}_$frameIndex.png');

    if (await file.exists()) {
      return file.path;
    }

    try {
      ui.Image sourceImage;
      double size = theme.spriteSize.toDouble();
      double sourceX = 0;
      double sourceY = 0;

      if (theme.type == CatType.composite) {
        sourceImage = await _loadImage(theme.basePath);
        final config = theme.animations[state] ?? theme.animations[CatAnimationState.idle];
        double row = config is AnimationRowConfig ? config.row.toDouble() : 1.0;
        sourceY = row * size;
        sourceX = frameIndex * size;
      } else {
        final config = theme.animations[state] ?? theme.animations[CatAnimationState.idle];
        final String fileName = config is SeparateAnimationConfig ? config.fileName : 'idle.png';
        sourceImage = await _loadImage('${theme.basePath}$fileName');
        sourceX = frameIndex * size;
      }

      // Check boundaries
      if (sourceX + size > sourceImage.width) {
        sourceX = 0;
      }

      const double targetSize = 18.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

      canvas.drawImageRect(
        sourceImage,
        ui.Rect.fromLTWH(sourceX, sourceY, size, size),
        const ui.Rect.fromLTWH(0, 0, targetSize, targetSize),
        paint,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes != null) {
        await file.writeAsBytes(pngBytes.buffer.asUint8List());
        return file.path;
      }
    } catch (e) {
      // Fallback
    }

    return '';
  }

  /// Clears the asset cache when changing themes or shutting down.
  static void clearCache() {
    _imageCache.clear();
  }

  /// Slices and returns all animation state mappings for the given CatTheme.
  static Future<Map<CatAnimationState, SpriteAnimation>> loadAnimations(CatTheme theme) async {
    try {
      final Map<CatAnimationState, SpriteAnimation> loaded = {};

      if (theme.type == CatType.composite) {
        // Composite: All animations live on a single sheet
        final ui.Image sheetImage = await _loadImage(theme.basePath);
        final double size = theme.spriteSize.toDouble();

        for (final state in CatAnimationState.values) {
          // Fallback to idle if animation isn't registered
          final config = theme.animations[state] ?? theme.animations[CatAnimationState.idle];
          if (config is AnimationRowConfig) {
            final data = SpriteAnimationData.sequenced(
              amount: config.frameCount,
              stepTime: config.stepTime,
              textureSize: Vector2(size, size),
              texturePosition: Vector2(0.0, config.row * size),
              loop: config.loop,
            );
            loaded[state] = SpriteAnimation.fromFrameData(sheetImage, data);
          }
        }
      } else if (theme.type == CatType.separate) {
        // Separate: Each animation state points to a unique image file
        final double size = theme.spriteSize.toDouble();

        for (final state in CatAnimationState.values) {
          final config = theme.animations[state] ?? theme.animations[CatAnimationState.idle];
          if (config is SeparateAnimationConfig) {
            final String fullPath = '${theme.basePath}${config.fileName}';
            try {
              final ui.Image stateImage = await _loadImage(fullPath);
              final data = SpriteAnimationData.sequenced(
                amount: config.frameCount,
                stepTime: config.stepTime,
                textureSize: Vector2(size, size),
                texturePosition: Vector2.zero(),
                loop: config.loop,
              );
              loaded[state] = SpriteAnimation.fromFrameData(stateImage, data);
            } catch (e) {
              final fallbackConfig = theme.animations[CatAnimationState.idle] as SeparateAnimationConfig;
              final String fallbackPath = '${theme.basePath}${fallbackConfig.fileName}';
              final ui.Image fallbackImage = await _loadImage(fallbackPath);
              final data = SpriteAnimationData.sequenced(
                amount: fallbackConfig.frameCount,
                stepTime: fallbackConfig.stepTime,
                textureSize: Vector2(size, size),
                texturePosition: Vector2.zero(),
                loop: fallbackConfig.loop,
              );
              loaded[state] = SpriteAnimation.fromFrameData(fallbackImage, data);
            }
          }
        }
      }

      return loaded;
    } catch (_) {
      if (theme.id == CatTheme.keyGreyCat) {
        return {};
      }
      return loadAnimations(CatTheme.getTheme(CatTheme.keyGreyCat));
    }
  }
}

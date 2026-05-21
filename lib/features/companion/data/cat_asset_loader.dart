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

  /// Loads a static asset file, auto-crops, resizes to targetSize x targetSize (default 44.0 px @2x template)
  /// with template-white color filter, and writes to target path.
  static Future<String> extractAndWhitenAsset(String assetPath, String outputPath, {double targetSize = 44.0}) async {
    try {
      final file = File(outputPath);
      if (await file.exists()) {
        return file.path;
      }
      
      final sourceImage = await _loadImage(assetPath);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..colorFilter = const ui.ColorFilter.mode(
          ui.Color(0xFFFFFFFF),
          ui.BlendMode.srcIn,
        );

      final rawBytes = await sourceImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      int minX = sourceImage.width;
      int maxX = 0;
      int minY = sourceImage.height;
      int maxY = 0;

      if (rawBytes != null) {
        final bytes = rawBytes.buffer.asUint8List();
        final width = sourceImage.width;
        final height = sourceImage.height;

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final offset = (y * width + x) * 4;
            if (offset + 3 < bytes.length) {
              final alpha = bytes[offset + 3];
              if (alpha > 10) { // Ignore transparent pixels
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
              }
            }
          }
        }
      }

      double contentWidth = (maxX - minX + 1).toDouble();
      double contentHeight = (maxY - minY + 1).toDouble();

      if (contentWidth > 0 && contentHeight > 0 && minX <= maxX && minY <= maxY) {
        const double padding = 1.0;
        final double activeSize = targetSize - 2 * padding; // 42.0 px active area

        double drawW, drawH;
        if (contentWidth > contentHeight) {
          drawW = activeSize;
          drawH = activeSize * (contentHeight / contentWidth);
        } else {
          drawH = activeSize;
          drawW = activeSize * (contentWidth / contentHeight);
        }

        final double destX = (targetSize - drawW) / 2.0;
        final double destY = (targetSize - drawH) / 2.0;

        canvas.drawImageRect(
          sourceImage,
          ui.Rect.fromLTWH(minX.toDouble(), minY.toDouble(), contentWidth, contentHeight),
          ui.Rect.fromLTWH(destX, destY, drawW, drawH),
          paint,
        );
      } else {
        canvas.drawImageRect(
          sourceImage,
          ui.Rect.fromLTWH(0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
          ui.Rect.fromLTWH(2.0, 2.0, targetSize - 4.0, targetSize - 4.0),
          paint,
        );
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes != null) {
        await file.writeAsBytes(pngBytes.buffer.asUint8List());
        return file.path;
      }
    } catch (_) {
      try {
        final bytes = await rootBundle.load(assetPath);
        final file = File(outputPath);
        await file.writeAsBytes(bytes.buffer.asUint8List());
        return file.path;
      } catch (_) {}
    }
    return '';
  }

  /// Extracts a specific frame of a companion's animation state as a cropped 44x44 (@2x retina Template) PNG file for the status bar tray.
  static Future<String> extractCatFramePath({
    required CatTheme theme,
    required CatAnimationState state,
    required int frameIndex,
  }) async {
    final tempDir = Directory.systemTemp;
    // Prefix changed to bm_cframe to bypass legacy uncropped files
    final file = File('${tempDir.path}/bm_cframe_${theme.id}_${state.name}_${frameIndex}Template@2x.png');

    if (await file.exists()) {
      return file.path;
    }

    try {
      ui.Image sourceImage;
      double size = theme.spriteSize.toDouble();
      double sourceX = 0;
      double sourceY = 0;
      double cropW = size;
      double cropH = size;

      if (theme.type == CatType.composite) {
        sourceImage = await _loadImage(theme.basePath);
        final config = theme.animations[state] ?? theme.animations[CatAnimationState.idle];
        double row = config is AnimationRowConfig ? config.row.toDouble() : 1.0;
        sourceY = row * size;
        int maxFrames = sourceImage.width ~/ size;
        int safeFrameIndex = maxFrames > 0 ? (frameIndex % maxFrames) : 0;
        sourceX = safeFrameIndex * size;
      } else {
        final config = theme.animations[state] ?? theme.animations[CatAnimationState.idle];
        final String fileName = config is SeparateAnimationConfig ? config.fileName : 'idle.png';
        sourceImage = await _loadImage('${theme.basePath}$fileName');

        int frameCount = 1;
        if (config is SeparateAnimationConfig) {
          frameCount = config.frameCount;
        }
        double frameWidth = sourceImage.width / frameCount;
        double frameHeight = sourceImage.height.toDouble();

        int safeFrameIndex = frameIndex % frameCount;
        sourceX = safeFrameIndex * frameWidth;
        cropW = frameWidth;
        cropH = frameHeight;
      }

      // Check boundaries
      if (sourceX + cropW > sourceImage.width) {
        sourceX = 0;
      }

      // Auto-crop: Scan alpha channel inside the frame region to find content bounding box
      final rawBytes = await sourceImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      int minX = (sourceX + cropW).toInt();
      int maxX = sourceX.toInt();
      int minY = (sourceY + cropH).toInt();
      int maxY = sourceY.toInt();

      if (rawBytes != null) {
        final bytes = rawBytes.buffer.asUint8List();
        final width = sourceImage.width;

        for (int y = sourceY.toInt(); y < sourceY + cropH; y++) {
          for (int x = sourceX.toInt(); x < sourceX + cropW; x++) {
            final offset = (y * width + x) * 4;
            if (offset + 3 < bytes.length) {
              final alpha = bytes[offset + 3];
              if (alpha > 10) { // Ignore transparent/near-transparent pixels
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
              }
            }
          }
        }
      }

      const double targetSize = 44.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..colorFilter = const ui.ColorFilter.mode(
          ui.Color(0xFFFFFFFF),
          ui.BlendMode.srcIn,
        );

      double contentWidth = (maxX - minX + 1).toDouble();
      double contentHeight = (maxY - minY + 1).toDouble();

      if (contentWidth > 0 && contentHeight > 0 && minX <= maxX && minY <= maxY) {
        // Content exists. Scale and center it with a small 1px safe padding (0.5pt at 2x)
        const double padding = 1.0;
        const double activeSize = targetSize - 2 * padding; // 42.0 px active area

        double drawW, drawH;
        if (contentWidth > contentHeight) {
          drawW = activeSize;
          drawH = activeSize * (contentHeight / contentWidth);
        } else {
          drawH = activeSize;
          drawW = activeSize * (contentWidth / contentHeight);
        }

        final double destX = (targetSize - drawW) / 2.0;
        final double destY = (targetSize - drawH) / 2.0;

        canvas.drawImageRect(
          sourceImage,
          ui.Rect.fromLTWH(minX.toDouble(), minY.toDouble(), contentWidth, contentHeight),
          ui.Rect.fromLTWH(destX, destY, drawW, drawH),
          paint,
        );
      } else {
        // Fallback: draw uncropped frame centered with safe margins
        canvas.drawImageRect(
          sourceImage,
          ui.Rect.fromLTWH(sourceX, sourceY, cropW, cropH),
          const ui.Rect.fromLTWH(2.0, 2.0, targetSize - 4.0, targetSize - 4.0),
          paint,
        );
      }

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
            int maxFrames = sheetImage.width ~/ size;
            int amount = config.frameCount;
            if (maxFrames > 0 && amount > maxFrames) {
              amount = maxFrames;
            }
            final data = SpriteAnimationData.sequenced(
              amount: amount,
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
        for (final state in CatAnimationState.values) {
          final config = theme.animations[state] ?? theme.animations[CatAnimationState.idle];
          if (config is SeparateAnimationConfig) {
            final String fullPath = '${theme.basePath}${config.fileName}';
            try {
              final ui.Image stateImage = await _loadImage(fullPath);
              double frameWidth = stateImage.width / config.frameCount;
              double frameHeight = stateImage.height.toDouble();
              final data = SpriteAnimationData.sequenced(
                amount: config.frameCount,
                stepTime: config.stepTime,
                textureSize: Vector2(frameWidth, frameHeight),
                texturePosition: Vector2.zero(),
                loop: config.loop,
              );
              loaded[state] = SpriteAnimation.fromFrameData(stateImage, data);
            } catch (e) {
              final fallbackConfig = theme.animations[CatAnimationState.idle] as SeparateAnimationConfig;
              final String fallbackPath = '${theme.basePath}${fallbackConfig.fileName}';
              final ui.Image fallbackImage = await _loadImage(fallbackPath);
              double fallbackFrameWidth = fallbackImage.width / fallbackConfig.frameCount;
              double fallbackFrameHeight = fallbackImage.height.toDouble();
              final data = SpriteAnimationData.sequenced(
                amount: fallbackConfig.frameCount,
                stepTime: fallbackConfig.stepTime,
                textureSize: Vector2(fallbackFrameWidth, fallbackFrameHeight),
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

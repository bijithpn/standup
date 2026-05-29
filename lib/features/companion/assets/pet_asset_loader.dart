import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:path_provider/path_provider.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/animation_row_config.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';

class PetAssetLoader {
  static final Map<String, ui.Image> _imageCache = {};
  static final Map<String, Map<PetAnimationState, SpriteAnimation>>
  _animationCache = {};
  static final Map<String, ui.Rect> _boundingBoxCache = {};

  static Future<ui.Image> loadImage(String path) async {
    if (_imageCache.containsKey(path)) {
      return _imageCache[path]!;
    }
    try {
      final ByteData data = await rootBundle.load(path);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      _imageCache[path] = fi.image;
      return fi.image;
    } catch (e) {
      throw Exception('Failed to load pet asset: $path, error: $e');
    }
  }

  static Map<String, dynamic>? _manifestCache;

  static Future<Map<String, dynamic>?> loadPetsManifest() async {
    if (_manifestCache != null) return _manifestCache;
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/animations/pets/pets.json',
      );
      _manifestCache = jsonDecode(jsonString) as Map<String, dynamic>;
      return _manifestCache;
    } catch (e) {
      return null;
    }
  }

  static String buildAssetPath(PetProfile profile, {String? stateName}) {
    final speciesPath = profile.species == PetSpecies.dog ? 'dogs' : 'cats';
    final basePath = 'assets/animations/$speciesPath/${profile.variant.id}/';
    if (stateName != null) {
      return '$basePath$stateName.png';
    }
    return basePath;
  }

  static Future<String> extractPetIconPath(PetTheme theme) async {
    final tempDir = await getApplicationSupportDirectory();
    final file = File('${tempDir.path}/bm_selected_pet_${theme.id}.png');

    // If already extracted, return cached path
    if (await file.exists()) {
      return file.path;
    }

    try {
      ui.Image sourceImage;
      double size = theme.spriteSize.toDouble();
      double sourceX = 0;
      double sourceY = 0;

      if (theme.type == PetType.composite) {
        sourceImage = await loadImage(theme.basePath);
        final config = theme.animations[PetAnimationState.idle];
        double row = config is AnimationRowConfig ? config.row.toDouble() : 1.0;
        sourceY = row * size;
      } else {
        final config = theme.animations[PetAnimationState.idle];
        final String fileName = config is SeparateAnimationConfig
            ? config.fileName
            : 'idle.png';
        sourceImage = await loadImage('${theme.basePath}$fileName');
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

  static Future<void> preCache(PetProfile profile) async {
    await loadAnimations(profile);
    final theme = PetTheme.getTheme(profile.variant.id);
    await extractPetIconPath(theme);
  }

  static Future<Map<PetAnimationState, SpriteAnimation>> loadAnimations(
    PetProfile profile,
  ) async {
    final cacheKey = '${profile.species.name}_${profile.variant.id}';
    if (_animationCache.containsKey(cacheKey)) {
      return _animationCache[cacheKey]!;
    }

    try {
      final Map<PetAnimationState, SpriteAnimation> loaded = {};
      final basePath = buildAssetPath(profile);
      final manifest = await loadPetsManifest();
      final petConfig = manifest?['pets']?.firstWhere(
        (p) => p['id'] == profile.id,
        orElse: () => null,
      );

      final variantConfig = petConfig?['variant'];

      // Find matching PetTheme to use as a fallback/config provider
      final matchingTheme = PetTheme.themes.firstWhere(
        (t) => t.id == profile.variant.id,
        orElse: () => PetTheme.themes.first,
      );

      final isSpriteSheet =
          variantConfig?['isSpriteSheet'] ??
          (matchingTheme.type == PetType.composite);
      final spriteSize =
          (variantConfig?['spriteSize'] ?? matchingTheme.spriteSize).toDouble();

      if (isSpriteSheet) {
        final sheetPath = variantConfig?['assetPath'] ?? matchingTheme.basePath;
        final ui.Image sheetImage = await loadImage(sheetPath);

        for (final state in PetAnimationState.values) {
          final stateName = state.name;

          int row = 0;
          int frameCount = 1;
          double stepTime = 0.1;
          bool loop = true;

          final themeAnim = matchingTheme.animations[state];
          if (themeAnim is AnimationRowConfig) {
            row = themeAnim.row;
            frameCount = themeAnim.frameCount;
            stepTime = themeAnim.stepTime;
            loop = themeAnim.loop;
          } else if (variantConfig?['rows']?[stateName] != null) {
            row = (variantConfig['rows'][stateName] as num).toInt();
            frameCount =
                (variantConfig['frameCounts']?[stateName] as num?)?.toInt() ??
                1;
            stepTime =
                (variantConfig['stepTimes']?[stateName] as num?)?.toDouble() ??
                0.1;
          }

          final maxFrames = sheetImage.width ~/ spriteSize;
          final amount = frameCount > maxFrames ? maxFrames : frameCount;

          final data = SpriteAnimationData.sequenced(
            amount: amount,
            stepTime: stepTime,
            textureSize: Vector2(spriteSize, spriteSize),
            texturePosition: Vector2(0.0, (row * spriteSize).toDouble()),
            loop: loop,
          );
          loaded[state] = SpriteAnimation.fromFrameData(sheetImage, data);
        }
      } else {
        for (final state in PetAnimationState.values) {
          final stateName = state.name;

          String fileName = '$stateName.png';
          int frameCount = 1;
          double stepTime = 0.1;
          bool loop = true;

          final themeAnim = matchingTheme.animations[state];
          if (themeAnim is SeparateAnimationConfig) {
            fileName = themeAnim.fileName;
            frameCount = themeAnim.frameCount;
            stepTime = themeAnim.stepTime;
            loop = themeAnim.loop;
          } else if (variantConfig?['fileNames']?[stateName] != null) {
            fileName = variantConfig['fileNames'][stateName] as String;
            frameCount =
                (variantConfig['frameCounts']?[stateName] as num?)?.toInt() ??
                1;
            stepTime =
                (variantConfig['stepTimes']?[stateName] as num?)?.toDouble() ??
                0.1;
          }

          final filePath = '$basePath$fileName';
          try {
            final ui.Image stateImage = await loadImage(filePath);
            final frameWidth = stateImage.width / frameCount;
            final frameHeight = stateImage.height.toDouble();

            final data = SpriteAnimationData.sequenced(
              amount: frameCount,
              stepTime: stepTime,
              textureSize: Vector2(frameWidth, frameHeight),
              texturePosition: Vector2.zero(),
              loop: loop,
            );
            loaded[state] = SpriteAnimation.fromFrameData(stateImage, data);
          } catch (e) {
            String fallbackFileName = 'idle.png';
            int fallbackFrameCount = 1;
            double fallbackStepTime = 0.1;
            bool fallbackLoop = true;

            final idleAnim = matchingTheme.animations[PetAnimationState.idle];
            if (idleAnim is SeparateAnimationConfig) {
              fallbackFileName = idleAnim.fileName;
              fallbackFrameCount = idleAnim.frameCount;
              fallbackStepTime = idleAnim.stepTime;
              fallbackLoop = idleAnim.loop;
            }

            final fallbackPath = '$basePath$fallbackFileName';
            try {
              final ui.Image fallbackImage = await loadImage(fallbackPath);
              final fallbackFrameWidth =
                  fallbackImage.width / fallbackFrameCount;
              final fallbackFrameHeight = fallbackImage.height.toDouble();

              final data = SpriteAnimationData.sequenced(
                amount: fallbackFrameCount,
                stepTime: fallbackStepTime,
                textureSize: Vector2(fallbackFrameWidth, fallbackFrameHeight),
                texturePosition: Vector2.zero(),
                loop: fallbackLoop,
              );
              loaded[state] = SpriteAnimation.fromFrameData(
                fallbackImage,
                data,
              );
            } catch (fallbackError) {
              // Silently ignore or fallback to empty
            }
          }
        }
      }

      _animationCache[cacheKey] = loaded;

      // Directional walk fallback: if walkUp/walkDown/walkSide are missing, assign them to walkSide
      final walkAnim = loaded[PetAnimationState.walkSide];
      if (walkAnim != null) {
        loaded[PetAnimationState.walkUp] ??= walkAnim;
        loaded[PetAnimationState.walkDown] ??= walkAnim;
      }

      // Ensure every state has an animation, fallback to idle if missing
      if (loaded.containsKey(PetAnimationState.idle)) {
        final idleAnim = loaded[PetAnimationState.idle]!;
        for (final state in PetAnimationState.values) {
          if (!loaded.containsKey(state)) {
            loaded[state] = idleAnim;
          }
        }
      }

      return loaded;
    } catch (e) {
      return {};
    }
  }

  // --- Native Tray Caching, Cropping & Whitening Logic ---

  /// Pre-caches all tray icon frames for the selected theme to avoid runtime lag.
  static Future<void> preCacheTrayIcons(PetTheme theme) async {
    final states = [
      PetAnimationState.idle,
      PetAnimationState.sleep,
      PetAnimationState.excited,
      PetAnimationState.notification,
    ];

    for (final state in states) {
      final config = theme.animations[state];
      int frameCount = 1;
      if (config is AnimationRowConfig) {
        frameCount = config.frameCount;
      } else if (config is SeparateAnimationConfig) {
        frameCount = config.frameCount;
      }

      for (int i = 0; i < frameCount; i++) {
        await extractPetFramePath(theme: theme, state: state, frameIndex: i);
      }
    }
  }

  /// Loads a static asset file, auto-crops, resizes to targetSize x targetSize (default 44.0 px @2x template)
  /// with template-white color filter, and writes to target path.
  static Future<String> extractAndWhitenAsset(
    String assetPath,
    String outputPath, {
    double targetSize = 44.0,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      // Use temporary directory and standard macOS template naming
      // No theme suffix needed for template icons
      final fileName = assetPath.split('/').last.replaceAll('.png', '');
      final file = File('${tempDir.path}/bm_icon_${fileName}Template@2x.png');
      
      if (await file.exists()) {
        return file.path;
      }

      final sourceImage = await loadImage(assetPath);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      
      // Template icons MUST be solid black with alpha.
      // macOS will tint them automatically.
      const tintColor = ui.Color(0xFF000000);
      final paint = ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..colorFilter = const ui.ColorFilter.mode(tintColor, ui.BlendMode.srcIn);

      final rawBytes = await sourceImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
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
              if (alpha > 15) {
                // Ignore transparent pixels
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

      if (contentWidth > 0 &&
          contentHeight > 0 &&
          minX <= maxX &&
          minY <= maxY) {
        const double padding = 1.0;
        final double activeSize =
            targetSize - 2 * padding; // 42.0 px active area

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
          ui.Rect.fromLTWH(
            minX.toDouble(),
            minY.toDouble(),
            contentWidth,
            contentHeight,
          ),
          ui.Rect.fromLTWH(destX, destY, drawW, drawH),
          paint,
        );
      } else {
        canvas.drawImageRect(
          sourceImage,
          ui.Rect.fromLTWH(
            0,
            0,
            sourceImage.width.toDouble(),
            sourceImage.height.toDouble(),
          ),
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
  static Future<String> extractPetFramePath({
    required PetTheme theme,
    required PetAnimationState state,
    required int frameIndex,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/bm_pframe_${theme.id}_${state.name}_$frameIndex' 'Template@2x.png',
    );

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

      if (theme.type == PetType.composite) {
        sourceImage = await loadImage(theme.basePath);
        final config =
            theme.animations[state] ?? theme.animations[PetAnimationState.idle];
        double row = config is AnimationRowConfig ? config.row.toDouble() : 1.0;
        sourceY = row * size;
        int maxFrames = sourceImage.width ~/ size;
        int safeFrameIndex = maxFrames > 0 ? (frameIndex % maxFrames) : 0;
        sourceX = safeFrameIndex * size;
      } else {
        final config =
            theme.animations[state] ?? theme.animations[PetAnimationState.idle];
        final String fileName = config is SeparateAnimationConfig
            ? config.fileName
            : 'idle.png';
        sourceImage = await loadImage('${theme.basePath}$fileName');

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
      final String bbCacheKey = '${theme.id}_${state.name}_$frameIndex';
      ui.Rect? cachedBB = _boundingBoxCache[bbCacheKey];

      int minX, maxX, minY, maxY;

      if (cachedBB != null) {
        minX = cachedBB.left.toInt();
        maxX = cachedBB.right.toInt();
        minY = cachedBB.top.toInt();
        maxY = cachedBB.bottom.toInt();
      } else {
        final rawBytes = await sourceImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        minX = (sourceX + cropW).toInt();
        maxX = sourceX.toInt();
        minY = (sourceY + cropH).toInt();
        maxY = sourceY.toInt();

        if (rawBytes != null) {
          final bytes = rawBytes.buffer.asUint8List();
          final width = sourceImage.width;

          for (int y = sourceY.toInt(); y < sourceY + cropH; y++) {
            final yOffset = y * width * 4;
            for (int x = sourceX.toInt(); x < sourceX + cropW; x++) {
              final offset = yOffset + (x * 4);
              if (offset + 3 < bytes.length) {
                final alpha = bytes[offset + 3];
                if (alpha > 15) {
                  // Ignore transparent/near-transparent pixels
                  if (x < minX) minX = x;
                  if (x > maxX) maxX = x;
                  if (y < minY) minY = y;
                  if (y > maxY) maxY = y;
                }
              }
            }
          }
        }

        _boundingBoxCache[bbCacheKey] = ui.Rect.fromLTRB(
          minX.toDouble(),
          minY.toDouble(),
          maxX.toDouble(),
          maxY.toDouble(),
        );
      }

      const double targetSize = 44.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      
      // Use Black for template icons
      const tintColor = ui.Color(0xFF000000);
      final paint = ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..colorFilter = const ui.ColorFilter.mode(tintColor, ui.BlendMode.srcIn);

      double contentWidth = (maxX - minX + 1).toDouble();
      double contentHeight = (maxY - minY + 1).toDouble();

      if (contentWidth > 0 &&
          contentHeight > 0 &&
          minX <= maxX &&
          minY <= maxY) {
        const double padding = 1.0;
        const double activeSize =
            targetSize - 2 * padding; // 42.0 px active area

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
          ui.Rect.fromLTWH(
            minX.toDouble(),
            minY.toDouble(),
            contentWidth,
            contentHeight,
          ),
          ui.Rect.fromLTWH(destX, destY, drawW, drawH),
          paint,
        );
      } else {
        canvas.drawImageRect(
          sourceImage,
          ui.Rect.fromLTWH(
            sourceX,
            sourceY,
            cropW,
            cropH,
          ),
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

  static void clearCache() {
    _imageCache.clear();
    _animationCache.clear();
    _boundingBoxCache.clear();
    CompanionSpriteWidget.clearCache();
  }
}

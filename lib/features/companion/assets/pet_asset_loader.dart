import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/pet_profile.dart';
import 'package:standup/features/companion/domain/pet_type.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/domain/animation_row_config.dart';

class PetAssetLoader {
  static final Map<String, ui.Image> _imageCache = {};
  static final Map<String, Map<CatAnimationState, SpriteAnimation>>
  _animationCache = {};

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
    final basePath =
        'assets/animations/$speciesPath/${profile.variant.id}/';
    if (stateName != null) {
      return '$basePath$stateName.png';
    }
    return basePath;
  }

  static Future<String> extractPetIconPath(PetProfile profile) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/bm_pet_${profile.id}.png');

    if (await file.exists()) {
      return file.path;
    }

    try {
      ui.Image sourceImage;
      final basePath = buildAssetPath(profile);
      final manifest = await loadPetsManifest();
      final petConfig = manifest?['pets']?.firstWhere(
        (p) => p['id'] == profile.id,
        orElse: () => null,
      );

      final variantConfig = petConfig?['variant'];
      final isSpriteSheet = variantConfig?['isSpriteSheet'] ?? false;

      if (isSpriteSheet) {
        final sheetPath = variantConfig?['assetPath'] ?? '$basePath${profile.variant.id}_sheet.png';
        sourceImage = await loadImage(sheetPath);
        final rowCount = variantConfig?['rowCount'] ?? 0;
        final spriteSize = (variantConfig?['spriteSize'] ?? 16.0).toDouble();
        final sourceY = rowCount * spriteSize;
        const double targetSize = 128.0;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

        canvas.drawImageRect(
          sourceImage,
          ui.Rect.fromLTWH(0, sourceY, spriteSize, spriteSize),
          const ui.Rect.fromLTWH(0, 0, targetSize, targetSize),
          paint,
        );

        final picture = recorder.endRecording();
        final img = await picture.toImage(
          targetSize.toInt(),
          targetSize.toInt(),
        );
        final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

        if (pngBytes != null) {
          await file.writeAsBytes(pngBytes.buffer.asUint8List());
          return file.path;
        }
      } else {
        sourceImage = await loadImage('${basePath}idle.png');
        const double targetSize = 128.0;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

        canvas.drawImageRect(
          sourceImage,
          ui.Rect.fromLTWH(
            0,
            0,
            sourceImage.width.toDouble(),
            sourceImage.height.toDouble(),
          ),
          const ui.Rect.fromLTWH(0, 0, targetSize, targetSize),
          paint,
        );

        final picture = recorder.endRecording();
        final img = await picture.toImage(
          targetSize.toInt(),
          targetSize.toInt(),
        );
        final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

        if (pngBytes != null) {
          await file.writeAsBytes(pngBytes.buffer.asUint8List());
          return file.path;
        }
      }
    } catch (e) {
      // Fallback
    }

    return '';
  }

  static Future<void> preCache(PetProfile profile) async {
    await loadAnimations(profile);
    await extractPetIconPath(profile);
  }

  static Future<Map<CatAnimationState, SpriteAnimation>> loadAnimations(
    PetProfile profile,
  ) async {
    final cacheKey = '${profile.species.name}_${profile.variant.id}';
    if (_animationCache.containsKey(cacheKey)) {
      return _animationCache[cacheKey]!;
    }

    try {
      final Map<CatAnimationState, SpriteAnimation> loaded = {};
      final basePath = buildAssetPath(profile);
      final manifest = await loadPetsManifest();
      final petConfig = manifest?['pets']?.firstWhere(
        (p) => p['id'] == profile.id,
        orElse: () => null,
      );

      final variantConfig = petConfig?['variant'];

      // Find matching legacy CatTheme to use as a fallback/config provider
      final matchingTheme = CatTheme.themes.firstWhere(
        (t) => t.id == profile.variant.id,
        orElse: () => CatTheme.themes.first,
      );

      final isSpriteSheet = variantConfig?['isSpriteSheet'] ?? (matchingTheme.type == CatType.composite);
      final spriteSize = (variantConfig?['spriteSize'] ?? matchingTheme.spriteSize).toDouble();

      if (isSpriteSheet) {
        final sheetPath = variantConfig?['assetPath'] ?? matchingTheme.basePath;
        final ui.Image sheetImage = await loadImage(sheetPath);

        for (final state in CatAnimationState.values) {
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
            frameCount = (variantConfig['frameCounts']?[stateName] as num?)?.toInt() ?? 1;
            stepTime = (variantConfig['stepTimes']?[stateName] as num?)?.toDouble() ?? 0.1;
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
        for (final state in CatAnimationState.values) {
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
            frameCount = (variantConfig['frameCounts']?[stateName] as num?)?.toInt() ?? 1;
            stepTime = (variantConfig['stepTimes']?[stateName] as num?)?.toDouble() ?? 0.1;
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

            final idleAnim = matchingTheme.animations[CatAnimationState.idle];
            if (idleAnim is SeparateAnimationConfig) {
              fallbackFileName = idleAnim.fileName;
              fallbackFrameCount = idleAnim.frameCount;
              fallbackStepTime = idleAnim.stepTime;
              fallbackLoop = idleAnim.loop;
            }

            final fallbackPath = '$basePath$fallbackFileName';
            try {
              final ui.Image fallbackImage = await loadImage(fallbackPath);
              final fallbackFrameWidth = fallbackImage.width / fallbackFrameCount;
              final fallbackFrameHeight = fallbackImage.height.toDouble();

              final data = SpriteAnimationData.sequenced(
                amount: fallbackFrameCount,
                stepTime: fallbackStepTime,
                textureSize: Vector2(fallbackFrameWidth, fallbackFrameHeight),
                texturePosition: Vector2.zero(),
                loop: fallbackLoop,
              );
              loaded[state] = SpriteAnimation.fromFrameData(fallbackImage, data);
            } catch (fallbackError) {
              // Silently ignore or fallback to empty
            }
          }
        }
      }

      _animationCache[cacheKey] = loaded;

      // Ensure every state has an animation, fallback to idle if missing
      if (loaded.containsKey(CatAnimationState.idle)) {
        final idleAnim = loaded[CatAnimationState.idle]!;
        for (final state in CatAnimationState.values) {
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

  static void clearCache() {
    _imageCache.clear();
    _animationCache.clear();
  }
}

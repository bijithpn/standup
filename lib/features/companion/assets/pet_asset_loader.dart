import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/pet_profile.dart';

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

  static Future<Map<String, dynamic>?> loadPetsManifest() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/animations/pets/pets.json',
      );
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static String buildAssetPath(PetProfile profile, {String? stateName}) {
    final basePath =
        'assets/animations/pets/${profile.species.name}/${profile.variant}/';
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

      final variantConfig = petConfig?['variants']?.firstWhere(
        (v) => v['name'] == profile.variant,
        orElse: () => null,
      );

      final isSpriteSheet = variantConfig?['isSpriteSheet'] ?? false;

      if (isSpriteSheet) {
        final sheetPath = '$basePath${profile.variant}_sheet.png';
        sourceImage = await loadImage(sheetPath);
        final rowCount = variantConfig?['rowCount'] ?? 0;
        final spriteSize = variantConfig?['spriteSize'] ?? 16.0;
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

  static Future<Map<CatAnimationState, SpriteAnimation>> loadAnimations(
    PetProfile profile,
  ) async {
    final cacheKey = '${profile.species.name}_${profile.variant}';
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

      final variantConfig = petConfig?['variants']?.firstWhere(
        (v) => v['name'] == profile.variant,
        orElse: () => null,
      );

      final isSpriteSheet = variantConfig?['isSpriteSheet'] ?? false;

      if (isSpriteSheet) {
        final sheetPath = '$basePath${profile.variant}_sheet.png';
        final ui.Image sheetImage = await loadImage(sheetPath);
        final spriteSize = (variantConfig?['spriteSize'] ?? 16).toDouble();
        final rowCountMap = <String, int>{};
        final frameCountMap = <String, int>{};
        final stepTimeMap = <String, double>{};

        for (final state in CatAnimationState.values) {
          final stateName = state.name;
          rowCountMap[stateName] = variantConfig?['rows']?[stateName] ?? 0;
          frameCountMap[stateName] =
              variantConfig?['frameCounts']?[stateName] ?? 1;
          stepTimeMap[stateName] =
              (variantConfig?['stepTimes']?[stateName] ?? 0.1).toDouble();
        }

        for (final state in CatAnimationState.values) {
          final stateName = state.name;
          final row = rowCountMap[stateName] ?? 0;
          final frameCount = frameCountMap[stateName] ?? 1;
          final stepTime = stepTimeMap[stateName] ?? 0.1;
          final maxFrames = sheetImage.width ~/ spriteSize;
          final amount = frameCount > maxFrames ? maxFrames : frameCount;

          final data = SpriteAnimationData.sequenced(
            amount: amount,
            stepTime: stepTime,
            textureSize: Vector2(spriteSize, spriteSize),
            texturePosition: Vector2(0.0, (row * spriteSize).toDouble()),
            loop: true,
          );
          loaded[state] = SpriteAnimation.fromFrameData(sheetImage, data);
        }
      } else {
        for (final state in CatAnimationState.values) {
          final stateName = state.name;
          final filePath = '$basePath$stateName.png';
          try {
            final ui.Image stateImage = await loadImage(filePath);
            final frameCount = (variantConfig?['frameCounts']?[stateName] ?? 1)
                .toInt();
            final stepTime = (variantConfig?['stepTimes']?[stateName] ?? 0.1)
                .toDouble();
            final frameWidth = stateImage.width / frameCount;
            final frameHeight = stateImage.height.toDouble();

            final data = SpriteAnimationData.sequenced(
              amount: frameCount,
              stepTime: stepTime,
              textureSize: Vector2(frameWidth, frameHeight),
              texturePosition: Vector2.zero(),
              loop: true,
            );
            loaded[state] = SpriteAnimation.fromFrameData(stateImage, data);
          } catch (e) {
            final fallbackPath = '${basePath}idle.png';
            final ui.Image fallbackImage = await loadImage(fallbackPath);
            final fallbackFrameCount =
                (variantConfig?['frameCounts']?['idle'] ?? 1).toInt();
            final fallbackStepTime =
                (variantConfig?['stepTimes']?['idle'] ?? 0.1).toDouble();
            final fallbackFrameWidth = fallbackImage.width / fallbackFrameCount;
            final fallbackFrameHeight = fallbackImage.height.toDouble();

            final data = SpriteAnimationData.sequenced(
              amount: fallbackFrameCount,
              stepTime: fallbackStepTime,
              textureSize: Vector2(fallbackFrameWidth, fallbackFrameHeight),
              texturePosition: Vector2.zero(),
              loop: true,
            );
            loaded[state] = SpriteAnimation.fromFrameData(fallbackImage, data);
          }
        }
      }

      _animationCache[cacheKey] = loaded;
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

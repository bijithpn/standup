import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/animation_row_config.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/errors/error_handler.dart';

class PetAssetLoader {
  static final Map<String, ByteData> _byteCache = {};

  /// Decoded image cache — avoids re-decoding PNG bytes on every call.
  static final Map<String, ui.Image> _imageCache = {};
  static final Map<int, Uint8List?> _rgbaCache = {};
  static final Set<String> _failedAssets = {};
  static final Map<String, ui.Rect> _boundingBoxCache = {};

  static Future<double> computeImageRectBottomPadding(
    ui.Image image,
    ui.Rect rect,
  ) async {
    return _computeSpriteBottomPadding(image, rect);
  }

  /// Scans alpha from bottom-up to find the first row that contains a visible
  /// pixel (alpha > 15). Returns the count of empty rows below that row.
  static Future<double> _computeSpriteBottomPadding(
    ui.Image image,
    ui.Rect rect,
  ) async {
    final bytes = await _rgbaBytesFor(image);
    if (bytes == null) return 0.0;

    final left = rect.left.floor().clamp(0, image.width - 1);
    final right = rect.right.ceil().clamp(left + 1, image.width);
    final top = rect.top.floor().clamp(0, image.height - 1);
    final bottom = rect.bottom.ceil().clamp(top + 1, image.height);
    final imgW = image.width;

    for (int y = bottom - 1; y >= top; y--) {
      final rowOffset = y * imgW * 4;
      for (int x = left; x < right; x++) {
        final offset = rowOffset + x * 4;
        if (offset + 3 < bytes.length && bytes[offset + 3] > 15) {
          // y is the bottom-most visible row (0-indexed, inclusive).
          // Rows from y+1 to bottom-1 are transparent padding.
          return (bottom - 1 - y).toDouble();
        }
      }
    }
    // Entire frame is blank — treat as no padding so we don't hide the pet.
    return 0.0;
  }

  static ui.Image? getImageSync(String path) {
    return _imageCache[path];
  }

  static Future<ui.Image> loadImage(String path) async {
    // Skip empty paths — environment asset paths are intentionally empty after
    // the asset migration. Attempting to load '' causes Flutter to throw.
    if (path.isEmpty) {
      throw AppException(
        type: AppErrorType.assetLoadFailure,
        message: 'loadImage called with empty path',
      );
    }

    // Return cached decoded image — avoids codec instantiation overhead every tick.
    final cached = _imageCache[path];
    if (cached != null) return cached;

    if (_failedAssets.contains(path)) {
      throw AppException(
        type: AppErrorType.assetLoadFailure,
        message: 'Asset previously failed to load: $path',
      );
    }
    try {
      ByteData? data = _byteCache[path];
      if (data == null) {
        data = await rootBundle.load(path);
        _byteCache[path] = data;
      }

      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      _imageCache[path] = fi.image;
      return fi.image;
    } catch (e) {
      _failedAssets.add(path);
      debugPrint(
        'Warning: Failed to load asset $path. Caching failure. Error: $e',
      );
      throw AppException(
        type: AppErrorType.assetLoadFailure,
        message: 'Failed to load pet asset: $path, error: $e',
      );
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
    final String speciesPath;
    if (profile.species == PetSpecies.dog) {
      speciesPath = 'dogs';
    } else if (profile.species == PetSpecies.flamingo) {
      speciesPath = 'flamingo';
    } else {
      speciesPath = 'cats';
    }
    final basePath = 'assets/animations/$speciesPath/${profile.variant.id}/';
    if (stateName != null) {
      return '$basePath$stateName.png';
    }
    return basePath;
  }

  static Future<String> extractPetIconPath(PetTheme theme) async {
    final supportDir = await getApplicationSupportDirectory();
    final file = File(
      p.join(supportDir.path, 'bm_selected_pet_${theme.id}.png'),
    );

    if (await file.exists()) {
      return file.path;
    }

    if (theme.type == PetType.avatar || theme.isAvatar) {
      final species = theme.avatarDefinition?.species ?? AvatarSpecies.bear;
      final thumbPath = species.thumbnailPngAssetPath;
      try {
        final data = await rootBundle.load(thumbPath);
        if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
        file.writeAsBytesSync(data.buffer.asUint8List(), flush: true);
        return file.path;
      } catch (e) {
        debugPrint('Failed to extract avatar pet icon: $e');
        return '';
      }
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

      img.dispose();
      picture.dispose();

      if (pngBytes != null) {
        if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
        file.writeAsBytesSync(pngBytes.buffer.asUint8List(), flush: true);
        return file.path;
      }
    } catch (e) {
      debugPrint('Failed to extract pet icon: $e');
    }

    return '';
  }

  static Future<void> preCache(PetProfile profile) async {
    if (profile.theme?.isAvatar == true ||
        profile.variant.id.startsWith('avatar_')) {
      return;
    }
    final theme = PetTheme.getTheme(profile.variant.id);
    await extractPetIconPath(theme);
  }

  static Future<Uint8List?> _rgbaBytesFor(ui.Image image) async {
    final key = image.hashCode;
    if (_rgbaCache.containsKey(key)) return _rgbaCache[key];

    final rawBytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = rawBytes?.buffer.asUint8List();
    _rgbaCache[key] = bytes;
    return bytes;
  }

  /// Pre-caches all tray icon frames for the selected theme to avoid runtime lag.
  static Future<void> preCacheTrayIcons(PetTheme theme) async {
    if (theme.type == PetType.avatar || theme.isAvatar) {
      await extractPetFramePath(
        theme: theme,
        state: PetAnimationState.idle,
        frameIndex: 0,
      );
      return;
    }

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

  static Future<String> extractAndWhitenAsset(
    String assetPath,
    String outputPath, {
    double targetSize = 44.0,
  }) async {
    try {
      final file = File(outputPath);

      if (await file.exists()) {
        final len = await file.length();
        if (len > 8) {
          final header = await file.openRead(0, 8).first;
          if (listEquals(header.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47])) {
            return file.path;
          }
        }
        try {
          await file.delete();
        } catch (_) {}
      }

      final sourceImage = await loadImage(assetPath);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Template icons MUST be solid black with alpha.
      const tintColor = ui.Color(0xFF000000);
      final paint = ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..colorFilter = const ui.ColorFilter.mode(
          tintColor,
          ui.BlendMode.srcIn,
        );

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
        final double activeSize = targetSize - 2 * padding;

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

      img.dispose();
      picture.dispose();

      if (pngBytes != null) {
        if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
        file.writeAsBytesSync(pngBytes.buffer.asUint8List(), flush: true);
        return file.path;
      }
    } catch (e) {
      debugPrint('Failed to extract whiten asset: $e');
      if (assetPath.toLowerCase().endsWith('.png')) {
        try {
          final bytes = await rootBundle.load(assetPath);
          final file = File(outputPath);
          if (!file.parent.existsSync()) {
            file.parent.createSync(recursive: true);
          }
          file.writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
          return file.path;
        } catch (e, st) {
          ErrorHandler().handleError(e, st);
        }
      }
    }
    return '';
  }

  static Future<String> extractPetFramePath({
    required PetTheme theme,
    required PetAnimationState state,
    required int frameIndex,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final file = File(
      p.join(
        supportDir.path,
        'bm_pframe_${theme.id}_${state.name}_${frameIndex}Template@2x.png',
      ),
    );

    if (theme.type == PetType.avatar || theme.isAvatar) {
      return extractAndWhitenAsset(
        AppConstants.trayIconPath,
        file.path,
        targetSize: 44.0,
      );
    }

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

      if (sourceX + cropW > sourceImage.width) {
        sourceX = 0;
      }

      final String bbCacheKey = '${theme.id}_${state.name}_$frameIndex';
      ui.Rect? cachedBB = _boundingBoxCache[bbCacheKey];

      int minX, maxX, minY, maxY;

      if (cachedBB != null) {
        minX = cachedBB.left.toInt();
        maxX = cachedBB.right.toInt();
        minY = cachedBB.top.toInt();
        maxY = cachedBB.bottom.toInt();
      } else {
        final bytes = await _rgbaBytesFor(sourceImage);
        minX = (sourceX + cropW).toInt();
        maxX = sourceX.toInt();
        minY = (sourceY + cropH).toInt();
        maxY = sourceY.toInt();

        if (bytes != null) {
          final width = sourceImage.width;

          // Process in small chunks to avoid blocking the UI thread for too long
          for (int y = sourceY.toInt(); y < sourceY + cropH; y++) {
            if (y % 20 == 0) await Future.delayed(Duration.zero);
            final yOffset = y * width * 4;
            for (int x = sourceX.toInt(); x < sourceX + cropW; x++) {
              final offset = yOffset + (x * 4);
              if (offset + 3 < bytes.length) {
                final alpha = bytes[offset + 3];
                if (alpha > 15) {
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

      const tintColor = ui.Color(0xFF000000);
      final paint = ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..colorFilter = const ui.ColorFilter.mode(
          tintColor,
          ui.BlendMode.srcIn,
        );

      double contentWidth = (maxX - minX + 1).toDouble();
      double contentHeight = (maxY - minY + 1).toDouble();

      if (contentWidth > 0 &&
          contentHeight > 0 &&
          minX <= maxX &&
          minY <= maxY) {
        const double padding = 1.0;
        const double activeSize = targetSize - 2 * padding;

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
          ui.Rect.fromLTWH(sourceX, sourceY, cropW, cropH),
          const ui.Rect.fromLTWH(2.0, 2.0, targetSize - 4.0, targetSize - 4.0),
          paint,
        );
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      img.dispose();
      picture.dispose();

      if (pngBytes != null) {
        if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
        file.writeAsBytesSync(pngBytes.buffer.asUint8List(), flush: true);
        return file.path;
      }
    } catch (e) {
      debugPrint('Failed to extract pet frame: $e');
    }

    return '';
  }

  static Future<void> preCacheBackgrounds() async {
    // asset-migration: background/environment assets removed — nothing to pre-cache
    const List<String> paths = [];
    for (final path in paths) {
      try {
        await loadImage(path);
      } catch (e) {
        debugPrint('Failed to pre-cache background: $path: $e');
      }
    }
  }

  static void clearCache() {
    _byteCache.clear();
    _imageCache.clear();
    _rgbaCache.clear();
    _failedAssets.clear();
    _boundingBoxCache.clear();
    CompanionSpriteWidget.clearCache();
  }
}

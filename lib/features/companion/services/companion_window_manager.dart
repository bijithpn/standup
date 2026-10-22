import 'dart:io' show Platform;
import 'package:breakmate/core/errors/error_handler.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/companion_window_controller.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class CompanionWindowManager {
  CompanionWindowManager({
    CompanionWindowController? windowController,
    SettingsRepository? settingsRepository,
    DisplayManager? displayManager,
    AppLogger? logger,
  }) : _windowController = windowController ?? CompanionWindowController(),
       _displayManager = displayManager,
       _logger = logger ?? AppLogger();

  final CompanionWindowController _windowController;
  final DisplayManager? _displayManager;
  final AppLogger _logger;

  Future<double> _getPrimaryScreenHeight() async {
    if (_displayManager == null) return 1080.0;
    try {
      final displays = await _displayManager.enumerateDisplays();
      if (displays.isNotEmpty) {
        final primary = displays.firstWhere(
          (d) => d.isPrimary,
          orElse: () => displays.first,
        );
        return primary.rect.height;
      }
    } catch (_) {}
    return 1080.0;
  }

  Size _currentSize = defaultSize;
  Offset _currentPosition = Offset.zero;

  Size get currentSize => _currentSize;
  Offset get currentPosition => _currentPosition;

  DisplayManager? get displayManager => _displayManager;

  static const Size defaultSize = Size(280, 320);
  static const Size minSize = Size(180, 210);
  static const Size maxSize = Size(360, 420);
  static const double handleHeight = 24.0;
  static const double minIntersection = 20.0;

  static const String _keyWindowWidth = 'companion_window_width';
  static const String _keyWindowHeight = 'companion_window_height';
  static const String _keyWindowX = 'companion_window_x';
  static const String _keyWindowY = 'companion_window_y';

  Future<void> initialize() async {
    final prefs = SimplePrefs.instance;

    final persistedWidth = prefs.getDouble(
      _keyWindowWidth,
      defaultValue: defaultSize.width,
    );
    final persistedHeight = prefs.getDouble(
      _keyWindowHeight,
      defaultValue: defaultSize.height,
    );
    final persistedX = prefs.getDouble(_keyWindowX, defaultValue: -1.0);
    final persistedY = prefs.getDouble(_keyWindowY, defaultValue: -1.0);

    _currentSize = _clampSize(Size(persistedWidth, persistedHeight));

    double x = persistedX;
    double y = persistedY;
    bool needsPersist = false;

    if (x == -1.0 || y == -1.0) {
      needsPersist = true;
      if (_displayManager != null) {
        try {
          final displays = await _displayManager.enumerateDisplays();
          if (displays.isNotEmpty) {
            final primary = displays.firstWhere(
              (d) => d.isPrimary,
              orElse: () => displays.first,
            );
            x = primary.rect.right - _currentSize.width - 20;
            y = primary.rect.bottom - _currentSize.height - 20;
          } else {
            x = 1000;
            y = 500;
          }
        } catch (_) {
          x = 1000;
          y = 500;
        }
      } else {
        x = 1000;
        y = 500;
      }
    }

    _currentPosition = Offset(x, y);

    _logger.info(
      'CompanionWindowManager.initialize(): restoring '
      'size=$_currentSize position=$_currentPosition',
    );

    await _windowController.setSize(_currentSize.width, _currentSize.height);

    final needsRecovery = await _isOffScreen(_currentPosition, _currentSize);
    if (needsRecovery) {
      final recovered = await _recoverPosition(_currentPosition, _currentSize);
      _logger.info(
        'CompanionWindowManager.initialize(): off-screen recovery '
        '$_currentPosition → $recovered',
      );
      _currentPosition = recovered;
      needsPersist = true;
    }

    if (needsPersist) {
      _persistPosition(_currentPosition);
    }

    double targetY = _currentPosition.dy;
    if (Platform.isMacOS) {
      final primaryHeight = await _getPrimaryScreenHeight();
      targetY = primaryHeight - _currentPosition.dy - _currentSize.height;
    }
    await _windowController.setPosition(_currentPosition.dx, targetY);

    await _windowController.setNonActivating(true);

    await _windowController.show();
  }

  Future<void> setSize(Size size) async {
    _currentSize = _clampSize(size);
    _logger.info('CompanionWindowManager.setSize(): $_currentSize');
    await _windowController.setSize(_currentSize.width, _currentSize.height);
    _persistSize(_currentSize);
  }

  Future<void> setPosition(Offset position) async {
    Offset resolved = position;

    final offScreen = await _isOffScreen(position, _currentSize);
    if (offScreen) {
      resolved = await _recoverPosition(position, _currentSize);
      _logger.info(
        'CompanionWindowManager.setPosition(): off-screen recovery '
        '$position → $resolved',
      );
    }

    _currentPosition = resolved;
    double targetY = resolved.dy;
    if (Platform.isMacOS) {
      final primaryHeight = await _getPrimaryScreenHeight();
      targetY = primaryHeight - resolved.dy - _currentSize.height;
    }
    await _windowController.setPosition(resolved.dx, targetY);
    _persistPosition(_currentPosition);
  }

  /// Moves the window without the off-screen recovery pass or a preference
  /// write.
  ///
  /// [setPosition] enumerates displays and writes two preferences on every
  /// call. That is right for a one-off move and far too heavy for an animation
  /// running twenty-five times a second, which is what the companion's
  /// wandering is — so a caller that has already clamped its own path to a
  /// display takes this instead, and calls [persistPosition] once it arrives.
  Future<void> moveTo(Offset position) async {
    _currentPosition = position;

    double targetY = position.dy;
    if (Platform.isMacOS) {
      targetY =
          await _primaryScreenHeight() - position.dy - _currentSize.height;
    }

    // Never animated: the caller is already drawing the motion frame by frame,
    // and on macOS an animated move blocks the main thread until it finishes.
    await _windowController.setPosition(position.dx, targetY, animate: false);
  }

  /// Writes the current position to preferences. Pairs with [moveTo].
  void persistPosition() => _persistPosition(_currentPosition);

  /// The primary screen's height, cached.
  ///
  /// Flipping into AppKit's bottom-left origin needs this on every frame of a
  /// move, and enumerating displays that often would undo the point of
  /// [moveTo]. The cache expires because monitors get swapped and resolutions
  /// change, and a stale height would put the companion at the wrong height on
  /// screen rather than merely being slow.
  Future<double> _primaryScreenHeight() async {
    final cached = _cachedPrimaryHeight;
    final measuredAt = _primaryHeightMeasuredAt;
    if (cached != null &&
        measuredAt != null &&
        DateTime.now().difference(measuredAt) < _primaryHeightTtl) {
      return cached;
    }

    final height = await _getPrimaryScreenHeight();
    _cachedPrimaryHeight = height;
    _primaryHeightMeasuredAt = DateTime.now();
    return height;
  }

  static const Duration _primaryHeightTtl = Duration(seconds: 30);

  double? _cachedPrimaryHeight;
  DateTime? _primaryHeightMeasuredAt;

  Future<void> setOpacity(double opacity) async {
    await _windowController.setOpacity(opacity);
  }

  Future<void> startDrag() async {
    await _windowController.startDrag();
  }

  Future<void> setNonActivating(bool nonActivating) async {
    await _windowController.setNonActivating(nonActivating);
  }

  Future<void> setAcceptsMouse(bool accepts) async {
    await _windowController.setAcceptsMouse(accepts);
  }

  Future<Offset> getPosition() async {
    final pos = await _windowController.getPosition();
    double y = pos['y'] as double;
    if (Platform.isMacOS) {
      final primaryHeight = await _getPrimaryScreenHeight();
      y = primaryHeight - y - _currentSize.height;
    }
    _currentPosition = Offset(pos['x'] as double, y);
    if (pos.containsKey('width') && pos.containsKey('height')) {
      final w = pos['width'] as double;
      final h = pos['height'] as double;
      if (w > 0 && h > 0) {
        _currentSize = Size(w, h);
        _persistSize(_currentSize);
      }
    }
    return _currentPosition;
  }

  static Size _clampSize(Size size) {
    return Size(
      size.width.clamp(minSize.width, maxSize.width),
      size.height.clamp(minSize.height, maxSize.height),
    );
  }

  Future<bool> _isOffScreen(Offset position, Size size) async {
    if (_displayManager == null) return false;

    List<DisplayBounds> displays;
    try {
      displays = await _displayManager.enumerateDisplays();
    } catch (e) {
      _logger.warning(
        'CompanionWindowManager._isOffScreen(): enumerateDisplays failed: $e',
      );
      return false;
    }

    if (displays.isEmpty) return false;

    final windowRect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    double maxIntersectionArea = 0.0;
    for (final display in displays) {
      if (windowRect.overlaps(display.rect)) {
        final intersection = windowRect.intersect(display.rect);
        final area = intersection.width * intersection.height;
        if (area > maxIntersectionArea) {
          maxIntersectionArea = area;
        }
      }
    }

    return maxIntersectionArea < minIntersection;
  }

  Future<Offset> _recoverPosition(Offset position, Size size) async {
    if (_displayManager == null) return Offset.zero;

    List<DisplayBounds> displays;
    try {
      displays = await _displayManager.enumerateDisplays();
    } catch (e) {
      _logger.warning(
        'CompanionWindowManager._recoverPosition(): enumerateDisplays '
        'failed: $e',
      );
      return Offset.zero;
    }

    if (displays.isEmpty) return Offset.zero;

    final windowCenter = Offset(
      position.dx + size.width / 2,
      position.dy + size.height / 2,
    );

    DisplayBounds nearest = displays.first;
    double nearestDist = _distanceToRect(windowCenter, nearest.rect);
    for (final d in displays.skip(1)) {
      final dist = _distanceToRect(windowCenter, d.rect);
      if (dist < nearestDist) {
        nearest = d;
        nearestDist = dist;
      }
    }

    return _anchorToClosestCorner(position, size, nearest.rect);
  }

  static Offset _anchorToClosestCorner(
    Offset windowPos,
    Size size,
    Rect displayRect,
  ) {
    final candidates = [
      Offset(displayRect.left, displayRect.top),
      Offset(displayRect.right - size.width, displayRect.top),
      Offset(displayRect.left, displayRect.bottom - size.height),
      Offset(displayRect.right - size.width, displayRect.bottom - size.height),
    ];

    Offset best = candidates.first;
    double bestDist = _euclidean(windowPos, candidates.first);
    for (final c in candidates.skip(1)) {
      final d = _euclidean(windowPos, c);
      if (d < bestDist) {
        best = c;
        bestDist = d;
      }
    }

    return Offset(
      best.dx.clamp(
        displayRect.left,
        math.max(displayRect.left, displayRect.right - size.width),
      ),
      best.dy.clamp(
        displayRect.top,
        math.max(displayRect.top, displayRect.bottom - size.height),
      ),
    );
  }

  static double _distanceToRect(Offset point, Rect rect) {
    final clampedX = point.dx.clamp(rect.left, rect.right);
    final clampedY = point.dy.clamp(rect.top, rect.bottom);
    return _euclidean(point, Offset(clampedX, clampedY));
  }

  static double _euclidean(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _persistSize(Size size) {
    try {
      SimplePrefs.instance.setDouble(_keyWindowWidth, size.width);
      SimplePrefs.instance.setDouble(_keyWindowHeight, size.height);
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  void _persistPosition(Offset position) {
    try {
      SimplePrefs.instance.setDouble(_keyWindowX, position.dx);
      SimplePrefs.instance.setDouble(_keyWindowY, position.dy);
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/companion_window_controller.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// Wraps [CompanionWindowController] with size/position persistence,
/// off-screen recovery, and per-platform focus-steal prevention.
///
/// Requirements: 1.2, 1.5, 1.8
class CompanionWindowManager {
  CompanionWindowManager({
    CompanionWindowController? windowController,
    SettingsRepository? settingsRepository,
    DisplayManager? displayManager,
    AppLogger? logger,
  }) : _windowController = windowController ?? CompanionWindowController(),
       _settingsRepository = settingsRepository,
       _displayManager = displayManager,
       _logger = logger ?? AppLogger();

  final CompanionWindowController _windowController;
  // SettingsRepository is accepted to honour the design contract even though
  // persistence is done via SimplePrefs (the same KV layer SettingsRepository
  // falls back to).  It may be used in future for richer snapshot integration.
  // ignore: unused_field
  final SettingsRepository? _settingsRepository;
  final DisplayManager? _displayManager;
  final AppLogger _logger;

  // ── Size and position state ───────────────────────────────────────────────

  Size _currentSize = defaultSize;
  Offset _currentPosition = Offset.zero;

  Size get currentSize => _currentSize;
  Offset get currentPosition => _currentPosition;

  DisplayManager? get displayManager => _displayManager;

  // ── Constants (Req 1.2) ───────────────────────────────────────────────────

  static const Size defaultSize = Size(280, 320);
  static const Size minSize = Size(160, 180);
  static const Size maxSize = Size(560, 640);
  static const double handleHeight = 24.0;
  static const double minIntersection = 20.0;

  // ── Settings keys ─────────────────────────────────────────────────────────

  static const String _keyWindowWidth = 'companion_window_width';
  static const String _keyWindowHeight = 'companion_window_height';
  static const String _keyWindowX = 'companion_window_x';
  static const String _keyWindowY = 'companion_window_y';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Restores persisted position/size from settings; applies off-screen
  /// recovery if the intersection with all displays is < [minIntersection]
  /// logical pixels before calling [CompanionWindowController.show].
  ///
  /// Requirement 1.2, 1.8
  Future<void> initialize() async {
    // --- Restore persisted size and position ---------------------------------
    final prefs = SimplePrefs.instance;

    final persistedWidth = prefs.getDouble(
      _keyWindowWidth,
      defaultValue: defaultSize.width,
    );
    final persistedHeight = prefs.getDouble(
      _keyWindowHeight,
      defaultValue: defaultSize.height,
    );
    final persistedX = prefs.getDouble(_keyWindowX, defaultValue: 0.0);
    final persistedY = prefs.getDouble(_keyWindowY, defaultValue: 0.0);

    // Clamp restored size to valid bounds.
    _currentSize = _clampSize(Size(persistedWidth, persistedHeight));
    _currentPosition = Offset(persistedX, persistedY);

    _logger.info(
      'CompanionWindowManager.initialize(): restoring '
      'size=$_currentSize position=$_currentPosition',
    );

    // Apply restored size to the native window.
    await _windowController.setSize(_currentSize.width, _currentSize.height);

    // --- Off-screen recovery (Req 1.8) ----------------------------------------
    final needsRecovery = await _isOffScreen(_currentPosition, _currentSize);
    if (needsRecovery) {
      final recovered = await _recoverPosition(_currentPosition, _currentSize);
      _logger.info(
        'CompanionWindowManager.initialize(): off-screen recovery '
        '$_currentPosition → $recovered',
      );
      _currentPosition = recovered;
      // Persist the recovered position so we don't recover again next launch.
      _persistPosition(_currentPosition);
    }

    await _windowController.setPosition(
      _currentPosition.dx,
      _currentPosition.dy,
    );

    // Apply non-activating style so the companion window never steals focus
    // from the user's active application (Req 18.2).
    await _windowController.setNonActivating(true);

    await _windowController.show();
  }

  /// Clamps [size] to [[minSize], [maxSize]], delegates to
  /// [CompanionWindowController], and persists.
  ///
  /// Requirement 1.2
  Future<void> setSize(Size size) async {
    _currentSize = _clampSize(size);
    _logger.info('CompanionWindowManager.setSize(): $_currentSize');
    await _windowController.setSize(_currentSize.width, _currentSize.height);
    _persistSize(_currentSize);
  }

  /// Delegates [position] to [CompanionWindowController]; triggers off-screen
  /// recovery if the intersection with all displays is < [minIntersection]
  /// logical pixels. Persists the final position.
  ///
  /// Requirement 1.5, 1.8
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
    await _windowController.setPosition(resolved.dx, resolved.dy);
    _persistPosition(_currentPosition);
  }

  /// Exposes the existing setOpacity from [CompanionWindowController].
  Future<void> setOpacity(double opacity) async {
    await _windowController.setOpacity(opacity);
  }

  /// Initiates a native window-drag so the OS handles repositioning.
  ///
  /// Called from the 24 px drag handle in [PiPOverlayWindow] (Req 1.5).
  Future<void> startDrag() async {
    await _windowController.startDrag();
  }

  /// Applies the non-activating window style so the companion window never
  /// steals keyboard focus from the user's current application (Req 18.2).
  ///
  /// Called once during [initialize].
  Future<void> setNonActivating(bool nonActivating) async {
    await _windowController.setNonActivating(nonActivating);
  }

  Future<void> setAcceptsMouse(bool accepts) async {
    await _windowController.setAcceptsMouse(accepts);
  }

  Future<Offset> getPosition() async {
    final pos = await _windowController.getPosition();
    _currentPosition = Offset(pos['x'] as double, pos['y'] as double);
    return _currentPosition;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Clamps [size] so width ∈ [[minSize.width], [maxSize.width]] and
  /// height ∈ [[minSize.height], [maxSize.height]].
  static Size _clampSize(Size size) {
    return Size(
      size.width.clamp(minSize.width, maxSize.width),
      size.height.clamp(minSize.height, maxSize.height),
    );
  }

  /// Returns `true` if the maximum intersection area between the window frame
  /// (defined by [position] and [size]) and all available displays is less
  /// than [minIntersection] sq logical pixels.
  ///
  /// When [_displayManager] is unavailable, returns `false` (safe fallback).
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

  /// Returns the recovered window origin, anchored to the closest corner of
  /// the nearest display such that the window is fully contained within it.
  ///
  /// Algorithm:
  /// 1. Find the display whose boundary is nearest to the window center.
  /// 2. Compute the four corner-anchored candidate positions for that display.
  /// 3. Choose the candidate closest to the original window position.
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

    // Find the display whose boundary is nearest to the window centre.
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

  /// Returns the window origin anchored to the corner of [displayRect]
  /// closest to [windowPos], ensuring the window of [size] is fully
  /// contained within [displayRect].
  static Offset _anchorToClosestCorner(
    Offset windowPos,
    Size size,
    Rect displayRect,
  ) {
    // Four candidate placements, one per corner of the display.
    final candidates = [
      Offset(displayRect.left, displayRect.top), // top-left
      Offset(displayRect.right - size.width, displayRect.top), // top-right
      Offset(displayRect.left, displayRect.bottom - size.height), // bottom-left
      Offset(
        displayRect.right - size.width,
        displayRect.bottom - size.height,
      ), // bottom-right
    ];

    // Pick the candidate closest to the original window position.
    Offset best = candidates.first;
    double bestDist = _euclidean(windowPos, candidates.first);
    for (final c in candidates.skip(1)) {
      final d = _euclidean(windowPos, c);
      if (d < bestDist) {
        best = c;
        bestDist = d;
      }
    }

    // Clamp to ensure the window stays inside the display even when the
    // display is smaller than the window.
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

  /// Euclidean distance from [point] to the nearest boundary point of [rect].
  /// Returns 0 when [point] is inside [rect].
  static double _distanceToRect(Offset point, Rect rect) {
    final clampedX = point.dx.clamp(rect.left, rect.right);
    final clampedY = point.dy.clamp(rect.top, rect.bottom);
    return _euclidean(point, Offset(clampedX, clampedY));
  }

  /// Euclidean distance between two offsets.
  static double _euclidean(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  void _persistSize(Size size) {
    try {
      SimplePrefs.instance.setDouble(_keyWindowWidth, size.width);
      SimplePrefs.instance.setDouble(_keyWindowHeight, size.height);
    } catch (e) {
      _logger.warning('CompanionWindowManager._persistSize() failed: $e');
    }
  }

  void _persistPosition(Offset position) {
    try {
      SimplePrefs.instance.setDouble(_keyWindowX, position.dx);
      SimplePrefs.instance.setDouble(_keyWindowY, position.dy);
    } catch (e) {
      _logger.warning('CompanionWindowManager._persistPosition() failed: $e');
    }
  }
}

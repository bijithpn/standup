import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:breakmate/core/errors/error_handler.dart';

/// Lightweight localhost HTTP server that serves the bundled OneWorks 3D Avatar Web Engine.
///
/// Binds dynamically to an ephemeral port on 127.0.0.1 loopback, eliminating CORS,
/// ES Module, and security policy restrictions in WebKit/WKWebView on macOS.
class AvatarWebServer {
  HttpServer? _server;
  int _port = 0;
  Completer<void>? _startCompleter;
  String? _resolvedWebPath;
  String? _resolvedAvatarsPath;
  Map<String, String>? _svgMap;

  bool get isRunning => _server != null;
  int get port => _port;
  String get baseUrl => 'http://127.0.0.1:$_port';

  Uri get companionUrl => Uri.parse('$baseUrl/?companion=1#/companion');
  Uri get editorUrl => Uri.parse('$baseUrl/#/editor');

  Uri buildCompanionUrl({String? queryParams}) {
    if (queryParams != null && queryParams.isNotEmpty) {
      final cleanQuery = queryParams.startsWith('?')
          ? queryParams.substring(1)
          : queryParams;
      return Uri.parse('$baseUrl/?$cleanQuery&companion=1#/companion');
    }
    return companionUrl;
  }

  Uri buildEditorUrl({String? queryParams}) {
    if (queryParams != null && queryParams.isNotEmpty) {
      final cleanQuery = queryParams.startsWith('?')
          ? queryParams.substring(1)
          : queryParams;
      return Uri.parse('$baseUrl/?$cleanQuery#/editor');
    }
    return editorUrl;
  }

  /// Starts the localhost HTTP server on an available port.
  Future<void> start() async {
    if (_server != null) return;
    if (_startCompleter != null) return _startCompleter!.future;

    _startCompleter = Completer<void>();
    _resolveAssetDirectory();
    await _loadSvgMap();

    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0, // Binds to available ephemeral port allocated by OS
      );
      _port = _server!.port;

      _server!.listen(
        _handleRequest,
        onError: (e, st) {
          ErrorHandler().handleError(e, st);
        },
      );
      _startCompleter!.complete();
    } catch (e, st) {
      _startCompleter!.completeError(e, st);
      _startCompleter = null;
      ErrorHandler().handleError(e, st);
      rethrow;
    }
  }

  /// Stops the running server.
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _port = 0;
      _startCompleter = null;
    }
  }

  void _resolveAssetDirectory() {
    if (_resolvedWebPath != null) return;

    // 1. macOS App Bundle relative to resolved executable
    try {
      final exe = File(Platform.resolvedExecutable);
      final exeDir = exe.parent;
      final candidates = [
        // macOS: BreakMate Dev.app/Contents/Frameworks/App.framework/Resources/flutter_assets
        p.join(
          exeDir.parent.path,
          'Frameworks',
          'App.framework',
          'Resources',
          'flutter_assets',
        ),
        p.join(
          exeDir.parent.path,
          'Frameworks',
          'App.framework',
          'Versions',
          'A',
          'Resources',
          'flutter_assets',
        ),
        p.join(
          exeDir.parent.path,
          'Frameworks',
          'App.framework',
          'Versions',
          'Current',
          'Resources',
          'flutter_assets',
        ),
        p.join(exeDir.parent.path, 'Resources', 'flutter_assets'),
        // Windows: flutter_assets alongside .exe
        p.join(exeDir.path, 'data', 'flutter_assets'),
      ];

      for (final candidate in candidates) {
        final webCandidate = p.join(candidate, 'assets', 'avatars', 'web');
        if (Directory(webCandidate).existsSync()) {
          _resolvedWebPath = webCandidate;
          _resolvedAvatarsPath = p.join(candidate, 'assets', 'avatars');
          return;
        }
      }
    } catch (_) {}

    // 2. Direct workspace location during dev/tests
    final localCandidates = [
      'assets/avatars/web',
      'assets/avatars',
      'avatar-main/dist',
      '../assets/avatars/web',
      '../assets/avatars',
    ];

    for (final candidate in localCandidates) {
      final dir = Directory(candidate);
      if (dir.existsSync()) {
        _resolvedWebPath = dir.absolute.path;
        final avatarsDir = Directory(p.join(dir.parent.path));
        if (avatarsDir.existsSync()) {
          _resolvedAvatarsPath = avatarsDir.absolute.path;
        }
        return;
      }
    }
  }

  Future<void> _loadSvgMap() async {
    if (_svgMap != null) return;

    if (_resolvedWebPath != null) {
      final mapFile = File(p.join(_resolvedWebPath!, 'svg_map.json'));
      if (mapFile.existsSync()) {
        try {
          final content = await mapFile.readAsString();
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          _svgMap = decoded.map((k, v) => MapEntry(k, v.toString()));
          return;
        } catch (_) {}
      }
    }

    try {
      final content = await rootBundle.loadString(
        'assets/avatars/web/svg_map.json',
      );
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      _svgMap = decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {}
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    // Support CORS and preflight if needed
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }

    if (request.method != 'GET') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }

    try {
      var requestedPath = request.uri.path;
      if (requestedPath == '/' || requestedPath.isEmpty) {
        requestedPath = '/index.html';
      }

      final fileName = p.basename(requestedPath);
      final hasExtension = p.extension(requestedPath).isNotEmpty;

      // 1. Check if requested asset is a deduplicated SVG mapped to assets/avatars/
      if (fileName.endsWith('.svg') && fileName != 'favicon.svg') {
        await _loadSvgMap();
        final mappedRelative = _svgMap?[fileName];
        if (mappedRelative != null) {
          if (_resolvedAvatarsPath != null) {
            final mappedDiskPath = p.join(
              _resolvedAvatarsPath!,
              mappedRelative,
            );
            final mappedFile = File(mappedDiskPath);
            if (mappedFile.existsSync()) {
              _setContentType(response, mappedDiskPath);
              await response.addStream(mappedFile.openRead());
              await response.close();
              return;
            }
          }

          try {
            final assetKey = 'assets/avatars/$mappedRelative';
            final byteData = await rootBundle.load(assetKey);
            _setContentType(response, fileName);
            response.add(byteData.buffer.asUint8List());
            await response.close();
            return;
          } catch (_) {}
        }
      }

      final cleanPath = requestedPath.startsWith('/')
          ? requestedPath.substring(1)
          : requestedPath;

      // 2. Try serving directly from local file directory if resolved
      if (_resolvedWebPath != null) {
        final filePath = p.join(_resolvedWebPath!, cleanPath);
        final file = File(filePath);

        if (file.existsSync()) {
          _setContentType(response, filePath);
          await response.addStream(file.openRead());
          await response.close();
          return;
        }
      }

      // 3. Fallback to Flutter AssetBundle
      try {
        final assetKey = 'assets/avatars/web/$cleanPath';
        final byteData = await rootBundle.load(assetKey);
        _setContentType(response, requestedPath);
        response.add(byteData.buffer.asUint8List());
        await response.close();
        return;
      } catch (_) {}

      // 4. Fallback to index.html for SPA client-side routing (ONLY for routes without extension)
      if (!hasExtension || requestedPath == '/index.html') {
        if (_resolvedWebPath != null) {
          final indexFile = File(p.join(_resolvedWebPath!, 'index.html'));
          if (indexFile.existsSync()) {
            _setContentType(response, 'index.html');
            await response.addStream(indexFile.openRead());
            await response.close();
            return;
          }
        }

        try {
          final indexData = await rootBundle.load(
            'assets/avatars/web/index.html',
          );
          _setContentType(response, 'index.html');
          response.add(indexData.buffer.asUint8List());
          await response.close();
          return;
        } catch (_) {}
      }

      response.statusCode = HttpStatus.notFound;
      response.write('Not Found');
      await response.close();
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
      try {
        response.statusCode = HttpStatus.internalServerError;
        response.write('Internal Server Error');
        await response.close();
      } catch (_) {}
    }
  }

  void _setContentType(HttpResponse response, String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.html':
        response.headers.contentType = ContentType(
          'text',
          'html',
          charset: 'utf-8',
        );
        break;
      case '.js':
      case '.mjs':
        response.headers.contentType = ContentType(
          'application',
          'javascript',
          charset: 'utf-8',
        );
        break;
      case '.css':
        response.headers.contentType = ContentType(
          'text',
          'css',
          charset: 'utf-8',
        );
        break;
      case '.svg':
        response.headers.contentType = ContentType('image', 'svg+xml');
        break;
      case '.json':
        response.headers.contentType = ContentType(
          'application',
          'json',
          charset: 'utf-8',
        );
        break;
      case '.png':
        response.headers.contentType = ContentType('image', 'png');
        break;
      case '.jpg':
      case '.jpeg':
        response.headers.contentType = ContentType('image', 'jpeg');
        break;
      case '.woff':
        response.headers.contentType = ContentType('font', 'woff');
        break;
      case '.woff2':
        response.headers.contentType = ContentType('font', 'woff2');
        break;
      default:
        response.headers.contentType = ContentType.binary;
    }
  }
}

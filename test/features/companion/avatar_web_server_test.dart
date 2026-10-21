import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/services/avatar_web_server.dart';

void main() {
  group('AvatarWebServer', () {
    late AvatarWebServer server;

    setUp(() {
      server = AvatarWebServer();
    });

    tearDown(() async {
      await server.stop();
    });

    test('starts and binds to loopback port', () async {
      expect(server.isRunning, isFalse);
      await server.start();
      expect(server.isRunning, isTrue);
      expect(server.port, isPositive);
      expect(server.baseUrl, startsWith('http://127.0.0.1:'));
      expect(server.companionUrl.toString(), contains('#/companion'));
      expect(server.editorUrl.toString(), contains('#/editor'));
    });

    test('serves index.html on HTTP GET request', () async {
      await server.start();
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(server.baseUrl));
        final response = await request.close();
        expect(response.statusCode, equals(HttpStatus.ok));
        expect(response.headers.contentType?.mimeType, equals('text/html'));
      } finally {
        client.close();
      }
    });

    test('serves deduplicated SVG from assets/avatars on request', () async {
      await server.start();
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('${server.baseUrl}/assets/sad-D0ZvAuKJ.svg'),
        );
        final response = await request.close();
        expect(response.statusCode, equals(HttpStatus.ok));
        expect(response.headers.contentType?.mimeType, equals('image/svg+xml'));
      } finally {
        client.close();
      }
    });

    test('serves JS bundle with application/javascript MIME type', () async {
      await server.start();
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('${server.baseUrl}/assets/index-DtC4GL6p.js'),
        );
        final response = await request.close();
        expect(response.statusCode, equals(HttpStatus.ok));
        expect(response.headers.contentType?.mimeType, equals('application/javascript'));
      } finally {
        client.close();
      }
    });

    test('serves CSS bundle with text/css MIME type', () async {
      await server.start();
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('${server.baseUrl}/assets/index-CCHSrDdA.css'),
        );
        final response = await request.close();
        expect(response.statusCode, equals(HttpStatus.ok));
        expect(response.headers.contentType?.mimeType, equals('text/css'));
      } finally {
        client.close();
      }
    });

    test('returns 404 for missing static asset files with extension', () async {
      await server.start();
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('${server.baseUrl}/assets/nonexistent-file.js'),
        );
        final response = await request.close();
        expect(response.statusCode, equals(HttpStatus.notFound));
      } finally {
        client.close();
      }
    });

    test('stops cleanly', () async {
      await server.start();
      expect(server.isRunning, isTrue);
      await server.stop();
      expect(server.isRunning, isFalse);
    });
  });
}

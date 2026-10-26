import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// A newer build advertised by the appcast for this platform.
class FeedUpdate {
  const FeedUpdate({
    required this.version,
    required this.notes,
    required this.downloadUrl,
  });

  final String version;
  final String notes;
  final Uri downloadUrl;
}

/// Update check for Windows and Linux, where there is no Sparkle.
///
/// It reads the same appcast macOS uses. An `<enclosure>` is offered to a
/// platform only when it carries `sparkle:os="windows"` / `sparkle:os="linux"`,
/// so the macOS-only entries are never suggested to the wrong OS.
class FeedUpdateChecker {
  FeedUpdateChecker({this.feedUrl = defaultFeedUrl, HttpClient? client})
    : _client = client;

  static const defaultFeedUrl =
      'https://raw.githubusercontent.com/bijithpn/standup/main/appcast.xml';

  final String feedUrl;
  final HttpClient? _client;

  static String get _osKey => Platform.isWindows ? 'windows' : 'linux';

  /// Returns the newest build for this OS if it is newer than the running one,
  /// otherwise null. Throws on network or feed errors.
  Future<FeedUpdate?> check() async {
    final current = int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
    final xml = await _fetch();
    return newestFor(xml, os: _osKey, currentBuild: current);
  }

  Future<String> _fetch() async {
    final client = _client ?? HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(feedUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Update server returned ${response.statusCode}');
      }
      return await response.transform(utf8.decoder).join();
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Pure parsing step, split out so it can be tested without a network.
  static FeedUpdate? newestFor(
    String xml, {
    required String os,
    required int currentBuild,
  }) {
    FeedUpdate? best;
    var bestBuild = currentBuild;

    final items = RegExp(r'<item>(.*?)</item>', dotAll: true).allMatches(xml);
    for (final item in items) {
      final body = item.group(1)!;
      final tag = RegExp(r'<enclosure\b[^>]*>', dotAll: true).firstMatch(body);
      if (tag == null) continue;

      final attrs = {
        for (final m in RegExp(r'([\w:]+)="([^"]*)"').allMatches(tag.group(0)!))
          m.group(1)!: m.group(2)!,
      };
      if (attrs['sparkle:os'] != os) continue;

      final build = int.tryParse(attrs['sparkle:version'] ?? '');
      final url = Uri.tryParse(attrs['url'] ?? '');
      if (build == null || url == null || build <= bestBuild) continue;

      final notes = RegExp(
        r'<description><!\[CDATA\[(.*?)\]\]></description>',
        dotAll: true,
      ).firstMatch(body)?.group(1)?.trim();

      bestBuild = build;
      best = FeedUpdate(
        version: attrs['sparkle:shortVersionString'] ?? '$build',
        notes: notes ?? '',
        downloadUrl: url,
      );
    }
    return best;
  }
}

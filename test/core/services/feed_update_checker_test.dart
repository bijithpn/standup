import 'package:breakmate/core/services/feed_update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

String _item(String version, int build, {String? os}) =>
    '''
<item><description><![CDATA[<p>notes $version</p>]]></description>
<enclosure url="https://example.com/$version"
 sparkle:version="$build" sparkle:shortVersionString="$version"${os == null ? '' : ' sparkle:os="$os"'} /></item>''';

void main() {
  test('ignores entries without a matching sparkle:os', () {
    final xml = _item('1.9.0', 50) + _item('1.8.0', 40, os: 'windows');
    expect(
      FeedUpdateChecker.newestFor(xml, os: 'windows', currentBuild: 45),
      isNull,
    );
  });

  test('offers the newest build for the platform', () {
    final xml =
        _item('1.9.0', 50, os: 'linux') +
        _item('2.0.0', 60, os: 'linux') +
        _item('3.0.0', 70, os: 'windows');
    final update = FeedUpdateChecker.newestFor(
      xml,
      os: 'linux',
      currentBuild: 42,
    );
    expect(update?.version, '2.0.0');
    expect(update?.notes, '<p>notes 2.0.0</p>');
  });

  test('returns null when already current', () {
    expect(
      FeedUpdateChecker.newestFor(
        _item('1.9.0', 50, os: 'linux'),
        os: 'linux',
        currentBuild: 50,
      ),
      isNull,
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/ipc/single_instance_token.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('bm_token_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('create stores a 64-char token that read returns', () async {
    final token = await SingleInstanceToken.create(dir);
    expect(token, hasLength(64));
    expect(await SingleInstanceToken.read(dir), token);
  });

  test('token file is owner-only on POSIX', () async {
    await SingleInstanceToken.create(dir);
    final mode = File('${dir.path}/ipc.token').statSync().mode & 0x1FF;
    expect(mode, 384); // 0600
  }, skip: Platform.isWindows);

  test('authorize accepts the right token and rejects others', () {
    expect(SingleInstanceToken.authorize('abc shutdown\n', 'abc'), 'shutdown');
    expect(SingleInstanceToken.authorize('bad shutdown\n', 'abc'), isNull);
    expect(SingleInstanceToken.authorize('shutdown\n', 'abc'), isNull);
    expect(SingleInstanceToken.authorize('abc shutdown', null), isNull);
  });
}

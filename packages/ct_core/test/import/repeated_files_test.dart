import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('ct_repeats_test_'));
  tearDown(() => dir.delete(recursive: true));

  String file(String name, String text) => (File(p.join(dir.path, name))..writeAsStringSync(text)).path;

  test('same bytes repeat an open page or an earlier added file', () async {
    final a = file('a.png', 'aaaa'), b = file('b.png', 'bbbb'), c = file('c.png', 'cccccc');
    final copyOfA = file('copy of a.png', 'aaaa');
    final sameSize = file('d.png', 'dddd');
    final e1 = file('e1.png', 'eeeee'), e2 = file('e2.png', 'eeeee');
    expect(await findRepeatedFiles([a, b, c], [copyOfA, sameSize, e1, e2, a]), [0, null, null, 5, 0]);
  });

  test('missing files repeat nothing', () async {
    final a = file('a.png', 'aaaa');
    final gone = p.join(dir.path, 'gone.png');
    expect(await findRepeatedFiles([gone], [a, gone]), [null, null]);
  });
}

import 'dart:io';

import 'package:comic_translate/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppInfo.version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(AppInfo.version, match!.group(1));
  });
}

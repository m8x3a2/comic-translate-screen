// Program icon: the user's picture becomes an .ico, the choice reaches the window.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_icon.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/window_mode.dart' show windowChannel;
import 'package:comic_translate/ui/app.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

/// Settings kept in memory: this test is about the window, not the file.
class _MemorySettings extends SettingsNotifier {
  @override
  Future<void> change(void Function(AppSettings s) change) async {
    final next = AppSettings.fromJson(state.toJson());
    change(next);
    state = next;
  }
}

/// A wide red picture: the icon must keep it whole (transparent above and below).
Future<Uint8List> _picture() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 600, 300), Paint()..color = const Color(0xFFFF0000));
  final image = await recorder.endRecording().toImage(600, 300);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

List<int> _icoSizes(Uint8List ico) {
  final d = ByteData.sublistView(ico);
  return [for (var n = 0; n < d.getUint16(4, Endian.little); n++) ico[6 + 16 * n] == 0 ? 256 : ico[6 + 16 * n]];
}

void main() {
  late Directory dir;
  late AppServices services;
  final iconCalls = <Object?>[];

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('cts_icon_test_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: fakeRegistry(),
    );
    services.appLog.info('test_start');
    await services.appLog.flush();
    iconCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, (
      call,
    ) async {
      if (call.method == 'setIcon') iconCalls.add(call.arguments);
      return true;
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, null);
    await services.dispose();
    dir.deleteSync(recursive: true);
  });

  testWidgets('a picture becomes an icon of every size, centred and whole', (tester) async {
    await tester.runAsync(() async {
      final src = File(p.join(dir.path, 'cat.png'))..writeAsBytesSync(await _picture());
      await makeCustomIcon(src.path, services.paths);
      final ico = services.paths.customIcon.readAsBytesSync();
      expect(_icoSizes(ico), icoSizes);
      // 16 px: a 2:1 picture is 16x8, centred: rows 0-3 clear, the middle red
      final d = ByteData.sublistView(ico);
      final off16 = d.getUint32(6 + 12, Endian.little);
      int alphaAt(int x, int y) => ico[off16 + 40 + ((15 - y) * 16 + x) * 4 + 3];
      expect(alphaAt(8, 1), 0);
      expect(alphaAt(8, 8), 255);
      expect(ico[off16 + 40 + ((15 - 8) * 16 + 8) * 4 + 2], greaterThan(200), reason: 'red, stored as BGRA');
      expect(services.paths.customIconPreview.existsSync(), isTrue);
    });
    expect(appIconSource('custom', services.paths), services.paths.customIcon.path);
  });

  testWidgets('an .ico is kept as it is; something that is not a picture is refused', (tester) async {
    await tester.runAsync(() async {
      final source = File(p.join('windows', 'runner', 'resources', 'app_icon_navy.ico'));
      await makeCustomIcon(source.path, services.paths);
      expect(services.paths.customIcon.readAsBytesSync(), source.readAsBytesSync());

      final bad = File(p.join(dir.path, 'notes.png'))..writeAsStringSync('not a picture');
      await expectLater(makeCustomIcon(bad.path, services.paths), throwsA(anything));
    });
  });

  test('without its file the own icon falls back to the blue one', () {
    expect(appIconSource('custom', services.paths), 'blue');
    expect(appIconSource('navy', services.paths), 'navy');
    expect(appIconSource('blue', services.paths), 'blue');
  });

  testWidgets('the window gets the icon at start and when another one is chosen', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider.overrideWithValue(services),
          initialSettingsProvider.overrideWithValue(fakeSettings()),
          workerRegistryProvider.overrideWithValue(fakeRegistry),
          settingsProvider.overrideWith(_MemorySettings.new),
        ],
        child: const ComicTranslateApp(),
      ),
    );
    await tester.pump();
    expect(iconCalls, ['blue']);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final navy = find.text('Тёмно-синяя');
    await tester.ensureVisible(navy);
    await tester.tap(navy);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    expect(container.read(settingsProvider).appIcon, 'navy');
    expect(iconCalls, ['blue', 'navy']);
    expect(find.text('Обновить ярлыки'), findsOneWidget);
  });
}

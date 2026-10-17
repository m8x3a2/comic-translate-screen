import 'dart:io';

import 'package:comic_translate/app_info.dart';
import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/gui/gui_main.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Real file IO (the app log) must not run inside testWidgets' fake-async
  // zone, so services are created and disposed outside of it.
  late Directory dir;
  late AppServices services;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('cts_gui_test_');
    services = AppServices.create(dataDirOverride: dir.path, secretStore: MemorySecretStore());
  });

  tearDownAll(() async {
    await services.dispose();
    dir.deleteSync(recursive: true);
  });

  testWidgets('GUI starts and shows the app name', (tester) async {
    await tester.pumpWidget(ComicTranslateApp(services: services));
    expect(find.text(AppInfo.name), findsOneWidget);
  });
}

// Several OpenRouter keys: the run stopped on money offers the other key.

import 'dart:async';
import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:comic_translate/ui/shell_full/batch_dialogs.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_plugins.dart';

void main() {
  late Directory dir;
  late AppServices services;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_openrouter_keys_test_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: fakeRegistry(),
    );
    services.appLog.info('test_start');
  });

  tearDown(() async {
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // still open; the folder is in temp
    }
  });

  Future<ProviderContainer> open(WidgetTester tester, AppSettings settings) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider.overrideWithValue(services),
          initialSettingsProvider.overrideWithValue(settings),
          workerRegistryProvider.overrideWithValue(fakeRegistry),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const ComicTranslateApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  BatchReport stopped(TranslationErrorKind kind) => BatchReport(
    total: 3,
    done: 1,
    skipped: const [],
    cancelled: false,
    duration: const Duration(seconds: 5),
    stoppedBy: TranslationFailedReason(kind, 'no credits'),
  );

  testWidgets('no money on the key: "Go on with" the other key switches to it', (tester) async {
    final settings = fakeSettings()..translator = 'openrouter';
    settings.setOwnServerKeys(AppSettings.openRouterKeysId, OwnServerKeys(notes: {'2': 'запасной'}));
    final container = await open(tester, settings);
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(showBatchReport(context, stopped(TranslationErrorKind.credits)));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('switch-key/2'));
    expect(button, findsOneWidget);
    expect(find.textContaining('Ключ 2 · запасной'), findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).keysForOwnServer('openrouter').activeId, '2');
  });

  testWidgets('another reason, or a single key: no such button', (tester) async {
    final settings = fakeSettings()..translator = 'openrouter';
    await open(tester, settings);
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(showBatchReport(context, stopped(TranslationErrorKind.credits)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('switch-key/2')), findsNothing);
    expect(find.byIcon(Icons.key_outlined), findsNothing);
  });
}


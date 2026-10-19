// Settings back to their defaults: one section, or all.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/settings_reset.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_plugins.dart';

AppSettings changed() => AppSettings(
  translator: 'mock',
  theme: 'light',
  testMode: true,
  extraContext: 'witches',
  render: const RenderSettings(maxFontSize: 60),
  recentProjects: ['a.ctsproj'],
  plugins: {
    'openai_compatible': {'api_url': 'https://openrouter.ai/api/v1'},
    'aot': {'x': 1},
  },
  approvedNetworkPlugins: {'openai_compatible@openrouter.ai'},
)..sourceLanguage = 'Japanese';

/// Settings kept in memory: this test is about the window, not the file.
class _MemorySettings extends SettingsNotifier {
  @override
  Future<void> change(void Function(AppSettings s) change) async {
    final next = AppSettings.fromJson(state.toJson());
    change(next);
    state = next;
  }
}

void main() {
  final registry = builtInRegistry();

  test('one section: only its settings go back', () {
    final s = changed();
    resetSettings(s, registry, part: SettingsPart.translator);
    expect((s.translator, s.extraContext), (AppSettings().translator, ''));
    expect(s.approvedNetworkPlugins, isEmpty);
    expect(s.plugins.keys, ['aot'], reason: 'tools keep their settings');
    expect((s.theme, s.render.maxFontSize, s.sourceLanguage), ('light', 60, 'Japanese'));

    resetSettings(s, registry, part: SettingsPart.text);
    expect(s.render.maxFontSize, AppSettings().render.maxFontSize);
  });

  test('all: everything but the recent projects', () {
    final s = changed();
    resetSettings(s, registry);
    expect(s.toJson()..remove('projects'), AppSettings().toJson()..remove('projects'));
    expect(s.recentProjects, ['a.ctsproj']);
  });

  late Directory dir;
  late AppServices services;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('cts_reset_test_');
    services = AppServices.create(dataDirOverride: dir.path, secretStore: MemorySecretStore(), registry: fakeRegistry());
    // The log file is opened here, outside the test's fake clock.
    services.appLog.info('test_start');
    await services.appLog.flush();
  });
  tearDown(() async {
    await services.dispose();
    dir.deleteSync(recursive: true);
  });

  testWidgets('the reset buttons ask first', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider.overrideWithValue(services),
          initialSettingsProvider.overrideWithValue(fakeSettings()..testMode = true),
          workerRegistryProvider.overrideWithValue(fakeRegistry),
          settingsProvider.overrideWith(_MemorySettings.new),
        ],
        child: const ComicTranslateApp(),
      ),
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сбросить раздел'));
    await tester.tap(find.text('Сбросить раздел'));
    await tester.pumpAndSettle();
    expect(find.text('Сбросить настройки?'), findsOneWidget);
    // Resetting itself is tested above; here the window asks and can be cancelled.
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    expect(container.read(settingsProvider).testMode, isTrue);
    expect(find.text('Сбросить все настройки'), findsOneWidget);
  });
}

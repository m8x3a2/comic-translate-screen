// Ready-made sets, templates and the locks of the sections (step 9).

import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/settings_reset.dart';
import 'package:comic_translate/state/settings_templates.dart';
import 'package:comic_translate/ui/app.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_plugins.dart';

void main() {
  final registry = fakeRegistry();

  group('sets', () {
    test('"Weak computer" lightens reading and cleaning; "Recommended" brings the defaults back', () {
      final s = AppSettings();
      applyPreset(s, SettingsPreset.weak, vlm: false);
      expect(s.textPrep, waifu2xCunetId);
      expect(s.readLevel, ReadLevel.simple);
      expect(s.textPrepSeconds, 30);
      expect(CleanLevel.of(s), CleanLevel.simple);
      applyPreset(s, SettingsPreset.recommended, vlm: false);
      final d = AppSettings();
      expect(
        (s.textPrep, s.readLevel, s.textPrepSeconds, s.inpainter, s.textMask),
        (d.textPrep, d.readLevel, d.textPrepSeconds, d.inpainter, d.textMask),
      );
    });

    test('"High quality" reads at "High" only with the reader for it', () {
      final s = AppSettings();
      applyPreset(s, SettingsPreset.high, vlm: false);
      expect(s.readLevel, ReadLevel.medium);
      applyPreset(s, SettingsPreset.high, vlm: true);
      expect(s.readLevel, ReadLevel.high);
      expect(s.textPrepSeconds, 180);
    });

    test('a locked section is left alone and told', () {
      final s = AppSettings()..lockedParts.add(SettingsPart.cleaning.name);
      applyPreset(s, SettingsPreset.weak, vlm: false);
      expect(s.readLevel, ReadLevel.simple);
      expect(CleanLevel.of(s), CleanLevel.high, reason: 'cleaning is locked');
      expect(presetBlockedBy(s, SettingsPreset.weak, vlm: false), [SettingsPart.cleaning]);
    });
  });

  group('templates', () {
    test('nothing private or of this computer goes into a template', () {
      final s = AppSettings(
        recentProjects: ['C:/secret/project.ctsproj'],
        gpuCpuModels: {'a': 'b'},
        approvedNetworkPlugins: {'openrouter@openrouter.ai'},
        ownServerNames: {'1': 'Home'},
        modelsDir: 'D:/models',
        textPanelWidth: 400,
      )..plugins['${AppSettings.ownServerStoragePrefix}1'] = {'api_url': 'http://10.0.0.2'};
      final text = SettingsTemplate.encode('Mine', s);
      for (final bit in ['secret', 'gpu_cpu_models', 'approved', 'Home', 'D:/models', 'text_panel_width', '10.0.0.2']) {
        expect(text, isNot(contains(bit)), reason: bit);
      }
      final back = SettingsTemplate.decode(text);
      expect(back.name, 'Mine');
      expect(back.settings.readLevel, s.readLevel);
    });

    test('not a template file is told', () {
      expect(() => SettingsTemplate.decode('{"a": 1}'), throwsFormatException);
      expect(() => SettingsTemplate.decode('not json'), throwsFormatException);
    });

    test('applied: only the unlocked sections, or entirely with its locks', () {
      final mine = AppSettings(theme: 'light', readLevel: ReadLevel.simple)..lockedParts.add(SettingsPart.ocr.name);
      final t = SettingsTemplate.decode(
        SettingsTemplate.encode(
          'T',
          AppSettings(theme: 'dark', readLevel: ReadLevel.high, sourceLanguage: 'Japanese')
            ..lockedParts.add(SettingsPart.text.name),
        ),
      );
      final partly = AppSettings.fromJson(mine.toJson());
      t.applyTo(partly, registry, unlockedOnly: true);
      expect(partly.theme, 'dark');
      expect(partly.sourceLanguage, 'Japanese');
      expect(partly.readLevel, ReadLevel.simple, reason: 'the reading is locked');
      expect(partly.lockedParts, {SettingsPart.ocr.name});
      final whole = AppSettings.fromJson(mine.toJson());
      t.applyTo(whole, registry, unlockedOnly: false);
      expect(whole.readLevel, ReadLevel.high);
      expect(whole.lockedParts, {SettingsPart.text.name});
    });

    test('kept in the folder and listed by name', () async {
      final dir = Directory.systemTemp.createTempSync('cts_templates_');
      addTearDown(() => dir.deleteSync(recursive: true));
      await saveTemplate(dir, 'Б: быстрый?', AppSettings());
      await saveTemplate(dir, 'А', AppSettings());
      File('${dir.path}/broken$settingsTemplateExtension').writeAsStringSync('{');
      final list = await listTemplates(dir);
      expect(list.map((t) => t.name), ['А', 'Б: быстрый?']);
      expect(templateFileName('a/b:c?'), 'a_b_c_$settingsTemplateExtension');
    });
  });

  late Directory dir;
  late AppServices services;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cts_settings_sets_test_');
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

  testWidgets('a set shows what changes; a lock keeps its section; a template is saved and listed', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider.overrideWithValue(services),
          initialSettingsProvider.overrideWithValue(fakeSettings()),
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
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    // Lock "Cleaning" from the General section's neighbour: open it and lock.
    await tester.tap(find.widgetWithText(ListTile, 'Очистка'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lock/cleaning')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect(container.read(settingsProvider).lockedParts, {'cleaning'});
    expect(find.byIcon(Icons.lock), findsWidgets, reason: 'the list shows the lock');

    await tester.tap(find.widgetWithText(ListTile, 'Общие'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('preset/weak')));
    await tester.tap(find.byKey(const ValueKey('preset/weak')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не меняется'), findsOneWidget, reason: 'the locked cleaning is told');
    await tester.tap(find.text('Применить'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final s = container.read(settingsProvider);
    expect(s.readLevel, ReadLevel.simple);
    expect((s.inpainter, s.textMask), (fakeSettings().inpainter, fakeSettings().textMask), reason: 'locked');

    // A template of these settings.
    await tester.ensureVisible(find.byKey(const ValueKey('template-save')));
    await tester.tap(find.byKey(const ValueKey('template-save')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('template-name')), 'Ноутбук');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pump();
    for (var i = 0; i < 20 && find.byKey(const ValueKey('template/Ноутбук')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('template/Ноутбук')), findsOneWidget);
    final file = File('${services.paths.settingsTemplates.path}/Ноутбук$settingsTemplateExtension');
    final saved = await tester.runAsync(() => file.readAsString());
    expect((jsonDecode(saved!) as Map)['name'], 'Ноутбук');
    await tester.pumpAndSettle();
  });
}

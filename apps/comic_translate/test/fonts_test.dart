// Fonts the user adds: copied into the program's folder, listed, removed.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/ui/common/fonts.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('added fonts are copied, listed by name and can be removed', () async {
    final dir = Directory.systemTemp.createTempSync('cts_fonts_test_');
    final services = AppServices.create(dataDirOverride: dir.path, secretStore: MemorySecretStore(), registry: fakeRegistry());
    final container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(services),
        initialSettingsProvider.overrideWithValue(fakeSettings()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await services.dispose();
      dir.deleteSync(recursive: true);
    });
    expect(container.read(addedFontsProvider), isEmpty);

    final downloads = Directory(p.join(dir.path, 'downloads'))..createSync();
    final fonts = [
      for (final n in ['Wild Words.ttf', 'anime.OTF', 'readme.txt'])
        (File(p.join(downloads.path, n))..writeAsBytesSync([0, 1, 0, 0])).path,
    ];
    final added = await container.read(addedFontsProvider.notifier).add(fonts);
    expect(added.map(p.basename), ['Wild Words.ttf', 'anime.OTF'], reason: 'only font files');
    expect(container.read(addedFontsProvider).map(fontLabel), ['anime', 'Wild Words']);
    expect(p.isWithin(services.paths.fonts.path, added.first), isTrue);
    expect(File(fonts.first).existsSync(), isTrue, reason: 'the original stays');

    container.read(addedFontsProvider.notifier).remove(added.first);
    expect(container.read(addedFontsProvider).map(fontLabel), ['anime']);
  });
}

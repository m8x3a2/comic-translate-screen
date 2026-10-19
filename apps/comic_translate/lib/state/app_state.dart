/// App-wide state: services and the user's settings.
library;

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap.dart';

/// Set in `ProviderScope.overrides` at startup.
final servicesProvider = Provider<AppServices>((ref) => throw UnimplementedError('servicesProvider not set'));

/// Builds the plugin registry inside the pipeline worker (a top-level
/// function; tests use fakes).
final workerRegistryProvider = Provider<PluginRegistry Function()>((ref) => builtInRegistry);

/// Files given on the command line ("Open with" in Explorer), opened at
/// startup.
final initialInputsProvider = Provider<List<String>>((ref) => const []);

/// `--translate` on the command line: run "Translate all" once the files
/// are open (for automated checks of the window).
final translateOnStartProvider = Provider<bool>((ref) => false);

/// `--settings=<section>`: open the settings at a section on start (for
/// automated checks of the window).
final settingsOnStartProvider = Provider<String?>((ref) => null);

/// Settings loaded at startup; set in `ProviderScope.overrides`.
final initialSettingsProvider = Provider<AppSettings>((ref) => AppSettings());

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// The current settings; every change is saved to `settings.json` at once.
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  /// Applies [change] to a copy of the settings and saves it.
  Future<void> change(void Function(AppSettings s) change) async {
    final next = AppSettings.fromJson(state.toJson());
    change(next);
    final services = ref.read(servicesProvider);
    if (next.modelsDir != state.modelsDir) services.useModelsDir(next.modelsDir);
    state = next;
    await services.settingsStore.save(next);
  }
}

/// Preparing small text for reading without a neural network: plain Lanczos
/// enlargement of the pieces (see `reading_scale.dart`). New in this
/// project; the neural ones are plugins in `ct_providers`.
library;

import '../image/raster.dart';
import '../models/model_manager.dart';
import '../plugins/settings_schema.dart';
import '../imaging/pil.dart';
import '../plugins/engines.dart';
import '../plugins/plugin.dart';
import '../plugins/registry.dart';

const textPrepOffId = 'text_prep_off';
const plainX15Id = 'plain_x1_5';
const plainX2Id = 'plain_x2';

const textPrepOffInfo = PluginInfo(
  id: textPrepOffId,
  displayName: 'No enlargement',
  description: 'Small text is read as it is.',
  kind: PluginKind.textPrep,
  privacy: Privacy.local,
);

const plainX15Info = PluginInfo(
  id: plainX15Id,
  displayName: 'Plain ×1.5 (no neural network)',
  description: 'Instant. Best for sites and games: their letters are sharp already.',
  kind: PluginKind.textPrep,
  privacy: Privacy.local,
);

const plainX2Info = PluginInfo(
  id: plainX2Id,
  displayName: 'Plain ×2 (no neural network)',
  description: 'Instant. For comics on a slow computer.',
  kind: PluginKind.textPrep,
  privacy: Privacy.local,
);

final textPrepOffFactory = PluginFactory<TextUpscaler>(
  textPrepOffInfo,
  (config, env) async => PlainTextUpscaler(textPrepOffInfo, 1),
);
final plainX15Factory = PluginFactory<TextUpscaler>(
  plainX15Info,
  (config, env) async => PlainTextUpscaler(plainX15Info, 1.5),
);
final plainX2Factory = PluginFactory<TextUpscaler>(
  plainX2Info,
  (config, env) async => PlainTextUpscaler(plainX2Info, 2),
);

/// Lanczos enlargement (as PIL's, which the experiment used).
class PlainTextUpscaler implements TextUpscaler {
  PlainTextUpscaler(this.info, this.factor);

  /// Plain ×2: also what a neural network falls back to when its model is
  /// not downloaded.
  PlainTextUpscaler.x2() : this(plainX2Info, 2);

  @override
  final PluginInfo info;

  @override
  final double factor;

  @override
  Future<RgbImage> enlarge(RgbImage piece, int width, int height, PluginContext context) async =>
      pilResize(piece, width, height, filter: PilFilter.lanczos);

  @override
  double estimateMs(int width, int height) => 0;

  @override
  Future<void> dispose() async {}
}

/// The text preparation [id] (see `AppSettings.activeTextPrep`). A neural
/// network whose model is not downloaded gives way to plain ×2: preparing
/// is an improvement, not a reason to stop (the models are offered for
/// download before a run anyway).
Future<TextUpscaler> loadTextPrep(
  PluginRegistry registry,
  String id,
  PluginConfig? config,
  PluginEnvironment env,
) async {
  if (!registry.contains(id)) {
    env.log.warn('text_prep_unknown', {'id': id});
    return PlainTextUpscaler.x2();
  }
  try {
    return await registry.instance<TextUpscaler>(id, config ?? PluginConfig(), env);
  } on ModelNotInstalledException catch (e) {
    env.log.warn('text_prep_model_missing', {'id': id, 'error': e.toString()});
    return PlainTextUpscaler.x2();
  }
}

import 'package:ct_core/ct_core.dart';

import 'src/detection/rtdetr_v2.dart';
import 'src/ocr/ppocr.dart';

/// Registers every built-in plugin. Adding a provider = one line here.
void registerBuiltInPlugins(PluginRegistry registry) {
  registry.register(rtdetrV2Factory);
  registry.register(ppocrFactory);
}

/// A registry with all built-in plugins.
PluginRegistry builtInRegistry() {
  final registry = PluginRegistry();
  registerBuiltInPlugins(registry);
  return registry;
}

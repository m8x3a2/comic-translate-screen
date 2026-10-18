import 'package:ct_core/ct_core.dart';

import 'src/detection/rtdetr_v2.dart';
import 'src/ocr/default_ocr.dart';
import 'src/ocr/manga_ocr.dart';
import 'src/ocr/ppocr.dart';

/// Registers every built-in plugin. Adding a provider = one line here.
void registerBuiltInPlugins(PluginRegistry registry) {
  registry.register(rtdetrV2Factory);
  registry.register(defaultOcrFactory);
  registry.register(ppocrFactory);
  registry.register(mangaOcrFactory);
}

/// A registry with all built-in plugins.
PluginRegistry builtInRegistry() {
  final registry = PluginRegistry();
  registerBuiltInPlugins(registry);
  return registry;
}

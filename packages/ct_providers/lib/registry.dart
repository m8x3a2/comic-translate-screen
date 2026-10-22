import 'package:ct_core/ct_core.dart';

import 'src/detection/ppocr_lines.dart';
import 'src/detection/rtdetr_v2.dart';
import 'src/inpainting/aot.dart';
import 'src/inpainting/lama.dart';
import 'src/ocr/default_ocr.dart';
import 'src/ocr/manga_ocr.dart';
import 'src/ocr/ppocr.dart';
import 'src/ocr/windows_ocr.dart';
import 'src/translation/mock.dart';
import 'src/translation/openai_compatible.dart';

/// Registers every built-in plugin. Adding a provider = one line here.
void registerBuiltInPlugins(PluginRegistry registry) {
  registry.register(rtdetrV2Factory);
  registry.register(ppocrLinesFactory);
  registry.register(defaultOcrFactory);
  registry.register(ppocrFactory);
  registry.register(mangaOcrFactory);
  registry.register(windowsOcrFactory);
  registry.register(openAiCompatibleFactory);
  registry.register(mockTranslatorFactory);
  registry.register(aotFactory);
  registry.register(lamaFactory);
}

/// A registry with all built-in plugins.
PluginRegistry builtInRegistry() {
  final registry = PluginRegistry();
  registerBuiltInPlugins(registry);
  return registry;
}

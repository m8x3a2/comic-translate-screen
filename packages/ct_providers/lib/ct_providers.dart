/// Built-in plugins of Comic Translate Screen.
library;

export 'registry.dart';
export 'src/detection/ppocr_lines.dart';
export 'src/detection/rtdetr_v2.dart';
export 'src/exchange/chat_exchange.dart';
export 'src/inpainting/aot.dart';
export 'src/inpainting/comic_text_detector.dart';
export 'src/inpainting/lama.dart';
export 'src/ocr/default_ocr.dart';
export 'src/ocr/manga_ocr.dart';
export 'src/ocr/paddleocr_vl.dart';
export 'src/ocr/ppocr.dart';
export 'src/ocr/script_id.dart';
export 'src/ocr/windows_ocr.dart';
export 'src/text_prep/neural_upscalers.dart';
export 'src/translation/mock.dart';
export 'src/translation/openai_compatible.dart';
export 'src/translation/openrouter.dart';
export 'src/translation/opus_mt.dart';

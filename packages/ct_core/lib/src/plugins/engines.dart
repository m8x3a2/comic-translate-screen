import '../image/raster.dart';
import '../model/geometry.dart';
import '../model/text_block.dart';
import 'plugin.dart';

/// Finds text blocks (and speech bubbles) on a page.
abstract interface class TextDetector implements Plugin {
  Future<List<TextBlock>> detect(RgbImage image, PluginContext context);
}

/// A detector that also finds single lines of text (new in this project):
/// used to check the lines the heuristics split other detectors' blocks
/// into (see `line_check.dart`).
abstract interface class LineDetector implements TextDetector {
  /// Whole lines of text on [image] (image pixels).
  Future<List<BBox>> findLines(RgbImage image, PluginContext context);
}

/// Recognizes the text of each block; fills `TextBlock.text` (and `texts`).
abstract interface class OcrEngine implements Plugin {
  /// [sourceLanguage] is a canonical language name (`English`, `Korean`,
  /// ...) or `Auto`.
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  });
}

/// Prepares small text for reading: enlarges the pieces of a page where the
/// lines are thin (see `reading_scale.dart`). New in this project.
abstract interface class TextUpscaler implements Plugin {
  /// How much larger the pieces become; 1: small text is read as it is.
  double get factor;

  /// [piece] enlarged to [width]×[height] (about [factor] times its size).
  Future<RgbImage> enlarge(RgbImage piece, int width, int height, PluginContext context);

  /// Rough time to enlarge a [width]×[height] piece on the processor (ms);
  /// 0 for instant ones. Keeps a page within `readingNeuralBudgetMs`.
  double estimateMs(int width, int height);
}

class TranslationRequest {
  TranslationRequest({
    required this.blocks,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.pageImage,
    this.extraContext = '',
    this.keys,
    this.pageImages = const [],
  });

  /// Blocks in reading order; translators fill `TextBlock.translation`.
  final List<TextBlock> blocks;
  final String sourceLanguage;
  final String targetLanguage;

  /// The page itself, for engines that accept an image as context. Only set
  /// when the user enabled "send page image".
  final RgbImage? pageImage;

  /// Free-form context about the comic, from settings.
  final String extraContext;

  /// The name of each block in the request (several pages in one request:
  /// their labels, `01-003`); null: `block_0`, `block_1`… as the original.
  final List<String>? keys;

  /// Several pages in one request: their pictures (with "send page image").
  final List<RgbImage> pageImages;

  /// The key of block [i] (see [keys]).
  String keyOf(int i) => keys?[i] ?? 'block_$i';

  /// The same request for [some] of its blocks only (their keys kept).
  TranslationRequest only(List<TextBlock> some) => TranslationRequest(
    blocks: some,
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    pageImage: pageImage,
    extraContext: extraContext,
    keys: keys == null ? null : [for (final b in some) keys![blocks.indexOf(b)]],
    pageImages: pageImages,
  );
}

/// Translates recognized text.
abstract interface class Translator implements Plugin {
  Future<void> translate(TranslationRequest request, PluginContext context);
}

/// How large images are handled before inpainting (`HDStrategy` in the
/// original `modules/inpainting/schema.py`).
enum HdStrategy {
  /// Inpaint at the original size.
  original,

  /// Downscale the longer side to [InpaintConfig.resizeLimit], inpaint, then
  /// upscale; pixels outside the mask keep full quality.
  resize,

  /// Inpaint crops around masked regions (with a margin) at full size.
  crop,
}

class InpaintConfig {
  const InpaintConfig({
    this.strategy = HdStrategy.resize,
    this.resizeLimit = 960,
    this.cropMargin = 512,
    this.cropTriggerSize = 512,
  });

  final HdStrategy strategy;
  final int resizeLimit;
  final int cropMargin;
  final int cropTriggerSize;

  Map<String, Object?> toJson() => {
    'strategy': strategy.name,
    'resize_limit': resizeLimit,
    'crop_margin': cropMargin,
    'crop_trigger_size': cropTriggerSize,
  };
}

/// Finds the letters themselves (pixels of text) on a page, so that the
/// network removes the letters and little of the drawing around them (new in
/// this project, see `generateMask`).
abstract interface class TextMasker implements Plugin {
  /// 255 where a pixel belongs to text, 0 elsewhere; the size of [image].
  Future<GrayImage> letters(RgbImage image, PluginContext context);
}

/// Removes masked content (the original text) from an image.
abstract interface class Inpainter implements Plugin {
  /// [mask]: 255 where content must be removed. Returns a new image of the
  /// same size.
  Future<RgbImage> inpaint(RgbImage image, GrayImage mask, InpaintConfig config, PluginContext context);
}

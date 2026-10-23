import '../image/raster.dart';
import '../model/text_block.dart';
import 'plugin.dart';

/// Finds text blocks (and speech bubbles) on a page.
abstract interface class TextDetector implements Plugin {
  Future<List<TextBlock>> detect(RgbImage image, PluginContext context);
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
}

class TranslationRequest {
  TranslationRequest({
    required this.blocks,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.pageImage,
    this.extraContext = '',
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

/// Removes masked content (the original text) from an image.
abstract interface class Inpainter implements Plugin {
  /// [mask]: 255 where content must be removed. Returns a new image of the
  /// same size.
  Future<RgbImage> inpaint(RgbImage image, GrayImage mask, InpaintConfig config, PluginContext context);
}

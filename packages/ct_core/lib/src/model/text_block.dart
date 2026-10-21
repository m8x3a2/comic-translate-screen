import '../render/block_style.dart';
import 'geometry.dart';

/// Where a block of text sits on the page.
enum TextClass {
  /// Inside (or overlapping) a speech bubble.
  bubble('text_bubble'),

  /// Free-standing text: captions, sound effects, signs.
  free('text_free'),

  unknown('');

  const TextClass(this.id);

  /// The identifier used by the original code and in JSON.
  final String id;

  static TextClass parse(String? id) =>
      values.firstWhere((c) => c.id == id, orElse: () => TextClass.unknown);
}

/// Reading/layout direction of a block's source text.
enum TextDirection {
  horizontal('horizontal'),
  vertical('vertical'),
  unknown('');

  const TextDirection(this.id);

  final String id;

  static TextDirection parse(String? id) =>
      values.firstWhere((d) => d.id == id, orElse: () => TextDirection.unknown);
}

/// One block of text on a page and everything the pipeline learns about it.
///
/// Port of `TextBlock` from `modules/utils/textblock.py`. Like the original
/// it is mutable: pipeline stages fill in `lines`, `text`, `translation`, etc.
/// Use [copy] before keeping a snapshot (undo history, caches).
class TextBlock {
  TextBlock({
    required this.xyxy,
    this.bubbleXyxy,
    this.textClass = TextClass.unknown,
    List<TextLine>? lines,
    this.segmentationPoints,
    this.angle = 0,
    this.transformOrigin,
    List<String>? texts,
    String text = '',
    this.translation = '',
    List<Map<String, Object?>>? skippedSmallTexts,
    this.lineSpacing = 1,
    this.alignment = '',
    this.sourceLang = '',
    this.targetLang = '',
    this.script = '',
    this.minFontSize = 0,
    this.maxFontSize = 0,
    this.fontColor,
    this.direction = TextDirection.unknown,
    this.style,
  })  : lines = lines ?? [],
        texts = texts ?? [],
        skippedSmallTexts = skippedSmallTexts ?? [],
        text = (texts != null && texts.isNotEmpty) ? texts.join(' ') : text;

  /// Text bounding box.
  BBox xyxy;

  /// Bounding box of the speech bubble containing the text, if any.
  BBox? bubbleXyxy;
  TextClass textClass;

  /// Text lines (or vertical columns) inside the block, in reading order.
  List<TextLine> lines;

  /// Optional segmentation polygon of the text region.
  List<Point2>? segmentationPoints;

  /// Rotation in degrees, used when rendering.
  double angle;
  Point2? transformOrigin;

  /// Per-line OCR results, when the engine reports them separately.
  List<String> texts;

  /// Recognized source text.
  String text;
  String translation;

  /// Small text fragments the OCR intentionally skipped (furigana etc.).
  List<Map<String, Object?>> skippedSmallTexts;

  double lineSpacing;
  String alignment;
  String sourceLang;
  String targetLang;

  /// Script detected by the OSD model (`Latin`, `Hangul`, `Japanese`, ...).
  String script;
  int minFontSize;
  int maxFontSize;

  /// Detected foreground (text) colour as RGB, if known.
  List<int>? fontColor;
  TextDirection direction;

  /// How the translation is drawn when the user changed it by hand.
  BlockStyle? style;

  BBox get bbox => xyxy;
  Point2 get center => xyxy.center;

  /// `ver_rtl` for vertical text, `hor_ltr` otherwise (original
  /// `source_lang_direction`).
  String get sourceLangDirection => direction == TextDirection.vertical ? 'ver_rtl' : 'hor_ltr';

  /// Gives the block a new box drawn by hand. A move takes the lines, the
  /// bubble and the outline along, so the new place is read and cleaned. A
  /// resize drops what no longer fits: the lines are found again when the
  /// text is read, and the bubble stays only around a box still inside it.
  void moveBoxTo(BBox box) {
    final dx = box.x1 - xyxy.x1, dy = box.y1 - xyxy.y1;
    final moved = box.width == xyxy.width && box.height == xyxy.height;
    xyxy = box;
    if (moved) {
      Point2 shift(Point2 p) => Point2(p.x + dx, p.y + dy);
      lines = [
        for (final l in lines)
          l.isPolygon ? TextLine.polygon([for (final p in l.polygon!) shift(p)]) : TextLine.box(l.box!.translate(dx, dy)),
      ];
      bubbleXyxy = bubbleXyxy?.translate(dx, dy);
      segmentationPoints = segmentationPoints?.map(shift).toList();
    } else {
      lines = [];
      segmentationPoints = null;
      if (bubbleXyxy case final bubble? when !bubble.containsBox(box)) bubbleXyxy = null;
    }
  }

  TextBlock copy() => TextBlock(
        xyxy: xyxy,
        bubbleXyxy: bubbleXyxy,
        textClass: textClass,
        lines: List.of(lines),
        segmentationPoints: segmentationPoints == null ? null : List.of(segmentationPoints!),
        angle: angle,
        transformOrigin: transformOrigin,
        texts: List.of(texts),
        text: text,
        translation: translation,
        skippedSmallTexts: [for (final m in skippedSmallTexts) Map.of(m)],
        lineSpacing: lineSpacing,
        alignment: alignment,
        sourceLang: sourceLang,
        targetLang: targetLang,
        script: script,
        minFontSize: minFontSize,
        maxFontSize: maxFontSize,
        fontColor: fontColor == null ? null : List.of(fontColor!),
        direction: direction,
        style: style,
      )..text = text;

  /// JSON with the original attribute names, so artifacts can be compared
  /// with reference output produced by the Python code.
  Map<String, Object?> toJson() => {
        'xyxy': xyxy.toJson(),
        'bubble_xyxy': bubbleXyxy?.toJson(),
        'text_class': textClass.id,
        'lines': [for (final l in lines) l.toJson()],
        if (segmentationPoints != null)
          'segm_pts': [for (final p in segmentationPoints!) p.toJson()],
        'angle': angle,
        if (transformOrigin != null) 'tr_origin_point': transformOrigin!.toJson(),
        if (texts.isNotEmpty) 'texts': texts,
        'text': text,
        'translation': translation,
        if (skippedSmallTexts.isNotEmpty) 'skipped_small_texts': skippedSmallTexts,
        'line_spacing': lineSpacing,
        'alignment': alignment,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'script': script,
        'min_font_size': minFontSize,
        'max_font_size': maxFontSize,
        'font_color': fontColor,
        'direction': direction.id,
        if (style != null && !style!.isEmpty) 'style': style!.toJson(),
      };

  factory TextBlock.fromJson(Map<String, Object?> json) {
    final block = TextBlock(
      xyxy: BBox.fromJson(json['xyxy']),
      bubbleXyxy: json['bubble_xyxy'] == null ? null : BBox.fromJson(json['bubble_xyxy']),
      textClass: TextClass.parse(json['text_class'] as String?),
      lines: [for (final l in (json['lines'] as List? ?? const [])) TextLine.fromJson(l)],
      segmentationPoints: (json['segm_pts'] as List?)?.map(Point2.fromJson).toList(),
      angle: (json['angle'] as num?)?.toDouble() ?? 0,
      transformOrigin: json['tr_origin_point'] == null || (json['tr_origin_point'] as List).isEmpty
          ? null
          : Point2.fromJson(json['tr_origin_point']),
      texts: (json['texts'] as List?)?.cast<String>(),
      translation: json['translation'] as String? ?? '',
      skippedSmallTexts: (json['skipped_small_texts'] as List?)
          ?.map((e) => (e as Map).cast<String, Object?>())
          .toList(),
      lineSpacing: (json['line_spacing'] as num?)?.toDouble() ?? 1,
      alignment: json['alignment'] as String? ?? '',
      sourceLang: json['source_lang'] as String? ?? '',
      targetLang: json['target_lang'] as String? ?? '',
      script: json['script'] as String? ?? '',
      minFontSize: (json['min_font_size'] as num?)?.toInt() ?? 0,
      maxFontSize: (json['max_font_size'] as num?)?.toInt() ?? 0,
      fontColor: parseColor(json['font_color']),
      direction: TextDirection.parse(json['direction'] as String?),
      style: json['style'] is Map ? BlockStyle.fromJson((json['style'] as Map).cast<String, Object?>()) : null,
    );
    // `text` is stored explicitly; it may differ from texts.join(' ').
    block.text = json['text'] as String? ?? block.text;
    return block;
  }

  /// Accepts `[r, g, b]`, `[r, g, b, a]`, `#rrggbb` or empty values.
  static List<int>? parseColor(Object? value) {
    if (value == null) return null;
    if (value is List) {
      if (value.length < 3) return null;
      return [for (final c in value.take(3)) (c as num).round().clamp(0, 255)];
    }
    if (value is String) {
      final hex = value.startsWith('#') ? value.substring(1) : value;
      if (hex.length < 6) return null;
      final v = int.tryParse(hex.substring(0, 6), radix: 16);
      if (v == null) return null;
      return [(v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];
    }
    return null;
  }
}

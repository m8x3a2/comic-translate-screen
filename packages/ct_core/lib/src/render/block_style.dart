/// How one block's translation is drawn when the user changed it by hand:
/// font, size, colours, placement. Unset fields follow the render settings.
///
/// The original keeps these on its Qt text items (`TextItemProperties`); here
/// they live on the block, so drawing stays a function of the page data.
library;

import '../model/geometry.dart';
import 'layout.dart';
import 'text_runs.dart';

const Object _keep = Object();

class BlockStyle {
  const BlockStyle({
    this.fontFamily,
    this.fontSizePt,
    this.color,
    this.outline,
    this.outlineColor,
    this.outlineWidth,
    this.bold,
    this.italic,
    this.underline,
    this.lineSpacing,
    this.alignment,
    this.vertical,
    this.angle,
    this.textBox,
    this.upperCase,
    this.sourceSizePx,
    this.hyphenate,
    this.shapeFit,
    this.runs = const [],
    this.preset,
  });

  /// Font family or font file (see [RenderSettings.fontFamily]).
  final String? fontFamily;

  /// Fixed font size in points; unset = the largest size that fits.
  final int? fontSizePt;

  /// ARGB text colour; unset = the colour detected in the block, else the
  /// setting.
  final int? color;
  final bool? outline;
  final int? outlineColor;
  final double? outlineWidth;
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final double? lineSpacing;
  final TextAlignment? alignment;

  /// Vertical columns; unset = vertical for vertical source text when the
  /// target language is written vertically.
  final bool? vertical;

  /// Rotation in degrees (clockwise) around the text box centre.
  final double? angle;

  /// Where the text goes, in page pixels; unset = the block's box made 5%
  /// smaller, as in the automatic run.
  final BBox? textBox;

  /// Capitals (true) or ordinary letters (false) whatever the setting says.
  final bool? upperCase;

  /// Height of the source letters (page pixels) the translation takes, as
  /// the largest size: "size as in the original".
  final double? sourceSizePx;

  final bool? hyphenate;
  final bool? shapeFit;

  /// The look of single words or signs of the translation.
  final List<StyledRun> runs;

  /// Name of a look preset (see [RenderSettings.presets]): its look under
  /// this style's own fields.
  final String? preset;

  bool get isEmpty =>
      fontFamily == null &&
      fontSizePt == null &&
      color == null &&
      outline == null &&
      outlineColor == null &&
      outlineWidth == null &&
      bold == null &&
      italic == null &&
      underline == null &&
      lineSpacing == null &&
      alignment == null &&
      vertical == null &&
      angle == null &&
      textBox == null &&
      upperCase == null &&
      sourceSizePx == null &&
      hyphenate == null &&
      shapeFit == null &&
      runs.isEmpty &&
      preset == null;

  /// The look a preset holds: font, colours, outline, bold, italic,
  /// underline, spacing, alignment, letter case.
  BlockStyle get look => BlockStyle(
    fontFamily: fontFamily,
    color: color,
    outline: outline,
    outlineColor: outlineColor,
    outlineWidth: outlineWidth,
    bold: bold,
    italic: italic,
    underline: underline,
    lineSpacing: lineSpacing,
    alignment: alignment,
    upperCase: upperCase,
  );

  /// This style without the fields of [look].
  BlockStyle get withoutLook => copyWith(
    fontFamily: null,
    color: null,
    outline: null,
    outlineColor: null,
    outlineWidth: null,
    bold: null,
    italic: null,
    underline: null,
    lineSpacing: null,
    alignment: null,
    upperCase: null,
  );

  /// Only where the text goes (its own text box), without the look; null
  /// when that is not set either.
  BlockStyle? get placeOnly => textBox == null ? null : BlockStyle(textBox: textBox);

  /// [settings] with this style's font, outline and spacing; a fixed size
  /// becomes both size limits.
  RenderSettings applyTo(RenderSettings settings) => settings.copyWith(
    fontFamily: fontFamily,
    minFontSize: fontSizePt,
    maxFontSize: fontSizePt,
    outline: outline,
    outlineColor: outlineColor,
    outlineWidth: outlineWidth,
    bold: bold,
    italic: italic,
    underline: underline,
    lineSpacing: lineSpacing,
    alignment: alignment,
    hyphenate: hyphenate,
    shapeFit: shapeFit,
  );

  /// A copy with the given fields changed; pass null to unset a field.
  BlockStyle copyWith({
    Object? fontFamily = _keep,
    Object? fontSizePt = _keep,
    Object? color = _keep,
    Object? outline = _keep,
    Object? outlineColor = _keep,
    Object? outlineWidth = _keep,
    Object? bold = _keep,
    Object? italic = _keep,
    Object? underline = _keep,
    Object? lineSpacing = _keep,
    Object? alignment = _keep,
    Object? vertical = _keep,
    Object? angle = _keep,
    Object? textBox = _keep,
    Object? upperCase = _keep,
    Object? sourceSizePx = _keep,
    Object? hyphenate = _keep,
    Object? shapeFit = _keep,
    List<StyledRun>? runs,
    Object? preset = _keep,
  }) {
    T? pick<T>(Object? v, T? old) => identical(v, _keep) ? old : v as T?;
    return BlockStyle(
      fontFamily: pick(fontFamily, this.fontFamily),
      fontSizePt: pick(fontSizePt, this.fontSizePt),
      color: pick(color, this.color),
      outline: pick(outline, this.outline),
      outlineColor: pick(outlineColor, this.outlineColor),
      outlineWidth: pick(outlineWidth, this.outlineWidth),
      bold: pick(bold, this.bold),
      italic: pick(italic, this.italic),
      underline: pick(underline, this.underline),
      lineSpacing: pick(lineSpacing, this.lineSpacing),
      alignment: pick(alignment, this.alignment),
      vertical: pick(vertical, this.vertical),
      angle: pick(angle, this.angle),
      textBox: pick(textBox, this.textBox),
      upperCase: pick(upperCase, this.upperCase),
      sourceSizePx: pick(sourceSizePx, this.sourceSizePx),
      hyphenate: pick(hyphenate, this.hyphenate),
      shapeFit: pick(shapeFit, this.shapeFit),
      runs: runs ?? this.runs,
      preset: pick(preset, this.preset),
    );
  }

  /// Only the fields set in [other] replace this style's.
  BlockStyle merge(BlockStyle other) => BlockStyle(
    fontFamily: other.fontFamily ?? fontFamily,
    fontSizePt: other.fontSizePt ?? fontSizePt,
    color: other.color ?? color,
    outline: other.outline ?? outline,
    outlineColor: other.outlineColor ?? outlineColor,
    outlineWidth: other.outlineWidth ?? outlineWidth,
    bold: other.bold ?? bold,
    italic: other.italic ?? italic,
    underline: other.underline ?? underline,
    lineSpacing: other.lineSpacing ?? lineSpacing,
    alignment: other.alignment ?? alignment,
    vertical: other.vertical ?? vertical,
    angle: other.angle ?? angle,
    textBox: other.textBox ?? textBox,
    upperCase: other.upperCase ?? upperCase,
    sourceSizePx: other.sourceSizePx ?? sourceSizePx,
    hyphenate: other.hyphenate ?? hyphenate,
    shapeFit: other.shapeFit ?? shapeFit,
    runs: other.runs.isEmpty ? runs : other.runs,
    preset: other.preset ?? preset,
  );

  /// The style for a page enlarged by [sx]×[sy] (the text box moves; sizes
  /// in points stay, like the automatic layout on an enlarged page).
  BlockStyle scaled(double sx, double sy) => textBox == null && sourceSizePx == null
      ? this
      : copyWith(
          textBox: textBox == null
              ? null
              : BBox(
                  (textBox!.x1 * sx).round(),
                  (textBox!.y1 * sy).round(),
                  (textBox!.x2 * sx).round(),
                  (textBox!.y2 * sy).round(),
                ),
          sourceSizePx: sourceSizePx == null ? null : sourceSizePx! * sy,
        );

  Map<String, Object?> toJson() => {
    if (fontFamily != null) 'font_family': fontFamily,
    if (fontSizePt != null) 'font_size_pt': fontSizePt,
    if (color != null) 'color': _hex(color!),
    if (outline != null) 'outline': outline,
    if (outlineColor != null) 'outline_color': _hex(outlineColor!),
    if (outlineWidth != null) 'outline_width': outlineWidth,
    if (bold != null) 'bold': bold,
    if (italic != null) 'italic': italic,
    if (underline != null) 'underline': underline,
    if (lineSpacing != null) 'line_spacing': lineSpacing,
    if (alignment != null) 'alignment': alignment!.name,
    if (vertical != null) 'vertical': vertical,
    if (angle != null) 'angle': angle,
    if (textBox != null) 'text_box': textBox!.toJson(),
    if (upperCase != null) 'upper_case': upperCase,
    if (sourceSizePx != null) 'source_size_px': sourceSizePx,
    if (hyphenate != null) 'hyphenate': hyphenate,
    if (shapeFit != null) 'shape_fit': shapeFit,
    if (runs.isNotEmpty) 'runs': [for (final r in runs) r.toJson()],
    if (preset != null) 'preset': preset,
  };

  factory BlockStyle.fromJson(Map<String, Object?> j) {
    T? get<T>(String key) => j[key] is T ? j[key] as T : null;
    final color = get<String>('color'), outlineColor = get<String>('outline_color');
    return BlockStyle(
      fontFamily: get<String>('font_family'),
      fontSizePt: get<num>('font_size_pt')?.toInt(),
      color: color == null ? null : parseColor(color),
      outline: get<bool>('outline'),
      outlineColor: outlineColor == null ? null : parseColor(outlineColor),
      outlineWidth: get<num>('outline_width')?.toDouble(),
      bold: get<bool>('bold'),
      italic: get<bool>('italic'),
      underline: get<bool>('underline'),
      lineSpacing: get<num>('line_spacing')?.toDouble(),
      alignment: TextAlignment.values.asNameMap()[get<String>('alignment')],
      vertical: get<bool>('vertical'),
      angle: get<num>('angle')?.toDouble(),
      textBox: j['text_box'] is List ? BBox.fromJson(j['text_box']) : null,
      upperCase: get<bool>('upper_case'),
      sourceSizePx: get<num>('source_size_px')?.toDouble(),
      hyphenate: get<bool>('hyphenate'),
      shapeFit: get<bool>('shape_fit'),
      runs: [
        if (j['runs'] case final List list)
          for (final r in list)
            if (r is Map) StyledRun.fromJson(r.cast()),
      ],
      preset: get<String>('preset'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BlockStyle &&
      other.fontFamily == fontFamily &&
      other.fontSizePt == fontSizePt &&
      other.color == color &&
      other.outline == outline &&
      other.outlineColor == outlineColor &&
      other.outlineWidth == outlineWidth &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.lineSpacing == lineSpacing &&
      other.alignment == alignment &&
      other.vertical == vertical &&
      other.angle == angle &&
      other.textBox == textBox &&
      other.upperCase == upperCase &&
      other.sourceSizePx == sourceSizePx &&
      other.hyphenate == hyphenate &&
      other.shapeFit == shapeFit &&
      _sameRuns(other.runs, runs) &&
      other.preset == preset;

  @override
  int get hashCode => Object.hash(
    fontFamily,
    fontSizePt,
    color,
    outline,
    outlineColor,
    outlineWidth,
    bold,
    italic,
    underline,
    lineSpacing,
    alignment,
    vertical,
    angle,
    textBox,
    Object.hash(upperCase, sourceSizePx, hyphenate, shapeFit, Object.hashAll(runs), preset),
  );
}

bool _sameRuns(List<StyledRun> a, List<StyledRun> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// The look of single words or signs of a translation ("runs"), over the
/// look of the whole block. Not in the original, where a block has one look.
///
/// For laying out, a translation carries its runs as invisible marks (from
/// the Unicode private use area) around them, so that wrapping, hyphenation
/// and letter case need not know about runs; the text engine draws the
/// marked runs in their look and the marks are taken out again for anything
/// shown as text.
library;

import 'layout.dart' show parseColor;

/// What a run changes; unset fields keep the block's look.
class RunStyle {
  const RunStyle({
    this.fontFamily,
    this.scale,
    this.color,
    this.outline,
    this.outlineColor,
    this.outlineWidth,
    this.bold,
    this.italic,
    this.underline,
    this.preset,
  });

  final String? fontFamily;

  /// Letter size to the block's (1.3 = 30 % larger).
  final double? scale;

  /// ARGB colours.
  final int? color;
  final bool? outline;
  final int? outlineColor;
  final double? outlineWidth;
  final bool? bold;
  final bool? italic;
  final bool? underline;

  /// Name of a look preset (see [RenderSettings.presets]); its fields under
  /// this run's own.
  final String? preset;

  bool get isEmpty =>
      fontFamily == null &&
      scale == null &&
      color == null &&
      outline == null &&
      outlineColor == null &&
      outlineWidth == null &&
      bold == null &&
      italic == null &&
      underline == null &&
      preset == null;

  /// A copy with the given fields changed; pass null to unset a field.
  RunStyle copyWith({
    Object? fontFamily = _keep,
    Object? scale = _keep,
    Object? color = _keep,
    Object? outline = _keep,
    Object? outlineColor = _keep,
    Object? outlineWidth = _keep,
    Object? bold = _keep,
    Object? italic = _keep,
    Object? underline = _keep,
    Object? preset = _keep,
  }) {
    T? pick<T>(Object? v, T? old) => identical(v, _keep) ? old : v as T?;
    return RunStyle(
      fontFamily: pick(fontFamily, this.fontFamily),
      scale: pick(scale, this.scale),
      color: pick(color, this.color),
      outline: pick(outline, this.outline),
      outlineColor: pick(outlineColor, this.outlineColor),
      outlineWidth: pick(outlineWidth, this.outlineWidth),
      bold: pick(bold, this.bold),
      italic: pick(italic, this.italic),
      underline: pick(underline, this.underline),
      preset: pick(preset, this.preset),
    );
  }

  /// Only the fields set in [other] replace this style's.
  RunStyle merge(RunStyle other) => RunStyle(
    fontFamily: other.fontFamily ?? fontFamily,
    scale: other.scale ?? scale,
    color: other.color ?? color,
    outline: other.outline ?? outline,
    outlineColor: other.outlineColor ?? outlineColor,
    outlineWidth: other.outlineWidth ?? outlineWidth,
    bold: other.bold ?? bold,
    italic: other.italic ?? italic,
    underline: other.underline ?? underline,
    preset: other.preset ?? preset,
  );

  Map<String, Object?> toJson() => {
    if (fontFamily != null) 'font_family': fontFamily,
    if (scale != null) 'scale': scale,
    if (color != null) 'color': _hex(color!),
    if (outline != null) 'outline': outline,
    if (outlineColor != null) 'outline_color': _hex(outlineColor!),
    if (outlineWidth != null) 'outline_width': outlineWidth,
    if (bold != null) 'bold': bold,
    if (italic != null) 'italic': italic,
    if (underline != null) 'underline': underline,
    if (preset != null) 'preset': preset,
  };

  factory RunStyle.fromJson(Map<String, Object?> j) {
    T? get<T>(String key) => j[key] is T ? j[key] as T : null;
    final color = get<String>('color'), outlineColor = get<String>('outline_color');
    return RunStyle(
      fontFamily: get<String>('font_family'),
      scale: get<num>('scale')?.toDouble(),
      color: color == null ? null : parseColor(color),
      outline: get<bool>('outline'),
      outlineColor: outlineColor == null ? null : parseColor(outlineColor),
      outlineWidth: get<num>('outline_width')?.toDouble(),
      bold: get<bool>('bold'),
      italic: get<bool>('italic'),
      underline: get<bool>('underline'),
      preset: get<String>('preset'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RunStyle &&
      other.fontFamily == fontFamily &&
      other.scale == scale &&
      other.color == color &&
      other.outline == outline &&
      other.outlineColor == outlineColor &&
      other.outlineWidth == outlineWidth &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.preset == preset;

  @override
  int get hashCode =>
      Object.hash(fontFamily, scale, color, outline, outlineColor, outlineWidth, bold, italic, underline, preset);
}

const _keep = Object();

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Characters [start] to [end] (exclusive) of a translation in [style].
class StyledRun {
  const StyledRun(this.start, this.end, this.style);

  final int start;
  final int end;
  final RunStyle style;

  Map<String, Object?> toJson() => {'start': start, 'end': end, ...style.toJson()};

  factory StyledRun.fromJson(Map<String, Object?> j) =>
      StyledRun((j['start'] as num?)?.toInt() ?? 0, (j['end'] as num?)?.toInt() ?? 0, RunStyle.fromJson(j));

  @override
  bool operator ==(Object other) =>
      other is StyledRun && other.start == start && other.end == end && other.style == style;

  @override
  int get hashCode => Object.hash(start, end, style);

  @override
  String toString() => 'StyledRun($start, $end, ${style.toJson()})';
}

/// [runs] (sorted, not overlapping) with [change] applied to characters
/// [start]..[end]: runs are split at the edges, characters without a run
/// get one, runs left without a look are dropped and equal neighbours
/// joined.
List<StyledRun> restyleRange(List<StyledRun> runs, int start, int end, RunStyle Function(RunStyle style) change) {
  if (end <= start) return runs;
  // Every character's look, for the stretch the runs and the range cover.
  final points = <int>{
    start,
    end,
    for (final r in runs) ...[r.start, r.end],
  }.toList()..sort();
  RunStyle at(int i) {
    for (final r in runs) {
      if (r.start <= i && i < r.end) return r.style;
    }
    return const RunStyle();
  }

  final out = <StyledRun>[];
  for (var k = 0; k + 1 < points.length; k++) {
    final a = points[k], b = points[k + 1];
    if (b <= a) continue;
    var style = at(a);
    if (a >= start && b <= end) style = change(style);
    if (style.isEmpty) continue;
    if (out.isNotEmpty && out.last.end == a && out.last.style == style) {
      out[out.length - 1] = StyledRun(out.last.start, b, style);
    } else {
      out.add(StyledRun(a, b, style));
    }
  }
  return out;
}

/// [runs] after the text changed from [old] to [now] (one edit: the text
/// between a common start and a common end was replaced): runs after the
/// edit move along, runs over it grow or shrink with it, runs left empty go.
List<StyledRun> shiftRuns(List<StyledRun> runs, String old, String now) {
  if (runs.isEmpty || old == now) return runs;
  var prefix = 0;
  final shortest = old.length < now.length ? old.length : now.length;
  while (prefix < shortest && old.codeUnitAt(prefix) == now.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < shortest - prefix &&
      old.codeUnitAt(old.length - 1 - suffix) == now.codeUnitAt(now.length - 1 - suffix)) {
    suffix++;
  }
  final oldEnd = old.length - suffix, delta = now.length - old.length;
  // Text typed just before a run or just after it is not part of it; a
  // run edge inside the replaced text goes to the edge of what was typed.
  int moveStart(int i) => i < prefix ? i : (i >= oldEnd ? i + delta : prefix);
  int moveEnd(int i) => i <= prefix ? i : (i >= oldEnd ? i + delta : oldEnd + delta);

  return [
    for (final r in runs)
      if (StyledRun(moveStart(r.start), moveEnd(r.end), r.style) case final s when s.end > s.start) s,
  ];
}

/// First mark of a run (run k is marked with `runMarkStart + k`).
const runMarkStart = 0xE000;

/// Mark after the last character of a run.
const runMarkEnd = 0xE0FF;

/// The most runs a block may have (marks left for them).
const maxRuns = runMarkEnd - runMarkStart;

bool isRunMark(int codeUnit) => codeUnit >= runMarkStart && codeUnit <= runMarkEnd;

/// [text] with [runs] marked; runs beyond the text or [maxRuns] are left out.
String markRuns(String text, List<StyledRun> runs) {
  if (runs.isEmpty) return text;
  final starts = <int, int>{}, ends = <int>{};
  for (final (k, r) in runs.indexed) {
    if (k >= maxRuns || r.start < 0 || r.end > text.length || r.end <= r.start) continue;
    starts[r.start] = k;
    ends.add(r.end);
  }
  final out = StringBuffer();
  for (var i = 0; i <= text.length; i++) {
    if (ends.contains(i)) out.writeCharCode(runMarkEnd);
    if (starts[i] case final k?) out.writeCharCode(runMarkStart + k);
    if (i < text.length) out.writeCharCode(text.codeUnitAt(i));
  }
  return out.toString();
}

/// [text] without run marks.
String unmarkRuns(String text) {
  if (!text.codeUnits.any(isRunMark)) return text;
  return String.fromCharCodes(text.codeUnits.where((c) => !isRunMark(c)));
}

/// The pieces of marked [text]: their text and the run they belong to
/// (null: none). A run may go on over line breaks.
List<(String text, int? run)> runPieces(String text) {
  final out = <(String, int?)>[];
  final piece = StringBuffer();
  int? run;
  void flush() {
    if (piece.isNotEmpty) out.add((piece.toString(), run));
    piece.clear();
  }

  for (final c in text.codeUnits) {
    if (c == runMarkEnd) {
      flush();
      run = null;
    } else if (isRunMark(c)) {
      flush();
      run = c - runMarkStart;
    } else {
      piece.writeCharCode(c);
    }
  }
  flush();
  return out;
}

/// The runs written as `*word*` (or `**word**`) in [text]: the text
/// without the stars and those words as bold runs (as a chat marks the
/// words the source stresses). Lone stars stay.
(String, List<StyledRun>) boldFromStars(String text) {
  final runs = <StyledRun>[];
  final out = StringBuffer();
  var last = 0;
  for (final m in _stars.allMatches(text)) {
    out.write(text.substring(last, m.start));
    final word = m.group(2)!;
    final start = out.length;
    out.write(word);
    runs.add(StyledRun(start, out.length, const RunStyle(bold: true)));
    last = m.end;
  }
  out.write(text.substring(last));
  return (out.toString(), runs);
}

final _stars = RegExp(r'(\*\*?)(?!\s)([^*\n]+?)(?<!\s)\1');

/// Search through the settings (the owner's idea): a setting is found by the
/// words of its name, its hints ("i"), its group and its section.
///
/// Nothing is listed by hand: the sections are built (out of sight) and
/// what can be seen in them is gathered from the widgets — fields, switches,
/// buttons, rows of lists, texts — so a setting added later is found too.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/info_hint.dart';
import 'settings_screen.dart';

/// Ctrl+F while the settings panel is open: its search, not the page's.
final settingsSearchRequestProvider = NotifierProvider<SettingsSearchRequest, int>(SettingsSearchRequest.new);

class SettingsSearchRequest extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

/// One thing that can be found in a built section: a field, a switch, a
/// button, a row of a list, or a note (a text standing alone).
class SettingUnit {
  SettingUnit({required this.element, required this.label, this.group, this.note = false});

  /// Where it is in the built section (for scrolling to it).
  final Element element;

  /// Its name: the label of a field, the title of a switch, the text of a
  /// button.
  final String label;

  /// The title of the group it is in.
  final String? group;

  /// A text standing alone (not a field or a button): found after the rest.
  final bool note;

  /// What else is written on it (help, the chosen value, the choices).
  final texts = <String>[];

  /// Its hints ("i").
  final infos = <String>[];
}

/// The settings that can be found under [root] (a built section), in order.
List<SettingUnit> collectSettings(Element root) {
  final units = <SettingUnit>[];

  void visit(Element e, String? group, String? groupTitle) {
    final w = e.widget;
    if (w is SettingsGroup) {
      final title = w.title ?? group;
      e.visitChildElements((c) => visit(c, title, w.title));
      return;
    }
    if (w is InfoHint) {
      // The hint after a field belongs to it.
      if (units.isNotEmpty) units.last.infos.add(w.text);
      return;
    }
    // An icon is drawn as a letter of its font: not a word.
    if (w is Icon) return;
    if (_isUnit(w)) {
      final unit = _gather(e, group);
      if (unit != null) units.add(unit);
      return;
    }
    if (w is RichText) {
      final text = w.text.toPlainText().trim();
      if (text.isNotEmpty && text != groupTitle) {
        units.add(SettingUnit(element: e, label: text, group: group, note: true));
      }
      return;
    }
    e.visitChildElements((c) => visit(c, group, groupTitle));
  }

  root.visitChildElements((c) => visit(c, null, null));
  return units;
}

bool _isUnit(Widget w) =>
    w is ListTile ||
    w is InputDecorator ||
    w is ButtonStyleButton ||
    w is IconButton ||
    w is SegmentedButton ||
    w is RawChip;

/// What a field, switch, button or row shows.
SettingUnit? _gather(Element root, String? group) {
  String? label = switch (root.widget) {
    InputDecorator(:final decoration) => decoration.labelText,
    _ => null,
  };
  final texts = <String>[];
  final infos = <String>[];
  final tips = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is InfoHint) {
      infos.add(w.text);
      return;
    }
    if (w is Icon) return;
    if (w is InputDecorator) {
      for (final t in [w.decoration.labelText, w.decoration.helperText, w.decoration.hintText]) {
        if (t != null && t.trim().isNotEmpty) texts.add(t.trim());
      }
    }
    if (w is Tooltip && (w.message?.trim().isNotEmpty ?? false)) tips.add(w.message!.trim());
    if (w is RichText) {
      final text = w.text.toPlainText().trim();
      if (text.isNotEmpty) texts.add(text);
      return;
    }
    e.visitChildElements(visit);
  }

  visit(root);
  label ??= texts.firstOrNull ?? tips.firstOrNull;
  if (label == null || label.isEmpty) return null;
  final unit = SettingUnit(element: root, label: label, group: group);
  final seen = {label};
  for (final t in [...texts, ...tips]) {
    if (seen.add(t)) unit.texts.add(t);
  }
  unit.infos.addAll(infos);
  return unit;
}

// Matching.

/// Lower case, "ё" as "е".
String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

final _wordSplit = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

List<String> _words(String s) => _norm(s).split(_wordSplit).where((w) => w.isNotEmpty).toList();

/// The beginning of a query word that has to match: the whole of a short
/// word, a longer one without its ending ("переводы" finds "перевод").
String _stem(String w) => w.length >= 5 ? w.substring(0, math.max(4, w.length - 2)) : w;

/// The query's words, as they are matched.
List<String> queryStems(String query) => [for (final w in _words(query)) _stem(w)];

bool _matches(String text, String stem) => _words(text).any((w) => w.startsWith(stem));

/// A setting found, with where it is.
class SettingHit {
  const SettingHit({
    required this.section,
    required this.index,
    required this.label,
    this.group,
    this.snippet,
    this.wholeSection = false,
  });

  final SettingsSection section;

  /// Its place among the settings of the section (-1: the section itself).
  final int index;
  final String label;
  final String? group;

  /// The hint or text where the words were found, when not in the name.
  final String? snippet;

  /// The section itself is what was found (by its name).
  final bool wholeSection;
}

/// The settings of [index] (per section, titled [titles]) that have every
/// word of [query], the best first.
List<SettingHit> searchSettings(
  Map<SettingsSection, List<SettingUnit>> index,
  Map<SettingsSection, String> titles,
  String query,
) {
  final stems = queryStems(query);
  if (stems.isEmpty) return const [];
  final scored = <(int, int, SettingHit)>[];
  var order = 0;
  for (final section in SettingsSection.values) {
    final title = titles[section] ?? '';
    if (stems.every((s) => _matches(title, s))) {
      scored.add((100, order++, SettingHit(section: section, index: -1, label: title, wholeSection: true)));
    }
    for (final (i, u) in (index[section] ?? const <SettingUnit>[]).indexed) {
      var score = 0;
      var inLabel = 0;
      String? snippet;
      for (final s in stems) {
        if (_matches(u.label, s)) {
          score += u.note ? 1 : 4;
          inLabel++;
        } else if (u.group != null && _matches(u.group!, s)) {
          score += 2;
        } else if (_matches(title, s)) {
          score += 1;
        } else if ([...u.infos, ...u.texts].where((t) => _matches(t, s)).firstOrNull case final t?) {
          score += 1;
          snippet ??= t;
        } else {
          score = -1;
          break;
        }
      }
      if (score < 0) continue;
      if (inLabel == stems.length && !u.note) score += 3;
      scored.add((
        score,
        order++,
        SettingHit(section: section, index: i, label: u.label, group: u.group, snippet: snippet),
      ));
    }
  }
  scored.sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
  return [for (final s in scored) s.$3];
}

/// [text] with the beginnings of words that match [stems] in [bold].
List<TextSpan> highlightSpans(String text, List<String> stems, TextStyle bold) {
  final spans = <TextSpan>[];
  var plain = StringBuffer();
  final word = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  var at = 0;
  for (final m in word.allMatches(text)) {
    plain.write(text.substring(at, m.start));
    at = m.end;
    final w = m[0]!;
    final n = _norm(w);
    final stem = stems
        .where((s) => n.startsWith(s))
        .fold<String?>(null, (a, s) => a == null || s.length > a.length ? s : a);
    if (stem == null) {
      plain.write(w);
      continue;
    }
    if (plain.isNotEmpty) spans.add(TextSpan(text: plain.toString()));
    plain = StringBuffer();
    spans.add(TextSpan(text: w.substring(0, stem.length), style: bold));
    plain.write(w.substring(stem.length));
  }
  plain.write(text.substring(at));
  if (plain.isNotEmpty) spans.add(TextSpan(text: plain.toString()));
  return spans;
}

/// A piece of [text] around its first word matching [stems], at most about
/// [length] characters.
String snippetOf(String text, List<String> stems, {int length = 140}) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= length) return flat;
  final word = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  var start = 0;
  for (final m in word.allMatches(flat)) {
    if (stems.any((s) => _norm(m[0]!).startsWith(s))) {
      start = m.start;
      break;
    }
  }
  var from = math.max(0, start - length ~/ 3);
  if (from > 0) {
    final space = flat.indexOf(' ', from);
    if (space >= 0 && space < start) from = space + 1;
  }
  final to = math.min(flat.length, from + length);
  return '${from > 0 ? '…' : ''}${flat.substring(from, to).trim()}${to < flat.length ? '…' : ''}';
}

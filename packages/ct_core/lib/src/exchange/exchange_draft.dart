/// Where an exchange with a chat stands, kept in its folder (the owner's
/// idea, from a check by another model): the answers taken so far and the
/// text in the answer fields, and in parts the pages of each part and the
/// part shown. A long chapter answered part by part survives closing the
/// window or the program before "Apply"; "Open an earlier exchange" goes on
/// from there. New in this project.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/text_block.dart';
import 'exchange_answer.dart';
import 'exchange_settings.dart';

class ExchangeDraft {
  const ExchangeDraft({
    required this.mode,
    this.parts = const [],
    this.part = 0,
    this.accepted = const {},
    this.unchanged = const [],
    this.answer = '',
    this.answer2 = '',
  });

  /// In the folder of the whole exchange (the one with the date).
  static const fileName = 'draft.json';

  final ExchangeMode mode;

  /// The page ids of each part (its folder `part_NN`, from 1); empty: all
  /// pages at once.
  final List<List<String>> parts;

  /// The part shown (from 0).
  final int part;

  /// Answers taken (earlier parts and rounds).
  final Map<ExchangeLabel, ExchangeReply> accepted;

  /// Pieces left as they were in the text files (no answer, not missing).
  final List<ExchangeLabel> unchanged;

  /// What the answer fields hold (with two fields, [answer2] the
  /// translations).
  final String answer, answer2;

  bool get isEmpty =>
      parts.isEmpty && accepted.isEmpty && unchanged.isEmpty && answer.trim().isEmpty && answer2.trim().isEmpty;

  Map<String, Object?> toJson() => {
    'version': 1,
    'mode': mode.name,
    if (parts.isNotEmpty) 'parts': parts,
    if (parts.isNotEmpty) 'part': part,
    'accepted': {
      for (final MapEntry(key: label, value: r) in accepted.entries)
        label.code: {
          'original': ?r.original,
          'translation': ?r.translation,
          if (r.missingArrow) 'missing_arrow': true,
          if (r.hasSpeaker) 'speaker': r.speaker?.tag ?? '-',
        },
    },
    if (unchanged.isNotEmpty) 'unchanged': [for (final l in unchanged) l.code],
    if (answer.isNotEmpty) 'answer': answer,
    if (answer2.isNotEmpty) 'answer2': answer2,
  };

  static ExchangeDraft fromJson(Map<String, Object?> json) {
    final parts = [
      for (final part in json['parts'] as List? ?? const [])
        if (part is List) [for (final id in part) '$id'],
    ];
    return ExchangeDraft(
      mode: ExchangeMode.parse(json['mode'] as String?),
      parts: parts,
      part: ((json['part'] as num?)?.toInt() ?? 0).clamp(0, parts.isEmpty ? 0 : parts.length - 1),
      accepted: {
        for (final MapEntry(:key, :value) in (json['accepted'] as Map? ?? const {}).entries)
          if ((ExchangeLabel.tryParse('$key'), value) case (final label?, final Map r))
            label: ExchangeReply(
              original: r['original'] as String?,
              translation: r['translation'] as String?,
              missingArrow: r['missing_arrow'] == true,
              speaker: Speaker.parse(r['speaker'] as String?),
              hasSpeaker: r.containsKey('speaker'),
            ),
      },
      unchanged: [for (final code in json['unchanged'] as List? ?? const []) ?ExchangeLabel.tryParse('$code')],
      answer: json['answer'] as String? ?? '',
      answer2: json['answer2'] as String? ?? '',
    );
  }

  /// Written next to the file and renamed over it: never half a draft.
  Future<void> write(Directory dir) async {
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileName));
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(toJson()), flush: true);
    try {
      await tmp.rename(file.path);
    } on FileSystemException {
      if (file.existsSync()) await file.delete();
      await tmp.rename(file.path);
    }
  }

  /// The draft of [dir]; null when there is none or it cannot be read.
  static Future<ExchangeDraft?> read(Directory dir) async {
    try {
      final file = File(p.join(dir.path, fileName));
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return json is Map ? fromJson(json.cast<String, Object?>()) : null;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  /// The draft of [dir] holds answers not applied yet (the folder is not
  /// removed with the old ones).
  static bool holdsAnswers(Directory dir) {
    try {
      final file = File(p.join(dir.path, fileName));
      if (!file.existsSync()) return false;
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map) return false;
      final d = fromJson(json.cast<String, Object?>());
      return d.accepted.isNotEmpty || d.answer.trim().isNotEmpty || d.answer2.trim().isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// After "Apply": the answers are in the pages.
  static Future<void> delete(Directory dir) async {
    final file = File(p.join(dir.path, fileName));
    if (await file.exists()) await file.delete();
  }
}

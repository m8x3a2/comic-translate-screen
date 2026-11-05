/// Checks of the chat's answer before it is applied: lines the chat left
/// untranslated. New in this project.
library;

import '../model/language.dart';
import 'exchange_answer.dart';

/// Writing systems told apart here.
enum _Script { latin, cyrillic, greek, han, kana, hangul, arabic, hebrew, thai, devanagari }

_Script? _scriptOf(int r) {
  if ((r >= 0x41 && r <= 0x5A) ||
      (r >= 0x61 && r <= 0x7A) ||
      (r >= 0xC0 && r <= 0x24F) ||
      (r >= 0x1E00 && r <= 0x1EFF)) {
    return r == 0xD7 || r == 0xF7 ? null : _Script.latin;
  }
  if (r >= 0x400 && r <= 0x52F) return _Script.cyrillic;
  if (r >= 0x370 && r <= 0x3FF) return _Script.greek;
  if ((r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF)) return _Script.han;
  if (r >= 0x3040 && r <= 0x30FF) return _Script.kana;
  if ((r >= 0xAC00 && r <= 0xD7AF) || (r >= 0x1100 && r <= 0x11FF)) return _Script.hangul;
  if (r >= 0x600 && r <= 0x6FF) return _Script.arabic;
  if (r >= 0x590 && r <= 0x5FF) return _Script.hebrew;
  if (r >= 0xE00 && r <= 0xE7F) return _Script.thai;
  if (r >= 0x900 && r <= 0x97F) return _Script.devanagari;
  return null;
}

/// The script of most letters of [text]; null with fewer than three
/// letters (sounds, "OK", "!!!").
_Script? _mainScript(String text) {
  final counts = <_Script, int>{};
  for (final r in text.runes) {
    if (_scriptOf(r) case final s?) counts[s] = (counts[s] ?? 0) + 1;
  }
  if (counts.values.fold(0, (a, b) => a + b) < 3) return null;
  final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  // Japanese writes with Chinese characters and kana alike.
  return top == _Script.kana ? _Script.han : top;
}

const _cyrillic = {'ru', 'uk', 'be', 'bg', 'sr', 'mk', 'kk', 'ky', 'mn', 'tg', 'tt', 'ba'};

/// The script [code] is written in.
_Script _scriptOfLanguage(String code) {
  final c = code.toLowerCase().split('-').first;
  if (_cyrillic.contains(c)) return _Script.cyrillic;
  return switch (c) {
    'el' => _Script.greek,
    'zh' || 'ja' => _Script.han,
    'ko' => _Script.hangul,
    'ar' || 'fa' || 'ur' => _Script.arabic,
    'he' => _Script.hebrew,
    'th' => _Script.thai,
    'hi' || 'mr' || 'ne' => _Script.devanagari,
    _ => _Script.latin,
  };
}

String _letters(String s) => s.toLowerCase().runes.where((r) => _scriptOf(r) != null).map(String.fromCharCode).join();

/// Labels of [replies] the chat seems to have left untranslated: the
/// translation is the original again, or it is written in the letters of
/// the original where [targetLanguage] uses other ones. The original is the
/// one in the answer, else the one sent ([items]).
List<ExchangeLabel> untranslatedReplies(
  List<ExchangeItem> items,
  Map<ExchangeLabel, ExchangeReply> replies, {
  required String targetLanguage,
}) {
  final target = _scriptOfLanguage(Languages.byName(targetLanguage)?.code ?? 'en');
  final sent = {for (final it in items) it.label: it.text};
  return [
    for (final MapEntry(key: label, value: reply) in replies.entries)
      if (reply.translation case final translation? when translation.trim().isNotEmpty)
        if (reply.original ?? sent[label] case final original? when original.trim().isNotEmpty)
          if (_untranslated(original, translation, target)) label,
  ];
}

bool _untranslated(String original, String translation, _Script target) {
  final a = _letters(original), b = _letters(translation);
  if (a.length >= 2 && a == b) return true;
  final from = _mainScript(original), to = _mainScript(translation);
  return from != null && from != target && to == from;
}

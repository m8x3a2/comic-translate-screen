/// Languages known to the app: source languages for OCR and target languages
/// for translation. Port of `modules/utils/language_utils.py`,
/// `app/ui/main_window/constants.py` and the bundled fallback of
/// `app/catalog.py` (the original's online catalog refresh is not used).
class Language {
  const Language({
    required this.name,
    required this.code,
    required this.nativeLabel,
    this.rtl = false,
    this.noSpace = false,
    this.vertical = false,
    this.source = false,
    this.target = false,
  });

  /// Canonical English name, stored in settings and sent to translators
  /// (e.g. `Simplified Chinese`).
  final String name;

  /// Language code (`en`, `zh-CN`, `pt-br`, ...), as in the original.
  final String code;

  /// Name in the language itself, for menus.
  final String nativeLabel;

  /// Written right-to-left (Arabic, Hebrew, Persian).
  final bool rtl;

  /// Words are not separated by spaces (Chinese, Japanese, Thai).
  final bool noSpace;

  /// Can be typeset vertically.
  final bool vertical;

  /// Offered as a source language.
  final bool source;

  /// Offered as a target language.
  final bool target;

  @override
  String toString() => name;
}

abstract final class Languages {
  /// Pseudo source language: detect the script automatically.
  static const auto = 'Auto';

  static const all = <Language>[
    Language(name: 'English', code: 'en', nativeLabel: 'English', source: true, target: true),
    Language(name: 'Korean', code: 'ko', nativeLabel: '한국어', source: true, target: true),
    Language(name: 'Japanese', code: 'ja', nativeLabel: '日本語', noSpace: true, vertical: true, source: true, target: true),
    Language(name: 'French', code: 'fr', nativeLabel: 'Français', source: true, target: true),
    Language(name: 'Chinese', code: 'zh', nativeLabel: '中文', noSpace: true, source: true),
    Language(name: 'Simplified Chinese', code: 'zh-CN', nativeLabel: '简体中文', noSpace: true, vertical: true, target: true),
    Language(name: 'Traditional Chinese', code: 'zh-TW', nativeLabel: '繁體中文', noSpace: true, vertical: true, target: true),
    Language(name: 'Russian', code: 'ru', nativeLabel: 'Русский', source: true, target: true),
    Language(name: 'German', code: 'de', nativeLabel: 'Deutsch', source: true, target: true),
    Language(name: 'Dutch', code: 'nl', nativeLabel: 'Nederlands', source: true, target: true),
    Language(name: 'Spanish', code: 'es', nativeLabel: 'Español', source: true, target: true),
    Language(name: 'Italian', code: 'it', nativeLabel: 'Italiano', source: true, target: true),
    Language(name: 'Turkish', code: 'tr', nativeLabel: 'Türkçe', target: true),
    Language(name: 'Polish', code: 'pl', nativeLabel: 'Polski', target: true),
    Language(name: 'Portuguese', code: 'pt', nativeLabel: 'Português', target: true),
    Language(name: 'Brazilian Portuguese', code: 'pt-br', nativeLabel: 'Português (Brasil)', target: true),
    Language(name: 'Thai', code: 'th', nativeLabel: 'ไทย', noSpace: true, target: true),
    Language(name: 'Vietnamese', code: 'vi', nativeLabel: 'Tiếng Việt', target: true),
    Language(name: 'Hungarian', code: 'hu', nativeLabel: 'Magyar', target: true),
    Language(name: 'Indonesian', code: 'id', nativeLabel: 'Bahasa Indonesia', target: true),
    Language(name: 'Finnish', code: 'fi', nativeLabel: 'Suomi', target: true),
    Language(name: 'Arabic', code: 'ar', nativeLabel: 'العربية', rtl: true, target: true),
    Language(name: 'Hebrew', code: 'he', nativeLabel: 'עברית', rtl: true, target: true),
    Language(name: 'Czech', code: 'cs', nativeLabel: 'Čeština', target: true),
    Language(name: 'Croatian', code: 'hr', nativeLabel: 'Hrvatski', target: true),
    Language(name: 'Persian', code: 'fa', nativeLabel: 'فارسی', rtl: true, target: true),
    Language(name: 'Romanian', code: 'ro', nativeLabel: 'Română', target: true),
    Language(name: 'Mongolian', code: 'mn', nativeLabel: 'Монгол', target: true),
  ];

  static Iterable<Language> get sources => all.where((l) => l.source);
  static Iterable<Language> get targets => all.where((l) => l.target);

  static Language? byName(String name) {
    for (final l in all) {
      if (l.name == name) return l;
    }
    return null;
  }

  static Language? byCode(String code) {
    final c = code.toLowerCase();
    for (final l in all) {
      if (l.code.toLowerCase() == c) return l;
    }
    return null;
  }

  /// Code for a canonical name (`get_language_code`), null if unknown.
  static String? codeOf(String name) => byName(name)?.code;

  /// `is_no_space_lang`: true for codes containing zh, ja or th.
  static bool isNoSpaceCode(String? code) {
    if (code == null || code.isEmpty) return false;
    final c = code.toLowerCase();
    if (c.contains('zh') || c.contains('ja') || c.contains('th')) return true;
    return byCode(c)?.noSpace ?? false;
  }

  /// `is_vertical_language_code`.
  static bool isVerticalCode(String? code) {
    if (code == null || code.isEmpty) return false;
    final c = code.toLowerCase();
    if (const {'zh-cn', 'zh-tw', 'ja'}.contains(c)) return true;
    return byCode(c)?.vertical ?? false;
  }

  static bool isRtlName(String name) => byName(name)?.rtl ?? false;
}

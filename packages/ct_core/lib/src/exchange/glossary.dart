/// The words of a project and how to translate them, written by the user as
/// plain text: `Kai --> Кай` lines, and any other line is a note on the
/// translation (`#` lines are the user's own remarks). It goes to the chat
/// and to translators over the network. New in this project.
library;

/// `Kai --> Кай`.
class GlossaryEntry {
  const GlossaryEntry(this.term, this.translation);

  final String term;
  final String translation;

  /// A line of the glossary text.
  String get line => '$term --> $translation';

  @override
  bool operator ==(Object other) => other is GlossaryEntry && other.term == term && other.translation == translation;

  @override
  int get hashCode => Object.hash(term, translation);
}

/// `-->`, `->`, `→`, `=>` and the like between a word and its translation.
final _arrow = RegExp(r'\s*(?:-{1,3}>|=>|→|⟶|—>|–>)\s*');

class Glossary {
  Glossary._(this.entries, this.notes);

  factory Glossary.parse(String text) {
    final entries = <GlossaryEntry>[], notes = <String>[];
    for (final raw in text.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final arrow = _arrow.firstMatch(line);
      final term = arrow == null ? '' : line.substring(0, arrow.start).trim();
      final translation = arrow == null ? '' : line.substring(arrow.end).trim();
      if (term.isNotEmpty && translation.isNotEmpty) {
        entries.add(GlossaryEntry(term, translation));
      } else {
        notes.add(line);
      }
    }
    return Glossary._(entries, notes);
  }

  final List<GlossaryEntry> entries;

  /// Lines that are no `word --> translation`: how to translate.
  final List<String> notes;

  bool get isEmpty => entries.isEmpty && notes.isEmpty;

  /// The glossary has [term] already (any case).
  bool has(String term) => entries.any((e) => e.term.toLowerCase() == term.trim().toLowerCase());

  /// For instructions to a chat or a translator; empty for an empty
  /// glossary. With [texts], only the words found in them go (all notes do).
  String forPrompt({Iterable<String>? texts}) {
    final all = texts?.join('\n').toLowerCase();
    final used = [
      for (final e in entries)
        if (all == null || all.contains(e.term.toLowerCase())) e,
    ];
    if (used.isEmpty && notes.isEmpty) return '';
    return [
      if (used.isNotEmpty) ...[
        'Glossary: translate these names and words exactly so:',
        for (final e in used) '${e.term} → ${e.translation}',
      ],
      if (notes.isNotEmpty) ...['Notes on the translation:', ...notes],
    ].join('\n');
  }

  /// [text] with the lines of [more] added at the end (words it has
  /// already are left out).
  static String add(String text, Iterable<GlossaryEntry> more) {
    final g = Glossary.parse(text);
    final fresh = [
      for (final e in more)
        if (!g.has(e.term)) e.line,
    ];
    if (fresh.isEmpty) return text;
    final base = text.trimRight();
    return '${base.isEmpty ? '' : '$base\n'}${fresh.join('\n')}\n';
  }
}

/// What the chat is asked for, after the answer, about words missing from
/// the glossary.
const glossaryNewInstruction =
    'If you meet names or special words that are not in the glossary, write after the answer an empty line and '
    'then one line for each: NEW: word --> translation';

final _newTerm = RegExp(
  // Chats like markdown: `**New:** Kai → Кай`.
  r'^[ \t>*_•-]*NEW[*_]*\s*:[*_]*\s*(.+?)\s*(?:-{1,3}>|=>|→|⟶|—>|–>)\s*(.+?)\s*$',
  multiLine: true,
  caseSensitive: false,
);

/// The words a chat suggests for the glossary (`NEW: Kai --> Кай` lines).
List<GlossaryEntry> exchangeNewTerms(String answer) => [
  for (final m in _newTerm.allMatches(answer.replaceAll('\r\n', '\n')))
    if (m[1]!.trim().isNotEmpty && m[2]!.trim().isNotEmpty) GlossaryEntry(m[1]!.trim(), m[2]!.trim()),
];

/// [answer] without the `NEW:` lines (they are no answer for a piece).
String withoutNewTerms(String answer) => answer.replaceAll('\r\n', '\n').replaceAll(_newTerm, '');

/// A ready style of translation for the instructions: the user picks
/// several, and adds own ones.
class PromptStyle {
  const PromptStyle(this.id, this.text, {this.name = ''});

  /// Built-in ones: `literal`, …; own ones: `own_1`, ….
  final String id;

  /// For the instructions, in English (chats follow English best).
  final String text;

  /// The name of an own style (built-in ones are named by the app).
  final String name;

  bool get builtIn => !id.startsWith('own_');

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'text': text};

  static PromptStyle? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], text = json['text'];
    if (id is! String || text is! String || text.trim().isEmpty) return null;
    return PromptStyle(id, text, name: json['name'] is String ? json['name'] as String : '');
  }
}

const builtInPromptStyles = [
  PromptStyle('literal', 'Translate close to the original wording; add nothing and leave nothing out.'),
  PromptStyle(
    'lively',
    'Make it lively and conversational, the way people really talk; use slang where the original does.',
  ),
  PromptStyle('soften', 'Soften rude words and swearing.'),
  PromptStyle('keep_swearing', 'Keep rude words and swearing as strong as in the original.'),
  PromptStyle(
    'honorifics',
    'Keep Japanese honorifics (-san, -kun, -chan, -sama, senpai) as they are, written in the alphabet of the translation.',
  ),
];

/// The style line of the instructions for [styles]; empty without styles.
String promptStyleLine(Iterable<PromptStyle> styles) {
  final texts = [
    for (final s in styles)
      if (s.text.trim().isNotEmpty) s.text.trim(),
  ];
  return texts.isEmpty ? '' : 'Style of the translation: ${texts.join(' ')}';
}

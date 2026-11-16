/// The offline dictionary window: a search field and the cards of what it
/// found (Russian words by meaning, Russian explanations with examples,
/// English explanations folded). A Russian word clicked goes into the
/// glossary of the project.
library;

import 'dart:async';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/dictionary.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';
import 'batch_dialogs.dart';

/// Opens the dictionary on [query] (empty: the search field only).
Future<void> showDictionary(BuildContext context, {String query = ''}) => showDialog<void>(
  context: context,
  builder: (_) => DictionaryDialog(query: query),
);

class DictionaryDialog extends ConsumerStatefulWidget {
  const DictionaryDialog({super.key, this.query = ''});

  final String query;

  @override
  ConsumerState<DictionaryDialog> createState() => _DictionaryDialogState();
}

class _DictionaryDialogState extends ConsumerState<DictionaryDialog> {
  late final _field = TextEditingController(text: widget.query);
  String _query = '';
  Timer? _debounce;

  /// What happened last (a word added to the glossary, a failed download).
  String? _note;
  double? _download;
  String? _offline;
  bool _translating = false;

  @override
  void initState() {
    super.initState();
    _query = widget.query.trim();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _search(text));
    });
  }

  void _search(String text) {
    _query = text.trim();
    _offline = null;
    _note = null;
  }

  void _searchNow(String text) {
    _field.text = text;
    setState(() => _search(text));
  }

  Future<void> _downloadDictionary() async {
    const spec = ModelCatalog.dictEnRu;
    final l = context.l10n;
    if (!await DialogBatchUi(context).confirmDownload(const [spec]) || !mounted) return;
    final models = ref.read(servicesProvider).models;
    setState(() => _download = 0);
    try {
      await models.download(
        spec,
        onProgress: (d) {
          if (mounted) setState(() => _download = d.received / spec.totalSize);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _note = e is ModelDownloadException && e.network ? l.downloadNetworkFailed : l.downloadFailed('$e'),
        );
      }
    } finally {
      ref.invalidate(dictionaryProvider);
      if (mounted) setState(() => _download = null);
    }
  }

  void _addToGlossary(String term, String word) {
    final l = context.l10n;
    final ws = ref.read(workspaceProvider);
    final now = ws.glossary;
    if (Glossary.parse(now).has(term)) {
      setState(() => _note = l.dictAlreadyThere(term));
      return;
    }
    ref.read(workspaceProvider.notifier).setGlossary(Glossary.add(now, [GlossaryEntry(term, word)]));
    setState(() => _note = l.dictAdded(term, word));
  }

  Future<void> _translateOffline() async {
    final l = context.l10n;
    final text = _query;
    setState(() => _translating = true);
    String? result;
    try {
      result = await translateOffline(ref.read(servicesProvider).models, text);
    } catch (e) {
      result = '$e';
    }
    if (!mounted || text != _query) return;
    setState(() {
      _translating = false;
      _offline = result ?? l.dictNoOfflineModel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dict = ref.watch(dictionaryProvider);
    final showEnglish = ref.watch(settingsProvider.select((s) => s.dictShowEnglish));
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.local_library_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text(l.dictTitle)),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _field,
              autofocus: widget.query.isEmpty,
              decoration: InputDecoration(
                hintText: l.dictSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _field.text.isEmpty
                    ? null
                    : IconButton(onPressed: () => _searchNow(''), icon: const Icon(Icons.clear)),
              ),
              onChanged: _typed,
              onSubmitted: (v) => setState(() => _search(v)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: switch (dict) {
                AsyncData(value: final d?) => _results(d, showEnglish, l, theme),
                AsyncData() => _notDownloaded(l, theme),
                AsyncError(:final error) => Text(
                  l.dictBroken('$error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close))],
    );
  }

  Widget _notDownloaded(AppLocalizations l, ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l.dictNotDownloaded(formatBytes(ModelCatalog.dictEnRu.totalSize))),
      const SizedBox(height: 12),
      if (_download case final p?)
        LinearProgressIndicator(value: p)
      else
        FilledButton.icon(
          onPressed: _downloadDictionary,
          icon: const Icon(Icons.download_outlined),
          label: Text(l.dictDownload),
        ),
    ],
  );

  Widget _results(OfflineDictionary dict, bool showEnglish, AppLocalizations l, ThemeData theme) {
    if (_query.isEmpty) {
      return Text(l.dictEmpty, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    final cards = dict.lookup(_query);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    if (cards.isEmpty) {
      final similar = _similar(dict, _query);
      return ListView(
        children: [
          Text(l.dictNotFound(_query)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _translating ? null : _translateOffline,
                icon: _translating
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.translate),
                label: Text(l.dictTranslateOffline),
              ),
            ],
          ),
          if (_offline != null) ...[const SizedBox(height: 8), SelectableText(_offline!)],
          if (similar.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l.dictSimilar, style: muted),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final w in similar) ActionChip(label: Text(w), onPressed: () => _searchNow(w))],
            ),
          ],
        ],
      );
    }
    return ListView(
      children: [
        if (cards.any((c) => c.parts.any((p) => p.translations.isNotEmpty))) Text(l.dictAddHint, style: muted),
        const SizedBox(height: 8),
        for (final c in cards)
          _Card(card: c, showEnglish: showEnglish, onWord: (w) => _addToGlossary(c.headword, w), onLink: _searchNow),
      ],
    );
  }
}

/// Words starting as much like [query] as the dictionary has (the longest
/// beginning, down to 3 letters): "messing up" → messing, messing about…
List<String> _similar(OfflineDictionary dict, String query) {
  final q = normalizeDictQuery(query);
  for (var n = q.length; n > 0 && (n >= 3 || n == q.length); n--) {
    final found = dict.suggest(q.substring(0, n), limit: 12);
    if (found.isNotEmpty) return found;
  }
  return const [];
}

class _Card extends StatelessWidget {
  const _Card({required this.card, required this.showEnglish, required this.onWord, required this.onLink});

  final DictCard card;
  final bool showEnglish;
  final ValueChanged<String> onWord;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final parts = [
      for (final p in card.parts)
        if (p.hasRussian || p.formOf.isNotEmpty || (showEnglish && p.english.isNotEmpty)) p,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                SelectableText(card.headword, style: theme.textTheme.titleMedium),
                if (card.note != null) Text(card.note!, style: muted),
              ],
            ),
            if (parts.isEmpty) Text(l.dictOnlyEnglish, style: muted),
            for (final p in parts) _part(p, l, theme, muted),
          ],
        ),
      ),
    );
  }

  Widget _part(DictPart p, AppLocalizations l, ThemeData theme, TextStyle? muted) {
    final label = l.dictPos(p.pos);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label == '?' ? p.pos : label,
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
          ),
          for (final f in p.formOf)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _FormOf(text: f, onLink: onLink, style: muted),
            ),
          for (final t in p.translations)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final w in t.words) _WordChip(word: w, onTap: () => onWord(w)),
                  if (t.sense.isNotEmpty) Text('— ${t.sense}', style: muted),
                ],
              ),
            ),
          for (final s in p.russian) _sense(s, muted, russian: true),
          if (showEnglish && p.english.isNotEmpty)
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                // Open by itself when the word has no Russian here.
                initiallyExpanded: !p.hasRussian,
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(l.dictEnglish(p.english.length), style: muted),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final s in p.english) _sense(s, muted, russian: false)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sense(DictSense s, TextStyle? muted, {required bool russian}) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(text: '• ${s.gloss}'),
              if (s.tags.isNotEmpty) TextSpan(text: '  ${s.tags.join(', ')}', style: muted),
            ],
          ),
        ),
        for (final x in s.examples.take(russian ? 1 : 2))
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: SelectableText(
              x.translation == null ? '«${x.text}»' : '«${x.text}» — ${x.translation}',
              style: muted?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    ),
  );
}

/// A Russian word: a click puts it into the glossary.
class _WordChip extends StatelessWidget {
  const _WordChip({required this.word, required this.onTap});

  final String word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.dictAddTip,
    child: ActionChip(
      label: Text(word),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: onTap,
    ),
  );
}

/// "plural of guy": the last word opens its card.
class _FormOf extends StatelessWidget {
  const _FormOf({required this.text, required this.onLink, this.style});

  final String text;
  final ValueChanged<String> onLink;
  final TextStyle? style;

  static final _of = RegExp(r'^(.*\bof )(.+?)\.?$');

  @override
  Widget build(BuildContext context) {
    final m = _of.firstMatch(text);
    if (m == null) return Text('↪ $text', style: style);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('↪ ${m[1]}', style: style),
        InkWell(
          onTap: () => onLink(m[2]!),
          child: Text(
            m[2]!,
            style: style?.copyWith(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}

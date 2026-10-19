/// The find and replace panel (original `search_replace_panel.py`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/search.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';
import 'text_panel.dart' show findOpenProvider;

class FindReplacePanel extends ConsumerStatefulWidget {
  const FindReplacePanel({super.key});

  @override
  ConsumerState<FindReplacePanel> createState() => _FindReplacePanelState();
}

class _FindReplacePanelState extends ConsumerState<FindReplacePanel> {
  final _find = TextEditingController();
  final _replace = TextEditingController();
  final _findFocus = FocusNode();
  var _o = const SearchOptions();
  var _current = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _findFocus.requestFocus());
  }

  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  List<SearchMatch> _matches(WorkspaceState ws) {
    try {
      return findMatches(ws.pages, _o, current: ws.currentPage?.id);
    } on FormatException {
      return const [];
    }
  }

  String? _error() {
    try {
      searchPattern(_o);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  void _go(int delta) {
    final ws = ref.read(workspaceProvider);
    final matches = _matches(ws);
    if (matches.isEmpty) return;
    final next = (_current + delta) % matches.length;
    setState(() => _current = next < 0 ? next + matches.length : next);
    _show(matches[_current]);
  }

  void _show(SearchMatch m) {
    final notifier = ref.read(workspaceProvider.notifier);
    final index = ref.read(workspaceProvider).pages.indexWhere((p) => p.id == m.pageId);
    if (index < 0) return;
    notifier.select(index);
    notifier.selectBlock(m.block);
  }

  void _replaceOne() {
    final ws = ref.read(workspaceProvider);
    final matches = _matches(ws);
    if (matches.isEmpty) return;
    final m = matches[_current.clamp(0, matches.length - 1)];
    final page = ws.byId(m.pageId);
    if (page == null || m.block >= page.blocks.length) return;
    final b = page.blocks[m.block];
    final text = replaceAt(_o.inSource ? b.text : b.translation, m.start, _o, _replace.text);
    if (text == null) return;
    ref.read(workspaceProvider.notifier).editBlock(m.pageId, m.block, (b) => setField(b, _o, text));
    // The next match moves into the replaced one's place.
    final left = _matches(ref.read(workspaceProvider));
    setState(() => _current = left.isEmpty ? -1 : _current.clamp(0, left.length - 1));
    if (left.isNotEmpty) _show(left[_current]);
  }

  void _replaceEverywhere() {
    final l = context.l10n;
    final ws = ref.read(workspaceProvider);
    final notifier = ref.read(workspaceProvider.notifier);
    var total = 0;
    for (final page in ws.pages) {
      if (!_o.allPages && page.id != ws.currentPage?.id) continue;
      var changed = false;
      final blocks = [
        for (final b in page.blocks)
          () {
            final (text, n) = replaceAll(_o.inSource ? b.text : b.translation, _o, _replace.text);
            if (n == 0) return b;
            total += n;
            changed = true;
            final c = b.copy();
            setField(c, _o, text);
            return c;
          }(),
      ];
      if (changed) notifier.edit(page.id, (p) => p.copyWith(blocks: blocks));
    }
    setState(() => _current = -1);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.replacedCount('$total')), showCloseIcon: true));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ws = ref.watch(workspaceProvider);
    final matches = _matches(ws);
    final error = _error();
    final pages = {for (final m in matches) m.pageId}.length;
    void options(SearchOptions o) => setState(() {
      _o = o;
      _current = -1;
    });
    Widget toggle(String text, String tip, bool on, VoidCallback onTap) => Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: on ? theme.colorScheme.secondaryContainer : null,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Text(text, style: theme.textTheme.labelMedium),
        ),
      ),
    );
    InputDecoration deco(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      suffix: suffix,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => ref.read(findOpenProvider.notifier).set(false),
        const SingleActivator(LogicalKeyboardKey.enter, shift: true): () => _go(-1),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _find,
              focusNode: _findFocus,
              decoration: deco(
                l.findHint,
                suffix: Text(
                  matches.isEmpty
                      ? (_find.text.isEmpty ? '' : '0')
                      : '${_current < 0 ? '–' : _current + 1}/${matches.length}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              onChanged: (v) => options(_o.copyWith(query: v)),
              onSubmitted: (_) {
                _go(1);
                _findFocus.requestFocus();
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                toggle('Aa', l.matchCase, _o.matchCase, () => options(_o.copyWith(matchCase: !_o.matchCase))),
                const SizedBox(width: 4),
                toggle('[ab]', l.wholeWord, _o.wholeWord, () => options(_o.copyWith(wholeWord: !_o.wholeWord))),
                const SizedBox(width: 4),
                toggle('.*', l.useRegex, _o.regex, () => options(_o.copyWith(regex: !_o.regex))),
                const Spacer(),
                IconButton(
                  tooltip: l.previousMatch,
                  visualDensity: VisualDensity.compact,
                  onPressed: matches.isEmpty ? null : () => _go(-1),
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: l.nextMatch,
                  visualDensity: VisualDensity.compact,
                  onPressed: matches.isEmpty ? null : () => _go(1),
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<bool>(
                    value: _o.inSource,
                    isExpanded: true,
                    isDense: true,
                    items: [
                      DropdownMenuItem(value: false, child: Text(l.searchInTranslation)),
                      DropdownMenuItem(value: true, child: Text(l.searchInSource)),
                    ],
                    onChanged: (v) => options(_o.copyWith(inSource: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<bool>(
                    value: _o.allPages,
                    isExpanded: true,
                    isDense: true,
                    items: [
                      DropdownMenuItem(value: true, child: Text(l.searchAllPages)),
                      DropdownMenuItem(value: false, child: Text(l.searchThisPage)),
                    ],
                    onChanged: (v) => options(_o.copyWith(allPages: v)),
                  ),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.badRegex(error), style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              )
            else if (_find.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.matchesSummary('${matches.length}', '$pages'), style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            TextField(controller: _replace, decoration: deco(l.replaceHint)),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton(onPressed: matches.isEmpty ? null : _replaceOne, child: Text(l.replace)),
                FilledButton.tonal(onPressed: matches.isEmpty ? null : _replaceEverywhere, child: Text(l.replaceAll)),
              ],
            ),
            const Divider(height: 16),
          ],
        ),
      ),
    );
  }
}

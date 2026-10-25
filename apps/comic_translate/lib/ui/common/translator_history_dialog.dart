/// "Translator history" (the owner's idea): the last requests to translators
/// over the network, what went and what came back, to see how the model
/// really answers. Opened from the translator settings and from the page
/// (only its requests). Not in the original.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/app_state.dart';
import '../settings/usage_section.dart' show formatMoney;
import 'labels.dart';
import 'plugin_strings.dart';

/// [page]: the name of the page whose requests are shown first (the filter
/// can be turned off).
Future<void> showTranslatorHistory(BuildContext context, {String? page}) => showDialog<void>(
  context: context,
  builder: (_) => _HistoryDialog(page: page),
);

class _HistoryDialog extends ConsumerStatefulWidget {
  const _HistoryDialog({this.page});

  final String? page;

  @override
  ConsumerState<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends ConsumerState<_HistoryDialog> {
  List<HistoryEntry>? _entries;
  late var _onlyPage = widget.page != null;
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ref.read(servicesProvider).history.read();
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _clear() async {
    final l = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.historyClearAsk),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.historyClear)),
        ],
      ),
    );
    if (sure != true) return;
    await ref.read(servicesProvider).history.clear();
    await _load();
  }

  /// The translator's name as the settings show it.
  String _pluginName(String id) {
    final registry = ref.read(servicesProvider).registry;
    return registry.contains(id) ? pluginName(context, registry.info(id)) : id;
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _note = context.l10n.historyCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final all = _entries;
    final shown = [
      for (final e in all ?? const <HistoryEntry>[])
        if (!_onlyPage || e.page == widget.page) e,
    ];
    String seconds(int ms) => NumberFormat('0.0', locale).format(ms / 1000);
    Widget block(String title, String text, String empty) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            if (text.isNotEmpty)
              TextButton.icon(
                onPressed: () => _copy(text),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(l.secretCopy),
              ),
          ],
        ),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 260),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              text.isEmpty ? empty : text,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
            ),
          ),
        ),
      ],
    );
    return AlertDialog(
      title: Text(l.historyTitle),
      content: SizedBox(
        width: 900,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.historyHelp('${TranslatorHistory.keep}'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.page != null)
                  FilterChip(
                    label: Text(l.historyOnlyPage(widget.page!)),
                    selected: _onlyPage,
                    onSelected: (v) => setState(() => _onlyPage = v),
                  ),
                if (all != null) Text(l.historyCount(shown.length, all.length), style: theme.textTheme.bodySmall),
                if (_note != null)
                  Text(_note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: all == null
                  ? const Center(child: CircularProgressIndicator())
                  : shown.isEmpty
                  ? Center(child: Text(_onlyPage ? l.historyNoneForPage : l.historyNone, textAlign: TextAlign.center))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final e = shown[i];
                        final missing = e.warnings.length;
                        final outcome = e.failed
                            ? l.historyFailed(e.error)
                            : missing == 0
                            ? l.historyOk(e.blocks)
                            : l.historyMissing(e.blocks - missing.clamp(0, e.blocks), e.blocks);
                        final color = e.failed
                            ? theme.colorScheme.error
                            : missing > 0
                            ? theme.colorScheme.tertiary
                            : Colors.green.shade600;
                        return Card.outlined(
                          child: ExpansionTile(
                            leading: Icon(
                              e.failed ? Icons.error_outline : (missing > 0 ? Icons.warning_amber : Icons.check_circle),
                              color: color,
                            ),
                            title: Text(
                              [
                                DateFormat('d MMM, HH:mm:ss', locale).format(e.time),
                                if (e.page.isNotEmpty) e.page,
                                e.model,
                                l.historySeconds(seconds(e.ms)),
                              ].join(' · '),
                            ),
                            subtitle: Text(
                              outcome,
                              style: TextStyle(color: color),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            expandedCrossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  '${e.host} (${_pluginName(e.plugin)})',
                                  if (e.image) l.historyImage,
                                  if (e.inputTokens + e.outputTokens > 0)
                                    l.historyTokens(e.inputTokens, e.outputTokens),
                                  if (e.cost != null) formatMoney(context, e.cost!),
                                ].join(' · '),
                                style: theme.textTheme.bodySmall,
                              ),
                              if (e.warnings.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(l.historyWarnings(e.warnings.join('; ')), style: theme.textTheme.bodySmall),
                              ],
                              const SizedBox(height: 8),
                              block(l.historySent, e.sent, ''),
                              const SizedBox(height: 8),
                              block(l.historyReply, e.reply, l.historyNoReply),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: all == null || all.isEmpty ? null : _clear,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: Text(l.historyClear),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
      ],
    );
  }
}

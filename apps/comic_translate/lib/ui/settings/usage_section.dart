/// What is left of the API key (asked from the service on request) and the
/// usage the program counted on this computer. Not in the original.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/app_state.dart';
import '../common/labels.dart';

/// The usage counter, read again each time the settings open.
final usageReportProvider = FutureProvider.autoDispose<UsageReport>((ref) => ref.read(servicesProvider).usage.read());

String _locale(BuildContext context) => Localizations.localeOf(context).toString();

/// `0,9962 $`: fractions of a cent stay visible ([moneyDecimals]).
String formatMoney(BuildContext context, double v) => NumberFormat.currency(
  locale: _locale(context),
  symbol: r'$',
  decimalDigits: moneyDecimals(v),
).format(v);

String _number(BuildContext context, int v) => NumberFormat.decimalPattern(_locale(context)).format(v);

/// "Check balance": sends only the key, only to [KeyStatusQuery.host], only
/// when pressed.
class KeyStatusPanel extends ConsumerStatefulWidget {
  const KeyStatusPanel(this.info, {super.key, required this.host});

  final PluginInfo info;
  final String host;

  @override
  ConsumerState<KeyStatusPanel> createState() => _KeyStatusPanelState();
}

class _KeyStatusPanelState extends ConsumerState<KeyStatusPanel> {
  bool _checking = false;
  KeyStatus? _status;
  String? _error;
  DateTime? _at;

  Future<void> _check() async {
    final l = context.l10n;
    final services = ref.read(servicesProvider);
    final config = await services.pluginConfig(widget.info.id, ref.read(settingsProvider));
    final query = widget.info.keyStatus?.call(config);
    if (query == null || !mounted) return;
    if (!query.hasKey) {
      setState(() {
        _status = null;
        _error = l.keyStatusNeedsKey;
      });
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    services.appLog.info('key_status_request', {'plugin': widget.info.id, 'host': query.host});
    try {
      final status = await query.run();
      services.appLog.info('key_status', {'limit': status.limit, 'remaining': status.remaining});
      if (!mounted) return;
      setState(() {
        _status = status;
        _at = DateTime.now();
      });
    } on TranslationException catch (e) {
      services.appLog.warn('key_status_failed', {'kind': e.kind.name, 'error': e.message});
      if (!mounted) return;
      setState(() {
        _status = null;
        _error = l.keyStatusFailed(translationErrorLabel(l, e.kind));
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = _status;
    String money(double v) => formatMoney(context, v);
    final lines = [
      if (s != null) ...[
        if (s.limit != null)
          l.keyStatusLimit(money(s.limit!), money(s.used), money(s.remaining ?? s.limit! - s.used))
        else
          l.keyStatusNoLimit(money(s.used)),
        l.keyStatusToday(money(s.usedToday), money(s.usedThisMonth)),
        l.keyStatusDelay,
        if (s.limit != null)
          ...switch (s.limitReset) {
            LimitReset.daily => [l.keyStatusResetDaily],
            LimitReset.weekly => [l.keyStatusResetWeekly],
            LimitReset.monthly => [l.keyStatusResetMonthly],
            null => const <String>[],
          },
        if (s.freeRequestsLimit != null) ...[
          l.keyStatusFree(
            '${s.freeRequestsToday ?? 0}',
            '${s.freeRequestsLimit}',
            '${s.freeRequestsLeft ?? s.freeRequestsLimit! - (s.freeRequestsToday ?? 0)}',
          ),
          l.keyStatusFreeNote,
        ],
        if (_at != null) l.keyStatusAt(DateFormat.Hm(_locale(context)).format(_at!)),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _checking ? null : _check,
                icon: _checking
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.account_balance_wallet_outlined),
                label: Text(_checking ? l.keyStatusChecking : l.keyStatusCheck),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(child: Text(l.keyStatusHelp(widget.host), style: theme.textTheme.bodySmall)),
                ],
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            ),
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, line) in lines.indexed)
                    Text(line, style: i == 0 ? theme.textTheme.bodyLarge : theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The usage counted on this computer, per model: today and in total.
class UsagePanel extends ConsumerWidget {
  const UsagePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final report = ref.watch(usageReportProvider).value;
    String totals(UsageTotals t) => [
      l.usageRequests(_number(context, t.requests)),
      l.usageTokens('${t.estimated ? '≈' : ''}${_number(context, t.tokens)}'),
      if (t.cost != null) l.usageCost(formatMoney(context, t.cost!)),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.usageHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        if (report != null && report.entries.isEmpty) Text(l.usageNone),
        for (final e in report?.entries ?? const <UsageEntry>[])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.model} · ${e.host}', style: theme.textTheme.titleSmall),
                Text('${l.usageToday}: ${e.today.isEmpty ? '—' : totals(e.today)}'),
                Text('${l.usageTotal}: ${totals(e.total)}'),
              ],
            ),
          ),
        if (report != null && report.entries.isNotEmpty)
          Row(
            children: [
              if (report.since != null)
                Expanded(
                  child: Text(
                    l.usageSince(DateFormat.yMd(_locale(context)).format(report.since!)),
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                const Spacer(),
              TextButton(onPressed: () => _reset(context, ref), child: Text(l.usageReset)),
            ],
          ),
      ],
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.usageResetTitle),
        content: Text(l.usageResetBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.reset)),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(servicesProvider).usage.reset();
    ref.invalidate(usageReportProvider);
  }
}

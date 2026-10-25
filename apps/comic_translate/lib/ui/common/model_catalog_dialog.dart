/// Picking a model from the service's list (OpenRouter): search, free ones,
/// ones that take pictures, prices. The list comes only when the user asks
/// for it, and nothing of the user's goes along. Not in the original.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/app_state.dart';
import '../settings/usage_section.dart' show formatMoney;
import 'labels.dart';

/// The lists already fetched in this session, by host.
final _fetched = <String, List<CatalogModel>>{};

/// The model picked (its id), or null.
Future<String?> showModelCatalogDialog(
  BuildContext context,
  ModelCatalogQuery query, {
  required String current,
  bool vision = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _ModelCatalogDialog(query, current: current, vision: vision),
);

enum _Order { newest, cheapest, name, context }

class _ModelCatalogDialog extends ConsumerStatefulWidget {
  const _ModelCatalogDialog(this.query, {required this.current, required this.vision});

  final ModelCatalogQuery query;
  final String current;

  /// The page image goes along: models that take pictures are offered.
  final bool vision;

  @override
  ConsumerState<_ModelCatalogDialog> createState() => _ModelCatalogDialogState();
}

class _ModelCatalogDialogState extends ConsumerState<_ModelCatalogDialog> {
  late List<CatalogModel>? _models = _fetched[_hostKey];
  String? _error;
  var _loading = false;
  final _search = TextEditingController();
  var _freeOnly = false;
  late var _visionOnly = widget.vision;
  var _order = _Order.newest;

  String get _hostKey => widget.query.host;

  @override
  void initState() {
    super.initState();
    if (_models == null) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final log = ref.read(servicesProvider).appLog;
    setState(() {
      _loading = true;
      _error = null;
    });
    log.info('model_catalog_request', {'host': widget.query.host});
    try {
      final models = await widget.query.run();
      _fetched[_hostKey] = models;
      log.info('model_catalog', {'models': models.length});
      if (mounted) setState(() => _models = models);
    } on TranslationException catch (e) {
      log.warn('model_catalog_failed', {'kind': e.kind.name, 'error': e.message});
      if (!mounted) return;
      final l = context.l10n;
      setState(() => _error = l.modelsFailed(translationErrorLabel(l, e.kind)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The models the search and the filters leave, in the chosen order.
  List<CatalogModel> get _shown {
    final words = _search.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final shown = [
      for (final m in _models ?? const <CatalogModel>[])
        if ((!_freeOnly || m.free) &&
            (!_visionOnly || m.vision) &&
            words.every((w) => m.id.toLowerCase().contains(w) || m.name.toLowerCase().contains(w)))
          m,
    ];
    // Unknown prices last when the cheapest go first.
    double price(CatalogModel m) =>
        m.promptPrice == null || m.completionPrice == null ? double.infinity : m.promptPrice! + m.completionPrice!;
    shown.sort(
      (a, b) => switch (_order) {
        _Order.newest => (b.created?.millisecondsSinceEpoch ?? 0).compareTo(a.created?.millisecondsSinceEpoch ?? 0),
        _Order.cheapest => price(a).compareTo(price(b)),
        _Order.name => (a.name.isEmpty ? a.id : a.name).toLowerCase().compareTo(
          (b.name.isEmpty ? b.id : b.name).toLowerCase(),
        ),
        _Order.context => (b.contextLength ?? 0).compareTo(a.contextLength ?? 0),
      },
    );
    return shown;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final models = _models;
    final shown = _shown;
    final locale = Localizations.localeOf(context).toString();
    String tokens(int n) => NumberFormat.compact(locale: locale).format(n);
    String details(CatalogModel m) => [
      if (m.free)
        l.modelsFree
      else if (m.promptPrice != null && m.completionPrice != null)
        l.modelsPrice(formatMoney(context, m.promptPrice!), formatMoney(context, m.completionPrice!)),
      if (m.contextLength != null) l.modelsContext(tokens(m.contextLength!)),
      if (m.vision) l.modelsVision,
    ].join(' · ');
    return AlertDialog(
      title: Text(l.modelsTitle(widget.query.host)),
      content: SizedBox(
        width: 760,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.modelsHelp(widget.query.host), style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      hintText: l.modelsSearch,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<_Order>(
                  value: _order,
                  items: [
                    DropdownMenuItem(value: _Order.newest, child: Text(l.modelsNewest)),
                    DropdownMenuItem(value: _Order.cheapest, child: Text(l.modelsCheapest)),
                    DropdownMenuItem(value: _Order.name, child: Text(l.modelsByName)),
                    DropdownMenuItem(value: _Order.context, child: Text(l.modelsByContext)),
                  ],
                  onChanged: (v) => setState(() => _order = v ?? _order),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: Text(l.modelsFreeOnly),
                  selected: _freeOnly,
                  onSelected: (v) => setState(() => _freeOnly = v),
                ),
                FilterChip(
                  label: Text(l.modelsVisionOnly),
                  tooltip: l.modelsVisionHelp,
                  selected: _visionOnly,
                  onSelected: (v) => setState(() => _visionOnly = v),
                ),
                if (models != null) Text(l.modelsCount(shown.length, models.length), style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: _load, child: Text(l.modelsRetry)),
                        ],
                      ),
                    )
                  : shown.isEmpty
                  ? Center(child: Text(l.modelsNone))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final m = shown[i];
                        final current = m.id == widget.current;
                        return ListTile(
                          dense: true,
                          selected: current,
                          leading: Icon(current ? Icons.check_circle : Icons.smart_toy_outlined),
                          title: Text(m.name.isEmpty ? m.id : m.name),
                          subtitle: Text('${m.id}\n${details(m)}'),
                          isThreeLine: true,
                          onTap: () => Navigator.pop(context, m.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          label: Text(l.modelsRefresh),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
      ],
    );
  }
}

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../common/labels.dart';

String _normalized(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

typedef _Connection = ({String? id, String name, String sortName, int order, String address, String model});

class OwnServerProfiles extends ConsumerWidget {
  const OwnServerProfiles(this.info, {super.key, this.forOcr = false});

  final PluginInfo info;
  final bool forOcr;

  void _select(AppSettings settings, String? id) {
    if (forOcr) {
      settings.ownServerOcrProfile = id;
    } else {
      settings.ownServerProfile = id ?? '';
    }
  }

  Future<void> _name(BuildContext context, WidgetRef ref, {String? id, String initial = ''}) async {
    final taken = {
      _normalized(context.l10n.ownServerOriginal),
      for (final entry in ref.read(settingsProvider).ownServerNames.entries)
        if (entry.key != id) _normalized(entry.value),
    };
    final name = await showDialog<String>(context: context, builder: (_) => _ProfileName(initial, taken));
    if (name == null || !context.mounted) return;
    await ref.read(settingsProvider.notifier).change((s) {
      final profile = id ?? DateTime.now().microsecondsSinceEpoch.toString();
      s.ownServerNames[profile] = name;
      _select(s, profile);
    });
  }

  Future<void> _choose(BuildContext context, WidgetRef ref, String? active, List<_Connection> connections) async {
    final l = context.l10n;
    final title = forOcr ? l.ownServerOcrConnection : l.ownServerProfile;
    final searchLabel = forOcr ? l.ownServerOcrSearch : l.ownServerSearch;
    final selected = await showDialog<_Connection>(
      context: context,
      builder: (_) => _ProfilePicker(active, connections, title, searchLabel),
    );
    if (selected == null || selected.id == active || !context.mounted) return;
    await ref.read(settingsProvider.notifier).change((s) => _select(s, selected.id));
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String profile, String storageId) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.ownServerRemoveTitle),
        content: Text(l.ownServerRemoveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final secrets = ref.read(servicesProvider).secrets;
    final settings = ref.read(settingsProvider.notifier);
    for (final slot in ref.read(settingsProvider).keysForOwnServer(storageId).slots) {
      await secrets.delete(AppSettings.ownServerSecretKey(storageId, slot));
    }
    for (final field in info.settings.whereType<SecretSetting>()) {
      if (field.key != 'api_key') await secrets.delete(field.storeKey(storageId));
    }
    await settings.change((s) {
      s.plugins.remove(storageId);
      s.ownServerKeys.remove(storageId);
      s.ownServerNames.remove(profile);
      if (s.ownServerProfile == profile) s.ownServerProfile = '';
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final active = forOcr
        ? s.ownServerOcrProfile
        : s.ownServerNames.containsKey(s.ownServerProfile)
        ? s.ownServerProfile
        : '';
    final names = {'': l.ownServerOriginal, ...s.ownServerNames};
    final counts = <String, int>{};
    for (final name in names.values) {
      counts.update(_normalized(name), (count) => count + 1, ifAbsent: () => 1);
    }
    final ordinal = <String, int>{};
    final connections = <_Connection>[];
    for (final MapEntry(key: id, value: name) in names.entries) {
      final key = _normalized(name);
      final label = id.isEmpty || counts[key] == 1
          ? name
          : '$name · ${ordinal.update(key, (n) => n + 1, ifAbsent: () => 1)}';
      final values = s.plugins[AppSettings.ownServerStorageId(id)];
      connections.add((
        id: id,
        name: label,
        sortName: key,
        order: connections.length,
        address: '${values?['api_url'] ?? ''}',
        model: forOcr ? '' : '${values?['model'] ?? ''}',
      ));
    }
    if (forOcr) {
      connections.add((
        id: null,
        name: l.ownServerOcrManual,
        sortName: '',
        order: connections.length,
        address: '${s.plugins['openai_compatible_ocr']?['api_url'] ?? ''}',
        model: '',
      ));
    }
    final current = connections.where((entry) => entry.id == active).firstOrNull;
    final name = s.ownServerNames[active];
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            onPressed: () => _choose(context, ref, active, connections),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: forOcr ? l.ownServerOcrConnection : l.ownServerProfile,
                border: InputBorder.none,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(current?.name ?? l.ownServerOcrMissing, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
        IconButton(tooltip: l.ownServerAdd, onPressed: () => _name(context, ref), icon: const Icon(Icons.add)),
        if (active != null && active.isNotEmpty && name != null) ...[
          IconButton(
            tooltip: l.ownServerRename,
            onPressed: () => _name(context, ref, id: active, initial: name),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: l.delete,
            onPressed: () => _remove(context, ref, active, AppSettings.ownServerStorageId(active)),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ],
    );
  }
}

class _ProfilePicker extends ConsumerStatefulWidget {
  const _ProfilePicker(this.active, this.connections, this.title, this.searchLabel);

  final String? active;
  final List<_Connection> connections;
  final String title;
  final String searchLabel;

  @override
  ConsumerState<_ProfilePicker> createState() => _ProfilePickerState();
}

class _ProfilePickerState extends ConsumerState<_ProfilePicker> {
  final _scroll = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final byName = ref.watch(settingsProvider.select((s) => s.ownServersByName));
    final matches = widget.connections
        .where((entry) => _normalized('${entry.name} ${entry.address} ${entry.model}').contains(_query))
        .toList();
    if (byName) {
      matches.sort((a, b) {
        if (a.order == 0 || b.order == 0) return a.order.compareTo(b.order);
        if (a.id == null || b.id == null) return a.order.compareTo(b.order);
        final names = a.sortName.compareTo(b.sortName);
        return names == 0 ? a.order.compareTo(b.order) : names;
      });
    }
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        height: (MediaQuery.sizeOf(context).height * 0.50).clamp(150.0, 380.0),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(labelText: widget.searchLabel, prefixIcon: const Icon(Icons.search)),
              onChanged: (value) {
                if (_scroll.hasClients) _scroll.jumpTo(0);
                setState(() => _query = _normalized(value));
              },
              onSubmitted: (_) {
                if (matches.length == 1) Navigator.pop(context, matches.single);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.ownServerSortAdded)),
                  ButtonSegment(value: true, label: Text(l.ownServerSortName)),
                ],
                selected: {byName},
                onSelectionChanged: (selection) {
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                  ref.read(settingsProvider.notifier).change((s) => s.ownServersByName = selection.single);
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? Center(child: Text(l.ownServerNoMatches))
                  : Scrollbar(
                      controller: _scroll,
                      thumbVisibility: true,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: ListView.builder(
                          controller: _scroll,
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final entry = matches[index];
                            final selected = entry.id == widget.active;
                            final details = [entry.address, entry.model].where((s) => s.isNotEmpty).join(' · ');
                            return ListTile(
                              selected: selected,
                              title: Text(entry.name),
                              subtitle: details.isEmpty
                                  ? null
                                  : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: selected ? const Icon(Icons.check) : null,
                              onTap: () => Navigator.pop(context, entry),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))],
    );
  }
}

class _ProfileName extends StatefulWidget {
  const _ProfileName(this.initial, this.taken);

  final String initial;
  final Set<String> taken;

  @override
  State<_ProfileName> createState() => _ProfileNameState();
}

class _ProfileNameState extends State<_ProfileName> {
  late final _name = TextEditingController(text: widget.initial);
  bool _duplicate = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (widget.taken.contains(_normalized(name))) {
      setState(() => _duplicate = true);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? l.ownServerAdd : l.ownServerRename),
      content: TextField(
        autofocus: true,
        controller: _name,
        maxLength: 100,
        decoration: InputDecoration(
          labelText: l.ownServerName,
          errorText: _duplicate ? l.ownServerNameTaken : null,
          errorMaxLines: 2,
        ),
        onChanged: (_) {
          if (_duplicate) setState(() => _duplicate = false);
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

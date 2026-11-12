import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../common/labels.dart';
import '../common/plugin_secret_field.dart';

class OwnServerKeyField extends ConsumerStatefulWidget {
  const OwnServerKeyField(this.info, this.field, this.storageId, {super.key});

  final PluginInfo info;
  final SecretSetting field;
  final String storageId;

  @override
  ConsumerState<OwnServerKeyField> createState() => _OwnServerKeyFieldState();
}

class _OwnServerKeyFieldState extends ConsumerState<OwnServerKeyField> {
  static const _noKey = 'none';
  bool _busy = false;

  Future<void> _edit({required bool add, String? slot, String note = ''}) async {
    final l = context.l10n;
    final result = await showDialog<({String key, String note})>(
      context: context,
      builder: (_) => _KeyDialog(add: add, note: note),
    );
    if (result == null || !mounted) return;
    final storageId = widget.storageId;
    final notifier = ref.read(settingsProvider.notifier);
    final services = ref.read(servicesProvider);
    setState(() => _busy = true);
    try {
      final slots = ref.read(settingsProvider).keysForOwnServer(storageId);
      if (add) {
        final id = DateTime.now().microsecondsSinceEpoch.toString();
        final secretKey = AppSettings.ownServerSecretKey(storageId, id);
        final active = slots.activeId;
        final hasActive =
            active != null &&
            (await services.secrets.read(AppSettings.ownServerSecretKey(storageId, active)))?.isNotEmpty == true;
        await services.secrets.write(secretKey, result.key);
        try {
          await notifier.change((s) {
            final current = s.keysForOwnServer(storageId);
            final next = current.withNote(id, result.note);
            s.setOwnServerKeys(
              storageId,
              active != null && !hasActive && current.activeId == active ? next.select(id) : next,
            );
          });
        } catch (_) {
          try {
            await notifier.change((s) {
              final current = s.keysForOwnServer(storageId);
              final next = current.remove(id);
              s.setOwnServerKeys(storageId, current.activeId == id ? next.select(active) : next);
            });
          } finally {
            await services.secrets.delete(secretKey);
          }
          rethrow;
        }
      } else {
        final id = slot!;
        final key = await services.secrets.read(AppSettings.ownServerSecretKey(storageId, id));
        if (key == null || key.isEmpty) {
          _message(l.secretNotSet);
          return;
        }
        if (_containsKey(result.note, key)) {
          _message(l.ownServerKeyNoteSecret);
          return;
        }
        await notifier.change((s) {
          final current = s.keysForOwnServer(storageId);
          if (current.slots.contains(id)) s.setOwnServerKeys(storageId, current.withNote(id, result.note));
        });
      }
    } catch (error, stack) {
      services.appLog.error('own_server_key_save_failed', error, stack);
      _message(l.ownServerKeySaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final storageId = widget.storageId;
    final keys = ref.watch(settingsProvider).keysForOwnServer(storageId);
    final notifier = ref.read(settingsProvider.notifier);
    final active = keys.activeId;
    final slots = keys.slots.toList();
    String label(int index, String id) {
      final note = keys.notes[id] ?? '';
      return [
        if (index == 0) l.ownServerKeyFirst else l.ownServerKeyNumber(index + 1),
        if (note.isNotEmpty) note,
      ].join(' · ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active != null)
          PluginSecretField(
            widget.info,
            widget.field,
            AppSettings.ownServerSecretKey(storageId, active),
            key: ValueKey((storageId, active)),
            storageHelp: l.ownServerKeysSecureHelp,
            removeBody: l.ownServerKeyRemoveBody,
            onRemoved: () => notifier.change((s) {
              final current = s.keysForOwnServer(storageId);
              s.setOwnServerKeys(storageId, current.remove(active));
            }),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey((storageId, active, 'key_selector')),
                initialValue: active ?? _noKey,
                isExpanded: true,
                menuMaxHeight: 320,
                decoration: InputDecoration(labelText: l.ownServerKeyActive),
                items: [
                  for (var i = 0; i < slots.length; i++)
                    DropdownMenuItem(
                      value: slots[i],
                      child: Text(label(i, slots[i]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  DropdownMenuItem(value: _noKey, child: Text(l.ownServerKeyNone)),
                ],
                onChanged: _busy
                    ? null
                    : (id) {
                        if (id == null) return;
                        notifier.change((s) {
                          final current = s.keysForOwnServer(storageId);
                          if (id == _noKey || current.slots.contains(id)) {
                            s.setOwnServerKeys(storageId, current.select(id == _noKey ? null : id));
                          }
                        });
                      },
              ),
            ),
            IconButton(
              tooltip: l.ownServerKeyAdd,
              onPressed: _busy ? null : () => _edit(add: true),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: l.ownServerKeyEditNote,
              onPressed: _busy || active == null
                  ? null
                  : () => _edit(add: false, slot: active, note: keys.notes[active] ?? ''),
              icon: const Icon(Icons.edit_note_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

bool _containsKey(String note, String key) => key.isNotEmpty && (key.length < 6 ? note == key : note.contains(key));

class _KeyDialog extends StatefulWidget {
  const _KeyDialog({required this.add, required this.note});

  final bool add;
  final String note;

  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  final _key = TextEditingController();
  late final _note = TextEditingController(text: widget.note);
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final l = context.l10n;
    final key = _key.text.trim();
    final note = _note.text.trim();
    if (widget.add && key.isEmpty) {
      setState(() => _error = l.ownServerKeyRequired);
      return;
    }
    if (RequestTemplate.containsCredentials(note) || _containsKey(note, key)) {
      setState(() => _error = l.ownServerKeyNoteSecret);
      return;
    }
    Navigator.pop(context, (key: key, note: note));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.add ? l.ownServerKeyAdd : l.ownServerKeyEditNote),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.add)
              TextField(
                controller: _key,
                autofocus: true,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(labelText: l.ownServerKeyValue),
              ),
            TextField(
              controller: _note,
              autofocus: !widget.add,
              maxLength: 100,
              decoration: InputDecoration(labelText: l.ownServerKeyNote, helperText: l.ownServerKeyNoteHelp),
              onSubmitted: (_) => _save(),
            ),
            if (_error case final error?) Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

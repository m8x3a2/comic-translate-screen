import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../common/labels.dart';

class ModelPromptButton extends ConsumerWidget {
  const ModelPromptButton({super.key, required this.pluginId, required this.storageId, this.reader = false});

  final String pluginId;
  final String storageId;
  final bool reader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final values = settings.pluginValues(pluginId);
    final initial = values[llmPromptSetting.key] as String? ?? '';
    final kind = reader ? ModelPromptKind.ocr : ModelPromptKind.translation;
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.edit_note),
        label: Text(l.modelPromptEditor),
        onPressed: () async {
          final notifier = ref.read(settingsProvider.notifier);
          final edited = await showDialog<_PromptEdit>(
            context: context,
            builder: (_) => _ModelPromptDialog(
              initial,
              presets: settings.modelPromptPresets[kind] ?? const [],
              reader: reader,
              together: values['together'] == true,
            ),
          );
          if (edited == null || !context.mounted) return;
          await notifier.change((s) {
            final fields = s.plugins.putIfAbsent(storageId, () => {});
            if (edited.text.isEmpty) {
              fields.remove(llmPromptSetting.key);
            } else {
              fields[llmPromptSetting.key] = edited.text;
            }
            if (edited.presets.isEmpty) {
              s.modelPromptPresets.remove(kind);
            } else {
              s.modelPromptPresets[kind] = edited.presets;
            }
          });
        },
      ),
    );
  }
}

typedef _PromptEdit = ({String text, List<PromptPreset> presets});

class _ModelPromptDialog extends StatefulWidget {
  const _ModelPromptDialog(this.initial, {required this.presets, required this.reader, required this.together});

  final String initial;
  final List<PromptPreset> presets;
  final bool reader;
  final bool together;

  @override
  State<_ModelPromptDialog> createState() => _ModelPromptDialogState();
}

class _ModelPromptDialogState extends State<_ModelPromptDialog> {
  static const _standard = -1;
  static const _custom = -2;

  late final _prompt = TextEditingController(text: widget.initial);
  late final _presets = [...widget.presets];
  late int _selected = _initialSelection();
  final _reply = TextEditingController();
  final _resultKey = GlobalKey();
  String? _result;

  int _initialSelection() {
    if (widget.initial.trim().isEmpty) return _standard;
    final matched = _presets.indexWhere((preset) => preset.text == widget.initial);
    return matched < 0 ? _custom : matched;
  }

  void _pick(int index) {
    if (index == _custom) return;
    setState(() {
      _selected = index;
      _prompt.text = index == _standard ? '' : _presets[index].text;
    });
  }

  Future<void> _editPreset({int? index}) async {
    final l = context.l10n;
    final form = GlobalKey<FormState>();
    final originalName = index == null ? '' : _presets[index].name;
    final originalText = index == null ? _prompt.text : _presets[index].text;
    var name = originalName;
    var text = originalText;
    String normalized(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final preset = await showDialog<PromptPreset>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(index == null ? l.modelPromptPresetAdd : l.modelPromptPresetEdit),
        content: SizedBox(
          width: 520,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  initialValue: originalName,
                  maxLength: 100,
                  onChanged: (value) => name = value,
                  decoration: InputDecoration(labelText: l.chatPresetName),
                  validator: (value) {
                    final key = normalized(value ?? '');
                    if (key.isEmpty) return l.modelPromptPresetNameRequired;
                    if (_presets.indexed.any((row) => row.$1 != index && normalized(row.$2.name) == key)) {
                      return l.modelPromptPresetNameTaken;
                    }
                    return null;
                  },
                ),
                TextFormField(
                  initialValue: originalText,
                  minLines: 4,
                  maxLines: 8,
                  onChanged: (value) => text = value,
                  validator: (value) => (value ?? '').trim().isEmpty ? l.modelPromptPresetTextRequired : null,
                  decoration: InputDecoration(labelText: l.modelPromptInstructions, border: const OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(dialog, PromptPreset(name.trim(), text.trim()));
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (preset == null || !mounted) return;
    final target = index ?? _presets.length;
    setState(() {
      if (index == null) {
        _presets.add(preset);
      } else {
        _presets[index] = preset;
      }
      _selected = target;
      _prompt.text = preset.text;
    });
  }

  Future<void> _deletePreset() async {
    final index = _selected;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.chatPresetDelete),
        content: Text(_presets[index].name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _presets.removeAt(index);
      _selected = _prompt.text.trim().isEmpty ? _standard : _custom;
    });
  }

  Widget _presetPicker() {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            key: ValueKey(_selected),
            initialValue: _selected,
            isExpanded: true,
            menuMaxHeight: 320,
            decoration: InputDecoration(labelText: l.modelPromptPreset, border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: _standard, child: Text(l.modelPromptPresetStandard)),
              if (_selected == _custom) DropdownMenuItem(value: _custom, child: Text(l.chatPresetOwn)),
              for (final (index, preset) in _presets.indexed)
                DropdownMenuItem(
                  value: index,
                  child: Text(preset.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (index) {
              if (index != null) _pick(index);
            },
          ),
        ),
        IconButton(tooltip: l.modelPromptPresetAdd, onPressed: _editPreset, icon: const Icon(Icons.add)),
        IconButton(
          tooltip: l.modelPromptPresetEdit,
          onPressed: _selected < 0 ? null : () => _editPreset(index: _selected),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: l.chatPresetDelete,
          onPressed: _selected < 0 ? null : _deletePreset,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _prompt.dispose();
    _reply.dispose();
    super.dispose();
  }

  void _showCheckResult(String result) {
    setState(() => _result = result);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultKey.currentContext case final resultContext?) Scrollable.ensureVisible(resultContext);
    });
  }

  void _check() {
    final l = context.l10n;
    final missing = <String>[];
    const box = BBox(0, 0, 1, 1);
    if (widget.reader) {
      final mode = widget.together ? ExchangeMode.both : ExchangeMode.recognize;
      final replies = parseExchangeAnswer(_reply.text, mode).replies;
      for (final label in [const ExchangeLabel(1, 1), const ExchangeLabel(1, 2)]) {
        final reply = replies[label];
        if (reply?.original == null ||
            (widget.together && (reply!.missingArrow || (reply.translation?.trim().isEmpty ?? true)))) {
          missing.add('$label');
        }
      }
    } else {
      final blocks = [TextBlock(xyxy: box), TextBlock(xyxy: box)];
      try {
        applyTranslationsJson(blocks, _reply.text);
      } on FormatException {
        _showCheckResult(l.modelPromptInvalidJson);
        return;
      }
      for (final (i, block) in blocks.indexed) {
        if (block.untranslated || block.translation.trim().isEmpty) missing.add('block_$i');
      }
    }
    _showCheckResult(missing.isEmpty ? l.modelPromptValid : l.modelPromptMissing(missing.join(', ')));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final example = widget.reader
        ? widget.together
              ? '[01-001] Hello --> Привет\n[01-002] Goodbye --> Пока'
              : '[01-001] Hello\n[01-002] Goodbye'
        : '{"block_0":"Привет","block_1":"Пока"}';
    return AlertDialog(
      scrollable: true,
      title: Text(l.modelPromptEditor),
      content: SizedBox(
        width: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.modelPromptHelp),
            const SizedBox(height: 12),
            _presetPicker(),
            const SizedBox(height: 6),
            Text(l.modelPromptPresetHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _prompt,
              onChanged: (value) {
                final selection = value.trim().isEmpty ? _standard : _custom;
                if (_selected != selection) setState(() => _selected = selection);
              },
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(labelText: l.modelPromptInstructions, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(l.modelPromptExample)),
                TextButton(
                  onPressed: () => setState(() {
                    _reply.text = example;
                    _result = null;
                  }),
                  child: Text(l.fillPromptSample),
                ),
              ],
            ),
            SelectableText(example, style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 8),
            TextField(
              controller: _reply,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) {
                if (_result != null) setState(() => _result = null);
              },
              decoration: InputDecoration(labelText: l.modelPromptReply, border: const OutlineInputBorder()),
            ),
            if (_result case final result?) SelectableText(result, key: _resultKey),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _check, child: Text(l.checkSample)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, (text: _prompt.text.trim(), presets: List.of(_presets))),
          child: Text(l.save),
        ),
      ],
    );
  }
}

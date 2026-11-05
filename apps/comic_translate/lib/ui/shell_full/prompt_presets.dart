/// The user's own presets of instructions for the chat: the list to pick
/// from (in the exchange window and in the settings) and the name asked when
/// one is saved.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';

import '../common/labels.dart';

/// Picks the instructions of [kind]: the built-in ones, a preset, or (shown
/// only while in use) own ones without a name. [onPick] gets the text to use
/// ('' = the built-in instructions).
class PromptPresetPicker extends StatelessWidget {
  const PromptPresetPicker({
    super.key,
    required this.settings,
    required this.kind,
    required this.onPick,
    this.width = 280,
  });

  final ExchangeSettings settings;
  final ExchangePrompt kind;
  final ValueChanged<String> onPick;
  final double width;

  static const _standard = '';
  static const _own = '\u0000own';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final presets = settings.presetsFor(kind);
    final active = settings.activePreset(kind);
    final value = active?.name ?? (settings.promptFor(kind).trim().isEmpty ? _standard : _own);
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        // The choice may change elsewhere (a preset saved, the text edited).
        key: ValueKey('preset.${kind.name}=$value'),
        initialValue: value,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.chatPreset, isDense: true, border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem(value: _standard, child: Text(l.chatPresetStandard)),
          for (final p in presets)
            DropdownMenuItem(
              value: p.name,
              child: Text(p.name, overflow: TextOverflow.ellipsis),
            ),
          if (value == _own) DropdownMenuItem(value: _own, child: Text(l.chatPresetOwn)),
        ],
        onChanged: (v) {
          if (v == null || v == _own || v == value) return;
          onPick(v == _standard ? '' : presets.firstWhere((p) => p.name == v).text);
        },
      ),
    );
  }
}

/// Asks the name to save a preset under ([initial] filled in); null: not
/// saved.
Future<String?> askPresetName(BuildContext context, {String initial = ''}) async {
  final l = context.l10n;
  final name = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.chatPresetSave),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: name,
          autofocus: true,
          decoration: InputDecoration(labelText: l.chatPresetName, helperText: l.chatPresetNameHelp),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, name.text), child: Text(l.save)),
      ],
    ),
  );
  name.dispose();
  final trimmed = result?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

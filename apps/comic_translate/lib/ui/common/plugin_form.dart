/// Settings form of a plugin, generated from its schema. Secrets go to the
/// OS secure storage and are never shown again.
library;

import 'dart:async';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import 'info_hint.dart';
import 'labels.dart';
import 'plugin_strings.dart';

class PluginSettingsForm extends ConsumerWidget {
  const PluginSettingsForm(this.info, {super.key});

  final PluginInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(settingsProvider.select((s) => s.pluginValues(info.id)));
    final config = PluginConfig.resolve(info.settings, values);
    void set(String key, Object? value) => ref
        .read(settingsProvider.notifier)
        .change((s) => s.plugins[info.id] = {...s.pluginValues(info.id), key: value});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in info.settings)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: switch (field) {
              SecretSetting() => _SecretField(info, field),
              BoolSetting() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: titleWithInfo(fieldLabel(context, info, field), fieldInfo(context, info, field)),
                subtitle: _help(context, field),
                value: config.value<bool>(field.key),
                onChanged: (v) => set(field.key, v),
              ),
              ChoiceSetting(:final options) => withInfo(
                DropdownButtonFormField<String>(
                  initialValue: config.value<String>(field.key),
                  decoration: InputDecoration(
                    labelText: fieldLabel(context, info, field),
                    helperText: _helpText(context, field),
                  ),
                  items: [
                    for (final e in options.entries)
                      DropdownMenuItem(value: e.key, child: Text(optionLabel(context, info, field, e.key, e.value))),
                  ],
                  onChanged: (v) => set(field.key, v),
                ),
                fieldInfo(context, info, field),
              ),
              TextSetting(:final placeholder, :final multiline) => withInfo(
                DebouncedTextField(
                  key: ValueKey('${info.id}.${field.key}'),
                  value: config.value<String>(field.key),
                  label: fieldLabel(context, info, field),
                  help: _helpText(context, field),
                  hint: placeholder,
                  multiline: multiline,
                  onChanged: (v) => set(field.key, v),
                ),
                fieldInfo(context, info, field),
              ),
              IntSetting() || DoubleSetting() => withInfo(
                DebouncedTextField(
                  key: ValueKey('${info.id}.${field.key}'),
                  value: '${config.values[field.key]}',
                  label: fieldLabel(context, info, field),
                  help: _helpText(context, field),
                  numeric: true,
                  onChanged: (v) {
                    final parsed = num.tryParse(v.replaceAll(',', '.'));
                    if (parsed != null) set(field.key, field.coerce(parsed));
                  },
                ),
                fieldInfo(context, info, field),
              ),
            },
          ),
      ],
    );
  }

  String? _helpText(BuildContext context, SettingField field) {
    final h = fieldHelp(context, info, field);
    return h.isEmpty ? null : h;
  }

  Widget? _help(BuildContext context, SettingField field) {
    final h = _helpText(context, field);
    return h == null ? null : Text(h);
  }
}

/// A text field that saves shortly after typing stops (and when it loses
/// focus), without moving the cursor on rebuilds.
class DebouncedTextField extends StatefulWidget {
  const DebouncedTextField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.help,
    this.hint,
    this.multiline = false,
    this.numeric = false,
  });

  final String value;
  final String label;
  final String? help;
  final String? hint;
  final bool multiline;
  final bool numeric;
  final ValueChanged<String> onChanged;

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _flush();
    });
  }

  @override
  void didUpdateWidget(DebouncedTextField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _controller.text) _controller.text = widget.value;
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (_controller.text != widget.value) widget.onChanged(_controller.text);
  }

  @override
  void dispose() {
    _flush();
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    minLines: widget.multiline ? 2 : 1,
    maxLines: widget.multiline ? 5 : 1,
    keyboardType: widget.numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
    inputFormatters: widget.numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))] : null,
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.help,
      helperMaxLines: 3,
      hintText: widget.hint,
    ),
    onChanged: (_) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 700), _flush);
    },
    onSubmitted: (_) => _flush(),
  );
}

/// The last 4 characters of a saved key, to tell keys apart; nothing for
/// short values, where 4 characters would give away too much.
String secretTail(String? value) => value == null || value.length < 12 ? '' : value.substring(value.length - 4);

/// A secret (API key): shows whether it is saved and its last 4 characters.
/// What the user types can be shown before saving; the saved key is shown
/// or copied only on request (and hidden again after a while). It never goes
/// into logs or bug reports.
class _SecretField extends ConsumerStatefulWidget {
  const _SecretField(this.info, this.field);

  final PluginInfo info;
  final SecretSetting field;

  @override
  ConsumerState<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends ConsumerState<_SecretField> {
  final _controller = TextEditingController();
  bool? _saved;
  String _tail = '';
  bool _show = false;

  /// The saved key, while shown.
  String? _revealed;
  Timer? _hide;

  String get _key => pluginSecretKey(widget.info.id, widget.field.key);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final value = await ref.read(servicesProvider).secrets.read(_key);
    if (!mounted) return;
    setState(() {
      _saved = value != null && value.isNotEmpty;
      _tail = secretTail(value);
    });
  }

  /// Saving over a saved key replaces it.
  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    await ref.read(servicesProvider).secrets.write(_key, value);
    _controller.clear();
    _show = false;
    _conceal();
    await _refresh();
  }

  Future<void> _remove() async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.secretRemoveTitle),
        content: Text(l.secretRemoveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await ref.read(servicesProvider).secrets.delete(_key);
    _conceal();
    await _refresh();
  }

  void _conceal() {
    _hide?.cancel();
    if (mounted) setState(() => _revealed = null);
  }

  Future<void> _reveal() async {
    if (_revealed != null) return _conceal();
    final value = await ref.read(servicesProvider).secrets.read(_key);
    if (!mounted || value == null) return;
    setState(() => _revealed = value);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 30), _conceal);
  }

  Future<void> _copy() async {
    final value = await ref.read(servicesProvider).secrets.read(_key);
    if (value == null) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.secretCopied)));
  }

  @override
  void dispose() {
    _hide?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final help = fieldHelp(context, widget.info, widget.field);
    final saved = _saved ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                obscureText: !_show,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: [
                    fieldLabel(context, widget.info, widget.field),
                    if (_saved != null)
                      saved ? (_tail.isEmpty ? l.secretSet : l.secretSavedTail(_tail)) : l.secretNotSet,
                  ].join(' · '),
                  hintText: saved ? l.secretReplaceHint : null,
                  helperText: [if (help.isNotEmpty) help, l.savedSecurely].join(' '),
                  helperMaxLines: 4,
                  suffixIcon: IconButton(
                    tooltip: _show ? l.secretHide : l.secretShow,
                    icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.tonal(onPressed: _save, child: Text(saved ? l.secretReplace : l.save)),
            ),
            if (saved)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: TextButton(onPressed: _remove, child: Text(l.secretRemove)),
              ),
          ],
        ),
        if (saved)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: _reveal,
                icon: Icon(_revealed == null ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                label: Text(_revealed == null ? l.secretShowSaved : l.secretHideSaved),
              ),
              TextButton.icon(onPressed: _copy, icon: const Icon(Icons.copy, size: 18), label: Text(l.secretCopy)),
              if (_revealed != null) SelectableText(_revealed!, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
      ],
    );
  }
}

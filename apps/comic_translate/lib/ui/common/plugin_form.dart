/// Settings form of a plugin, generated from its schema. Secrets go to the
/// OS secure storage and are never shown again.
library;

import 'dart:async';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../settings/own_server_key_field.dart';
import 'info_hint.dart';
import 'labels.dart';
import 'model_catalog_dialog.dart';
import 'plugin_secret_field.dart';
import 'plugin_strings.dart';

class PluginSettingsForm extends ConsumerWidget {
  const PluginSettingsForm(this.info, {super.key, this.hiddenFields = const {}, this.ownServerStorageId});

  final PluginInfo info;
  final Set<String> hiddenFields;
  final String? ownServerStorageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageId = ref.watch(settingsProvider.select((s) => ownServerStorageId ?? s.pluginStorageId(info.id)));
    final values = ref.watch(
      settingsProvider.select(
        (s) => ownServerStorageId == null ? s.pluginValues(info.id) : s.pluginValuesForStorage(storageId),
      ),
    );
    final config = PluginConfig.resolve(info.settings, values);
    final notifier = ref.read(settingsProvider.notifier);
    void set(String key, Object? value) =>
        notifier.change((s) => s.plugins[storageId] = {...?s.plugins[storageId], key: value});
    Widget row(SettingField field) =>
        Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(context, ref, config, field, set, storageId));
    final advanced = [
      for (final field in info.settings)
        if (field.advanced && !hiddenFields.contains(field.key)) field,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in info.settings)
          if (!field.advanced && !hiddenFields.contains(field.key)) row(field),
        // Rarely changed: folded.
        if (advanced.isNotEmpty)
          ExpansionTile(
            key: ValueKey('${info.id}.more'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(context.l10n.pluginMoreSettings),
            children: [for (final field in advanced) row(field)],
          ),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    WidgetRef ref,
    PluginConfig config,
    SettingField field,
    void Function(String key, Object? value) set,
    String storageId,
  ) => switch (field) {
    SecretSetting() when info.id == 'openai_compatible' && field.key == 'api_key' => OwnServerKeyField(
      info,
      field,
      storageId,
    ),
    SecretSetting() => PluginSecretField(info, field, field.storeKey(storageId)),
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
        decoration: InputDecoration(labelText: fieldLabel(context, info, field), helperText: _helpText(context, field)),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: Text(optionLabel(context, info, field, e.key, e.value))),
        ],
        onChanged: (v) => set(field.key, v),
      ),
      fieldInfo(context, info, field),
    ),
    TextSetting(:final placeholder, :final multiline) => _withCatalog(
      context,
      ref,
      config,
      field,
      withInfo(
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
      (id) => set(field.key, id),
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
  };

  /// The model field of a service with a list of models: "Choose…" beside it.
  Widget _withCatalog(
    BuildContext context,
    WidgetRef ref,
    PluginConfig config,
    SettingField field,
    Widget child,
    ValueChanged<String> pick,
  ) {
    final custom = const {'openai_compatible', 'openai_compatible_ocr'}.contains(info.id);
    final query = info.modelCatalog?.call(config);
    if (custom ? field.key != 'model' : query?.settingKey != field.key) return child;
    final l = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Tooltip(
            message: query == null
                ? l.ownServerModelsNeedUrl
                : query.usesProfileCredentials
                ? l.ownServerModelsHelp(query.host)
                : l.modelsChooseHelp(query.host),
            child: OutlinedButton.icon(
              onPressed: () async {
                FocusScope.of(context).unfocus();
                final settings = ref.read(settingsProvider);
                final storageId = settings.pluginStorageId(info.id);
                final current = PluginConfig.resolve(info.settings, settings.pluginValues(info.id));
                final preview = info.modelCatalog?.call(current);
                if (preview == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.ownServerModelsNeedUrl)));
                  return;
                }
                var catalog = preview;
                if (preview.usesProfileCredentials) {
                  final services = ref.read(servicesProvider);
                  final PluginConfig resolved;
                  try {
                    resolved = await services.pluginConfig(info.id, settings);
                  } catch (e, stack) {
                    services.appLog.error('model_catalog_config_failed', e, stack);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.trErrOther)));
                    }
                    return;
                  }
                  if (!context.mounted ||
                      ModalRoute.of(context)?.isCurrent != true ||
                      ref.read(settingsProvider).pluginStorageId(info.id) != storageId) {
                    return;
                  }
                  catalog = info.modelCatalog!.call(resolved)!;
                  if (resolved.secret('api_key') != null && info.endpointFor(resolved) != null) {
                    final allowed = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        title: Text(l.ownServerLoadModels),
                        content: Text(l.ownServerModelsConsent(catalog.host)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l.cancel)),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: Text(l.ownServerLoadModels),
                          ),
                        ],
                      ),
                    );
                    if (allowed != true || !context.mounted) return;
                  }
                }
                final id = await showModelCatalogDialog(
                  context,
                  catalog,
                  current: current.value<String>(field.key),
                  vision: !custom && settings.sendPageImage,
                );
                if (id != null && context.mounted && ref.read(settingsProvider).pluginStorageId(info.id) == storageId) {
                  pick(id);
                }
              },
              icon: const Icon(Icons.list_alt),
              label: Text(custom ? l.ownServerLoadModels : l.modelsChoose),
            ),
          ),
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

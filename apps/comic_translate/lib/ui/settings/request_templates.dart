import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../common/labels.dart';
import 'http_request_dialog.dart';

String _normalized(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Selects a shared template for a single connection. Editing a template
/// applies to every connection using its ID.
class RequestTemplates extends ConsumerWidget {
  const RequestTemplates({super.key, required this.storageId, this.forOcr = false});

  final String storageId;
  final bool forOcr;

  Future<void> _edit(BuildContext context, WidgetRef ref, {String? id, RequestTemplate? template}) async {
    final notifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);
    final settings = forOcr
        ? (AppSettings.fromJson(current.toJson())..ownServerProfile = current.ownServerOcrProfile ?? '')
        : current;
    final taken = {
      for (final entry in settings.requestTemplates.entries)
        if (entry.key != id) _normalized(entry.value.name),
    };
    final edited = await showDialog<RequestTemplate>(
      context: context,
      builder: (_) => _EditTemplate(
        template: template,
        taken: taken,
        settings: settings,
        storageId: storageId,
        model: forOcr ? current.pluginValues('openai_compatible_ocr')['model'] as String? ?? '' : null,
      ),
    );
    if (edited == null || !context.mounted) return;
    await notifier.change((s) {
      final key = id ?? DateTime.now().microsecondsSinceEpoch.toString();
      s.requestTemplates[key] = edited;
      if (id == null) _select(s, key);
    });
  }

  void _select(AppSettings s, String id) {
    final values = {...?s.plugins[storageId]};
    if (id.isEmpty) {
      values.remove(RequestTemplate.selectionKey);
    } else {
      values[RequestTemplate.selectionKey] = id;
    }
    s.plugins[storageId] = values;
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id, String name) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.requestTemplateDelete),
        content: Text(l.requestTemplateDeleteHelp(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l.delete)),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await ref.read(settingsProvider.notifier).change((s) => s.removeRequestTemplate(id));
    }
  }

  static const _jsonFiles = XTypeGroup(label: 'JSON', extensions: ['json']);

  RequestTemplate _portable(String source, Redactor redactor) {
    if (redactor.containsKnownSecret(source)) {
      throw const FormatException('Credentials');
    }
    final raw = jsonDecode(source);
    final template = RequestTemplate.fromJson(raw);
    if (raw is! Map || template == null || template.name.characters.length > 100) {
      throw const FormatException('Template');
    }
    final encoded = template.toJson();
    if (raw.keys.any((key) => !encoded.containsKey(key)) ||
        (raw['http'] is Map && (raw['http'] as Map).length != template.http.length)) {
      throw const FormatException('Unexpected template fields');
    }
    for (final path in [template.chatPath, template.modelsPath, template.keyStatusPath]) {
      if (path.isNotEmpty) {
        EditableHttpRequest.parse(HttpOperation.chat, HttpRequestSpec('GET $path', '{"text":"content"}'));
      }
    }
    final fields = RequestTemplate.parseKeyStatusFields(jsonEncode(template.keyStatusFields));
    if (fields == null || template.keyStatusPath.isEmpty != fields.isEmpty) {
      throw const FormatException('Key status');
    }
    for (final entry in template.http.entries) {
      EditableHttpRequest.parse(entry.key, entry.value);
    }
    return template;
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref, {RequestTemplate? template}) async {
    final l = context.l10n;
    final notifier = ref.read(settingsProvider.notifier);
    final services = ref.read(servicesProvider);
    void notice(String message) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    try {
      if (template != null) {
        final source = const JsonEncoder.withIndent('  ').convert(template.toJson());
        _portable(source, services.redactor);
        final location = await getSaveLocation(suggestedName: 'http-template.json', acceptedTypeGroups: [_jsonFiles]);
        if (location == null) return;
        await File(location.path).writeAsString(source);
        return;
      }
      final file = await openFile(acceptedTypeGroups: [_jsonFiles]);
      if (file == null || !context.mounted) return;
      if (await file.length() > 1024 * 1024) throw const FormatException('Template too large');
      final imported = _portable(await file.readAsString(), services.redactor);
      if (!context.mounted) return;
      var added = false;
      await notifier.change((s) {
        if (s.requestTemplates.values.any((item) => _normalized(item.name) == _normalized(imported.name))) return;
        final id = DateTime.now().microsecondsSinceEpoch.toString();
        s.requestTemplates[id] = imported;
        _select(s, id);
        added = true;
      });
      notice(added ? l.requestTemplateImported : l.requestTemplateNameTaken);
    } on Exception {
      notice(l.requestTemplateTransferError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final templates = s.requestTemplates;
    final selected = s.plugins[storageId]?[RequestTemplate.selectionKey];
    final id = selected is String && templates.containsKey(selected) ? selected : '';
    final template = templates[id];
    final items = templates.entries.toList()
      ..sort((a, b) => _normalized(a.value.name).compareTo(_normalized(b.value.name)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey((storageId, id)),
                  initialValue: id,
                  isExpanded: true,
                  menuMaxHeight: 340,
                  decoration: InputDecoration(labelText: l.requestTemplate),
                  items: [
                    DropdownMenuItem(value: '', child: Text(l.requestTemplateNone)),
                    for (final entry in items)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) ref.read(settingsProvider.notifier).change((s) => _select(s, value));
                  },
                ),
              ),
              IconButton(
                tooltip: l.requestTemplateAdd,
                icon: const Icon(Icons.add),
                onPressed: () => _edit(context, ref),
              ),
              IconButton(
                tooltip: l.requestTemplateEdit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: template == null ? null : () => _edit(context, ref, id: id, template: template),
              ),
              IconButton(
                tooltip: l.requestTemplateDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: template == null ? null : () => _delete(context, ref, id, template.name),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.requestTemplateHelp, style: Theme.of(context).textTheme.bodySmall),
          if (storageId == 'openrouter') Text(l.openRouterTemplateHelp),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _transfer(context, ref),
                icon: const Icon(Icons.file_open_outlined),
                label: Text(l.requestTemplateImport),
              ),
              TextButton.icon(
                onPressed: template == null ? null : () => _transfer(context, ref, template: template),
                icon: const Icon(Icons.file_download_outlined),
                label: Text(l.requestTemplateExport),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditTemplate extends StatefulWidget {
  const _EditTemplate({
    required this.template,
    required this.taken,
    required this.settings,
    required this.storageId,
    required this.model,
  });

  final RequestTemplate? template;
  final Set<String> taken;
  final AppSettings settings;
  final String storageId;
  final String? model;

  @override
  State<_EditTemplate> createState() => _EditTemplateState();
}

class _EditTemplateState extends State<_EditTemplate> {
  late final _name = TextEditingController(text: widget.template?.name);
  late final _chat = TextEditingController(text: widget.template?.chatPath);
  late final _models = TextEditingController(text: widget.template?.modelsPath);
  late final _options = TextEditingController(text: widget.template?.requestOptions);
  late final _status = TextEditingController(text: widget.template?.keyStatusPath);
  late final _fields = TextEditingController(
    text: widget.template == null || widget.template!.keyStatusFields.isEmpty
        ? ''
        : const JsonEncoder.withIndent('  ').convert(widget.template!.keyStatusFields),
  );
  String? _error;
  late final _http = <HttpOperation, HttpRequestSpec>{...?widget.template?.http};

  Map<String, Object?> get _profile => widget.settings.plugins[widget.storageId] ?? const {};
  String get _effectiveOptions {
    final options = _options.text.trim();
    return options.isEmpty ? _profile['request_options'] as String? ?? '' : options;
  }

  HttpRequestSpec _draft(HttpOperation operation) {
    String path(String current, String key, String fallback) =>
        [current, _profile[key] as String? ?? '', fallback].map((v) => v.trim()).firstWhere((v) => v.isNotEmpty);
    const indent = JsonEncoder.withIndent('  ');
    const auth = 'Authorization: Bearer {{api_key}}';
    switch (operation) {
      case HttpOperation.chat:
        final limit = _profile['token_limit_param'] as String? ?? 'max_completion_tokens';
        final fields = {
          'model': '{{model}}',
          'messages': '{{messages}}',
          'temperature': '{{temperature}}',
          if (const {'max_completion_tokens', 'max_tokens'}.contains(limit)) limit: '{{token_limit}}',
        };
        try {
          if (_effectiveOptions.trim().isNotEmpty) {
            for (final entry in RequestTemplate.parseRequestOptions(_effectiveOptions).entries) {
              if (entry.value == null) {
                fields.remove(entry.key);
              } else {
                fields[entry.key] = jsonEncode(entry.value);
              }
            }
          }
        } on FormatException {
          // The original parameters can still be fixed in the parent dialog.
        }
        final body = fields.entries.map((e) => '  ${jsonEncode(e.key)}: ${e.value}').join(',\n');
        return HttpRequestSpec(
          'POST ${path(_chat.text, 'chat_path', 'chat/completions')}\n$auth\nContent-Type: application/json\n\n{\n$body\n}',
          indent.convert({
            'text': 'choices[0].message.content',
            'finish': 'choices[0].finish_reason',
            'usage': 'usage',
          }),
        );
      case HttpOperation.models:
        return HttpRequestSpec(
          'GET ${path(_models.text, 'models_path', 'models')}\n$auth',
          indent.convert({
            'items': 'data',
            'id': 'id',
            'name': 'name',
            if (widget.storageId == 'openrouter') ...openRouterModelResponsePaths,
          }),
        );
      case HttpOperation.keyStatus:
        final fields = RequestTemplate.parseKeyStatusFields(_fields.text) ?? const <String, String>{};
        return HttpRequestSpec(
          'GET ${path(_status.text, 'key_status_path', widget.storageId == 'openrouter' ? 'key' : 'usage/key')}\n$auth',
          indent.convert({
            'fields': fields.isEmpty
                ? {
                    context.l10n.httpEditorBalance: widget.storageId == 'openrouter'
                        ? 'data.limit_remaining'
                        : 'data.balance',
                  }
                : fields,
          }),
        );
    }
  }

  Future<void> _openHttp(HttpOperation operation) async {
    final existing = _http[operation];
    final edited = await showDialog<({HttpRequestSpec spec, bool enabled})>(
      context: context,
      builder: (_) => HttpRequestDialog(
        operation: operation,
        spec: existing ?? _draft(operation),
        enabled: existing != null,
        settings: widget.settings,
        model: widget.model,
        pluginId: widget.storageId == 'openrouter' ? 'openrouter' : 'openai_compatible',
      ),
    );
    if (edited == null || !mounted) return;
    setState(() {
      if (edited.enabled) {
        _http[operation] = edited.spec;
      } else {
        _http.remove(operation);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in [_name, _chat, _models, _options, _status, _fields]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final l = context.l10n;
    final name = _name.text.trim();
    final chat = _chat.text.trim();
    final models = _models.text.trim();
    final options = _options.text.trim();
    final status = _status.text.trim();
    final fieldsText = _fields.text.trim();
    void invalid(String error) => setState(() => _error = error);

    if (name.isEmpty) return invalid(l.requestTemplateNameRequired);
    if (widget.taken.contains(_normalized(name))) return invalid(l.requestTemplateNameTaken);
    if ([
      chat,
      models,
      status,
    ].any((path) => path.isNotEmpty && openAiCompatibleUri('http://localhost', path, path) == null)) {
      return invalid(l.requestTemplatePathError);
    }
    final Map<String, Object?> parsed;
    try {
      parsed = options.isEmpty ? const {} : RequestTemplate.parseRequestOptions(options);
    } on FormatException {
      return invalid(l.requestTemplateOptionsError);
    }
    if (RequestTemplate.containsCredentials([name, chat, models, status, parsed, fieldsText])) {
      return invalid(l.requestTemplateCredentialsError);
    }
    final fields = fieldsText.isEmpty ? const <String, String>{} : RequestTemplate.parseKeyStatusFields(fieldsText);
    if (fields == null || status.isEmpty != fields.isEmpty) return invalid(l.requestTemplateStatusError);
    Navigator.pop(
      context,
      RequestTemplate(
        name: name,
        chatPath: chat,
        modelsPath: models,
        requestOptions: options,
        keyStatusPath: status,
        keyStatusFields: fields,
        http: _http,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget field(TextEditingController controller, String label, {String? hint, String? help, int lines = 1}) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines == 1 ? 1 : 5,
            decoration: InputDecoration(labelText: label, hintText: hint, helperText: help, helperMaxLines: 3),
          ),
        );
    return AlertDialog(
      scrollable: true,
      title: Text(widget.template == null ? l.requestTemplateAdd : l.requestTemplateEdit),
      content: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.requestTemplateEditorHelp),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 100,
              decoration: InputDecoration(labelText: l.requestTemplateName),
            ),
            Text(l.httpEditorOperations),
            Wrap(
              spacing: 8,
              children: [
                for (final operation in HttpOperation.values)
                  OutlinedButton.icon(
                    onPressed: () => _openHttp(operation),
                    icon: Icon(_http.containsKey(operation) ? Icons.check : Icons.code),
                    label: Text(httpOperationLabel(context, operation)),
                  ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l.httpEditorLegacy),
              children: [
                field(_chat, l.requestTemplateChatPath, hint: 'chat/completions'),
                field(_models, l.requestTemplateModelsPath, hint: 'models'),
                field(_options, l.requestTemplateOptions, hint: '{"top_p": 0.9}', lines: 2),
                field(_status, l.requestTemplateStatusPath, hint: 'usage/key', help: l.requestTemplateStatusPathHelp),
                field(_fields, l.requestTemplateStatusFields, hint: '{"Balance": "data.balance"}', lines: 2),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (_error case final error?) Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

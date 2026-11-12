import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../common/labels.dart';

String httpOperationLabel(BuildContext context, HttpOperation operation) => switch (operation) {
  HttpOperation.chat => context.l10n.httpEditorChat,
  HttpOperation.models => context.l10n.httpEditorModels,
  HttpOperation.keyStatus => context.l10n.keyStatusCheck,
};

class HttpRequestDialog extends ConsumerStatefulWidget {
  const HttpRequestDialog({
    super.key,
    required this.operation,
    required this.spec,
    required this.enabled,
    required this.settings,
    this.model,
    this.pluginId = 'openai_compatible',
  });

  final HttpOperation operation;
  final HttpRequestSpec spec;
  final bool enabled;
  final AppSettings settings;
  final String? model;
  final String pluginId;

  @override
  ConsumerState<HttpRequestDialog> createState() => _HttpRequestDialogState();
}

class _HttpRequestDialogState extends ConsumerState<HttpRequestDialog> {
  late final _request = TextEditingController(text: widget.spec.request);
  late final _response = TextEditingController(text: widget.spec.response);
  TextEditingController? _message;
  CancelToken? _pending;
  HttpTemplateFile? _file;
  String? _error;

  HttpRequestSpec get _spec => HttpRequestSpec(_request.text.trim(), _response.text.trim());

  EditableHttpRequest _parse() =>
      EditableHttpRequest.parse(widget.operation, _spec, openRouterModelDefaults: widget.pluginId == 'openrouter');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.operation == HttpOperation.chat) {
      _message ??= TextEditingController(text: context.l10n.httpEditorSampleMessage);
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    _request.dispose();
    _response.dispose();
    _message?.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final l = context.l10n;
    try {
      final file = await openFile();
      if (file == null || !mounted) return;
      if (await file.length() > 10 * 1024 * 1024) {
        if (mounted) setState(() => _error = l.httpEditorFileTooLarge);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _file = HttpTemplateFile(file.name, bytes);
        _error = null;
      });
    } on Exception {
      if (mounted) setState(() => _error = l.trErrOther);
    }
  }

  void _apply() {
    try {
      _parse();
      Navigator.pop(context, (spec: _spec, enabled: true));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Map<String, Object?> _payload(PluginConfig config) {
    if (widget.operation != HttpOperation.chat) return const {};
    final model = (widget.model ?? config.value<String>('model')).trim();
    final limit = config.values['token_limit_param'] as String? ?? 'max_completion_tokens';
    return {
      if (model.isNotEmpty) 'model': model,
      'messages': [
        {'role': 'user', 'content': _message!.text},
      ],
      'temperature': config.value<double>('temperature'),
      if (limit != 'none') limit: config.value<int>('max_tokens'),
    };
  }

  Future<void> _run({required bool send}) async {
    final l = context.l10n;
    final services = ref.read(servicesProvider);
    final cancel = CancelToken();
    setState(() {
      _error = null;
      _pending = cancel;
    });
    try {
      final operation = _parse();
      final config = await services.pluginConfig(widget.pluginId, widget.settings);
      if (!mounted) return;
      final key = config.secret('api_key') ?? '';
      final base = widget.pluginId == 'openrouter' ? openRouterApiUrl : openAiCompatibleUrl(config);
      final file = _file;
      if (file != null && !operation.acceptsFiles) {
        setState(() => _error = l.httpEditorFileNeedsTemplate);
        return;
      }
      final request = operation.prepare(base, key, _payload(config), files: file == null ? null : [file]);
      final preview = services.redactor.redact(request.preview);
      if (!send) {
        await _showResult(l.httpEditorPreview, preview);
        return;
      }
      final allowed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l.httpEditorSend),
          content: Text(
            [
              l.httpEditorConfirm(services.redactor.redact('${request.method} ${request.uri}')),
              if (file != null) l.httpEditorFileConfirm(file.name),
            ].join('\n\n'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l.httpEditorSend)),
          ],
        ),
      );
      if (allowed != true || !mounted) return;
      final exchange = await request.send(
        timeout: Duration(seconds: config.value<int>('timeout')),
        cancel: cancel,
      );
      if (!mounted) return;
      final extract = _extract(operation, exchange, key);
      final body = services.redactor.redact(redactHttpText(exchange.body, key));
      final output = [
        preview,
        'HTTP ${exchange.status}',
        body.length > 24000 ? '${body.substring(0, 24000)}\n…' : body,
        l.httpEditorExtracted,
        services.redactor.redact(extract),
      ].join('\n\n');
      await _showResult(l.httpEditorResult, output);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = services.redactor.redact(error.message));
    } on TranslationException catch (error) {
      if (mounted) setState(() => _error = services.redactor.redact(error.message));
    } on CancelledException {
      // Closing the editor cancels the test request.
    } catch (_) {
      if (mounted) setState(() => _error = l.trErrOther);
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  String _extract(EditableHttpRequest operation, HttpExchange exchange, String key) {
    final l = context.l10n;
    String extract;
    try {
      final value = operation.decode(exchange, key);
      extract = switch (value) {
        (final String text, _, _) => text,
        List<CatalogModel>() =>
          value.map((item) => item.name.isEmpty ? item.id : '${item.id} · ${item.name}').join('\n'),
        KeyStatus() => value.fields!.entries.map((item) => '${item.key} · ${item.value}').join('\n'),
        _ => '',
      };
    } on TranslationException catch (error) {
      extract = '${translationErrorLabel(l, error.kind)} · ${error.message}';
    }
    return redactHttpText(extract, key);
  }

  Future<void> _checkSample() async {
    final l = context.l10n;
    final form = GlobalKey<FormState>();
    var body = '';
    var status = 200;
    final sample = await showDialog<HttpExchange>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(_isSse ? l.httpEditorCheckResponse : l.httpEditorOffline),
        content: SizedBox(
          width: 620,
          child: Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  initialValue: '200',
                  decoration: InputDecoration(labelText: l.httpEditorStatus),
                  validator: (value) {
                    final code = int.tryParse(value ?? '');
                    if (code == null || code < 100 || code > 599) return l.httpEditorStatusError;
                    return null;
                  },
                  onSaved: (value) => status = int.parse(value!),
                ),
                TextFormField(
                  minLines: 6,
                  maxLines: 10,
                  decoration: InputDecoration(labelText: _isSse ? l.httpEditorSampleSse : l.httpEditorSampleJson),
                  onChanged: (value) => body = value,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              form.currentState!.save();
              Navigator.pop(dialog, HttpExchange(status, body));
            },
            child: Text(l.checkSample),
          ),
        ],
      ),
    );
    if (sample == null || !mounted) return;
    final services = ref.read(servicesProvider);
    try {
      final operation = _parse();
      final config = await services.pluginConfig(widget.pluginId, widget.settings);
      if (!mounted) return;
      final result = _extract(operation, sample, config.secret('api_key') ?? '');
      await _showResult(l.httpEditorExtracted, services.redactor.redact(result));
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = services.redactor.redact(error.message));
    } on Exception {
      if (mounted) setState(() => _error = l.trErrOther);
    }
  }

  Future<void> _showResult(String title, String output) {
    final l = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 690,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(output, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: output)),
            child: Text(l.httpEditorCopy),
          ),
          FilledButton(onPressed: () => Navigator.pop(dialog), child: Text(l.close)),
        ],
      ),
    );
  }

  EditableHttpRequest? get _parsed {
    try {
      return _parse();
    } on FormatException {
      return null;
    }
  }

  bool get _isSse => _parsed?.streams ?? false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final busy = _pending != null;
    final parsed = _parsed;
    Widget editor(TextEditingController controller, String label, int lines) => TextField(
      controller: controller,
      readOnly: busy,
      onChanged: (_) => setState(() {}),
      minLines: lines,
      maxLines: lines,
      style: const TextStyle(fontFamily: 'monospace'),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
    return AlertDialog(
      scrollable: true,
      title: Text('HTTP · ${httpOperationLabel(context, widget.operation)}'),
      content: SizedBox(
        width: 690,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.httpEditorHelp),
            const SizedBox(height: 12),
            editor(_request, l.httpEditorRequest, 8),
            const SizedBox(height: 12),
            editor(_response, l.httpEditorResponse, 4),
            if (_message case final message?)
              TextField(
                controller: message,
                readOnly: busy,
                decoration: InputDecoration(labelText: l.httpEditorSampleLabel),
              ),
            const SizedBox(height: 8),
            Text(l.httpEditorTips, style: Theme.of(context).textTheme.bodySmall),
            Text(l.httpEditorFormatsHelp, style: Theme.of(context).textTheme.bodySmall),
            if (parsed?.acceptsFiles == true || _file != null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: busy || parsed?.acceptsFiles != true ? null : _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(l.httpEditorAttachFile),
                  ),
                  if (_file case final file?) ...[
                    Text(file.name),
                    IconButton(
                      tooltip: l.httpEditorRemoveFile,
                      onPressed: busy ? null : () => setState(() => _file = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
            if (busy) const LinearProgressIndicator(),
            if (_error case final error?)
              SelectableText(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        if (widget.enabled)
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, (spec: _spec, enabled: false)),
            child: Text(l.requestTemplateNone),
          ),
        TextButton(onPressed: busy ? null : () => _run(send: false), child: Text(l.httpEditorPreview)),
        TextButton(
          onPressed: busy ? null : _checkSample,
          child: Text(_isSse ? l.httpEditorCheckResponse : l.httpEditorOffline),
        ),
        OutlinedButton(onPressed: busy ? null : () => _run(send: true), child: Text(l.httpEditorSend)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: busy ? null : _apply, child: Text(l.httpEditorApply)),
      ],
    );
  }
}

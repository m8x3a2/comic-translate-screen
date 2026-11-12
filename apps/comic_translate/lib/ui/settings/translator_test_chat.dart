import 'dart:async';
import 'dart:ui' as ui;

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/chat_library.dart';
import '../../services/file_clipboard.dart';
import '../../state/app_state.dart';
import '../../state/batch.dart';
import '../common/labels.dart';
import '../shell_full/batch_dialogs.dart';

final _sendTestMessage = Provider((ref) {
  return (
    String id,
    List<Map<String, Object?>> messages,
    CancelToken cancel,
    BatchUi ui, {
    required bool confirm,
    AppSettings? connection,
    Future<void> Function()? beforeSend,
    Future<bool> Function(String)? confirmImage,
    required void Function(String) onRequest,
    required void Function(int, String) onResponse,
    required void Function(String) onText,
    List<HttpTemplateFile>? files,
  }) async {
    if (!await checkPluginKey(ref, ui, id, connection: connection)) return null;
    if (confirm && !await approvePluginNetwork(ref, ui, id, sendsImage: false, connection: connection)) return null;
    cancel.throwIfCancelled();
    final services = ref.read(servicesProvider);
    final translator = await services.plugin<Translator>(
      id,
      connection ?? ref.read<AppSettings>(settingsProvider),
    ) as OpenAiCompatibleTranslator;
    if (files != null && !translator.acceptsTemplateFiles) {
      throw TranslationException('The active template does not accept files', kind: TranslationErrorKind.config);
    }
    if (confirmImage != null) {
      final endpoint = Uri.tryParse(translator.apiUrl);
      if (endpoint != null && endpoint.host.isNotEmpty) {
        final destination = Uri(
          scheme: endpoint.scheme,
          host: endpoint.host,
          port: endpoint.hasPort ? endpoint.port : null,
        );
        if (!await confirmImage('$destination')) return null;
      }
    }
    cancel.throwIfCancelled();
    await beforeSend?.call();
    cancel.throwIfCancelled();
    return translator.testChat(
      messages,
      cancel,
      EventLog.silent(),
      onRequest: (request) => onRequest(services.redactor.redact(request)),
      onResponse: (status, body) => onResponse(status, services.redactor.redact(body)),
      onText: onText,
      files: files,
    );
  };
});

const _maxImageBytes = 10 * 1024 * 1024;
const _imageExtensions = ['png', 'jpg', 'jpeg', 'webp'];

String? _imageMime(Uint8List bytes) {
  bool starts(List<int> prefix, [int offset = 0]) =>
      bytes.length >= offset + prefix.length && prefix.indexed.every((item) => bytes[offset + item.$1] == item.$2);
  if (starts(const [137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
  if (starts(const [255, 216, 255])) return 'image/jpeg';
  if (starts(const [82, 73, 70, 70]) && starts(const [87, 69, 66, 80], 8)) return 'image/webp';
  return null;
}

Map<String, Object?> _wireTurn(ChatMessage turn, {required bool embedImages}) => {
  'role': turn.role,
  'content': embedImages && turn.attachments.isNotEmpty
      ? [
          if (turn.text.isNotEmpty) {'type': 'text', 'text': turn.text},
          for (final image in turn.attachments)
            {
              'type': 'image_url',
              'image_url': {'url': image.dataUrl},
            },
        ]
      : turn.text,
};

Future<void> showTranslatorTestChat(BuildContext context, PluginInfo info, String host, String model) =>
    showDialog<void>(
      context: context,
      builder: (_) => ChatConversation(pluginId: info.id, host: host, model: model),
    );

class ChatConversation extends ConsumerStatefulWidget {
  const ChatConversation({
    super.key,
    required this.pluginId,
    required this.host,
    required this.model,
    this.thread,
    this.connection,
    this.append,
    this.connectionAvailable = true,
  });

  final String pluginId;
  final String host;
  final String model;
  final ChatThread? thread;
  final AppSettings? connection;
  final Future<void> Function(ChatMessage)? append;
  final bool connectionAvailable;

  @override
  ConsumerState<ChatConversation> createState() => _TestChatState();
}

class _TestChatState extends ConsumerState<ChatConversation> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _testMessages = <ChatMessage>[];
  List<ChatMessage> get _messages => widget.thread?.messages ?? _testMessages;
  String _query = '';
  final _attachments = <ChatImage>[];
  bool _includePastAttachments = false;
  String _partial = '';
  bool _scrollQueued = false;
  CancelToken? _pending;
  bool _attaching = false;
  String? _error;
  String? _request;
  String? _response;
  String? _detail;
  int? _status;

  bool get _busy => _pending != null || _attaching;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_paste);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_paste);
    _pending?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _acceptsFiles(AppSettings settings) {
    final registry = ref.read(servicesProvider).registry;
    if (!registry.contains(widget.pluginId)) return false;
    final info = registry.info(widget.pluginId);
    final config = PluginConfig.resolve(info.settings, settings.pluginValues(info.id));
    try {
      final spec = httpRequestSpec(config, HttpOperation.chat);
      return spec != null && EditableHttpRequest.parse(HttpOperation.chat, spec).acceptsFiles;
    } on FormatException {
      return false;
    }
  }

  void _scrollToEnd() {
    if (_scrollQueued) return;
    _scrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQueued = false;
      if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _attach(Stream<({Uint8List bytes, String name})> Function() select, {bool allowFiles = false}) async {
    if (_busy) return;
    final l = context.l10n;
    setState(() {
      _attaching = true;
      _error = null;
    });
    try {
      final files = <ChatImage>[];
      await for (final file in select()) {
        if (!mounted) return;
        final mime = _imageMime(file.bytes);
        if (file.bytes.length > _maxImageBytes) throw const _ImageTooLarge();
        if (mime == null && !allowFiles) throw const FormatException();
        if (mime != null) await _checkImageSize(file.bytes);
        files.add(ChatImage(file.bytes, mime ?? 'application/octet-stream', file.name));
      }
      if (mounted) setState(() => _attachments.addAll(files));
    } on _ImageTooLarge {
      if (mounted) setState(() => _error = allowFiles ? l.httpEditorFileTooLarge : l.translatorTestImageTooLarge);
    } catch (_) {
      if (mounted) setState(() => _error = l.translatorTestInvalidImage);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _checkImageSize(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > 24000000) throw const _ImageTooLarge();
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  Future<({Uint8List bytes, String name})> _readFile(XFile file) async {
    if (await file.length() > _maxImageBytes) throw const _ImageTooLarge();
    return (bytes: await file.readAsBytes(), name: file.name);
  }

  Future<void> _pickAttachment(bool allowFiles) => _attach(() async* {
    final files = await openFiles(
      acceptedTypeGroups: allowFiles ? const [] : const [XTypeGroup(extensions: _imageExtensions)],
    );
    for (final file in files) {
      yield await _readFile(file);
    }
  }, allowFiles: allowFiles);

  bool _paste(KeyEvent event) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.keyV && event.physicalKey != PhysicalKeyboardKey.keyV) ||
        !HardwareKeyboard.instance.isControlPressed ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _busy) {
      return false;
    }
    switch (readClipboardPages()) {
      case final ClipboardPicture picture:
        final name = context.l10n.translatorTestPastedImage;
        unawaited(
          _attach(() async* {
            yield (bytes: await compute(pictureToPng, picture), name: name);
          }),
        );
        return true;
      case ClipboardFiles(:final paths):
        final images = paths.where((path) => _imageExtensions.contains(path.split('.').last.toLowerCase())).toList();
        if (images.isEmpty) return false;
        unawaited(
          _attach(() async* {
            for (final path in images) {
              yield await _readFile(XFile(path));
            }
          }),
        );
        return true;
      case null:
        break;
    }
    return false;
  }

  Future<bool> _confirmAttachment(String destination, {required bool files, required bool includesHistory}) async {
    if (!mounted) return false;
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(files ? l.translatorTestFileConfirm : l.translatorTestImageConfirm),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(files ? l.translatorTestFileNetwork(destination) : l.translatorTestImageNetwork(destination)),
                if (includesHistory) Text(l.chatResendAttachmentsNotice),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.translatorTestSend)),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _send({bool continueReply = false}) async {
    if (_busy || !widget.connectionAvailable) return;
    final priorMessages = _messages;
    if (continueReply && priorMessages.lastOrNull?.incomplete != true) return;
    final newAttachments = continueReply ? const <ChatImage>[] : List<ChatImage>.of(_attachments);
    final typed = continueReply ? context.l10n.chatContinuePrompt : _text.text.trim();
    if (typed.isEmpty && newAttachments.isEmpty) return;
    final allowFiles = _acceptsFiles(widget.connection ?? ref.read<AppSettings>(settingsProvider));
    final history = [
      for (final (index, turn) in priorMessages.indexed)
        if (!turn.incomplete || (continueReply && index == priorMessages.length - 1))
          (
            role: turn.role,
            text: turn.text,
            attachments: _includePastAttachments ? turn.attachments : const <ChatImage>[],
            incomplete: turn.incomplete,
          ),
    ];
    final includesPastAttachments = history.any((turn) => turn.attachments.isNotEmpty);
    final attachments = [for (final turn in history) ...turn.attachments, ...newAttachments];
    if (!allowFiles && attachments.any((item) => !item.isImage)) {
      setState(() => _error = context.l10n.httpEditorFileNeedsTemplate);
      return;
    }
    final text = typed.isEmpty && newAttachments.any((file) => file.isImage)
        ? context.l10n.translatorTestOcrPrompt
        : typed;
    final cancel = CancelToken();
    setState(() {
      _pending = cancel;
      _partial = '';
      _error = null;
      _request = null;
      _response = null;
      _detail = null;
      _status = null;
    });
    final message = (role: 'user', text: text, attachments: newAttachments, incomplete: false);
    final services = ref.read(servicesProvider);
    final append = widget.append;
    String? reply;
    var partial = '';
    try {
      reply = await ref.read(_sendTestMessage)(
        widget.pluginId,
        [
          for (final turn in [...history, message])
            if (turn.text.isNotEmpty || turn.attachments.isNotEmpty) _wireTurn(turn, embedImages: !allowFiles),
        ],
        cancel,
        DialogBatchUi(context, testChat: true),
        confirm: attachments.isEmpty && (widget.thread != null || _messages.isEmpty),
        files: allowFiles
            ? [for (final file in attachments) HttpTemplateFile(file.name, file.bytes, contentType: file.mime)]
            : null,
        connection: widget.connection,
        beforeSend: append == null
            ? null
            : () async {
                await append(message);
                if (mounted) {
                  setState(() => _resetComposer(continueReply: continueReply));
                }
              },
        confirmImage: attachments.isEmpty
            ? null
            : (host) => _confirmAttachment(host, files: allowFiles, includesHistory: includesPastAttachments),
        onText: (text) {
          partial = text;
          if (!mounted) return;
          setState(() => _partial = text);
          _scrollToEnd();
        },
        onRequest: (request) {
          if (mounted) setState(() => _request = request);
        },
        onResponse: (status, body) {
          if (mounted) {
            setState(() {
              _status = status;
              _response = body;
            });
          }
        },
      );
    } on CancelledException {
      // Closing the test chat cancels the request.
    } on TranslationException catch (e) {
      if (mounted) {
        final label = translationErrorLabel(context.l10n, e.kind);
        // Server errors for image inputs often explain the unsupported capability.
        final safeMessage = ref.read(servicesProvider).redactor.redact(e.message);
        final detail = switch (e.statusCode) {
          400 || 404 || 415 || 422 => safeMessage,
          _ => '',
        };
        setState(() {
          _error = detail.isEmpty ? label : context.l10n.withDetails(label, detail);
          _detail = safeMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.l10n.trErrOther;
          _detail = _error;
        });
      }
    } finally {
      final answerText = reply ?? services.redactor.redact(partial);
      try {
        if (answerText.trim().isNotEmpty) {
          final answer = (
            role: 'assistant',
            text: answerText,
            attachments: const <ChatImage>[],
            incomplete: reply == null,
          );
          if (append != null) {
            await append(answer);
          } else if (mounted) {
            _testMessages.addAll([message, answer]);
            _resetComposer(continueReply: continueReply);
          }
        }
      } catch (error, stack) {
        services.appLog.error('chat_answer_save_failed', error, stack);
        if (mounted) _error = context.l10n.trErrOther;
      }
      if (mounted) {
        setState(() {
          _pending = null;
          _partial = '';
        });
        _scrollToEnd();
      }
    }
  }

  void _resetComposer({required bool continueReply}) {
    _includePastAttachments = false;
    if (continueReply) return;
    _text.clear();
    _attachments.clear();
  }

  Future<void> _showDiagnostics() async {
    final l = context.l10n;
    final report = [
      if (_request case final request?) '${l.translatorTestRequest}\n$request',
      if (_response case final response?) '${l.translatorTestResponse} · HTTP $_status\n$response',
      ?_detail,
    ].join('\n\n');
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.translatorTestDiagnostics),
        content: SizedBox(
          width: 580,
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.translatorTestDiagnosticsHelp),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(report.isEmpty ? l.translatorTestDiagnosticsEmpty : report),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l.close)),
          FilledButton.icon(
            onPressed: report.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: report));
                    if (dialog.mounted) Navigator.pop(dialog);
                  },
            icon: const Icon(Icons.copy_outlined),
            label: Text(l.translatorTestCopyDiagnostics),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final thread = widget.thread;
    final allowFiles = _acceptsFiles(widget.connection ?? ref.watch<AppSettings>(settingsProvider));
    final partial = ref.read(servicesProvider).redactor.redact(_partial);
    final showPartial = partial.isNotEmpty && partial.toLowerCase().contains(_query);
    final messages = _messages.where((item) => item.text.toLowerCase().contains(_query)).toList();
    final pane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text([widget.host, widget.model].where((s) => s.isNotEmpty).join(' · ')),
        if (thread != null) ...[
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: l.chatMessageSearch),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          ),
          if (!widget.connectionAvailable) Text(l.chatConnectionMissing),
        ],
        const Divider(),
        Expanded(
          child: _messages.isEmpty && !showPartial
              ? Text(thread == null ? l.translatorTestHelp : l.chatEmpty)
              : messages.isEmpty && !showPartial
              ? Center(child: Text(l.chatNoMessagesFound))
              : ListView(
                  controller: _scroll,
                  children: [
                    for (final message in messages)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(message.role == 'user' ? Icons.person_outline : Icons.smart_toy_outlined),
                        title: SelectableText(message.text),
                        subtitle: message.incomplete
                            ? Text(
                                l.chatIncompleteResponse,
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              )
                            : message.attachments.isEmpty
                            ? null
                            : Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (final file in message.attachments)
                                    if (file.isImage)
                                      Tooltip(message: file.name, child: _thumbnail(file))
                                    else
                                      Text(file.name),
                                ],
                              ),
                      ),
                    if (showPartial)
                      ListTile(leading: const Icon(Icons.smart_toy_outlined), title: SelectableText(partial)),
                  ],
                ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error case final error?)
          Text(
            error,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_messages.lastOrNull?.incomplete == true)
          Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: l.chatContinueHelp,
              child: TextButton.icon(
                onPressed: _busy || !widget.connectionAvailable ? null : () => _send(continueReply: true),
                icon: const Icon(Icons.play_arrow_outlined),
                label: Text(l.chatContinueReply),
              ),
            ),
          ),
        if (_messages.any((message) => message.attachments.isNotEmpty))
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l.chatResendAttachments),
            value: _includePastAttachments,
            onChanged: _busy || !widget.connectionAvailable
                ? null
                : (value) => setState(() => _includePastAttachments = value ?? false),
          ),
        if (_attachments.isNotEmpty)
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _attachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final file = _attachments[index];
                return Row(
                  children: [
                    Tooltip(message: file.name, child: _thumbnail(file)),
                    SizedBox(width: 100, child: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    IconButton(
                      tooltip: file.isImage ? l.translatorTestRemoveImage : l.httpEditorRemoveFile,
                      onPressed: _busy ? null : () => setState(() => _attachments.removeAt(index)),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                );
              },
            ),
          ),
        if (_attachments.any((file) => file.isImage))
          Text(l.translatorTestImageHint, style: Theme.of(context).textTheme.bodySmall),
        Row(
          children: [
            IconButton(
              tooltip: allowFiles ? l.httpEditorAttachFile : l.translatorTestAttachImage,
              onPressed: _busy || !widget.connectionAvailable ? null : () => _pickAttachment(allowFiles),
              icon: const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                autofocus: thread == null,
                readOnly: _busy || !widget.connectionAvailable,
                controller: _text,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(labelText: l.translatorTestMessage),
              ),
            ),
            if (thread != null) ...[
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _busy || !widget.connectionAvailable ? null : _send,
                child: Text(l.translatorTestSend),
              ),
            ],
          ],
        ),
      ],
    );
    if (thread != null) return pane;
    return AlertDialog(
      title: Text(l.translatorTestChat),
      content: SizedBox(width: 560, height: 330, child: pane),
      actions: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _showDiagnostics,
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(l.translatorTestDiagnostics),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
        FilledButton(onPressed: _busy ? null : _send, child: Text(l.translatorTestSend)),
      ],
    );
  }

  Widget _thumbnail(ChatImage image) => !image.isImage
      ? const Icon(Icons.insert_drive_file_outlined)
      : Image.memory(
          image.bytes,
          width: 64,
          height: 48,
          cacheWidth: 128,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        );
}

class _ImageTooLarge implements Exception {
  const _ImageTooLarge();
}

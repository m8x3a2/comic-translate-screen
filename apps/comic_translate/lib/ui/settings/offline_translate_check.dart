// "Try a translation" of the offline translator: type a phrase, see the
// translation at the chosen level (the owner's wish of 2026-11-19). The
// network runs in the background, loaded for each check.

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../state/dictionary.dart';
import '../common/labels.dart';
import '../common/plugin_strings.dart';

// Top level: in a method of the dialog the closure would share its captured
// variables with the dialog's other closures, `this` included.
Future<String> _llmCheckInBackground(String root, String specId, String target, String text) =>
    Isolate.run(() => _llmCheck(root, specId, target, text));

/// [text] translated into [target] by the network [specId] (a level above
/// "Low"), in its own isolate: plain data only.
Future<String> _llmCheck(String root, String specId, String target, String text) async {
  final translator = OfflineLlmTranslator(
    ModelManager(Directory(root)),
    ModelCatalog.byId(specId)!,
    info: opusMtInfo,
    followNotes: false,
  );
  try {
    final block = TextBlock(xyxy: const BBox(0, 0, 1, 1), text: text);
    await translator.translate(
      TranslationRequest(blocks: [block], sourceLanguage: '', targetLanguage: target),
      PluginContext(log: EventLog.silent()),
    );
    return block.translation;
  } finally {
    await translator.dispose();
  }
}

Future<void> showOfflineTranslateCheck(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const OfflineTranslateCheck());

class OfflineTranslateCheck extends ConsumerStatefulWidget {
  const OfflineTranslateCheck({super.key});

  @override
  ConsumerState<OfflineTranslateCheck> createState() => _OfflineTranslateCheckState();
}

class _OfflineTranslateCheckState extends ConsumerState<OfflineTranslateCheck> {
  final _text = TextEditingController();
  String _from = 'English';
  bool _busy = false;
  bool? _installed;
  double? _download;
  CancelToken? _cancel;
  String? _result;
  String? _time;

  /// The level of the settings, "auto" resolved.
  String get _level => resolveOfflineLevel(
    PluginConfig.resolve(
      opusMtInfo.settings,
      ref.read(settingsProvider).pluginValues(opusMtInfo.id),
    ).value<String>('level'),
  );

  /// The network of the level; null for "Low" (OPUS-MT).
  ModelSpec? get _llm => offlineLevelModels[_level];

  ModelSpec get _spec => _llm ?? opusMtBigModels[_from]!.$1;

  @override
  void initState() {
    super.initState();
    _from = ref.read(settingsProvider).sourceLanguage == 'Russian' ? 'Russian' : 'English';
    _checkModel();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _checkModel() async {
    final spec = _spec;
    final status = await ref.read(servicesProvider).models.status(spec);
    if (mounted && spec == _spec) setState(() => _installed = status == ModelStatus.installed);
  }

  Future<void> _downloadModel() async {
    final cancel = _cancel = CancelToken();
    setState(() => _download = 0);
    try {
      await ref
          .read(servicesProvider)
          .models
          .download(
            _spec,
            cancel: cancel,
            onProgress: (d) {
              if (mounted) setState(() => _download = d.total > 0 ? d.received / d.total : null);
            },
          );
    } catch (e) {
      if (mounted && !cancel.isCancelled) setState(() => _result = '$e');
    }
    if (!mounted) return;
    setState(() => _download = null);
    await _checkModel();
  }

  Future<void> _translate() async {
    final text = _text.text.trim();
    if (text.isEmpty || _busy) return;
    final from = _from;
    setState(() {
      _busy = true;
      _result = null;
      _time = null;
    });
    final sw = Stopwatch()..start();
    String? result;
    try {
      final llm = _llm;
      final models = ref.read(servicesProvider).models;
      if (llm == null) {
        result = await translateOffline(models, text, from: from);
      } else if (await models.status(llm) != ModelStatus.installed) {
        result = null;
      } else {
        final root = models.root.path, id = llm.id, target = from == 'English' ? 'Russian' : 'English';
        result = await _llmCheckInBackground(root, id, target, text);
      }
    } catch (e) {
      result = '$e';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result == null) {
        _installed = false;
      } else {
        _result = result;
        _time = (sw.elapsedMilliseconds / 1000).toStringAsFixed(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final megabytes = (_spec.files.fold<int>(0, (a, f) => a + f.size) / 1e6).round();
    return AlertDialog(
      title: Text(l.offlineCheckTitle),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.offlineCheckHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              l.offlineCheckLevel(optionLabel(context, opusMtInfo, opusMtInfo.field('level')!, _level, _level)),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'English', label: Text(l.offlineCheckEnRu)),
                ButtonSegment(value: 'Russian', label: Text(l.offlineCheckRuEn)),
              ],
              selected: {_from},
              onSelectionChanged: _busy || _download != null
                  ? null
                  : (v) {
                      setState(() {
                        _from = v.first;
                        _installed = null;
                        _result = null;
                        _time = null;
                      });
                      _checkModel();
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(labelText: l.offlineCheckPhrase, border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (_installed == false) ...[
              Text(l.offlineCheckNoModel(megabytes)),
              const SizedBox(height: 8),
              if (_download != null) ...[
                Text(l.offlineCheckDownloading),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: _download == 0 ? null : _download),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _downloadModel,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(l.offlineCheckDownload),
                  ),
                ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(_result!, style: theme.textTheme.bodyLarge),
              ),
            if (_time != null) ...[
              const SizedBox(height: 6),
              Text(
                l.offlineCheckTime(l.localeName.startsWith('ru') ? _time!.replaceAll('.', ',') : _time!),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        FilledButton(
          onPressed: _busy || _installed != true || _text.text.trim().isEmpty ? null : _translate,
          child: Text(l.offlineCheckTranslate),
        ),
      ],
    );
  }
}

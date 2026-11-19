// "Try a translation" of the offline translator: type a phrase, see the
// translation (the owner's wish of 2026-11-19; the offline translator is not
// a chat model, so it gets this box instead of the test chat).

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../state/dictionary.dart';
import '../common/labels.dart';

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

  ModelSpec get _spec => opusMtBigModels[_from]!.$1;

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
      result = await translateOffline(ref.read(servicesProvider).models, text, from: from);
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
              Text(l.offlineCheckTime(_time!), style: theme.textTheme.bodySmall),
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

import 'dart:async';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import 'labels.dart';
import 'plugin_strings.dart';

/// The last 4 characters of a saved key, to tell keys apart; nothing for
/// short values, where 4 characters would give away too much.
String secretTail(String? value) => value == null || value.length < 12 ? '' : value.substring(value.length - 4);

/// A secret (API key): shows whether it is saved and its last 4 characters.
/// What the user types can be shown before saving; the saved key is shown
/// or copied only on request (and hidden again after a while). It never goes
/// into logs or bug reports.
class PluginSecretField extends ConsumerStatefulWidget {
  const PluginSecretField(
    this.info,
    this.field,
    this.secretKey, {
    super.key,
    this.storageHelp,
    this.removeBody,
    this.onRemoved,
  });

  final PluginInfo info;
  final SecretSetting field;
  final String secretKey;
  final String? storageHelp;
  final String? removeBody;
  final Future<void> Function()? onRemoved;

  @override
  ConsumerState<PluginSecretField> createState() => _PluginSecretFieldState();
}

class _PluginSecretFieldState extends ConsumerState<PluginSecretField> {
  final _controller = TextEditingController();
  bool? _saved;
  String _tail = '';
  bool _show = false;

  /// The saved key, while shown.
  String? _revealed;
  Timer? _hide;

  String get _key => widget.secretKey;

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
    final revision = ref.read(credentialRevisionProvider.notifier);
    await ref.read(servicesProvider).secrets.write(_key, value);
    revision.changed();
    if (!mounted) return;
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
        content: Text(widget.removeBody ?? l.secretRemoveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final onRemoved = widget.onRemoved;
    final revision = ref.read(credentialRevisionProvider.notifier);
    await ref.read(servicesProvider).secrets.delete(_key);
    revision.changed();
    if (mounted) {
      _conceal();
      setState(() {
        _saved = false;
        _tail = '';
      });
    }
    if (onRemoved != null) await onRemoved();
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
                  helperText: [if (help.isNotEmpty) help, widget.storageHelp ?? l.savedSecurely].join(' '),
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
        if (saved || widget.info.keyUrl.isNotEmpty)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              // The service's page where keys are made, in the browser.
              if (widget.info.keyUrl.isNotEmpty)
                Tooltip(
                  message: widget.info.keyUrl,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse(widget.info.keyUrl)),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l.secretGetKey),
                  ),
                ),
              if (saved) ...[
                TextButton.icon(
                  onPressed: _reveal,
                  icon: Icon(_revealed == null ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  label: Text(_revealed == null ? l.secretShowSaved : l.secretHideSaved),
                ),
                TextButton.icon(onPressed: _copy, icon: const Icon(Icons.copy, size: 18), label: Text(l.secretCopy)),
                if (_revealed != null) SelectableText(_revealed!, style: const TextStyle(fontFamily: 'monospace')),
              ],
            ],
          ),
      ],
    );
  }
}

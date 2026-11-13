/// Settings → General → Program icon: the green translator, the blue or dark
/// cat or the user's own picture (which can be removed again), and "Update
/// shortcuts" ([lib/state/app_icon.dart]).
library;

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_icon.dart';
import '../../state/app_state.dart';
import '../common/info_hint.dart';
import '../common/labels.dart';
import '../shell_full/main_screen.dart' show showInExplorer;

class AppIconChoice extends ConsumerStatefulWidget {
  const AppIconChoice({super.key});

  @override
  ConsumerState<AppIconChoice> createState() => _AppIconChoiceState();
}

class _AppIconChoiceState extends ConsumerState<AppIconChoice> {
  bool _busy = false;

  /// Bumped after a new picture, so the preview is read again.
  int _revision = 0;

  AppPaths get _paths => ref.read(servicesProvider).paths;

  void _choose(String icon) => ref.read(settingsProvider.notifier).change((s) => s.appIcon = icon);

  void _say(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _pickPicture() async {
    final l = context.l10n;
    final file = await openFile(
      acceptedTypeGroups: [XTypeGroup(label: l.appIconCustom, extensions: appIconPictureTypes)],
    );
    if (file == null) return;
    setState(() => _busy = true);
    try {
      await makeCustomIcon(file.path, _paths);
    } on Object catch (e) {
      _say(l.appIconBadPicture('$e'));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    setState(() => _revision++);
    final already = ref.read(settingsProvider).appIcon == 'custom';
    _choose('custom');
    // the setting did not change, so nobody else puts the new picture on
    if (already && !await applyAppIcon('custom', _paths)) _say(l.appIconNotLoaded);
  }

  /// Deletes the user's picture; when it was the chosen icon, the green one
  /// comes back, and the shortcuts can be updated right from the message.
  Future<void> _removePicture() async {
    final l = context.l10n;
    final wasChosen = ref.read(settingsProvider).appIcon == 'custom';
    try {
      await deleteCustomIcon(_paths);
    } on Object catch (e) {
      _say(l.appIconRemoveFailed('$e'));
      return;
    }
    if (!mounted) return;
    setState(() => _revision++);
    if (!wasChosen) {
      _say(l.appIconRemoved);
      return;
    }
    _choose('green');
    _say(
      l.appIconRemovedBack,
      action: SnackBarAction(label: l.updateShortcuts, onPressed: _updateShortcuts),
    );
  }

  Future<void> _updateShortcuts() async {
    final l = context.l10n;
    final location = shortcutIconLocation(ref.read(settingsProvider).appIcon, _paths);
    setState(() => _busy = true);
    try {
      final n = await updateShortcuts(location);
      if (n > 0) {
        _say(l.shortcutsUpdated(n));
        return;
      }
      if (!mounted) return;
      final create = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.shortcutsNoneTitle),
          content: Text(l.shortcutsNoneBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.createDesktopShortcut)),
          ],
        ),
      );
      if (create != true) return;
      final path = await createDesktopShortcut(location);
      _say(
        l.shortcutCreated(path),
        action: SnackBarAction(label: l.showInFolder, onPressed: () => showInExplorer(path)),
      );
    } on Object catch (e) {
      _say(l.shortcutsFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final icon = ref.watch(settingsProvider.select((s) => s.appIcon));
    final paths = ref.watch(servicesProvider).paths;
    final hasCustom = paths.customIcon.existsSync();
    final preview = paths.customIconPreview;
    final custom = hasCustom && preview.existsSync()
        ? Image.memory(preview.readAsBytesSync(), key: ValueKey(_revision), width: 48, height: 48)
        : Icon(hasCustom ? Icons.image_outlined : Icons.add_photo_alternate_outlined, size: 40);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _IconTile(
              label: l.appIconGreen,
              selected: icon == 'green' || (icon == 'custom' && !hasCustom),
              onTap: _busy ? null : () => _choose('green'),
              child: Image.asset('assets/icon/preview_green.png', width: 48, height: 48),
            ),
            _IconTile(
              label: l.appIconBlue,
              selected: icon == 'blue',
              onTap: _busy ? null : () => _choose('blue'),
              child: Image.asset('assets/icon/preview_blue.png', width: 48, height: 48),
            ),
            _IconTile(
              label: l.appIconNavy,
              selected: icon == 'navy',
              onTap: _busy ? null : () => _choose('navy'),
              child: Image.asset('assets/icon/preview_navy.png', width: 48, height: 48),
            ),
            _IconTile(
              label: l.appIconCustom,
              selected: icon == 'custom' && hasCustom,
              onTap: _busy ? null : (hasCustom ? () => _choose('custom') : _pickPicture),
              child: custom,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (hasCustom)
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickPicture,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(l.appIconOther),
              ),
            if (hasCustom)
              OutlinedButton.icon(
                onPressed: _busy ? null : _removePicture,
                icon: const Icon(Icons.delete_outline),
                label: Text(l.appIconRemove),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _updateShortcuts,
                  icon: const Icon(Icons.shortcut),
                  label: Text(l.updateShortcuts),
                ),
                const SizedBox(width: 4),
                InfoHint(l.updateShortcutsInfo),
              ],
            ),
            if (_busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 6),
        Text(l.appIconHelp, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.label, required this.selected, required this.onTap, required this.child});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 128,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(
                children: [
                  SizedBox(width: 48, height: 48, child: Center(child: child)),
                  const SizedBox(height: 6),
                  Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialogs of "Translate all": permission to send text, model downloads,
/// the report.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/batch.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';
import '../common/plugin_strings.dart';
import '../settings/settings_screen.dart';
import 'main_screen.dart' show showInExplorer;

class DialogBatchUi implements BatchUi {
  DialogBatchUi(this.context);

  final BuildContext context;

  @override
  Future<bool> confirmDownload(List<ModelSpec> models) async {
    if (!context.mounted) return false;
    final l = context.l10n;
    final total = models.fold<int>(0, (a, m) => a + m.files.fold(0, (b, f) => b + f.size));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.download_outlined),
        title: Text(l.downloadTitle),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.downloadBody(formatBytes(total))),
              const SizedBox(height: 12),
              for (final m in models)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.memory),
                  title: Text(modelText(l, m).$1),
                  subtitle: Text(
                    l.downloadFrom(
                      formatBytes(m.files.fold(0, (a, f) => a + f.size)),
                      {for (final f in m.files) f.host}.join(', '),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.download)),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Future<NetworkChoice> confirmNetwork(
    PluginInfo translator,
    PluginEndpoint endpoint, {
    required bool sendsImage,
  }) async {
    if (!context.mounted) return NetworkChoice.cancel;
    final l = context.l10n;
    final where = endpoint.privacy == Privacy.lan ? l.networkWhereLan : l.networkWhereCloud;
    final choice = await showDialog<NetworkChoice>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(privacyIcon(endpoint.privacy)),
        title: Text(l.networkTitle),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.networkBody(pluginName(context, translator), endpoint.host, where)),
              if (sendsImage) ...[const SizedBox(height: 8), Text(l.networkBodyImage)],
              const SizedBox(height: 8),
              Text(l.networkOffline, style: Theme.of(c).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, NetworkChoice.cancel), child: Text(l.cancel)),
          OutlinedButton(onPressed: () => Navigator.pop(c, NetworkChoice.always), child: Text(l.allowAlways)),
          FilledButton(onPressed: () => Navigator.pop(c, NetworkChoice.once), child: Text(l.allowOnce)),
        ],
      ),
    );
    return choice ?? NetworkChoice.cancel;
  }

  @override
  Future<void> explainMissingKey(PluginInfo translator, String host) async {
    if (!context.mounted) return;
    final l = context.l10n;
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.key_outlined),
        title: Text(host.isEmpty ? l.missingAddressTitle : l.missingKeyTitle),
        content: SizedBox(
          width: 460,
          child: Text(
            host.isEmpty
                ? l.missingAddressBody(pluginName(context, translator))
                : l.missingKeyBody(pluginName(context, translator), host),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.openSettings)),
        ],
      ),
    );
    if ((open ?? false) && context.mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen(initial: SettingsSection.translator)));
    }
  }

  @override
  Future<HandEditedChoice> confirmHandEdited(int count) async {
    if (!context.mounted) return HandEditedChoice.cancel;
    final l = context.l10n;
    final choice = await showDialog<HandEditedChoice>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.edit_note),
        title: Text(l.handEditedTitle),
        content: SizedBox(width: 460, child: Text(l.handEditedBody('$count'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, HandEditedChoice.cancel), child: Text(l.cancel)),
          OutlinedButton(
            onPressed: () => Navigator.pop(c, HandEditedChoice.translate),
            child: Text(l.handEditedTranslate),
          ),
          FilledButton(onPressed: () => Navigator.pop(c, HandEditedChoice.skip), child: Text(l.handEditedSkip)),
        ],
      ),
    );
    return choice ?? HandEditedChoice.cancel;
  }

  @override
  void showError(Object error) {
    if (!context.mounted) return;
    final l = context.l10n;
    final text = switch (error) {
      ModelDownloadException(:final message) => l.downloadFailed(message),
      _ => l.runFailed(reasonLabel(l, skipReasonFor(error))),
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text), showCloseIcon: true, duration: const Duration(seconds: 10)));
  }
}

Future<void> showBatchReport(BuildContext context, BatchReport report) =>
    showDialog<void>(context: context, builder: (c) => _ReportDialog(report));

class _ReportDialog extends ConsumerWidget {
  const _ReportDialog(this.report);

  final BatchReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l.reportTitle),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reportSummary('${report.done}', '${report.total}', formatDuration(report.duration))),
            if (report.stoppedBy case final reason?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.reportStopped(reasonLabel(l, reason)), style: TextStyle(color: theme.colorScheme.error)),
                    if (fixedInSettings(reason))
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen(initial: SettingsSection.translator),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined),
                        label: Text(l.openSettings),
                      ),
                  ],
                ),
              )
            else if (report.cancelled)
              Text(l.reportCancelled, style: TextStyle(color: theme.colorScheme.error)),
            for (final dir in report.exportDirs)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(l.reportExported(dir))),
                    TextButton(onPressed: () => showInExplorer(dir), child: Text(l.showInFolder)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (report.skipped.isEmpty)
              Text(l.reportNoSkipped)
            else ...[
              Text(l.reportSkipped, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in report.skipped)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.warning_amber, color: theme.colorScheme.error),
                        title: Text(s.name),
                        subtitle: Text(reasonLabel(l, s.reason)),
                        trailing: IconButton(
                          tooltip: l.goToPage,
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () {
                            final pages = ref.read(workspaceProvider).pages;
                            final i = pages.indexWhere((p) => p.id == s.pageId);
                            if (i >= 0) ref.read(workspaceProvider.notifier).select(i);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.close))],
    );
  }
}

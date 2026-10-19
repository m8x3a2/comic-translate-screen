/// Start screen, shown while no pages are open (original `startup_home.py`),
/// with the recent projects.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../app_info.dart';
import '../../state/app_state.dart';
import '../../state/project.dart';
import '../common/labels.dart';

class HomeView extends ConsumerWidget {
  const HomeView({
    super.key,
    required this.onOpenFiles,
    required this.onOpenFolder,
    required this.onOpenProject,
    this.busy = false,
  });

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenFolder;
  final void Function([String? path]) onOpenProject;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final services = ref.watch(servicesProvider);
    PluginEndpoint? endpoint;
    if (services.registry.contains(settings.translator)) {
      final info = services.registry.info(settings.translator);
      endpoint = info.endpointFor(PluginConfig.resolve(info.settings, settings.pluginValues(info.id)));
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_outlined, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(AppInfo.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                l.homeTagline,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              if (busy)
                Column(children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(l.importing)])
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _BigButton(icon: Icons.insert_drive_file_outlined, label: l.openFiles, onTap: onOpenFiles),
                    _BigButton(icon: Icons.folder_open_outlined, label: l.openFolder, onTap: onOpenFolder),
                    _BigButton(icon: Icons.auto_stories_outlined, label: l.openProject, onTap: () => onOpenProject()),
                  ],
                ),
              const SizedBox(height: 16),
              Text(l.dropHint, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(l.supportedFormats, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              if (!busy && settings.recentProjects.isNotEmpty) ...[
                const SizedBox(height: 32),
                Align(alignment: Alignment.centerLeft, child: Text(l.recentProjects, style: theme.textTheme.titleMedium)),
                const SizedBox(height: 4),
                for (final path in settings.recentProjects.take(8)) _RecentProject(path, onOpen: onOpenProject),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    privacyIcon(endpoint?.privacy ?? Privacy.local),
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      endpoint == null ? l.privacyLocal : l.privacySends(endpoint.host),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentProject extends ConsumerWidget {
  const _RecentProject(this.path, {required this.onOpen});

  final String path;
  final void Function([String? path]) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final file = File(path);
    final exists = file.existsSync();
    final when = exists
        ? DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hm().format(file.statSync().modified)
        : l.fileNotFound;
    return ListTile(
      dense: true,
      enabled: exists,
      leading: Icon(Icons.auto_stories_outlined, color: exists ? theme.colorScheme.primary : null),
      title: Text(p.basenameWithoutExtension(path)),
      subtitle: Text('${p.dirname(path)} · $when', overflow: TextOverflow.ellipsis),
      onTap: exists ? () => onOpen(path) : null,
      trailing: IconButton(
        tooltip: l.removeFromList,
        icon: const Icon(Icons.close, size: 18),
        onPressed: () => ref.read(projectProvider.notifier).forget(path),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      height: 120,
      child: Card.outlined(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

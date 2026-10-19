/// Start screen, shown while no pages are open (original `startup_home.py`;
/// recent projects come with projects in M9).
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_info.dart';
import '../../state/app_state.dart';
import '../common/labels.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key, required this.onOpenFiles, required this.onOpenFolder, this.busy = false});

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenFolder;
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
          constraints: const BoxConstraints(maxWidth: 640),
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
                  ],
                ),
              const SizedBox(height: 16),
              Text(l.dropHint, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(l.supportedFormats, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
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

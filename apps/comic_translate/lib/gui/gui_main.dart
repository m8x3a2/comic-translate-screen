import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_info.dart';
import '../bootstrap.dart';

Future<void> guiMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = AppServices.create();
  final log = services.appLog.child(stage: 'gui');

  // Every unhandled error ends up in logs/app.jsonl (redacted).
  FlutterError.onError = (details) {
    log.error('flutter_error', details.exception, details.stack,
        {'library': details.library, 'context': details.context?.toString()});
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('uncaught_error', error, stack);
    return true;
  };

  log.info('gui_start', {'version': AppInfo.version});
  runApp(ComicTranslateApp(services: services));
}

class ComicTranslateApp extends StatelessWidget {
  const ComicTranslateApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3B6FE0);
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: _PlaceholderHome(services: services),
    );
  }
}

/// Temporary start screen until the full interface lands (milestone M7).
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppInfo.name, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('v${AppInfo.version} · stage 1 in progress', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            SelectableText(services.paths.root.path, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

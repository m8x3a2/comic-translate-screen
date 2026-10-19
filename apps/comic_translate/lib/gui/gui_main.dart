import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_info.dart';
import '../bootstrap.dart';
import '../state/app_state.dart';
import '../ui/app.dart';

Future<void> guiMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = AppServices.create();
  await services.init();
  final log = services.appLog.child(stage: 'gui');

  // Every unhandled error ends up in logs/app.jsonl (redacted).
  FlutterError.onError = (details) {
    log.error('flutter_error', details.exception, details.stack, {
      'library': details.library,
      'context': details.context?.toString(),
    });
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('uncaught_error', error, stack);
    return true;
  };

  final settings = await services.settingsStore.load();
  log.info('gui_start', {'version': AppInfo.version});
  runApp(
    ProviderScope(
      overrides: [
        servicesProvider.overrideWithValue(services),
        initialSettingsProvider.overrideWithValue(settings),
        initialInputsProvider.overrideWithValue([
          for (final a in args)
            if (FileSystemEntity.typeSync(a) != FileSystemEntityType.notFound) a,
        ]),
        translateOnStartProvider.overrideWithValue(args.contains('--translate')),
        settingsOnStartProvider.overrideWithValue(
          args.where((a) => a.startsWith('--settings=')).map((a) => a.substring(11)).firstOrNull,
        ),
      ],
      child: const ComicTranslateApp(),
    ),
  );
}

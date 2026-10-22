import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_info.dart';
import '../bootstrap.dart';
import '../l10n/app_localizations.dart';
import '../pipeline/pipeline_worker.dart' show GpuFallback, gpuFallbacks;
import '../state/app_state.dart';
import '../state/gpu_check.dart' show shortGpuReason;
import '../state/window_mode.dart';
import 'common/key_bindings.dart';
import 'shell_full/main_screen.dart' show MainScreen, showInExplorer;

/// Shows messages from outside the widget tree (unexpected errors).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

DateTime? _lastErrorNotice;
DateTime? _lastAutoReport;

/// Settings → General: an unexpected error builds a bug report by itself.
/// Kept here because errors are reported from outside the widget tree.
bool autoBugReportEnabled = true;

const _errorNoticeTime = Duration(seconds: 30);

/// Tells the user that something failed unexpectedly; details are in the
/// log. With [autoBugReportEnabled] a bug report is built right away (at
/// most one a minute) and the message says where it is; otherwise the
/// message offers to build one. At most one message every 10 s.
void notifyUnexpectedError(AppServices services) {
  final now = DateTime.now();
  if (_lastErrorNotice != null && now.difference(_lastErrorNotice!) < const Duration(seconds: 10)) return;
  _lastErrorNotice = now;
  final auto =
      autoBugReportEnabled &&
      (_lastAutoReport == null || now.difference(_lastAutoReport!) >= const Duration(minutes: 1));
  if (auto) _lastAutoReport = now;
  final report = auto ? services.buildBugReport(auto: true).then<File?>((f) => f, onError: (_) => null) : null;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final messenger = appMessengerKey.currentState;
    final context = appMessengerKey.currentContext;
    if (messenger == null || context == null) return;
    final l = AppLocalizations.of(context);
    final zip = await report;
    if (zip != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.unexpectedErrorReported(zip.path)),
          duration: _errorNoticeTime,
          showCloseIcon: true,
          action: SnackBarAction(label: l.showInFolder, onPressed: () => showInExplorer(zip.path)),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.unexpectedError),
        duration: _errorNoticeTime,
        showCloseIcon: true,
        action: SnackBarAction(
          label: l.bugReport,
          onPressed: () async {
            final zip = await services.buildBugReport();
            messenger.showSnackBar(
              SnackBar(
                content: Text(l.bugReportDone(zip.path)),
                duration: _errorNoticeTime,
                showCloseIcon: true,
                action: SnackBarAction(label: l.showInFolder, onPressed: () => showInExplorer(zip.path)),
              ),
            );
          },
        ),
      ),
    );
  });
  WidgetsBinding.instance.scheduleFrame();
}

class ComicTranslateApp extends ConsumerStatefulWidget {
  const ComicTranslateApp({super.key});

  @override
  ConsumerState<ComicTranslateApp> createState() => _ComicTranslateAppState();
}

class _ComicTranslateAppState extends ConsumerState<ComicTranslateApp> {
  static const _seed = Color(0xFF3B6FE0);
  late final StreamSubscription<GpuFallback> _gpuFallbackSub;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    // A model that failed on the graphics card opens on the processor from
    // now on (the notice is the main screen's).
    _gpuFallbackSub = gpuFallbacks.stream.listen(
      (f) => ref.read(settingsProvider.notifier).change((s) => s.gpuCpuModels[f.model] = shortGpuReason(f.reason)),
    );
    autoBugReportEnabled = ref.read(settingsProvider).autoBugReport;
    ref.listenManual(settingsProvider.select((s) => s.autoBugReport), (_, on) => autoBugReportEnabled = on);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _gpuFallbackSub.cancel();
    super.dispose();
  }

  /// Full screen (F11, or the key chosen in the settings) works everywhere:
  /// on every screen and under dialogs.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || capturingShortcut) return false;
    final combo = KeyCombo.ofEvent(e, HardwareKeyboard.instance);
    final keys = KeyBindings.of(ref.read(settingsProvider));
    if (combo == null || keys.actionOf(combo) != ShortcutAction.fullScreen) return false;
    ref.read(fullScreenProvider.notifier).toggle().then((on) {
      final messenger = appMessengerKey.currentState;
      final context = appMessengerKey.currentContext;
      if (!on || messenger == null || context == null || !context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).fullScreenOn), duration: const Duration(seconds: 3)),
      );
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(settingsProvider.select((s) => s.theme));
    final language = ref.watch(settingsProvider.select((s) => s.uiLanguage));
    return MaterialApp(
      title: AppInfo.name,
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      themeMode: switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: Locale(language == 'en' ? 'en' : 'ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainScreen(),
    );
  }
}

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_info.dart';
import '../bootstrap.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../state/window_mode.dart';
import 'common/key_bindings.dart';
import 'shell_full/main_screen.dart';

/// Shows messages from outside the widget tree (unexpected errors).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

DateTime? _lastErrorNotice;

/// Tells the user that something failed unexpectedly; details are in the
/// log, and the message offers a bug report. At most one every 10 s.
void notifyUnexpectedError(AppServices services) {
  final now = DateTime.now();
  if (_lastErrorNotice != null && now.difference(_lastErrorNotice!) < const Duration(seconds: 10)) return;
  _lastErrorNotice = now;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final messenger = appMessengerKey.currentState;
    final context = appMessengerKey.currentContext;
    if (messenger == null || context == null) return;
    final l = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.unexpectedError),
        duration: const Duration(seconds: 12),
        showCloseIcon: true,
        action: SnackBarAction(
          label: l.bugReport,
          onPressed: () async {
            await services.appLog.flush();
            final zip = await BugReportBuilder(
              paths: services.paths,
              redactor: services.redactor,
            ).build(environment: await services.environmentWithGpu());
            services.appLog.info('bug_report', {'file': zip.path, 'with_images': false});
            messenger.showSnackBar(SnackBar(content: Text(l.bugReportDone(zip.path)), showCloseIcon: true));
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

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
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

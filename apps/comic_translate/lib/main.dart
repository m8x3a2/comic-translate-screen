import 'dart:io';

import 'package:flutter/widgets.dart';

import 'cli/cli.dart';
import 'gui/gui_main.dart';

/// Added by the native cts.exe launcher (windows/runner/cli_main.cpp).
const cliFlag = '--cts-cli';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == cliFlag) {
    WidgetsFlutterBinding.ensureInitialized();
    final code = await runCli(args.sublist(1));
    await stdout.flush();
    await stderr.flush();
    exit(code);
  }
  await guiMain(args);
}

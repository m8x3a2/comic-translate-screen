import 'dart:io';

import '../../app_info.dart';
import '../cli.dart';
import '../cli_context.dart';

class VersionCommand extends CtsCommand {
  VersionCommand(super.holder);

  @override
  String get name => 'version';

  @override
  String get description => 'Print version information.';

  @override
  Future<int> run() async {
    final info = {
      'app': AppInfo.name,
      'version': AppInfo.version,
      if (AppInfo.gitSha.isNotEmpty) 'git_sha': AppInfo.gitSha,
      'flutter': AppInfo.flutterVersion,
      'dart': Platform.version.split(' ').first,
    };
    if (ctx.json) {
      ctx.printJson(info);
    } else {
      final sha = AppInfo.gitSha.isEmpty ? '' : ' (${AppInfo.gitSha})';
      ctx.say('${AppInfo.name} ${AppInfo.version}$sha · '
          'Flutter ${info['flutter'] ?? '?'} · Dart ${info['dart']}');
    }
    return ExitCodes.ok;
  }
}

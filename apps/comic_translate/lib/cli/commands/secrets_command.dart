import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ct_core/ct_core.dart';

import '../cli.dart';
import '../cli_context.dart';

/// Manages API keys in the OS secure storage. Values are read from stdin,
/// never from arguments, so they do not end up in shell history.
class SecretsCommand extends Command<int> {
  SecretsCommand(CliContextHolder holder) {
    addSubcommand(_SecretsList(holder));
    addSubcommand(_SecretsSet(holder));
    addSubcommand(_SecretsDelete(holder));
  }

  @override
  String get name => 'secrets';

  @override
  String get description => 'Manage API keys stored in the OS secure storage.';
}

class _SecretsList extends CtsCommand {
  _SecretsList(super.holder);

  @override
  String get name => 'list';

  @override
  String get description => 'List stored secret names (values are never shown).';

  @override
  Future<int> run() async {
    final keys = await ctx.services.secrets.keys();
    if (ctx.json) {
      ctx.printJson(keys);
    } else if (keys.isEmpty) {
      ctx.say('No secrets stored.');
    } else {
      keys.forEach(ctx.say);
    }
    return ExitCodes.ok;
  }
}

class _SecretsSet extends CtsCommand {
  _SecretsSet(super.holder);

  @override
  String get name => 'set';

  @override
  String get description => 'Store a secret read from stdin, e.g. '
      '`cts secrets set plugin.openai_compatible.api_key` then paste the key.';

  @override
  String get invocation => 'cts secrets set <name>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) usageException('Expected exactly one secret name.');
    if (!ctx.json) ctx.err.writeln('Paste the value and press Enter:');
    final value = stdin.readLineSync(encoding: utf8)?.trim() ?? '';
    if (value.isEmpty) {
      ctx.err.writeln('Empty value, nothing stored.');
      return ExitCodes.failure;
    }
    await ctx.services.secrets.write(rest.single, value);
    ctx.services.appLog.info('secret_set', {'name': rest.single});
    ctx.say('Stored ${rest.single}.');
    return ExitCodes.ok;
  }
}

class _SecretsDelete extends CtsCommand {
  _SecretsDelete(super.holder);

  @override
  String get name => 'delete';

  @override
  String get description => 'Delete a stored secret.';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) usageException('Expected exactly one secret name.');
    await ctx.services.secrets.delete(rest.single);
    ctx.services.appLog.info('secret_delete', {'name': rest.single});
    ctx.say('Deleted ${rest.single}.');
    return ExitCodes.ok;
  }
}

/// Reports whether the secret store works at all (used by `cts doctor`).
Future<String> describeSecretStore(SecretStore store) async {
  final n = (await store.keys()).length;
  return '$n secret(s) stored';
}

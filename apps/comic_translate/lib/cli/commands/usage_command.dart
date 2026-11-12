import 'package:ct_core/ct_core.dart';

import '../cli.dart';
import '../cli_context.dart';

/// The usage counter kept on this computer and, with `--balance`, what the
/// service says is left of the API key (OpenRouter).
class UsageCommand extends CtsCommand {
  UsageCommand(super.holder) {
    argParser
      ..addFlag('reset', negatable: false, help: 'Start the counter from zero.')
      ..addFlag(
        'balance',
        negatable: false,
        help: "Ask the translator's service for key details. This sends the saved key to the server.",
      )
      ..addOption('translator', help: 'Translator plugin id for --balance (default from settings).');
  }

  @override
  String get name => 'usage';

  @override
  String get description =>
      'Show the usage of paid services counted on this computer (requests, tokens, cost per model).';

  @override
  String get invocation => 'cts usage [--balance] [--reset]';

  @override
  Future<int> run() async {
    final args = argResults!;
    final services = ctx.services;
    if (args.flag('reset')) {
      await services.usage.reset();
      ctx.say('Usage counter reset.');
      return ExitCodes.ok;
    }

    KeyStatus? balance;
    String? balanceHost;
    if (args.flag('balance')) {
      final settings = await services.settingsStore.load();
      final id = args.option('translator') ?? settings.translator;
      final PluginInfo info;
      try {
        info = services.registry.info(id);
      } on UnknownPluginException {
        usageException('Unknown translator "$id". See `cts settings plugins`.');
      }
      final query = info.keyStatus?.call(await services.pluginConfig(id, settings));
      if (query == null) {
        ctx.err.writeln('No key status request is configured for "${info.displayName}".');
        return ExitCodes.failure;
      }
      if (!query.hasKey) {
        final field = info.field('api_key');
        final slot = field is SecretSetting ? settings.pluginSettingSecretKey(id, field) : null;
        ctx.err.writeln('No active API key for "${info.displayName}".');
        ctx.err.writeln(slot == null ? 'Select a key in Settings.' : 'Save it with: cts secrets set $slot');
        return ExitCodes.failure;
      }
      ctx.err.writeln('Sending the API key to ${query.host} to ask what is left of it.');
      services.appLog.info('key_status_request', {'plugin': id, 'host': query.host});
      try {
        balance = await query.run();
        balanceHost = query.host;
      } on TranslationException catch (e) {
        services.appLog.warn('key_status_failed', {'kind': e.kind.name, 'error': e.message});
        ctx.err.writeln('Could not check the balance (${e.kind.name}): ${e.message}');
        return ExitCodes.failure;
      }
    }

    final report = await services.usage.read();
    if (ctx.json) {
      ctx.printJson({
        'since': report.since == null ? null : UsageLog.dayKey(report.since!),
        'entries': [
          for (final e in report.entries)
            {
              'plugin': e.plugin,
              'host': e.host,
              'model': e.model,
              'today': e.today.toJson(),
              'total': e.total.toJson(),
              'last_used': e.lastUsed?.toIso8601String(),
            },
        ],
        if (balance != null)
          'balance': {
            'host': balanceHost,
            if (balance.fields case final fields?)
              'fields': fields
            else ...{
              'limit': balance.limit,
              'remaining': balance.remaining,
              'used': balance.used,
              'used_today': balance.usedToday,
              'used_this_month': balance.usedThisMonth,
              'limit_reset': balance.limitReset?.name,
              'free_requests_today': balance.freeRequestsToday,
              'free_requests_limit': balance.freeRequestsLimit,
              'free_requests_left': balance.freeRequestsLeft,
            },
          },
      });
      return ExitCodes.ok;
    }

    String money(double v) => '\$${v.toStringAsFixed(moneyDecimals(v))}';
    String totals(UsageTotals t) => [
      '${t.requests} request(s)',
      '${t.estimated ? '~' : ''}${t.tokens} tokens (in ${t.inputTokens}, out ${t.outputTokens})',
      if (t.cost != null) money(t.cost!),
    ].join(', ');
    if (report.entries.isEmpty) ctx.say('No requests to paid services counted yet.');
    for (final e in report.entries) {
      ctx.say('${e.model} @ ${e.host}');
      ctx.say('  today: ${e.today.isEmpty ? '-' : totals(e.today)}');
      ctx.say('  total: ${totals(e.total)}');
    }
    if (report.since != null) ctx.say('Counted since ${UsageLog.dayKey(report.since!)}, only on this computer.');
    final b = balance;
    if (b?.fields case final fields?) {
      ctx.say('');
      ctx.say('Key details from $balanceHost');
      for (final entry in fields.entries) {
        ctx.say('  ${entry.key} · ${entry.value}');
      }
    } else if (b != null) {
      ctx.say('');
      ctx.say(
        'Key at $balanceHost: ${b.limit == null ? 'no limit' : 'limit ${money(b.limit!)}, left ${money(b.remaining ?? b.limit! - b.used)}'}, '
        'spent ${money(b.used)} (today UTC ${money(b.usedToday)}, this month ${money(b.usedThisMonth)})'
        '${b.limitReset == null ? '' : ', the limit resets ${b.limitReset!.name}'}.',
      );
      if (b.freeRequestsLimit != null) {
        ctx.say(
          'Free models today: ${b.freeRequestsToday ?? 0} of ${b.freeRequestsLimit} requests, ${b.freeRequestsLeft} left.',
        );
      }
    }
    return ExitCodes.ok;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../cli.dart';
import '../cli_context.dart';

class TranslateCommand extends CtsCommand {
  TranslateCommand(super.holder) {
    argParser
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'cts_out')
      ..addOption('to', help: 'Target language, e.g. Russian (default from settings).')
      ..addOption('from', help: 'Source language (default: the one stored by `cts ocr`, else settings).')
      ..addOption('translator', help: 'Translator plugin id (default from settings).')
      ..addOption('image', help: 'Page image to send as context (only with "send page image" enabled in settings).')
      ..addFlag('allow-network', negatable: false, help: 'Allow this run to send the text to the configured server.')
      ..addFlag('remember', negatable: false, help: 'With --allow-network: remember the approval for this server.')
      ..addFlag('debug', negatable: false, help: 'Test mode: save a run folder with the request (redacted) and reply.');
  }

  @override
  String get name => 'translate';

  @override
  String get description =>
      'Translate the blocks of <name>.ocr.json files from `cts ocr`; writes <name>.translated.json.';

  @override
  String get invocation => 'cts translate <name.ocr.json>... [--to Russian] [--translator mock] [--allow-network]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty) usageException('Give at least one .ocr.json file from `cts ocr`.');
    final services = ctx.services;
    final store = services.settingsStore;
    final settings = await store.load();
    final translatorId = args.option('translator') ?? settings.translator;
    final target = args.option('to') ?? settings.targetLanguage;
    if (Languages.byName(target) == null) usageException('Unknown target language "$target".');
    if (args.option('image') != null && args.rest.length != 1) usageException('--image works with exactly one file.');

    final allowed = await checkTranslatorNetwork(
      ctx,
      translatorId,
      settings,
      allowNetwork: args.flag('allow-network'),
      remember: args.flag('remember'),
      usageException: usageException,
    );
    if (!allowed) return ExitCodes.failure;

    RunRecorder? recorder;
    if (args.flag('debug')) {
      recorder = await RunRecorder.start(
        runsDir: services.paths.runs,
        redactor: services.redactor,
        environment: services.environment(),
        label: 'translate',
      );
      ctx.say('Run folder: ${recorder.dir.path}');
    }
    final log = recorder?.log ?? services.appLog.child(stage: 'translate');
    final outDir = Directory(args.option('output')!)..createSync(recursive: true);

    final Translator translator;
    try {
      translator = await services.plugin<Translator>(translatorId, settings, log: log);
    } on Object catch (e) {
      ctx.err.writeln(e);
      await recorder?.finish(success: false, summary: {'error': e.toString()});
      return ExitCodes.failure;
    }

    final results = <Map<String, Object?>>[];
    var ok = true;
    for (final input in args.rest) {
      final page = p.basename(input);
      final pageLog = log.child(page: page);
      try {
        final json = (jsonDecode(File(input).readAsStringSync()) as Map).cast<String, Object?>();
        final blocks = [for (final b in (json['blocks'] as List).cast<Map<String, Object?>>()) TextBlock.fromJson(b)];
        final order = (json['reading_order'] as List?)?.cast<int>() ?? [for (var i = 0; i < blocks.length; i++) i];
        final source = args.option('from') ?? (json['source_language'] as String?) ?? settings.sourceLanguage;

        RgbImage? pageImage;
        final imagePath = args.option('image');
        if (settings.sendPageImage && imagePath != null) {
          pageImage = await ImageCodec.readFile(imagePath);
        } else if (imagePath != null) {
          ctx.err.writeln('Page image not sent: "send page image" is off (cts settings set llm.send_page_image true).');
        }

        final ordered = [for (final i in order) blocks[i]];
        final sw = Stopwatch()..start();
        await translateBlocks(
          translator,
          TranslationRequest(
            blocks: ordered,
            sourceLanguage: source,
            targetLanguage: target,
            pageImage: pageImage,
            extraContext: settings.extraContext,
          ),
          PluginContext(log: pageLog, recorder: recorder, page: page),
        );
        setUpperCase(ordered, settings.upperCase);
        final ms = sw.elapsedMilliseconds;
        recorder?.recordTiming('03_translate', Duration(milliseconds: ms), page: page);

        final out = {
          ...json,
          'source_language': source,
          'target_language': target,
          'translator': translatorId,
          'blocks': [for (final b in blocks) b.toJson()],
        };
        final stem = p.basename(input).replaceAll(RegExp(r'(\.ocr)?\.json$'), '');
        final file = File(p.join(outDir.path, '$stem.translated.json'))
          ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
        pageLog.log(LogLevel.info, 'translate_done', durMs: ms, data: {'blocks': blocks.length});
        results.add({
          'file': input,
          'json': file.path,
          'translate_ms': ms,
          'pairs': [for (final b in ordered) {'text': b.text, 'translation': b.translation}],
        });
        ctx.say('$page: ${blocks.length} block(s), $ms ms → ${file.path}');
        for (final b in ordered) {
          ctx.say('  ${b.text}\n    → ${b.translation}');
        }
      } catch (e, st) {
        ok = false;
        pageLog.error('translate_failed', e, st);
        results.add({'file': input, 'error': e.toString()});
        ctx.err.writeln('$page: $e');
      }
    }
    await recorder?.finish(success: ok, summary: {'files': results.length});
    if (ctx.json) ctx.printJson({'ok': ok, 'run': recorder?.runId, 'results': results});
    return ok ? ExitCodes.ok : ExitCodes.failure;
  }
}

/// Refuses translators that send text off this computer unless the user
/// allowed it for this run (`--allow-network`) or approved the server before.
/// Prints where the text goes. Returns false when nothing may be sent.
Future<bool> checkTranslatorNetwork(
  CliContext ctx,
  String translatorId,
  AppSettings settings, {
  required bool allowNetwork,
  required bool remember,
  required Never Function(String) usageException,
}) async {
  final services = ctx.services;
  final PluginInfo info;
  try {
    info = services.registry.info(translatorId);
  } on UnknownPluginException {
    usageException('Unknown translator "$translatorId". See `cts settings plugins`.');
  }
  if (info.kind != PluginKind.translator) usageException('"$translatorId" is not a translator.');
  final config = await services.pluginConfig(translatorId, settings);
  final endpoint = info.endpointFor(config);
  if (endpoint == null) return true;
  final key = endpoint.approvalKey(translatorId);
  final where = endpoint.privacy == Privacy.lan ? 'a computer on your local network' : 'the internet';
  if (!settings.approvedNetworkPlugins.contains(key) && !allowNetwork) {
    ctx.err.writeln('"${info.displayName}" sends the recognized text to ${endpoint.host} ($where). '
        'Nothing was sent. Re-run with --allow-network (add --remember to approve this server permanently), '
        'or use --translator mock to test offline.');
    return false;
  }
  if (remember && allowNetwork) {
    settings.approvedNetworkPlugins.add(key);
    await services.settingsStore.save(settings);
  }
  ctx.err.writeln('Sending text to ${endpoint.host} ($where).');
  return true;
}

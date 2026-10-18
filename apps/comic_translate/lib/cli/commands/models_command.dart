import 'package:args/command_runner.dart';
import 'package:ct_core/ct_core.dart';

import '../cli.dart';
import '../cli_context.dart';

class ModelsCommand extends Command<int> {
  ModelsCommand(CliContextHolder holder) {
    addSubcommand(_ModelsList(holder));
    addSubcommand(_ModelsDownload(holder));
    addSubcommand(_ModelsVerify(holder));
    addSubcommand(_ModelsDelete(holder));
  }

  @override
  String get name => 'models';

  @override
  String get description => 'List, download, verify and delete models.';
}

abstract class _ModelsSubcommand extends CtsCommand {
  _ModelsSubcommand(super.holder);

  ModelManager get manager => ctx.services.models;

  /// Models named in the rest arguments, or all with `--all`.
  List<ModelSpec> selected({bool allowAll = true}) {
    final args = argResults!;
    if (allowAll && args.options.contains('all') && args.flag('all')) return ModelCatalog.all;
    if (args.rest.isEmpty) usageException('Name at least one model id (see `cts models list`).');
    return [
      for (final id in args.rest)
        ModelCatalog.byId(id) ?? (throw UsageException('Unknown model "$id"', usage)),
    ];
  }
}

class _ModelsList extends _ModelsSubcommand {
  _ModelsList(super.holder);

  @override
  String get name => 'list';

  @override
  String get description => 'Show known models and whether they are downloaded.';

  @override
  Future<int> run() async {
    final rows = <Map<String, Object?>>[];
    for (final m in ModelCatalog.all) {
      rows.add({
        'id': m.id,
        'name': m.displayName,
        'purpose': m.purpose,
        'status': (await manager.status(m)).name,
        'bytes': m.totalSize,
        'hosts': m.hosts.toList(),
        'license': m.license,
        'path': manager.dirOf(m).path,
      });
    }
    if (ctx.json) {
      ctx.printJson(rows);
    } else {
      final idWidth = rows.fold(0, (w, r) => (r['id'] as String).length > w ? (r['id'] as String).length : w);
      for (final r in rows) {
        ctx.say('${(r['status'] as String).padRight(9)} ${(r['id'] as String).padRight(idWidth)} '
            '${formatBytes(r['bytes'] as int).padLeft(8)}  ${r['purpose']}  [${r['license']}]');
      }
      ctx.say('');
      ctx.say('Models are stored in ${manager.root.path}');
    }
    return ExitCodes.ok;
  }
}

class _ModelsDownload extends _ModelsSubcommand {
  _ModelsDownload(super.holder) {
    argParser.addFlag('all', negatable: false, help: 'Download every known model.');
  }

  @override
  String get name => 'download';

  @override
  String get description => 'Download models (network access: shows hosts and sizes first).';

  @override
  String get invocation => 'cts models download <model id>... | --all';

  @override
  Future<int> run() async {
    final specs = selected();
    var failed = false;
    for (final spec in specs) {
      if (await manager.status(spec) == ModelStatus.installed) {
        ctx.say('${spec.id}: already downloaded');
        continue;
      }
      ctx.say('${spec.id}: downloading ${formatBytes(spec.totalSize)} from ${spec.hosts.join(', ')}');
      var lastPercent = -1;
      try {
        await manager.download(spec, onProgress: (p) {
          final percent = (p.fraction * 100).floor();
          if (!ctx.json && percent != lastPercent && percent % 10 == 0) {
            lastPercent = percent;
            ctx.err.writeln('  $percent%');
          }
        });
        ctx.say('${spec.id}: OK');
      } on ModelDownloadException catch (e) {
        failed = true;
        ctx.err.writeln('${spec.id}: ${e.message}');
      }
    }
    if (ctx.json) {
      ctx.printJson({
        for (final s in specs) s.id: (await manager.status(s)).name,
      });
    }
    return failed ? ExitCodes.failure : ExitCodes.ok;
  }
}

class _ModelsVerify extends _ModelsSubcommand {
  _ModelsVerify(super.holder) {
    argParser.addFlag('all', negatable: false, help: 'Verify every downloaded model.');
  }

  @override
  String get name => 'verify';

  @override
  String get description => 'Re-check SHA-256 of downloaded model files.';

  @override
  Future<int> run() async {
    final results = <String, List<String>>{};
    for (final spec in selected()) {
      if (await manager.status(spec) == ModelStatus.missing) continue;
      results[spec.id] = await manager.verify(spec);
    }
    final ok = results.values.every((bad) => bad.isEmpty);
    if (ctx.json) {
      ctx.printJson({'ok': ok, 'bad_files': results});
    } else {
      for (final e in results.entries) {
        ctx.say(e.value.isEmpty ? '${e.key}: OK' : '${e.key}: BAD ${e.value.join(', ')}');
      }
      if (results.isEmpty) ctx.say('No downloaded models to verify.');
    }
    return ok ? ExitCodes.ok : ExitCodes.failure;
  }
}

class _ModelsDelete extends _ModelsSubcommand {
  _ModelsDelete(super.holder);

  @override
  String get name => 'delete';

  @override
  String get description => 'Delete downloaded model files.';

  @override
  Future<int> run() async {
    for (final spec in selected(allowAll: false)) {
      await manager.delete(spec);
      ctx.say('${spec.id}: deleted');
    }
    return ExitCodes.ok;
  }
}

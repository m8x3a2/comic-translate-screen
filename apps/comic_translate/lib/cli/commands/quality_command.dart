import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../../pipeline/page_pipeline.dart';
import '../cli.dart';
import '../cli_context.dart';

const _pretty = JsonEncoder.withIndent('  ');

/// `cts compare`: how far two images are apart.
class CompareCommand extends CtsCommand {
  CompareCommand(super.holder) {
    argParser
      ..addOption('diff', help: 'Write a picture of the differences (changed pixels in red) to this PNG.')
      ..addOption('threshold', help: 'Channel difference that counts a pixel as changed.', defaultsTo: '16')
      ..addOption('min-psnr', help: 'Pass when PSNR (dB) is at least this; default: images must be identical.');
  }

  @override
  String get name => 'compare';

  @override
  String get description => 'Compare two images of the same size (PSNR, largest difference, changed pixels). '
      'Exit code 0 when they match.';

  @override
  String get invocation => 'cts compare <a.png> <b.png> [--diff diff.png] [--min-psnr 35]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length != 2) usageException('Give exactly two images.');
    final threshold = int.tryParse(args.option('threshold')!) ?? usageException('--threshold must be a number.');
    final minPsnrText = args.option('min-psnr');
    final minPsnr = minPsnrText == null ? null : double.tryParse(minPsnrText) ?? usageException('--min-psnr must be a number.');
    final a = await ImageCodec.readFile(args.rest[0]);
    final b = await ImageCodec.readFile(args.rest[1]);
    if (a.width != b.width || a.height != b.height) {
      ctx.err.writeln('Sizes differ: ${a.width}x${a.height} vs ${b.width}x${b.height}.');
      if (ctx.json) ctx.printJson({'ok': false, 'error': 'size_mismatch'});
      return ExitCodes.failure;
    }
    final d = compareImages(a, b, threshold: threshold);
    final diffPath = args.option('diff');
    if (diffPath != null) File(diffPath).writeAsBytesSync(ImageCodec.encodePng(diffImage(a, b, threshold: threshold)));
    final ok = minPsnr == null ? d.identical : d.psnr >= minPsnr;
    ctx.say('${ok ? 'match' : 'DIFFERENT'}: $d');
    if (ctx.json) ctx.printJson({'ok': ok, ...d.toJson(), 'diff': ?diffPath});
    return ok ? ExitCodes.ok : ExitCodes.failure;
  }
}

/// Creates the pipeline used for reproducible runs: default settings, the
/// offline mock translator, CPU only.
Future<PagePipeline> _offlinePipeline(CliContext ctx, String source, String target, {bool gpu = false}) async {
  final settings = AppSettings();
  return PagePipeline.load(ctx.services, settings,
      sourceLanguage: source, targetLanguage: target, translatorId: 'mock', useGpu: gpu, log: ctx.services.appLog);
}

/// `cts golden check|update`.
class GoldenCommand extends CtsCommand {
  GoldenCommand(CliContextHolder holder) : super(holder) {
    addSubcommand(_GoldenRun(holder, update: false));
    addSubcommand(_GoldenRun(holder, update: true));
  }

  @override
  String get name => 'golden';

  @override
  String get description => 'Check the whole pipeline against saved results (test_data/golden), or update them.';
}

class _GoldenRun extends Command<int> {
  _GoldenRun(this._holder, {required this.update}) {
    argParser
      ..addOption('dir', help: 'Golden folder with golden.json.', defaultsTo: p.join('test_data', 'golden'))
      ..addOption('output', abbr: 'o', help: 'Where check writes results and difference pictures.',
          defaultsTo: p.join('cts_out', 'golden'));
  }

  final CliContextHolder _holder;
  final bool update;

  @override
  String get name => update ? 'update' : 'check';

  @override
  String get description => update
      ? 'Re-run the golden pages and overwrite the saved results.'
      : 'Re-run the golden pages (default settings, mock translator, CPU) and compare with the saved results.';

  @override
  Future<int> run() async {
    final ctx = _holder.context;
    final dir = argResults!.option('dir')!;
    final manifestFile = File(p.join(dir, 'golden.json'));
    if (!manifestFile.existsSync()) {
      ctx.err.writeln('No ${manifestFile.path}. Run from the repository root or pass --dir.');
      return ExitCodes.failure;
    }
    final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
    final maxSide = (manifest['max_side'] as num?)?.toInt() ?? 1000;
    final minPsnr = (manifest['min_psnr'] as num?)?.toDouble() ?? 30;
    final minIou = (manifest['min_iou'] as num?)?.toDouble() ?? 0.9;
    final outDir = Directory(argResults!.option('output')!);
    if (!update) outDir.createSync(recursive: true);

    final pipelines = <String, PagePipeline>{};
    final report = <Map<String, Object?>>[];
    var failed = 0;
    for (final entry in (manifest['pages'] as List).cast<Map<String, Object?>>()) {
      final imagePath = p.normalize(p.join(dir, entry['image'] as String));
      final source = entry['from'] as String, target = entry['to'] as String;
      final stem = p.basenameWithoutExtension(imagePath);
      final PagePipeline pipeline;
      try {
        pipeline = pipelines['$source>$target'] ??= await _offlinePipeline(ctx, source, target);
      } on ModelNotInstalledException catch (e) {
        ctx.err.writeln(e);
        return ExitCodes.failure;
      }
      final image = await ImageCodec.readFile(imagePath);
      final r = await pipeline.run(image, PluginContext(log: ctx.services.appLog, page: stem));
      final summary = _summary(r);
      final small = fitWithin(r.rendered, maxSide);
      final jsonFile = File(p.join(dir, '$stem.json'));
      final jpgFile = File(p.join(dir, '$stem.jpg'));
      if (update) {
        jsonFile.writeAsStringSync('${_pretty.convert(summary)}\n');
        jpgFile.writeAsBytesSync(ImageCodec.encodeJpeg(small, quality: 92));
        ctx.say('$stem: saved (${r.blocks.length} blocks, ${r.items.length} text items)');
        report.add({'page': stem, 'updated': true});
        continue;
      }
      final problems = <String>[];
      if (!jsonFile.existsSync() || !jpgFile.existsSync()) {
        problems.add('no saved result; run cts golden update');
      } else {
        problems.addAll(_compareSummaries(jsonDecode(jsonFile.readAsStringSync()) as Map<String, Object?>, summary, minIou));
        final golden = ImageCodec.decode(jpgFile.readAsBytesSync());
        if (golden.width != small.width || golden.height != small.height) {
          problems.add('image size ${small.width}x${small.height}, saved ${golden.width}x${golden.height}');
        } else {
          final d = compareImages(golden, small);
          if (d.psnr < minPsnr) {
            problems.add('image differs: $d (need PSNR ≥ $minPsnr)');
            File(p.join(outDir.path, '$stem.diff.png')).writeAsBytesSync(ImageCodec.encodePng(diffImage(golden, small)));
          }
        }
      }
      File(p.join(outDir.path, '$stem.png')).writeAsBytesSync(ImageCodec.encodePng(small));
      File(p.join(outDir.path, '$stem.json')).writeAsStringSync('${_pretty.convert(summary)}\n');
      if (problems.isNotEmpty) failed++;
      ctx.say('$stem: ${problems.isEmpty ? 'ok' : 'FAILED'}');
      for (final pr in problems) {
        ctx.say('  - $pr');
      }
      report.add({'page': stem, 'ok': problems.isEmpty, 'problems': problems});
    }
    if (!update) ctx.say(failed == 0 ? 'All ${report.length} golden pages match.' : '$failed of ${report.length} pages differ; see ${outDir.path}');
    if (ctx.json) ctx.printJson({'ok': failed == 0, 'pages': report});
    return failed == 0 ? ExitCodes.ok : ExitCodes.failure;
  }

  static Map<String, Object?> _summary(PageResult r) => {
        'blocks': [
          for (final b in r.blocks)
            {
              'xyxy': [b.xyxy.x1, b.xyxy.y1, b.xyxy.x2, b.xyxy.y2],
              'text': b.text,
              'translation': b.translation,
            }
        ],
        'items': [
          for (final i in r.items) {'text': i.text, 'font_size_pt': i.fontSizePt, 'x': i.x.round(), 'y': i.y.round()}
        ],
      };

  static List<String> _compareSummaries(Map<String, Object?> saved, Map<String, Object?> now, double minIou) {
    final problems = <String>[];
    final a = (saved['blocks'] as List).cast<Map<String, Object?>>();
    final b = (now['blocks'] as List).cast<Map<String, Object?>>();
    if (a.length != b.length) problems.add('${b.length} blocks, saved ${a.length}');
    BBox box(Map<String, Object?> m) {
      final v = (m['xyxy'] as List).cast<num>();
      return BBox(v[0].toInt(), v[1].toInt(), v[2].toInt(), v[3].toInt());
    }

    for (var i = 0; i < a.length && i < b.length; i++) {
      final iou = box(a[i]).iou(box(b[i]));
      if (iou < minIou) problems.add('block $i moved (IoU ${iou.toStringAsFixed(3)})');
      if (a[i]['text'] != b[i]['text']) problems.add('block $i text "${b[i]['text']}", saved "${a[i]['text']}"');
    }
    final ia = (saved['items'] as List).cast<Map<String, Object?>>();
    final ib = (now['items'] as List).cast<Map<String, Object?>>();
    if (ia.length != ib.length) problems.add('${ib.length} text items, saved ${ia.length}');
    for (var i = 0; i < ia.length && i < ib.length; i++) {
      if (ia[i]['font_size_pt'] != ib[i]['font_size_pt'] || ia[i]['text'] != ib[i]['text']) {
        problems.add('text item $i: ${ib[i]['font_size_pt']} pt "${ib[i]['text']}", '
            'saved ${ia[i]['font_size_pt']} pt "${ia[i]['text']}"');
      }
    }
    return problems;
  }
}

/// `cts bench`: timings per stage.
class BenchCommand extends CtsCommand {
  BenchCommand(super.holder) {
    argParser
      ..addOption('from', help: 'Source language.', defaultsTo: 'English')
      ..addOption('to', help: 'Target language.', defaultsTo: 'Russian')
      ..addOption('repeat', help: 'Runs per page after the first (warm-up) run.', defaultsTo: '2')
      ..addFlag('gpu', negatable: false, help: 'Use the GPU (DirectML).');
  }

  @override
  String get name => 'bench';

  @override
  String get description => 'Time every pipeline stage (default settings, mock translator, nothing sent). '
      'The first run of each page is reported separately (models loading, caches).';

  @override
  String get invocation => 'cts bench <image>... [--repeat 2] [--gpu]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty) usageException('Give at least one image.');
    final repeat = int.tryParse(args.option('repeat')!) ?? usageException('--repeat must be a number.');
    final source = args.option('from')!, target = args.option('to')!;
    if (Languages.byName(source) == null || Languages.byName(target) == null) usageException('Unknown language.');
    final gpu = args.flag('gpu');
    final loadSw = Stopwatch()..start();
    final PagePipeline pipeline;
    try {
      pipeline = await _offlinePipeline(ctx, source, target, gpu: gpu);
    } on ModelNotInstalledException catch (e) {
      ctx.err.writeln(e);
      return ExitCodes.failure;
    }
    final loadMs = loadSw.elapsedMilliseconds;
    final first = <String, List<int>>{}, warm = <String, List<int>>{};
    for (final input in args.rest) {
      final image = await ImageCodec.readFile(input);
      for (var run = 0; run <= repeat; run++) {
        final r = await pipeline.run(image, PluginContext(log: ctx.services.appLog, page: p.basename(input)));
        final into = run == 0 ? first : warm;
        for (final MapEntry(:key, :value) in {...r.timingsMs, 'total': r.totalMs}.entries) {
          (into[key] ??= []).add(value);
        }
      }
      ctx.say('${p.basename(input)}: done');
    }
    int median(List<int>? v) {
      if (v == null || v.isEmpty) return 0;
      final s = [...v]..sort();
      return s[s.length ~/ 2];
    }

    final stages = first.keys.toList();
    final rows = {
      for (final s in stages) s: {'first_ms': median(first[s]), 'median_ms': median(warm[s])},
    };
    final peakMb = ProcessInfo.maxRss ~/ (1024 * 1024);
    ctx.say('');
    ctx.say('stage          first run   median (${repeat}x)');
    for (final s in stages) {
      ctx.say('${s.padRight(14)} ${'${rows[s]!['first_ms']} ms'.padLeft(9)}   ${repeat == 0 ? '-' : '${rows[s]!['median_ms']} ms'}');
    }
    ctx.say('models loaded in $loadMs ms; peak memory $peakMb MB; ${gpu ? 'GPU (DirectML)' : 'CPU'}');
    if (ctx.json) {
      ctx.printJson({
        'ok': true,
        'pages': args.rest.length,
        'repeat': repeat,
        'gpu': gpu,
        'load_ms': loadMs,
        'peak_rss_mb': peakMb,
        'stages': rows,
      });
    }
    return ExitCodes.ok;
  }
}

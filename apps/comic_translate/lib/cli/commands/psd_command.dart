/// `cts psd info`: what is inside a Photoshop file, as the program reads it.
library;

import 'package:args/command_runner.dart';
import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import '../cli.dart';
import '../cli_context.dart';

class PsdCommand extends Command<int> {
  PsdCommand(CliContextHolder holder) {
    addSubcommand(_PsdInfo(holder));
  }

  @override
  String get name => 'psd';

  @override
  String get description => 'Look into Photoshop files (.psd, .psb).';
}

class _PsdInfo extends CtsCommand {
  _PsdInfo(super.holder);

  @override
  String get name => 'info';

  @override
  String get description => 'Size, layers and text layers of a PSD file, and how it would be opened.';

  @override
  String get invocation => 'cts psd info <file.psd>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) usageException('Give one .psd file.');
    final PsdDocument doc;
    try {
      doc = await readPsdFile(rest.single);
    } on Object catch (e) {
      ctx.err.writeln('${p.basename(rest.single)}: $e');
      return ExitCodes.failure;
    }
    final page = readPagePsd(doc);
    final layers = [
      for (final (l, path) in doc.flatLayers())
        {
          'name': l.name,
          if (path.isNotEmpty) 'group': path.join('/'),
          if (l.pixels case final px?) 'bounds': [px.left, px.top, px.left + px.width, px.top + px.height],
          if (l.hidden) 'hidden': true,
          if (l.text case final t?) 'text': t.text,
          if (l.text case final t?) 'font': t.font,
          if (l.text case final t?) 'font_size': t.fontSize,
        },
    ];
    if (ctx.json) {
      ctx.printJson({
        'width': doc.width,
        'height': doc.height,
        'merged_picture': doc.composite != null,
        'laid_out_by_comic_translate': page.ours,
        'page_data': page.meta != null,
        'unsupported': page.unsupported,
        'layers': layers,
      });
      return ExitCodes.ok;
    }
    ctx.say(
      '${p.basename(rest.single)}: ${doc.width}x${doc.height}, ${layers.length} layer(s)'
      '${page.ours ? ', laid out by Comic Translate' : ''}${page.meta != null ? ' (with page data)' : ''}',
    );
    for (final l in layers) {
      final group = l['group'] == null ? '' : '${l['group']}/';
      final text = l['text'] == null
          ? ''
          : ' "${'${l['text']}'.replaceAll('\n', r'\n')}" (${l['font']}, ${l['font_size']} px)';
      ctx.say('  $group${l['name']}${l['hidden'] == true ? ' [hidden]' : ''}$text');
    }
    if (page.unsupported.isNotEmpty) ctx.say('Not carried over on opening: ${page.unsupported.join(', ')}');
    return ExitCodes.ok;
  }
}

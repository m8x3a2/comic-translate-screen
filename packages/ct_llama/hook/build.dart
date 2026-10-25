// Fetches the pinned llama.cpp binaries and registers them as code assets.
//
// The download is cached in the hook's shared output directory and verified
// by SHA-256; nothing is downloaded again until the version changes.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:ct_llama/src/native_release.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;

    if (code.targetOS != OS.windows) {
      // Android arrives with the Android port.
      return;
    }
    if (code.targetArchitecture != Architecture.x64) {
      throw UnsupportedError('ct_llama: Windows ${code.targetArchitecture} is not supported yet');
    }

    final cacheDir = Directory.fromUri(input.outputDirectoryShared.resolve('llama-${LlamaNativeRelease.version}/'));
    final zip = File.fromUri(cacheDir.uri.resolve('llama-cpu-x64.zip'));
    await _ensureDownloaded(Uri.parse(LlamaNativeRelease.windowsZipUrl), zip, LlamaNativeRelease.windowsZipSha256);

    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final wanted = [
      for (final f in archive.files)
        if (f.isFile &&
            (LlamaNativeRelease.windowsLibraries.contains(f.name.split('/').last) ||
                LlamaNativeRelease.isCpuBackend(f.name.split('/').last)))
          f,
    ];
    for (final name in LlamaNativeRelease.windowsLibraries) {
      if (!wanted.any((f) => f.name.split('/').last == name))
        throw StateError('ct_llama: $name not found in ${zip.path}');
    }
    for (final entry in wanted) {
      final fileName = entry.name.split('/').last;
      final outFile = File.fromUri(input.outputDirectory.resolve(fileName));
      await outFile.writeAsBytes(entry.content, flush: true);
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: fileName.substring(0, fileName.length - '.dll'.length),
          linkMode: DynamicLoadingBundled(),
          file: outFile.uri,
        ),
      );
    }
  });
}

Future<void> _ensureDownloaded(Uri url, File target, String sha256Hex) async {
  if (target.existsSync() && await _sha256(target) == sha256Hex) return;
  await target.parent.create(recursive: true);
  final tmp = File('${target.path}.part');

  final client = HttpClient()..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('ct_llama: GET $url failed with HTTP ${response.statusCode}', uri: url);
    }
    final sink = tmp.openWrite();
    await response.pipe(sink);
  } finally {
    client.close(force: true);
  }

  final actual = await _sha256(tmp);
  if (actual != sha256Hex) {
    await tmp.delete();
    throw StateError('ct_llama: SHA-256 mismatch for $url: expected $sha256Hex, got $actual');
  }
  if (target.existsSync()) await target.delete();
  await tmp.rename(target.path);
}

Future<String> _sha256(File file) async => (await sha256.bind(file.openRead()).first).toString();

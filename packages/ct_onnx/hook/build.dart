// Fetches the pinned ONNX Runtime binaries and registers them as code assets.
//
// The download is cached in the hook's shared output directory and verified
// by SHA-256; nothing is downloaded again until the version changes.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:ct_onnx/src/native_release.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;

    if (code.targetOS != OS.windows) {
      // Android (onnxruntime-android AAR) arrives with the Android port.
      return;
    }
    if (code.targetArchitecture != Architecture.x64) {
      throw UnsupportedError('ct_onnx: Windows ${code.targetArchitecture} is not supported yet');
    }

    final cacheDir = Directory.fromUri(input.outputDirectoryShared.resolve('onnxruntime-${OrtNativeRelease.version}/'));
    final nupkg = File.fromUri(cacheDir.uri.resolve('onnxruntime-directml.nupkg'));
    await _ensureDownloaded(
      Uri.parse(OrtNativeRelease.windowsNupkgUrl),
      nupkg,
      OrtNativeRelease.windowsNupkgSha256,
    );

    final archive = ZipDecoder().decodeBytes(await nupkg.readAsBytes());
    for (final entryPath in OrtNativeRelease.windowsX64Files) {
      final entry = archive.findFile(entryPath) ??
          (throw StateError('ct_onnx: $entryPath not found in ${nupkg.path}'));
      final fileName = entryPath.split('/').last;
      final outFile = File.fromUri(input.outputDirectory.resolve(fileName));
      await outFile.writeAsBytes(entry.content, flush: true);

      final assetName = fileName.substring(0, fileName.length - '.dll'.length);
      output.assets.code.add(CodeAsset(
        package: input.packageName,
        name: assetName,
        linkMode: DynamicLoadingBundled(),
        file: outFile.uri,
      ));
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
      throw HttpException('ct_onnx: GET $url failed with HTTP ${response.statusCode}', uri: url);
    }
    final sink = tmp.openWrite();
    await response.pipe(sink);
  } finally {
    client.close(force: true);
  }

  final actual = await _sha256(tmp);
  if (actual != sha256Hex) {
    await tmp.delete();
    throw StateError('ct_onnx: SHA-256 mismatch for $url: expected $sha256Hex, got $actual');
  }
  if (target.existsSync()) await target.delete();
  await tmp.rename(target.path);
}

Future<String> _sha256(File file) async => (await sha256.bind(file.openRead()).first).toString();

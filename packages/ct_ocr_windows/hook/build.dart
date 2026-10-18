// Compiles the C++/WinRT wrapper around Windows.Media.Ocr (Windows only).

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets || input.config.code.targetOS != OS.windows) return;
    await CBuilder.library(
      name: 'ct_ocr_windows',
      assetName: 'ct_ocr_windows',
      sources: ['src/ct_ocr_windows.cpp'],
      language: Language.cpp,
      // C++20: MSVC 14.51+ removed the experimental coroutines C++/WinRT
      // uses under C++17.
      std: 'c++20',
      flags: ['/EHsc', '/utf-8', '/permissive-'],
      libraries: ['WindowsApp', 'ole32'],
    ).run(
      input: input,
      output: output,
      logger: Logger('')..onRecord.listen((r) => print(r.message)),
    );
  });
}

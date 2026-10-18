# Contributing

Thanks for helping! This project is a Dart/Flutter rewrite based on
[ogkalu2/comic-translate](https://github.com/ogkalu2/comic-translate).

## Setup (Windows)

1. Install Flutter 3.47+ and Visual Studio 2022 Build Tools with the
   "Desktop development with C++" workload and the "C++ ATL" component
   (`Microsoft.VisualStudio.Component.VC.ATL`, needed by flutter_secure_storage).
2. Enable Windows Developer Mode (needed for Flutter plugins).
3. From the repository root:

```bash
flutter pub get
```

Disable Flutter's experimental "record use" feature once:

```bash
flutter config --no-enable-record-use
```

With it on, dartcv4 restricts the exports of its native library to the
functions recorded in the previous release build, so a release build that
starts using a new OpenCV function fails with "Failed to lookup symbol". If
that already happened, run `flutter clean` in `apps/comic_translate` and
delete `.dart_tool/hooks_runner/dartcv4` and
`.dart_tool/hooks_runner/shared/dartcv4/dartcv_keep.txt`.

The first build compiles the OpenCV wrapper of `dartcv4` and downloads ONNX
Runtime through build hooks. Compiling takes roughly 10–15 minutes on a laptop
and happens once per build mode (`dart test`, Flutter debug/tests, Flutter
release); results are cached in `.dart_tool/hooks_runner` afterwards.

To regenerate the ONNX Runtime bindings (only when upgrading ONNX Runtime) you
also need LLVM: `winget install LLVM.LLVM`, then
`cd packages/ct_onnx && dart run tool/ffigen.dart`.

Parity tests in `ct_providers` need the models they test
(`cts models download rtdetr-v2-int8 ppocr-v5-rec-en ...`) and skip themselves
otherwise. The native Windows OCR library is compiled by a build hook with the
Visual Studio C++ tools (C++/WinRT headers come with the Windows SDK).

## Checks before a pull request

```bash
cd packages/ct_core && dart analyze && dart test
cd packages/ct_onnx && dart analyze && dart test
cd packages/ct_ocr_windows && dart analyze && dart test
cd packages/ct_providers && dart analyze && dart test
cd apps/comic_translate && flutter analyze && flutter test
```

and, when native or rendering code changed:

```bash
cd apps/comic_translate && flutter build windows
build/windows/x64/runner/Release/cts.exe doctor
```

When the pipeline or rendering changed, check the golden pages from the
repository root (needs the default models: `cts models download --all`):

```bash
apps/comic_translate/build/windows/x64/runner/Release/cts.exe golden check
```

If a difference is intended, run `golden update`, look at the new pictures in
`test_data/golden/` and commit them with the change.

## Guidelines

- Keep `ct_core` free of Flutter imports so it stays testable with `dart test`.
- New engines are plugins: one file plus one registry line ([docs/PLUGINS.md](docs/PLUGINS.md)).
- Anything that sends data off the device must declare its privacy level and be
  covered by the UI warning. No telemetry.
- Never log secrets or personal data directly; diagnostics go through the
  `EventLog`/`Redactor` ([docs/DIAGNOSTICS.md](docs/DIAGNOSTICS.md)).
- When porting code from the original, mention the source file in a comment and
  add a parity or unit test.
- Tests must not need internet access or real API keys.
- Test images must have a license compatible with redistribution; record it in
  `test_data/LICENSES.md`.

## Commit messages

Short imperative subject line, optional body explaining why.

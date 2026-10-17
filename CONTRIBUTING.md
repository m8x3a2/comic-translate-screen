# Contributing

Thanks for helping! This project is a Dart/Flutter rewrite based on
[ogkalu2/comic-translate](https://github.com/ogkalu2/comic-translate).

## Setup (Windows)

1. Install Flutter 3.47+ and Visual Studio 2022 Build Tools with the
   "Desktop development with C++" workload.
2. Enable Windows Developer Mode (needed for Flutter plugins).
3. From the repository root:

```bash
flutter pub get
```

## Checks before a pull request

```bash
cd packages/ct_core && dart analyze && dart test
cd apps/comic_translate && flutter analyze && flutter test
```

and, when native or rendering code changed:

```bash
cd apps/comic_translate && flutter build windows
build/windows/x64/runner/Release/cts.exe doctor
```

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

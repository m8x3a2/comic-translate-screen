# Comic Translate Screen

[Русская версия](README.ru.md)

Translate comics, manga, manhwa and webtoons on your own computer: detect text,
recognize it, translate it, clean the bubbles and typeset the translation.

> **Independent project.** Comic Translate Screen is a Dart/Flutter rewrite based on
> [ogkalu2/comic-translate](https://github.com/ogkalu2/comic-translate) (Apache-2.0).
> It is **not** an official version of Comic Translate and is not affiliated with
> its authors.

## Status

Stage 1 is in progress: porting the original application to Flutter for Windows 11,
with Android to follow. See the [architecture](docs/ARCHITECTURE.md) for the roadmap.

| Milestone | Scope | State |
|---|---|---|
| M0 | Project skeleton, `cts` CLI, diagnostics | done |
| M1 | Core model, plugin registry, settings and secrets, model manager, ONNX Runtime, OpenCV | done |
| M2 | Text and bubble detection (RT-DETR-v2), line splitting, `cts detect`; identical output to the original on the test pages | done |
| M3 | OCR: PaddleOCR and manga-ocr (identical output to the original), Windows OCR, `cts ocr` | done |
| M4 | Translation: the original's LLM protocol, an OpenAI-compatible provider (OpenRouter, OpenAI, local servers), an offline test translator, `cts translate` | done |
| M5 | Text removal: mask, fast fill of uniform bubbles, AOT and LaMa inpainting (identical output to the original), `cts mask`, `cts inpaint` | done |
| M6 | Text rendering; the whole pipeline in one command (`cts process`); golden checks and benchmarks | done |
| M7 | The window: open images, folders, comic archives and PDF; page list and viewer; "Translate all" in the background with progress, stop and report; settings; models folder and offline model import; enlarging small pages so the translation stays sharp | done |
| M8–M12 | Manual mode and editing, projects and export, webtoon mode, PSD, polish | planned |

## Principles

- **Local by default.** Detection, OCR and inpainting run on your machine. Anything
  that sends data over the network is clearly marked in the UI and asks first.
- **No accounts, no credits, no telemetry.**
- **API keys** are stored in the operating system's secure storage and never written
  to logs or bug reports.
- **Pluggable.** OCR, translation, detection and inpainting engines share common
  interfaces; adding a provider is one file plus one registration line
  (see [docs/PLUGINS.md](docs/PLUGINS.md)).
- Neural networks run through native runtimes (ONNX Runtime, later llama.cpp) via FFI.

## Differences from the original (stage 1)

- OCR runs locally, as in the original's default: PaddleOCR (PP-OCRv5/v6, ONNX)
  and manga-ocr for Japanese. New: the OCR built into Windows (Windows.Media.Ocr;
  ML Kit on Android later) as a light alternative that needs no model download.
  Paid cloud OCR is removed.
- Translation: an offline test translator and one OpenAI-compatible provider
  (works with OpenRouter, OpenAI, DeepSeek, LM Studio, Ollama, llama.cpp server)
  with the original's prompt. Other providers will return one by one. A server
  on `localhost` counts as local; anything else is marked and needs approval.
- New: small pages (screenshots, low-resolution scans) are enlarged before the
  translation is drawn, so the letters stay sharp when the result is viewed or
  printed larger (setting "Enlarging": automatic by default, ×2/×3/×4 or to a
  width; the neural upscalers are planned for stage 2).
- Models can live in any folder and can be installed from files copied from
  another computer (no internet needed).
- Removed: sign-in, accounts, credits, paid cloud OCR, automatic update checks.

## Building from source (Windows)

Requirements: Flutter 3.47+ (Dart 3.13+), Visual Studio 2022 Build Tools with the
"Desktop development with C++" workload and the "C++ ATL" component (needed by the
secure-storage plugin), Windows Developer Mode enabled.

```bash
flutter pub get
cd apps/comic_translate
flutter build windows
```

The build produces two executables in `apps/comic_translate/build/windows/x64/runner/Release/`:

- `comic_translate.exe`: the application;
- `cts.exe`: the command-line interface ([docs/CLI.md](docs/CLI.md)).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Command-line interface](docs/CLI.md)
- [Test mode and bug reports](docs/DIAGNOSTICS.md)
- [Contributing](CONTRIBUTING.md)

## License

[Apache License 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.

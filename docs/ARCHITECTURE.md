# Architecture

Comic Translate Screen is a Dart/Flutter rewrite of
[ogkalu2/comic-translate](https://github.com/ogkalu2/comic-translate). This document
describes the target structure; parts that are not implemented yet are marked
with their milestone.

## Pipeline

The same pipeline as the original (`pipeline/batch_processor.py`), expressed as an
ordered list of stages so that new stages can be inserted without touching the rest:

```
load page → detect → OCR → translate → mask → inpaint → layout text → render / export
```

| Stage | Stage 1 implementation | Ported from |
|---|---|---|
| detect | RT-DETR-v2 (`detector-v4-s_int8.onnx`), slicing of tall pages, bubble association, heuristic line segmentation | `modules/detection/*` |
| OCR | `default` = the original's Default: PaddleOCR recognition of each heuristic line (PP-OCRv5/v6 per script, ONNX) and manga-ocr for Japanese; `windows_ocr` (Windows.Media.Ocr through a C++/WinRT library) as a light alternative (ML Kit on Android later) | `modules/ocr/ppocr/*`, `modules/ocr/manga_ocr/mobile/*`, `modules/ocr/factory.py`, `modules/ocr/processor.py` |
| translate | `mock` (offline) and `openai_compatible` (the original's Custom); same prompt, `block_N` JSON protocol, filters and upper-case handling | `modules/translation/*`, `modules/utils/translator_utils.py` |
| mask | connected components inside blocks, bubble clipping, dilation | `modules/utils/image_utils.py` |
| inpaint | AOT (default), LaMa, MI-GAN via ONNX Runtime; HD strategies; fast fill of uniform bubbles | `pipeline/inpainting.py`, `modules/inpainting/*` |
| layout + render | font-size fitting and wrapping with dart:ui (hyphenation, no-space languages, vertical CJK), outline, smart colour | `modules/rendering/*` |

A future upscaling stage (stage 2) is inserted before `inpaint`.

### Deliberate differences from the original

- The PP-OCR line *detector* is not ported. The original runs it only when no
  block has text lines; the heuristic line splitter always produces lines, and a
  block without lines is read as a whole instead.
- Automatic source language ("Auto") needs the script-identification model and
  arrives with M12; until then a language must be chosen.
- `windows_ocr` is new (system OCR, no download).
- Small text (screenshots, low-resolution scans) is read on an enlarged copy
  of the page: when the smaller text lines are thinner than about 30 px, the
  page is enlarged (Lanczos, up to 4×) and re-split into lines before OCR
  (setting `tools.upscale_small_text`, on by default). On 400×570 screenshots
  this turns unreadable OCR into usable text; on normal pages it changes little.
- For Cyrillic source languages, Latin look-alike letters that OCR returns in
  Cyrillic words ("HET" for "НЕТ") are replaced with Cyrillic ones.
- Translation: a reply with stray braces after its JSON is still read (the
  original fails the page); the Authorization header is omitted when no API key
  is set; the length-limit field name is configurable for older servers.

## Packages (pub workspace)

```
apps/comic_translate/   Flutter app: GUI and CLI share one Dart entry point
  lib/main.dart         --cts-cli flag → CLI, otherwise GUI
  lib/cli/              cts commands (package:args)
  lib/gui/              interface shells; "Full" in stage 1, "Simple" in stage 2   (M7+)
  lib/render/           text layout and rasterization with dart:ui                 (M6)
  windows/runner/       main.cpp → comic_translate.exe, cli_main.cpp → cts.exe
packages/ct_core/       pure Dart: models, pipeline, plugin interfaces, registry,
                        image-processing ports, project format, diagnostics
packages/ct_onnx/       FFI bindings to the ONNX Runtime C API + build hook that
                        fetches pinned official binaries                            (M1)
packages/ct_ocr_windows/ Windows.Media.Ocr: C++/WinRT library with a C ABI, compiled
                        by a build hook                                             (M3)
packages/ct_providers/  plugin implementations: detector, OCR engines, inpainters,
                        translators                                                 (M2+)
tools/                  developer scripts; reference/ generates parity data from
                        the original Python code                                    (M2)
test_data/              test pages (with licenses), reference outputs, goldens      (M2)
```

`ct_core` never imports Flutter, so its logic is tested with plain `dart test`.
Code that needs the Flutter engine (dart:ui text rendering, plugins) lives in the app.

## Why `cts.exe` is a second runner executable

The CLI must be able to do everything the GUI does, including text rendering, so
that results are identical and testable without a window. `cts.exe` is built from
the same CMake project as the GUI with a console-subsystem `wmain`
(`windows/runner/cli_main.cpp`). It creates the Flutter window but never shows it,
passes `--cts-cli` to Dart and returns the exit code set by Dart's `exit()`. Both
executables share `flutter_windows.dll`, `data/` (assets, AOT snapshot) and plugins.

## Native code

Rule: no neural-network inference in pure Dart.

- **ONNX Runtime** through our own thin FFI layer (`ct_onnx`). A build hook downloads
  the official binaries with a pinned version and SHA-256: DirectML + CPU on Windows,
  the Android AAR later. llama.cpp (stage 2) follows the same pattern.
- **OpenCV** through `dartcv4` for classical image processing. The original's `imkit`
  mirrors the cv2 API, so ports map almost one-to-one.
- **Windows.Media.Ocr** through a small C++/WinRT library with a C ABI.

## Plugins

Detection, OCR, translation, inpainting and text rendering are plugins with common
interfaces in `ct_core` (M1). Each plugin declares a `PluginInfo`: id, display name,
privacy level (`local`, `lan`, `cloud`), supported platforms, a settings schema (the
settings UI is generated from it) and the models it needs. Adding a provider means
one file in `ct_providers/lib/src/<kind>/` and one line in its registry. See
[PLUGINS.md](PLUGINS.md).

## Privacy and secrets

- Everything runs locally by default. Plugins with privacy level `cloud` or `lan` are
  marked in the UI and require confirmation on first use. Model downloads show the
  source host and size before starting.
- API keys live in the OS secure storage (`flutter_secure_storage`: DPAPI/Credential
  Manager on Windows, Keystore on Android). Every value read from it is registered
  with the `Redactor`, which masks it in all logs, artifacts and bug reports.
- There is no telemetry and no automatic network access (the original's update check
  was removed).

## Diagnostics

See [DIAGNOSTICS.md](DIAGNOSTICS.md): JSONL logs, per-run folders with stage
artifacts and timings, and `cts report` for bug reports.

## Data locations

`%LOCALAPPDATA%\ComicTranslateScreen` on Windows (local, not roaming: models are
large). Override with `--data-dir` or the `CTS_DATA_DIR` environment variable.

```
logs/app.jsonl     process log (GUI and CLI)
runs/<run_id>/     test-mode runs
models/            downloaded models
reports/           bug reports, self-test output
settings.json      settings (no secrets)
```

## Stage 1 milestones

M0 skeleton, CLI, diagnostics → M1 core, plugin registry, model manager, ONNX Runtime →
M2 detection → M3 OCR (PaddleOCR ONNX, then Windows OCR) → M4 translation → M5 mask and inpainting →
M6 text rendering, end-to-end `cts process`, goldens → M7 GUI basics and automatic mode →
M8 manual mode and editing → M9 projects and export → M10 webtoon mode → M11 PSD →
M12 UI languages, automatic source language, documentation.

# Comic Translate Screen

[Русская версия](README.ru.md)

Translate comics, manga, manhwa and webtoons on your own computer: detect text,
recognize it, translate it, clean the bubbles and typeset the translation.

Author: [m8x3a2](https://github.com/m8x3a2).

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
| M8 | Manual mode: single steps on a page (find text, recognize, translate, mask, clean); boxes, brush and eraser; moving, resizing and turning the translation; per-bubble font, size, colours and outline; undo/redo; find and replace; keyboard shortcuts | done |
| M8.1 | Full screen (F11); API keys: show what you typed, the last 4 characters of a saved key, replace and delete; OpenRouter key balance on request; a per-model usage counter kept on this computer | done |
| M9 | Projects `.ctsproj` (save, open, recent, autosave, crash recovery); export to a folder, ZIP, CBZ, CB7, PDF: translations, cleaned pages, texts, by chapter; added fonts; languages per page; steps on several pages; all-boxes tools; embedded PDF pictures | done |
| M9.1 | Settings reset (one section or all); a solid text outline at any width; Space / Ctrl + left button moves the page; models grouped (main, by language, extra) with "download what is needed", "download all", "check all"; an "i" explaining models and settings | done |
| M10 | Webtoon mode: all pages as one strip (wheel scrolls, Ctrl + wheel zooms, light on long chapters); a bubble cut by the edge between two pages is read, cleaned and drawn whole; very tall pictures shown in tiles; export of the strip as one picture or cut again into parts along even rows | done |
| M11 | PSD files for Photoshop: each page with the original, the cleaned places and the translation as editable text layers (font, size, colours, outline, rotation); opening PSD files of this program, of the original Comic Translate and of other programs; `cts psd info` | done |
| M12 | Polish | planned |

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
- Projects save themselves by default (the original's autosave is off by
  default); the undo history is not kept in a project. A PDF page gives its
  embedded picture only when it is one picture with nothing visible drawn over
  it (the original takes the first picture of any page and could lose text);
  other pages are rendered at 200 dpi (the original: 72).
- New: for OpenRouter, a button shows what is left of the key's limit, and the program
  keeps its own per-model usage counter (requests, tokens, cost, today and in total),
  stored only on this computer and never sent anywhere.
- Removed: sign-in, accounts, credits, paid cloud OCR, automatic update checks.

## New since stage 1 (stage 2, in progress)

- **Exchange with a chat AI by hand**: crops of the bubbles (or text) go to ChatGPT, Gemini or Claude
  in your own browser, and their answer is pasted back; the program itself sends nothing.
- **Offline translation** English ↔ Russian (OPUS-MT, no internet and no keys).
- **Comics / Sites and games**: screenshots of sites, games and visual novels are read line by line
  (PP-OCRv5 line detector) instead of bubble by bubble.
- **Preparing small text for reading**: only the pieces with thin lines are enlarged before OCR —
  plain ×1.5 / ×2, or neural networks on three levels (waifu2x CUNet, waifu2x Swin-UNet, Fatality
  Comix by Twittman, CC BY-NC-SA 4.0, the default for comics). Words glued together on tiny text can be
  split by a dictionary; tiny text gets advice on what to do.
- **Text removal levels** Simple / Medium / High: Medium and High find the letters themselves
  (comic-text-detector, GPL-3.0, separate download), so the network repaints the letters and not the
  drawing around them; High repaints with LaMa (the default).
- **The look of the original**: the translation takes the letter case, bold, italic and outline of
  the source lettering; long Russian words break by syllables where that keeps the letters larger;
  optional lines along the bubble's oval and "size as in the original". 16 free fonts with Cyrillic
  come with the program, and "Suggest a font" names the ones closest to the page's lettering.
- **The look of single words**: a selected word or sign gets its own font, size, colour, outline and
  style; named styles change every bubble that uses them; words a chat marks with stars become bold.
- Each step shows how long it took, and the report of "Translate all" gives the time of every step.
- An unexpected error builds a bug report by itself (kept on this computer).

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
- [How to test and report bugs](docs/TESTING.ru.md) (Russian); F1 in the app lists the keyboard shortcuts, F11 switches full screen
- [Contributing](CONTRIBUTING.md)

## License

[Apache License 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.

If you use this project — change it, build your own on top of it, or take parts of
it — keep the [NOTICE](NOTICE) file (the license requires it) and please credit the
author, **m8x3a2**, with a link to https://github.com/m8x3a2/comic-translate-screen.

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
| mask | Otsu content components inside each block, text-like component selection, bubble interior segmentation (ellipse fallback), clipping and dilation | `modules/utils/image_utils.py`, `modules/detection/utils/content.py` |
| inpaint | fast flat fill of uniform bubbles; the rest by AOT (default) or LaMa via ONNX Runtime, by patches or on the whole page (the original's cost model), with the Resize / Crop / Original high-resolution strategies | `pipeline/inpainting.py`, `modules/inpainting/*` |
| layout + render | render areas (5% inset), greedy wrapping with hyphen handling and no-space languages, binary search for the largest font size that fits (outline included), smart colour, upper case; measured and drawn with dart:ui (bundled Pangolin font, system fallbacks for CJK), outline as in Qt, simplified vertical CJK, long pages drawn in 4096 px strips | `modules/rendering/render.py`, `pipeline/batch_processor.py` |

A future upscaling stage (stage 2) is inserted before `inpaint`.

### Deliberate differences from the original

- The original runs the PP-OCR line detector only when no block has text
  lines, and reads a hand-drawn box among detected ones as one line. Here
  every block without lines (drawn by hand, or resized) is split by the
  heuristic line splitter just before reading, so it also counts towards
  enlarging small text; only if the heuristics give up is it read as a whole.
- "Comics / Sites and games" (new, `tools.content`): sites, games and visual
  novels have lines of ordinary text, which the comic detector mostly misses
  (a phone screenshot: 1 word of 136). For them the PP-OCRv5 line detector
  (`ppocr_lines`, `ppocr_det.dart`) is a detector of its own: the
  preprocessing, DB post-processing and line merging are the original's
  (`test_data/reference/ppocr_lines.json`, same pieces within 2 px on every
  test page; the polygon fill matches mahotas), the lines are then gathered
  into paragraph blocks (`groupLinesIntoBlocks`, new). Boxes are grown by 1.4
  instead of 2.0: the original's tall boxes make the recognizer misread long
  lines (English game screenshots: 93 % of words right against 71 %; the
  comic detector: 65 %). Pieces side by side are merged only across one line
  height (the original allows two, or 8 % of the page), so that two columns
  of a phone screenshot stay apart; blocks are read row by row, each row from
  the left. These lines are kept (`fixed_lines`) when the page
  is enlarged for reading.
- A moved box takes its lines, bubble and outline along (the original keeps
  them in place); a resized one loses its lines and keeps its bubble only while
  it is still inside it.
- Automatic source language ("Auto", M12) is the original's: the OSD LSTM
  model (Tesseract's script detector in ONNX, `osd-script-id`) reads the
  largest line of each block, and each block is read by the recognizer of its
  script (Latin, Cyrillic, Japanese, Hangul, Chinese), or of the page's main
  script when its own is unclear. Differences: scripts are identified inside
  the OCR step, on the page as prepared for reading (enlarged when its text is
  small), not right after detection; the translator is told the language the
  scripts give (Japanese, Korean, Chinese, Russian; the original tells local
  LLMs the word "Auto"), and "text in any language" for Latin-script or mixed
  pages; a page found to be Japanese is read right to left in "Translate all"
  (single steps keep the detection order, as the original always does for
  "Auto"). `windows_ocr` takes the installed Windows language of each script
  (any Latin-script one for Latin, English first). On the Korean test page the
  original takes the text for Latin (its line splitter cuts the block as
  vertical text, so the model reads a rotated line); here the page's small
  text is read enlarged and is found Korean (with the text preparation off
  the result is the original's). Latin pages are read by the Latin
  recognizer, which sometimes adds accents to English (HÁPPENS); English is
  still the default source language and reads English more accurately.
- `windows_ocr` is new (system OCR, no download).
- Small text (screenshots, low-resolution scans) is prepared for reading
  (new, step 2 of the plan; `reading_scale.dart`, `TextUpscaler` plugins of
  kind `textPrep`): blocks whose lines are thinner than 20 px are cut out
  with an 8 px margin, enlarged and put together on canvases (at most 16 Mpx
  each), re-split into lines and read there; on such a page blocks with lines
  up to 64 px (or with none found) are enlarged too, since on tiny text the
  splitter takes several lines for one. Other blocks, and pages without small
  text, are read as they are. Choices (`tools.text_prep` for comics,
  `tools.screen_text_prep` for sites and games): off, plain Lanczos ×1.5 or
  ×2, and neural networks ×2 — waifu2x CUNet (Simple), waifu2x Swin-UNet
  (Medium, the default for comics), Fatality Comix ×4 brought to ×2 (High,
  CC-BY-NC-SA, converted to ONNX here and published in this project's
  releases); sites and games default to plain ×1.5. A network whose model is
  missing gives way to plain ×2. Until 0.1.2 the whole page was enlarged to
  36 px lines (≈×3), which merged the gaps between words. The experiment of
  step 2 (30 networks and factors on manga screenshots, reduced comic pages
  and Russian webtoon strips) chose the levels; the program reproduces its
  numbers, and the networks its output pixels
  (`test_data/reference/text_prep.json`).
- For Cyrillic source languages, Latin look-alike letters that OCR returns in
  Cyrillic words ("HET" for "НЕТ") are replaced with Cyrillic ones (setting
  `tools.fix_cyrillic_lookalikes`, off by default; never applied to other
  source languages).
- Glued words (new, `glued_words.dart`): English words the OCR read as one on
  tiny text ("REALLIFE") are split into dictionary words, by word frequency
  (the SymSpell list, 80 000 words, bundled in `assets/dict`). Only words
  missing from the dictionary are split, short pieces must be among the 1 000
  most frequent words, letters never change. A button of the text panel (page
  or selected pages, one block) and `tools.split_glued_words` (after OCR, off
  by default). On the OCR output of the step 2 experiment: 8 % more right
  words, fewer wrong ones.
- Very small text (new): each block remembers its line thickness on the page
  (`line_px`, measured before reading). Below 14 px the translator is told
  that words may be glued and letters misread; below 12 px, where even the
  networks get about one word in five wrong, the text panel advises the High
  level or a larger screenshot.
- Offline translation (new, `opus_mt`): OPUS-MT English ↔ Russian (Helsinki-NLP,
  CC-BY 4.0; int8 ONNX exports of Xenova, 110 MB per direction) on the
  processor (int8 models do not run on DirectML). The SentencePiece tokenizer
  (`sentencepiece.dart`: model file, `nmt_nfkc` character map, unigram
  Viterbi) and greedy decoding match the Python `sentencepiece` and the same
  models run from Python (`test_data/reference/opus_mt.json`). Comic text is
  prepared first: capitals in sentence case, hyphen breaks joined, each
  sentence translated on its own (the models drop sentences of long inputs).
  "Better" is a beam search of 4 (length-normalized, pad banned, as the
  models' generation config). About 0.4 s (fast) / 0.7 s (better) per bubble
  on the owner's i5-8265U. NLLB-200 600M was compared and left out (6× slower,
  950 MB, invents text on short lines).
- MI-GAN is not included (its download URL in the original returns 404).
- Translator errors are sorted by kind (key refused, no credits, wrong address
  or model, no connection, rate limit, server error, timeout, unreadable
  reply). Rate limits, server errors and lost connections are sent again
  twice (after 2 s and 6 s, or the server's Retry-After). A batch run (GUI and
  `cts process`) stops at once on errors every page would repeat (key,
  credits, address, connection) and after three failed pages in a row; the
  original fails each page and goes on. A reply without any translation is
  reported as an error instead of leaving the page silently untranslated.
- Translation: a reply with stray braces after its JSON is still read (the
  original fails the page); the Authorization header is omitted when no API key
  is set; the length-limit field name is configurable for older servers.
- Usage and key balance (new, M8.1): every answered request is reported through
  `PluginContext.reportUsage` (tokens and cost from the reply's `usage`, or about
  4 characters per token when a server sends none) and counted in `usage.json`
  by `UsageLog`, per plugin, server and model, today and in total, from the GUI
  worker and from `cts`. Plugins whose service can tell what is left of a key
  declare `PluginInfo.keyStatus`; for `openai_compatible` that is OpenRouter's
  `GET /api/v1/key`, sent only when the user presses "Check balance".
- Enlarging before drawing (new, setting `upscale`): when the source text
  lines are thinner than about 20 px, or when many translations do not fit
  even at the smallest font size, the cleaned page is enlarged (Lanczos, up
  to 4×) and the translation is drawn on the larger copy, so letters stay
  sharp. Fixed ×2/×3/×4 and "to width" modes exist; neural upscalers are
  planned for stage 2. Golden pages ru_E01P02 and ja_E01P02 are enlarged
  1.5× because their test translations do not fit at the smallest size.
- Text outline: the glyph contours are stroked under the text (width on each
  side of the contour). The original draws the text eight more times, shifted
  by the width, which shows as smeared copies of the letters at wide outlines.
- PDF import: a page that is one picture covering it, with nothing visible
  drawn over it (invisible OCR text is allowed), gives that picture as it is
  stored (a JPEG stays the same file) or at its own resolution; the original
  takes the first picture of any page, which loses text drawn over it. Other
  pages are rendered at 200 dpi (the original: 72 dpi).
- Projects (M9): autosave is on by default (the original's is off); the undo
  history is not kept in a project file (the original keeps image history).
  Recovery copies are made only by the first window of the program.
- "Translate all" over pages changed by hand since they were last translated
  whole (text, boxes, formatting, brush; kept in project files as
  `hand_edited`) first asks whether to translate them again or skip them
  (M12); the original translates them again. Undo brings the hand-made
  version back.
- Manual mode (M8): there is no Manual/Automatic switch; the single steps
  are always above the page and act on the current page, or on the pages
  picked with Ctrl / Shift in the page list (as the original). A step does the steps it needs
  first (translating a fresh page detects and reads it). There is no
  "Render" step: the translation is always drawn live, exactly as export
  will draw it. Text formatting applies to a whole bubble (the original also
  formats selected characters inside a text item); text is typed in the
  side panel, not on the page. Line breaks typed by the user are kept (the
  original wraps them away). The generated mask is a raster, and brush and
  eraser strokes are kept as strokes over it (the original turns the mask
  into vector paths).
  Cleaning starts from the current cleaned page, as in the original.
- Webtoon mode (M10): a bubble cut by the edge between two pages belongs to
  the upper page. The original detects both pages apart and joins the two
  halves found at the edge (`_match_split_blocks`); here the upper page is
  detected together with the top of the page below (`ct_core`
  `src/webtoon/seams.dart`), so the detector sees the whole bubble. Blocks
  that start on the page below are left to it, and that page drops what
  continues a block of the page above. Reading and cleaning such a block use
  the page with the rows of the next page it needs; what was cleaned below
  the edge is kept with the upper page as a transparent patch
  (`PageEntry.overflowPath`, `overflow` in project files), drawn over the next
  page in the strip, in export and in `cts export`, together with the part of
  the translation that reaches into it. The original also cuts long pages
  into 2000–3500 px pieces for memory; here pages are processed whole (a
  20 000 px chapter takes about 35 s and fits in memory), and pictures
  taller than 8192 px are shown in 4096 px tiles (graphics cards refuse
  larger textures). The strip view builds only the pages within a screen of
  what is shown; the wheel scrolls, Ctrl + wheel zooms. Pages of the strip
  are centred on each other, as in the original. New: export of the strip
  as one picture per chapter, or cut again into parts of about N px along
  the calmest row within 40 % of N (`src/export/strip_export.dart`).
- Graphics card (M12, new): a model that fails on DirectML while running
  (a GTX 1660 Ti refused a Softmax of PaddleOCR) is loaded again on the CPU
  and the run repeated (`OrtSession.run`); the window shows a notice that
  stays until closed, `cts` prints a warning, both are logged
  (`gpu_fallback`). Switching the GPU setting on lists the adapters (virtual
  ones such as Citrix left out), runs a tiny model through DirectML, then
  times a bundled test page on the CPU and on the card in the background
  worker and recommends the card only when it is at least 15 % faster,
  counting the steps that run on the CPU because they fail on the card (the
  result says which); a failed or partial
  test builds a bug report at once. Models that failed on DirectML are
  remembered in the settings (`tools.gpu_cpu_models`, shown under the switch
  with "Try again") and open on the CPU from then on
  (`OrtSession.cpuOnlyModels`), so the failure and its notice come once.
  `CTS_SIMULATE_DML_FAILURE=1` makes the first DirectML run of every real
  model fail, for checks on computers where DirectML works.
- PSD (M11): written and read in pure Dart (`ct_core` `src/psd/`; it is a file
  format, not inference), not through PhotoshopAPI as in the original: that
  library has no C interface, needs C++20 with vcpkg and has no Android
  build. The layout of a page file is the original's (`psd_exporter.py`), so
  files go both ways: top to bottom the group "Editable Text" (one text layer
  per translation: font by PostScript name, size, colour, outline, bold /
  italic as a real face or imitated, underline, alignment, line distance,
  rotation), "Inpaint Patches" (the places where the cleaned page differs from
  the original, in 32 px squares joined when they touch) and "Raw Image".
  Unlike the original: the merged picture is written (viewers and Krita show
  the page; the original's files have none), each text layer carries its text
  as drawn here (programs without Photoshop's text engine show that), the page
  is saved at 72 dpi so that points are pixels, the text box is a little wider
  and taller than the program's (Photoshop measures letters differently and
  hides what does not fit), vertical text is a picture layer only (vertical
  text layers of other writers are known to break Photoshop files), files
  taller than 30 000 px are PSB, and the page's blocks are kept in image
  resource 4000 (JSON) so the file opens again with the recognized text and
  boxes; translations changed in Photoshop and new text layers are taken over.
  The bundled font and its licence are put beside exported files that use it.
  Opening (as the original): a file of this layout gives the raw page, the
  patches over it as the cleaned page and the text layers as blocks; any other
  file gives its visible picture layers joined and its text layers as
  translated blocks, with a notice, and features that are not reproduced
  (smart objects, masks, blend modes, opacity, adjustment layers) are named.
  A webtoon page's file also has the text continued from the page above
  ("Text N (page above)"), which opening leaves to that page.
- `renderPage` does not change the blocks (the original leaves the render
  areas and case-adjusted translations in them), so a page can be edited
  and drawn again; golden pages now store the detected boxes.
- Rendering: fitted text is centred vertically in its area and placed
  horizontally by the alignment (setting `render.place_in_block`, on by
  default). The original puts it at the area's top-left corner, so short
  lines sit off-centre in their bubbles. Text is drawn by Flutter instead of
  Qt, so glyph shapes and line breaks can differ slightly; vertical text is a
  simplified column layout. The default font is Pangolin (OFL), bundled.

## Packages (pub workspace)

```
apps/comic_translate/   Flutter app: GUI and CLI share one Dart entry point
  lib/main.dart         --cts-cli flag → CLI, otherwise GUI
  lib/cli/              cts commands (package:args)
  lib/gui/              GUI start-up (services, settings, error logging)            (M7)
  lib/ui/               widgets: shell_full/ (main window), settings/, common/      (M7)
  lib/state/            Riverpod state: settings, open pages, "Translate all"      (M7)
  lib/import/           PDF pages through PDFium (archives are in ct_core)          (M7)
  lib/l10n/             interface strings (ARB, Russian and English)               (M7)
  lib/render/           text measurement and drawing with dart:ui                  (M6)
  lib/pipeline/         one page through every step; pipeline_worker.dart runs the
                        heavy steps in a background isolate for the GUI          (M6, M7)
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

## The window and the background worker

The GUI keeps the window responsive by running detection, OCR, translation and
cleaning in a background isolate (`lib/pipeline/pipeline_worker.dart`). The
main isolate resolves the plugin configuration (secrets come from the OS
secure storage, which only the main isolate can reach) into a `PipelineSpec`;
the worker creates its own plugin instances from it, keeps them loaded for the
whole run, forwards its log events to the main log and, in test mode, keeps
the run folder. Drawing the translation needs dart:ui and happens on the main
isolate; the worker then encodes and writes the files. Pages are processed one
at a time; "Stop" takes effect at the next step boundary.

One worker is shared by "Translate all" and the editor's single steps
(`lib/state/worker_pool.dart`): plugins load when a step first needs them and
stay loaded, so a step after another costs no loading time; an idle worker is
released after three minutes (memory is tight on small laptops), and a change
of plugins or their settings starts a new one.

Pages are immutable values (`lib/state/workspace.dart`): every change makes
new `PageEntry` and `TextBlock` objects, and the undo history of a page is the
list of its previous values (typing and dragging merge into one step; each run
of a step is one step). A bubble's own look is a `BlockStyle` on its block
(font, size, colours, outline, alignment, spacing, vertical text, rotation,
text box), honoured by the shared layout, so the viewer, export and `cts
render` draw the same thing. The viewer lays the page out with a per-block
cache and draws the text live; export draws the pages changed since they were
last drawn.

Projects (`lib/state/project.dart`, file format in `ct_core`
`src/project/project_file.dart`): a `.ctsproj` is SQLite, as the original's
`.ctpr`: `meta` (format version, program version, saved time), `project`
(current page), `pages` (one JSON row per page: name, source, file references,
blocks with styles, strokes, status, languages), `blobs` (every file once, by
SHA-256: originals, cleaned pages, masks, the fonts of block styles) and
`fingerprints` (path, size, time → hash, so unchanged files are not read
again). A save writes only the pages that changed, removes files no page uses
and runs an incremental vacuum; it runs in a background isolate. Opening
unpacks the files into a new session folder. The project notifier watches the
pages: a change marks the project unsaved and either schedules an autosave
(2 s) or, without a file, a recovery copy (`autosave/recovery.ctsproj`, every
2 minutes, guarded by a lock file so only one window keeps it). Export
(`ct_core` `src/export/`) writes folders, ZIP/CBZ (pictures stored, not
recompressed), CB7 through 7-Zip and PDF through a small writer of
picture pages.

Before a run the GUI asks for permission when the translator sends text off
the computer (once, or always for that server) and offers to download the
models the chosen plugins need for the source language (plugins list them in
`PluginInfo.modelsForLanguage`), showing size and source.

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
- **Full screen** (F11): the Windows runner (`windows/runner/flutter_window.cpp`) answers the
  `comic_translate/window` method channel, as Chromium does it (no frame, the whole monitor).

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
  Each plugin has its own keys (`plugin.<id>.<key>`). The settings show only whether
  a key is saved and its last 4 characters (keys shorter than 12 characters: none);
  what the user types can be shown before saving. "Show key" shows a saved key for
  30 seconds and "Copy" puts it on the clipboard, only when pressed; the value is
  still masked in logs and reports.
- The usage counter (`usage.json`) stays on this computer; it holds model names and
  numbers only.
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
usage.json         usage counter of paid services (requests, tokens, cost)
autosave/          recovery copy of unsaved work (recovery.ctsproj)
fonts/             fonts the user added
```

## Stage 1 milestones

M0 skeleton, CLI, diagnostics → M1 core, plugin registry, model manager, ONNX Runtime →
M2 detection → M3 OCR (PaddleOCR ONNX, then Windows OCR) → M4 translation → M5 mask and inpainting →
M6 text rendering, end-to-end `cts process`, goldens → M7 GUI basics and automatic mode →
M8 manual mode and editing → M9 projects and export → M10 webtoon mode → M11 PSD →
M12 UI languages, automatic source language, documentation.

# Command-line interface (`cts`)

`cts.exe` is built next to `comic_translate.exe` and runs the same code without a
window. Every pipeline function will be available here so that it can be tested
and debugged without the GUI.

```
cts [--data-dir DIR] [--json] [-v] <command> [options]
```

| Global option | Meaning |
|---|---|
| `--data-dir DIR` | Data directory (logs, runs, models). Default: `CTS_DATA_DIR` or `%LOCALAPPDATA%\ComicTranslateScreen` |
| `--json` | Print exactly one JSON document to stdout (for scripts and automated checks) |
| `-v, --verbose` | Mirror log events to stderr |

## Available now

| Command | Purpose |
|---|---|
| `cts version` | Version, git commit, Flutter and Dart versions |
| `cts doctor` | Environment checks: data directory, text rendering, OpenCV, ONNX Runtime (CPU and DirectML), Windows OCR languages, secure storage, models |
| `cts selftest render [-o file.png]` | Render sample text with dart:ui and save it |
| `cts models list` | Known models: status, size, license, location |
| `cts models download <id>... \| --all` | Download models (network access; shows hosts and sizes, resumes interrupted downloads) |
| `cts models verify <id>... \| --all` | Re-check SHA-256 of downloaded files |
| `cts models delete <id>...` | Delete downloaded files |
| `cts models import <file\|folder\|zip>...` | Install model files copied from another computer; files are recognized by size and SHA-256, nothing is downloaded |
| `cts secrets list` | Names of stored secrets (values are never printed) |
| `cts secrets set <name>` | Store a secret read from stdin, e.g. `plugin.openai_compatible.api_key` |
| `cts secrets delete <name>` | Delete a stored secret |
| `cts detect <image>... [-o dir] [--gpu] [--confidence X] [--debug]` | Detect text blocks and speech bubbles; writes `<name>.blocks.json` (blocks with their lines and text direction) and `<name>.overlay.png` |
| `cts ocr <image>... [--lang English] [--ocr default\|ppocr\|manga_ocr\|windows_ocr] [--blocks f.blocks.json] [--[no-]upscale] [-o dir] [--debug]` | Detect (or load blocks) and recognize text; small text is read on an enlarged copy (`--no-upscale` turns that off); writes `<name>.ocr.json` and prints the text in reading order |
| `cts translate <name.ocr.json>... [--to Russian] [--translator mock\|openai_compatible] [--allow-network [--remember]] [--image page.jpg] [-o dir] [--debug]` | Translate blocks recognized by `cts ocr` in reading order; writes `<name>.translated.json`. A translator that sends data off this computer refuses to run without `--allow-network` (or a remembered approval for that server) |
| `cts settings show\|get <path>\|set <path> <value>\|plugins` | Read or change settings.json by dotted path (e.g. `plugins.openai_compatible.api_url`); `plugins` lists every plugin with its settings and where it sends data |
| `cts mask <image> --blocks f.json [-o dir]` | Build the text-removal mask from blocks (detect/ocr/translate JSON); writes `<name>.mask.png` |
| `cts inpaint <image>... [--blocks f.json \| --mask m.png] [--inpainter aot\|lama] [--strategy resize\|crop\|original] [--gpu] [-o dir] [--debug]` | Remove text: uniform bubbles are flat-filled, the rest goes to the inpainting network (by patches or the whole page); without `--blocks`/`--mask` text is detected first; writes `<name>.clean.png` |
| `cts render <page.png> --blocks f.translated.json [--to lang] [-o dir]` | Draw translations onto a page (usually the cleaned page from `cts inpaint`); writes `<name>.rendered.png` and `<name>.layout.json` |
| `cts process <image\|folder\|archive\|pdf>... [--from English] [--to Russian] [--translator mock\|openai_compatible] [--allow-network [--remember]] [--gpu] [-o dir] [--debug] [--project file.ctsproj] [--webtoon]` | The whole pipeline: detect, OCR, translate, remove text, draw the translation. Folders are read in natural order (page2 before page10); archives (cbz, zip, epub, cbt, tar; cbr, rar, cb7, 7z through an installed 7-Zip or WinRAR) and PDF pages (a page that is one picture gives that picture, others are rendered at 200 dpi) are unpacked to a temporary folder, and their pages are named `<archive>_001` …. Small pages are enlarged before drawing (setting `upscale.mode`). Writes `<name>.translated.png` and `<name>.json` (blocks, layout, timings); `--project` also saves a project to open in the window. `--webtoon`: the pages are one strip, a bubble cut by the edge between two pages is read, cleaned and drawn whole (and the project opens in the webtoon mode) |
| `cts compare <a.png> <b.png> [--diff d.png] [--threshold 16] [--min-psnr dB]` | Compare two images (PSNR, largest difference, changed pixels); exit code 0 when identical (or PSNR ≥ `--min-psnr`) |
| `cts golden check\|update [--dir test_data/golden] [-o dir]` | Re-run the golden pages (default settings, offline mock translator, CPU) and compare blocks, OCR text, layout and picture with the saved results; `update` saves new results after an intended change |
| `cts bench <image>... [--from] [--to] [--repeat 2] [--gpu]` | Time every stage (mock translator, nothing sent); the first run is shown separately, plus model loading time and peak memory |
| `cts report [--run ID] [--with-images] [--note TEXT] [-o file.zip]` | Build a bug report |
| `cts project info <file.ctsproj>` | Pages, size, saved time and program version of a project |
| `cts export <file.ctsproj> -o <file\|folder> [--as folder\|zip\|cbz\|cb7\|pdf] [--what translated,cleaned,raw,translations] [--image-format source\|png\|jpg\|webp\|psd] [--by-chapter] [--to lang] [--strip pages\|single\|slices] [--slice-height 1280]` | Export a project like the window's Export: the translations are drawn, then written as images, an archive or a PDF (one per chapter with `--by-chapter`); texts as JSON like the original. Webtoons: `--strip single` joins the pages into one picture per chapter, `--strip slices` cuts the strip again into parts of about `--slice-height` px along even rows. `--image-format psd`: one layered Photoshop file per page (the original, the cleaned places, the translation as editable text layers; the bundled font beside them when used), into a folder or ZIP |
| `cts psd info <file.psd>` | Size, layers and text layers of a Photoshop file (PSD or PSB), whether it is laid out by this program or the original, and what opening it would not carry over (smart objects, masks, blend modes …) |
| `cts usage [--balance [--translator id]] [--reset]` | The usage of paid services counted on this computer: requests, tokens and cost per model, today and in total (`usage.json`, never sent anywhere). `--balance` asks the translator's service what is left of the API key (sends the key; OpenRouter only) |

Example: translate with OpenRouter

```
cts settings set plugins.openai_compatible.api_url https://openrouter.ai/api/v1
cts settings set plugins.openai_compatible.model openai/gpt-4.1-mini
cts secrets set plugin.openai_compatible.api_key      (paste the key, Enter)
cts ocr page.jpg -o out
cts translate out/page.ocr.json --to Russian --allow-network -o out
```

Example: translate a whole chapter in one go

```
cts process chapter01 --from English --to Russian --allow-network -o out
cts process chapter01 --to Russian --translator mock -o out      (offline test run)
```

`--debug` (or `cts settings set test_mode true`) also saves every stage
(`01_detect` … `06_render`: blocks, mask, cleaned page, layout, final page and
timings) in the run folder.

Secrets are read from stdin so they never appear in shell history or process
lists. They are stored in the OS secure storage and masked in all logs.

## Planned

| Command | Milestone |
|---|---|
| `cts process` on projects | M9 |

Parity with the original is checked by the test suites (`dart test`) against
`test_data/reference/`, not by a CLI command: see
[tools/reference](../tools/reference/README.md).

## The window's command line

`comic_translate.exe [files...]` opens the given images, folders, archives or
PDFs (this is what "Open with" in Explorer does). For automated checks of the
window: `--translate` starts "Translate all" once the files are open, and
`--settings=<section>` opens the settings at `general`, `translator`,
`tools`, `text`, `upscale`, `export`, `models` or `about`. With
`CTS_DATA_DIR` set, the window uses that data folder, as `cts` does.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | The command ran but a check or operation failed |
| 64 | Usage error (unknown command or option) |
| 70 | Internal error; details are in `logs/app.jsonl`, run `cts report` |

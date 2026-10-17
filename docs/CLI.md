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
| `cts doctor` | Environment checks: data directory, text rendering engine (more checks arrive with each milestone) |
| `cts selftest render [-o file.png]` | Render sample text with dart:ui and save it |
| `cts report [--run ID] [--with-images] [--note TEXT] [-o file.zip]` | Build a bug report |

## Planned

| Command | Milestone |
|---|---|
| `cts models list\|download\|verify` | M1 |
| `cts detect <img>` → `blocks.json`, `overlay.png` | M2 |
| `cts parity <page>` (compare with the original's reference output) | M2 |
| `cts ocr <img> [--blocks f] --lang en` | M3 |
| `cts translate <blocks.json> --to ru [--provider mock\|openai_compatible]` | M4 |
| `cts mask <img> --blocks f`, `cts inpaint <img> --mask m.png [--model aot\|lama\|migan]` | M5 |
| `cts render`, `cts process <inputs> -o out [--debug]`, `cts compare`, `cts golden check\|update`, `cts bench` | M6 |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | The command ran but a check or operation failed |
| 64 | Usage error (unknown command or option) |
| 70 | Internal error; details are in `logs/app.jsonl`, run `cts report` |

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
| `cts doctor` | Environment checks: data directory, text rendering, OpenCV, ONNX Runtime (CPU and DirectML), secure storage, models |
| `cts selftest render [-o file.png]` | Render sample text with dart:ui and save it |
| `cts models list` | Known models: status, size, license, location |
| `cts models download <id>... \| --all` | Download models (network access; shows hosts and sizes, resumes interrupted downloads) |
| `cts models verify <id>... \| --all` | Re-check SHA-256 of downloaded files |
| `cts models delete <id>...` | Delete downloaded files |
| `cts secrets list` | Names of stored secrets (values are never printed) |
| `cts secrets set <name>` | Store a secret read from stdin, e.g. `plugin.openai_compatible.api_key` |
| `cts secrets delete <name>` | Delete a stored secret |
| `cts detect <image>... [-o dir] [--gpu] [--confidence X] [--debug]` | Detect text blocks and speech bubbles; writes `<name>.blocks.json` and `<name>.overlay.png` (line splitting arrives with the heuristic-lines port) |
| `cts report [--run ID] [--with-images] [--note TEXT] [-o file.zip]` | Build a bug report |

Secrets are read from stdin so they never appear in shell history or process
lists. They are stored in the OS secure storage and masked in all logs.

## Planned

| Command | Milestone |
|---|---|
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

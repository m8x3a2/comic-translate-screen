# Test mode, logs and bug reports

## Logs

All logs are JSON Lines, one event per line:

```json
{"ts":"2026-10-17T18:03:12.512Z","level":"info","event":"stage_end","run_id":"20261017-210312-1a2b","page":"001.png","stage":"02_ocr","dur_ms":834,"data":{"blocks":12}}
```

| Field | Meaning |
|---|---|
| `ts` | UTC timestamp |
| `level` | `trace`, `debug`, `info`, `warn`, `error` |
| `event` | Machine-readable name (`stage_start`, `stage_end`, `stage_error`, `cli_command`, ...) |
| `run_id`, `page`, `stage` | Context, when known |
| `dur_ms` | Duration for timed events |
| `data` | Event-specific fields; errors carry `error`, `error_type`, `stack` |

`logs/app.jsonl` is the process log of the GUI and CLI. It is always on.

## Test mode

When test mode is on (GUI setting, or `cts process --debug`), each run gets a folder:

```
runs/<run_id>/
  env.json          app version, git commit, Flutter/Dart, ONNX Runtime and execution
                    provider, OS, CPU/GPU, OCR languages, model SHA-256s
  events.jsonl      everything that happened, with timings
  timings.json      per page and stage durations
  result.json       success flag and summary
  pages/<page>/
    01_detect/      blocks.json, overlay.png
    02_ocr/         blocks.json, crops/
    03_translate/   request.redacted.json, response.json
    04_mask/        mask.png
    05_inpaint/     before.png, after.png, diff.png
    06_render/      layout.json, final.png
```

The stage folders are filled in as the corresponding milestones land.

## Redaction

Everything written to logs, artifacts and bug reports passes through the `Redactor`
(`packages/ct_core/lib/src/diagnostics/redactor.dart`):

- every secret read from secure storage is registered and masked as `***`;
- known key formats (`sk-...`, `AIza...`), `Bearer`/`Basic` credentials, `?key=`
  query parameters and values of fields such as `api_key`, `token`, `password` are masked;
- e-mail addresses become `<email>`;
- the user's home folder becomes `%USERPROFILE%`.

Tests assert that secrets never appear in logs, run folders or bug reports.

## Bug reports

```bash
cts report
```

The command writes `reports/bugreport-<timestamp>.zip` with `env.json`, settings
(without secrets), the tail of `logs/app.jsonl` and the latest run (text files only).
Options:

- `--run ID` to choose a run;
- `--with-images` to include page images and stage artifacts;
- `--note "what happened"` to attach a description.

In the app, an unexpected error builds `reports/bugreport-auto-<timestamp>.zip` by itself (at most one a
minute; the newest 20 are kept) and a 30-second notice shows where it is. Settings → General → "Build a bug
report automatically" turns this off (after a warning); then the notice offers a button instead.

The GUI will get the same action as a button (M7).

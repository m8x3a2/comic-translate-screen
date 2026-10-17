# Models

No model is bundled with the application. Models are downloaded only when the
user agrees (GUI prompt) or asks for it (`cts models download`), from their
original publishers, verified by SHA-256 and stored in `models/<id>/` inside the
data directory. They remain under their own licenses. The prompt always shows
the source host and size before starting.

The registry lives in `packages/ct_core/lib/src/models/model_catalog.dart`;
URLs and checksums are taken from the original `modules/utils/download.py`.

| Id | Purpose | File | Size | License | Source |
|---|---|---|---|---|---|
| `rtdetr-v2-int8` | Text and bubble detection (RT-DETR-v2) | `detector-v4-s_int8.onnx` | 10.6 MB | Apache-2.0 | huggingface.co/ogkalu/comic-text-and-bubble-detector |
| `aot-inpainting` | Text removal, default inpainter (AOT-GAN) | `aot.onnx` | 22.0 MB | MIT | huggingface.co/ogkalu/aot-inpainting |
| `lama-manga` | Text removal, higher quality (LaMa manga fine-tune) | `lama-manga-dynamic.onnx` | 197 MB | Apache-2.0 | huggingface.co/ogkalu/lama-manga-onnx-dynamic |
| `osd-script-id` | Automatic source-language (script) detection | `osd_lstm.onnx`, `osd_labels.json` | 3.6 MB | Apache-2.0 | huggingface.co/ogkalu/image-script-identification |

MI-GAN is not included: the original's ONNX download URL returns 404 and the
original user interface only offers LaMa and AOT.

## Commands

```bash
cts models list                 # status, size, license
cts models download aot-inpainting
cts models download --all
cts models verify --all         # re-check SHA-256
cts models delete lama-manga
```

Interrupted downloads resume from where they stopped (`*.part` files).

## ONNX Runtime

Models run on ONNX Runtime 1.24.4 (MIT), fetched at build time from NuGet
(`Microsoft.ML.OnnxRuntime.DirectML`) by the `ct_onnx` build hook and verified
by SHA-256. It provides the DirectML (GPU) and CPU execution providers.
`DirectML.dll` is used from Windows (System32); if it is unavailable the CPU
provider is used.

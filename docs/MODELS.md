# Models

No model is bundled with the application. Models are downloaded on first use from
their original publishers, verified by SHA-256 and stored in `models/` inside the
data directory. They remain under their own licenses. The download dialog always
shows the source host and size before starting.

Models used in stage 1, all already published in ONNX format by the upstream project:

| Purpose | File | Source |
|---|---|---|
| Text and bubble detection (RT-DETR-v2) | `detector-v4-s_int8.onnx` | huggingface.co/ogkalu/comic-text-and-bubble-detector |
| Inpainting (AOT, default) | `aot.onnx` | huggingface.co/ogkalu/aot-inpainting |
| Inpainting (LaMa, manga fine-tune) | `lama-manga-dynamic.onnx` | huggingface.co/ogkalu/lama-manga-onnx-dynamic |
| Inpainting (MI-GAN) | `migan_pipeline_v2.onnx` | github.com/Sanster/models (release `migan`) |
| Script detection for automatic source language | `osd_lstm.onnx`, `osd_labels.json` | huggingface.co/ogkalu/image-script-identification |

Exact URLs, sizes, checksums and license notes are recorded in the model registry
when it lands (M1) and mirrored here.

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

| `ppocr-v5-rec-en` | OCR, English (PP-OCRv5 mobile) | `en_PP-OCRv5_rec_mobile_infer.onnx` + dictionary | 7.5 MB | Apache-2.0 | huggingface.co/ogkalu/ppocr-v5-onnx |
| `ppocr-v5-rec-latin` | OCR, French, German, Spanish, Italian, Dutch | `latin_PP-OCRv5_rec_mobile_infer.onnx` + dictionary | 7.5 MB | Apache-2.0 | huggingface.co/ogkalu/ppocr-v5-onnx |
| `ppocr-v5-rec-eslav` | OCR, Russian | `eslav_PP-OCRv5_rec_mobile_infer.onnx` + dictionary | 7.5 MB | Apache-2.0 | huggingface.co/ogkalu/ppocr-v5-onnx |
| `ppocr-v5-rec-korean` | OCR, Korean | `korean_PP-OCRv5_rec_mobile_infer.onnx` + dictionary | 12.9 MB | Apache-2.0 | huggingface.co/ogkalu/ppocr-v5-onnx |
| `ppocr-v6-rec-small` | OCR, Chinese (and Japanese titles) | `PP-OCRv6_small_rec.onnx` + dictionary | 20.3 MB | Apache-2.0 | huggingface.co/ogkalu/ppocr-v6-onnx |
| `manga-ocr-mobile` | OCR, Japanese (manga-ocr) | encoder, two decoder parts, vocabulary | 61.8 MB | Apache-2.0 | huggingface.co/ogkalu/manga-ocr-mobile |

Preparing small text for reading (new in this project; only the level chosen
in the settings is needed):

| Id | Level | File | Size | License | Source |
|---|---|---|---|---|---|
| `waifu2x-cunet-art-2x` | Simple | `waifu2x_cunet_art_scale2x.onnx` | 4.9 MB | MIT (nagadomi, waifu2x/nunif) | huggingface.co/deepghs/waifu2x_onnx |
| `waifu2x-swin-art-2x` | Medium (default for comics) | `waifu2x_swin_unet_art_scale2x.onnx` | 16.0 MB | MIT (nagadomi, waifu2x/nunif) | huggingface.co/deepghs/waifu2x_onnx |
| `fatality-comix-4x` | High | `fatality_comix_4x.onnx` | 64.0 MB | CC-BY-NC-SA-4.0 (Twittman) | github.com/m8x3a2/comic-translate-screen releases |

Fatality Comix (4x_Fatality_Comix_260000_G, by Twittman, https://openmodeldb.info/models/4x-Fatality-Comix)
is published by its author only as PyTorch weights; this project converted it to
ONNX (opset 17, dynamic sizes, weights unchanged) and publishes that file in its
GitHub releases under the model's own licence, CC BY-NC-SA 4.0: non-commercial
use, credit the author, share changes under the same licence. Comic Translate
Screen is free and non-commercial.

Only the recognizer of the chosen source language is needed. The PP-OCR line
detector of the original is not used (see docs/ARCHITECTURE.md).

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

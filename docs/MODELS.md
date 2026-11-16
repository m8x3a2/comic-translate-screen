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
| `waifu2x-swin-art-2x` | Medium | `waifu2x_swin_unet_art_scale2x.onnx` | 16.0 MB | MIT (nagadomi, waifu2x/nunif) | huggingface.co/deepghs/waifu2x_onnx |
| `fatality-comix-4x` | High (default for comics) | `fatality_comix_4x.onnx` | 64.0 MB | CC-BY-NC-SA-4.0 (Twittman) | github.com/m8x3a2/comic-translate-screen releases |

Fatality Comix (4x_Fatality_Comix_260000_G, by Twittman, https://openmodeldb.info/models/4x-Fatality-Comix)
is published by its author only as PyTorch weights; this project converted it to
ONNX (opset 17, dynamic sizes, weights unchanged) and publishes that file in its
GitHub releases under the model's own licence, CC BY-NC-SA 4.0: non-commercial
use, credit the author, share changes under the same licence. Comic Translate
Screen is free and non-commercial.

Offline translation (new in this project; the translator "Offline (OPUS-MT)", only the direction and
level in use are needed). Fast and Better use the OPUS-MT models (`opus-mt-en-ru`, `opus-mt-ru-en`,
int8 ONNX by Xenova); High uses the big ones:

| Id | Level | Files | Size | License | Source |
|---|---|---|---|---|---|
| `opus-mt-tc-big-en-ru` | High, English → Russian | `encoder_model_quantized.onnx`, `decoder_model_merged_quantized.onnx` (+ `source.spm`, `vocab.json`) | 353 MB | CC-BY-4.0 (Helsinki-NLP, Tatoeba Challenge) | github.com/m8x3a2/comic-translate-screen releases; tokenizer from huggingface.co/Helsinki-NLP/opus-mt-tc-big-en-zle |
| `opus-mt-tc-big-ru-en` | High, Russian → English | the same | 352 MB | CC-BY-4.0 (Helsinki-NLP, Tatoeba Challenge) | github.com/m8x3a2/comic-translate-screen releases; tokenizer from huggingface.co/Helsinki-NLP/opus-mt-tc-big-zle-en |

OPUS-MT tc-big (Helsinki-NLP/opus-mt-tc-big-en-zle and opus-mt-tc-big-zle-en, by Jörg Tiedemann and the
Language Technology Research Group at the University of Helsinki, https://github.com/Helsinki-NLP/Tatoeba-Challenge)
is published by its authors as PyTorch weights; this project exported it to ONNX (optimum) and made it
int8 (dynamic, per channel; the decoders one by one, then merged), as the Xenova models of OPUS-MT are,
and publishes those files in its GitHub releases under the models' own licence, CC BY 4.0: credit the
authors. The English model also translates into Belarusian and Ukrainian; the app asks it for Russian
with the token `>>rus<<`. The weights are otherwise unchanged.

Offline dictionary (new in this project; the book button in the "Text" panel, Chat → Dictionary):

| Id | Use | Files | Size | License | Source |
|---|---|---|---|---|---|
| `dict-en-ru` | Dictionary, English → Russian | `dictionary.sqlite` | 121 MB | CC-BY-SA-4.0 (Wiktionary contributors) | github.com/m8x3a2/comic-translate-screen releases (`dict-en-ru-wiktionary-1.sqlite`) |

Built by `tools/dictionary/build_dictionary.py` from the Wiktionary extracts of kaikki.org (wiktextract,
Tatu Ylonen): the English edition gives Russian words by meaning, the Russian edition short Russian
explanations with translated examples. Kept are the 92 thousand words and phrases with Russian and the
80 thousand frequent English words (English explanations only), plus the forms Wiktionary lists (ran → run).
Wiktionary is licensed CC BY-SA 4.0; so is the file.

Text removal levels (new in this project; Settings → Tools → Text removal quality): Simple uses
`aot-inpainting`, Medium `comic-text-detector` + `aot-inpainting`, High (default)
`comic-text-detector` + `lama-manga`.

| Id | Purpose | File | Size | License | Source |
|---|---|---|---|---|---|
| `comic-text-detector` | The letters themselves for text removal (mask head of comic-text-detector) | `comic-text-detector.onnx` | 78.4 MB | GPL-3.0 (dmMaze) | huggingface.co/EarthWL/hiyori-onnx (pinned commit) |

comic-text-detector (https://github.com/dmMaze/comic-text-detector, by dmMaze) is GPL-3.0. It is not
bundled and not linked into the program: it is a separate download, run by ONNX Runtime like any
other model file. The export used (EarthWL/hiyori-onnx, pinned to commit 0aec190) keeps the
mask and line heads with unchanged weights and takes any input size.

Recognition levels of English text (new in this project; Settings → Tools → Recognition quality,
one level for comics and one for sites and games): Simple is `ppocr-v5-rec-en` alone, Medium (the
default) adds `ppocr-v6-rec-small` as a second reader, High and Ultra add PaddleOCR-VL.

| Id | Purpose | Files | Size | License | Source |
|---|---|---|---|---|---|
| `paddleocr-vl-1.6` | Slow accurate English reader of the levels High and Ultra (vision-language model, run by llama.cpp) | `PaddleOCR-VL-1.6-GGUF.gguf`, `PaddleOCR-VL-1.6-GGUF-mmproj.gguf` | 1.7 GB | Apache-2.0 (PaddlePaddle) | huggingface.co/PaddlePaddle/PaddleOCR-VL-1.6-GGUF (pinned commit) |

Only the recognizer of the chosen source language is needed. The PP-OCR line
detector of the original is not used (see docs/ARCHITECTURE.md).

MI-GAN is not included: the original's ONNX download URL returns 404, and in the night experiment
of 2026-10-25 it (and big-LaMa, Telea, Stable Diffusion 1.5 inpainting) cleaned worse than
LaMa manga and AOT.

## Commands

```bash
cts models list                 # status, size, license
cts models download aot-inpainting
cts models download --all
cts models verify --all         # re-check SHA-256
cts models delete lama-manga
```

Interrupted downloads resume from where they stopped (`*.part` files).

## llama.cpp

PaddleOCR-VL runs on llama.cpp b11858 (MIT, https://github.com/ggml-org/llama.cpp), the official
Windows CPU build fetched at build time by the `ct_llama` build hook and verified by SHA-256
(`llama.dll`, `mtmd.dll`, `ggml*.dll`, `libomp.dll`; ggml picks the `ggml-cpu-*` variant of the
processor at run time).

## ONNX Runtime

Models run on ONNX Runtime 1.24.4 (MIT), fetched at build time from NuGet
(`Microsoft.ML.OnnxRuntime.DirectML`) by the `ct_onnx` build hook and verified
by SHA-256. It provides the DirectML (GPU) and CPU execution providers.
`DirectML.dll` is used from Windows (System32); if it is unavailable the CPU
provider is used.

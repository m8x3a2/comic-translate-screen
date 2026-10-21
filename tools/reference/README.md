# Parity reference data

Ports of algorithms from the original
[comic-translate](https://github.com/ogkalu2/comic-translate) are checked against
the original Python code: this folder runs the original functions on the test
pages and stores their outputs in `test_data/reference/`; Dart tests compare the
port with those outputs. Deterministic steps (image primitives, geometry,
detection boxes, line splitting) must match exactly; model outputs are compared
with small tolerances.

| Section | Contents | Checked by |
|---|---|---|
| `primitives` | PIL grayscale and resize, mahotas Otsu and labelling, numpy median/percentile | `packages/ct_core/test/parity/primitives_test.dart` |
| `geometry` | box filtering and merging, slicing of tall pages, reading order | `packages/ct_core/test/parity/geometry_test.dart` |
| `detection` | RT-DETR-v2 on every test page: raw outputs, blocks, lines, colours | `packages/ct_providers/test/rtdetr_v2_parity_test.dart` (needs the model) |
| `ocr` | PaddleOCR on the detected blocks: line crops, recognizer inputs, texts | `packages/ct_providers/test/ppocr_parity_test.dart` (needs the models) |
| `manga_ocr` | manga-ocr on two pages (inputs, tokens, texts) and its text clean-up | `packages/ct_providers/test/manga_ocr_parity_test.dart`, `packages/ct_core/test/parity/manga_ocr_text_test.dart` |
| `search` | "preserve case" of find and replace on ~300 word pairs (the function is taken from the source: its module needs the whole Qt application) | `apps/comic_translate/test/search_test.dart` |
| `script` | script identification ("Auto"): the line read in each block, model inputs and best paths, script labels, page language (with lines, without, inverted) | `packages/ct_core/test/parity/script_test.dart`, `packages/ct_providers/test/script_id_parity_test.dart` (needs the model) |
| `mask` | mahotas morphology, imkit contours, Pillow blur and "L" resize; generate_mask on every page | `packages/ct_core/test/parity/mask_test.dart` |
| `inpaint` | fast bubble fill, patch/full routing, AOT and LaMa results with each high-resolution strategy | `packages/ct_providers/test/inpaint_parity_test.dart` (needs the models) |
| `heuristics` | line splitting and text direction on ~500 crops (blocks, bubbles, rotated, inverted, random regions) | `packages/ct_core/test/parity/heuristics_test.dart` |

`gen_manga_ocr_tables.py` generates the jaconv tables used by the Dart port.

`heuristics`, `ocr`, `manga_ocr` and `script` reuse the blocks of `detection`, so generate `detection` first
(it needs the model: `cts models download rtdetr-v2-int8`).

The original repository is only read. Point `CT_ORIGINAL_DIR` at a checkout
(default: `../official` relative to the parent of this repository).

```bash
cd tools/reference
uv sync
uv run python -B gen_reference.py --original C:/path/to/comic-translate [--only heuristics]
```

The environment pins ONNX Runtime to the same release as `packages/ct_onnx`, so
model outputs are comparable.

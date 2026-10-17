# Parity reference data

Ports of algorithms from the original
[comic-translate](https://github.com/ogkalu2/comic-translate) are checked against
the original Python code: this folder runs the original functions on the test
pages and stores their outputs in `test_data/reference/`; Dart tests compare the
port with those outputs (box IoU, mask IoU, image PSNR).

The original repository is only read. Point `CT_ORIGINAL_DIR` at a checkout
(default: `../official` relative to the parent of this repository).

```bash
cd tools/reference
uv sync
uv run python gen_reference.py --original C:/path/to/comic-translate
```

The environment pins ONNX Runtime to the same release as `packages/ct_onnx`, so
model outputs are comparable.

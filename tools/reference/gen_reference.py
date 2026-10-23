"""Generate parity reference data by running the original comic-translate code.

    uv run python -B gen_reference.py [--original DIR] [--only primitives|geometry|detection|heuristics|ocr|manga_ocr|translation|mask|inpaint|render]

The original repository is only imported (bytecode writing is disabled), never
modified. Outputs go to test_data/reference/ and are compared by Dart tests.

Pages are decoded with OpenCV 4.12 (the same version dartcv4 builds), so the
original algorithms and the Dart port start from identical pixels; every page
record carries the SHA-256 of its decoded RGB buffer to prove it.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import random
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True

import cv2  # noqa: E402
import numpy as np  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
DEFAULT_ORIGINAL = REPO.parent.parent / "official"
DEFAULT_PAGES = REPO / "test_data" / "pages" / "peppercarrot"
DEFAULT_OUT = REPO / "test_data" / "reference"
DEFAULT_MODELS = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "ComicTranslateScreen" / "models"

SEED = 20261017


# ---------------------------------------------------------------- helpers ---

def b64(arr: np.ndarray) -> str:
    return base64.b64encode(np.ascontiguousarray(arr).tobytes()).decode("ascii")


def sha256(arr: np.ndarray) -> str:
    return hashlib.sha256(np.ascontiguousarray(arr).tobytes()).hexdigest()


def to_py(value):
    """Converts numpy values to JSON-friendly Python values."""
    if isinstance(value, np.ndarray):
        return [to_py(v) for v in value.tolist()] if value.dtype != object else [to_py(v) for v in value]
    if isinstance(value, (list, tuple)):
        return [to_py(v) for v in value]
    if isinstance(value, dict):
        return {str(k): to_py(v) for k, v in value.items()}
    if isinstance(value, np.integer):
        return int(value)
    if isinstance(value, np.floating):
        return float(value)
    if isinstance(value, np.bool_):
        return bool(value)
    return value


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(to_py(data), ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    print("wrote", path.relative_to(REPO))


def decode_rgb(path: Path) -> np.ndarray:
    data = np.fromfile(str(path), dtype=np.uint8)
    bgr = cv2.imdecode(data, cv2.IMREAD_COLOR)
    return cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)


def block_to_json(blk) -> dict:
    return {
        "xyxy": [int(v) for v in blk.xyxy],
        "bubble_xyxy": None if blk.bubble_xyxy is None else [int(v) for v in blk.bubble_xyxy],
        "text_class": blk.text_class,
        "lines": to_py(blk.lines or []),
        "direction": blk.direction,
        "font_color": to_py(list(blk.font_color)) if blk.font_color else None,
    }


# ------------------------------------------------------------- primitives ---

def gen_primitives(out: Path) -> None:
    import imkit as imk
    import mahotas
    from PIL import Image

    rng = np.random.default_rng(SEED)
    data: dict = {}

    # PIL convert("L")
    cases = []
    for _ in range(20):
        h, w = rng.integers(1, 9, size=2)
        img = rng.integers(0, 256, size=(h, w, 3), dtype=np.uint8)
        cases.append({"h": int(h), "w": int(w), "rgb": b64(img), "gray": b64(imk.to_gray(img))})
    edge = np.array([[[0, 0, 0], [255, 255, 255], [255, 0, 0], [0, 255, 0], [0, 0, 255], [128, 128, 128]]], dtype=np.uint8)
    cases.append({"h": 1, "w": 6, "rgb": b64(edge), "gray": b64(imk.to_gray(edge))})
    data["to_gray"] = cases

    # Otsu: imkit (mahotas.otsu on the array) and mahotas.thresholding.otsu.
    cases = []
    for i in range(400):
        n = int(rng.integers(1, 600))
        kind = i % 5
        if kind == 0:
            arr = rng.integers(0, 256, size=n, dtype=np.uint8)
        elif kind == 1:  # bimodal
            a = rng.normal(rng.integers(10, 90), rng.integers(1, 20), size=n // 2)
            b = rng.normal(rng.integers(150, 250), rng.integers(1, 20), size=n - n // 2)
            arr = np.clip(np.concatenate([a, b]), 0, 255).astype(np.uint8)
        elif kind == 2:  # small max value
            arr = rng.integers(0, int(rng.integers(1, 8)), size=n, dtype=np.uint8)
        elif kind == 3:  # constant
            arr = np.full(n, int(rng.integers(0, 256)), dtype=np.uint8)
        else:  # few distinct values
            vals = rng.choice(256, size=int(rng.integers(2, 5)), replace=False)
            arr = rng.choice(vals, size=n).astype(np.uint8)
        arr2d = arr.reshape(1, -1)
        cases.append({
            "values": b64(arr),
            "imkit": float(imk.otsu_threshold(arr2d)[0]),
            "mahotas": int(mahotas.thresholding.otsu(arr2d)),
        })
    data["otsu"] = cases

    # Connected components with stats (4- and 8-connectivity).
    cases = []
    for i in range(120):
        h, w = (int(v) for v in rng.integers(1, 36, size=2))
        density = float(rng.uniform(0.05, 0.7))
        mask = (rng.random((h, w)) < density).astype(np.uint8) * 255
        if i % 10 == 0:
            mask[:] = 0
        conn = 8 if i % 2 else 4
        num, labels, stats, centroids = imk.connected_components_with_stats(mask, connectivity=conn)
        case = {
            "h": h, "w": w, "connectivity": conn, "mask": b64(mask),
            "num_labels": int(num), "stats": stats.astype(np.int64).tolist(),
            "centroids": centroids.tolist(),
        }
        if i < 40:
            case["labels"] = b64(labels.astype(np.int32))
        cases.append(case)
    data["connected_components"] = cases

    # numpy median / percentile (linear interpolation).
    cases = []
    for _ in range(60):
        n = int(rng.integers(1, 40))
        arr = rng.integers(-500, 500, size=n).astype(np.float64) / rng.choice([1, 3, 7])
        q = float(rng.choice([0, 10, 20, 25, 50, 75, 80, 90, 100]))
        cases.append({"values": arr.tolist(), "median": float(np.median(arr)), "q": q, "percentile": float(np.percentile(arr, q))})
    data["median_percentile"] = cases

    # Python round (half to even) through int(round(x)) and np.round / np.rint.
    xs = [i / 2 for i in range(-12, 13)] + [2.675, -0.5000001, 1e-9, 7.4999999]
    data["round"] = [{"x": x, "round": int(round(x)), "np_rint": float(np.rint(x))} for x in xs]

    # PIL bicubic resize (the detector's preprocessing: Image.resize((640, 640))).
    cases = []
    for (h, w, th, tw) in [(5, 7, 13, 11), (40, 30, 640, 640), (300, 200, 64, 96), (17, 640, 640, 640)]:
        img = rng.integers(0, 256, size=(h, w, 3), dtype=np.uint8)
        res = np.asarray(Image.fromarray(img).resize((tw, th)))
        case = {"h": h, "w": w, "th": th, "tw": tw, "rgb": b64(img), "sha256": sha256(res)}
        if th * tw <= 400:
            case["out"] = b64(res)
        cases.append(case)
    data["pil_resize"] = cases

    write_json(out / "primitives.json", data)


# --------------------------------------------------------------- geometry ---

def random_boxes(rng: random.Random, n: int, size: int = 400) -> list[list[int]]:
    boxes = []
    for _ in range(n):
        x1 = rng.randint(-20, size)
        y1 = rng.randint(-20, size)
        boxes.append([x1, y1, x1 + rng.randint(-5, 160), y1 + rng.randint(-5, 120)])
    return boxes


def gen_geometry(out: Path) -> None:
    from modules.detection.utils.content import filter_and_fix_bboxes
    from modules.detection.utils.geometry import merge_overlapping_boxes
    from modules.detection.utils.slicer import ImageSlicer
    from modules.utils.textblock import TextBlock, sort_blk_list

    rng = random.Random(SEED)
    data: dict = {"filter_and_fix": [], "merge_overlapping": [], "slicer_merge": [], "slicer_params": [], "sort_blocks": []}

    for _ in range(80):
        boxes = random_boxes(rng, rng.randint(0, 25))
        shape = (rng.randint(200, 500), rng.randint(200, 500))
        filtered = filter_and_fix_bboxes(boxes, shape)
        data["filter_and_fix"].append({"boxes": boxes, "h": shape[0], "w": shape[1], "out": filtered.tolist()})

    for _ in range(80):
        boxes = [b for b in random_boxes(rng, rng.randint(0, 20)) if b[2] > b[0] and b[3] > b[1]]
        merged = merge_overlapping_boxes(np.array(boxes, dtype=int)) if boxes else np.array([])
        data["merge_overlapping"].append({"boxes": boxes, "out": merged.tolist()})

    slicer = ImageSlicer()
    for _ in range(80):
        boxes = [b for b in random_boxes(rng, rng.randint(0, 20), size=3000) if b[2] > b[0] and b[3] > b[1]]
        height = rng.randint(1000, 8000)
        if boxes:
            merged, _ = slicer.merge_overlapping_boxes(np.array(boxes, dtype=float), image_height=height)
            merged = merged.tolist()
        else:
            merged = []
        data["slicer_merge"].append({"boxes": boxes, "image_height": height, "out": merged})

    for _ in range(40):
        w = rng.randint(200, 1500)
        h = rng.randint(100, 20000)
        img = np.zeros((h, w, 1), dtype=np.uint8)
        should = slicer.should_slice(img)
        params = slicer.calculate_slice_params(img) if should else None
        data["slicer_params"].append({"h": h, "w": w, "should_slice": should, "params": params})

    for i in range(60):
        blocks = []
        for b in random_boxes(rng, rng.randint(1, 15), size=600):
            if b[2] <= b[0] or b[3] <= b[1]:
                continue
            blk = TextBlock(text_bbox=np.array(b))
            blk.direction = rng.choice(["horizontal", "vertical", ""])
            blocks.append(blk)
        rtl = bool(i % 2)
        order = sort_blk_list(list(blocks), rtl)
        index = {id(b): k for k, b in enumerate(blocks)}
        data["sort_blocks"].append({
            "blocks": [{"xyxy": [int(v) for v in b.xyxy], "direction": b.direction} for b in blocks],
            "rtl": rtl,
            "order": [index[id(b)] for b in order],
        })

    write_json(out / "geometry.json", data)


# -------------------------------------------------------------- detection ---

def gen_detection(out: Path, pages_dir: Path, models_dir: Path) -> None:
    from PIL import Image

    import modules.detection.rtdetr_v2_onnx as rt
    from modules.detection.font.engine import extract_foreground_color
    from modules.detection.utils.content import filter_and_fix_bboxes
    from modules.detection.utils.geometry import merge_overlapping_boxes
    from modules.utils.textblock import sort_blk_list

    model_path = models_dir / "rtdetr-v2-int8" / "detector-v4-s_int8.onnx"
    if not model_path.exists():
        sys.exit(f"Model not found: {model_path}. Run: cts models download rtdetr-v2-int8")

    # Use our verified model file instead of the original's downloader.
    rt.ModelDownloader.get_file_path = staticmethod(lambda *_args, **_kw: str(model_path))
    detector = rt.RTDetrV2ONNXDetection(settings=None)
    detector.initialize(device="cpu")

    pages: list[tuple[str, np.ndarray]] = []
    for path in sorted(pages_dir.glob("*.jpg")):
        pages.append((path.stem, decode_rgb(path)))
    # A tall synthetic "webtoon" page to exercise slicing.
    strip = [img for name, img in pages if name in ("en_E01P01", "en_E01P02", "en_E01P03")]
    if len(strip) == 3 and len({img.shape[1] for img in strip}) == 1:
        pages.append(("webtoon_en_E01P01-03", np.vstack(strip)))

    for name, image in pages:
        h, w = image.shape[:2]
        record: dict = {"page": name, "height": h, "width": w, "rgb_sha256": sha256(image)}

        resized = np.asarray(Image.fromarray(image).resize((640, 640)))
        record["preprocess_sha256"] = sha256(resized)

        # Raw model outputs on the full page (no slicing), before thresholding.
        arr = np.transpose(resized.astype(np.float32) / 255.0, (2, 0, 1))[np.newaxis, ...]
        labels, boxes, scores = detector.session.run(None, {
            "images": arr, "orig_target_sizes": np.array([[w, h]], dtype=np.int64),
        })[:3]
        keep = np.argsort(-scores[0])[:60]
        record["raw_top"] = [
            {"label": int(labels[0][k]), "score": float(scores[0][k]), "box": [float(v) for v in boxes[0][k]]}
            for k in keep
        ]

        bubble_boxes, text_boxes = detector.image_slicer.process_slices_for_detection(image, detector._detect_single_image)
        record["sliced"] = detector.image_slicer.should_slice(image)
        record["bubble_boxes"] = to_py(bubble_boxes)
        record["text_boxes"] = to_py(text_boxes)

        filtered_text = filter_and_fix_bboxes(text_boxes, image.shape)
        record["filtered_text_boxes"] = filtered_text.tolist()
        record["filtered_bubble_boxes"] = filter_and_fix_bboxes(bubble_boxes, image.shape).tolist()
        record["merged_text_boxes"] = merge_overlapping_boxes(filtered_text).tolist() if len(filtered_text) else []

        blocks = detector.create_text_blocks(image, text_boxes, bubble_boxes)
        record["blocks"] = [block_to_json(b) for b in blocks]
        index = {id(b): k for k, b in enumerate(blocks)}
        record["sorted_order"] = [index[id(b)] for b in sort_blk_list(list(blocks), False)]

        # Foreground colour of each merged text box, computed in isolation.
        colors = []
        for box in record["merged_text_boxes"]:
            x1, y1, x2, y2 = (int(v) for v in box)
            colors.append(to_py(extract_foreground_color(image[max(0, y1):min(h, y2), max(0, x1):min(w, x2)])))
        record["foreground_colors"] = colors

        write_json(out / "detection" / f"{name}.json", record)


# ------------------------------------------------------------- heuristics ---

def transform_crop(crop: np.ndarray, transform: str) -> np.ndarray:
    if transform == "rot90":  # counter-clockwise, turns text rows into columns
        return np.ascontiguousarray(np.rot90(crop))
    if transform == "invert":
        return 255 - crop
    return crop


def gen_heuristics(out: Path, pages_dir: Path, detection_dir: Path) -> None:
    """Line/direction heuristics on many crops: detected blocks and bubbles,
    rotated (vertical text), inverted and random regions of every page."""
    from modules.detection.heuristic_lines.core import _detect_lines_and_direction_in_crop

    rng = random.Random(SEED)
    pages = {path.stem: decode_rgb(path) for path in sorted(pages_dir.glob("*.jpg"))}
    cases = []
    for name in sorted(pages):
        image = pages[name]
        h, w = image.shape[:2]
        ref_path = detection_dir / f"{name}.json"
        if not ref_path.exists():
            sys.exit(f"Missing {ref_path}; generate the detection section first")
        ref = json.loads(ref_path.read_text(encoding="utf-8"))

        crops: list[tuple[list[int], list[tuple[str, str]]]] = []
        for blk in ref["blocks"]:
            x1, y1, x2, y2 = blk["xyxy"]
            for pct in (4, 15):
                dx, dy = (x2 - x1) * pct / 100.0, (y2 - y1) * pct / 100.0
                box = [max(0, round(x1 - dx)), max(0, round(y1 - dy)), min(w, round(x2 + dx)), min(h, round(y2 + dy))]
                variants = [("none", ""), ("rot90", ""), ("rot90", "ja"), ("invert", "")] if pct == 4 else [("none", ""), ("rot90", "zh")]
                crops.append((box, variants))
        for box in ref["filtered_bubble_boxes"]:
            x1, y1, x2, y2 = (int(v) for v in box)
            crops.append(([max(0, x1), max(0, y1), min(w, x2), min(h, y2)], [("none", ""), ("rot90", "ja")]))
        for _ in range(12):
            bw, bh = rng.randint(30, 520), rng.randint(30, 520)
            x1, y1 = rng.randint(0, w - bw), rng.randint(0, h - bh)
            crops.append(([x1, y1, x1 + bw, y1 + bh], [("none", ""), (rng.choice(["rot90", "invert"]), rng.choice(["", "ja", "ko"]))]))

        for box, variants in crops:
            x1, y1, x2, y2 = box
            if x2 <= x1 or y2 <= y1:
                continue
            for transform, lang in variants:
                crop = transform_crop(image[y1:y2, x1:x2], transform)
                case = {"page": name, "box": box, "transform": transform, "lang": lang}
                try:
                    lines, direction = _detect_lines_and_direction_in_crop(crop, lang)
                    case["lines"] = to_py(lines)
                    case["direction"] = direction
                except Exception as e:  # the Dart port must fail the same way
                    case["error"] = type(e).__name__
                cases.append(case)
    write_json(out / "heuristics.json", {"cases": cases})


# -------------------------------------------------------------------- ocr ---

# Our model directories (packages/ct_core ModelCatalog) per original ModelID.
OCR_MODEL_DIRS = {
    "PPOCR_V5_REC_EN_MOBILE": "ppocr-v5-rec-en",
    "PPOCR_V5_REC_LATIN_MOBILE": "ppocr-v5-rec-latin",
    "PPOCR_V5_REC_ESLAV_MOBILE": "ppocr-v5-rec-eslav",
    "PPOCR_V5_REC_KOREAN_MOBILE": "ppocr-v5-rec-korean",
    "PPOCR_V6_REC_SMALL": "ppocr-v6-rec-small",
    "MANGA_OCR_MOBILE_ONNX": "manga-ocr-mobile",
    "OSD_SCRIPT_DETECTOR_ONNX": "osd-script-id",
}

# Page -> (PP-OCR language, source language code) runs.
OCR_RUNS = {
    "en": [("en", "en"), ("latin", "fr")],
    "ru": [("ru", "ru")],
    "kr": [("ko", "ko")],
    "cn": [("ch", "zh")],
    "ja": [("ja", "ja")],
}


def patch_model_downloader(models_dir: Path) -> None:
    from modules.utils.download import ModelDownloader, ModelID

    def local_map(model):
        spec = ModelDownloader.registry[model] if isinstance(model, ModelID) else model
        folder = models_dir / OCR_MODEL_DIRS[spec.id.name]
        return {name: str(folder / name) for name in spec.files}

    ModelDownloader.ensure = classmethod(lambda cls, models: None)
    ModelDownloader.file_path_map = classmethod(lambda cls, model: local_map(model))
    ModelDownloader.primary_path = classmethod(lambda cls, model: next(iter(local_map(model).values())))
    ModelDownloader.get_file_path = classmethod(lambda cls, model, file_name: local_map(model)[file_name])


def gen_ocr(out: Path, pages_dir: Path, models_dir: Path, detection_dir: Path) -> None:
    """PP-OCR recognition of the detected blocks (with their heuristic lines)."""
    import modules.ocr.ppocr.engine as eng
    from modules.utils.textblock import TextBlock

    patch_model_downloader(models_dir)
    engines: dict[str, object] = {}
    for ref_path in sorted(detection_dir.glob("*.json")):
        ref = json.loads(ref_path.read_text(encoding="utf-8"))
        name = ref["page"]
        if name.startswith("webtoon_"):
            continue
        image = decode_rgb(pages_dir / f"{name}.jpg")
        for lang, code in OCR_RUNS[name.split("_")[0]]:
            if lang not in engines:
                e = eng.PPOCRv5Engine()
                e.initialize(lang=lang, device="cpu")
                engines[lang] = e
            engine = engines[lang]
            blocks = []
            for b in ref["blocks"]:
                blk = TextBlock(
                    text_bbox=np.array(b["xyxy"]),
                    bubble_bbox=None if b["bubble_xyxy"] is None else np.array(b["bubble_xyxy"]),
                    text_class=b["text_class"],
                    lines=b["lines"],
                    direction=b["direction"],
                    source_lang=code,
                )
                blocks.append(blk)

            crops_log: list[dict] = []
            original_rec = eng.PPOCRv5Engine._rec_infer
            original_norm = eng.rec_resize_norm

            def logging_norm(img, img_shape=(3, 48, 320), max_wh_ratio=None):
                x = original_norm(img, img_shape, max_wh_ratio)
                crops_log.append({"input_shape": list(x.shape), "input_sha256": sha256(x.astype(np.float32))})
                return x

            recorded = {}

            def capture_rec(self, crops):
                recorded["crops"] = [{"w": int(c.shape[1]), "h": int(c.shape[0]), "sha256": sha256(np.ascontiguousarray(c))} for c in crops]
                texts, confs = original_rec(self, crops)
                recorded["texts"] = list(texts)
                recorded["confs"] = [float(v) for v in confs]
                return texts, confs

            eng.rec_resize_norm = logging_norm
            eng.PPOCRv5Engine._rec_infer = capture_rec
            try:
                engine.process_image(image, blocks)
            finally:
                eng.rec_resize_norm = original_norm
                eng.PPOCRv5Engine._rec_infer = original_rec

            # Inputs were logged in bucket order; recorded crops are in page order.
            write_json(out / "ocr" / f"{name}.{lang}.json", {
                "page": name,
                "lang": lang,
                "source_lang": code,
                "crops": recorded.get("crops", []),
                "rec_texts": recorded.get("texts", []),
                "rec_confs": recorded.get("confs", []),
                "inputs_in_bucket_order": crops_log,
                "blocks": [{"texts": list(b.texts), "text": b.text, "skipped": to_py(b.skipped_small_texts)} for b in blocks],
            })


def gen_manga_ocr(out: Path, pages_dir: Path, models_dir: Path, detection_dir: Path) -> None:
    """manga-ocr on the Japanese page's blocks, plus its text post-processing."""
    import modules.ocr.manga_ocr.mobile.onnx_engine as mo
    from modules.utils.download import ModelDownloader, ModelID
    from modules.utils.textblock import TextBlock

    patch_model_downloader(models_dir)
    folder = models_dir / OCR_MODEL_DIRS["MANGA_OCR_MOBILE_ONNX"]
    ModelDownloader.get = classmethod(lambda cls, model: None)
    ModelDownloader.get_file_path = classmethod(lambda cls, model, name: str(folder / name))
    model = mo.MangaOCRMobileONNX()

    pages = []
    for name in ["ja_E01P02", "en_E01P02"]:
        ref = json.loads((detection_dir / f"{name}.json").read_text(encoding="utf-8"))
        image = decode_rgb(pages_dir / f"{name}.jpg")
        blocks = []
        for b in ref["blocks"]:
            x1, y1, x2, y2 = b["xyxy"]
            crop = np.ascontiguousarray(image[y1:y2, x1:x2])
            model._preprocess_into(crop)
            input_sha = sha256(model.image_buffer)
            # Token ids: re-run the decoder loop through process_single with a spy on _decode.
            captured = {}
            original_decode = model._decode
            model._decode = lambda ids: (captured.__setitem__("ids", list(ids)), original_decode(ids))[1]
            try:
                text = model.process_single(crop)
            finally:
                model._decode = original_decode
            blocks.append({"xyxy": b["xyxy"], "input_sha256": input_sha, "token_ids": captured["ids"], "text": text})
        pages.append({"page": name, "blocks": blocks})

    samples = [
        "ｶﾞｷﾞｸﾞﾊﾟﾋﾟｳﾞｱｲｳ", "abc XYZ 123!?", "ﾃｨﾛﾌｨﾅｰﾚ", "それは…………すごい", "....", "・・・・・・",
        "えええええええええええええええええ", "ーーーーーーーーーーーー", "………………………………", "。。。。。。。。。。。。。",
        "あ　い" + chr(9) + "う" + chr(10) + "え", "ＡＢＣ１２３", "~~~~~~~~~", "!?!?..........!?", "ok.....ok",
        "ア" * 20 + "イ",
    ]
    # The engine's literal mojibake strings (an ellipsis and a dot class).
    engine_src = Path(mo.__file__).read_text(encoding="utf-8")
    mojibake = engine_src.split('text.replace("', 1)[1].split('"', 1)[0]
    samples += ["a" + mojibake + "b", mojibake[:3] * 2 + "x"]
    text_cases = [{"in": t, "out": model._postprocess(t)} for t in samples]
    write_json(out / "manga_ocr.json", {"pages": pages, "postprocess": text_cases, "vocab_size": model.vocab_size})


# ----------------------------------------------------------------- script ---

# Labels beyond the model's own, for the "Auto" language helpers.
EXTRA_SCRIPT_LABELS = ["", "Japanese_vert", "HanS_vert", "HanT-dn", "Latin_vert-dn", "Hangul_vert", "Unknown"]


def gen_script(out: Path, pages_dir: Path, models_dir: Path, detection_dir: Path) -> None:
    """OSD script identification of the detected blocks ("Auto" source language) and the
    helpers that route blocks by script: OCR bucket, language code, page language."""
    import modules.detection.script_detection as sd
    from modules.utils.language_utils import (
        get_dominant_page_script, get_lang_code_for_script, get_ocr_bucket_for_script,
        get_source_language_for_script, is_supported_script, normalize_script, resolve_auto_source_language,
    )
    from modules.utils.textblock import TextBlock

    patch_model_downloader(models_dir)
    detector = sd.ScriptDetector()
    detector.initialize()

    pages = []
    for ref_path in sorted(detection_dir.glob("*.json")):
        ref = json.loads(ref_path.read_text(encoding="utf-8"))
        name = ref["page"]
        if name.startswith("webtoon_"):
            continue
        image = decode_rgb(pages_dir / f"{name}.jpg")
        # With the detector's lines; without them (lines found again in the crop); white on black.
        variants = {"lines": (image, True), "no_lines": (image, False), "inverted": (255 - image, True)}
        page: dict = {"page": name, "variants": {}}
        for variant, (img, keep_lines) in variants.items():
            blocks = [
                TextBlock(
                    text_bbox=np.array(b["xyxy"]),
                    bubble_bbox=None if b["bubble_xyxy"] is None else np.array(b["bubble_xyxy"]),
                    text_class=b["text_class"],
                    lines=b["lines"] if keep_lines else [],
                    direction=b["direction"] if keep_lines else "",
                )
                for b in ref["blocks"]
            ]
            results = []
            for blk in blocks:
                entry: dict = {}
                found = sd._largest_line_crop(img, blk)
                if found is not None:
                    crop, direction = found
                    entry["crop"] = [int(crop.shape[0]), int(crop.shape[1])]
                    entry["direction"] = direction
                    if crop.size and crop.shape[0] >= 3 and crop.shape[1] >= 3:
                        if direction == "vertical":
                            crop = np.rot90(crop, k=1)
                        pixels = sd._preprocess(crop)
                        entry["input_width"] = int(pixels.shape[-1])
                        entry["input_sha256"] = sha256(pixels)
                        if pixels.shape[-1] >= 3:
                            scores = detector.session.run(None, {"image": pixels})[0]
                            entry["scores_shape"] = list(scores.shape)
                            entry["ids"] = scores.argmax(axis=1).tolist()
                blk.script = detector.detect_block_script(img, blk)
                entry["script"] = blk.script
                results.append(entry)
            page["variants"][variant] = {
                "blocks": results,
                "dominant": get_dominant_page_script(blocks),
                "dominant_any": get_dominant_page_script(blocks, 0.0),
                "resolved": resolve_auto_source_language(blocks, "Auto"),
            }
        pages.append(page)

    labels = list(detector.labels) + EXTRA_SCRIPT_LABELS
    helpers = [{
        "label": label,
        "normalized": normalize_script(label),
        "supported": is_supported_script(label),
        "bucket": get_ocr_bucket_for_script(label),
        "code": get_lang_code_for_script(label),
        "source": get_source_language_for_script(label),
    } for label in labels]

    # Page language from block scripts weighted by area.
    rng = random.Random(SEED + 11)
    choices = ["Latin", "Cyrillic", "Japanese", "Japanese_vert", "Hangul", "HanS", "HanT", "", "Greek", "Arabic"]
    dominant = []
    for _ in range(80):
        blocks = []
        for _ in range(rng.randint(0, 8)):
            x1, y1 = rng.randint(0, 400), rng.randint(0, 400)
            box = [x1, y1, x1 + rng.randint(-3, 200), y1 + rng.randint(-3, 150)]
            blocks.append(TextBlock(text_bbox=np.array(box), script=rng.choice(choices)))
        dominant.append({
            "blocks": [{"xyxy": b.xyxy.tolist(), "script": b.script} for b in blocks],
            "dominant": get_dominant_page_script(blocks),
            "dominant_any": get_dominant_page_script(blocks, 0.0),
            "resolved": resolve_auto_source_language(blocks, "Auto"),
        })

    write_json(out / "script.json", {"labels": detector.labels, "pages": pages, "helpers": helpers, "dominant": dominant})


# ----------------------------------------------------------------- search ---

def gen_search(out: Path, original: Path) -> None:
    """"Preserve case" of find and replace (`_apply_preserve_case`). The module imports the
    whole Qt application, so the function is taken from its source and run alone."""
    import ast

    path = original / "app" / "controllers" / "search_replace.py"
    tree = ast.parse(path.read_text(encoding="utf-8"))
    fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "_apply_preserve_case")
    namespace: dict = {}
    exec(compile(ast.Module(body=[fn], type_ignores=[]), str(path), "exec"), namespace)
    apply = namespace["_apply_preserve_case"]

    matched = ["hello", "HELLO", "Hello", "Hello World", "hELLO", "HeLLo", "привет", "ПРИВЕТ", "Привет",
               "Привет Мир", "ß", "ǅemal", "they're", "X", "x", "123", "1st", "Ünder", "ΣΊΣΥΦΟΣ", "", "a-b", "Mc"]
    replacements = ["world", "WORLD", "World", "big world", "мир", "большой мир", "straße", "x", "ǆungla",
                    "o'neil", "", "1two", "éclair", "ﬁne"]
    cases = [{"matched": m, "replacement": r, "out": apply(m, r)} for m in matched for r in replacements]
    write_json(out / "search.json", {"preserve_case": cases})


# ------------------------------------------------------------ translation ---

def gen_translation(out: Path) -> None:
    """The LLM translation protocol: prompts, block JSON, reply parsing, filters."""
    from modules.translation.base import LLMTranslation
    from modules.utils.textblock import TextBlock
    from modules.utils.translator_utils import (
        get_raw_text, has_translatable_content, set_texts_from_json, set_upper_case,
    )

    class Prompt(LLMTranslation):
        def initialize(self, *a, **k): pass
        def translate(self, *a, **k): pass

    texts_sets = [
        [],
        ["Hello!", "NO! Don't even think about it.", "..."],
        ["ダメ！そんなことしちゃだめなんだから", "환력", "Ах.. идеально", 'He said "hi" \\ back', "tab\there\nnew line", "\x01ctrl\x1f"],
        ["", "   ", "!?", "5", "何", "€"],
    ]
    prompts = []
    for src, tgt in [("English", "Russian"), ("Japanese", "English"), ("Korean", "Simplified Chinese")]:
        prompts.append({"source": src, "target": tgt, "system": Prompt().get_system_prompt(src, tgt)})

    raw = []
    for texts in texts_sets:
        blocks = [TextBlock(text_bbox=np.array([0, 0, 1, 1]), text=t) for t in texts]
        raw_json = get_raw_text(blocks)
        user = f"{'A comic about witches.'}\nMake the translation sound as natural as possible.\nTranslate this:\n{raw_json}"
        raw.append({"texts": texts, "json": raw_json, "user_prompt": user})

    replies = [
        '{"block_0": "Привет!", "block_1": "НЕТ!"}',
        'Sure! Here you go:\n```json\n{\n  "block_0": "a",\n  "block_2": "c"\n}\n```\nHope it helps {really}',
        "no json at all",
        '{"block_0": 5, "block_1": null, "block_2": "x"}',
    ]
    reply_cases = []
    for reply in replies:
        blocks = [TextBlock(text_bbox=np.array([0, 0, 1, 1]), text=f"t{i}") for i in range(3)]
        for b in blocks:
            b.translation = "old"
        error = None
        try:
            set_texts_from_json(blocks, reply)
        except Exception as e:
            error = type(e).__name__
        reply_cases.append({"reply": reply, "translations": [b.translation if isinstance(b.translation, str) else to_py(b.translation) for b in blocks], "error": error})

    samples = ["", "...", "!?", "a", "5", "何", "ー", "・・・", "€", "½", "Ⅻ", "x²", " \t", "환", "ـ"]
    translatable = [{"text": t, "result": has_translatable_content(t)} for t in samples]

    upper_cases = []
    for t in ["hello world", "HELLO WORLD", "Hello", "привет МИР", "ПРИВЕТ", "123", "ダメ", "ß straße", "ǆ title", "İstanbul", ""]:
        for flag in (True, False):
            blk = TextBlock(text_bbox=np.array([0, 0, 1, 1]))
            blk.translation = t
            set_upper_case([blk], flag)
            upper_cases.append({"in": t, "upper": flag, "out": blk.translation})

    write_json(out / "translation.json", {
        "prompts": prompts, "raw": raw, "replies": reply_cases,
        "translatable": translatable, "upper_case": upper_cases,
    })


# ------------------------------------------------------------------- mask ---

def gen_mask(out: Path, pages_dir: Path, detection_dir: Path) -> None:
    """Morphology/contour/blur primitives and generate_mask on every page."""
    import imkit as imk
    import mahotas as mh
    from PIL import Image, ImageFilter
    from modules.utils.image_utils import generate_mask, build_block_mask_data
    from modules.utils.textblock import TextBlock

    rng = np.random.default_rng(SEED + 5)
    prim: dict = {"morph": [], "close_holes": [], "contours": [], "blur": [], "resize_l": []}
    ses = {
        "rect3": np.ones((3, 3), bool), "rect5": np.ones((5, 5), bool), "rect4": np.ones((4, 4), bool),
        "rect17": np.ones((17, 17), bool), "cross3": imk.get_structuring_element(imk.MORPH_CROSS, (3, 3)),
    }
    for i in range(60):
        h, w = (int(v) for v in rng.integers(1, 40, 2))
        a = rng.random((h, w)) < rng.uniform(0.05, 0.6)
        name = list(ses)[i % len(ses)]
        se = ses[name]
        u8 = a.astype(np.uint8) * 255
        prim["morph"].append({
            "h": h, "w": w, "se": name, "a": b64(a.astype(np.uint8)),
            "dilate_bool": b64(mh.dilate(a, se).astype(np.uint8)),
            "erode_bool": b64(mh.erode(a, se).astype(np.uint8)),
            "dilate_u8": b64(mh.dilate(u8, se)), "erode_u8": b64(mh.erode(u8, se)),
            "close_u8": b64(mh.close(u8, se)),
            "imk_dilate3": b64(imk.dilate(u8, se.astype(np.uint8), iterations=3)),
            "imk_erode2": b64(imk.erode(u8, se.astype(np.uint8), iterations=2)),
        })
    for i in range(40):
        h, w = (int(v) for v in rng.integers(3, 40, 2))
        a = rng.random((h, w)) < rng.uniform(0.3, 0.8)
        prim["close_holes"].append({"h": h, "w": w, "a": b64(a.astype(np.uint8)), "out": b64(imk.close_holes(a).astype(np.uint8))})
    for i in range(60):
        h, w = (int(v) for v in rng.integers(1, 50, 2))
        a = (rng.random((h, w)) < rng.uniform(0.05, 0.7)).astype(np.uint8) * 255
        contours, _ = imk.find_contours(a)
        prim["contours"].append({
            "h": h, "w": w, "a": b64(a),
            "contours": [c.reshape(-1, 2).tolist() for c in contours],
            "rects": [list(imk.bounding_rect(c)) for c in contours],
        })
    for i in range(30):
        h, w = (int(v) for v in rng.integers(1, 60, 2))
        a = (rng.random((h, w)) < 0.3).astype(np.uint8) * 255 if i % 2 else rng.integers(0, 256, (h, w), dtype=np.uint8)
        radius = [1.0, 0.5, 2.0, 3.5][i % 4]
        blurred = np.array(Image.fromarray(a).filter(ImageFilter.GaussianBlur(radius=radius)))
        prim["blur"].append({"h": h, "w": w, "radius": radius, "a": b64(a), "out": b64(blurred)})
    for i in range(30):
        h, w = (int(v) for v in rng.integers(1, 80, 2))
        a = rng.integers(0, 256, (h, w), dtype=np.uint8)
        nh, nw = (int(v) for v in rng.integers(1, 120, 2))
        mode = [Image.Resampling.BICUBIC, Image.Resampling.BILINEAR][i % 2]
        prim["resize_l"].append({
            "h": h, "w": w, "nh": nh, "nw": nw, "mode": "bicubic" if i % 2 == 0 else "bilinear",
            "a": b64(a), "out": b64(np.array(Image.fromarray(a).resize((nw, nh), resample=mode))),
        })
    write_json(out / "mask_primitives.json", prim)

    for ref_path in sorted(detection_dir.glob("*.json")):
        ref = json.loads(ref_path.read_text(encoding="utf-8"))
        name = ref["page"]
        if name.startswith("webtoon_"):
            continue
        image = decode_rgb(pages_dir / f"{name}.jpg")
        blocks = []
        for b in ref["blocks"]:
            blocks.append(TextBlock(
                text_bbox=np.array(b["xyxy"]),
                bubble_bbox=None if b["bubble_xyxy"] is None else np.array(b["bubble_xyxy"]),
                text_class=b["text_class"], text="text",
            ))
        per_block = []
        for blk in blocks:
            for clip in (True, False):
                m, bounds = build_block_mask_data(image, blk, clip_to_bubble=clip)
                per_block.append({
                    "clip": clip,
                    "bounds": None if bounds is None else [int(v) for v in bounds],
                    "sha256": None if m is None else sha256(m),
                    "nonzero": None if m is None else int(np.count_nonzero(m)),
                })
        mask = generate_mask(image, blocks)
        write_json(out / "mask" / f"{name}.json", {
            "page": name, "blocks": per_block,
            "mask_sha256": sha256(mask), "mask_nonzero": int(np.count_nonzero(mask)),
            "mask_values": sorted(int(v) for v in np.unique(mask)),
        })


# ---------------------------------------------------------------- inpaint ---

INPAINT_RUNS = [
    # page, inpainter, strategy
    ("en_E06P05", "aot", "Resize"),
    ("en_E01P01", "aot", "Resize"),
    ("ja_E01P02", "aot", "Resize"),
    ("kr_E01P02", "aot", "Original"),
    ("ru_E01P02", "aot", "Crop"),
    ("en_E11P03", "aot", "Resize"),
    ("ja_E01P02", "lama", "Resize"),
    ("en_E01P01", "lama", "Original"),
]


def gen_inpaint(out: Path, pages_dir: Path, models_dir: Path, detection_dir: Path) -> None:
    """Fast bubble fill, patch/full routing and AOT/LaMa results on test pages."""
    import imkit as imk
    from modules.inpainting.schema import Config
    from modules.utils.download import ModelDownloader, ModelID
    from modules.utils.image_utils import generate_mask
    from modules.utils.textblock import TextBlock
    import types
    # pipeline.inpainting imports the settings UI (and through it accounts);
    # only these names are used, and not by inpaint_image.
    stub = types.ModuleType("modules.utils.pipeline_config")
    stub.inpaint_map, stub.get_config, stub.get_inpainter_backend = {}, None, None
    sys.modules.setdefault("modules.utils.pipeline_config", stub)
    import pipeline.inpainting as pin

    files = {
        "AOT_ONNX": models_dir / "aot-inpainting" / "aot.onnx",
        "LAMA_ONNX": models_dir / "lama-manga" / "lama-manga-dynamic.onnx",
    }
    ModelDownloader.get = classmethod(lambda cls, model: None)
    ModelDownloader.primary_path = classmethod(lambda cls, model: str(files[model.name if isinstance(model, ModelID) else model.id.name]))
    from modules.inpainting.aot import AOT
    from modules.inpainting.lama import LaMa
    models = {"aot": AOT("cpu", backend="onnx"), "lama": LaMa("cpu", backend="onnx")}

    for name, model_name, strategy in INPAINT_RUNS:
        ref = json.loads((detection_dir / f"{name}.json").read_text(encoding="utf-8"))
        image = decode_rgb(pages_dir / f"{name}.jpg")
        blocks = [
            TextBlock(
                text_bbox=np.array(b["xyxy"]),
                bubble_bbox=None if b["bubble_xyxy"] is None else np.array(b["bubble_xyxy"]),
                text_class=b["text_class"], text="text", translation="x",
            )
            for b in ref["blocks"]
        ]
        mask = generate_mask(image, blocks)
        if strategy == "Resize":
            config = Config(hd_strategy="Resize", hd_strategy_resize_limit=960)
        elif strategy == "Crop":
            config = Config(hd_strategy="Crop", hd_strategy_crop_margin=512, hd_strategy_crop_trigger_size=512)
        else:
            config = Config(hd_strategy="Original")

        handler = pin.InpaintingHandler(None)
        handler.inpainter_cache = models[model_name]
        working_image, working_mask, cleaned = handler._apply_fast_bubble_cleanup(image.copy(), mask.copy(), blocks)
        calls = []
        original_full, original_patches = handler._inpaint_full_image, handler._inpaint_by_patches
        handler._inpaint_full_image = lambda i, m, c: (calls.append("full"), original_full(i, m, c))[1]
        handler._inpaint_by_patches = lambda i, m, c: (calls.append("patches"), original_patches(i, m, c))[1]
        result = handler.inpaint_image(image.copy(), mask.copy(), config, blk_list=blocks)
        result = imk.convert_scale_abs(result)

        ys, xs = np.nonzero(mask)
        region = None
        if ys.size:
            y1, y2, x1, x2 = int(ys.min()), int(ys.max()) + 1, int(xs.min()), int(xs.max()) + 1
            png = imk.encode_image(result[y1:y2, x1:x2], "png")
            # Pixels only for small regions (fallback comparison on CPUs whose
            # ONNX Runtime kernels round differently); the hash is the check.
            region = {"box": [x1, y1, x2, y2], "png": base64.b64encode(png).decode("ascii") if len(png) < 400_000 else None}
        write_json(out / "inpaint" / f"{name}.{model_name}.json", {
            "page": name, "model": model_name, "strategy": strategy,
            "mask_sha256": sha256(mask),
            "fast_filled_blocks": int(cleaned),
            "fast_fill_image_sha256": sha256(working_image),
            "residual_mask_sha256": sha256(working_mask),
            "residual_nonzero": int(np.count_nonzero(working_mask)),
            "mode": calls[0] if calls else "none",
            "result_sha256": sha256(result),
            "result_region": region,
        })


# ----------------------------------------------------------------- render ---

def gen_render(out: Path) -> None:
    """Greedy wrapping of render.py with a deterministic measure (characters x 7)."""
    from modules.rendering.render import _wrap_text_greedily, _wrap_no_space_text_greedily

    def measure(text):
        return max((len(line) for line in text.split("\n")), default=0) * 7.0

    texts = [
        "Hello there, how are you today?",
        "A well-known self-taught jack-of-all-trades arrived.",
        "Supercalifragilisticexpialidocious is long",
        "  spaces   everywhere \n and newlines  ",
        "",
        "Так-то вот, ребята-демократы, по-моему, всё-таки нет.",
        "word-",
        "-word",
        "a b c d e f g h",
    ]
    no_space = ["ダメ！そんなことしちゃだめなんだから", "哈…成功了！ 不行！想都別想！", "一行目\n二行目の長い文章です", ""]
    cases = []
    for t in texts:
        for max_side in (30.0, 70.0, 120.0, 400.0):
            cases.append({"text": t, "max": max_side, "no_space": False, "out": _wrap_text_greedily(t, measure, max_side)})
    for t in no_space:
        for max_side in (14.0, 35.0, 70.0):
            cases.append({"text": t, "max": max_side, "no_space": True, "out": _wrap_no_space_text_greedily(t, measure, max_side)})
    write_json(out / "render.json", {"wrap": cases})


# ------------------------------------------------------------ ppocr lines ---

def gen_ppocr_lines(out: Path, pages_dir: Path, models_dir: Path) -> None:
    """PP-OCRv5 line detection of `PPOCRLineDetector.detect_lines` on every page."""
    from modules.detection.ppocr_lines import _axis_box, _merge_line_boxes
    from modules.ocr.ppocr.postprocessing import DBPostProcessor
    from modules.ocr.ppocr.preprocessing import det_preprocess
    import onnxruntime as ort

    model_path = models_dir / "ppocr-v5-det-mobile" / "ch_PP-OCRv5_mobile_det.onnx"
    if not model_path.exists():
        sys.exit(f"Model not found: {model_path}. Run: cts models download ppocr-v5-det-mobile")
    session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    post = DBPostProcessor(thresh=0.3, box_thresh=0.5, unclip_ratio=2.0, use_dilation=False)

    records = []
    for path in sorted(pages_dir.glob("*.jpg")):
        image = decode_rgb(path)
        h, w = image.shape[:2]
        inp = det_preprocess(image, limit_side_len=960, limit_type="min")
        pred = session.run([session.get_outputs()[0].name], {session.get_inputs()[0].name: inp})[0]
        quads, scores = post(pred, (h, w))
        boxes = [_axis_box(q) for q in quads]
        records.append({
            "page": path.stem,
            "input_shape": list(inp.shape),
            "input_sha256": sha256(inp),
            "prob_mean": float(pred.mean()),
            "quads": [q.tolist() for q in quads],
            "scores": scores,
            "lines": _merge_line_boxes(boxes, w, h),
        })
    write_json(out / "ppocr_lines.json", records)


# -------------------------------------------------------------- text prep ---
# Not in the original: the neural text preparation of this project (step 2),
# with the tiling of the experiment that chose the models
# (`ocr-experiment/sr_run.py`).

TEXT_PREP_MODELS = [
    # (model id, file, scale, pad, crop w×h)
    ("waifu2x-cunet-art-2x", "waifu2x_cunet_art_scale2x.onnx", 2, 18, (200, 150)),
    ("waifu2x-swin-art-2x", "waifu2x_swin_unet_art_scale2x.onnx", 2, 8, (200, 150)),
    ("fatality-comix-4x", "fatality_comix_4x.onnx", 4, 0, (100, 75)),
]


def sr_upscale(session, img: np.ndarray, scale: int, pad: int, tile: int = 192, overlap: int = 16) -> np.ndarray:
    """img HxWx3 uint8 -> upscaled uint8, tiled with overlap (`upscale` of sr_run.py)."""
    img = img.astype(np.float32) / 255
    h, w, _ = img.shape
    src = np.pad(img, ((pad, pad), (pad, pad), (0, 0)), mode="reflect") if pad else img
    out = np.zeros((h * scale, w * scale, 3), np.float32)
    step = tile - 2 * overlap
    for y0 in range(0, h, step):
        for x0 in range(0, w, step):
            ya, xa = max(0, y0 - overlap), max(0, x0 - overlap)
            yb, xb = min(h, y0 + step + overlap), min(w, x0 + step + overlap)
            crop = src[ya:yb + 2 * pad, xa:xb + 2 * pad]
            ch, cw = crop.shape[0] - 2 * pad, crop.shape[1] - 2 * pad
            eh, ew = -ch % 16, -cw % 16
            if eh or ew:
                crop = np.pad(crop, ((0, eh), (0, ew), (0, 0)), mode="edge")
            x = crop.transpose(2, 0, 1)[None].copy()
            y = session.run(None, {session.get_inputs()[0].name: x})[0][0].transpose(1, 2, 0)[: ch * scale, : cw * scale]
            iy, ix = (y0 - ya) * scale, (x0 - xa) * scale
            hh, ww = (min(h, y0 + step) - y0) * scale, (min(w, x0 + step) - x0) * scale
            out[y0 * scale:y0 * scale + hh, x0 * scale:x0 * scale + ww] = y[iy:iy + hh, ix:ix + ww]
    return (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)


def gen_text_prep(out: Path, pages_dir: Path, models_dir: Path, detection_dir: Path) -> None:
    """Each text preparation network on a crop around the first text block of en_E01P01."""
    import onnxruntime as ort

    image = decode_rgb(pages_dir / "en_E01P01.jpg")
    det = json.loads((detection_dir / "en_E01P01.json").read_text(encoding="utf-8"))
    x1, y1 = det["blocks"][0]["xyxy"][:2]
    records = []
    for model_id, file, scale, pad, (cw, ch) in TEXT_PREP_MODELS:
        path = models_dir / model_id / file
        if not path.exists():
            sys.exit(f"Model not found: {path}. Run: cts models download {model_id}")
        session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
        crop = np.ascontiguousarray(image[y1:y1 + ch, x1:x1 + cw])
        y = sr_upscale(session, crop, scale, pad)
        records.append({
            "model": model_id, "scale": scale, "pad": pad, "crop": [int(x1), int(y1), int(x1) + cw, int(y1) + ch],
            "out_shape": list(y.shape), "out_sha256": sha256(y), "out_mean": float(y.mean()),
        })
    write_json(out / "text_prep.json", records)


# ------------------------------------------------------------------- main ---

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--original", type=Path, default=Path(os.environ.get("CT_ORIGINAL_DIR", DEFAULT_ORIGINAL)))
    ap.add_argument("--pages", type=Path, default=DEFAULT_PAGES)
    ap.add_argument("--models", type=Path, default=DEFAULT_MODELS)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--only", choices=["primitives", "geometry", "detection", "heuristics", "ocr", "manga_ocr", "script", "search", "translation", "mask", "inpaint", "render", "ppocr_lines", "text_prep"], action="append")
    args = ap.parse_args()

    original = args.original.resolve()
    if not (original / "modules").is_dir():
        sys.exit(f"Original comic-translate checkout not found at {original}")
    sys.path.insert(0, str(original))

    import mahotas
    import onnxruntime
    import PIL

    try:
        commit = subprocess.run(["git", "-C", str(original), "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        commit = "unknown"
    write_json(args.out / "meta.json", {
        "original_commit": commit,
        "seed": SEED,
        "versions": {
            "python": sys.version.split()[0], "numpy": np.__version__, "pillow": PIL.__version__,
            "mahotas": mahotas.__version__, "onnxruntime": onnxruntime.__version__, "opencv": cv2.__version__,
        },
        "decoder": "cv2.imdecode(IMREAD_COLOR) + BGR2RGB",
    })

    only = set(args.only or ["primitives", "geometry", "detection", "heuristics", "ocr", "manga_ocr", "script", "search", "translation", "mask", "inpaint", "render", "ppocr_lines"])
    if "primitives" in only:
        gen_primitives(args.out)
    if "geometry" in only:
        gen_geometry(args.out)
    if "detection" in only:
        gen_detection(args.out, args.pages, args.models)
    if "heuristics" in only:
        gen_heuristics(args.out, args.pages, args.out / "detection")
    if "ocr" in only:
        gen_ocr(args.out, args.pages, args.models, args.out / "detection")
    if "manga_ocr" in only:
        gen_manga_ocr(args.out, args.pages, args.models, args.out / "detection")
    if "script" in only:
        gen_script(args.out, args.pages, args.models, args.out / "detection")
    if "search" in only:
        gen_search(args.out, original)
    if "translation" in only:
        gen_translation(args.out)
    if "mask" in only:
        gen_mask(args.out, args.pages, args.out / "detection")
    if "inpaint" in only:
        gen_inpaint(args.out, args.pages, args.models, args.out / "detection")
    if "render" in only:
        gen_render(args.out)
    if "ppocr_lines" in only:
        gen_ppocr_lines(args.out, args.pages, args.models)
    if "text_prep" in only:
        gen_text_prep(args.out, args.pages, args.models, args.out / "detection")


if __name__ == "__main__":
    main()

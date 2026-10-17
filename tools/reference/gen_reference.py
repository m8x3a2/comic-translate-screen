"""Generate parity reference data by running the original comic-translate code.

    uv run python -B gen_reference.py [--original DIR] [--only primitives|geometry|detection]

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
    path.write_text(json.dumps(to_py(data), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
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


# ------------------------------------------------------------------- main ---

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--original", type=Path, default=Path(os.environ.get("CT_ORIGINAL_DIR", DEFAULT_ORIGINAL)))
    ap.add_argument("--pages", type=Path, default=DEFAULT_PAGES)
    ap.add_argument("--models", type=Path, default=DEFAULT_MODELS)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--only", choices=["primitives", "geometry", "detection"], action="append")
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

    only = set(args.only or ["primitives", "geometry", "detection"])
    if "primitives" in only:
        gen_primitives(args.out)
    if "geometry" in only:
        gen_geometry(args.out)
    if "detection" in only:
        gen_detection(args.out, args.pages, args.models)


if __name__ == "__main__":
    main()

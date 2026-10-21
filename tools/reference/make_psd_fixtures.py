"""Writes the PSD test files in test_data/psd with PhotoshopAPI, the library
the original program exports and imports PSD files with.

    uv run --with photoshopapi==0.9.1 --with numpy python -B -I tools/reference/make_psd_fixtures.py
"""

import pathlib

import numpy as np
import photoshopapi as psapi

OUT = pathlib.Path(__file__).resolve().parents[2] / "test_data" / "psd"
W, H = 64, 48


def chw(rgb, alpha=255):
    a = np.full(rgb.shape[:2] + (1,), alpha, np.uint8)
    return np.ascontiguousarray(np.transpose(np.concatenate([rgb, a], 2), (2, 0, 1)))


def page():
    img = np.full((H, W, 3), 255, np.uint8)
    img[10:30, 10:40] = 90
    return img


def text(name, value, x, y, w, h):
    return psapi.TextLayer_8bit(
        layer_name=name, text=value, font="ArialMT", font_size=18.0,
        fill_color=[1.0, 0.0, 0.0, 0.0], position_x=x, position_y=y, box_width=w, box_height=h,
    )


def original_export():
    """Laid out as the original's psd_exporter.py writes a page."""
    doc = psapi.LayeredFile_8bit(psapi.enum.ColorMode.rgb, W, H)
    doc.dpi = 300.0
    group = psapi.GroupLayer_8bit("Editable Text")
    doc.add_layer(group)
    group.add_layer(doc, text("Text 1", "HELLO,\nworld", 12.0, 14.0, 40.0, 24.0))
    patches = psapi.GroupLayer_8bit("Inpaint Patches")
    doc.add_layer(patches)
    patch = np.full((6, 8, 3), 255, np.uint8)
    patches.add_layer(doc, psapi.ImageLayer_8bit(chw(patch), "Patch 1", width=8, height=6, pos_x=24, pos_y=23))
    doc.add_layer(psapi.ImageLayer_8bit(chw(page()), "Raw Image", width=W, height=H, pos_x=W / 2, pos_y=H / 2))
    doc.write(str(OUT / "original_export.psd"), force_overwrite=True)


def other_program():
    """Someone else's file: a background, a half-transparent layer, text."""
    doc = psapi.LayeredFile_8bit(psapi.enum.ColorMode.rgb, W, H)
    doc.add_layer(text("Caption", "Hi", 4.0, 30.0, 30.0, 16.0))
    red = np.zeros((10, 10, 3), np.uint8)
    red[..., 0] = 255
    doc.add_layer(psapi.ImageLayer_8bit(chw(red), "Red", width=10, height=10, pos_x=55, pos_y=5))
    hidden = np.zeros((H, W, 3), np.uint8)
    layer = psapi.ImageLayer_8bit(chw(hidden), "Hidden", width=W, height=H, pos_x=W / 2, pos_y=H / 2)
    layer.is_visible = False
    doc.add_layer(layer)
    doc.add_layer(psapi.ImageLayer_8bit(chw(page()), "Background", width=W, height=H, pos_x=W / 2, pos_y=H / 2))
    doc.write(str(OUT / "other_program.psd"), force_overwrite=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    original_export()
    other_program()
    print("written to", OUT)

# -*- coding: utf-8 -*-
"""Split the 6x6 white-background emoji sheet (sheet_emoji.png, RGB) into
single transparent WebP emoji assets in assets/emojis/.

Unlike the achievement icons (native-alpha sheets), this sheet is flat RGB on
white, so the pipeline is: flood from the image borders over near-white pixels
to mark the background; the complement is the badge body (enclosed whites such
as masks / tears / eye whites stay, they never touch the outer background).
The body mask is eroded 1px and feathered to kill the anti-aliased white
fringe left along the rounded corners.

源文件与脚本不参与打包（同 docs/achievement_icons 做法）。
"""
import os

import numpy as np
from PIL import Image, ImageFilter

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE, "sheet_emoji.png")
OUT = os.path.join(BASE, "icons")
PROJECT = os.path.dirname(os.path.dirname(BASE))
ASSETS = os.path.join(PROJECT, "assets", "emojis")

ROWS, COLS = 6, 6
BG_DIST = 30          # 与纯白的距离阈值（最浅徽章粉色 ≈51，安全）
ERODE_PX = 1          # 收掉抗锯齿白晕
FEATHER_PX = 1.0      # 边缘羽化

# 按行优先（从左到右、从上到下）命名，避免与 assets/emojis 既有文件重名
NAMES = [
    "giggle",      "sleepy",     "beaming",    "blank",        "knocked_out", "blushing",
    "sad",         "gritting",   "sweating",   "mad",          "cool",        "puzzled",
    "astonished",  "winking",    "worried",    "heart_eyes",   "kissing",     "queasy",
    "glee",        "scared",     "kissy",      "cheesy",       "bawling",     "masked",
    "deadpan",     "uneasy",     "awkward",    "overjoyed",    "relaxed",     "wow",
    "waterworks",  "hysterical", "grumpy",     "goofy",        "stunned",     "pouty",
]


def background_mask(arr: np.ndarray) -> np.ndarray:
    """从整图边缘向内泛洪近白像素，返回 True=背景。"""
    dist = np.sqrt(((arr.astype(np.int16) - 255) ** 2).sum(-1))
    allowed = dist < BG_DIST
    h, w = allowed.shape
    visited = np.zeros((h, w), dtype=bool)
    seed = np.zeros((h, w), dtype=bool)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = True
    seed &= allowed
    visited |= seed
    frontier = visited
    while True:
        grow = np.zeros_like(frontier)
        grow[1:, :] |= frontier[:-1, :]
        grow[:-1, :] |= frontier[1:, :]
        grow[:, 1:] |= frontier[:, :-1]
        grow[:, :-1] |= frontier[:, 1:]
        grow &= allowed & ~visited
        if not grow.any():
            break
        visited |= grow
        frontier = grow
    return visited


def main():
    im = Image.open(SRC).convert("RGB")
    arr = np.asarray(im)
    bg = background_mask(arr)
    h, w = bg.shape

    body = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8), "L")
    body = body.filter(ImageFilter.MinFilter(3 + 2 * (ERODE_PX - 1)))
    body = body.filter(ImageFilter.GaussianBlur(FEATHER_PX))
    body_arr = np.asarray(body)

    os.makedirs(OUT, exist_ok=True)
    os.makedirs(ASSETS, exist_ok=True)
    count = 0
    for r in range(ROWS):
        for c in range(COLS):
            name = NAMES[r * COLS + c]
            x0, x1 = int(w * c / COLS), int(w * (c + 1) / COLS)
            y0, y1 = int(h * r / ROWS), int(h * (r + 1) / ROWS)
            cell = np.dstack([arr[y0:y1, x0:x1], body_arr[y0:y1, x0:x1]])
            ys, xs = np.where(cell[..., 3] > 8)
            pad = 2
            cy0, cy1 = max(0, ys.min() - pad), min(cell.shape[0], ys.max() + pad)
            cx0, cx1 = max(0, xs.min() - pad), min(cell.shape[1], xs.max() + pad)
            result = Image.fromarray(cell[cy0:cy1, cx0:cx1])
            png_path = os.path.join(OUT, "E{:02d}_{}.png".format(r * COLS + c + 1, name))
            result.save(png_path)
            webp_path = os.path.join(ASSETS, "{}.webp".format(name))
            result.save(webp_path, "WEBP", quality=90, method=6)
            count += 1
            print("E{:02d} {}x{} -> {}".format(r * COLS + c + 1, result.width, result.height, os.path.basename(webp_path)))
    print("DONE total={}".format(count))


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""把 6x6 白底 emoji 表情图（sheet_emoji.png）转成透明 WebP 内置表情。

徽章行列分布不均匀（有的行更大更满、越出均匀网格），不能按固定网格切：
1. 全图对"非白色像素"做行投影分出 6 行条带；
2. 每条带内做列投影分出 6 枚徽章，再细化每枚的 y 范围；
3. 每枚按包围盒套圆角矩形蒙版（徽章就是圆角方块）转透明，
   导出 WebP 到 assets/emojis/（pubspec 已按目录声明）。
源图与本脚本不参与打包（同 docs/achievement_icons 做法）。
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE, "sheet_emoji.png")
PROJECT = os.path.dirname(os.path.dirname(BASE))
ASSETS = os.path.join(PROJECT, "assets", "emojis")

ROWS, COLS = 6, 6
WHITE_DIST = 40     # 距纯白小于该值视为背景（最浅徽章粉色 ≈49）
ROUND_RATIO = 0.28  # 圆角半径 / 边宽（实测）
MIN_PROJ = 10       # 行/列投影计数阈值，滤掉抗锯齿零星像素

# 按行优先（从左到右、从上到下）命名，避免与 assets/emojis 既有文件重名
NAMES = [
    "tasty",       "tongue_out", "heart_eyes", "wailing",      "cool",        "blushing",
    "sad",         "gritting",   "gaping",     "mad",          "skeptical",   "hysterical",
    "knocked_out", "kissy",      "deadpan",    "winking",      "sleepy",      "star_eyes",
    "glee",        "puzzled",    "flushed",    "contented",    "annoyed",     "bawling",
    "unamused",    "blowing_kiss", "sweating", "sly",          "puke",        "wow",
    "nervous",     "baffled",    "furious",    "drooly",       "puppy_eyes",  "playful",
]


def runs(mask):
    """布尔序列中所有连续 True 段 [(start, end), ...]，按位置排序。"""
    out = []
    start = None
    for i, v in enumerate(list(mask) + [False]):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append((start, i))
            start = None
    return out


def top_spans(mask, n):
    """取最长的 n 个段，再按位置排序。"""
    return sorted(sorted(runs(mask), key=lambda s: s[0] - s[1])[:n])


def to_transparent():
    os.makedirs(ASSETS, exist_ok=True)
    sheet = np.asarray(Image.open(SRC).convert("RGB"))
    colored = np.sqrt(((sheet.astype(np.int32) - 255) ** 2).sum(-1)) > WHITE_DIST

    boxes = []
    for ry0, ry1 in top_spans(list(colored.sum(1) > MIN_PROJ), ROWS):
        band = colored[ry0:ry1]
        for x0, x1 in top_spans(list(band.sum(0) > MIN_PROJ), COLS):
            ys = np.where(band[:, x0:x1].sum(1) > MIN_PROJ)[0]
            boxes.append((x0, ry0 + ys[0], x1, ry0 + ys[-1] + 1))
    assert len(boxes) == len(NAMES), "检测到 {} 枚徽章，应为 {} 枚".format(len(boxes), len(NAMES))

    for (name, (x0, y0, x1, y1)) in zip(NAMES, boxes):
        bw, bh = x1 - x0, y1 - y0
        ss = 4
        m = Image.new("L", (bw * ss, bh * ss), 0)
        ImageDraw.Draw(m).rounded_rectangle(
            [0, 0, bw * ss - 1, bh * ss - 1], radius=int(ROUND_RATIO * min(bw, bh)) * ss, fill=255
        )
        m = m.resize((bw, bh), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.0))
        alpha = np.zeros(sheet.shape[:2], np.uint8)
        alpha[y0:y1, x0:x1] = np.asarray(m)
        cell = np.dstack([sheet, alpha])
        pys, pxs = np.where(alpha > 8)
        pad = 2
        res = Image.fromarray(cell[
            max(0, pys.min() - pad):pys.max() + pad, max(0, pxs.min() - pad):pxs.max() + pad
        ])
        res.save(os.path.join(ASSETS, "{}.webp".format(name)), "WEBP", quality=90, method=6)
        print("{:4d}x{:<4d} -> {}".format(res.width, res.height, name))
    print("DONE total={}".format(len(NAMES)))


if __name__ == "__main__":
    to_transparent()

# -*- coding: utf-8 -*-
"""把 6x5 图标雪碧图（透明底 PNG）拆分为单枚图标并导出到应用资源。

切分原理与 docs/achievement_icons/split_icons.py 一致：
每格从格中心在 alpha>128 区域泛洪取主体（剔除悬浮毛边），按包围盒裁切，
原生 alpha 原样保留。搜索窗口为单元格四周外扩 25%。

用法：python docs/jelly_icons/split_icons.py
源图：docs/jelly_icons/sheet_01.png（6 列 x 5 行，顺序见 NAMES）
输出：assets/jelly_icons/<英文名>.webp（透明，已在 pubspec.yaml 声明）
"""
import os

import numpy as np
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(BASE)), "assets", "jelly_icons")

# 行优先：第 1 行在顶部。名称即导出文件名（ASCII，Flutter 资源路径安全）。
NAMES = [
    "gift", "clapperboard", "spray", "egg", "coin", "banner",
    "star", "chest", "gold", "lightning", "cash", "scroll",
    "diamond", "bomb", "speech_bubble", "hourglass", "trophy", "envelope",
    "stopwatch", "crown", "flashlight", "piggy_bank", "pill", "heart",
    "shield", "potion", "swords", "calendar", "shop", "key",
]

ROWS, COLS = 5, 6


def flood_component(allowed: np.ndarray, cy, cx) -> np.ndarray:
    """布尔数组中包含 (cy, cx) 的四连通分量。"""
    visited = np.zeros_like(allowed)
    if not allowed[cy, cx]:
        found = False
        for r in range(1, 60):
            ys, xs = np.where(allowed[max(0, cy - r):cy + r, max(0, cx - r):cx + r])
            if len(ys):
                cy = max(0, cy - r) + ys[0]
                cx = max(0, cx - r) + xs[0]
                found = True
                break
        if not found:
            return visited
    visited[cy, cx] = True
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
    os.makedirs(OUT, exist_ok=True)
    im = Image.open(os.path.join(BASE, "sheet_01.png")).convert("RGBA")
    arr = np.asarray(im)
    h, w = arr.shape[:2]
    assert len(NAMES) == ROWS * COLS, "NAMES 数量与网格不符"
    for i, name in enumerate(NAMES):
        r, c = divmod(i, COLS)
        x0, x1 = int(w * c / COLS), int(w * (c + 1) / COLS)
        y0, y1 = int(h * r / ROWS), int(h * (r + 1) / ROWS)
        m = min(x1 - x0, y1 - y0) // 4
        wy0, wy1 = max(0, y0 - m), min(h, y1 + m)
        wx0, wx1 = max(0, x0 - m), min(w, x1 + m)
        win = arr[wy0:wy1, wx0:wx1, 3] > 128
        comp = flood_component(win, (wy1 - wy0) // 2, (wx1 - wx0) // 2)
        cell = arr[wy0:wy1, wx0:wx1].copy()
        cell[..., 3] = np.where(comp, cell[..., 3], 0)
        ys, xs = np.where(cell[..., 3] > 8)
        pad = 2
        wh, ww = wy1 - wy0, wx1 - wx0
        result = Image.fromarray(cell[max(0, ys.min() - pad):min(wh, ys.max() + pad),
                                      max(0, xs.min() - pad):min(ww, xs.max() + pad)])
        dst = os.path.join(OUT, name + ".webp")
        result.save(dst, "WEBP", quality=90, method=6)
        print("{} {}x{}".format(name, result.width, result.height))
    print("DONE -> {}".format(OUT))


if __name__ == "__main__":
    main()

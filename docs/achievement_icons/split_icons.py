# -*- coding: utf-8 -*-
"""Split achievement icon sheets (3x3 / 3+3+1 / 2x2 grids) into single
transparent-background PNG icons.

Two input kinds:
- Native-alpha sheets (gpt-image-2.5-sunburst, background=transparent):
  per cell, flood from the cell center over alpha>128 to isolate the badge
  body (loose speckle fringe stays disconnected and is ignored), fit a
  geometric rounded-hexagon mask to that body, output alpha = original
  alpha * hexagon mask. Badge pixels are copied verbatim.
- RGB sheets (old style): flood-fill from borders locates badges (location
  only), same hexagon mask applied."""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "icons")

NAMES = {
    "A01": "千言万语", "A02": "频道缔造者", "A03": "标签管理员", "A04": "单频深耕",
    "A05": "促膝长谈", "A06": "声临其境", "A07": "工具大师", "A08": "点将台", "A09": "预设玩家",
    "A10": "朋友圈原住民", "A11": "赛博知己", "A12": "伙伴收藏家", "A13": "播报员",
    "A14": "笔耕不辍", "A15": "习惯成自然", "A16": "长篇大论",
    "A17": "时间记录者", "A18": "千时如梭", "A19": "标签收藏家",
    "A20": "习惯成瘾", "A21": "技能点满", "A22": "多线操作",
    "A23": "百炼成钢", "A24": "全勤奖", "A25": "建制完成",
    "A26": "效率专家", "A27": "今日事今日毕", "A28": "立志者",
    "A29": "灵感收割机", "A30": "分门别类",
    "A31": "知识之树", "A32": "闭环完成", "A33": "富文本玩家",
    "A34": "人生刻度", "A35": "倒计时开始",
    "A36": "行程满档", "A37": "忙碌一周",
    "A38": "定格瞬间", "A39": "标签相册",
    "A40": "不再遗忘", "A41": "守时主义",
    "A42": "持家有道", "A43": "连续记账", "A44": "多账户玩家",
    "A45": "百物图鉴", "A46": "分仓管理", "A47": "物尽其用",
    "A48": "第一桶金", "A49": "血拼达人", "A50": "兑换图鉴",
    "A51": "高朋满座", "A52": "保持联络", "A53": "社交蝴蝶",
    "A54": "旗开得胜", "A55": "记录点滴",
    "A56": "建库师", "A57": "万条数据", "A58": "全字段控",
    "A59": "开始计时", "A60": "万分钟专注",
    "A61": "播音员", "A62": "三通道玩家",
    "A63": "一触即发", "A64": "标签工程师",
    "A65": "冲浪起点", "A66": "网址收藏夹", "A67": "多线程浏览",
    "A68": "Hello World", "A69": "脚本作者", "A70": "效率革命",
    "A71": "全能启动", "A72": "全方位记录", "A73": "百日筑基", "A74": "深度玩家",
}

SHEETS = {
    "sheet_01.png": ([(r, c) for r in range(3) for c in range(3)], 1),   # A01-A09
    "sheet_02.png": ([(r, c) for r in range(3) for c in range(3)], 10),  # A10-A18
    "sheet_03.png": ([(r, c) for r in range(3) for c in range(3)], 19),
    "sheet_04.png": ([(r, c) for r in range(3) for c in range(3)], 28),
    "sheet_05.png": ([(r, c) for r in range(3) for c in range(3)], 37),
    "sheet_06.png": ([(r, c) for r in range(3) for c in range(3)], 46),
    "sheet_07.png": ([(r, c) for r in range(3) for c in range(3)], 55),
    "sheet_08.png": ([(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (2, 1)], 64),
    "sheet_09.png": ([(0, 0), (0, 1), (1, 0), (1, 1)], 71),
}


def background_locate(im: Image.Image) -> np.ndarray:
    """RGB sheets: mask of non-background area (badge bodies) via border flood."""
    rgb = np.asarray(im.convert("RGB"), dtype=np.int16)
    h, w = rgb.shape[:2]
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.sqrt(((rgb - bg) ** 2).sum(-1))
    m_strict = dist < 30
    m_loose = dist < 80
    bright = rgb.min(-1) > 242
    neutral = (rgb[..., 2] - rgb[..., 0]) < 14
    white_like = bright & neutral
    allowed = m_strict | (m_loose & ~white_like)

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
    return np.where(visited, 0, 255).astype(np.uint8)


def flood_component(allowed: np.ndarray, cy, cx) -> np.ndarray:
    """Connected component containing (cy, cx) in boolean array, 4-connected."""
    visited = np.zeros_like(allowed)
    if not allowed[cy, cx]:
        # nudge to nearest allowed pixel in a small spiral
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


def rounded_hexagon_mask(size_w, size_h, cx, cy, radius, corner_ratio=0.14, ss=4):
    """Pointy-top rounded hexagon mask, supersampled for smooth edges."""
    rc = radius * corner_ratio
    verts = []
    for k in range(6):
        ang = math.radians(90 + 60 * k)
        verts.append((cx + radius * math.cos(ang), cy + radius * math.sin(ang)))
    pts = []
    for k in range(6):
        p = verts[k]
        prv, nxt = verts[(k - 1) % 6], verts[(k + 1) % 6]
        d1 = (prv[0] - p[0], prv[1] - p[1])
        l1 = math.hypot(*d1)
        a = (p[0] + d1[0] / l1 * rc, p[1] + d1[1] / l1 * rc)
        d2 = (nxt[0] - p[0], nxt[1] - p[1])
        l2 = math.hypot(*d2)
        b = (p[0] + d2[0] / l2 * rc, p[1] + d2[1] / l2 * rc)
        for i in range(11):
            t = i / 10.0
            x = (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * p[0] + t ** 2 * b[0]
            y = (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * p[1] + t ** 2 * b[1]
            pts.append((x * ss, y * ss))
    mask = Image.new("L", (size_w * ss, size_h * ss), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    mask = mask.resize((size_w, size_h), Image.LANCZOS)
    return np.asarray(mask.filter(ImageFilter.GaussianBlur(0.5)))


def main():
    os.makedirs(OUT, exist_ok=True)
    count = 0
    for sheet, (cells, start_id) in SHEETS.items():
        path_sheet = os.path.join(BASE, sheet)
        if not os.path.exists(path_sheet):
            print("SKIP {} (not generated yet)".format(sheet))
            continue
        im = Image.open(path_sheet).convert("RGBA")
        arr = np.asarray(im)
        native_alpha = bool(arr[..., 3].min() < 200)
        locate = None if native_alpha else background_locate(im)
        h, w = arr.shape[:2]
        rows = max(r for r, _ in cells) + 1
        cols = max(c for _, c in cells) + 1
        for i, (r, c) in enumerate(cells):
            aid = start_id + i
            name = NAMES["A{:02d}".format(aid)]
            x0, x1 = int(w * c / cols), int(w * (c + 1) / cols)
            y0, y1 = int(h * r / rows), int(h * (r + 1) / rows)
            cw, ch = x1 - x0, y1 - y0
            if native_alpha:
                # search window = cell expanded 25% so badges crossing the grid
                # line are not clipped; neighboring badges stay outside the window
                m = ch // 4
                wy0, wy1 = max(0, y0 - m), min(h, y1 + m)
                wx0, wx1 = max(0, x0 - m), min(w, x1 + m)
                win = arr[wy0:wy1, wx0:wx1, 3] > 128
                comp = flood_component(win, (wy1 - wy0) // 2, (wx1 - wx0) // 2)
                cell = arr[wy0:wy1, wx0:wx1].copy()
                cell[..., 3] = np.where(comp, cell[..., 3], 0)
                ys, xs = np.where(cell[..., 3] > 8)
            else:
                comp = locate[y0:y1, x0:x1] > 128
                ys, xs = np.where(comp)
                bx0, bx1, by0, by1 = xs.min(), xs.max(), ys.min(), ys.max()
                cx, cy = (bx0 + bx1) / 2.0, (by0 + by1) / 2.0
                # pointy-top hexagon: width = sqrt(3)*R, height = 2R; shrink 1.5% so the
                # mask stays inside the white border even with slight AI-drawn skew
                radius = min((by1 - by0) / 2.0, (bx1 - bx0) / math.sqrt(3)) * 0.985
                mask = rounded_hexagon_mask(cw, ch, cx, cy, radius)
                m = np.where(comp, mask, 0)
                ys, xs = np.where(m > 8)
                cell = arr[y0:y1, x0:x1].copy()
                cell[..., 3] = (cell[..., 3].astype(np.uint16) * m.astype(np.uint16) // 255).astype(np.uint8)
            pad = 2
            wh, ww = wy1 - wy0, wx1 - wx0
            cy0, cy1 = max(0, ys.min() - pad), min(wh, ys.max() + pad)
            cx0, cx1 = max(0, xs.min() - pad), min(ww, xs.max() + pad)
            result = Image.fromarray(cell[cy0:cy1, cx0:cx1])
            path = os.path.join(OUT, "A{:02d}_{}.png".format(aid, name))
            result.save(path)
            count += 1
            print("A{:02d} {}x{} native={} -> {}".format(aid, result.width, result.height, native_alpha, os.path.basename(path)))
    print("DONE total={}".format(count))


if __name__ == "__main__":
    main()

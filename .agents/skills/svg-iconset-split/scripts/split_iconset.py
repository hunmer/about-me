#!/usr/bin/env python3
"""拆分设计工具导出的图标集 SVG 为多个独立 SVG。

适用结构（探测失败会报告并退出，勿强行使用）：
  <svg viewBox="0 0 W H">
    <defs>
      <clipPath id=..><rect w=ICW h=ICH/></clipPath>   # 图标裁剪框 = 图标设计尺寸
      <g id=..>...</g> ...                              # 各图标的图形定义
    </defs>
    <g><rect W x H fill=../></g>                        # 全画布背景（会被排除）
    <g transform=scale..>                               # 每图标的顶层实例（叠放/网格）
      <g transform=translate(dx,dy)>                    # 网格残留偏移（拆分时删除）
        <g clip-path=url(#..)> 实际图形（带 SMIL 动画） </g>

用法:
  python split_iconset.py <iconset.svg> <outdir> [--json <lottie.json>] [--prefix loading_]
                          [--name-by color|lottie|index] [--clip] [--pad 0]

默认按内容实际包围盒（椭圆并集 ∪ clip 框）确定 viewBox 并移除 clip 裁剪，
保证图形四周完整不被吞；--clip 则保持原始设计裁剪（viewBox=clip 尺寸）。
有 Lottie JSON（bodymovin）时用其 assets 名称做交叉校验与命名参考。
"""
import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

NS = 'http://www.w3.org/2000/svg'
ns = f'{{{NS}}}'
ET.register_namespace('', NS)
ET.register_namespace('xlink', 'http://www.w3.org/1999/xlink')


def ser(e):
    return ET.tostring(e, encoding='unicode')


def lottie_val(v):
    """Lottie 属性取静态值（关键帧取首帧）。"""
    if isinstance(v, dict) and 'k' in v:
        k = v['k']
        if isinstance(k, list) and k and isinstance(k[0], dict) and 's' in k[0]:
            return k[0]['s']
        return k
    return v


def parse_lottie(path):
    """返回 [{name, colors}]，colors 为该 asset 图层的填充色列表（小写 hex）。"""
    d = json.load(open(path, encoding='utf-8'))
    out = []
    for a in d.get('assets', []):
        colors = []
        for l in a.get('layers', []):
            for g in l.get('shapes', []):
                for it in g.get('it', []):
                    if it.get('ty') in ('fl', 'st'):
                        c = lottie_val(it.get('c'))
                        if isinstance(c, list) and len(c) >= 3:
                            colors.append(''.join(f'{round(x*255):02x}' for x in c[:3]))
        out.append({'name': a.get('nm', a.get('id')), 'colors': colors})
    return out


def ellipse_union(e, m, boxes):
    """累计父链仿射变换，收集所有 ellipse 的变换后包围盒（含非均匀缩放的保守半径）。"""
    tf = e.get('transform')
    if tf:
        mm = re.fullmatch(
            r'matrix\(([-\d.eE]+),([-\d.eE]+),([-\d.eE]+),([-\d.eE]+),([-\d.eE]+),([-\d.eE]+)\)', tf)
        if mm:
            a, b, c, d, ee, ff = map(float, mm.groups())
            m = (m[0]*a + m[2]*b, m[1]*a + m[3]*b, m[0]*c + m[2]*d, m[1]*c + m[3]*d,
                 m[0]*ee + m[2]*ff + m[4], m[1]*ee + m[3]*ff + m[5])
    if e.tag == f'{ns}ellipse':
        cx, cy = float(e.get('cx', 0)), float(e.get('cy', 0))
        r = max(float(e.get('rx')), float(e.get('ry'))) * \
            max(abs(m[0]), abs(m[1]), abs(m[2]), abs(m[3]))
        x = m[0]*cx + m[2]*cy + m[4]
        y = m[1]*cx + m[3]*cy + m[5]
        boxes.append((x-r, y-r, x+r, y+r))
    for c in e:
        ellipse_union(c, m, boxes)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('svg')
    ap.add_argument('outdir')
    ap.add_argument('--json', help='配套 Lottie JSON（可选，用于校验与命名）')
    ap.add_argument('--prefix', default='icon_', help='输出文件名前缀，默认 icon_')
    ap.add_argument('--name-by', choices=['color', 'lottie', 'index'], default='color',
                    help='命名方式：主题色 / Lottie asset 名 / 序号，默认 color')
    ap.add_argument('--clip', action='store_true',
                    help='保留原始 clip 裁剪（viewBox=clip 尺寸），默认输出完整图形')
    ap.add_argument('--pad', type=float, default=0, help='viewBox 四周额外留白')
    args = ap.parse_args()

    tree = ET.parse(args.svg)
    root = tree.getroot()
    vb = (root.get('viewBox') or '').split()
    if len(vb) != 4:
        sys.exit('无法读取 viewBox')

    # 1. defs 中的 clipPath（取第一个含 rect 的，其尺寸 = 图标设计尺寸）
    clip = None
    defs = root.find(f'{ns}defs')
    if defs is not None:
        for cp in defs.findall(f'{ns}clipPath'):
            if cp.find(f'{ns}rect') is not None:
                clip = cp
                break
    if clip is None:
        sys.exit('未在 defs 中找到含 rect 的 clipPath，结构不匹配，请手动分析')
    rw = float(clip.find(f'{ns}rect').get('width'))
    rh = float(clip.find(f'{ns}rect').get('height'))

    # 2. 顶层实例：排除空组与全画布背景矩形组
    W, H = float(vb[2]), float(vb[3])
    insts = []
    for g in root:
        if g.tag != f'{ns}g':
            continue
        kids = list(g)
        if not kids:
            continue
        first = kids[0]
        if first.tag == f'{ns}rect':
            w, h = first.get('width'), first.get('height')
            try:
                if w and h and float(w) >= W * 0.95 and float(h) >= H * 0.95:
                    continue  # 背景
            except ValueError:
                pass
        insts.append(g)
    if not insts:
        sys.exit('未找到图标实例组，结构不匹配，请手动分析')

    lottie = parse_lottie(args.json) if args.json else []

    os.makedirs(args.outdir, exist_ok=True)
    print(f'图标设计尺寸: {rw:g}x{rh:g}，实例数: {len(insts)}，输出目录: {args.outdir}')
    names_used = set()
    for i, inst in enumerate(insts, 1):
        inner = list(inst)[0]
        grid_tf = inner.attrib.pop('transform', None)  # 去掉网格残留偏移

        s = ser(inst)
        fills = re.findall(r'fill="(#[0-9a-fA-F]{6})"', s)
        theme = fills[1].lower().lstrip('#') if len(fills) > 1 else None

        # 命名: Lottie 匹配(主题色出现在某 asset 色列表中) > 主题色 > 序号
        name = None
        if theme and args.name_by == 'lottie':
            for la in lottie:
                if theme in la['colors']:
                    safe = re.sub(r'[^\w-]+', '_', la['name']).strip('_').lower()
                    if safe:
                        name = safe
                        print(f'[{i}] 匹配 Lottie asset: {la["name"]}')
                    break
        if not name and args.name_by == 'color' and theme:
            name = theme
        if not name:
            name = str(i)
        if name in names_used:
            name = f'{i}_{name}'
        names_used.add(name)

        # viewBox: 默认按椭圆并集 ∪ clip 框（完整显示，不吞边）；--clip 用原始裁剪
        if args.clip:
            vb = (0, 0, rw, rh)
        else:
            boxes = [(0, 0, rw, rh)]
            ellipse_union(inner, (1, 0, 0, 1, 0, 0), boxes)
            x0 = min(b[0] for b in boxes) - args.pad
            y0 = min(b[1] for b in boxes) - args.pad
            x1 = max(b[2] for b in boxes) + args.pad
            y1 = max(b[3] for b in boxes) + args.pad
            vb = (x0, y0, x1 - x0, y1 - y0)
            for g in inner.iter(f'{ns}g'):
                g.attrib.pop('clip-path', None)  # 裁剪会吞掉超出部分

        svg = ET.Element(f'{ns}svg', {
            'fill': 'none', 'width': '100%', 'height': '100%',
            'viewBox': ' '.join(f'{v:g}' for v in vb),
            'xmlns:xlink': 'http://www.w3.org/1999/xlink',
        })
        d = ET.SubElement(svg, f'{ns}defs')
        d.append(ET.fromstring(ser(clip)))
        svg.append(ET.fromstring(ser(inner)))

        path = os.path.join(args.outdir, f'{args.prefix}{name}.svg')
        ET.ElementTree(svg).write(path, encoding='unicode', xml_declaration=False)
        print(f'[{i}] {os.path.basename(path)}  主题色: {theme}  去除偏移: {grid_tf}  '
              f'动画数: {s.count("<animate")}')

    print('完成。请用浏览器抽查输出文件：图形应居中、动画应播放。')


if __name__ == '__main__':
    main()

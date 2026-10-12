# -*- coding: utf-8 -*-
"""将生成的封面大图按 4列x2行 拆分并转为竖版 webp。

用法:
    python split_covers.py [sheet.png]

输入默认为同目录 sheet_raw.png，输出到 D:/about-me/assets/agents/。
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops

SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / "sheet_raw.png"
OUT_DIR = Path("D:/about-me/assets/agents")

# 行主序，对应 sample_data.dart 中 8 个默认智能体
NAMES = [
    "agent_assistant",    # 通用助手
    "agent_analyst",      # 数据分析专家
    "agent_writer",       # 创意写作助手
    "agent_coder",        # 编程助手
    "agent_tutor",        # 学习导师
    "agent_health",       # 健康生活顾问
    "agent_travel",       # 旅行规划师
    "agent_psychologist", # 心理支持顾问
]

COLS, ROWS = 4, 2
WHITE_THRESH = 12  # 视为白色留白的容差
INSET = 2          # bbox 后再内缩，去掉白色抗锯齿边


def main():
    img = Image.open(SRC).convert("RGB")
    w, h = img.size
    cw, ch = w // COLS, h // ROWS
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for r in range(ROWS):
        for c in range(COLS):
            cell = img.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            # 与纯白底做差，找卡片实际边界（去掉列间白色留白）
            bg = Image.new("RGB", cell.size, (255, 255, 255))
            diff = ImageChops.difference(cell, bg).convert("L")
            diff = diff.point(lambda p: 255 if p > WHITE_THRESH else 0)
            bbox = diff.getbbox()
            if bbox is None:
                raise SystemExit(f"cell ({r},{c}) 未检测到卡片内容")
            box = (
                bbox[0] + INSET,
                bbox[1] + INSET,
                bbox[2] - INSET,
                bbox[3] - INSET,
            )
            card = cell.crop(box)
            name = NAMES[r * COLS + c]
            out = OUT_DIR / f"{name}.webp"
            card.save(out, "WEBP", quality=82, method=6)
            print(f"{out}  {card.size[0]}x{card.size[1]}  ratio={card.size[0]/card.size[1]:.2f}")


if __name__ == "__main__":
    main()

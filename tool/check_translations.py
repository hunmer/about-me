#!/usr/bin/env python3
"""检查 i18n 完整性。

1. 代码中 'xxx'.tr / 'xxx'.trParams 使用的 key 必须在翻译文件中有定义，
   否则运行时 GetX 会直接显示 key 原文。
2. *_zh.dart 与对应 *_en.dart 的 key 集合必须对称，防止某语言漏翻。
3. --unused 报告定义了但代码中无引用的死 key。

"引用"采用宽松判定：key 的字符串字面量出现在任何非翻译 dart 文件中
（.tr 调用、数组常量、模型默认值均算），因为存在变量 .tr / 拼接 key
（'xxx_${id}'.tr）等动态用法，仅看 .tr 调用点会误报。拼接前缀对应的
key 同样视为在用。

用法:
    python tool/check_translations.py                  # 检查 1/2
    python tool/check_translations.py --unused         # 额外报告死 key 候选
    python tool/check_translations.py --prune          # 干跑：显示将删除的死 key 行
    python tool/check_translations.py --prune --apply  # 实际删除死 key（仅单行定义，跨行值跳过）

退出码: 0 通过, 1 存在问题
"""
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

# 'xxx'.tr / 'xxx'.trParams(...)，xxx 为纯标识符（动态 key 变量无法静态检查，跳过）
usage_re = re.compile(r"""['"]([A-Za-z_][A-Za-z0-9_]*)['"]\s*\.tr(?:Params)?\b""")
# 翻译文件中行首的 'key': 定义
def_re = re.compile(r"""^[ \t]*['"]([A-Za-z_][A-Za-z0-9_]*)['"]\s*:""", re.M)
# 拼接 key：'prefix_${...}'.tr / 'prefix_${...}'.trParams，prefix 视为动态前缀
interp_re = re.compile(r"""['"]([A-Za-z_][A-Za-z0-9_]*)\$\{[^}]+\}['"]\s*\.tr(?:Params)?\b""")
# 任意字符串字面量（宽松引用判定用）
literal_re = re.compile(r"""['"]([A-Za-z_][A-Za-z0-9_]*)['"]""")


def iter_dart_files():
    for dirpath, _dirnames, filenames in os.walk(LIB):
        for name in filenames:
            if name.endswith(".dart"):
                yield os.path.join(dirpath, name)


def rel(path):
    return os.path.relpath(path, ROOT).replace("\\", "/")


def main():
    show_unused = "--unused" in sys.argv
    prune = "--prune" in sys.argv

    defined = set()
    # file_stem(去 _zh/_en) -> {"zh": set, "en": set}
    lang_keys = defaultdict(dict)
    interp_prefixes = set()
    # 非翻译文件全文，用于宽松引用判定
    code_texts = []
    trans_files = []  # [(path, text)]

    for path in iter_dart_files():
        name = os.path.basename(path)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        if "translations" not in name:
            code_texts.append((path, text))
            interp_prefixes.update(interp_re.findall(text))
            continue
        trans_files.append((path, text))
        keys = set(def_re.findall(text))
        defined |= keys
        if name.endswith("_zh.dart"):
            lang_keys[name[: -len("_zh.dart")]]["zh"] = keys
        elif name.endswith("_en.dart"):
            lang_keys[name[: -len("_en.dart")]]["en"] = keys

    usages = defaultdict(list)  # key -> [(file:line), ...]
    referenced = set()
    for path, text in code_texts:
        lines = text.splitlines()
        for i, line in enumerate(lines, 1):
            for m in usage_re.finditer(line):
                usages[m.group(1)].append(f"{rel(path)}:{i}")
        referenced.update(literal_re.findall(text))

    problems = []

    undefined = sorted(k for k in usages if k not in defined)
    if undefined:
        problems.append(f"未定义的翻译 key（运行时会显示 key 原文）: {len(undefined)} 个")
        for key in undefined:
            problems.append(f"  {key}")
            for loc in usages[key]:
                problems.append(f"    - {loc}")

    for stem, langs in sorted(lang_keys.items()):
        zh, en = langs.get("zh"), langs.get("en")
        if zh is None or en is None:
            continue  # 只有单语言的文件（如 unified_translations.dart 本身）跳过
        if zh != en:
            only_zh = sorted(zh - en)
            only_en = sorted(en - zh)
            if only_zh:
                problems.append(f"{stem}_zh 有而 _en 缺失: {', '.join(only_zh)}")
            if only_en:
                problems.append(f"{stem}_en 有而 _zh 缺失: {', '.join(only_en)}")

    # 未使用判定：字面量无引用，且不匹配任何动态拼接前缀（'xxx_${id}'.tr）
    unused = sorted(
        k
        for k in defined
        if k not in referenced and not any(k.startswith(p) for p in interp_prefixes)
    )

    if show_unused and unused:
        problems.append(f"未使用的翻译 key（候选删除）: {len(unused)} 个")
        # 按模块前缀归组输出
        groups = defaultdict(list)
        for key in unused:
            groups[key.split("_")[0]].append(key)
        for prefix in sorted(groups):
            problems.append(f"  [{prefix}] {', '.join(groups[prefix])}")

    if prune:
        unused_set = set(unused)
        apply = "--apply" in sys.argv
        total_removed = 0
        for path, _text in trans_files:
            with open(path, encoding="utf-8") as f:
                lines = f.readlines()
            kept, removed_here, skipping = [], 0, False
            for line in lines:
                if skipping:
                    # 跨行值：删到以 , 结尾的行为止
                    if line.rstrip().endswith(","):
                        skipping = False
                    removed_here += 1
                    continue
                m = re.match(r"""^[ \t]*['"]([A-Za-z_][A-Za-z0-9_]*)['"]\s*:""", line)
                if m and m.group(1) in unused_set:
                    if line.rstrip().endswith(","):
                        removed_here += 1
                        if apply:
                            continue  # 丢弃该行（单行定义）
                    else:
                        # key 行以 : 结尾，值为跨行，删 key 行 + 值行
                        removed_here += 1
                        skipping = True
                        continue
                kept.append(line)
            if removed_here:
                total_removed += removed_here
                if apply:
                    with open(path, "w", encoding="utf-8", newline="") as f:
                        f.writelines(kept)
                print(f"{'已删除' if apply else '将删除'} {removed_here} 行 - {rel(path)}")
        print(f"{'--apply 已执行' if apply else '(干跑,加 --apply 执行)'} 共 {total_removed} 行")
        return

    if problems:
        print("\n".join(problems))
        sys.exit(1)

    print(
        f"i18n 检查通过: {len(usages)} 个使用中的 key 均有定义, "
        f"翻译文件共定义 {len(defined)} 个 key, zh/en 对称"
        + (f", 未使用 {len(unused)} 个" if show_unused else "")
    )
    if show_unused and unused:
        sys.exit(1)  # --unused 模式下存在死 key 视为失败


if __name__ == "__main__":
    main()

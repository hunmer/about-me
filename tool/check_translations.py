#!/usr/bin/env python3
"""检查 i18n 完整性。

1. 代码中 'xxx'.tr / 'xxx'.trParams 使用的 key 必须在翻译文件中有定义，
   否则运行时 GetX 会直接显示 key 原文。
2. *_zh.dart 与对应 *_en.dart 的 key 集合必须对称，防止某语言漏翻。

翻译 key 的来源：lib/ 下所有 *translations*.dart 文件中行首 'key': 形式
（与 unified_translations.dart 聚合的运行时 map 一致）。

用法:
    python tool/check_translations.py

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


def iter_dart_files():
    for dirpath, _dirnames, filenames in os.walk(LIB):
        for name in filenames:
            if name.endswith(".dart"):
                yield os.path.join(dirpath, name)


def rel(path):
    return os.path.relpath(path, ROOT).replace("\\", "/")


def main():
    defined = set()
    # file_stem(去 _zh/_en) -> {"zh": set, "en": set}
    lang_keys = defaultdict(dict)

    for path in iter_dart_files():
        name = os.path.basename(path)
        if "translations" not in name:
            continue
        with open(path, encoding="utf-8") as f:
            text = f.read()
        keys = set(def_re.findall(text))
        defined |= keys

        if name.endswith("_zh.dart"):
            lang_keys[name[: -len("_zh.dart")]]["zh"] = keys
        elif name.endswith("_en.dart"):
            lang_keys[name[: -len("_en.dart")]]["en"] = keys

    usages = defaultdict(list)  # key -> [(file:line), ...]
    for path in iter_dart_files():
        with open(path, encoding="utf-8") as f:
            for i, line in enumerate(f, 1):
                for m in usage_re.finditer(line):
                    usages[m.group(1)].append(f"{rel(path)}:{i}")

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

    if problems:
        print("\n".join(problems))
        sys.exit(1)

    print(
        f"i18n 检查通过: {len(usages)} 个使用中的 key 均有定义, "
        f"翻译文件共定义 {len(defined)} 个 key, zh/en 对称"
    )


if __name__ == "__main__":
    main()

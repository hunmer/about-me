#!/usr/bin/env python3
"""检查 lib/ 下未被引用的 dart 文件（死代码）。

原理：从入口（lib/main.dart + test/ + tool/ + docs/ 脚本）出发，
解析全部 import/export/part（含条件 import 分支），做可达性分析。
lib/ 下不可达的文件即为候选死文件。

用法:
    python3 tool/check_dead_dart.py            # 只报告
    python3 tool/check_dead_dart.py --delete   # 报告并删除

注意：
- packages/、shared_models/ 不在删除范围（独立包，各有自己的入口）。
- 删除前会做 basename 字符串引用扫描作为二次保险，但仍建议
  删除后跑 flutter analyze 复验，并用 git 可随时还原。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SCAN_DIRS = ["lib", "test", "tool", "docs", "scripts"]

# 根入口目录/文件（这些文件本身永远算可达）
ENTRY_DIRS = ["test", "tool", "docs", "scripts"]

pkg_map = {
    "aboutme": os.path.join(ROOT, "lib"),
    "shared_models": os.path.join(ROOT, "shared_models", "lib"),
}

uri_re = re.compile(r"""['"]([^'"]+)['"]""")
stmt_re = re.compile(r"""^[ \t]*(?:import|export|part)\b[^;]*;""", re.M)


def resolve(cur_file, uri):
    if uri.startswith("dart:"):
        return None
    if uri.startswith("package:"):
        pkg, _, path = uri[len("package:"):].partition("/")
        if pkg in pkg_map:
            return os.path.normpath(os.path.join(pkg_map[pkg], path))
        return None
    return os.path.normpath(os.path.join(os.path.dirname(cur_file), uri))


def main():
    delete = "--delete" in sys.argv

    all_files = set()
    for d in SCAN_DIRS + ["shared_models"]:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [x for x in dirnames if x not in (".dart_tool", "build", ".git")]
            for f in filenames:
                if f.endswith(".dart"):
                    all_files.add(os.path.normpath(os.path.join(dirpath, f)))

    deps = {}
    for f in sorted(all_files):
        try:
            content = open(f, encoding="utf-8").read()
        except OSError as e:
            print(f"读取失败 {f}: {e}", file=sys.stderr)
            continue
        targets = set()
        for stmt in stmt_re.findall(content):
            for uri in uri_re.findall(stmt):
                t = resolve(f, uri)
                if t:
                    targets.add(t)
        deps[f] = targets

    roots = [f for f in all_files
             if f == os.path.join(ROOT, "lib", "main.dart")
             or any(f.startswith(os.path.join(ROOT, d) + os.sep) for d in ENTRY_DIRS)]

    reached = set()
    queue = list(roots)
    while queue:
        f = queue.pop()
        if f in reached:
            continue
        reached.add(f)
        queue.extend(d for d in deps.get(f, ()) if d not in reached)

    lib_prefix = os.path.join(ROOT, "lib") + os.sep
    dead = sorted(f for f in all_files
                  if f.startswith(lib_prefix) and f not in reached and os.path.exists(f))

    print(f"扫描 {len(all_files)} 个文件, 入口 {len(roots)} 个, "
          f"lib/ 下不可达: {len(dead)} 个\n")

    # 二次保险：死文件的 basename 是否出现在任何活文件里（字符串/同名类引用）
    word_re = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
    suspicious = []
    if dead:
        dead_set = set(dead)
        live_words = {}
        for p, words in ((p, set(word_re.findall(open(p, encoding="utf-8", errors="ignore").read())))
                         for p in reached if p.endswith(".dart")):
            live_words[p] = words
        for d in dead:
            base = os.path.splitext(os.path.basename(d))[0]
            camel = "".join(w[:1].upper() + w[1:] for w in base.split("_") if w)
            hits = [p for p, words in live_words.items() if base in words or camel in words]
            if hits:
                suspicious.append((d, hits[:3]))

    for f in dead:
        print(os.path.relpath(f, ROOT))

    if suspicious:
        print("\n[!] 以下死文件名在活文件中以标识符出现，删除前请人工确认（多为同名类副本/注释）：")
        for d, hits in suspicious:
            print(f"  {os.path.relpath(d, ROOT)}")
            for h in hits:
                print(f"      <- {os.path.relpath(h, ROOT)}")

    if delete:
        if suspicious:
            print("\n存在待确认项，已中止删除。请先人工排查上述文件（或从列表移除）后重跑。")
            sys.exit(1)
        for f in dead:
            os.remove(f)
        print(f"\n已删除 {len(dead)} 个文件。建议运行 flutter analyze 复验。")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""把 iOS 的 Localizable.strings 批量转成 Android strings.xml。

用法：python3 tools/convert_strings.py
源目录：../EchoesOfTime/Resources/<lang>.lproj/Localizable.strings
输出：app/src/main/res/values*/strings.xml
"""
import os
import re
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(BASE, "..", "EchoesOfTime", "Resources")
OUT = os.path.join(BASE, "app", "src", "main", "res")

LANGS = {
    "en": "values",
    "zh-Hans": "values-zh-rCN",
    "es": "values-es",
    "fr": "values-fr",
    "de": "values-de",
    "it": "values-it",
    "nl": "values-nl",
    "pt-BR": "values-pt-rBR",
    "ja": "values-ja",
    "ko": "values-ko",
}

PAIR = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')


def parse_strings(path):
    pairs = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("/*") or line.startswith("//"):
                continue
            m = PAIR.match(line)
            if m:
                pairs.append((m.group(1), m.group(2)))
    return pairs


def unescape(value):
    # iOS 源里 \\n 表示换行，\\" 表示引号
    value = value.replace('\\"', '"')
    value = value.replace("\\n", "\n")
    value = value.replace("\\t", "\t")
    return value


def to_android(key, value):
    value = unescape(value)
    # %@ -> 位置参数 %1$s, %2$s ...
    counter = [0]

    def repl(_m):
        counter[0] += 1
        return "%%%d$s" % counter[0]

    value = re.sub(r"%@", repl, value)
    # %d 在多参数时同样需要定位
    if counter[0] > 0:
        counter2 = [0]

        def repl_d(_m):
            counter2[0] += 1
            return "%%%d$d" % counter2[0]

        value = re.sub(r"%d", repl_d, value)

    value = value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    value = value.replace("'", "\\'").replace('"', '\\"')
    # 首尾有空白必须加引号，否则会被裁掉
    if value.startswith(" ") or value.endswith(" ") or value.startswith("\n") or value.endswith("\n"):
        value = '"' + value + '"'
    return key, value


def main():
    if not os.path.isdir(SRC):
        sys.exit("找不到源目录: %s" % SRC)
    for lang, resdir in LANGS.items():
        src = os.path.join(SRC, "%s.lproj" % lang, "Localizable.strings")
        if not os.path.exists(src):
            print("跳过（缺失）:", src)
            continue
        pairs = [to_android(k, v) for k, v in parse_strings(src)]
        dest_dir = os.path.join(OUT, resdir)
        os.makedirs(dest_dir, exist_ok=True)
        dest = os.path.join(dest_dir, "strings.xml")
        with open(dest, "w", encoding="utf-8") as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n')
            f.write("<resources>\n")
            if resdir == "values":
                f.write('    <string name="app_name">Echoes of Time</string>\n')
            for k, v in pairs:
                f.write('    <string name="%s">%s</string>\n' % (k, v))
            f.write("</resources>\n")
        print("%-14s %3d 条 -> %s" % (lang, len(pairs), os.path.relpath(dest, BASE)))


if __name__ == "__main__":
    main()

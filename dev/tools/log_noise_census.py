#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
日志噪音普查（第一步：纯机械统计，不用任何模型）

把 mangosd 的 ERROR/WARN 行（含 SD2 的 SCRIPT 行）**归一化成模式**（数字/GUID/坐标/时间戳 → 占位符），
按出现次数排序输出 TSV。用途：找出"我们自己的正常业务日志挂在 ERROR 上"这类噪音，
让 `grep ERROR Server.log` 重新变得可用。

用法:
  python log_noise_census.py <日志目录> [输出目录]
  # 例（先把云端日志拉回本地）：
  #   scp root@HOST:/opt/mangos/logs/{Server.log,DBErrors.log,EventAIErrors.log,SD2Errors1.log} ./cloud_logs/
  #   python log_noise_census.py ./cloud_logs ./out

输出:
  <输出目录>/patterns.tsv  →  count / level / file_top / pattern / sample

进阶：把 patterns.tsv 交给本地小模型初筛分类（见 log_noise_label.py），再人工复核差异。
注意：带中文输出时设 PYTHONIOENCODING=utf-8，否则 GBK 控制台会抛 UnicodeEncodeError。
"""
import os
import re
import sys
from collections import Counter, defaultdict

TS = re.compile(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s*')
# 数字/十六进制/浮点/坐标/引号内容 → 占位符（顺序重要：先长后短）
SUBS = [
    (re.compile(r'0x[0-9a-fA-F]+'), '<HEX>'),
    (re.compile(r'-?\d+\.\d+'), '<F>'),
    (re.compile(r'\b\d{3,}\b'), '<N>'),
    (re.compile(r'\b\d+\b'), '<n>'),
    (re.compile(r"'[^']*'"), "'<S>'"),
]


def norm(line):
    s = line
    for rx, rep in SUBS:
        s = rx.sub(rep, s)
    return s.strip()


def level(line):
    if 'ERROR' in line or 'Error:' in line:
        return 'ERROR'
    if 'WARN' in line or 'Warning' in line:
        return 'WARN'
    if 'SCRIPT' in line or 'Script' in line:
        return 'SCRIPT'
    return 'OTHER'


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    logs = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.abspath('.')
    os.makedirs(out, exist_ok=True)

    pat = Counter()
    sample = {}
    per_file = defaultdict(Counter)
    for fn in sorted(os.listdir(logs)):
        if not fn.endswith('.log') or fn == 'mem_monitor.log':
            continue
        with open(os.path.join(logs, fn), encoding='utf-8', errors='replace') as f:
            for raw in f:
                line = TS.sub('', raw.rstrip('\n'))
                if not line.strip():
                    continue
                lv = level(line)
                if lv == 'OTHER':
                    continue
                p = norm(line)
                pat[(lv, p)] += 1
                per_file[fn][(lv, p)] += 1
                sample.setdefault((lv, p), raw.rstrip('\n')[:400])

    rows = sorted(pat.items(), key=lambda kv: -kv[1])
    tsv = os.path.join(out, 'patterns.tsv')
    with open(tsv, 'w', encoding='utf-8', newline='\n') as f:
        f.write("count\tlevel\tfile_top\tpattern\tsample\n")
        for (lv, p), c in rows:
            files = sorted(per_file.items(), key=lambda kv: -kv[1].get((lv, p), 0))
            top = files[0][0] if files and files[0][1].get((lv, p)) else ''
            f.write("%d\t%s\t%s\t%s\t%s\n" % (c, lv, top, p.replace('\t', ' '), sample[(lv, p)].replace('\t', ' ')))

    print("唯一模式 %d 条，总行数 %d" % (len(rows), sum(pat.values())))
    print("写出 %s" % tsv)
    for (lv, p), c in rows[:25]:
        print("%6d  %-6s %s" % (c, lv, p[:150]))
    return 0


if __name__ == '__main__':
    sys.exit(main())

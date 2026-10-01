#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
日志模式分类（第二步：用**本机** ollama 小模型给 patterns.tsv 初筛分类）

为什么用本机模型：63 条模式这种"体量小但需要语义判断"的活儿，走本地 4B 模型几秒就能初筛完，
不消耗远端额度；但**必须人工复核差异** —— 实测它对"我们自己定义的日志标签"会误判
（例如把 [MMQUOTE] 当成异常、把 [AHTRADE] 当成数据错误）。

前置: ollama 在 http://127.0.0.1:11434 运行，并有可用模型（如 qwen3:4b-instruct-2507-q8_0）
用法: python log_noise_label.py <patterns.tsv> [模型名] [输出 tsv]
  提示：中文 prompt 必须按 UTF-8 字节发送（本脚本已处理），否则 PowerShell/GBK 会把中文变成 ???
"""
import json
import os
import sys
import urllib.request

API = 'http://127.0.0.1:11434/api/generate'

SYS = """你是 WoW 私服（cmangos TBC）的日志审核员。用户给你一批已经归一的日志模式，
每行格式为 `序号<TAB>级别<TAB>模式`。请对每条给出分类，分类只能是下列之一：
噪音-我方调试输出 / 噪音-正常业务记录 / 真问题-数据配置 / 真问题-运行异常 / 需人工判断
判断标准：
- 噪音-我方调试输出：开发者诊断打印（例如 [PFDBG]/[ZCORR] 之类）、加载进度打印；
- 噪音-正常业务记录：正常运行时按周期/按笔数写的业务日志（拍卖成交、每周期汇总等）；
- 真问题-数据配置：DB 数据或配置内容有问题（掉落几率>100%、引用不存在的条目、重复键等）；
- 真问题-运行异常：运行期出现了不该出现的状态（找不到生物、脚本找不到 buddy、组队形创建/删除失败等）；
- 需人工判断：拿不准。
只输出结果，每条一行，格式严格为：序号|分类|不超过20字的理由
不要输出任何其它文字、不要 Markdown。"""


def call(model, prompt):
    body = json.dumps({
        "model": model, "prompt": prompt, "system": SYS, "stream": False,
        "options": {"temperature": 0, "num_predict": 1200}
    }).encode('utf-8')
    req = urllib.request.Request(API, data=body, headers={'Content-Type': 'application/json; charset=utf-8'})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read().decode('utf-8')).get('response', '')


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    inp = sys.argv[1]
    model = sys.argv[2] if len(sys.argv) > 2 else 'qwen3:4b-instruct-2507-q8_0'
    out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(inp)), 'llama_labels.tsv')

    rows = []
    with open(inp, encoding='utf-8') as f:
        f.readline()
        for line in f:
            p = line.rstrip('\n').split('\t')
            if len(p) >= 4:
                rows.append({'count': int(p[0]), 'level': p[1], 'pattern': p[3]})

    results = {}
    B = 8
    for i in range(0, len(rows), B):
        chunk = rows[i:i + B]
        lines = "\n".join("%d\t%s\t%s" % (i + j, r['level'], r['pattern'][:220]) for j, r in enumerate(chunk))
        out_text = call(model, lines)
        got = 0
        for ln in out_text.splitlines():
            ln = ln.strip().strip('`')
            if '|' not in ln:
                continue
            parts = [x.strip() for x in ln.split('|')]
            if len(parts) < 3 or not parts[0].isdigit():
                continue
            idx = int(parts[0])
            if 0 <= idx < len(rows):
                results[idx] = (parts[1], parts[2])
                got += 1
        print("batch %d-%d -> %d 条" % (i, i + len(chunk) - 1, got), flush=True)

    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write("count\tlevel\tllama_label\tllama_reason\tpattern\n")
        for i, r in enumerate(rows):
            lab, rea = results.get(i, ('(未分类)', ''))
            f.write("%d\t%s\t%s\t%s\t%s\n" % (r['count'], r['level'], lab, rea.replace('\t', ' '), r['pattern'][:200]))
    print("写出 %s，共 %d 条，已分类 %d 条" % (out, len(rows), len(results)))
    return 0


if __name__ == '__main__':
    sys.exit(main())

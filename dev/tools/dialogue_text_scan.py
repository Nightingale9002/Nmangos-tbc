#!/usr/bin/env python3
"""Scan ScriptDevAI dialogue arrays for steps that DialogueHelper will now say.

For every `static const DialogueEntry <name>[] = { ... };` array, resolve the first field
(text entry) and the second field (sayer entry) to numbers and report entries that have a
sayer AND a positive text id: those are the steps DoNextDialogueStep feeds to
DoBroadcastText, so every id must exist in `broadcast_text`.

Usage: python dialogue_text_scan.py <scripts_root> [out.tsv]
"""
import json
import os
import re
import sys

IDENT_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:=|,)\s*(-?\d+)\s*,?\s*(?://.*)?$')
ARRAY_START_RE = re.compile(r'\bDialogueEntry\w*\s+(\w+)\s*\[\s*\]\s*=\s*\{?')
NUM_RE = re.compile(r'^-?\d+$')


def collect_constants(root):
    """Map IDENT -> value for every `IDENT = <int>` in the tree (best effort)."""
    consts = {}
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            if not name.endswith(('.h', '.cpp')):
                continue
            path = os.path.join(dirpath, name)
            try:
                with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                    for line in fh:
                        m = IDENT_RE.match(line)
                        if m:
                            consts.setdefault(m.group(1), int(m.group(2)))
            except OSError:
                continue
    return consts


def resolve(token, consts):
    token = token.strip()
    if NUM_RE.match(token):
        return int(token)
    if token in consts:
        return consts[token]
    m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*\+\s*(\d+)$', token)
    if m and m.group(1) in consts:
        return consts[m.group(1)] + int(m.group(2))
    return None


def scan(path, consts, out):
    with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
        lines = fh.readlines()

    in_array = False
    array_name = ''
    for num, line in enumerate(lines, 1):
        if not in_array:
            m = ARRAY_START_RE.search(line)
            if m:
                in_array = True
                array_name = m.group(1)
            continue

        if '};' in line:
            in_array = False
            continue

        m = re.match(r'\s*\{([^}]*)\}', line)
        if not m:
            continue
        fields = m.group(1).split(',')
        if len(fields) < 3:
            continue
        text_id = resolve(fields[0], consts)
        sayer = resolve(fields[1], consts)
        if sayer is None or text_id is None:
            continue
        if sayer != 0 and text_id > 0:
            out.append({'text': text_id, 'sayer': sayer, 'file': os.path.basename(path),
                        'line': num, 'array': array_name})


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    root = sys.argv[1]
    consts = collect_constants(root)
    out = []
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            if name.endswith('.cpp'):
                scan(os.path.join(dirpath, name), consts, out)

    ids = sorted({e['text'] for e in out})
    print(f'dialogue steps that will be said (sayer + positive id): {len(out)} entries, '
          f'{len(ids)} distinct text ids')
    print('text ids: ' + ','.join(str(i) for i in ids))
    if len(sys.argv) > 2:
        with open(sys.argv[2], 'w', encoding='utf-8') as fh:
            json.dump(out, fh, indent=1)
        print('details written to ' + sys.argv[2])
    return 0


if __name__ == '__main__':
    sys.exit(main())

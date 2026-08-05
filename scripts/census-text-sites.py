#!/usr/bin/env python3
"""Read-only census: classify every Text( call site in app source.
Run with an optional path filter: python3 scripts/census-text-sites.py [subdir ...]
"""
import re
import subprocess
import sys
import bisect

ROOT = "TheRecruitingCompass/TheRecruitingCompass"
CALL = re.compile(r'\bText\(')


def find_calls(text):
    """Yield (start_idx, arg_str) for each Text( call, matching balanced parens."""
    for m in CALL.finditer(text):
        i = m.end()
        depth = 1
        j = i
        while j < len(text) and depth > 0:
            if text[j] == '(':
                depth += 1
            elif text[j] == ')':
                depth -= 1
            j += 1
        yield m.start(), text[i:j - 1]


def classify(arg):
    s = arg.strip()
    if s.startswith('verbatim:'):
        return 'verbatim'
    if s.startswith('"'):
        return 'literal'
    if re.match(r'^[A-Za-z_][A-Za-z0-9_.]*\s*,\s*(style|format)\s*:', s):
        return 'date-style'
    if 'Image(' in s[:20]:
        return 'image'
    return 'passthrough'


def main():
    paths = sys.argv[1:] or [ROOT]
    result = subprocess.run(
        ["grep", "-rl", "Text(", *paths, "--include=*.swift"],
        capture_output=True, text=True,
    )
    files = sorted(f for f in result.stdout.splitlines() if f and '_ScreenTemplate' not in f)
    counts = {}
    passthrough_sites = []
    for path in files:
        with open(path, encoding='utf-8') as f:
            text = f.read()
        lines_start = [0]
        for idx, ch in enumerate(text):
            if ch == '\n':
                lines_start.append(idx + 1)

        def line_of(pos):
            return bisect.bisect_right(lines_start, pos)

        for start, arg in find_calls(text):
            bucket = classify(arg)
            counts[bucket] = counts.get(bucket, 0) + 1
            if bucket == 'passthrough':
                already = 'String(localized:' in arg
                passthrough_sites.append((path, line_of(start), arg.strip()[:80], already))
    print("=== Counts ===")
    for k, v in sorted(counts.items()):
        print(f"{k}: {v}")
    print("\n=== Passthrough sites (needing a decision), already-wrapped excluded ===")
    for path, line, arg, already in passthrough_sites:
        if not already:
            print(f"{path}:{line}: Text({arg}")


if __name__ == "__main__":
    main()

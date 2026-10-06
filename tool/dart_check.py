#!/usr/bin/env python3
"""Structural validator for the Flutter/Dart sources.

`flutter analyze` / `dart analyze` cannot run in this sandbox (the Flutter,
Dart and node header download hosts are network-blocked), so this tool is the
best available static gate. It runs a real character-level Dart lexer over the
actual source files and reports:

  * unbalanced (), [], {} outside strings/comments
  * unterminated string / char / comment literals
  * unresolved *local* `import 'package:<pkg>/...'` and relative imports
  * pubspec `assets:` directory entries that do not exist on disk
  * obvious "undefined identifier" risks are NOT detectable here (that needs the
    real analyzer) — this is a syntax/structure + asset/import-parity check only.

Exit code 0 = clean, 1 = problems found.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")


def strip_and_balance(text):
    """Scan Dart source, return (problems, openers)."""
    problems = []
    pairs = {")": "(", "]": "[", "}": "{"}
    openers = {"(": 0, "[": 0, "{": 0}
    stack = []
    i = 0
    n = len(text)
    line = 1

    def err(msg):
        problems.append(f"line {line}: {msg}")

    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        # comments
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            i = n if j == -1 else j
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            depth = 1
            i += 2
            while i < n and depth:
                if text.startswith("/*", i):
                    depth += 1
                    i += 2
                elif text.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    if text[i] == "\n":
                        line += 1
                    i += 1
            if depth:
                err("unterminated /* comment")
            continue
        # strings
        if c in ("'", '"'):
            quote = c
            triple = text.startswith(quote * 3, i)
            q = quote * 3 if triple else quote
            raw = False
            i += len(q)
            while i < n:
                ch = text[i]
                if ch == "\\" and i + 1 < n:
                    i += 2
                    continue
                if ch == "\n":
                    line += 1
                    if not triple:
                        # newline in a non-triple string is illegal
                        err("newline inside single-line string")
                        break
                if text.startswith(q, i):
                    i += len(q)
                    break
                i += 1
            else:
                err(f"unterminated string ({quote})")
            continue
        # delimiters
        if c in "([{":
            stack.append((c, line))
            openers[c] += 1
            i += 1
            continue
        if c in ")]}":
            if not stack:
                err(f"unmatched '{c}'")
            else:
                top, _ = stack.pop()
                if top != pairs[c]:
                    err(f"mismatched '{c}' (open '{top}')")
            i += 1
            continue
        i += 1
    for c, ln in stack:
        problems.append(f"line {ln}: unclosed '{c}'")
    return problems, openers


IMPORT_RE = re.compile(r"""import\s+['"]([^'"]+)['"]""")


def check_imports(path, text, problems):
    pkg = None
    pubspec = os.path.join(ROOT, "pubspec.yaml")
    with open(pubspec, encoding="utf-8") as f:
        m = re.search(r"^name:\s*(\S+)", f.read(), re.M)
        pkg = m.group(1) if m else None
    for imp in IMPORT_RE.findall(text):
        if imp.startswith("package:"):
            rest = imp[len("package:"):]
            pname, _, rel = rest.partition("/")
            if pname != pkg:
                continue  # external package; can't resolve here
            target = os.path.join(LIB, rel)
        elif imp.startswith("dart:"):
            continue
        else:
            target = os.path.normpath(os.path.join(os.path.dirname(path), imp))
        if not os.path.isfile(target):
            problems.append(f"unresolved import: {imp}")


def check_pubspec_assets(problems):
    pubspec = os.path.join(ROOT, "pubspec.yaml")
    with open(pubspec, encoding="utf-8") as f:
        txt = f.read()
    in_assets = False
    for raw in txt.splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if stripped.startswith("assets:"):
            in_assets = True
            continue
        if in_assets:
            if stripped.startswith("- "):
                p = stripped[2:].strip()
                d = os.path.join(ROOT, p)
                if not (os.path.isdir(d) or os.path.isfile(d)):
                    problems.append(f"pubspec asset path missing: {p}")
            elif stripped and not stripped.startswith("#"):
                in_assets = False


def main():
    bad = 0
    for dirpath, _dirs, files in os.walk(LIB):
        for fn in sorted(files):
            if not fn.endswith(".dart"):
                continue
            path = os.path.join(dirpath, fn)
            with open(path, encoding="utf-8") as f:
                text = f.read()
            problems, _ = strip_and_balance(text)
            check_imports(path, text, problems)
            rel = os.path.relpath(path, ROOT)
            if problems:
                bad += 1
                print(f"FAIL {rel}")
                for p in problems:
                    print(f"     {p}")
            else:
                print(f"ok   {rel}")
    asset_problems = []
    check_pubspec_assets(asset_problems)
    for p in asset_problems:
        print("FAIL pubspec:", p)
        bad += 1
    print("\nRESULT:", "CLEAN" if bad == 0 else f"{bad} file(s) with issues")
    sys.exit(0 if bad == 0 else 1)


if __name__ == "__main__":
    main()

from __future__ import annotations
import argparse
import sys
import textwrap
import re
from pathlib import Path
import tempfile
import subprocess
import os
import shutil
from . import __version__

SUBJECT_MAX = 50
BODY_WRAP = 72


def read_input(path: str | None) -> str:
    if path:
        return Path(path).read_text(encoding="utf-8")
    if not sys.stdin.isatty():
        return sys.stdin.read()
    editor = os.environ.get("EDITOR") or shutil.which("nano") or shutil.which("vi") or "vi"
    with tempfile.NamedTemporaryFile(mode="w+", suffix=".commit", delete=False, encoding="utf-8") as tf:
        tmpname = tf.name
        tf.write("# Enter bullet points (leading '-' or '*' optional). Lines starting with '#' are ignored.\n")
        tf.write("# Example:\n")
        tf.write("# - module: short subject line\n")
        tf.flush()
    try:
        subprocess.call([editor, tmpname])
        text = Path(tmpname).read_text(encoding="utf-8")
        return text
    finally:
        try:
            os.unlink(tmpname)
        except OSError:
            pass


def extract_bullets(text: str) -> list[str]:
    lines = text.splitlines()
    bullets: list[str] = []
    for ln in lines:
        ln = ln.rstrip()
        if not ln:
            continue
        if ln.lstrip().startswith("#"):
            continue
        m = re.match(r'^\s*[-*]\s*(.+)$', ln)
        if m:
            bullets.append(m.group(1).strip())
        else:
            bullets.append(ln.strip())
    return bullets


def make_subject(first: str, maxlen: int = SUBJECT_MAX) -> str:
    s = re.sub(r'\s+', ' ', first).strip()
    if len(s) <= maxlen:
        return s
    cut = s[:maxlen]
    if ' ' in cut:
        cut = cut.rsplit(' ', 1)[0]
    return cut + '...'


def make_body(bullets: list[str], skip_first: bool = True, width: int = BODY_WRAP) -> str:
    items = bullets[1:] if skip_first and len(bullets) > 1 else bullets
    if not items:
        return ""
    joined = ' '.join(re.sub(r'\s+', ' ', it).strip() for it in items)
    wrapped = textwrap.fill(joined, width=width)
    return wrapped


def build_commit_message(src_text: str, subject_max: int = SUBJECT_MAX, body_wrap: int = BODY_WRAP) -> str:
    bullets = extract_bullets(src_text)
    if not bullets:
        raise SystemExit("No content found in input.")
    subject = make_subject(bullets[0], maxlen=subject_max)
    body = make_body(bullets, skip_first=True, width=body_wrap)
    if body:
        return subject + "\n\n" + body + "\n"
    return subject + "\n"


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="gitta", description="Make git commit message from bullet list.")
    p.add_argument("-V", "--version", action="version", version=f"gitta {__version__}")
    p.add_argument("-i", "--input", help="Input file (default: stdin or $EDITOR if interactive)", default=None)
    p.add_argument("-o", "--output", help="Output file (default: stdout)", default=None)
    p.add_argument("--subject-max", type=int, default=SUBJECT_MAX, help="Max length for subject")
    p.add_argument("--wrap", type=int, default=BODY_WRAP, help="Wrap width for body")
    return p


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    global SUBJECT_MAX, BODY_WRAP
    SUBJECT_MAX = args.subject_max
    BODY_WRAP = args.wrap

    src = read_input(args.input)
    msg = build_commit_message(src, subject_max=args.subject_max, body_wrap=args.wrap)
    if args.output:
        Path(args.output).write_text(msg, encoding="utf-8")
    else:
        sys.stdout.write(msg)
    return 0

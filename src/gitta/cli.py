import argparse
from . import __version__


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="gitta", description="gitta — placeholder Python CLI")
    p.add_argument("-V", "--version", action="version", version=f"gitta {__version__}")
    sub = p.add_subparsers(dest="cmd")
    hello = sub.add_parser("hello", help="print a friendly greeting")
    hello.add_argument("name", nargs="?", default="world")
    return p


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.cmd == "hello":
        print(f"hello, {args.name}")
        return 0
    parser.print_help()
    return 0


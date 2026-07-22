#!/usr/bin/env python3
"""Backward-compatible entry point for the canonical :mod:`taurido` CLI.

Historically this file contained a second Docker/Tauri implementation. It now
only translates the legacy flag-based interface to the positional taurido
interface so both commands execute the same tested engine.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import List, Optional, Sequence


PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from taurido.cli import main as taurido_main  # noqa: E402


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Dock2Tauri compatibility launcher; delegates to taurido",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument("--image", "-i", default="nginx:alpine", help="Docker image or Dockerfile path")
    parser.add_argument("--host-port", "-p", type=int, default=8088, help="Host port (default: 8088)")
    parser.add_argument("--container-port", "-c", type=int, default=80, help="Container port (default: 80)")
    parser.add_argument("--build", "-b", action="store_true", help="Build release bundles")
    parser.add_argument("--target", help="Rust/Tauri target triple")
    parser.add_argument("--health-url", help="Readiness URL override")
    parser.add_argument("--timeout", type=int, default=30, help="Readiness timeout in seconds")
    parser.add_argument("--cross", action="store_true", help="Attempt installed cross targets")
    parser.add_argument("--project-root", help="Directory containing src-tauri")
    parser.add_argument("--export-dir", "--output-dir", dest="export_dir", help="Bundle export directory")
    parser.add_argument("--app-name", help="Product name in the generated Tauri configuration")
    parser.add_argument("--filename", dest="filename_prefix", help="Prefix copied artifact filenames")
    parser.add_argument("--copy-to", help="Comma-separated additional artifact directories")
    parser.add_argument("--launch", action="store_true", help="Launch the built application")
    parser.add_argument("--list-bundles", action="store_true", help="List generated bundles")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    parser.add_argument("--print-plan", action="store_true", help="Print normalized plan without executing")
    return parser


def build_canonical_argv(argv: Optional[Sequence[str]] = None) -> List[str]:
    args = build_parser().parse_args(argv)
    forwarded = [args.image, str(args.host_port), str(args.container_port)]

    if args.build:
        forwarded.append("--build")
    if args.target:
        forwarded.extend(["--target", args.target])
    if args.health_url:
        forwarded.extend(["--health-url", args.health_url])
    if args.timeout != 30:
        forwarded.extend(["--timeout", str(args.timeout)])
    if args.cross:
        forwarded.append("--cross")
    if args.project_root:
        forwarded.extend(["--project-root", args.project_root])
    if args.export_dir:
        forwarded.extend(["--export-dir", args.export_dir])
    if args.app_name:
        forwarded.extend(["--app-name", args.app_name])
    if args.filename_prefix:
        forwarded.extend(["--filename", args.filename_prefix])
    if args.copy_to:
        forwarded.extend(["--copy-to", args.copy_to])
    if args.launch:
        forwarded.append("--launch")
    if args.list_bundles:
        forwarded.append("--list-bundles")
    if args.debug:
        os.environ["DOCK2TAURI_DEBUG"] = "1"
        forwarded.append("--debug")
    if args.print_plan:
        forwarded.append("--print-plan")

    return forwarded


def main(argv: Optional[Sequence[str]] = None) -> int:
    return int(taurido_main(build_canonical_argv(argv)) or 0)


if __name__ == "__main__":
    raise SystemExit(main())

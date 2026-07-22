"""Canonical command-line interface for every Dock2Tauri launcher."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Optional, Sequence, Tuple

from .core import Runner
from .plan import BuildPlan


def _load_env_file(path: Path) -> None:
    """Load simple KEY=VALUE settings without evaluating shell code."""
    if not path.is_file():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[7:].lstrip()
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("\"'")
        if key.isidentifier():
            os.environ.setdefault(key, value)


def _copy_targets(value: Optional[str]) -> Tuple[str, ...]:
    if not value:
        return ()
    return tuple(item.strip() for item in value.split(",") if item.strip())


def build_parser() -> argparse.ArgumentParser:
    config_root = Path(os.environ.get("TAURIDO_PROJECT_ROOT", Path.cwd()))
    _load_env_file(config_root / ".env")

    parser = argparse.ArgumentParser(
        prog="taurido",
        description="Package a Dockerized web application as a Tauri desktop app",
    )
    parser.add_argument(
        "image_or_dockerfile",
        nargs="?",
        default=os.environ.get("DOCKER_IMAGE", "nginx:alpine"),
        help="Docker image or Dockerfile path (default: nginx:alpine)",
    )
    parser.add_argument("host_port", nargs="?", default="8088", help="Host port (default: 8088)")
    parser.add_argument("container_port", nargs="?", default="80", help="Container port (default: 80)")
    parser.add_argument("--build", "-b", action="store_true", help="Build Tauri release bundles")
    parser.add_argument("--target", help="Target triple for cargo tauri build")
    parser.add_argument("--health-url", dest="health_url", help="Override readiness URL")
    parser.add_argument("--timeout", type=int, default=30, help="Readiness timeout seconds (default: 30)")
    parser.add_argument("--cross", action="store_true", help="Attempt installed cross targets")
    parser.add_argument(
        "--project-root",
        help="Directory containing src-tauri; automatically detected when omitted",
    )
    parser.add_argument(
        "--export-dir",
        "--output-dir",
        dest="export_dir",
        default=os.environ.get("OUTPUT_DIR"),
        help="Bundle export directory (default: project-root/dist)",
    )
    parser.add_argument(
        "--app-name",
        default=os.environ.get("CUSTOM_APP_NAME"),
        help="Product name stored in the generated Tauri configuration",
    )
    parser.add_argument(
        "--filename",
        dest="filename_prefix",
        default=os.environ.get("CUSTOM_FILENAME"),
        help="Prefix copied artifact filenames",
    )
    parser.add_argument(
        "--copy-to",
        default=os.environ.get("ADDITIONAL_OUTPUT_DIRS"),
        help="Comma-separated additional artifact directories",
    )
    parser.add_argument("--launch", action="store_true", help="Launch the built application")
    parser.add_argument("--list-bundles", action="store_true", help="List generated bundle contents")
    parser.add_argument("--debug", action="store_true", help="Enable diagnostic environment output")
    parser.add_argument(
        "--print-plan",
        action="store_true",
        help="Print the normalized JSON execution plan without running Docker or Tauri",
    )
    return parser


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    args = build_parser().parse_args(argv)
    if os.path.isfile(args.image_or_dockerfile) and not args.build:
        args.build = True
        os.environ.setdefault("EXPORT_BUNDLES", "1")
        if not args.print_plan:
            print("\x1b[34mℹ️  Dockerfile input detected; defaulting to build and export bundles.\x1b[0m")
    return args


def create_plan(args: argparse.Namespace) -> BuildPlan:
    return BuildPlan(
        image_or_dockerfile=args.image_or_dockerfile,
        host_port=str(args.host_port),
        container_port=str(args.container_port),
        build=args.build,
        target=args.target,
        health_url=args.health_url,
        timeout=int(args.timeout),
        cross=args.cross,
        project_root=args.project_root,
        export_dir=args.export_dir,
        app_name=args.app_name,
        filename_prefix=args.filename_prefix,
        copy_to=_copy_targets(args.copy_to),
        launch=args.launch,
        list_bundles=args.list_bundles,
        debug=args.debug,
    )


def execute_plan(plan: BuildPlan) -> None:
    if plan.debug:
        os.environ["DOCK2TAURI_DEBUG"] = "1"
    runner = Runner(
        base_dir=Path(plan.project_root) if plan.project_root else None,
        export_dir=Path(plan.export_dir) if plan.export_dir else None,
        launch_after_build=plan.launch,
        list_bundles=plan.list_bundles,
        app_name=plan.app_name,
        filename_prefix=plan.filename_prefix,
        additional_output_dirs=[Path(item) for item in plan.copy_to],
    )
    try:
        if plan.build:
            runner.build_flow(
                image_or_dockerfile=plan.image_or_dockerfile,
                host_port=plan.host_port,
                container_port=plan.container_port,
                target=plan.target or "",
                cross=plan.cross,
                health_url=plan.health_url,
                timeout=plan.timeout,
            )
        else:
            runner.dev_flow(
                image_or_dockerfile=plan.image_or_dockerfile,
                host_port=plan.host_port,
                container_port=plan.container_port,
                health_url=plan.health_url,
                timeout=plan.timeout,
            )
    except KeyboardInterrupt:
        pass
    finally:
        runner.cleanup()


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    plan = create_plan(args)
    if args.print_plan:
        print(json.dumps(plan.to_dict(), sort_keys=True))
        return 0
    execute_plan(plan)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

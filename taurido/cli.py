import argparse
import os
import sys
from pathlib import Path
from .core import Runner


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        prog="taurido",
        description="Tauri + Docker bridge CLI (Python) based on Dock2Tauri launcher",
    )
    parser.add_argument("image_or_dockerfile", help="Docker image to run OR path to Dockerfile")
    parser.add_argument("host_port", nargs="?", default="8088", help="Host port (default: 8088)")
    parser.add_argument("container_port", nargs="?", default="80", help="Container port (default: 80)")
    parser.add_argument("--build", "-b", action="store_true", help="Build Tauri release bundles")
    parser.add_argument("--target", help="Target triple for cargo tauri build")
    parser.add_argument("--health-url", dest="health_url", help="Override readiness URL")
    parser.add_argument("--timeout", type=int, default=30, help="Readiness timeout seconds (default: 30)")
    parser.add_argument("--cross", action="store_true", help="Attempt best-effort cross-target builds")
    parser.add_argument(
        "--project-root",
        dest="project_root",
        help="Path to Dock2Tauri project root (directory containing src-tauri/). Auto-detected if omitted.",
    )
    parser.add_argument(
        "--export-dir",
        dest="export_dir",
        help="Custom directory to export bundles (default: project-root/dist).",
    )
    parser.add_argument(
        "--launch",
        action="store_true",
        help="Launch the application after successful bundle creation.",
    )

    args = parser.parse_args(argv)

    # If input is a Dockerfile path and --build not provided, default to build mode
    if os.path.isfile(args.image_or_dockerfile) and not args.build:
        args.build = True
        os.environ.setdefault("EXPORT_BUNDLES", "1")
        print("\x1b[34mℹ️  Dockerfile input detected; defaulting to build and export bundles.\x1b[0m")

    return args


def main(argv=None):
    args = parse_args(argv)
    runner = Runner(
        base_dir=Path(args.project_root) if args.project_root else None,
        export_dir=Path(args.export_dir) if args.export_dir else None,
        launch_after_build=args.launch
    )
    try:
        if args.build:
            runner.build_flow(
                image_or_dockerfile=args.image_or_dockerfile,
                host_port=str(args.host_port),
                container_port=str(args.container_port),
                target=args.target or "",
                cross=args.cross,
                health_url=args.health_url,
                timeout=int(args.timeout),
            )
        else:
            runner.dev_flow(
                image_or_dockerfile=args.image_or_dockerfile,
                host_port=str(args.host_port),
                container_port=str(args.container_port),
                health_url=args.health_url,
                timeout=int(args.timeout),
            )
    except KeyboardInterrupt:
        pass
    finally:
        runner.cleanup()


if __name__ == "__main__":
    sys.exit(main())

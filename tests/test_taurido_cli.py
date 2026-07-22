import importlib.util
import json
from pathlib import Path
import tempfile

from taurido.cli import create_plan, parse_args
from taurido.core import Runner


def load_legacy_launcher():
    script = Path(__file__).parents[1] / "scripts" / "dock2tauri.py"
    spec = importlib.util.spec_from_file_location("dock2tauri_legacy", script)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_parse_args_defaults_for_dockerfile():
    with tempfile.TemporaryDirectory() as d:
        dockerfile = Path(d) / "Dockerfile"
        dockerfile.write_text("FROM scratch\n")
        args = parse_args([str(dockerfile)])
        assert args.build is True
        assert args.host_port == "8088"
        assert args.container_port == "80"


def test_parse_args_with_all_args():
    with tempfile.TemporaryDirectory() as d:
        dockerfile = Path(d) / "Dockerfile"
        dockerfile.write_text("FROM scratch\n")
        args = parse_args([str(dockerfile), "1234", "5678", "--build", "--target=x86_64-unknown-linux-gnu", "--timeout=42", "--cross"])
        assert args.build is True
        assert args.host_port == "1234"
        assert args.container_port == "5678"
        assert args.target == "x86_64-unknown-linux-gnu"
        assert args.timeout == 42
        assert args.cross is True


def test_project_root_updates_default_export_dir(monkeypatch):
    with tempfile.TemporaryDirectory() as d:
        initial_root = Path(d) / "caller"
        project_root = Path(d) / "dock2tauri"
        initial_root.mkdir()
        (project_root / "src-tauri").mkdir(parents=True)
        monkeypatch.setenv("TAURIDO_PROJECT_ROOT", str(project_root))

        runner = Runner(base_dir=initial_root)
        runner._ensure_project_root("nginx:alpine")

        assert runner.base_dir == project_root
        assert runner.export_dir == project_root / "dist"


def test_project_root_preserves_explicit_export_dir(monkeypatch):
    with tempfile.TemporaryDirectory() as d:
        initial_root = Path(d) / "caller"
        project_root = Path(d) / "dock2tauri"
        export_dir = Path(d) / "artifacts"
        initial_root.mkdir()
        (project_root / "src-tauri").mkdir(parents=True)
        monkeypatch.setenv("TAURIDO_PROJECT_ROOT", str(project_root))

        runner = Runner(base_dir=initial_root, export_dir=export_dir)
        runner._ensure_project_root("nginx:alpine")

        assert runner.base_dir == project_root
        assert runner.export_dir == export_dir


def test_legacy_launcher_maps_defaults_to_canonical_cli():
    launcher = load_legacy_launcher()

    assert launcher.build_canonical_argv([]) == ["nginx:alpine", "8088", "80"]


def test_legacy_launcher_maps_all_supported_options(monkeypatch):
    launcher = load_legacy_launcher()
    monkeypatch.delenv("DOCK2TAURI_DEBUG", raising=False)

    forwarded = launcher.build_canonical_argv(
        [
            "--image",
            "grafana/grafana",
            "--host-port",
            "3001",
            "--container-port",
            "3000",
            "--build",
            "--target",
            "x86_64-unknown-linux-gnu",
            "--health-url",
            "http://localhost:3001/login",
            "--timeout",
            "60",
            "--cross",
            "--project-root",
            "/tmp/project",
            "--export-dir",
            "/tmp/dist",
            "--launch",
            "--list-bundles",
            "--debug",
        ]
    )

    assert forwarded == [
        "grafana/grafana",
        "3001",
        "3000",
        "--build",
        "--target",
        "x86_64-unknown-linux-gnu",
        "--health-url",
        "http://localhost:3001/login",
        "--timeout",
        "60",
        "--cross",
        "--project-root",
        "/tmp/project",
        "--export-dir",
        "/tmp/dist",
        "--launch",
        "--list-bundles",
        "--debug",
    ]
    assert launcher.os.environ["DOCK2TAURI_DEBUG"] == "1"


def test_legacy_launcher_delegates_to_taurido(monkeypatch):
    launcher = load_legacy_launcher()
    calls = []
    monkeypatch.setattr(launcher, "taurido_main", calls.append)

    assert launcher.main(["-i", "nginx:alpine", "-p", "9090", "-c", "8080", "-b"]) == 0
    assert calls == [["nginx:alpine", "9090", "8080", "--build"]]


def test_runner_applies_custom_product_and_artifact_names():
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        runner = Runner(base_dir=root, app_name="Custom App", filename_prefix="custom")
        runner._generate_tauri_config(
            docker_image="example/app:latest",
            host_port="8088",
            build_release=True,
            dockerfile_path=None,
            docker_build_ctx=None,
        )
        assert runner.tauri_config_path is not None
        config = json.loads(runner.tauri_config_path.read_text())

        assert config["productName"] == "Custom App"
        assert config["app"]["windows"][0]["title"] == "Custom App"
        assert runner._artifact_name(Path("example.deb")) == "custom-example.deb"
        runner.filename_prefix = "unsafe/name"
        assert runner._artifact_name(Path("example.deb")) == "unsafe-name-example.deb"
        runner.cleanup()


def test_runner_copies_exports_to_additional_directories():
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        export_dir = root / "dist"
        additional_dir = root / "mirror"
        platform_dir = export_dir / "linux-x64"
        platform_dir.mkdir(parents=True)
        (platform_dir / "app.deb").write_text("package")
        (export_dir / "README.md").write_text("artifacts")
        runner = Runner(
            base_dir=root,
            export_dir=export_dir,
            additional_output_dirs=[additional_dir],
        )

        runner._copy_to_additional_dirs()

        assert (additional_dir / "linux-x64" / "app.deb").read_text() == "package"
        assert (additional_dir / "README.md").read_text() == "artifacts"


def test_runner_rejects_recursive_additional_output():
    with tempfile.TemporaryDirectory() as d:
        export_dir = Path(d) / "dist"
        export_dir.mkdir()
        nested_destination = export_dir / "mirror"
        runner = Runner(export_dir=export_dir, additional_output_dirs=[nested_destination])

        runner._copy_to_additional_dirs()

        assert not nested_destination.exists()


def test_env_file_populates_the_normalized_plan(monkeypatch):
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / ".env").write_text(
            "\n".join(
                [
                    "DOCKER_IMAGE=example/app:latest",
                    "OUTPUT_DIR=./artifacts",
                    "CUSTOM_APP_NAME='Example App'",
                    "CUSTOM_FILENAME=example",
                    "ADDITIONAL_OUTPUT_DIRS=/tmp/one,/tmp/two",
                ]
            )
        )
        monkeypatch.chdir(root)
        for key in (
            "DOCKER_IMAGE",
            "OUTPUT_DIR",
            "CUSTOM_APP_NAME",
            "CUSTOM_FILENAME",
            "ADDITIONAL_OUTPUT_DIRS",
        ):
            monkeypatch.delenv(key, raising=False)

        plan = create_plan(parse_args(["--print-plan"]))

        assert plan.image_or_dockerfile == "example/app:latest"
        assert plan.export_dir == "./artifacts"
        assert plan.app_name == "Example App"
        assert plan.filename_prefix == "example"
        assert plan.copy_to == ("/tmp/one", "/tmp/two")

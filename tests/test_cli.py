from pathlib import Path
import tempfile

from taurido.cli import parse_args


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

"""Contract tests proving every launcher produces the same execution plan."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).parents[1]
COMMON_ARGS = [
    "grafana/grafana",
    "3001",
    "3000",
    "--build",
    "--target=x86_64-unknown-linux-gnu",
    "--health-url=http://localhost:3001/login",
    "--timeout=60",
    "--cross",
    "--output-dir=/tmp/dock2tauri-dist",
    "--app-name=Grafana Desktop",
    "--filename=grafana",
    "--copy-to=/tmp/one,/tmp/two",
    "--print-plan",
]


def run_plan(command):
    env = os.environ.copy()
    env["DOCK2TAURI_PYTHON"] = sys.executable
    env["PYTHONPATH"] = str(ROOT)
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def test_bash_node_and_python_share_one_plan():
    commands = [
        [sys.executable, "-m", "taurido.cli", *COMMON_ARGS],
        ["bash", "scripts/dock2tauri.sh", *COMMON_ARGS],
        ["node", "scripts/dock2tauri.js", *COMMON_ARGS],
    ]

    plans = [run_plan(command) for command in commands]

    assert plans[1:] == plans[:-1]
    assert plans[0]["app_name"] == "Grafana Desktop"
    assert plans[0]["copy_to"] == ["/tmp/one", "/tmp/two"]
    assert plans[0]["filename_prefix"] == "grafana"


def test_legacy_python_flags_produce_the_canonical_plan():
    canonical = run_plan([sys.executable, "-m", "taurido.cli", *COMMON_ARGS])
    legacy = run_plan(
        [
            sys.executable,
            "scripts/dock2tauri.py",
            "--image=grafana/grafana",
            "--host-port=3001",
            "--container-port=3000",
            *COMMON_ARGS[3:],
        ]
    )

    assert legacy == canonical

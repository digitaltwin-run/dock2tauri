#!/usr/bin/env node
"use strict";

// Thin compatibility launcher for the canonical taurido execution engine.
const path = require("path");
const { spawnSync } = require("child_process");

function findPython() {
    const configured = process.env.DOCK2TAURI_PYTHON;
    const candidates = configured ? [configured] : ["python3", "python"];
    for (const candidate of candidates) {
        const probe = spawnSync(candidate, ["--version"], { stdio: "ignore" });
        if (!probe.error && probe.status === 0) return candidate;
    }
    return null;
}

function run(argv = process.argv.slice(2)) {
    const python = findPython();
    if (!python) {
        console.error("Dock2Tauri requires Python 3 to run the canonical taurido engine.");
        return 127;
    }

    const projectRoot = path.resolve(__dirname, "..");
    const currentPythonPath = process.env.PYTHONPATH;
    const pythonPath = currentPythonPath
        ? `${projectRoot}${path.delimiter}${currentPythonPath}`
        : projectRoot;
    const result = spawnSync(python, ["-m", "taurido.cli", ...argv], {
        env: { ...process.env, PYTHONPATH: pythonPath },
        stdio: "inherit",
    });
    if (result.error) {
        console.error(result.error.message);
        return 1;
    }
    return result.status === null ? 1 : result.status;
}

if (require.main === module) {
    process.exitCode = run();
}

module.exports = { findPython, run };

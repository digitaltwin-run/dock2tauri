PYTHON ?= python3
VENV ?= .venv
PIP := $(VENV)/bin/pip
PY := $(VENV)/bin/python
PYTEST := $(VENV)/bin/pytest
RUFF := $(VENV)/bin/ruff
TAURIDO := $(VENV)/bin/taurido

.PHONY: venv install dev-install test lint build clean run-example

venv:
	$(PYTHON) -m venv $(VENV)

install: venv
	$(PIP) install -e .

dev-install: venv
	$(PIP) install -e .[dev]

test: dev-install
	$(PYTEST) -q

lint: dev-install
	$(RUFF) check . || true

build: dev-install
	$(PY) -m build

clean:
	rm -rf $(VENV) build dist *.egg-info

# Run example from the Dock2Tauri repo root
run-example: dev-install
	cd ../dock2tauri && $(TAURIDO) ./examples/pwa-hello/Dockerfile 8088 80

#!/usr/bin/env bash
# Headless Godot test entry point (mirrors .github/workflows/tests.yml).
# Usage: bash Tools/ci/run_tests.sh   (from anywhere; resolves to repo root)
set -euo pipefail
cd "$(dirname "$0")/../.."

if ! command -v godot >/dev/null 2>&1; then
  echo "godot not found on PATH." >&2
  echo "Install Godot 4.3 (https://godotengine.org/download, 'Godot Engine - .NET' NOT required)" >&2
  echo "and re-run: godot --headless --script tests/test_runner.gd" >&2
  exit 2
fi

# Best-effort import so global class_names resolve; harmless when there is no
# project.godot yet (test suites SKIP real-script probes and run inline specs).
godot --headless --import >/dev/null 2>&1 || true

exec godot --headless --script tests/test_runner.gd

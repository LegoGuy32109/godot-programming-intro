#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
zip -r godot-demo.zip .

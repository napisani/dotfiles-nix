#!/usr/bin/env bash
set -e

# Create a venv directory if it doesn't exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
	echo 'Creating global_python_scripts venv directory...'
	mkdir -p "$SCRIPT_DIR/.venv"

	# Create the venv using uv
	uv venv "$SCRIPT_DIR/.venv"

	# Activate the venv
	source "$SCRIPT_DIR/.venv/bin/activate"

	# Install the requirements
	uv sync

	# Deactivate the venv
	deactivate

	echo 'Virtual environment created and set up with uv.'
else
	exit 0
fi

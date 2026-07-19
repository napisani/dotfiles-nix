PYTHON ?= 3.12
UV_CACHE_DIR ?= $(CURDIR)/.uv-cache

.PHONY: test install

test:
	UV_CACHE_DIR="$(UV_CACHE_DIR)" uv run --python $(PYTHON) --with pytest pytest tests -q

install:
	UV_CACHE_DIR="$(UV_CACHE_DIR)" uv tool install --editable .

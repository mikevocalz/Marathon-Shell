#!/bin/sh
# Keep the historical entry point; Python passes paths and parses Qt's JSON.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$here/validate-qml.py" "$@"

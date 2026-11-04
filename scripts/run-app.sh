#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
"$repo_root/scripts/build-app.sh" "$@"
exec /usr/bin/open "$repo_root/build/Ice.app"

#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${1:-debug}"
if [[ $# -gt 1 || ( "$configuration" != debug && "$configuration" != release ) ]]; then
    echo "Usage: $0 [debug|release]" >&2
    exit 2
fi
cd "$repo_root"
xcrun swift build --configuration "$configuration" --product Ice
bin_path="$(xcrun swift build --configuration "$configuration" --show-bin-path)"
exec /usr/bin/python3 "$repo_root/scripts/package-app.py" "$bin_path" "$configuration"

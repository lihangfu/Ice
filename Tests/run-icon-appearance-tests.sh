#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ice-icon-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

xcrun swiftc -module-cache-path "$test_dir/module-cache" \
    "$repo_root/Ice/MenuBar/MenuBarItems/MenuBarIconAppearance.swift" \
    "$repo_root/Tests/MenuBarIconAppearanceTests.swift" \
    -o "$test_dir/icon-tests"
"$test_dir/icon-tests" "$repo_root"

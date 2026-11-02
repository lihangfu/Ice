#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ice-localization-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

plutil -lint "$repo_root/Ice/Resources/en.lproj/Localizable.strings" \
    "$repo_root/Ice/Resources/zh-Hans.lproj/Localizable.strings"
xcrun swiftc -module-cache-path "$test_dir/module-cache" \
    "$repo_root/Ice/Utilities/Defaults.swift" \
    "$repo_root/Ice/Utilities/AppLanguage.swift" \
    "$repo_root/Tests/LocalizationTests.swift" \
    -o "$test_dir/localization-tests"
"$test_dir/localization-tests" "$repo_root" -AppleLocale en_GB

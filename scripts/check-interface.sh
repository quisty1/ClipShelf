#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_DIR"
swift build --product ClipShelf
BINARY_DIR="$(swift build --show-bin-path)"
APP_SOURCES=()
for SOURCE in "$PROJECT_DIR"/Sources/ClipShelf/*.swift; do
    if [[ "$SOURCE" != */main.swift ]]; then APP_SOURCES+=("$SOURCE"); fi
done
# Compile the real app types into a separate check executable, without starting
# its clipboard monitor, login service or global shortcut. Requires a macOS desktop.
swiftc -swift-version 6 -default-isolation MainActor -parse-as-library \
    -target "$(uname -m)-apple-macosx14.0" \
    -I "$BINARY_DIR/Modules" "${APP_SOURCES[@]}" \
    "$PROJECT_DIR/Tests/ClipShelfInterfaceChecks/WindowChecks.swift" \
    "$BINARY_DIR"/ClipShelfCore.build/*.o -o "$BINARY_DIR/ClipShelfInterfaceChecks"
"$BINARY_DIR/ClipShelfInterfaceChecks"

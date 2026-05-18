#!/usr/bin/env bash
# Generates iosApp.xcodeproj from project.yml using XcodeGen.
# Run once after cloning, or whenever project.yml changes.
#
# Prereqs:
#   - xcodegen      brew install xcodegen
#   - Gradle wrapper at repo root (for building SkeletonKit.xcframework)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen not found. Install with: brew install xcodegen" >&2
    exit 1
fi

echo "==> Building SkeletonApp XCFramework (debug)…"
(cd "$REPO_ROOT" && ./gradlew :shared-app:assembleSkeletonAppDebugXCFramework)

FRAMEWORK_PATH="$REPO_ROOT/shared-app/build/XCFrameworks/debug/SkeletonApp.xcframework"
if [ ! -d "$FRAMEWORK_PATH" ]; then
    echo "error: expected XCFramework at $FRAMEWORK_PATH after gradle build" >&2
    exit 1
fi

echo "==> Running xcodegen…"
(cd "$SCRIPT_DIR" && xcodegen generate --spec project.yml)

echo "==> Done. Open with: open '$SCRIPT_DIR/iosApp.xcodeproj'"

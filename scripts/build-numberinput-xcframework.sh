#!/usr/bin/env bash
# Build NumberInputKit.xcframework from the pure-Swift NumberInputKit SPM package.
#
# Pure SPM packages don't produce framework outputs when archived via their auto-generated
# scheme, so we generate a thin Xcode framework project via xcodegen (project.yml lives in
# the package root) and archive that for device + simulator, then merge into an XCFramework.
#
# Output: swift-package/NumberInputKit/build/NumberInputKit.xcframework
#
# Requires: Xcode 16+, xcodegen (brew install xcodegen).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_DIR="$REPO_ROOT/swift-package/NumberInputKit"
BUILD_DIR="$PKG_DIR/build"
SCHEME="NumberInputKit"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "ERROR: xcodegen not found. Install with: brew install xcodegen"
  exit 1
fi

cd "$PKG_DIR"

rm -rf "$BUILD_DIR" "$PKG_DIR/NumberInputKitFramework.xcodeproj"
mkdir -p "$BUILD_DIR"

echo "==> Generating Xcode framework project via xcodegen…"
xcodegen generate

ARCHIVE_DEVICE="$BUILD_DIR/$SCHEME-iphoneos.xcarchive"
ARCHIVE_SIM="$BUILD_DIR/$SCHEME-iphonesimulator.xcarchive"

echo "==> Archiving $SCHEME for iphoneos…"
xcodebuild archive \
  -project NumberInputKitFramework.xcodeproj \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_DEVICE" \
  -configuration Release \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  > "$BUILD_DIR/archive-device.log" 2>&1

echo "==> Archiving $SCHEME for iphonesimulator…"
xcodebuild archive \
  -project NumberInputKitFramework.xcodeproj \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "$ARCHIVE_SIM" \
  -configuration Release \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  > "$BUILD_DIR/archive-sim.log" 2>&1

FRAMEWORK_DEVICE_PATH="$ARCHIVE_DEVICE/Products/Library/Frameworks/$SCHEME.framework"
FRAMEWORK_SIM_PATH="$ARCHIVE_SIM/Products/Library/Frameworks/$SCHEME.framework"

if [[ ! -d "$FRAMEWORK_DEVICE_PATH" || ! -d "$FRAMEWORK_SIM_PATH" ]]; then
  echo "ERROR: Archive did not produce framework outputs."
  echo "  device archive:  $ARCHIVE_DEVICE"
  echo "  sim archive:     $ARCHIVE_SIM"
  echo "  device fw:       $FRAMEWORK_DEVICE_PATH"
  echo "  sim fw:          $FRAMEWORK_SIM_PATH"
  echo "Inspect the archives' Products/ directory to find the actual layout."
  echo "Device archive log: $BUILD_DIR/archive-device.log"
  echo "Sim archive log:    $BUILD_DIR/archive-sim.log"
  exit 1
fi

XCF_OUT="$BUILD_DIR/$SCHEME.xcframework"
rm -rf "$XCF_OUT"

echo "==> Merging into $SCHEME.xcframework…"
xcodebuild -create-xcframework \
  -framework "$FRAMEWORK_DEVICE_PATH" \
  -framework "$FRAMEWORK_SIM_PATH" \
  -output "$XCF_OUT" \
  > "$BUILD_DIR/xcframework.log" 2>&1

# Clean up the generated wrapper project (keep .build for tests).
rm -rf "$PKG_DIR/NumberInputKitFramework.xcodeproj"

echo
echo "✅ Built $XCF_OUT"
ls -la "$XCF_OUT"

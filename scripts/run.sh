#!/usr/bin/env bash
# Build and run the skeleton app on iOS Simulator or Android emulator.
# Usage: ./scripts/run.sh            # interactive
#        ./scripts/run.sh ios        # non-interactive
#        ./scripts/run.sh android

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

IOS_BUNDLE_ID="dev.viethung.skeleton.iosApp"
IOS_SCHEME="iosApp"
IOS_WORKSPACE_OR_PROJECT="iosApp/iosApp.xcodeproj"
ANDROID_APP_ID="dev.viethung.skeleton.android"
ANDROID_LAUNCH_ACTIVITY=".MainActivity"

log()  { printf '\033[1;36m[run]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[run]\033[0m %s\n' "$*" >&2; exit 1; }

choose_platform() {
    if [[ $# -ge 1 && -n "$1" ]]; then
        case "$1" in
            1|ios|iOS|IOS)         echo "ios"; return ;;
            2|android|Android|AND) echo "android"; return ;;
            *) fail "Unknown platform: $1 (use 'ios' or 'android')" ;;
        esac
    fi
    {
        echo
        echo "Select target:"
        echo "  1) iOS Simulator"
        echo "  2) Android Emulator"
    } >&2
    local choice
    read -rp "Enter 1 or 2: " choice >&2
    case "$choice" in
        1|ios|iOS|IOS)         echo "ios" ;;
        2|android|Android|AND) echo "android" ;;
        *) fail "Invalid selection: '$choice'. Type 1 for iOS or 2 for Android." ;;
    esac
}

run_ios() {
    command -v xcodebuild >/dev/null || fail "xcodebuild not found. Install Xcode."
    command -v xcrun      >/dev/null || fail "xcrun not found."

    local udid name
    udid="$(xcrun simctl list devices booted -j \
              | /usr/bin/python3 -c 'import json,sys;d=json.load(sys.stdin)["devices"];print(next((dev["udid"] for runtime in d.values() for dev in runtime if dev.get("state")=="Booted" and "iPhone" in dev.get("name","")), ""))' 2>/dev/null || true)"

    if [[ -z "$udid" ]]; then
        log "No booted simulator. Picking first available iPhone."
        udid="$(xcrun simctl list devices available -j \
                  | /usr/bin/python3 -c 'import json,sys;d=json.load(sys.stdin)["devices"];print(next((dev["udid"] for runtime,devs in d.items() if "iOS" in runtime for dev in devs if "iPhone" in dev.get("name","")), ""))')"
        [[ -n "$udid" ]] || fail "No iPhone simulators available. Open Xcode > Settings > Platforms."
        log "Booting $udid"
        xcrun simctl boot "$udid" || true
    fi
    name="$(xcrun simctl list devices -j | /usr/bin/python3 -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next((dev['name'] for r in d.values() for dev in r if dev['udid']=='$udid'), ''))")"
    log "Using simulator: $name ($udid)"

    open -a Simulator

    log "Building $IOS_SCHEME for simulator..."
    xcodebuild \
        -project "$IOS_WORKSPACE_OR_PROJECT" \
        -scheme "$IOS_SCHEME" \
        -configuration Debug \
        -destination "platform=iOS Simulator,id=$udid" \
        -derivedDataPath "iosApp/build" \
        build | xcpretty 2>/dev/null || xcodebuild \
            -project "$IOS_WORKSPACE_OR_PROJECT" \
            -scheme "$IOS_SCHEME" \
            -configuration Debug \
            -destination "platform=iOS Simulator,id=$udid" \
            -derivedDataPath "iosApp/build" \
            build

    local app_path
    app_path="$(find iosApp/build/Build/Products -name "${IOS_SCHEME}.app" -type d | head -n1)"
    [[ -n "$app_path" ]] || fail "Built .app not found under iosApp/build/Build/Products."

    log "Installing $app_path"
    xcrun simctl install "$udid" "$app_path"
    log "Launching $IOS_BUNDLE_ID"
    xcrun simctl launch "$udid" "$IOS_BUNDLE_ID"
}

run_android() {
    command -v adb     >/dev/null || fail "adb not found. Ensure Android SDK platform-tools is on PATH."
    command -v emulator >/dev/null || log  "emulator binary not on PATH (only needed if no device is running)."

    local serial
    serial="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"

    if [[ -z "$serial" ]]; then
        command -v emulator >/dev/null || fail "No running device and 'emulator' not on PATH. Start one from Android Studio."
        local avd
        avd="$(emulator -list-avds | head -n1)"
        [[ -n "$avd" ]] || fail "No AVDs available. Create one in Android Studio > Device Manager."
        log "Booting AVD: $avd"
        ( emulator -avd "$avd" -netdelay none -netspeed full >/dev/null 2>&1 & )
        log "Waiting for device..."
        adb wait-for-device
        # Wait for boot completion
        until [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
            sleep 2
        done
        serial="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
    fi
    log "Using device: $serial"

    log "Building & installing :androidApp..."
    ./gradlew :androidApp:installDebug

    log "Launching $ANDROID_APP_ID/$ANDROID_LAUNCH_ACTIVITY"
    adb -s "$serial" shell monkey -p "$ANDROID_APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null
}

main() {
    local platform
    platform="$(choose_platform "$@")"
    case "$platform" in
        ios)     run_ios ;;
        android) run_android ;;
        *)       fail "Unknown platform: $platform" ;;
    esac
    log "Done."
}

main "$@"

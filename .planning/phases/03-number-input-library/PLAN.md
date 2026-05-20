# Phase 03 — Number Input → Reusable Library

| Field | Value |
|---|---|
| **Status** | In progress |
| **Driver** | Autonomous agents (no human confirm per /goal) |
| **Created** | 2026-05-20 |
| **Reference** | [`docs/components/NUMBER-INPUT-REUSE.md`](../../../docs/components/NUMBER-INPUT-REUSE.md) |

---

## 1. Goal

Extract the Number Input component from `:shared-components` (KMP) into a **standalone, independently distributable library** for both platforms, so it can be consumed by **any** iOS or Android app without dragging in the rest of the skeleton.

Old code stays alongside until the new library is verified. Migration of in-tree consumers is **out of scope** for this phase.

## 2. Decisions (locked at kickoff)

| Question | Answer |
|---|---|
| Gradle module | `:number-input` |
| Package + Maven coords | `dev.viethung.numberinput`, artifact `dev.viethung:number-input:0.1.0-SNAPSHOT` |
| iOS strategy | **Path B (REUSE doc §3.2)** — pure-Swift port, no Kotlin/Native binary |
| iOS distribution | `NumberInputKit.xcframework` (built from pure-Swift package) **and** SPM source target |
| Swift Package name | `NumberInputKit` (distinct from existing `swift-package/NumberInput`) |
| Android strategy | Pure Android library (AAR), `com.android.library` plugin, no KMP/expect-actual |
| Old code | Left in place (`shared-components/.../numberinput/`, `swift-package/NumberInput/`) |
| Consumer migration | Deferred — this phase only ships the library + tests |

## 3. Source surface to port

| Source (commonMain / iosMain / androidMain) | Lines | New home |
|---|---:|---|
| `NumberInputViewModel.kt` | 144 | Android: `number-input/.../NumberInputViewModel.kt` ; iOS: `NumberInputKit/Sources/.../NumberInputViewModel.swift` |
| `NumberInputUiState.kt` | 41 | Android: same ; iOS: `enum NumberInputUiState` |
| `NumberInputConfig.kt` | 28 | Both platforms |
| `LocaleNumberFormatter.kt` (interface + `liveFormat`) | 65 | Both platforms |
| `LocaleNumberFormatter.android.kt` (java.text.DecimalFormat actual) | 37 | Android `AndroidLocaleNumberFormatter.kt` (no `actual`) |
| `LocaleNumberFormatter.ios.kt` (NSNumberFormatter actual) | 50 | Swift `LocaleNumberFormatter.swift` |
| Swift `NumberInputBridge.swift` (Combine bridge to KMP VM) | 68 | Folded into Swift VM — no bridge needed |
| Swift `NumberInputField.swift` (SwiftUI view) | 132 | Direct port (drop SkeletonKit dep) |
| Swift `NumberInputUITextField.swift` (UIKit) | 109 | Direct port |
| Swift `DesignTokenBridge.swift` (uses DesignTokens) | 53 | Replace with built-in defaults + caller-overridable theme struct |
| **NEW** | — | Android Compose `NumberInputField` composable (no current Android UI) |

## 4. Phases

### P1 — Scaffold (sequential)
- Add `com.android.library` + `org.jetbrains.kotlin.android` plugin aliases to `gradle/libs.versions.toml`.
- Create `:number-input/build.gradle.kts` (Android Library, Compose, lifecycle-viewmodel, vanniktech-publish).
- Register `:number-input` in `settings.gradle.kts`.
- Empty source dirs + placeholder file so `./gradlew :number-input:assembleDebug` builds.
- Create `swift-package/NumberInputKit/Package.swift` (iOS 16+, no binary target).
- Empty Swift target with placeholder type so `swift build` succeeds.

**Gate:** `./gradlew :number-input:assembleDebug` succeeds AND `swift build` in `swift-package/NumberInputKit/` succeeds.

### P2 — Parallel ports
Two agents in parallel:

**P2-Android (Agent A):**
- Port VM/state/config/formatter interface/Android formatter/liveFormat. NO `expect/actual`.
- Build Compose `NumberInputField` composable: `OutlinedTextField` + trailing icon buttons for Clear and ± (sign toggle); driven by VM `StateFlow`.
- JVM unit tests (kotlin.test + Turbine + kotlinx-coroutines-test): mirror the 22 tests from the current `NumberInputViewModelTest`.
- Compose instrumented UI tests: live grouping en-US, vi-VN, decimal preservation, clear/sign button enabled states.

**P2-iOS (Agent B):**
- Port VM as an `ObservableObject` with `@Published` state (sealed enum), state machine semantics identical to Kotlin.
- Port `LocaleNumberFormatter` protocol + iOS implementation backed by `NumberFormatter`.
- Port `liveFormat` helper (Swift function).
- Port SwiftUI `NumberInputField` + UIKit `NumberInputUITextField` + Toolbar. **Drop SkeletonKit/SkeletonKit import**.
- Replace DesignTokenBridge: provide a `NumberInputTheme` struct with sensible defaults; expose a `numberInputTheme(_:)` modifier so callers can override.
- XCTests for VM state machine + grouping for en-US/vi-VN/de-DE.

**Gate:** Each agent's tests pass.

### P3 — XCFramework + Publish
- `scripts/build-numberinput-xcframework.sh`: `xcodebuild archive` for iOS device + simulator, then `xcodebuild -create-xcframework`. Output: `swift-package/NumberInputKit/build/NumberInputKit.xcframework`.
- `:number-input` `mavenPublishing { coordinates(... "0.1.0-SNAPSHOT") }`.
- Verify `./gradlew :number-input:publishToMavenLocal` succeeds.

**Gate:** XCFramework directory exists with expected layout + `~/.m2/repository/dev/viethung/number-input/0.1.0-SNAPSHOT/` contains the AAR + POM.

### P4 — Verification gate
Parallel runs:
- `./gradlew :number-input:testDebugUnitTest`
- `./gradlew :number-input:connectedDebugAndroidTest` (or skip with note if no emulator running)
- `xcodebuild test -scheme NumberInputKit -destination 'platform=iOS Simulator,name=iPhone 15'`
- `./gradlew :shared-components:allTests` (sanity — old code still works)

All must pass.

### P5 — Commit
Single commit on `develop`. PR opening is **opt-in** (user must ask).

## 5. Risk + mitigation

| Risk | Mitigation |
|---|---|
| Swift VM divergence from Kotlin VM | Port test cases 1:1 from `NumberInputViewModelTest.kt` into Swift; both platforms must pass the same scenarios |
| Compose UI test needs a running emulator | Document the gap and run JVM unit tests only; UI test command stays in the build but is `--continue`-tolerant |
| Vanniktech publish needs signing for `publish` (not just `publishToMavenLocal`) | We only verify `publishToMavenLocal` in this phase |
| Pure-Swift XCFramework requires the right `xcodebuild` invocation | Test on a single device + simulator slice first; widen later |
| Naming collision with old `NumberInput` Swift Package | New name `NumberInputKit` (everywhere — module, target, framework, files) |

## 6. Out of scope (explicitly)

- Migrating in-tree consumers (`shared-app`, `iosApp` showcase) to the new library.
- Publishing to Maven Central / CocoaPods / SPM remote.
- Removing the old Number Input code from `:shared-components`.
- Adding the new library to `:androidApp` build graph.
- Hooking the new library into the existing `SkeletonKit.xcframework`.

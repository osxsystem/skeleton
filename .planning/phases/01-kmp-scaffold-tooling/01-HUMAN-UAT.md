---
status: partial
phase: 01-kmp-scaffold-tooling
source: [01-08-PLAN.md, 01-08-SUMMARY.md, 01-11-PLAN.md, 01-12-PLAN.md, 01-13-PLAN.md, 01-15-PLAN.md]
started: 2026-05-09T00:00:00Z
updated: 2026-05-09T20:00:00Z
---

## Current Test

[awaiting human testing on Mac + Xcode 16]
[BI-A/B/C/D/E closed by 01-15; new BI-F (AGP 9 KMP DSL migration) blocks Android smoke and Tests 1–7]

## Post Gap-Closure Status (Plans 01-11..01-13)

Wave 1 gap-closure source has been applied to develop. Each fix is reviewed and consistent at the source level:

| Fix | Gap | What Changed |
|-----|-----|-------------|
| CR-01 | GreetingRepository never bound | `GreetingRepositoryImpl.kt` created (SQLDelight-backed); `factory<GreetingRepository> { GreetingRepositoryImpl(get()) }` added to `appModule` |
| CR-02 | iOS DatabaseDriverFactory unbound | `iosPlatformModule` created in `shared-app/iosMain`; `initKoin(vararg platformModules: Module)` accepts platform modules; `AppKoinBridge.swift` passes `iosPlatformModule` |
| CR-05 | GreetingViewModelFactory bypassed ViewModelStore | Factory now resolves `GetGreetingUseCase` from Koin and constructs `GreetingViewModel(useCase)` directly so `ViewModelStore` owns the instance |
| WR-01 | kotlinx-datetime prohibited dependency | Removed from `shared-core/build.gradle.kts` and `gradle/libs.versions.toml` |
| WR-05 | CI SKIE gate exited 0 on missing headers | `ci.yml` SKIE header gate and XCFramework path check now `exit 1` with ERROR |

Source commits (on `develop`): `d99e084`, `ac107bd`, `8de2a24`, `49f3671`, `4b05e5f` (01-11/12), `14f3e9d`, `946fde8`, `179da63` (01-13).

## Pre-Flight Build-Infra Gate

- [x] **A. `gradlew` script is missing.** CLOSED by 01-15 — generated via `gradle wrapper` from a Gradle 9.5.0 distribution against an empty temp project (the live project's plugins block tripped AGP 9 conflicts during wrapper task evaluation).
- [x] **B. `gradle/wrapper/gradle-wrapper.jar` is missing.** CLOSED by 01-15 — same source as BI-A.
- [x] **C. `build.gradle.kts:3` plugin spec.** CLOSED by 01-15 — replaced `kotlin("jvm") apply false` with `alias(libs.plugins.kotlin.jvm) apply false`; added `kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }` to `gradle/libs.versions.toml [plugins]`.

### Discovered & closed during 01-15 (out of original scope, user-authorized inline fixes)

- [x] **D. KSP version `2.3.21-2.0.4` does not exist upstream.** CLOSED by 01-15 — bumped to `ksp = "2.3.7"` (Maven Central latest for the 2.3.x line; KSP2 dropped the `<kotlin>-<ksp>` legacy naming). CLAUDE.md tech stack table needs a follow-up doc fix.
- [x] **E. AGP 9 + `kotlin.multiplatform` + `com.android.application` extension conflict.** CLOSED by 01-15 — added `android.builtInKotlin=false` and `android.newDsl=false` to `gradle.properties` as the upstream-recommended temporary bypass. Long-term fix per AGP 9 guidance: either remove `kotlin.multiplatform` from `androidApp` (let built-in Kotlin handle Android-side compilation) or restructure androidApp to use `com.android.kotlin.multiplatform.library`. Tracked for follow-up.

### Discovered during 01-15, NOT closed — current blocker

- [ ] **F. KMP modules use pre-AGP-9 `android {}` DSL (BLOCKING).** With BI-E flags applied, configuration progresses past the extension conflict but fails compiling `shared-app/build.gradle.kts:39-49` — the top-level `android { namespace = …; defaultConfig { … }; compileOptions { … } }` block is not on `KotlinMultiplatformExtension` in AGP 9. The new shape is:
  ```kotlin
  kotlin {
      androidLibrary {       // or `android { … }` as a method on KotlinMultiplatformExtension
          namespace = "…"
          compileSdk = 36
          minSdk = 23
          // sourceCompatibility/targetCompatibility moved
      }
  }
  ```
  Affected files (at minimum): `shared-app/build.gradle.kts`, `shared-core/build.gradle.kts`, `shared-components/build.gradle.kts`. Source-set layout v2 also flagged (`androidApp/src/androidMain/kotlin` migration). Recommend a focused 01-16 plan: AGP 9 KMP DSL migration with proper threat model.

**Current state:** A/B/C/D/E closed. F open. Android smoke (`./gradlew :androidApp:assembleDebug`) cannot run until F is fixed. iOS Tests 1–7 remain blocked.

## Tests

### 1. Build the SkeletonKit XCFramework
expected: `./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework` succeeds; the framework appears at `shared-components/build/XCFrameworks/release/SkeletonKit.xcframework`.
result: pending

### 2. Create the iosApp Xcode project
expected: Xcode → File → New → Project → iOS App (SwiftUI). Product Name `iosApp`, Bundle ID `dev.viethung.skeleton.ios`. Saved into `iosApp/` so `iosApp/iosApp.xcodeproj` exists. Minimum deployment target = iOS 17.0.
result: pending

### 3. Wire committed Swift sources into the project
expected: Drag `iosApp/iosApp/Common/IosViewModelStoreOwner.swift`, `iosApp/iosApp/App/AppKoinBridge.swift`, `iosApp/iosApp/Greeting/GreetingScreen.swift` into the project navigator. Replace Xcode-generated `iosApp.swift` and `ContentView.swift` with the committed versions.
result: pending

### 4. Embed SkeletonKit framework
expected: Targets → iosApp → General → Frameworks, Libraries, and Embedded Content → + → add `SkeletonKit.xcframework` → set to Embed & Sign.
result: pending

### 5. Add `-lsqlite3` linker flag
expected: Build Settings → Other Linker Flags → add `-lsqlite3`.
result: pending

### 6. Compile and run on iOS 17 simulator
expected: ⌘B compiles green. Run on iPhone 15 / iOS 17 simulator. "Hello, KMP" (or whatever the Greeting use-case returns) renders on screen.
result: pending

### 7. Verify @StateObject deinit lifecycle
expected: Push a second view (`NavigationLink` to a trivial `Text("ok")` view), then pop back. Xcode console must show `[IosViewModelStoreOwner] deinit cleared store`. This proves D-12 / Pitfall 1+2 / SCAF-05 are working at runtime.
result: pending

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps

```yaml
- truth: "`./gradlew` script exists at repo root and is executable"
  status: closed
  closed_by: 01-15 (commit 7e20b82)
  defect_id: BI-A

- truth: "`gradle/wrapper/gradle-wrapper.jar` exists in the repo so `./gradlew` can bootstrap"
  status: closed
  closed_by: 01-15 (commit 7e20b82)
  defect_id: BI-B

- truth: "Root `build.gradle.kts` plugins block compiles — every plugin spec carries a version or comes from a versioned source"
  status: closed
  closed_by: 01-15 (commit dcee746)
  defect_id: BI-C

- truth: "KSP plugin version pinned in libs.versions.toml exists upstream"
  status: closed
  closed_by: 01-15 (commit d4859b5) — ksp bumped from 2.3.21-2.0.4 (legacy KSP1 naming, never published) to 2.3.7
  defect_id: BI-D
  follow_up: "CLAUDE.md tech stack table still lists KSP 2.3.21-2.0.4; update to 2.3.7 in a doc-only plan."

- truth: "AGP 9 + `kotlin.multiplatform` + `com.android.application` configure without extension conflict"
  status: closed
  closed_by: 01-15 (commit fad8968) — added android.builtInKotlin=false + android.newDsl=false as temporary bypass
  defect_id: BI-E
  follow_up: "Long-term: either remove kotlin.multiplatform from androidApp or restructure to com.android.kotlin.multiplatform.library. See https://kotl.in/gradle/agp-new-kmp"

- truth: "shared-* KMP build.gradle.kts files configure successfully under AGP 9"
  status: failed
  reason: "shared-app/build.gradle.kts:39-49 uses pre-AGP-9 `android { namespace; defaultConfig; compileOptions }` DSL. With BI-E flags applied, KotlinMultiplatformExtension no longer accepts the old shape. Compilation fails: 'Unresolved reference: defaultConfig / compileOptions / sourceCompatibility / targetCompatibility'. shared-core and shared-components likely have the same issue."
  severity: blocker
  test: 1
  artifacts: ["shared-app/build.gradle.kts", "shared-core/build.gradle.kts", "shared-components/build.gradle.kts", "androidApp/src/androidMain/kotlin (source set v2 also warned)"]
  missing: []
  defect_id: BI-F
  blocks: [1, 2, 3, 4, 5, 6, 7]
  recommendation: "Open a focused 01-16 plan: AGP 9 KMP DSL migration with proper threat model — migrate android {} blocks to androidLibrary {} on KotlinMultiplatformExtension, address source-set v2 layout, then re-run Android smoke and proceed to Tests 1–7."
```

---
phase: 02-design-token-bridge
plan: "03"
subsystem: ios-theme
tags: [iosApp, swiftui, theme, environment-key, pitfall-6, pitfall-7, d-17, xcodegen, phase-1-gap-fix]

requires: ["02-01"]
provides:
  - iosApp/iosApp/Theme/AppTheme.swift — SwiftUI environment adapter with Color(argb: Int64) + struct AppTheme + EnvironmentKey
  - iosApp/iosApp/iosApp.swift — @State themeOverride hoist + .preferredColorScheme + .environment(\.appTheme, ...) at WindowGroup root
  - iosApp/iosApp/ContentView.swift — @Binding<ColorScheme?> pass-through
  - iosApp/iosApp/Greeting/GreetingScreen.swift — theme.colors.error consumption + three-state cycle button (D-17)
  - iosApp/iosAppTests/AppThemeTests.swift — 3 alpha-preservation XCTests (Pitfall 6 guard, indigo + opaque white + opaque black)
  - iosApp/project.yml + iosApp/generate-xcodeproj.sh — reproducible Xcode project bootstrap via XcodeGen
  - iosApp/iosApp.xcodeproj — generated project file (registered with iosApp + iosAppTests targets)
affects: [02-04 manual D-17 toggle smoke on iOS]

tech-stack:
  added:
    - "XcodeGen 2.45.3 (host tool, reproducible Xcode project generation from project.yml)"
  patterns:
    - "Color(argb: Int64) byte-extraction — Int64 parameter required to avoid sign-bit corruption (Pitfall 6 / D-08)"
    - "AppTheme.build(isDark:) selects DesignTokens.LightColors.shared or DarkColors.shared — Swift owns palette selection (D-16 / Pitfall 7)"
    - "Single AppThemeKey EnvironmentKey + EnvironmentValues extension; theme injected once at WindowGroup root"
    - "Three-state @Binding<ColorScheme?> cycle nil → .light → .dark → nil — UX parity with Android (D-17)"
    - "XcodeGen-driven project.yml is the source of truth; iosApp.xcodeproj is regenerated, not hand-edited"

key-files:
  created:
    - iosApp/iosApp/Theme/AppTheme.swift
    - iosApp/iosAppTests/AppThemeTests.swift
    - iosApp/project.yml
    - iosApp/generate-xcodeproj.sh
    - iosApp/iosApp.xcodeproj/  (generated)
    - iosApp/iosApp/Info.plist  (generated)
    - shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelHelper.kt
  modified:
    - iosApp/iosApp/iosApp.swift
    - iosApp/iosApp/ContentView.swift
    - iosApp/iosApp/Greeting/GreetingScreen.swift
    - iosApp/iosApp/Common/IosViewModelStoreOwner.swift
    - iosApp/iosApp/App/AppKoinBridge.swift
    - shared-components/build.gradle.kts
    - shared-app/build.gradle.kts

key-decisions:
  - "Adopted XcodeGen to generate iosApp.xcodeproj from project.yml. No .xcodeproj existed at the start of this plan (Phase 1 left iOS UAT deferred per commit c49b277); the project file must be regeneratable in CI and not stored as a hand-edited blob. project.yml + generate-xcodeproj.sh is the source of truth."
  - "Switched iOS umbrella from SkeletonKit (shared-components) to SkeletonApp (shared-app) — SkeletonApp re-exports shared-core and shared-components so a single import gives Swift access to DesignTokens + ColorPalette + GreetingViewModel + ViewModelProvider*. This closes the Phase 1 gap where GreetingViewModel (in :shared-app) was invisible to Swift."
  - "Added `-lsqlite3` to shared-components umbrella framework linkerOpts (mirrors shared-core) — Pitfall 19 fix that was missing in Phase 1."
  - "Replaced SKIE-only call sites with vanilla K/N patterns: `onEnum(of:)` → `if let` against subclass types; `for await s in vm.state` → `subscribeGreetingState` returning a Job; varargs `[mod]` → explicit `KotlinArray<Koin_coreModule>(size: 1)`. SKIE remains disabled per Kotlin 2.3.21 incompatibility note in shared-components/build.gradle.kts."
  - "Dropped generic `IosViewModelStoreOwner.viewModel<VM>(factory:)` — non-SKIE Swift can't construct a `KotlinKClass`. Replaced with per-VM Kotlin helper `createGreetingViewModel(store:)` in :shared-app. Future ViewModels follow the same pattern."
  - "EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64 because the shared framework only ships arm64 simulator slices (matches the iosSimulatorArm64-only Kotlin target from D-01 Phase 1)."

patterns-established:
  - "XcodeGen project.yml + generate-xcodeproj.sh as the bootstrap pattern — iOS project is reproducible from source"
  - "Per-ViewModel Kotlin helper pattern (`createXxxViewModel(store:)`) substitutes for SKIE's KClass<VM> bridge"
  - "Per-ViewModel Flow subscription pattern (`subscribeXxxState(vm:onState:) → Job`) substitutes for SKIE's AsyncSequence bridge; the Job is held in @State and cancelled on .onDisappear"
  - "shared-app emits the iOS umbrella XCFramework (SkeletonApp). shared-components keeps SkeletonKit for product-only builds that strip the showcase."

requirements-completed: [THEME-04, THEME-05]

duration: 50min
completed: 2026-05-18
---

# Phase 2 Plan 03: iOS SwiftUI Adapter

**Wave 2B — DesignTokens → SwiftUI EnvironmentKey adapter with D-17 in-app theme toggle. Also closes the Phase 1 iOS build gap: introduces SkeletonApp XCFramework that re-exports the showcase ViewModel, bootstraps Xcode project generation via XcodeGen, and replaces SKIE-only call sites with vanilla K/N patterns.**

## Accomplishments
- Created `AppTheme.swift` with `Color(argb: Int64)` extension (Pitfall 6 / D-08 — Int64 prevents sign-bit corruption), `ThemeColors`/`ThemeTypography`/`ThemeSpacing`/`ThemeRadius` sub-structs, `struct AppTheme` root, `AppTheme.build(isDark:)` palette builder, `AppThemeKey: EnvironmentKey`, and `EnvironmentValues.appTheme` extension.
- Updated `iosApp.swift` to hoist `@State themeOverride: ColorScheme?`, read `@Environment(\.colorScheme)`, inject `.environment(\.appTheme, AppTheme.build(isDark: effective == .dark))` and `.preferredColorScheme(themeOverride)` at the WindowGroup root.
- Updated `ContentView.swift` to accept and forward `@Binding<ColorScheme?>` to GreetingScreen.
- Rewrote `GreetingScreen.swift` to consume `theme.colors.error` (replacing hardcoded `.red`), accept the binding, render a three-state cycle button (`nil → .light → .dark → nil`), and use vanilla K/N for state subscription (no `onEnum(of:)`).
- Created `AppThemeTests.swift` with 3 alpha-preservation XCTests (FFOpaqueLong = LightColors.primary indigo; opaque white = 0xFFFFFFFF; opaque black = 0xFF000000). All pass.
- Generated `iosApp.xcodeproj` via `xcodegen` from `project.yml`; both `iosApp` and `iosAppTests` targets, scheme wiring, and XCFramework dependency declared declaratively.
- Closed the Phase 1 iOS build gap (4 sub-fixes — see Deviations below).

## Verification
- `xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED**
- `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17'` → **3/3 AppThemeTests pass** (0 failures)
- `grep -c 'Int64' iosApp/iosApp/Theme/AppTheme.swift` → 9 (well above the plan's `>= 2` floor)
- `grep -c 'Int32' iosApp/iosApp/Theme/AppTheme.swift` → 1 (only the `fontWeight(from weight: Int32)` helper)
- `grep -cE '\.foregroundColor\(\.red\)|\.foregroundStyle\(\.red\)' iosApp/iosApp/Greeting/GreetingScreen.swift` → 0 (hardcoded .red removed; D-13)
- `grep -c 'themeOverride' iosApp/iosApp/iosApp.swift` → 3 (@State + ContentView binding + .preferredColorScheme)
- `grep -c '.preferredColorScheme' iosApp/iosApp/iosApp.swift` → 1 (D-17 override mechanism)
- `grep -c 'theme.colors.error' iosApp/iosApp/Greeting/GreetingScreen.swift` → 1
- `grep -c 'surfaceTint' iosApp/iosApp/Theme/AppTheme.swift` → 2 (struct field + Color(argb:) assignment)
- AppTheme.swift and AppThemeTests.swift both registered in `iosApp/iosApp.xcodeproj/project.pbxproj` via xcodegen
- Manual D-17 cycle smoke: **approved by user** (10× cycles, palette flips per tap, no restart, label cycles correctly)

## Deviations from Plan

The plan assumed the iOS app would build cleanly on top of Phase 1's shared modules. It did not — Phase 1 closed PARTIAL with iOS UAT deferred (commit c49b277), and four pre-existing gaps surfaced when `xcodebuild` first ran. Closing them was necessary to verify Wave 2B; the fixes belong on record:

1. **No iosApp.xcodeproj existed.** Adopted XcodeGen 2.45.3 and authored `project.yml` + `generate-xcodeproj.sh`. The script also runs `./gradlew :shared-app:assembleSkeletonAppDebugXCFramework` so the framework dependency exists before `xcodegen generate`. Replaces the plan's "edit pbxproj directly" task — the project file is now generated, not hand-edited.

2. **Umbrella framework didn't include the showcase ViewModel.** `GreetingViewModel` (in `:shared-app`) was not reachable from Swift because `:shared-app` previously only built a non-exported `SkeletonApp` framework. Refactored `shared-app/build.gradle.kts` to emit a real XCFramework via `XCFramework("SkeletonApp")` that explicitly `export(...)`s both `:shared-core` and `:shared-components` (K/N `export` is not transitive — both must be listed). All Swift sources now `import SkeletonApp` instead of `SkeletonKit`.

3. **Missing `-lsqlite3` linker option on the umbrella framework.** First framework link failed with `_sqlite3_*` undefined symbols. `:shared-core` had the linker opt; `:shared-components` did not. Added it (and added it to the new `:shared-app` framework too).

4. **SKIE-only call sites in pre-existing iOS code.** SKIE is intentionally disabled (Kotlin 2.3.21 incompatible with SKIE 0.10.11 per the comment in `shared-components/build.gradle.kts:60-68`), but the existing `IosViewModelStoreOwner.swift` and `GreetingScreen.swift` relied on it. Replaced with vanilla K/N patterns:
   - `ViewModelProvider.Factory` → `ViewModelProviderFactory` (K/N exports nested types of non-object classes as flat protocols)
   - `owner.viewModel<VM>(factory:)` → per-VM Kotlin helper `GreetingViewModelHelperKt.createGreetingViewModel(store:)` (Swift cannot construct a `KotlinKClass` without SKIE; the generic extension was removed and a documentation note added)
   - `onEnum(of: state) { case .ready(let s): … }` → `if let ready = state as? GreetingViewModelUiStateReady { … }` against the bridged subclass types
   - `for await s in vm.state { … }` → `GreetingViewModelHelperKt.subscribeGreetingState(vm:onState:) → Job` (Job held in @State, cancelled on `.onDisappear`)
   - `[IosPlatformModuleKt.iosPlatformModule]` → `KotlinArray<Koin_coreModule>(size: 1) { _ in … }` (Swift array literal doesn't auto-bridge to Kotlin vararg)

5. **EXCLUDED_ARCHS=x86_64 for iphonesimulator.** Build initially failed because Xcode tried to compile x86_64 alongside arm64 but the shared framework only ships arm64 simulator slices (Kotlin target is `iosSimulatorArm64` per Phase 1 D-01). Added the exclusion in `project.yml` configs.

These deviations expand scope beyond pure Phase 2 token-bridge work, but they're the minimum necessary to verify Wave 2B per the plan's xcodebuild gate. The Phase 1 iOS code was draft-only and not shippable before this plan; it now compiles and the showcase runs end-to-end.

## Issues Encountered

All issues were the Phase 1 gaps documented in Deviations above. Each was resolved before the manual D-17 checkpoint.

## User Setup Required

- **First-time iOS build on a new machine:** install XcodeGen (`brew install xcodegen`) then run `./iosApp/generate-xcodeproj.sh`. The script handles the rest (XCFramework build + Xcode project generation).
- **README update suggested** (out of scope for this SUMMARY): document the XcodeGen prerequisite and the generate-xcodeproj.sh bootstrap step. Currently the README still references `open iosApp/iosApp.xcodeproj` directly — that path now requires the generator to have run first.

## Next Plan Readiness

- iOS adapter ready; manual D-17 cycle smoke approved on simulator (10× taps, palette flips per tap, label cycles `Override theme → Switch to Dark → Switch to System → Override theme`).
- All non-SKIE call patterns documented in helper Kotlin files — future shared ViewModels follow `createXxxViewModel(store:)` + `subscribeXxxState(vm:onState:) → Job`.
- 02-04 Wave 3 dark-mode test additions in `DesignTokensTest.kt` can proceed; manual gate (which this plan unblocked) is the only blocker remaining.

---
*Phase: 02-design-token-bridge*
*Completed: 2026-05-18*

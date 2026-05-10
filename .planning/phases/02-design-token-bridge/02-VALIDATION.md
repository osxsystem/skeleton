---
phase: 2
slug: design-token-bridge
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-10
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | kotlin.test + kotest-assertions-core (commonTest); JUnit/Espresso (Android instrumented); XCTest (iOS) |
| **Config file** | `gradle/libs.versions.toml`, `shared-core/build.gradle.kts` (kotlin-test, kotest deps) |
| **Quick run command** | `./gradlew :shared-core:jvmTest` (~5s — fast feedback on token primitives) |
| **Full suite command** | `./gradlew :shared-core:allTests` (commonTest across jvm + iosSimulatorArm64) |
| **Estimated runtime** | ~30–60 seconds (full allTests including iOS simulator target) |

---

## Sampling Rate

- **After every task commit:** Run `./gradlew :shared-core:jvmTest` (jvmTest only; <10s feedback)
- **After every plan wave:** Run `./gradlew :shared-core:allTests` (cross-target — catches Long-overflow on iosSimulatorArm64)
- **Before `/gsd-verify-work`:** Full suite must be green; manual dark-mode toggle smoke on both platforms
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-T1 | 02-01 | 1 | THEME-01, THEME-02 | Pitfall 6 | No platform imports in commonMain; 36 Long constants per palette (incl. surfaceTint) with L suffix | build gate | `./gradlew :shared-core:jvmTest 2>&1 \| tail -5` | ✅ planned | ⬜ pending |
| 02-01-T2 | 02-01 | 1 | THEME-02 | Pitfall 6 | noColorConstantIsNegative covers all 72 constants (36 light + 36 dark); kotlin.test.Test used (not org.junit.Test) | unit (commonTest) | `./gradlew :shared-core:jvmTest --tests "dev.viethung.core.theme.DesignTokensTest" 2>&1 \| tail -10` | ✅ planned | ⬜ pending |
| 02-02-T1 | 02-02 | 2 | THEME-02, THEME-03 | Pitfall 6 | ColorScheme(36 roles incl. surfaceTint) sourced from DesignTokens; no hex literals in theme dir | build gate | `./gradlew :androidApp:assembleDebug 2>&1 \| tail -10` | ✅ planned | ⬜ pending |
| 02-02-T2 | 02-02 | 2 | THEME-03 | — | MainActivity wraps with AppTheme; no bare MaterialTheme | build gate | `./gradlew :androidApp:assembleDebug 2>&1 \| tail -5` | ✅ planned | ⬜ pending |
| 02-03-T1 | 02-03 | 2 | THEME-04 | Pitfall 6 | Color(argb: Int64) extension; 36 ThemeColors fields incl. surfaceTint; AppTheme.swift in project.pbxproj | grep + pbxproj check | `grep -c 'EnvironmentKey' iosApp/iosApp/Theme/AppTheme.swift && grep -c 'Int64' iosApp/iosApp/Theme/AppTheme.swift && grep -c 'AppTheme.swift' iosApp/iosApp.xcodeproj/project.pbxproj` | ✅ planned | ⬜ pending |
| 02-03-T2 | 02-03 | 2 | THEME-04, THEME-05 | Pitfall 7 | AppTheme injected at WindowGroup root; .red replaced by theme.colors.error; xcodebuild passes | build gate | `xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 \| tail -5` | ✅ planned | ⬜ pending |
| 02-03-T3 | 02-03 | 2 | THEME-04 | Pitfall 6 (Swift side) | testColorAdapterPreservesAlphaForFFOpaqueLong passes; AppThemeTests.swift in project.pbxproj | XCTest (unit) | `xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 \| tail -5` | ✅ planned | ⬜ pending |
| 02-04-T1 | 02-04 | 3 | THEME-05 | Pitfall 7 | rapidToggleSimulation + darkColorsBrightInDark tests pass (5 total in DesignTokensTest) | unit (commonTest) | `./gradlew :shared-core:jvmTest --tests "dev.viethung.core.theme.DesignTokensTest" 2>&1 \| grep -E "tests completed\|FAILED\|PASSED"` | ✅ planned | ⬜ pending |
| 02-04-CKP | 02-04 | 3 | THEME-05 (SC4) | Pitfall 7 | 10× dark/light toggle without app restart on Android + iOS | checkpoint:human-verify | manual | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `:shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt` — `noColorConstantIsNegative()` + token-completeness assertions for THEME-01, THEME-02 — **covered by 02-01-T2**
- [x] kotest-assertions-core dependency confirmed in `:shared-core` commonTest sourceSet (carry-over from Phase 1)
- [x] iOS smoke harness: `iosApp/iosAppTests/AppThemeTests.swift` — `testColorAdapterPreservesAlphaForFFOpaqueLong()` verifies Pitfall 6 mitigation on the Swift side — **covered by 02-03-T3**

*All Wave 0 items are covered by planned tasks. nyquist_compliant = true.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live dark/light toggle without restart (Android) | THEME-04 (SC4) | System-appearance switch is OS-level, not unit-testable | 1) Run `:androidApp:installDebug` 2) Open Settings → Display → Dark theme 3) Toggle 10× rapidly, confirm GreetingScreen palette flips each time without app restart |
| Live dark/light toggle without restart (iOS) | THEME-04 (SC4) | `@Environment(\.colorScheme)` is driven by macOS/iOS appearance setting | 1) Run `iosApp` in simulator 2) Features → Toggle Appearance (Cmd+Shift+A) 3) Toggle 10× rapidly, confirm theme flips without restart |
| No hex literals in androidApp theme code | THEME-02 (SC2) | Negative assertion (file content) | `! grep -rE '0x[0-9A-Fa-f]{6,8}L?' androidApp/src/main/kotlin/.../theme/` returns no hits |
| No hex literals in iosApp theme code | THEME-03 (SC3) | Negative assertion (file content) | `! grep -rE 'Color\(red:.*green:.*blue:' iosApp/iosApp/Theme/` returns no hits (raw initializers must live in `AppTheme.swift` adapter only, taking `Long` → `Color`) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

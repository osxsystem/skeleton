---
phase: 2
slug: design-token-bridge
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| TBD-by-planner | TBD | TBD | THEME-01..05 | — | — | unit/instrumented | `./gradlew :shared-core:allTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Planner fills this table from PLAN.md task IDs after Step 8 completes.*

---

## Wave 0 Requirements

- [ ] `:shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt` — `noColorConstantIsNegative()` + token-completeness assertions for THEME-01, THEME-02
- [ ] kotest-assertions-core dependency confirmed in `:shared-core` commonTest sourceSet (carry-over from Phase 1)
- [ ] iOS smoke harness: `iosApp/iosAppTests/AppThemeTests.swift` — `testColorAdapterPreservesAlphaForFFOpaqueLong()` verifies Pitfall 6 mitigation on the Swift side

*If none of the above is missing post-Phase-1, downgrade to "Existing infrastructure covers all phase requirements."*

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

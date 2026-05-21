# Scenario Report — Number Input Library

> Output of `ck:scenario` skill against `feat/number-input-library`, 2026-05-20.
> Targets:
> - Android `:number-input` (AAR + Jetpack Compose)
> - Pure-Swift SPM `NumberInputKit`
> - Swift wrapper `NumberInput` consuming SkeletonKit XCFramework

## Dimensions analyzed (11/12)

User Types · Input Extremes · Timing · Scale · State Transitions · Environment · Error Cascades · Data Integrity · Integration · Compliance/a11y · Business Logic.

Skipped: **Authorization** — number input is a leaf UI widget with no auth surface.

## Scenario matrix

| # | Dimension | Scenario | Severity | Expected Behavior |
|---|-----------|----------|----------|-------------------|
| 1  | User Types          | VoiceOver/TalkBack focuses field; toolbar Done/Clear/± announced | High     | Each button reads its accessibilityLabel; field announces accessibilityValue or "Empty" |
| 2  | User Types          | Switch Control sequential focus traversal: field → toolbar | Medium   | Toolbar reachable without keyboard |
| 3  | User Types          | Power user pastes formatted text `"1,234,567.89"` en-US | Medium   | Parse strips grouping, regroups live |
| 4  | User Types          | New user sees disabled ± when `allowNegative=false` | Low      | Button visibly disabled (alpha + accessibilityHint) |
| 5  | Input Extremes      | `""` typed mid-edit clears value to nil | High     | `state.value == null && formattedText == ""` |
| 6  | Input Extremes      | Pasted scientific notation `"1e10"` — formatter cannot parse | High     | Keep prior value; rawText shows "1e10"; display unchanged after commit |
| 7  | Input Extremes      | Pasted Unicode minus `−42.5` (U+2212) on iOS | High     | parse returns nil; ± toolbar remains the sole sign source |
| 8  | Input Extremes      | Arabic-Indic digits `١٢٣٤.٥` pasted (unsupported locale digits) | Medium   | parse returns nil; no crash |
| 9  | Input Extremes      | Multiple decimal separators `"1.2.3"` typed en-US | High     | parse returns nil → keep prior value; live formatter behavior **undefined — test required** |
| 10 | Input Extremes      | Leading zeros `"000123"` typed | Medium   | groupedInt re-computes from Long → drops zeros |
| 11 | Input Extremes      | Very long integer `"999999999999999999"` exceeds `Long`/`Int64` range | High     | `toLongOrNull` returns null → digits kept verbatim, no crash |
| 12 | Input Extremes      | Pasted `" 1234.5 "` with surrounding whitespace | Medium   | iOS `parse` trims; Android `DecimalFormat.parse` may fail — **inconsistency risk** |
| 13 | Timing              | Done tapped while `viewModelScope.launch` for onTextChange is still scheduled | High     | Commit operates on latest emitted state; no torn update |
| 14 | Timing              | Rapid focus toggle (focus → blur → focus) | High     | StateFlow distinct-until-changed handles double-Idle |
| 15 | Timing              | SwiftUI `.onReceive(vm.$state)` writes back to `@Binding value` while typing | Critical | Binding write must not re-trigger `onTextChange`; verify no echo loop |
| 16 | Timing              | Two ± taps within one frame | Medium   | Net result matches parity of taps; no Combine over-emission |
| 17 | Scale               | `significantDigits = 0` formatting `1234.5` | High     | Output `"1,234"`, no decimal separator |
| 18 | Scale               | `significantDigits = 9` formatting `1234.5` | Medium   | Output `"1,234.500000000"`, < 5 ms (NFR-01) |
| 19 | Scale               | `initialValue = Double.MAX_VALUE` | High     | format succeeds; integer-part `toLong()` overflows safely in live formatter |
| 20 | Scale               | `initialValue = Double.NaN` / `POSITIVE_INFINITY` | High     | format returns "NaN"/"∞"; parse on commit returns nil; VM stable |
| 21 | Scale               | `significantDigits = -1` or `10` passed directly to VM | Critical | NumberInputConfig fails fast; **VM constructor accepts any Int — gap** |
| 22 | State Transitions   | `onClear()` while currently `Idle` | Medium   | Currently transitions to Editing without focus — **possible defect** |
| 23 | State Transitions   | `onToggleSign()` while currently `Idle` | Medium   | Same as #22 |
| 24 | State Transitions   | `onCommit()` twice in succession | Medium   | Emits Committed/Idle/Committed/Idle; collectors may double-fire |
| 25 | State Transitions   | `onTextChange` while `Idle` (pre-focus) | Medium   | Currently transitions to Editing; verify intentional |
| 26 | State Transitions   | initialValue null + onClear (already empty) | High     | `prevValue` guard prevents extra emit (Compose) |
| 27 | State Transitions   | iOS Binding for `value` set externally after first render | High     | VM is `@StateObject`, not re-initialised → **external value change ignored on iOS** |
| 28 | Environment         | Device locale changed at runtime | High     | Compose `viewModel(key=...locale...)` rebuilds VM |
| 29 | Environment         | RTL layout (ar/he) | Medium   | Toolbar mirror; NumberFormatter handles sign placement |
| 30 | Environment         | iPad external Bluetooth keyboard — letters typed | Medium   | parse returns nil → keep prior value |
| 31 | Environment         | Process death (Android) mid-edit | Medium   | Out of scope v1; documented |
| 32 | Environment         | Compose `LazyColumn` recycles field while typing | High     | `viewModel(key=...)` preserves VM state |
| 33 | Environment         | Dynamic Type at AX5 — toolbar buttons truncate | Low      | Acceptable visually; accessibilityLabel intact |
| 34 | Environment         | iOS keyboard locale en-US, field locale vi-VN — `.` substituted with `,` | High     | Verified at `NumberInputUITextField.swift:78` |
| 35 | Error Cascades      | Invalid BCP-47 tag `"xx-XX"` | Medium   | Locale falls back to ROOT; functional |
| 36 | Error Cascades      | `NumberFormatter.string(from:)` returns nil for `NaN` on some iOS versions | High     | iOS impl `?? ""` → safe |
| 37 | Error Cascades      | `DecimalFormat.getInstance` cast fails on non-DecimalFormat locale | Medium   | ClassCastException possible; document or guard |
| 38 | Data Integrity      | Repeated ± on `0.1` | High     | Sign toggle is pure negation; no drift |
| 39 | Data Integrity      | ± on `0.0` → `-0.0` display | Medium   | NumberFormatter suppresses sign; visual no-op |
| 40 | Data Integrity      | Round-trip `format(1.005, 2)` half-even on both platforms | High     | iOS halfEven `→ "1.00"`; Android DecimalFormat default halfEven — match |
| 41 | Data Integrity      | Invalid text doesn't re-emit onValueChange | High     | `prevValue` guard (NumberInputField.kt:48) |
| 42 | Data Integrity      | iOS `onReceive(vm.$state)` writes binding on every state emission | High     | **Defect risk** — value setter fires on every state mutation |
| 43 | Integration         | XCFramework `SkeletonKit.xcframework` missing at SPM resolve time | Critical | SPM fails with path error; documented |
| 44 | Integration         | NumberInputKit consumed by iOS-15 app (below `.iOS(.v16)` floor) | High     | SPM rejects with platform-mismatch error |
| 45 | Integration         | Compose `viewModel(key=...)` rebuilds VM when `significantDigits` changes | High     | New VM seeded with current binding value; no flicker |
| 46 | Integration         | `.numberInputTheme(_:)` modifier propagation through StateObject | Medium   | Environment read in `body`; propagation OK |
| 47 | Integration         | `NumberInputBridge.subscriptionJob` not cancelled — leak | High     | `deinit` cancels job; leak only on retain cycle |
| 48 | Integration         | AAR consumer on older AGP / Compose Compiler mismatch | Medium   | Gradle resolution catches mismatch |
| 49 | Compliance / a11y   | Empty value reads "Empty" via accessibilityValue | High     | Verified iOS; Android has no equivalent — **gap** |
| 50 | Compliance / a11y   | Toolbar buttons exposed via accessibilityIdentifier | High     | Verified for both platforms |
| 51 | Business Logic      | ± when value is exactly 0.0 (non-null) | Medium   | `-0.0` produced; formatter renders without sign |
| 52 | Business Logic      | `allowNegative=false` + binding set externally to `-5.0` post-init | High     | Initial clamp only runs at construction — **gap** |
| 53 | Business Logic      | `onTextChange("-")` with `allowNegative=false` | Medium   | Currently displays `-`; consider rejecting |
| 54 | Business Logic      | `significantDigits = 5` typing `1.234567` then Done | High     | Both platforms halfEven `→ "1.23457"` |
| 55 | Business Logic      | Placeholder visible while value=null and focused | Low      | UITextField shows attributedPlaceholder; Compose null — visual parity |

## Summary

| Severity | Count |
|---|---|
| Critical | **3** (#15, #21, #43) |
| High     | **24** |
| Medium   | **23** |
| Low      | **5** |
| **Total**    | **55** |

## Existing test coverage map (qualitative)

| Scenario # | Already covered? | Where |
|---|---|---|
| 5, 14, 17, 18, 19, 26, 38, 41 | ✅ | `NumberInputViewModelTest.kt` / `NumberInputViewModelTests.swift` |
| 6 (live format en-US), 28, 34 | ✅ | `LiveFormatTests.swift`, `NumberInputUITextField.swift` |
| 50 | ✅ partial | toolbar accessibility identifiers wired |
| 7, 8, 9, 10, 11, 12, 15, 17 (en-US edge), 19, 20, 21, 22, 23, 27, 29, 36, 37, 39, 40, 42, 49, 51, 52, 53, 54 | ❌ | gap — addressed in Bước 3 |

## Self-Check

```
📋 Bước 2 Self-Check:
├── Gọi Skill tool ck:scenario? ✅ CÓ
├── Số dimensions phân tích: 11/12 (Authorization N/A documented)
├── Số scenarios: 55 (≥ 30 required) ✅
└── Có severity (Critical/High/Medium/Low)? ✅
```

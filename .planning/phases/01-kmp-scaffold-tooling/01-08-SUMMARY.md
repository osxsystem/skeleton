---
phase: 01-kmp-scaffold-tooling
plan: "08"
subsystem: ios
tags: [swiftui, skie, koin, viewmodel, statobject]

requires:
  - phase: 01-kmp-scaffold-tooling
    provides: ":shared-app GreetingViewModel, AppModule (initKoin), GreetingViewModelFactory; :shared-components SkeletonKit framework spec"
provides:
  - "iOS Swift sources implementing the @StateObject ViewModel lifecycle pattern (D-12, SCAF-05)"
  - "SKIE AsyncSequence consumption pattern via for await in .task {} (SCAF-06)"
  - "Koin initialization from iOS via AppKoinBridge (SCAF-06)"
  - "DEFERRED: Xcode .xcodeproj creation, framework embedding, build, and runtime smoke test"
affects: [phase-02, phase-03, phase-05, phase-07]

tech-stack:
  added: [SwiftUI, SKIE bridging, NavigationStack]
  patterns: ["@StateObject IosViewModelStoreOwner with deinit clear", "SwiftUI .task { for await } SKIE consumption", "import SkeletonKit (umbrella) not import shared"]

key-files:
  created:
    - "iosApp/iosApp/Common/IosViewModelStoreOwner.swift"
    - "iosApp/iosApp/App/AppKoinBridge.swift"
    - "iosApp/iosApp/Greeting/GreetingScreen.swift"
    - "iosApp/iosApp/iosApp.swift"
    - "iosApp/iosApp/ContentView.swift"
    - "shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt"
  modified:
    - "shared-app/src/commonMain/kotlin/dev/viethung/showcase/di/AppModule.kt"

key-decisions:
  - "Task 2 (Xcode IDE work) deferred — captured as a HUMAN-UAT item; finalised when Mac+Xcode 16 toolchain is available"
  - "iosApp.swift entry point calls AppKoinBridge.start() in init() before any view is constructed"
  - "ContentView wraps GreetingScreen in NavigationStack so the Phase 5 navigation host plugs in cleanly"

patterns-established:
  - "iOS ViewModel lifecycle: SwiftUI view holds @StateObject IosViewModelStoreOwner; deinit logs '[IosViewModelStoreOwner] deinit cleared store'"
  - "SKIE bridge: Kotlin Flow → AsyncSequence consumed via for await in SwiftUI .task {} blocks"
  - "Top-level Kotlin fns (initKoin, greetingViewModelFactory) become AppModuleKt.doInitKoin() / GreetingViewModelFactoryKt.greetingViewModelFactory in Swift"

requirements-completed:
  - SCAF-05  # @StateObject + deinit clear pattern locked in Swift sources
  - SCAF-06  # SKIE AsyncSequence consumption pattern locked in Swift sources

# Metrics
duration: ~3.5min (autonomous portion)
completed: 2026-05-09
---

# Plan 01-08: iOS Xcode Project Summary

**Swift sources for the iOS showcase app are written and committed. The Xcode `.xcodeproj` and runtime smoke test are deferred to a HUMAN-UAT item — to be completed on a Mac with Xcode 16 toolchain available.**

## Performance

- **Duration:** ~3.5 min (autonomous Swift-source generation only)
- **Tasks:** 1/2 complete autonomously; Task 2 deferred per user decision
- **Files modified:** 7 created

## Accomplishments
- All architectural pitfalls from `01-CONTEXT.md` (Pitfalls 1, 2, 21) encoded in the committed Swift sources
- `IosViewModelStoreOwner` declared `@StateObject` with `deinit { viewModelStore.clear() }` and `print("[IosViewModelStoreOwner] deinit cleared store")` (D-12 / SCAF-05)
- `import SkeletonKit` everywhere — never `import shared` (D-15 / Pitfall 21)
- `GreetingScreen` consumes the StateFlow via `.task { for await s in vm.state { state = s } }` (SCAF-06)
- `AppKoinBridge.start()` calls `AppModuleKt.doInitKoin()` from `iosApp.init()` before any view is built

## Task Commits

1. **Task 1: iOS Swift sources** — `5f3672e` (feat)

## Deferred — HUMAN-UAT (open)

The following must be completed on a Mac with Xcode 16 to close out this plan's UAT:

| Step | Action | Where |
|------|--------|-------|
| 1 | `./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework` | Terminal at repo root |
| 2 | Create iOS App project (SwiftUI lifecycle), bundle id `dev.viethung.skeleton.ios`, save into `iosApp/` | Xcode → File → New → Project |
| 3 | Set Minimum Deployments → iOS 17.0 | Project → General |
| 4 | Drag committed Swift files into project navigator (replace generated `iosApp.swift` / `ContentView.swift`) | Xcode project navigator |
| 5 | Add `SkeletonKit.xcframework` → Embed & Sign | Targets → iosApp → General → Frameworks |
| 6 | Add `-lsqlite3` to Other Linker Flags | Build Settings |
| 7 | ⌘B compile, run on iPhone 15 simulator (iOS 17), confirm "Hello, KMP" renders | Xcode |
| 8 | Navigate away from `GreetingScreen` and back; confirm `[IosViewModelStoreOwner] deinit cleared store` in console | Xcode console |

This list will surface in `/gsd-progress` and `/gsd-audit-uat` until verified.

## Self-Check

The autonomous portion is internally consistent and follows the plan's must-haves. Runtime smoke test is **NOT** done — that is the explicit deferral.

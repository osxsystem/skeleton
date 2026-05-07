<!-- generated-by: gsd-doc-writer -->
# Testing

This document describes the test strategy, frameworks, file conventions, and commands for the Skeleton KMP project.

---

## Test framework and setup

Testing spans three layers, each using the idiomatic framework for that context:

| Layer | Framework | Scope |
|---|---|---|
| Shared business logic (`commonMain` / `commonTest`) | `kotlin.test` + Kotest | Use cases, repositories, ViewModels, domain models |
| Android UI | JUnit 4 + Compose UI Test | `@Composable` screens, Compose interactions |
| iOS | XCTest | SwiftUI views, iOS-specific `actual` implementations |

No additional global setup is required beyond the standard project prerequisites (JDK 21, Android SDK, Xcode 15.4+). See [GETTING-STARTED.md](../docs/GETTING-STARTED.md) if those are not yet installed.

Dependencies are declared in `gradle/libs.versions.toml`. No manual installation step is needed — Gradle resolves them on first build.

---

## Running tests

### Shared KMP tests (all platforms)

```bash
./gradlew :shared:allTests
```

Runs `commonTest` on JVM, Android (via a device/emulator if connected), and iOS simulator targets simultaneously. This is the primary command for validating shared logic.

### Shared tests — JVM only (fast feedback loop)

```bash
./gradlew :shared:jvmTest
```

Runs only the JVM target. No Android device or simulator required. Use this during local development for the quickest iteration cycle.

### Android instrumented and UI tests

```bash
./gradlew :androidApp:connectedAndroidTest
```

Requires a connected Android device or running emulator. Runs Compose UI tests alongside any Android-specific instrumented tests.

### Android unit tests (JVM, no device)

```bash
./gradlew :androidApp:testDebugUnitTest
```

### Static analysis

```bash
./gradlew check
```

Runs lint and any configured static-analysis tasks across all modules. Note: `ktlint` / `detekt` integration is marked TBD in the project; check `build.gradle.kts` files as the project matures.

### iOS tests

Open the project in Xcode and run the test suite with `⌘U`, or from the command line:

```bash
xcodebuild test \
  -scheme iosApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Replace the simulator name with any available simulator from `xcrun simctl list devices`.

---

## Writing new tests

### File naming and location

| Test type | Location | File naming |
|---|---|---|
| Shared (common) | `shared/src/commonTest/kotlin/dev/skeleton/` | `*Test.kt` (e.g., `ProfileViewModelTest.kt`) |
| Android unit | `androidApp/src/test/kotlin/dev/skeleton/` | `*Test.kt` |
| Android instrumented | `androidApp/src/androidTest/kotlin/dev/skeleton/` | `*Test.kt` |
| iOS | `iosApp/iosAppTests/` | `*Tests.swift` |

### Shared test example (`commonTest`)

```kotlin
// shared/src/commonTest/kotlin/dev/skeleton/ui/profile/ProfileViewModelTest.kt
package dev.skeleton.ui.profile

import kotlin.test.Test
import kotlin.test.assertIs

class ProfileViewModelTest {

    @Test
    fun initialStateIsLoading() {
        val vm = ProfileViewModel(FakeLoadProfileUseCase())
        assertIs<ProfileViewModel.UiState.Loading>(vm.state.value)
    }
}
```

Use `kotlin.test` assertions (`assertEquals`, `assertIs`, `assertNotNull`) — they are multiplatform and work on JVM, Android, and iOS simulator targets without modification.

### Kotest (optional, shared)

Kotest's `core` artifact supports KMP. Use it for property-based tests or more expressive specs in `commonTest`. Keep `kotlin.test` as the default for straightforward unit assertions.

### Compose UI test example (Android)

```kotlin
// androidApp/src/androidTest/kotlin/dev/skeleton/ProfileScreenTest.kt
@RunWith(AndroidJUnit4::class)
class ProfileScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun showsLoadingIndicatorInitially() {
        composeTestRule.setContent { ProfileScreen() }
        composeTestRule.onNodeWithTag("loading_indicator").assertIsDisplayed()
    }
}
```

---

## Coverage requirements

No coverage thresholds are configured at this time. The project is in design/early implementation phase.

When thresholds are introduced, add them to `shared/build.gradle.kts` under the `kover` (or `jacoco`) configuration block and document the values here.

---

## CI integration

No CI/CD pipeline is configured in the repository at this time. There are no `.github/workflows/` files present.

When CI is added, the recommended test step sequence is:

1. `./gradlew :shared:allTests` — shared KMP logic
2. `./gradlew :androidApp:testDebugUnitTest` — Android unit tests
3. `./gradlew check` — static analysis
4. `xcodebuild test ...` on a macOS runner — iOS tests

<!-- VERIFY: CI platform, runner OS, and exact workflow trigger once a pipeline is configured -->

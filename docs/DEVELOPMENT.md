<!-- generated-by: gsd-doc-writer -->
# Development

This guide covers local setup, build commands, code style conventions, and the contribution workflow for the Skeleton KMP project.

---

## Local setup

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| JDK | 21 | Set `JAVA_HOME` to this installation |
| Android SDK | latest stable | Set `ANDROID_HOME` / `ANDROID_SDK_ROOT` |
| Xcode | 15.4+ | Required for iOS builds |
| Kotlin | pinned in `gradle/libs.versions.toml` | Do not drift from the pinned version |

CocoaPods is **not** required — the project uses Swift Package Manager (SPM).

### Clone and first build

```bash
git clone https://github.com/<your-username>/skeleton.git
cd skeleton
```

Gradle downloads all dependencies automatically on first build. No separate install command is needed.

Export the required environment variables before running any Gradle task:

```bash
export JAVA_HOME=/path/to/jdk21
export ANDROID_HOME=~/Library/Android/sdk   # or ANDROID_SDK_ROOT
```

See [CONFIGURATION.md](CONFIGURATION.md) for the full list of environment variables.

---

## Build commands

All builds are driven by Gradle. Run tasks from the project root (`skeleton/`).

| Command | Description |
|---|---|
| `./gradlew :androidApp:installDebug` | Build and install the Android app on a connected device or emulator |
| `./gradlew :androidApp:assembleDebug` | Assemble the Android debug APK without installing |
| `./gradlew :androidApp:assembleRelease` | Assemble the Android release APK |
| `./gradlew :shared:allTests` | Run all tests in the `shared/` KMP module (common + platform targets) |
| `./gradlew check` | Run static analysis across all modules (includes ktlint/detekt when wired) |
| `./gradlew build` | Build all modules |

### iOS builds

iOS must be built through Xcode — Gradle produces the shared framework, Xcode links it via SPM:

```bash
# Open the Xcode project, then use ⌘R or xcodebuild
open iosApp/iosApp.xcodeproj
```

Command-line iOS build (e.g., for CI):

```bash
xcodebuild -scheme Skeleton -destination 'generic/platform=iOS Simulator' build
```

---

## Code style

### Kotlin (`shared/`, `androidApp/`)

Static analysis tooling (ktlint / detekt) is planned but not yet wired. The following conventions are enforced by code review until tooling is configured:

- All visual primitives (color, font, spacing, radius) must come from `shared/.../theme/DesignTokens.kt`. Raw literals (`16.dp`, `Color(0xFF...)`, `Font.system(size: 14)`) are rejected in review.
- No business logic in `androidApp/` or `iosApp/`. Move it to `shared/` using `expect`/`actual` if platform glue is required.
- All dependency versions are declared in `gradle/libs.versions.toml`. No inline version literals in `build.gradle.kts` files.

Run static analysis when available:

```bash
./gradlew check
```

### Swift (`iosApp/`)

SwiftUI code follows platform-idiomatic Swift conventions. Theme values are consumed via `AppTheme` helpers — no raw color or font literals in view files.

### Version catalog

`gradle/libs.versions.toml` is the single source of truth for every library and plugin version. Always update versions there, not in individual `build.gradle.kts` files.

---

## Branch conventions

No formal branch naming policy is documented yet. The recommended approach until one is established:

- Use `feat/<short-description>` for new features.
- Use `fix/<short-description>` for bug fixes.
- Use `chore/<short-description>` for maintenance tasks (dependency updates, tooling config).
- The default branch is `main`; `develop` is the active working branch.

One commit per logical change — many small commits are preferred over one large commit.

---

## PR process

No `.github/PULL_REQUEST_TEMPLATE.md` exists yet. Follow these guidelines when opening a pull request:

- Keep PRs small and focused on a single logical change.
- Ensure `./gradlew :shared:allTests` passes before opening the PR.
- Ensure `./gradlew check` passes (once linting is wired).
- For iOS changes, verify the Xcode build succeeds on a simulator target.
- Reference the relevant item from the README TODO list if the PR implements a planned task.
- After renaming from `skeleton` to a real product name, update the PR template to reflect the new project identity.

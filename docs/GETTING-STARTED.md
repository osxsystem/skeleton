<!-- generated-by: gsd-doc-writer -->
# Getting Started

This guide covers everything you need to clone, configure, and build the Skeleton KMP template for the first time.

---

## Prerequisites

Install and configure all of the following before running any build command.

| Tool | Version | Notes |
|---|---|---|
| JDK | 21 | Set `JAVA_HOME` and `ANDROIDX_JDK21` to the same path |
| Android SDK | latest stable | Set `ANDROID_SDK_ROOT` (and optionally `ANDROID_HOME`) |
| Xcode | 15.4+ | Required for iOS builds |
| Android Studio | 2025.2.3.5 | Set Gradle JVM to JDK 21 under `Settings → Build, Execution, Deployment → Build Tools → Gradle` |
| Kotlin | pinned in `gradle/libs.versions.toml` | Do not override; Gradle resolves it automatically |

> CocoaPods is **not** required. iOS dependencies are managed via Swift Package Manager (SPM).

---

## Installation Steps

1. Clone the repository:

```bash
git clone https://github.com/<your-username>/skeleton.git
cd skeleton
```

2. Export required environment variables (add to your shell profile for persistence):

```bash
export ANDROIDX_JDK21=/opt/homebrew/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home
export JAVA_HOME=$ANDROIDX_JDK21
export ANDROID_SDK_ROOT=~/Library/Android/sdk
```

3. No additional package manager install step is required. Gradle downloads all dependencies automatically on first build.

---

## First Run

### Android

Build and install on a connected device or running emulator:

```bash
./gradlew :androidApp:installDebug
```

### iOS

Open the Xcode project, select a simulator, and press `Cmd+R`:

```bash
open iosApp/iosApp.xcodeproj
```

### Shared tests

```bash
./gradlew :shared:allTests
```

---

## Common Setup Issues

**"No matching toolchains found for requested specification"**

Gradle's auto-download and auto-detect are both disabled (`gradle.properties`). This error means `ANDROIDX_JDK21` is not set or does not point to a valid JDK 21 installation. Verify:

```bash
echo $ANDROIDX_JDK21
java -version   # should print 21.x
```

**Android SDK not found**

Set `ANDROID_SDK_ROOT` to the root of your SDK installation (e.g. `~/Library/Android/sdk` on macOS). Optionally create `local.properties` at the project root with:

```properties
sdk.dir=/path/to/your/Android/sdk
```

**Configuration cache failures after plugin or settings changes**

Bypass the cache for one run:

```bash
./gradlew <task> --no-configuration-cache
```

**Xcode build fails to find the `shared` framework**

The iOS app consumes `shared` via SPM. Ensure the scheme is set to a simulator target and run a full Gradle build first so the framework artifact exists:

```bash
./gradlew :shared:assembleDebugXCFramework
```

Then build in Xcode.

---

## Next Steps

- **Development workflow and build commands:** see [DEVELOPMENT.md](DEVELOPMENT.md)
- **Architecture and layering rules:** see [ARCHITECTURE.md](ARCHITECTURE.md)
- **Environment variables and Gradle properties:** see [CONFIGURATION.md](CONFIGURATION.md)
- **Renaming for a real product:** follow the find-and-replace sequence in [README.md](../README.md#renaming-the-skeleton)

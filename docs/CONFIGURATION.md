<!-- generated-by: gsd-doc-writer -->
# Configuration

This document covers all environment variables, Gradle properties, and local configuration files required to build and develop the `compose-multiplatform-core` (JetBrains fork of androidx).

---

## Environment Variables

These variables must be exported in your shell before running any Gradle command.

| Variable | Required | Default | Description |
|---|---|---|---|
| `ANDROIDX_JDK21` | Required | — | Path to a JDK 21 installation. Gradle toolchain resolution uses this exclusively (`auto-download` and `auto-detect` are both disabled in `gradle.properties`). |
| `JAVA_HOME` | Required | — | Should point to the same JDK 21 path as `ANDROIDX_JDK21`. |
| `ANDROID_SDK_ROOT` | Required | — | Path to Android SDK root (e.g. `~/Library/Android/sdk`). Checked after `ANDROID_HOME` per AGP conventions. |
| `ANDROID_HOME` | Optional | — | Deprecated AGP alias for `ANDROID_SDK_ROOT`. Checked first if set. |

**Symptom when `ANDROIDX_JDK21` is missing:** Gradle fails at toolchain resolution with "No matching toolchains found for requested specification" because both `org.gradle.java.installations.auto-download=false` and `org.gradle.java.installations.auto-detect=false` are set in `gradle.properties`.

Example export (macOS/Linux):

```bash
export ANDROIDX_JDK21=/opt/homebrew/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home
export JAVA_HOME=$ANDROIDX_JDK21
export ANDROID_SDK_ROOT=~/Library/Android/sdk
```

---

## Local Configuration File

**`compose-multiplatform-core/local.properties`**

This file is not checked into version control. It is auto-generated or manually created to supply the Android SDK path for Gradle when running outside a full `repo` checkout (Playground layout).

```properties
sdk.dir=/path/to/your/Android/sdk
```

The `sdk.dir` value is read by `SdkHelper.kt` before falling back to `ANDROID_SDK_ROOT`. Set it to the same path as `ANDROID_SDK_ROOT`.

---

## Gradle Properties (`gradle.properties`)

Located at `compose-multiplatform-core/gradle.properties`. The table below covers the properties most relevant to day-to-day development. The full file contains additional AGP and Kotlin suppression flags that do not require developer changes.

### JVM / Toolchain

| Property | Value | Description |
|---|---|---|
| `org.gradle.jvmargs` | `-Xmx12g ...` | Daemon JVM heap and GC settings. Reduce `-Xmx` if your machine has less than 16 GB RAM. |
| `org.gradle.java.installations.fromEnv` | `ANDROIDX_JDK21` | Env var name from which Gradle resolves the JDK 21 toolchain. |
| `org.gradle.java.installations.auto-download` | `false` | Prevents Gradle from downloading JDKs automatically. |
| `org.gradle.java.installations.auto-detect` | `false` | Prevents Gradle from auto-detecting local JDKs. |

### Gradle Performance

| Property | Value | Description |
|---|---|---|
| `org.gradle.daemon` | `true` | Keeps Gradle daemon alive between builds. |
| `org.gradle.parallel` | `true` | Enables parallel project execution. |
| `org.gradle.caching` | `true` | Enables Gradle build cache. |
| `org.gradle.configuration-cache` | `true` | Enables configuration cache. Use `--no-configuration-cache` to bypass when debugging Gradle plugin changes. |
| `org.gradle.configuration-cache.problems` | `warn` | Logs configuration-cache problems as warnings rather than errors. |
| `org.gradle.configureondemand` | `true` | Configures only the projects required for a given task. |

### Android SDK Targets

| Property | Value | Description |
|---|---|---|
| `androidx.compileSdk` | `34` | Default compile SDK version for library modules. |
| `androidx.latestStableCompileSdk` | `36` | Latest stable SDK used in some modules. |
| `androidx.targetSdkVersion` | `36` | Target SDK version. |

### JetBrains Fork Properties

| Property | Value | Description |
|---|---|---|
| `androidx.studio.type` | `jetbrains-fork` | Identifies this checkout as the JetBrains fork. Affects task registration (e.g., disables the `:studio` Gradle task). |
| `jetbrains.androidx.web.tests.enableChrome` | `true` | Runs web tests in Chrome. |
| `jetbrains.androidx.web.tests.enableChromium` | `false` | Chromium disabled by default. |
| `jetbrains.androidx.web.tests.enableFirefox` | `false` | Firefox disabled by default. |
| `jetbrains.androidx.web.tests.enableSafari` | `false` | Safari disabled by default. |

### Artifact Redirection Versions

When a user depends on `org.jetbrains.*` artifacts for targets without a JetBrains-specific implementation, the build redirects to the corresponding `androidx.*` artifact. These version properties control which `androidx.*` version is used.

| Property | Default Value |
|---|---|
| `artifactRedirection.version.androidx.compose` | `1.12.0-alpha01` |
| `artifactRedirection.version.androidx.compose.material3` | `1.5.0-alpha18` |
| `artifactRedirection.version.androidx.lifecycle` | `2.11.0-beta01` |
| `artifactRedirection.version.androidx.navigation` | `2.10.0-alpha03` |
| `artifactRedirection.version.androidx.savedstate` | `1.5.0-alpha01` |
| `artifactRedirection.version.androidx.window` | `1.5.0` |
| `artifactRedirection.version.androidx.collection` | `1.5.0` |
| `artifactRedirection.version.androidx.annotation` | `1.9.1` |

### Kotlin / KMP Flags

| Property | Value | Description |
|---|---|---|
| `kotlin.native.ignoreDisabledTargets` | `true` | Suppresses warnings when Mac targets cannot be built on Linux. |
| `kotlin.native.enableKlibsCrossCompilation` | `false` | Cross-compilation of KLibs is disabled. |
| `kotlin.mpp.enableCInteropCommonization` | `true` | Enables CInterop commonization for KMP. |
| `kapt.use.k2` | `true` | Enables kapt with the K2 compiler. |
| `ksp.version.check` | `false` | Disables KSP version compatibility check. |

---

## Version Catalog (`gradle/libs.versions.toml`)

Key version pins used across all modules:

| Component | Version |
|---|---|
| Kotlin | `2.3.20` |
| Android Gradle Plugin (AGP) | `8.12.0` |
| Compose Compiler Plugin | `2.3.20` |
| Android Studio (required) | `2025.2.3.5` |
| Metalava | `1.0.0-alpha14` |
| AtomicFu | `0.28.0` |
| Skiko | `0.148.0` |
| Node.js | `20.9.0` |

The full catalog is at `compose-multiplatform-core/gradle/libs.versions.toml`.

---

## Publishing Gradle Properties

Pass these as `-P` flags on the Gradle command line when publishing to Maven Local. They are not stored in `gradle.properties`.

| Property | Description |
|---|---|
| `-Pjetbrains.publication.version.COMPOSE=<ver>` | Override Compose publication version (default: `0.0.0-SNAPSHOT`). |
| `-Pjetbrains.publication.version.LIFECYCLE=<ver>` | Override Lifecycle publication version. |
| `-Pjetbrains.publication.version.NAVIGATION=<ver>` | Override Navigation publication version. |
| `-Pjetbrains.publication.version.SAVEDSTATE=<ver>` | Override SavedState publication version. |
| `-Pjetbrains.publication.version.WINDOW=<ver>` | Override Window publication version. |
| `-Pcompose.platforms=all` | Target all platforms. Replace with a comma-separated list (e.g., `js,jvm,androidDebug,androidRelease,macosx64,ios`) to restrict targets. |
| `-Pjetbrains.publication.libraries=<groups>` | Comma-separated library groups to publish (default: all). |

---

## Per-Environment Overrides

There are no `.env.development` / `.env.production` files. Environment-specific behaviour is controlled by:

- **CI (GitHub Actions):** The `compose-multiplatform-core/.github/actions/setup-prerequisites/action.yml` composite action installs JDK 21 (`distribution: corretto`) and Android SDK automatically. No manual env export is needed in CI.
- **Local development:** Export `ANDROIDX_JDK21`, `JAVA_HOME`, and `ANDROID_SDK_ROOT` in your shell profile, and set `local.properties` `sdk.dir` for IDE use.
- **IDE (Android Studio / IntelliJ IDEA):** Set the Gradle JVM to JDK 21 under `Settings → Build, Execution, Deployment → Build Tools → Gradle`. The `MULTIPLATFORM.md` reference to JDK 17 is stale; the authoritative source is `gradle.properties` (`ANDROIDX_JDK21`).
- **Configuration cache bypass:** If Gradle configuration cache causes issues after plugin or settings changes, run any Gradle command with `--no-configuration-cache`.

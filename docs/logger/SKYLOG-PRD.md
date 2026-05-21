# Skylog — Product Requirements Document

| Field | Value |
|---|---|
| **Status** | **Draft 2026-05-21** — §12 D1–D8 resolved 2026-05-21 via `/plan-ceo-review` HOLD SCOPE mode; remaining acceptance criteria in §14 |
| **Owner** | _unassigned_ |
| **Companion plan** | [`SKYLOG-IMPLEMENTATION-PLAN.md`](./SKYLOG-IMPLEMENTATION-PLAN.md) |
| **Sibling reference** | [`../components/NUMBER-INPUT-PRD.md`](../components/NUMBER-INPUT-PRD.md) — same "standalone publishable library" shape |
| **Phase** | First KMP infrastructure library extracted from this skeleton |
| **Target sprint** | 1.5 sprints (~5 days, build order in companion plan §10) |
| **Document version** | 0.1 (2026-05-21) |

---

## 1. Problem Statement

1. **The skeleton has no shared logging primitive.** Today, Android code uses `android.util.Log`, iOS code uses `print` / `NSLog`, and `commonMain` is silent. There is no way to write `Log.i { ... }` once and have it land in the right console on every platform. Adding cross-cutting concerns later — crash reports, analytics breadcrumbs, in-app debug overlays — requires a logging seam that does not exist.
2. **Existing KMP loggers solve the engine, not the UI.** Kermit (Touchlab), kotlin-logging (oshai), Klogging, and Napier all ship robust write-everywhere engines with lazy lambdas and severity filtering. **None of them ship a beautiful in-app log viewer.** Every team that wants one rebuilds it from scratch — a ring buffer, a list view, severity colors, filters, search. That work is the unpaid tax on every KMP app that wants production-quality observability during dogfood and QA.
3. **The skeleton's UI strategy excludes a single shared viewer.** Per `architecture.md` and `CLAUDE.md` §4, Android uses Jetpack Compose and iOS uses SwiftUI — not Compose Multiplatform for the user-facing UI. A debug console must therefore render natively on each side while sharing a single source of log entries.
4. **Compose-specific debugging is a separate gap.** Recomposition counts and lifecycle events are the two most common things a Compose developer wants to log in development. There is no shared, tag-and-discard primitive for either; everyone writes their own `SideEffect { Log.d(...) }`.
5. **Distribution must match `:number-input`.** The previous standalone library (`:number-input`) shipped Android via Maven (AAR) and iOS via a pure-Swift SPM package. Consumers outside this repo need the same shape: drop in a Gradle dep on Android, add a Swift Package on iOS, no transitive Kotlin/Native toolchain required on iOS.

---

## 2. Goals & Success Metrics

| Goal | Measurement | Target |
|---|---|---|
| Single log API across Android, iOS, JVM | `Skylog.i { ... }` callable from `:shared-core`, `:androidApp`, `iosApp`, `:server` | Demo screen logs identical entries on all four targets |
| Lazy message evaluation | Block-form `Skylog.d { expensive() }` does **not** evaluate `expensive()` when severity is filtered out | Verified by `commonTest` with a probe lambda |
| In-app log console | A drop-in `LogConsoleScreen()` on Android (Compose) and `LogConsoleView()` on iOS (SwiftUI) | Renders ≥1000 entries at 60 fps; filter by severity + tag + free-text search |
| Compose helpers | `LogRecompositions(label)` and `LogLifecycle(label)` composables ship in `:skylog-ui` | Each verified by an instrumented Compose UI test |
| Floating debug overlay | A draggable `@Composable FloatingLogButton()` (Android) + `FloatingLogButton` SwiftUI view (iOS) that opens the console from anywhere | Manual verification on Android emulator + iOS simulator |
| External reusability | Skylog installable from Maven (`dev.viethung:skylog-core:0.1.0`) and SPM (`SkylogKit`) by an unrelated app | A bare Compose-only sample app and a bare SwiftUI sample app both build and log against the published artifacts |
| No architectural drift | Zero violations of CLAUDE.md §2 rules (no platform types in `commonMain`, single source of versions in `libs.versions.toml`, no business logic in `:*App` modules) | `./gradlew check` clean; manual audit of `commonMain` for `android.*` / `UIKit.*` / `androidx.compose.*` imports |

---

## 3. User Stories

- **US-01.** As a **shared-code developer**, I want to call `Skylog.i(tag = "Auth") { "User \$id signed in" }` from `commonMain`, so that the same line lands in Logcat on Android, OSLog on iOS, and stdout on JVM without me writing platform code.
- **US-02.** As a **performance-sensitive developer**, I want `Skylog.d { buildString { ... } }` to skip the lambda entirely when Debug is below the configured minimum severity, so that production builds pay zero cost for verbose tracing.
- **US-03.** As a **QA engineer dogfooding the app**, I want to tap a floating button in any screen and see a scrolling list of recent logs with severity colors and a search box, so that I can capture evidence of a bug without attaching a debugger.
- **US-04.** As a **Compose developer**, I want to drop `LogRecompositions("CartScreen")` at the top of a screen and see a counter tick in the log console every time it recomposes, so that I can diagnose recomposition storms without restarting the app.
- **US-05.** As an **iOS developer in a sibling app**, I want to `import SkylogKit` via Swift Package Manager and call `Skylog.i { "..." }` with no Kotlin/Native toolchain in my build, so that I can adopt Skylog incrementally without restructuring my project.
- **US-06.** As a **library author integrating Skylog**, I want to register a custom `LogWriter` that forwards entries to Crashlytics / Sentry / a backend endpoint, so that production logs reach our observability stack without touching application code.
- **US-07.** As a **future maintainer**, I want the public API surface to be stable, documented, and versioned via SemVer, so that bumping Skylog never silently breaks consumers.

---

## 4. Scope

### In scope

- **Core KMP engine** in `:skylog-core` (commonMain + androidMain + iosMain + jvmMain):
  - `Skylog` global facade with severity-keyed log calls (`v`, `d`, `i`, `w`, `e`, `a`).
  - `Logger` configurable instance — tag, minimum severity, writer list.
  - `LogWriter` abstract base + `isLoggable` filter.
  - `Severity` enum (Verbose, Debug, Info, Warn, Error, Assert).
  - `LogEntry` immutable data class with timestamp, severity, tag, message, throwable, optional structured fields.
  - Lazy message evaluation via `() -> String` (string-first per locked premise).
  - Optional structured fields builder: `Skylog.i(tag = "X") { "msg" }` or `Skylog.i(tag = "X", fields = { put("id", id) }) { "msg" }`.
- **Platform writers** (one per target):
  - `LogcatWriter` (androidMain) — wraps `android.util.Log`.
  - `OsLogWriter` (iosMain) — wraps `os_log` via Kotlin/Native cinterop or NSLog fallback.
  - `StdoutWriter` (jvmMain) — `println` with severity prefix, ANSI color when TTY.
  - `platformDefaultWriter()` — `expect`/`actual` factory returning the right default per target.
- **In-memory writer** in `:skylog-core`:
  - `InMemoryLogWriter(capacity: Int = 1000)` — ring buffer, exposes `StateFlow<List<LogEntry>>` for UI consumption.
  - Thread-safe via a single coroutine-confined mutex; reads do not block writes.
- **Android Compose UI** in `:skylog-ui` (com.android.library, Compose):
  - `@Composable LogConsoleScreen(buffer: InMemoryLogWriter)` — list, filter chips (severity), tag dropdown, free-text search, copy/share row, dark-aware via `DesignTokens`.
  - `@Composable FloatingLogButton(onOpen: () -> Unit)` — draggable FAB.
  - `@Composable LogRecompositions(label: String)` — `SideEffect` increments a counter and logs every Nth (configurable) recomposition.
  - `@Composable LogLifecycle(label: String)` — `DisposableEffect` logs enter/exit.
- **iOS SwiftUI UI** in `swift-package/SkylogKit`:
  - Pure-Swift port of the engine (mirrors the Kotlin API one-for-one, like `NumberInputKit`).
  - `LogConsoleView(buffer: InMemoryLogWriter)` — SwiftUI list with severity colors, filters, search.
  - `FloatingLogButton` — draggable overlay view.
  - SwiftUI helpers do **not** include recomposition equivalents (SwiftUI doesn't expose recomposition counts the same way) — covered explicitly in §12 (open decision) and §13 (out of scope alternatives).
- **Showcase wiring** in `:androidApp` (Compose) and `:iosApp` (SwiftUI):
  - A "Logger" entry in the existing showcase index that opens the in-app console.
  - Sample log calls (one per severity, one with throwable, one with structured fields) emitted on screen entry.
- **Distribution**:
  - Maven Central / GitHub Packages: `dev.viethung:skylog-core:0.1.0` (KMP publication), `dev.viethung:skylog-ui:0.1.0` (Android Compose).
  - SPM: `SkylogKit` (pure Swift, iOS 16+) wrapping the engine + SwiftUI views — no Kotlin/Native dependency for pure-iOS consumers (mirrors `NumberInputKit`).
  - Sample integration app docs in the package README.
- **Tests**:
  - `commonTest` covering severity filtering, lazy lambda non-evaluation, writer composition, ring buffer semantics, structured field roundtrip.
  - Android Compose UI tests for `LogConsoleScreen` (filter, search, copy).
  - XCTest for the Swift port (mirror of `commonTest` coverage).

### Out of scope (see §13)

- **Remote log ingestion / backend service** (Loki, Datadog, custom HTTP sink). The `LogWriter` extension point makes this trivial to add downstream; we ship no built-in network writer.
- **Crash reporting integration** (Crashlytics, Sentry). Same reasoning — consumers register their own writer.
- **Structured logging as the primary surface.** String-first is the locked premise (§12 D2 resolved). Structured fields are supported but secondary.
- **Coroutine-context propagation** (`withLogContext("requestId" to id)`). Useful but adds API surface; deferred to v0.2.
- **Web / wasm / Native CLI targets.** Locked premise (§12 D3 resolved): Android + iOS + JVM only for v1.
- **Persistent on-device log storage.** Ring buffer is in-memory only; if a user wants persistence they can register a writer that writes to disk.
- **Compose Multiplatform iOS UI.** The console renders SwiftUI on iOS, not Compose iOS — matches this skeleton's "native UI per platform" rule.
- **SwiftUI recomposition counter equivalent.** SwiftUI doesn't expose render counts at the granularity Compose does; building a heuristic equivalent is a separate project.
- **Log formatting plugins** (JSON, logfmt, ECS schema). The `LogEntry → String` step is internal to each writer; we don't expose a pluggable formatter in v1.

---

## 5. Functional Requirements

| ID | Requirement | Plan ref |
|---|---|---|
| **FR-01** | The library SHALL expose a global facade `Skylog` with methods `v`, `d`, `i`, `w`, `e`, `a`, each accepting an optional `tag: String`, optional `throwable: Throwable`, and a trailing `message: () -> String` lambda. | Plan §4.1 |
| **FR-02** | The `message` lambda SHALL NOT be evaluated when the configured minimum severity is greater than the call's severity, nor when no registered `LogWriter` returns `true` from `isLoggable(tag, severity)`. | Plan §4.2 |
| **FR-03** | The library SHALL expose a `Logger` class for callers that need a non-global, tag-bound, writer-bound instance. The global `Skylog` SHALL be implemented as a singleton `Logger`. | Plan §4.3 |
| **FR-04** | The library SHALL ship a `Severity` enum with values `Verbose`, `Debug`, `Info`, `Warn`, `Error`, `Assert` (ordered least to most severe). The enum SHALL be comparable. | Plan §4.4 |
| **FR-05** | The library SHALL ship a `LogEntry` immutable data class containing `timestamp: Instant`, `severity: Severity`, `tag: String`, `message: String` (already evaluated), `throwable: Throwable?`, `fields: Map<String, String>?`. | Plan §4.5 |
| **FR-06** | The library SHALL ship platform-default writers (`LogcatWriter` on Android, `OsLogWriter` on iOS, `StdoutWriter` on JVM) and an `expect fun platformDefaultWriter(): LogWriter` factory that returns them. | Plan §4.6 |
| **FR-07** | The library SHALL ship an `InMemoryLogWriter(capacity)` that retains the most recent `capacity` entries (default 1000) and exposes `entries: StateFlow<List<LogEntry>>`. Writes SHALL be O(1); reads SHALL be lock-free for `StateFlow` consumers. | Plan §4.7 |
| **FR-08** | The library SHALL allow registering multiple writers via `Skylog.configure { writers += writer }` (or equivalent). Each log call SHALL fan out to all registered writers in registration order. | Plan §4.8 |
| **FR-09** | The library SHALL expose a structured-fields entry point: `Skylog.i(tag = "X", fields = mapOf("id" to id)) { "msg" }`. Fields SHALL be passed through to writers via `LogEntry.fields`. | Plan §4.9 |
| **FR-10** | The `:skylog-ui` module SHALL expose `@Composable LogConsoleScreen(buffer: InMemoryLogWriter, modifier: Modifier = Modifier)` rendering a virtualized list of entries with severity color, tag, time, message, and optional throwable expansion. | Plan §5.1 |
| **FR-11** | `LogConsoleScreen` SHALL support filtering by minimum severity (chip row), by tag (dropdown), and by free-text search (matches message + tag). All filters compose with AND semantics. | Plan §5.2 |
| **FR-12** | `LogConsoleScreen` SHALL provide a "Copy" action per row and a "Share all" action for the current filtered view, producing plain-text output suitable for paste into a bug report. | Plan §5.3 |
| **FR-13** | The `:skylog-ui` module SHALL expose `@Composable FloatingLogButton(onOpen: () -> Unit, modifier: Modifier = Modifier)` — a draggable FAB that calls `onOpen` on tap. | Plan §5.4 |
| **FR-14** | The `:skylog-ui` module SHALL expose `@Composable LogRecompositions(label: String, everyN: Int = 1)` that logs at `Debug` severity every Nth recomposition, using `SideEffect`. | Plan §5.5 |
| **FR-15** | The `:skylog-ui` module SHALL expose `@Composable LogLifecycle(label: String)` that logs `Debug` on first composition and on disposal, using `DisposableEffect`. | Plan §5.6 |
| **FR-16** | The Swift package `SkylogKit` SHALL expose `Skylog.v/d/i/w/e/a(tag:throwable:_:)` (variadic-trailing-closure form) mirroring the Kotlin API. | Plan §6.1 |
| **FR-17** | `SkylogKit` SHALL expose `LogConsoleView` and `FloatingLogButton` as SwiftUI views with the same filtering and search semantics as the Compose equivalents. | Plan §6.2 |
| **FR-18** | `SkylogKit` SHALL be a pure-Swift package — no Kotlin/Native framework dependency, mirroring the `NumberInputKit` distribution choice. | Plan §6.3 |
| **FR-19** | The library SHALL respect platform design tokens via `shared-core/.../theme/DesignTokens.kt` on Android, and an equivalent `SkylogTheme` struct on iOS — no hardcoded colors in UI code. | Plan §5.7, §6.4 |
| **FR-20** | The publication for `:skylog-core` SHALL produce: an Android AAR, KMP klibs for `iosArm64`, `iosX64`, `iosSimulatorArm64`, and a JVM jar — all under group `dev.viethung`, artifact `skylog-core`, version `0.1.0-SNAPSHOT`. v0.1 publishes to maven-local + GitHub Packages only; Maven Central publication is deferred to v0.2 (Mega Plan Review §9 F-9.1). | Plan §7.1 |

---

## 6. Non-Functional Requirements

| ID | Requirement | Rationale |
|---|---|---|
| **NFR-01** | Per-call overhead when log is filtered out SHALL be < 100 ns on a typical mobile CPU (single severity comparison + one branch). | Lazy lambdas are pointless if the entry path is slow. |
| **NFR-02** | The library SHALL have **zero runtime dependencies** other than the Kotlin standard library and `kotlinx.coroutines` (for `StateFlow`). | "Like Kermit, our style" — keep the footprint tiny. |
| **NFR-03** | The library SHALL be thread-safe — concurrent calls from multiple threads SHALL not lose or corrupt entries, nor cause writer-side races. | Logging is fan-in by definition. |
| **NFR-04** | `InMemoryLogWriter` at capacity 1000 SHALL consume < 200 KB of heap (assuming average message length of 80 chars). | Debug overlays should not move the needle on app memory. |
| **NFR-05** | Public API SHALL be source-compatible across all 0.x.y patch versions and binary-compatible across 0.0.x patch versions (KotlinX binary-validator enforced). | Consumers need confidence. |
| **NFR-06** | All public symbols SHALL have KDoc / DocC (Swift) comments. | Library, not application code. |

---

## 7. Public API Surface (Sketch)

> Final signatures locked in the companion plan §4 (Kotlin) and §6 (Swift). This is a directional sketch — copy-edits expected during plan sign-off.

### Kotlin (`dev.viethung.skylog`)

```kotlin
// Global facade
object Skylog {
    fun v(tag: String? = null, throwable: Throwable? = null, message: () -> String)
    fun d(tag: String? = null, throwable: Throwable? = null, message: () -> String)
    fun i(tag: String? = null, throwable: Throwable? = null, message: () -> String)
    fun w(tag: String? = null, throwable: Throwable? = null, message: () -> String)
    fun e(tag: String? = null, throwable: Throwable? = null, message: () -> String)
    fun a(tag: String? = null, throwable: Throwable? = null, message: () -> String)

    // Structured fields entry point (rarely used; secondary surface)
    fun i(tag: String? = null, fields: Map<String, String>, throwable: Throwable? = null, message: () -> String)
    // (and v/d/w/e/a equivalents)

    fun configure(block: SkylogConfig.() -> Unit)
    fun minSeverity(severity: Severity)
}

class Logger(val config: SkylogConfig) { /* same surface as Skylog */ }

enum class Severity { Verbose, Debug, Info, Warn, Error, Assert }

data class LogEntry(
    val timestamp: Instant,
    val severity: Severity,
    val tag: String,
    val message: String,
    val throwable: Throwable?,
    val fields: Map<String, String>?,
)

abstract class LogWriter {
    abstract fun log(entry: LogEntry)
    open fun isLoggable(tag: String, severity: Severity): Boolean = true
}

class SkylogConfig {
    var minSeverity: Severity = Severity.Verbose
    val writers: MutableList<LogWriter> = mutableListOf()
}

// Built-in writers
class InMemoryLogWriter(capacity: Int = 1000) : LogWriter() {
    val entries: StateFlow<List<LogEntry>>
}

expect fun platformDefaultWriter(): LogWriter
// androidMain → LogcatWriter
// iosMain     → OsLogWriter
// jvmMain     → StdoutWriter
```

### Swift (`SkylogKit`)

```swift
public enum Skylog {
    public static func v(tag: String? = nil, throwable: Error? = nil, _ message: () -> String)
    public static func d(tag: String? = nil, throwable: Error? = nil, _ message: () -> String)
    public static func i(tag: String? = nil, throwable: Error? = nil, _ message: () -> String)
    public static func w(tag: String? = nil, throwable: Error? = nil, _ message: () -> String)
    public static func e(tag: String? = nil, throwable: Error? = nil, _ message: () -> String)
    public static func a(tag: String? = nil, throwable: Error? = nil, _ message: () -> String)

    public static func configure(_ block: (inout SkylogConfig) -> Void)
}

public enum Severity: Int, Comparable { case verbose, debug, info, warn, error, assert }

public struct LogEntry {
    public let timestamp: Date
    public let severity: Severity
    public let tag: String
    public let message: String
    public let throwable: Error?
    public let fields: [String: String]?
}

public protocol LogWriter {
    func log(_ entry: LogEntry)
    func isLoggable(tag: String, severity: Severity) -> Bool
}

public final class InMemoryLogWriter: LogWriter, ObservableObject {
    @Published public private(set) var entries: [LogEntry]
}
```

### Compose UI (`dev.viethung.skylog.ui`)

```kotlin
@Composable fun LogConsoleScreen(buffer: InMemoryLogWriter, modifier: Modifier = Modifier)
@Composable fun FloatingLogButton(onOpen: () -> Unit, modifier: Modifier = Modifier)
@Composable fun LogRecompositions(label: String, everyN: Int = 1)
@Composable fun LogLifecycle(label: String)
```

### SwiftUI UI (`SkylogKit`)

```swift
public struct LogConsoleView: View { public init(buffer: InMemoryLogWriter) }
public struct FloatingLogButton: View { public init(onOpen: @escaping () -> Void) }
// No LogRecompositions equivalent — see §12 D5.
```

---

## 8. Compose / SwiftUI Console — UI Spec (Brief)

A separate `SKYLOG-UI.md` may follow for visual detail. For this PRD, the contract is:

- **Row layout (top→bottom):** severity color stripe (4 dp wide, left edge) • timestamp (HH:mm:ss.SSS, monospace, small) • tag (small caps, semi-bold) • message (body, 2-line ellipsis, expandable on tap) • throwable indicator (chevron, expands to show stack trace).
- **Severity colors** sourced from `DesignTokens` (Android) and `SkylogTheme` (iOS):
  - Verbose: dim gray
  - Debug: blue
  - Info: green
  - Warn: yellow / amber
  - Error: red
  - Assert: magenta
- **Empty state:** two variants. When the buffer is empty: "No logs yet" + "Try emitting a log with Skylog.i(\"...\")" hint. When the buffer is populated but the active filter returns zero matches: "No logs match the current filter" (no emit hint — emitting will not unstick the filter).
- **Header bar:** severity filter chips (min-severity model: tapping `Warn` shows Warn + Error + Assert; mirrors Logcat / OSLog / pino / winston conventions) • tag dropdown • search field (debounced 200 ms).
- **Footer actions:** "Share filtered logs as text", "Clear buffer" (with undo snackbar, 5 s).
- **Floating button:** 56 dp circular FAB, severity-tinted by highest unread entry, badge with unread count.
- **Performance:** list virtualization mandatory; render budget 8 ms / frame on a 60 Hz device with 1000 entries.

---

## 9. Module & Repository Structure (locked)

```
skeleton/
├── skylog-core/                      [NEW — KMP library]
│   ├── build.gradle.kts
│   └── src/
│       ├── commonMain/kotlin/dev/viethung/skylog/...
│       ├── androidMain/kotlin/dev/viethung/skylog/...    (LogcatWriter)
│       ├── iosMain/kotlin/dev/viethung/skylog/...        (OsLogWriter)
│       ├── jvmMain/kotlin/dev/viethung/skylog/...        (StdoutWriter)
│       └── commonTest/kotlin/dev/viethung/skylog/...
│
├── skylog-ui/                        [NEW — Android Compose library]
│   ├── build.gradle.kts
│   └── src/
│       ├── main/kotlin/dev/viethung/skylog/ui/...
│       └── androidTest/kotlin/dev/viethung/skylog/ui/... (instrumented tests)
│
├── swift-package/
│   └── SkylogKit/                    [NEW — pure Swift, mirrors NumberInputKit]
│       ├── Package.swift
│       ├── Sources/SkylogKit/
│       │   ├── Skylog.swift          (engine port)
│       │   ├── Severity.swift
│       │   ├── LogWriter.swift
│       │   ├── InMemoryLogWriter.swift
│       │   ├── platform/OsLogWriter.swift
│       │   ├── views/LogConsoleView.swift
│       │   ├── views/FloatingLogButton.swift
│       │   └── views/SkylogTheme.swift
│       └── Tests/SkylogKitTests/...
│
├── settings.gradle.kts               [MODIFY — add :skylog-core, :skylog-ui]
├── gradle/libs.versions.toml         [MODIFY — add publish coords if needed]
├── androidApp/                       [MODIFY — wire showcase entry]
└── iosApp/                           [MODIFY — wire showcase entry]
```

---

## 10. Distribution

| Target | Mechanism | Coords | Notes |
|---|---|---|---|
| Maven (Android, JVM, KMP iOS klibs) | Maven Central via `vanniktech-publish` | `dev.viethung:skylog-core:0.1.0` | KMP publication — Android AAR + JVM jar + iOS klibs |
| Maven (Android Compose UI) | same | `dev.viethung:skylog-ui:0.1.0` | Android-only AAR |
| SPM (iOS) | Local + GitHub SemVer tag | `SkylogKit` | Pure Swift, no Kotlin/Native dep — mirrors `NumberInputKit` |

Version bump rules: 0.x bumps allowed for source-incompatible changes during alpha; binary compat enforced from 1.0.

---

## 11. Architecture (Cross-Reference)

```
   commonMain (Kotlin)                  pure Swift (SkylogKit)
   ┌──────────────────┐                ┌──────────────────┐
   │ Skylog facade    │                │ Skylog facade    │
   │ Logger           │                │ Logger           │
   │ Severity         │                │ Severity         │
   │ LogEntry         │                │ LogEntry         │
   │ LogWriter (abs)  │                │ LogWriter        │
   │ InMemoryLogWriter│                │ InMemoryLogWriter│
   └──────────────────┘                └──────────────────┘
        │                                      │
   ┌─────┴─────┬──────────┐              ┌─────┴───────┐
   │           │          │              │             │
   androidMain iosMain   jvmMain         OsLogWriter   SwiftUI
   LogcatW.   OsLogW.   StdoutW.                       LogConsoleView
                                                       FloatingLogButton
```

**Direction of dependency:** UI → in-memory buffer → core API. UI modules never reach into platform writers; they consume the `StateFlow<List<LogEntry>>` only.

---

## 12. Decisions — resolved 2026-05-21 via `/plan-ceo-review`

| # | Question | Resolution | Rationale |
|---|---|---|---|
| **D1** | iOS engine: pure Swift port or KMP framework via SPM XCFramework? | **Pure Swift port** (status quo) | User confirmed during CEO review — accepts two-engine maintenance burden in exchange for zero Kotlin/Native dep on iOS consumers. Mirrors `NumberInputKit` precedent. Drift risk documented in §13 R-01. |
| **D2** | Coroutine-context-aware logging in v1? | **Deferred to v0.2** | Adds API surface + the wider question of Task-local equivalence in the Swift port. Not blocking v0.1 demand. |
| **D3** | `LogConsoleScreen` empty-state: ship asset or accept a slot? | **Default implementation, no shipped asset.** A future overload may accept a slot. | Keeps library headless in v0.1. No design work / licensing for an illustration. See Plan §5.1.a. |
| **D4** | `InMemoryLogWriter` disk persistence? | **In-memory only.** | Persistence would require I/O, sandbox handling, and a `FilesystemLogWriter`. Consumers who need it register their own writer. Out of scope. |
| **D5** | SwiftUI parallel of `LogRecompositions`? | **Do not ship.** | SwiftUI does not expose render counts at Compose's granularity. Any heuristic would mislead. Shipping nothing is the honest answer. |
| **D6** | `LogcatWriter` tag truncation on API <26? | **Silent truncation to 23 chars on API <26; full tag on API ≥26.** | Prevents `IllegalArgumentException` on older devices without forcing consumers to think about it. Documented in `LogcatWriter` KDoc. |
| **D7** | Default min severity per build type? | **Debug builds: `Verbose`. Release builds: `Info`.** Surfaced via `Skylog.configure { minSeverity = if (BuildConfig.DEBUG) Verbose else Info }` — consumer wires the flag. | Verbose in dev is the right default for a debug library; Info in release keeps Logcat / OSLog noise low. |
| **D8** | Package namespace: `dev.viethung.skylog` or open-source rename later? | **`dev.viethung.skylog` for v0.1.** Revisit pre-1.0 if we open-source under a separate org. | Rename pre-1.0 is a 1-hour mechanical change; making the call now is premature. Matches `:number-input` convention. |

---

## 13. Risks & Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Two-engine drift (Kotlin vs Swift port diverge over time) | Medium | High | Test contracts mirror across `commonTest` and `SkylogKitTests` — same scenarios, same assertions. Treat divergence as a bug. |
| R-02 | `InMemoryLogWriter` becomes a memory hot spot if a consumer cranks capacity to 10k+ | Low | Medium | Document the 200 KB / 1000-entries baseline; cap default at 1000; let consumers opt-in higher. |
| R-03 | `os_log` on iOS doesn't honor the message lambda the way Logcat does (it expects a format string for privacy redaction) | Medium | Medium | Default `OsLogWriter` evaluates the lambda and passes the result as `"%{public}s"` — explicit, no redaction. Document that consumers needing redaction should subclass. |
| R-04 | Compose UI tests for floating button drag interaction are flaky in CI | Medium | Low | Cover the state machine via Compose tests, but verify drag visually in a manual smoke test for v1. |
| R-05 | Compose `LogRecompositions(label)` itself causes recompositions and pollutes the very signal it's measuring | Medium | Medium | Use `remember { mutableStateOf(0) }` + `SideEffect` carefully; document the known minor inflation and provide a recipe for skipping it in release. |
| R-06 | Maven Central publish flow fails for KMP iOS klibs (vanniktech-publish corner cases) | Low | Medium | Reference the existing `:shared-core` publish config; verify locally via `publishToMavenLocal` before tagging. |
| R-07 | Swift port can't replicate Kotlin's `() -> String` laziness without `@autoclosure` boilerplate at every callsite | Low | Low | Mark message params `@autoclosure () -> String` in Swift — semantics match. |

---

## 14. Acceptance Criteria (PRD sign-off)

PRD is **approved** when:

- [x] §12 decisions D1–D8 resolved (closed 2026-05-21).
- [ ] Plan §10 build order references each FR-NN in this PRD.
- [ ] Sample log calls (one per severity, plus structured-fields + throwable variants) round-trip through `InMemoryLogWriter` and `platformDefaultWriter` on Android, iOS simulator, and JVM in manual smoke.
- [ ] `LogConsoleScreen` renders, filters, and searches on a sample of ≥100 entries in `:androidApp`.
- [ ] `LogConsoleView` renders the equivalent in `:iosApp`.
- [ ] No `android.*` / `androidx.*` / `UIKit.*` / `SwiftUI.*` imports leak into `commonMain`.
- [ ] `./gradlew check` is clean; `:skylog-core` and `:skylog-ui` participate in CI.
- [ ] Mega Plan Review findings (this PRD's §13 + Plan §12) all closed via approved patches.

When all boxes are ticked, flip status to **Approved YYYY-MM-DD** and execute the plan.

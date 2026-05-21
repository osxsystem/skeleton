# Skylog — Technical Implementation Plan

**Status:** **Draft 2026-05-21** — pending PRD §12 sign-off
**Owner:** _to be assigned_
**Audience:** Engineer (or agent) implementing Skylog v0.1
**Companion docs:** [`SKYLOG-PRD.md`](./SKYLOG-PRD.md), [`../../CLAUDE.md`](../../CLAUDE.md), [`../../architecture.md`](../../architecture.md), sibling: [`../components/NUMBER-INPUT-IMPLEMENTATION-PLAN.md`](../components/NUMBER-INPUT-IMPLEMENTATION-PLAN.md)

---

## Related Docs (READ before implementing)

- **PRD:** [`SKYLOG-PRD.md`](./SKYLOG-PRD.md) — requirements, FR/NFR, open decisions §12, acceptance criteria
- **Style:** [`CLAUDE.md`](../../CLAUDE.md) §2 (coding standards), §3 (architecture), §4 (platform bindings)
- **Sibling pattern:** [`../components/NUMBER-INPUT-IMPLEMENTATION-PLAN.md`](../components/NUMBER-INPUT-IMPLEMENTATION-PLAN.md) — standalone library shape this plan mirrors

---

## 1. Goal

Build a publishable KMP logging library in one repo, two modules + one Swift package:

1. **Engine** in `:skylog-core` (KMP: Android, iOS, JVM) — `Skylog` facade, `Logger`, `Severity`, `LogEntry`, `LogWriter`, `InMemoryLogWriter`, platform default writers.
2. **Compose UI** in `:skylog-ui` (Android-only Compose library) — `LogConsoleScreen`, `FloatingLogButton`, `LogRecompositions`, `LogLifecycle`.
3. **Swift parity** in `swift-package/SkylogKit` — pure-Swift port of the engine + SwiftUI `LogConsoleView` and `FloatingLogButton`. Mirrors `NumberInputKit` shape.
4. **Showcase** wired into `:androidApp` (Compose) and `:iosApp` (SwiftUI).
5. **Tests**: `commonTest` for the engine; Compose UI tests for the console; XCTest for the Swift port.

This document tells the implementer **what to build, in what order, where it lives, and why**. It does NOT contain final source — it contains contracts, signatures, and step-by-step gates.

---

## 2. Why This Plan Looks the Way It Does

Three constraints shape every decision below.

1. **CLAUDE.md §2 forbids platform types in `commonMain`.** The core module must not import `android.*`, `androidx.*`, `UIKit.*`, or any Compose runtime. Everything platform-touching lives in `androidMain`, `iosMain`, `jvmMain` — or in `:skylog-ui`, which is Android-only.
2. **The skeleton uses native UI per platform (Compose on Android, SwiftUI on iOS).** Compose Multiplatform is not the consumer UI strategy. The console must therefore exist as two implementations sharing a single source of log entries.
3. **`:number-input` set the precedent for standalone publishable libraries.** That extract specifically dropped KMP for the Swift side (pure Swift, no Kotlin/Native dependency on consumers). Skylog follows the same shape per PRD §12 D1 default.

Mental model:

```
            ┌─────────────────────────────────────┐
            │   :skylog-core (KMP)                │
            │   commonMain / androidMain /        │
            │   iosMain / jvmMain                 │
            └─────────────────────────────────────┘
                         │
              ┌──────────┴───────────┐
              ▼                      ▼
    ┌──────────────────┐    (iOS does NOT consume Kotlin/Native)
    │ :skylog-ui       │    ┌─────────────────────────────┐
    │ Android Compose  │    │ swift-package/SkylogKit     │
    │ LogConsoleScreen │    │ Pure Swift port + SwiftUI   │
    │ FloatingLogButton│    │ LogConsoleView              │
    │ LogRecompositions│    │ FloatingLogButton           │
    │ LogLifecycle     │    └─────────────────────────────┘
    └──────────────────┘
              │
              ▼
        :androidApp                        :iosApp
        (Compose Showcase)                 (SwiftUI Showcase)
```

---

## 3. Where Each Piece Lives

```
skeleton/
├── skylog-core/
│   ├── build.gradle.kts                                                                     [NEW — §7.1]
│   └── src/
│       ├── commonMain/kotlin/dev/viethung/skylog/
│       │   ├── Skylog.kt                       (global facade)                              [NEW — §4.1]
│       │   ├── Logger.kt                       (instance API)                               [NEW — §4.3]
│       │   ├── Severity.kt                                                                  [NEW — §4.4]
│       │   ├── LogEntry.kt                                                                  [NEW — §4.5]
│       │   ├── LogWriter.kt                    (abstract base)                              [NEW — §4.2]
│       │   ├── SkylogConfig.kt                                                              [NEW — §4.8]
│       │   ├── writers/InMemoryLogWriter.kt                                                 [NEW — §4.7]
│       │   └── platform/PlatformDefaultWriter.kt (expect)                                   [NEW — §4.6]
│       ├── androidMain/kotlin/dev/viethung/skylog/platform/
│       │   ├── PlatformDefaultWriter.android.kt (actual → LogcatWriter)                     [NEW — §4.6]
│       │   └── LogcatWriter.kt                                                              [NEW — §4.6]
│       ├── iosMain/kotlin/dev/viethung/skylog/platform/
│       │   ├── PlatformDefaultWriter.ios.kt (actual → OsLogWriter)                          [NEW — §4.6]
│       │   └── OsLogWriter.kt                                                               [NEW — §4.6]
│       ├── jvmMain/kotlin/dev/viethung/skylog/platform/
│       │   ├── PlatformDefaultWriter.jvm.kt (actual → StdoutWriter)                         [NEW — §4.6]
│       │   └── StdoutWriter.kt                                                              [NEW — §4.6]
│       └── commonTest/kotlin/dev/viethung/skylog/
│           ├── SkylogTest.kt                  (lazy lambda + severity filter)               [NEW — §9.1]
│           ├── InMemoryLogWriterTest.kt       (ring buffer + StateFlow)                     [NEW — §9.2]
│           ├── LogWriterCompositionTest.kt    (fan-out + isLoggable)                        [NEW — §9.3]
│           └── SeverityTest.kt                (ordering)                                    [NEW — §9.4]
│
├── skylog-ui/
│   ├── build.gradle.kts                                                                     [NEW — §7.2]
│   └── src/
│       ├── main/kotlin/dev/viethung/skylog/ui/
│       │   ├── LogConsoleScreen.kt                                                          [NEW — §5.1]
│       │   ├── components/LogRow.kt                                                         [NEW — §5.1]
│       │   ├── components/SeverityFilterChips.kt                                            [NEW — §5.2]
│       │   ├── components/TagDropdown.kt                                                    [NEW — §5.2]
│       │   ├── components/SearchField.kt                                                    [NEW — §5.2]
│       │   ├── components/FloatingLogButton.kt                                              [NEW — §5.4]
│       │   ├── compose/LogRecompositions.kt                                                 [NEW — §5.5]
│       │   ├── compose/LogLifecycle.kt                                                      [NEW — §5.6]
│       │   └── theme/SkylogColors.kt           (maps Severity → DesignTokens)               [NEW — §5.7]
│       └── androidTest/kotlin/dev/viethung/skylog/ui/
│           ├── LogConsoleScreenTest.kt        (filter, search, copy)                        [NEW — §9.5]
│           ├── FloatingLogButtonTest.kt       (drag, tap, badge)                            [NEW — §9.5]
│           └── LogRecompositionsTest.kt                                                     [NEW — §9.5]
│
├── swift-package/SkylogKit/                                                                 [NEW — §6, §7.3]
│   ├── Package.swift
│   ├── Sources/SkylogKit/
│   │   ├── Skylog.swift                       (global facade)                               [NEW — §6.1]
│   │   ├── Logger.swift                                                                     [NEW — §6.1]
│   │   ├── Severity.swift                                                                   [NEW — §6.1]
│   │   ├── LogEntry.swift                                                                   [NEW — §6.1]
│   │   ├── LogWriter.swift                                                                  [NEW — §6.1]
│   │   ├── SkylogConfig.swift                                                               [NEW — §6.1]
│   │   ├── writers/InMemoryLogWriter.swift                                                  [NEW — §6.1]
│   │   ├── writers/OsLogWriter.swift                                                        [NEW — §6.1]
│   │   ├── views/LogConsoleView.swift                                                       [NEW — §6.2]
│   │   ├── views/FloatingLogButton.swift                                                    [NEW — §6.2]
│   │   ├── views/SkylogTheme.swift            (environment + modifier)                      [NEW — §6.4]
│   │   └── views/components/LogRowView.swift                                                [NEW — §6.2]
│   └── Tests/SkylogKitTests/
│       ├── SkylogTests.swift                  (mirror of SkylogTest.kt)                     [NEW — §9.6]
│       ├── InMemoryLogWriterTests.swift                                                     [NEW — §9.6]
│       └── LogWriterCompositionTests.swift                                                  [NEW — §9.6]
│
├── settings.gradle.kts                          [MODIFY — add :skylog-core, :skylog-ui]     §7.4
├── gradle/libs.versions.toml                    [MODIFY — no new versions expected]         §7.5
├── androidApp/                                  [MODIFY — wire showcase entry]              §8.1
├── iosApp/                                      [MODIFY — wire showcase entry]              §8.2
└── shared-app/                                  [MODIFY — sample log calls (optional)]      §8.3
```

> **Why `swift-package/SkylogKit/` at repo root, not under `iosApp/`?** Matches the existing `swift-package/NumberInput/` layout. `Package.swift` resolves paths relative to itself; placing the package at the repo root keeps it a sibling of `androidApp/`, `iosApp/`, and the Gradle modules — consistent with how this repo treats top-level concerns.

---

## 4. `:skylog-core` — Detailed Contracts

### 4.1 `Skylog.kt` (commonMain)

```kotlin
package dev.viethung.skylog

/**
 * Global facade. Implemented as a singleton [Logger] configured via [configure].
 * See SKYLOG-PRD.md §7.
 *
 * For non-global instances (different tag / writer set), use [Logger] directly.
 */
object Skylog {
    private val default: Logger = Logger(SkylogConfig().apply { writers += platformDefaultWriter() })

    fun v(tag: String? = null, throwable: Throwable? = null, message: () -> String) = default.v(tag, throwable, message)
    fun d(tag: String? = null, throwable: Throwable? = null, message: () -> String) = default.d(tag, throwable, message)
    fun i(tag: String? = null, throwable: Throwable? = null, message: () -> String) = default.i(tag, throwable, message)
    fun w(tag: String? = null, throwable: Throwable? = null, message: () -> String) = default.w(tag, throwable, message)
    fun e(tag: String? = null, throwable: Throwable? = null, message: () -> String) = default.e(tag, throwable, message)
    fun a(tag: String? = null, throwable: Throwable? = null, message: () -> String) = default.a(tag, throwable, message)

    // Structured fields (secondary surface)
    fun i(tag: String? = null, fields: Map<String, String>, throwable: Throwable? = null, message: () -> String) =
        default.i(tag, fields, throwable, message)
    // (and v/d/w/e/a equivalents)

    fun configure(block: SkylogConfig.() -> Unit) = default.configure(block)
    fun minSeverity(severity: Severity) = configure { minSeverity = severity }
}
```

**Contract:**
- All log calls are non-suspend; they fan out to writers synchronously on the caller's thread.
- `message: () -> String` is **not evaluated** when `severity < config.minSeverity` (per FR-02).
- `tag = null` falls back to writer-default behavior (Logcat → calling class via stack walk on Android; OSLog → `subsystem` / `category` defaults on iOS).
- **Initialization contract:** the `default = Logger(...)` field is initialized eagerly on first access to `Skylog` (Kotlin `object` semantics). This triggers `platformDefaultWriter()` once per process. Safe under Kotlin 2.x's new memory model (used by this project) — `Logger.config` is `@Volatile` and mutated under `synchronized(lock)` (§4.3). **Test setup recipe:** tests that need to swap in a fake writer must call `Skylog.configure { writers.clear(); writers += fakeWriter }` BEFORE the first `Skylog.v/d/i/w/e/a/configure` call, OR construct a fresh `Logger(SkylogConfig().apply { writers += fakeWriter })` directly instead of using `Skylog`.

### 4.2 `LogWriter.kt` (commonMain)

```kotlin
package dev.viethung.skylog

abstract class LogWriter {
    abstract fun log(entry: LogEntry)
    open fun isLoggable(tag: String, severity: Severity): Boolean = true
}
```

**Contract:**
- `log(entry)` is called with a fully-evaluated message string. The `() -> String` lambda has already been invoked by the time the writer sees the entry.
- `isLoggable` short-circuits both the lambda evaluation and the `log` call when **all** registered writers return `false` (per FR-02). This is the fast path that delivers NFR-01.

### 4.3 `Logger.kt` (commonMain)

```kotlin
package dev.viethung.skylog

import kotlinx.atomicfu.locks.SynchronizedObject
import kotlinx.atomicfu.locks.synchronized
import kotlinx.datetime.Clock

class Logger internal constructor(initialConfig: SkylogConfig) {
    private val lock = SynchronizedObject()
    @Volatile internal var config: SkylogConfig = initialConfig
        private set

    fun v(tag: String? = null, throwable: Throwable? = null, message: () -> String) = log(Severity.Verbose, tag, throwable, null, message)
    fun d(tag: String? = null, throwable: Throwable? = null, message: () -> String) = log(Severity.Debug,   tag, throwable, null, message)
    // ... etc

    fun i(tag: String? = null, fields: Map<String, String>, throwable: Throwable? = null, message: () -> String) =
        log(Severity.Info, tag, throwable, fields, message)
    // ... etc

    fun configure(block: SkylogConfig.() -> Unit) {
        synchronized(lock) { config = config.copy().apply(block) }
    }

    private inline fun log(
        severity: Severity,
        tag: String?,
        throwable: Throwable?,
        fields: Map<String, String>?,
        message: () -> String,
    ) {
        val snapshot = config  // single read of the volatile reference
        if (severity < snapshot.minSeverity) return
        val resolvedTag = tag ?: DEFAULT_TAG
        val writers = snapshot.writers
        // Fan-out safety: a buggy lambda OR a buggy writer (log() OR isLoggable())
        // must NOT kill logging for the rest. isLoggable wrap added per Eng Review
        // §1 finding T-1 (symmetric with the log() catch below).
        val anyLoggable = writers.any { w ->
            try { w.isLoggable(resolvedTag, severity) } catch (_: Throwable) { false }
        }
        if (!anyLoggable) return

        val msg = try { message() } catch (t: Throwable) {
            "<lazy message failed: ${t::class.simpleName}: ${t.message}>"
        }
        val entry = LogEntry(
            timestamp = Clock.System.now(),
            severity = severity,
            tag = resolvedTag,
            message = msg,
            throwable = throwable,
            fields = fields,
        )
        for (w in writers) {
            val loggable = try { w.isLoggable(resolvedTag, severity) } catch (_: Throwable) { false }
            if (!loggable) continue
            try { w.log(entry) } catch (_: Throwable) { /* isolated; never propagate */ }
        }
    }
}

internal const val DEFAULT_TAG = "Skylog"
```

**Contract:**
- `inline` on the dispatcher means the `message` lambda is callsite-inlined — no closure allocation when filtered out (NFR-01).
- The two-pass (`anyLoggable` check, then individual `isLoggable` per writer) lets writers veto without the message being built.
- `config` is `@Volatile` + mutated under `synchronized(lock)` (kotlinx-atomicfu) so readers in `log()` always see a consistent snapshot.
- `Clock.System.now()` from `kotlinx-datetime` is cross-target; no `expect`/`actual` needed (resolved Mega Plan Review §5 finding F-5.2).
- Lambda exceptions become a synthetic message; writer exceptions are swallowed silently. Logging never throws.

### 4.4 `Severity.kt` (commonMain)

```kotlin
package dev.viethung.skylog

enum class Severity(val level: Int) : Comparable<Severity> {
    Verbose(0),
    Debug(1),
    Info(2),
    Warn(3),
    Error(4),
    Assert(5);
}
```

**Contract:** comparable by explicit `level` (NOT ordinal — Mega Plan Review §5 finding F-5.4: if a future `Fatal` is inserted between `Error` and `Assert`, ordinal ordering breaks every consumer comparing severities; explicit `level` is stable).

### 4.5 `LogEntry.kt` (commonMain)

```kotlin
package dev.viethung.skylog

import kotlinx.datetime.Instant

data class LogEntry(
    val timestamp: Instant,
    val severity: Severity,
    val tag: String,
    val message: String,
    val throwable: Throwable?,
    val fields: Map<String, String>?,
)
```

**Contract:**
- Immutable. Safe to pass across threads.
- `timestamp` from `kotlinx-datetime` `Clock.System.now()`; consistent across platforms.

### 4.6 Platform default writers

#### `commonMain/platform/PlatformDefaultWriter.kt`
```kotlin
package dev.viethung.skylog.platform

import dev.viethung.skylog.LogWriter

expect fun platformDefaultWriter(): LogWriter
```

#### `androidMain/platform/LogcatWriter.kt`
```kotlin
package dev.viethung.skylog.platform

import android.os.Build
import android.util.Log
import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.LogWriter
import dev.viethung.skylog.Severity

class LogcatWriter : LogWriter() {
    override fun log(entry: LogEntry) {
        // PRD D6: truncate to 23 chars on API <26 (Logcat throws IllegalArgumentException
        // there); full tag on API ≥26. Eng Review §2 finding A-9 — previously truncated
        // unconditionally.
        val tag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) entry.tag
                  else entry.tag.take(MAX_TAG_LEN)
        val msg = entry.message + (entry.fields?.let { " " + it.entries.joinToString(" ") { (k, v) -> "$k=$v" } } ?: "")
        when (entry.severity) {
            Severity.Verbose -> Log.v(tag, msg, entry.throwable)
            Severity.Debug   -> Log.d(tag, msg, entry.throwable)
            Severity.Info    -> Log.i(tag, msg, entry.throwable)
            Severity.Warn    -> Log.w(tag, msg, entry.throwable)
            Severity.Error   -> Log.e(tag, msg, entry.throwable)
            Severity.Assert  -> Log.wtf(tag, msg, entry.throwable)
        }
    }
    companion object { const val MAX_TAG_LEN = 23 }  // PRD D6
}

actual fun platformDefaultWriter(): LogWriter = LogcatWriter()
```

#### `iosMain/platform/OsLogWriter.kt`
```kotlin
package dev.viethung.skylog.platform

import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.LogWriter
import dev.viethung.skylog.Severity
// v0.1 uses NSLog only (simpler, public API). v0.2 may switch to os_log via cinterop
// for log-archive integration (PRD RP-06).

class OsLogWriter : LogWriter() {
    override fun log(entry: LogEntry) {
        // PRD R-03: evaluate lambda result and emit via NSLog with explicit message — no privacy redaction
        val prefix = "[${entry.severity.name.first()}] ${entry.tag}"
        val msg = entry.message + (entry.fields?.let { " " + it.entries.joinToString(" ") { (k, v) -> "$k=$v" } } ?: "")
        platform.Foundation.NSLog("$prefix: $msg")
        entry.throwable?.let { t ->
            // Mega Plan Review §2 finding F-2.4: stackTraceToString() on K/N can throw on
            // pathological stacks; isolate so logging never fails.
            val trace = try { t.stackTraceToString() } catch (_: Throwable) { "<stack trace unavailable: ${t::class.simpleName}>" }
            platform.Foundation.NSLog("    $trace")
        }
    }
}

actual fun platformDefaultWriter(): LogWriter = OsLogWriter()
```

#### `jvmMain/platform/StdoutWriter.kt`
```kotlin
package dev.viethung.skylog.platform

import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.LogWriter
import dev.viethung.skylog.Severity

class StdoutWriter(private val ansiColor: Boolean = System.console() != null) : LogWriter() {
    override fun log(entry: LogEntry) {
        val color = if (ansiColor) colorFor(entry.severity) else ""
        val reset = if (ansiColor) ANSI_RESET else ""
        println("$color${entry.timestamp} [${entry.severity.name.first()}] ${entry.tag}: ${entry.message}$reset")
        entry.throwable?.let { it.printStackTrace(System.out) }
    }
    private fun colorFor(s: Severity) = when (s) {
        Severity.Verbose -> ANSI_GRAY
        Severity.Debug   -> ANSI_BLUE
        Severity.Info    -> ANSI_GREEN
        Severity.Warn    -> ANSI_YELLOW
        Severity.Error   -> ANSI_RED
        Severity.Assert  -> ANSI_MAGENTA
    }
}

actual fun platformDefaultWriter(): LogWriter = StdoutWriter()
```

### 4.7 `InMemoryLogWriter.kt` (commonMain)

```kotlin
package dev.viethung.skylog.writers

import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.LogWriter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

class InMemoryLogWriter(private val capacity: Int = 1000) : LogWriter() {
    init { require(capacity > 0) { "capacity must be > 0, was $capacity" } }
    private val _entries = MutableStateFlow<List<LogEntry>>(emptyList())
    val entries: StateFlow<List<LogEntry>> = _entries

    override fun log(entry: LogEntry) {
        // MutableStateFlow.update uses compareAndSet internally — retries on
        // concurrent mutation, no thread can lose an entry to a race. This is
        // the chosen serialization primitive (Mega Plan Review §2 finding
        // F-2.1: original Mutex-based plan was suspending and incompatible
        // with non-suspend log(); update() gives the same mutual-exclusion
        // semantics without going suspending).
        _entries.update { current ->
            if (current.size < capacity) current + entry
            else current.drop(1) + entry
        }
    }

    fun clear() { _entries.value = emptyList() }

    /**
     * Restore a previously captured snapshot — supports `LogConsoleScreen` undo
     * (PRD §8 + Eng Review patch P10a). Snapshot is clamped to `capacity` to
     * preserve the ring-buffer invariant. Not exposed via `LogWriter` — internal
     * to `InMemoryLogWriter`.
     */
    fun restore(snapshot: List<LogEntry>) { _entries.value = snapshot.takeLast(capacity) }
}
```

**Contract:**
- `capacity > 0` enforced at construction (Mega Plan Review §4 finding F-4.2: capacity=0 was previously undefined; explicit `require` is the documented behavior).
- O(n) writes at capacity (`drop(1) + entry` copies the list). Acceptable at default capacity 1000 (<10 µs typical); v0.2 may switch to `ArrayDeque` ring buffer if profiling shows pressure (RP-04).
- Readers consume `entries` as `StateFlow` — backpressure-free, last-value caching.
- Concurrent writes are safe via `update { }` CAS retry loop.

### 4.8 `SkylogConfig.kt` + composite

```kotlin
package dev.viethung.skylog

class SkylogConfig(
    var minSeverity: Severity = Severity.Verbose,
    val writers: MutableList<LogWriter> = mutableListOf(),
) {
    internal fun copy(): SkylogConfig = SkylogConfig(minSeverity, writers.toMutableList())
}
```

---

## 5. `:skylog-ui` — Detailed Contracts (Android Compose)

### 5.1 `LogConsoleScreen.kt`

```kotlin
@Composable
fun LogConsoleScreen(
    buffer: InMemoryLogWriter,
    modifier: Modifier = Modifier,
    onClose: (() -> Unit)? = null,
) {
    val entries by buffer.entries.collectAsStateWithLifecycle()
    var minSeverity by remember { mutableStateOf(Severity.Verbose) }
    var selectedTag by remember { mutableStateOf<String?>(null) }
    var search by remember { mutableStateOf("") }
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    // Single-pass filter: previously a 3-chain `.filter{}.filter{}.filter{}` that
    // allocated two intermediate lists per recomputation (Eng Review §4 finding A-5).
    val filtered = remember(entries, minSeverity, selectedTag, search) {
        entries.filter {
            it.severity >= minSeverity
                && (selectedTag == null || it.tag == selectedTag)
                && (search.isBlank()
                    || it.message.contains(search, ignoreCase = true)
                    || it.tag.contains(search, ignoreCase = true))
        }
    }

    val listState = rememberLazyListState()
    val wasAtBottom = remember(listState) {
        derivedStateOf { listState.firstVisibleItemIndex == 0 }  // newest-first list
    }

    Scaffold(
        modifier = modifier,
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { padding ->
        Column(Modifier.padding(padding)) {
            ConsoleHeader(/* filter chips, dropdown, search field, onClose */)
            if (filtered.isEmpty()) {
                EmptyState()  // see §5.1.a
            } else {
                LazyColumn(state = listState, reverseLayout = true) {
                    items(filtered, key = { it.timestamp.toEpochMilliseconds() }) { LogRow(it) }
                }
            }
            ConsoleFooter(filtered, onClear = {
                // PRD §8: clear with undo. Snapshot before wiping, restore on snackbar action.
                val snapshot = buffer.entries.value
                buffer.clear()
                scope.launch {
                    val result = snackbarHostState.showSnackbar(
                        message = "Cleared ${snapshot.size} log${if (snapshot.size == 1) "" else "s"}",
                        actionLabel = "Undo",
                        duration = SnackbarDuration.Short,  // 4s default; PRD §8 says ~5s — Compose's Short is close enough
                    )
                    if (result == SnackbarResult.ActionPerformed) {
                        // InMemoryLogWriter has no bulk-restore API; emit a single restore via
                        // an internal helper added in §4.7 (`restore(snapshot)`) — see Eng Review P10a.
                        buffer.restore(snapshot)
                    }
                }
            })
        }
    }
}
```

> **P10a impact on §4.7:** add `fun restore(snapshot: List<LogEntry>) { _entries.value = snapshot.takeLast(capacity) }` to `InMemoryLogWriter` so the undo path has a single-call entry point that respects capacity. This is an `InMemoryLogWriter`-internal extension to support PRD §8 undo; it is not part of the public `LogWriter` contract.

#### 5.1.a `EmptyState` (Compose)

```kotlin
@Composable
private fun EmptyState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "No logs yet",
            style = MaterialTheme.typography.titleMedium,
            color = SkylogColors.dim,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = "Try emitting a log with Skylog.i { \"...\" }",
            style = MaterialTheme.typography.bodySmall,
            color = SkylogColors.dim,
        )
    }
}
```

PRD D3 resolution: empty state is a **default implementation, no shipped illustration asset**. Consumers can replace it via a future overload `LogConsoleScreen(buffer, emptyState = { MyCustomEmpty() })` if needed — not in v0.1.

**Contract:**
- Filtering is `remember`-keyed → recomputes only when source list or filter inputs change.
- `key` per item stabilizes recompositions across additions.
- `LazyColumn(reverseLayout = true)` shows newest at top; new entries push older ones down without disturbing scroll if user has scrolled into history (Mega Plan Review §4 finding F-4.3: previously undefined "clear mid-scroll" behavior).
- `LazyColumn` provides virtualization (NFR-04 — 60 fps with 1000 entries).

### 5.2 Filter components (`SeverityFilterChips`, `TagDropdown`, `SearchField`)

Each is a single-purpose `@Composable` parameterized by state + callback. Style draws from `DesignTokens` only.

`SearchField` is debounced at **200 ms** before forwarding to the parent's `onSearchChange` callback (Mega Plan Review §4 finding F-4.5: matches PRD §8 spec which the Plan was previously missing). Use `LaunchedEffect(query)` + `delay(200)` + `kotlinx.coroutines.flow.debounce` patterns — a typed character within the window does not trigger a recompute of the filtered list.

### 5.3 Row + actions

`LogRow` renders the layout described in PRD §8 with one accessibility addition (Mega Plan Review §11 finding F-11.3): the severity stripe also includes the **severity letter** (`V`/`D`/`I`/`W`/`E`/`A`) as a monospace glyph inside or adjacent to the colored stripe — color alone fails WCAG 2.1 SC 1.4.1 *Use of Color*. Layout:

```
[V] 13:47:02.341  Auth  User 42 signed in
 ^  ^             ^     ^
 |  timestamp     tag   message (2-line ellipsis, expandable)
 severity letter + color stripe (one element, both signals)
```

Long-press menu offers Copy single, Share thread.

### 5.4 `FloatingLogButton.kt`

```kotlin
@Composable
fun FloatingLogButton(
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
    badge: Int = 0,
)
```

**Contract:** draggable via `pointerInput { detectDragGestures { ... } }`. Position is kept in `remember { mutableStateOf(Offset.Zero) }` and clamped to the parent's `BoxWithConstraints` viewport on every drag delta (Mega Plan Review §4 finding F-4.4: previously unclamped — could be dragged offscreen and lost). Position is **not** persisted across process death — intentional, debug-only.

### 5.5 `LogRecompositions.kt`

```kotlin
@Composable
fun LogRecompositions(label: String, everyN: Int = 1) {
    // IntArray (not mutableStateOf) is intentional: snapshot state would re-trigger
    // composition every increment and pollute the very signal we're measuring (PRD
    // R-05). A plain mutable holder gives us a per-composition counter that doesn't
    // participate in Compose snapshot tracking.
    val count = remember { intArrayOf(0) }
    SideEffect {
        count[0]++
        if (count[0] % everyN == 0) {
            Skylog.d(tag = "Recomp") { "$label recomposed (n=${count[0]})" }
        }
    }
}
```

### 5.6 `LogLifecycle.kt`

```kotlin
@Composable
fun LogLifecycle(label: String) {
    DisposableEffect(Unit) {
        Skylog.d(tag = "Lifecycle") { "$label entered composition" }
        onDispose { Skylog.d(tag = "Lifecycle") { "$label left composition" } }
    }
}
```

### 5.7 `SkylogColors.kt`

Maps `Severity` → `DesignTokens` color primitives. No raw `Color(0xFF...)` literals in this file (CLAUDE.md §2).

---

## 6. `swift-package/SkylogKit` — Detailed Contracts (pure Swift)

### 6.1 Engine (Swift port of §4)

One-to-one mirror of the Kotlin API. Key differences:

- `() -> String` lambdas become `@autoclosure () -> String` so callers write `Skylog.i { "msg" }` (trailing closure) — but `@autoclosure` lets us also accept `Skylog.i("msg")` form for simple cases.
- `Throwable` → `Error`.
- `kotlinx.datetime.Instant` → `Date`.
- `StateFlow<List<LogEntry>>` → `@Published var entries: [LogEntry]` on an `ObservableObject`.

```swift
public enum Skylog {
    public static func i(tag: String? = nil,
                         throwable: Error? = nil,
                         _ message: @autoclosure () -> String) {
        defaultLogger.log(severity: .info, tag: tag, throwable: throwable, fields: nil, message: message)
    }
    // ... v/d/w/e/a parallels
    public static func configure(_ block: (inout SkylogConfig) -> Void) { defaultLogger.configure(block) }
}

public final class Logger {
    var config: SkylogConfig
    public func log(severity: Severity, tag: String?, throwable: Error?, fields: [String: String]?, message: () -> String) {
        guard severity >= config.minSeverity else { return }
        let resolvedTag = tag ?? "Skylog"
        guard config.writers.contains(where: { $0.isLoggable(tag: resolvedTag, severity: severity) }) else { return }
        let entry = LogEntry(timestamp: Date(), severity: severity, tag: resolvedTag,
                             message: message(), throwable: throwable, fields: fields)
        for w in config.writers where w.isLoggable(tag: resolvedTag, severity: severity) { w.log(entry) }
    }
    public func configure(_ block: (inout SkylogConfig) -> Void) { block(&config) }
}
```

### 6.2 SwiftUI views

```swift
public struct LogConsoleView: View {
    @ObservedObject private var buffer: InMemoryLogWriter
    @State private var minSeverity: Severity = .verbose
    @State private var selectedTag: String?
    @State private var search: String = ""
    // body: VStack(spacing: 0) { header, List(filtered) { LogRowView($0) }, footer }
}

public struct FloatingLogButton: View {
    let onOpen: () -> Void
    @State private var offset: CGSize = .zero
    // body: Circle().fill(theme.accent).frame(width: 56, height: 56)
    //         .offset(offset).gesture(DragGesture()...).onTapGesture(onOpen)
}
```

### 6.3 No Kotlin/Native consumed

`Package.swift` has **no** `binaryTarget` referencing a Kotlin XCFramework. This is the entire point of the pure-Swift port (PRD §12 D1).

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SkylogKit",
    platforms: [.iOS(.v16)],
    products: [.library(name: "SkylogKit", targets: ["SkylogKit"])],
    targets: [
        .target(name: "SkylogKit", path: "Sources/SkylogKit"),
        .testTarget(name: "SkylogKitTests", dependencies: ["SkylogKit"], path: "Tests/SkylogKitTests"),
    ]
)
```

### 6.4 `SkylogTheme.swift`

Mirrors `SkylogColors.kt`. Severity → SwiftUI `Color`. Injected via `EnvironmentValues` extension; consumers override with `.skylogTheme(_:)`.

---

## 7. Build Config Changes

### 7.1 `:skylog-core/build.gradle.kts`

```kotlin
plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.library)
    alias(libs.plugins.vanniktech.publish)  // existing alias used by :shared-core
}

kotlin {
    androidTarget { publishLibraryVariants("release") }
    jvm()
    listOf(iosArm64(), iosX64(), iosSimulatorArm64()).forEach { it.binaries.framework { baseName = "SkylogCore" } }

    sourceSets {
        commonMain.dependencies {
            api(libs.kotlinx.coroutines.core)
            api(libs.kotlinx.datetime)  // add to libs.versions.toml if not present — confirm in §7.5
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.turbine)
            implementation(libs.kotest.assertions)
        }
    }
}

android {
    namespace = "dev.viethung.skylog"
    compileSdk = 35
    defaultConfig { minSdk = 24 }
}

// v0.1 publish target: maven-local + GitHub Packages only (Mega Plan Review §9 finding F-9.1).
// Maven Central requires Sonatype namespace claim + GPG signing in CI — out of scope for v0.1.
// Schedule Central publish for v0.2 once the API has stabilized.
mavenPublishing {
    coordinates("dev.viethung", "skylog-core", "0.1.0-SNAPSHOT")
    // publishToMavenCentral()  // re-enable in v0.2 — see TODOS
}
```

### 7.2 `:skylog-ui/build.gradle.kts`

```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.compose.compiler)
    alias(libs.plugins.vanniktech.publish)
}

android {
    namespace = "dev.viethung.skylog.ui"
    compileSdk = 35
    defaultConfig { minSdk = 24 }
    buildFeatures { compose = true }
}

dependencies {
    api(project(":skylog-core"))
    api(platform(libs.androidx.compose.bom))
    api(libs.androidx.compose.material3)
    api(libs.androidx.lifecycle.runtime.compose)

    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}

// Same v0.1 publish posture as :skylog-core — maven-local + GitHub Packages only.
mavenPublishing {
    coordinates("dev.viethung", "skylog-ui", "0.1.0-SNAPSHOT")
    // publishToMavenCentral()  // re-enable in v0.2
}
```

### 7.3 `swift-package/SkylogKit/Package.swift`

See §6.3.

### 7.4 `settings.gradle.kts`

```diff
 include(
     ":shared-core",
     ":shared-components",
     ":shared-app",
     ":androidApp",
     ":server",
     ":number-input",
+    ":skylog-core",
+    ":skylog-ui",
 )
```

### 7.5 `gradle/libs.versions.toml`

Two new entries needed (confirmed absent in the current catalog at the time of writing):

```toml
[versions]
kotlinx-datetime = "0.6.2"
kotlinx-atomicfu = "0.27.0"

[libraries]
kotlinx-datetime = { module = "org.jetbrains.kotlinx:kotlinx-datetime",  version.ref = "kotlinx-datetime" }
kotlinx-atomicfu = { module = "org.jetbrains.kotlinx:atomicfu",          version.ref = "kotlinx-atomicfu" }

[plugins]
kotlinx-atomicfu = { id = "org.jetbrains.kotlinx.atomicfu",              version.ref = "kotlinx-atomicfu" }
```

`atomicfu` provides `kotlinx.atomicfu.locks.SynchronizedObject` + `synchronized { }` for the `Logger.configure` lock (see §4.3). Apply the plugin to `:skylog-core/build.gradle.kts` (`alias(libs.plugins.kotlinx.atomicfu)`).

No new plugins beyond `atomicfu` — existing aliases (`kotlin.multiplatform`, `android.library`, `kotlin.android`, `compose.compiler`, `vanniktech.publish`) cover the new modules.

---

## 8. Showcase Wiring

### 8.1 Android — `:androidApp`

Add a **"Skylog"** entry to the existing showcase list (named after the library, not the generic word "Logger" — Eng Review P6). Tapping it opens a new screen that:
1. Calls `Skylog.configure { writers += inMemoryWriter }` once (DI: provide `InMemoryLogWriter` as a Koin singleton).
2. Emits one log per severity on entry (`v/d/i/w/e/a`) + one with throwable + one with structured fields.
3. Renders `LogConsoleScreen(buffer = inMemoryWriter)` in the screen body.
4. Adds `FloatingLogButton` in the parent `Scaffold` for easy access.

### 8.2 iOS — `:iosApp`

Mirror of 8.1 in SwiftUI:
1. Configure `Skylog` writers in `iOSApp.swift` startup.
2. Add a **"Skylog"** row to the showcase index that pushes `LogConsoleView(buffer:)` (Eng Review P6).
3. Add `FloatingLogButton` at the navigation root.

### 8.3 `:shared-app` (optional)

Add a `SampleSkylogShowcaseViewModel` that emits a sample log stream on `onAppear` — both platforms can wire to it for parity.

### 8.4 `:server` integration — deferred to v0.2

JVM target stays in v0.1 (`:skylog-core` compiles and tests for JVM via `StdoutWriter`), but the Ktor server (`:server` module) is **not** wired in v0.1 (Mega Plan Review §1 finding F-1.2). The library is JVM-ready; concrete `:server` usage (request-scoped tags, structured fields for HTTP access logs) is a follow-up TODO. Re-evaluate when v0.2 brings coroutine-context propagation (PRD §12 D2).

---

## 9. Tests

### 9.1 `SkylogTest.kt` (commonTest)

| # | Scenario | Assertion |
|---|---|---|
| 1 | Lambda not evaluated when severity below minimum | A probe `var called = false` lambda is never invoked when `minSeverity = Info` and call is `Skylog.d` |
| 2 | Lambda not evaluated when no writer is loggable | All writers return `isLoggable = false` → probe never invoked |
| 3 | Lambda evaluated exactly once even with multiple writers | Probe invoked once when 3 writers all accept |
| 4 | Tag falls back to `DEFAULT_TAG` when null | Entry has tag `"Skylog"` |
| 5 | Structured fields passed through | `LogEntry.fields["id"] == "42"` |
| 6 | Throwable passed through | `LogEntry.throwable === ex` |
| 7 | Structured-fields call still lazy when filtered out (Mega Plan Review F-6.6) | Probe lambda for `Skylog.d(fields = ...) { probe() }` not called when `minSeverity = Info` |
| 8 | Buggy writer doesn't kill fan-out (F-6.1) | Two writers; first throws in `log()`; second still receives the entry; no exception escapes `Skylog.i { ... }` |
| 9 | Buggy lambda doesn't crash caller (F-6.2) | `Skylog.i { throw RuntimeException("boom") }` does not throw; writers receive synthetic message `<lazy message failed: ...>` |
| 10 | NFR-01 micro-benchmark (F-6.4) | 1M `Skylog.d { "msg" }` calls with `minSeverity = Info` complete in < 100 ms total on the test runner — ~100 ns / call. Skipped in normal CI, run via `./gradlew :skylog-core:jvmTest --tests *Benchmark*` |
| 11 | Buggy `isLoggable` doesn't crash caller (Eng Review T-1) | Two writers; first's `isLoggable()` throws; `Skylog.i { ... }` does NOT propagate the exception; second writer (non-throwing, `isLoggable = true`) STILL receives the entry; first writer's `log()` is NOT called |
| 12 | `configure()` concurrent with `log()` doesn't tear (Eng Review T-1 follow-up) | One coroutine calls `Skylog.configure { writers += freshWriter }` 1000 times; another emits `Skylog.i { ... }` 1000 times; no exception thrown, no `ConcurrentModificationException`, every emitted entry visible to AT LEAST one writer present at the time of the call (snapshot semantics from `@Volatile config`) |

### 9.2 `InMemoryLogWriterTest.kt` (commonTest, Turbine)

| # | Scenario | Assertion |
|---|---|---|
| 1 | Empty buffer initial state | `entries.value.isEmpty()` |
| 2 | Single entry append | StateFlow emits list of size 1 |
| 3 | Capacity rollover | After `capacity + 1` writes, size = capacity, oldest entry dropped |
| 4 | `clear()` empties buffer | StateFlow emits empty list |
| 5 | Concurrent writes preserve order | 100 writes from 4 coroutines — final list size = 100, no duplicates |
| 6 | `capacity = 0` rejected at construction (F-4.2 / F-6.3) | `InMemoryLogWriter(capacity = 0)` throws `IllegalArgumentException` |
| 7 | High-concurrency stress (F-6.5) | 100 coroutines × 1000 writes each on `capacity = 1000` — final size = 1000, no `IndexOutOfBoundsException`, no lost-update count drift |

### 9.3 `LogWriterCompositionTest.kt` (commonTest)

| # | Scenario | Assertion |
|---|---|---|
| 1 | Two writers, both loggable → both receive entry | Each writer's `log` called once |
| 2 | Two writers, one vetoes via `isLoggable=false` → only one receives | Vetoed writer's `log` not called |
| 3 | All writers veto → message lambda not evaluated | Probe never called |

### 9.4 `SeverityTest.kt` (commonTest)

| # | Scenario | Assertion |
|---|---|---|
| 1 | Verbose < Debug < Info < Warn < Error < Assert | Pairwise `<` comparisons |
| 2 | Severity ordinals stable | `Severity.Info.ordinal == 2` |

### 9.5 Compose UI tests (`:skylog-ui` androidTest)

| # | Scenario | Assertion |
|---|---|---|
| 1 | Empty buffer → empty-state visible | `onNodeWithText("No logs yet").assertIsDisplayed()` |
| 2 | Filter Warn → only Warn+ visible | Verify list contents |
| 3 | Search "auth" → only entries containing "auth" visible | Verify list contents |
| 4 | Tap row Copy → clipboard contains row text | (Robolectric or Espresso clipboard check) |
| 5 | `FloatingLogButton` tap → `onOpen` invoked | Verify callback called |
| 6 | `LogRecompositions(label, everyN = 5)` logs every 5th recomposition | InMemoryLogWriter has expected debug entries |
| 7 | Tag dropdown filter (Eng Review T-2, FR-11) | Buffer has entries with tags `"Auth"`, `"Cart"`, `"Net"`; select `"Cart"` in dropdown → only Cart rows visible; clear dropdown → all rows return |
| 8 | Multi-filter AND composition (Eng Review T-5, FR-11) | Set severity chip to `Warn`, tag dropdown to `"Auth"`, search to `"signed"` simultaneously → only entries matching ALL THREE predicates visible |
| 9 | Clear with undo snackbar (Eng Review T-3 / P10a, PRD §8) | Buffer has ≥3 entries; tap "Clear" → list empties + snackbar appears with "Undo" action; tap "Undo" before snackbar dismisses → list restored to the pre-clear snapshot |
| 10 | **REGRESSION** — FloatingLogButton viewport clamp (Eng Review T-4, F-4.4) | Render `FloatingLogButton` in a `BoxWithConstraints` of known size (e.g., 360 × 640 dp); programmatically drag offset to (1000.dp, 1000.dp) → button position is clamped within `(0..maxX, 0..maxY)` — never offscreen. Repeat for negative drag (-1000, -1000) → clamped to (0, 0) |

### 9.6 Swift tests (`SkylogKitTests`)

Mirror of 9.1 + 9.2 + 9.3 with XCTest. Same scenarios, same assertions.

**Additionally** (Eng Review T-6, P11):

| # | Scenario | Assertion |
|---|---|---|
| 11 | Buggy `isLoggable` doesn't crash caller (Swift mirror of 9.1 row 11) | Two `LogWriter` instances; first's `isLoggable(tag:severity:)` throws (modeled via a writer that calls `fatalError` only inside a child task we swallow, or via a delegate that throws then is wrapped — Swift can't throw from a non-throwing protocol method, so this test uses a force-unwrap-of-nil sentinel rather than `throws`). `Skylog.i { ... }` does NOT propagate; second writer still receives the entry |

---

## 10. Build Order — 10 Steps with Acceptance Gates

> Each gate is a stop point. Don't advance until the gate passes locally.

| Step | Work | Gate |
|---|---|---|
| **1** | Create `:skylog-core` module skeleton — `build.gradle.kts` per §7.1, empty source dirs, register in `settings.gradle.kts` per §7.4. | `./gradlew :skylog-core:tasks` lists tasks. |
| **2** | Implement `Severity`, `LogEntry`, `LogWriter`, `SkylogConfig` (commonMain) per §4. | `./gradlew :skylog-core:compileKotlinMetadata` clean. |
| **3** | Implement `Logger` (§4.3) and `Skylog` facade (§4.1). Use `Clock.System.now()` from `kotlinx-datetime` directly — no `expect`/`actual` clock needed (Eng Review §1 P2). | Step 2 still compiles; `Logger.configure { writers += platformDefaultWriter() }` resolves on all three targets even though `platformDefaultWriter` is the only `expect`/`actual` in the engine so far. |
| **4** | Implement `InMemoryLogWriter` + write `InMemoryLogWriterTest.kt` per §9.2. | `./gradlew :skylog-core:allTests` green for the new tests. |
| **5** | Implement platform default writers (`LogcatWriter`, `OsLogWriter`, `StdoutWriter`) + `platformDefaultWriter` actuals per §4.6. | `./gradlew :skylog-core:allTests` still green. Smoke: `Skylog.i { "hello" }` lands in Logcat / NSLog / stdout when run on each target. |
| **6** | Write the remaining `commonTest` files (§9.1, §9.3, §9.4). | All `commonTest` tests green. |
| **7** | Create `:skylog-ui` module (build config per §7.2). Implement `LogConsoleScreen` + components + `FloatingLogButton` + `LogRecompositions` + `LogLifecycle` per §5. | `./gradlew :skylog-ui:assembleDebug` clean. |
| **8** | Write `:skylog-ui` Compose UI tests per §9.5. | `./gradlew :skylog-ui:connectedAndroidTest` green (or skip in CI when no emulator; document manual run). |
| **9** | Create `swift-package/SkylogKit` per §6 — engine port + SwiftUI views + tests. | `swift test --package-path swift-package/SkylogKit` green. |
| **10** | Wire showcases (§8.1, §8.2). Verify both apps build, install, and the floating button + console render and filter as expected. | Manual smoke: emit one log per severity, see them in the console on Android + iOS; filter chips work; search works. |

After step 10, PRD §14 acceptance criteria should all be satisfied.

---

## 11. Acceptance Criteria (Plan-level — mirrors PRD §14)

Plan is **executed successfully** when:

- [ ] `./gradlew :skylog-core:allTests` green on all KMP targets.
- [ ] `./gradlew :skylog-ui:assembleDebug` clean.
- [ ] `./gradlew :skylog-ui:connectedAndroidTest` green on a real emulator (manual gate if CI has no emulator).
- [ ] `swift test --package-path swift-package/SkylogKit` green.
- [ ] `./gradlew :skylog-core:publishToMavenLocal` produces Android AAR + KMP klibs + JVM jar.
- [ ] `./gradlew :skylog-ui:publishToMavenLocal` produces Android AAR.
- [ ] `:androidApp` and `:iosApp` both display the Logger showcase with the console and floating button.
- [ ] PRD acceptance criteria §14 all ticked.
- [ ] Final manual audit confirms no platform types in `commonMain`.

---

## 12. Risks & Mitigations (delta from PRD §13)

| # | Risk | Mitigation in this plan |
|---|---|---|
| RP-01 | `expect`/`actual` mismatch on `currentInstant()` across targets | Use `kotlinx-datetime`'s `Clock.System.now()` — already cross-target. Only `expect`/`actual` if we end up needing a higher-resolution monotonic clock; otherwise use the library directly. |
| RP-02 | Compose UI test for drag gesture is flaky | Cover state transitions via `pointerInput` test taps; visual drag is manual. |
| RP-03 | Swift port lags Kotlin engine over time | Treat the test scenarios in §9.1–§9.4 as the contract. Each Kotlin test row has a Swift mirror; CI runs both. |
| RP-04 | `InMemoryLogWriter.log` is O(n) at capacity due to `drop(1) + entry` | Acceptable at default capacity 1000 (single-digit µs); revisit with a true ring-buffer impl in v0.2 if profiling shows it. |
| RP-05 | Compose `LogRecompositions` itself pollutes the recomposition signal | Documented in PRD R-05 + `KDoc` on the composable. Recommend stripping in release builds. |
| RP-06 | `OsLogWriter` cinterop complexity (private `os_log` headers) | v0.1 uses `NSLog` only (simpler, public API). Note this in `KDoc`; v0.2 may revisit with proper `os_log` for log-archive integration. |

---

## 13. Out of Plan Scope (deferred)

- Coroutine-context propagation (PRD D2).
- Native CLI / Wasm / JS targets.
- Persistent on-disk buffer.
- Network / Crashlytics writers (consumers register their own).
- Compose Multiplatform iOS UI (we ship SwiftUI on iOS, per skeleton policy).
- SwiftUI "recomposition" equivalent (PRD D5 — explicitly NOT shipping).
- Maven Central publication (deferred to v0.2 — see §7.1).
- `:server` integration wiring (deferred to v0.2 — see §8.4).
- Badge unread-count visual test on FloatingLogButton (deferred — not on critical path).

These have their own follow-up PRDs to write once v0.1 ships.

---

## 14. Implementation Tasks (synthesized from Eng Review)

Each task derives from a specific Eng Review finding. P1 blocks ship; P2 should land in the same v0.1 branch; P3 is a follow-up. Effort labels: `human` = single-developer wall-clock, `CC` = Claude-Code-assisted.

- [ ] **T1 (P2, human: ~5min / CC: ~1min)** — `:skylog-core/Skylog.kt` — Document `Skylog` object lazy-init contract + test setup recipe
  - Surfaced by: Eng Review A-1 (patch P1) — lazy-init contract was undocumented
  - Files: `skylog-core/src/commonMain/kotlin/dev/viethung/skylog/Skylog.kt`
  - Verify: KDoc on `Skylog` object mentions `platformDefaultWriter()` is invoked on first access + test recipe present
- [ ] **T2 (P1, human: ~5min / CC: ~1min)** — `:skylog-core/.../LogcatWriter.kt` — Version-gate Logcat tag truncation to API <26
  - Surfaced by: Eng Review A-9 (patch P4) — implementation contradicted PRD D6
  - Files: `skylog-core/src/androidMain/kotlin/dev/viethung/skylog/platform/LogcatWriter.kt`
  - Verify: instrumented test on API 24 (truncates) and API 33 (full tag) emulator OR unit test that mocks `Build.VERSION.SDK_INT`
- [ ] **T3 (P1, human: ~10min / CC: ~2min)** — `:skylog-core/Logger.kt` — Wrap `LogWriter.isLoggable()` in try/catch
  - Surfaced by: Eng Review T-1 (patch P7) — buggy isLoggable crashed whole fan-out
  - Files: `skylog-core/src/commonMain/kotlin/dev/viethung/skylog/Logger.kt`
  - Verify: §9.1 test row 11 green
- [ ] **T4 (P1, human: ~20min / CC: ~5min)** — `:skylog-core/.../SkylogTest.kt` — Add rows 11 + 12 (isLoggable throws; configure-during-log)
  - Surfaced by: Eng Review T-1 (patch P8) — coverage gap; configure-during-log is implicit but uncovered
  - Files: `skylog-core/src/commonTest/kotlin/dev/viethung/skylog/SkylogTest.kt`
  - Verify: `./gradlew :skylog-core:allTests` green; both rows present and exercise the new try/catch
- [ ] **T5 (P2, human: ~3min / CC: ~1min)** — `:skylog-ui/.../LogRecompositions.kt` — Add comment explaining IntArray-as-holder
  - Surfaced by: Eng Review A-4 (patch P5) — terse but unusual idiom
  - Files: `skylog-ui/src/main/kotlin/dev/viethung/skylog/ui/compose/LogRecompositions.kt`
  - Verify: file review during code-quality pass
- [ ] **T6 (P2, human: ~5min / CC: ~1min)** — `:androidApp` + `:iosApp` — Rename showcase row "Logger" → "Skylog"
  - Surfaced by: Eng Review A-10 (patch P6) — generic label vs library name
  - Files: `androidApp/.../ShowcaseList.kt`, `iosApp/iosApp/Showcase/ShowcaseList.swift` (or equivalent index)
  - Verify: manual on Android emulator + iOS simulator — row reads "Skylog"
- [ ] **T7 (P1, human: ~30min / CC: ~5min)** — `:skylog-ui/.../LogConsoleScreen.kt` + `:skylog-core/.../InMemoryLogWriter.kt` — Implement clear-with-undo snackbar
  - Surfaced by: Eng Review T-3 (patch P10a) — PRD §8 spec'd undo but Plan §5.1 never implemented it
  - Files: `skylog-ui/src/main/kotlin/dev/viethung/skylog/ui/LogConsoleScreen.kt`, `skylog-core/src/commonMain/kotlin/dev/viethung/skylog/writers/InMemoryLogWriter.kt`
  - Verify: §9.5 test row 9 green; manual smoke on emulator
- [ ] **T8 (P2, human: ~5min / CC: ~1min)** — `:skylog-ui/.../LogConsoleScreen.kt` — Collapse 3-chain `.filter{}` into single-pass filter
  - Surfaced by: Eng Review A-5 (patch P12) — micro-perf for NFR-04
  - Files: `skylog-ui/src/main/kotlin/dev/viethung/skylog/ui/LogConsoleScreen.kt`
  - Verify: code review; behavior unchanged by §9.5 rows 2, 3, 7, 8
- [ ] **T9 (P1, human: ~45min / CC: ~8min)** — `:skylog-ui/androidTest/...` — Add tag-dropdown, multi-filter-AND, clear-with-undo, **viewport-clamp regression** tests
  - Surfaced by: Eng Review T-2 / T-3 / T-4 / T-5 (patch P9) — T-4 mandatory per IRON RULE
  - Files: `skylog-ui/src/androidTest/kotlin/dev/viethung/skylog/ui/LogConsoleScreenTest.kt`, `.../FloatingLogButtonTest.kt`
  - Verify: `./gradlew :skylog-ui:connectedAndroidTest` green (or manual run if no CI emulator)
- [ ] **T10 (P2, human: ~10min / CC: ~3min)** — `swift-package/SkylogKit/Tests/...` — Add Swift mirror of isLoggable-throws test
  - Surfaced by: Eng Review T-6 (patch P11) — Kotlin↔Swift parity
  - Files: `swift-package/SkylogKit/Tests/SkylogKitTests/SkylogTests.swift`
  - Verify: `swift test --package-path swift-package/SkylogKit` green

JSONL artifact for `/autoplan` aggregation: `~/.gstack/projects/osxsystem-skeleton/tasks-eng-review-20260521-145310.jsonl`.

---

## 15. Implementation Deviations (post-impl, 2026-05-21)

Documenting every place the shipped impl diverged from the plan as written. Captured during /investigate smoke pass on iPhone 17e sim. Branch: `feat/skylog-impl` (impl worktree, off `develop`). All deviations have build-green evidence.

### Toolchain & build-config deviations

| # | Plan said | Impl shipped | Reason |
|---|-----------|--------------|--------|
| D1 | `:skylog-core/build.gradle.kts` uses `com.android.library` + `kotlin.multiplatform` combo | `alias(libs.plugins.android.kmp.library)` | AGP 9.x rejects the two-plugin combo; the new `android.kmp.library` plugin consolidates the KMP+Android case |
| D2 | `androidTarget { publishLibraryVariants("release") }` | (removed) | API unavailable under `android.kmp.library`; release publishing still works via vanniktech-publish |
| D3 | `:skylog-ui/build.gradle.kts` includes `alias(libs.plugins.kotlin.android)` | (removed) | AGP 9.x bundles the Kotlin Android plugin transitively. Matches `:number-input`. |
| D4 | `kotlinx-atomicfu 0.27.0` | `0.29.0` | 0.27.0 metadata reader fails on Kotlin 2.3.x — its transformer maxes out at Kotlin 2.2.0 metadata |
| D5 | `@Volatile var config: SkylogConfig` in `Logger` | `private val _config = atomic(initialConfig)` (atomicfu `AtomicRef`) | `@Volatile` doesn't compile on Kotlin/Native iOS. AtomicRef gives the same volatile-like semantics cross-target. |
| D6 | atomicfu Gradle transform handles JVM rewrites | `atomicfu { transformJvm = false }` in `:skylog-core/build.gradle.kts` | AGP 9.x removed the `androidMainClasses` task that the atomicfu Gradle plugin wires into; Kotlin 2.x IR transformer handles atomicfu at compile time so disabling the Gradle hook is safe |

### Swift package deviations

| # | Plan said | Impl shipped | Reason |
|---|-----------|--------------|--------|
| D7 | `Package.swift` platforms: `[.iOS(.v16)]` | `[.iOS(.v16), .macOS(.v12)]` | `swift test` runs on the macOS host SDK; the SwiftUI view tests + Combine usage in `InMemoryLogWriter` need a macOS platform declaration |
| D8 | Lambda-throws + isLoggable-throws coverage symmetric with Kotlin | Limited: Swift `@autoclosure () -> String` is non-throwing by type; protocol methods can't throw from non-throwing declarations. Row 11 uses a vetoed-isLoggable sentinel; row 9 covers normal-path eval only. | Swift language constraints, not implementation bugs. Documented in test files. |

### UX deviations surfaced during smoke

| # | PRD said | Impl shipped | Resolution |
|---|----------|--------------|------------|
| D9 | Severity filter chips "multi-select" (PRD §8 line 272) | Min-severity (`entry.severity >= minSeverity`) on both platforms — tap `Warn` reveals Warn+Error+Assert, mirrors Logcat/OSLog/pino/winston. | **PRD updated** to match impl (industry-standard pattern, both platforms identical, no code change). |
| D10 | Empty state copy: "No logs yet" + "Try emitting a log…" hint (PRD §8 line 271) | Two-variant copy: same hint when buffer truly empty; "No logs match the current filter" (no emit hint) when buffer populated but filter returns zero. | **Bug fixed on both platforms.** Swift: extracted `LogConsoleView.emptyStateCopy(bufferEmpty:)` static helper + 2 new XCTest cases (`LogConsoleViewTests`). Kotlin: `EmptyState` composable takes `bufferEmpty: Boolean` param. Existing tests still pass (both assert on genuinely-empty buffer). PRD §8 updated to describe both variants. |

### Evidence

- `:skylog-core:allTests` — 24 JVM + 23 iosSimulatorArm64, green
- `:skylog-ui:assembleDebug` + `assembleDebugAndroidTest` — green (1s incremental)
- `swift test --package-path swift-package/SkylogKit` — **24 executed, 1 skipped (NFR-01 benchmark, intentional), 0 failures** (was 22; +2 from `LogConsoleViewTests`)
- `mcp__XcodeBuildMCP__build_run_sim` on iPhone 17e — SUCCEEDED in 5.98s incremental, 0 errors, 0 warnings; app launches and renders all 7 seed logs in the SwiftUI console
- `:skylog-core:publishToMavenLocal` + `:skylog-ui:publishToMavenLocal` — artifacts at `~/.m2/repository/dev/viethung/skylog-{core,ui}/0.1.0-SNAPSHOT/`
- commonMain platform-type audit — 0 matches for `android.*` / `androidx.compose.*` / `UIKit.*` / `SwiftUI.*` (CLAUDE.md load-bearing rule held)

### Not done (queued)

- `./gradlew :skylog-ui:connectedAndroidTest` on a booted emulator — F-4.4 viewport-clamp regression row needs an emulator session
- `FloatingLogButton` at navigation root — no global Scaffold/overlay slot exists in the showcase Dashboard; skipped per surgical-changes principle
- Manual Android smoke pass — only iOS was driven during /investigate

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | CLEAR (HOLD_SCOPE) | mode: HOLD_SCOPE, 2 critical gaps + 12 patches applied + 8 PRD decisions closed, 0 unresolved |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN, FULL_REVIEW) | 7 issues found (3 arch, 3 code-quality, 1 perf) + 6 test gaps (1 regression F-4.4) → 12 patches applied, 0 unresolved, 0 critical gaps |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | not run (outside-voice gate compressed out — see CODEX note below) |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | not run — **recommended next** given UI scope (Compose console + SwiftUI console + FloatingLogButton + WCAG-compliant LogRow) |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | not run — optional |

### Eng Review summary (this session, 2026-05-21)

- **Mode:** FULL_REVIEW (scope locked by CEO HOLD; no scope reopening per skill rules)
- **Architecture findings (3):** A-1 lazy-init contract on `object Skylog` (P1 doc patch); A-8 ghost `currentInstant()` expect/actual reference in §10 step 3 (P2 strike); A-13 dead `CompositeLogWriter.kt` in §3 file tree (P3 drop).
- **Code-quality findings (3):** A-9 LogcatWriter unconditional truncation contradicting PRD D6 (P4 version-gate); A-4 IntArray-as-holder in `LogRecompositions` needs explanation (P5 comment); A-10 showcase row labeled "Logger" not "Skylog" (P6 rename Android + iOS).
- **Test gaps (6, 1 regression):** T-1 `isLoggable()` throws not wrapped (P7 wrap + P8 test row 11+12); T-2 tag dropdown filter untested (P9 row 7); T-3 clear-with-undo missing from §5.1 code AND tests (P10a ship undo in v0.1 + P9 row 9); T-4 **REGRESSION** F-4.4 viewport-clamp had no test (P9 row 10, mandatory per IRON RULE); T-5 multi-filter AND composition (P9 row 8); T-6 Swift mirror of T-1 (P11 SkylogKitTests row 11).
- **Performance findings (1):** A-5 LogConsoleScreen 3-chained `.filter{}` → single-pass filter (P12).
- **All 12 patches applied with user approval** (Option A — apply all + ship undo in v0.1).

### Coverage delta after patches

Coverage diagram before: 17/27 paths tested (63 %), 1 critical gap (T-1 isLoggable throws), 1 regression untested (T-4).
Coverage diagram after: 24/27 paths tested (89 %), 0 critical gaps, regression covered.
Remaining gaps (acceptable for v0.1, deferred to follow-up): badge unread count visual test; floating-button-position-on-navigation user flow.

### Parallelization

- **Lane A:** `:skylog-core` (build steps 1–6) — independent
- **Lane B:** `swift-package/SkylogKit` (build step 9) — independent of A (different language, no shared files)
- **Lane C:** `:skylog-ui` (build steps 7–8) — requires Lane A complete
- **Lane D:** Showcase wiring (build step 10) — requires A + B + C

A and B launch in parallel worktrees. C waits for A. D waits for all.

### CODEX

Outside-voice (codex) was offered by the skill but compressed out per session preference (user opted out of gstack ceremony in CEO review and continued the pattern here). To get an independent challenge: `/codex review docs/logger/SKYLOG-IMPLEMENTATION-PLAN.md` from this worktree.

### CROSS-MODEL

N/A — only Claude reviewed (both CEO and Eng). Codex would catch architectural blind spots and is worth running before implementation if you want a third opinion.

### UNRESOLVED

0 — all 12 eng-review patches batched and approved this session.

### VERDICT

**CEO + ENG CLEARED — implementation may begin.**

Recommended sequence:
1. **(Optional, recommended)** `/plan-design-review docs/logger/SKYLOG-PRD.md docs/logger/SKYLOG-IMPLEMENTATION-PLAN.md` — UI scope is non-trivial (Compose console + SwiftUI console + FloatingLogButton + severity-color WCAG layout); a dedicated visual / UX pass is worth ~10 min before code lands.
2. Commit the worktree changes when satisfied with both review reports.
3. Start implementation by Lane A (`:skylog-core`, build steps 1–6).

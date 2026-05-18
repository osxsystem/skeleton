import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kmp.library)
    // NOTE: maven-publish is intentionally ABSENT. :shared-app is showcase wiring,
    // never published to Maven. It does emit an iOS XCFramework for iosApp consumption.
}

kotlin {
    android {
        namespace = "dev.viethung.showcase"
        compileSdk = 36
        minSdk = 23
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
        }
        withHostTestBuilder { }
    }

    // iOS targets — iosArm64 + iosSimulatorArm64 ONLY (D-01)
    val xcframework = XCFramework("SkeletonApp")
    listOf(
        iosArm64(),
        iosSimulatorArm64(),
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "SkeletonApp"
            xcframework.add(this)

            // Re-export shared-core + shared-components types so a single `import SkeletonApp`
            // gives Swift access to DesignTokens, ColorPalette, ViewModel*, SampleUiState,
            // GreetingViewModel, and friends. K/N `export()` is not transitive — both must
            // be listed even though shared-components already api-exports shared-core.
            export(project(":shared-core"))
            export(project(":shared-components"))
            export(libs.androidx.lifecycle.viewmodel)

            // SQLDelight NativeSqliteDriver requires libsqlite3 (Pitfall 19) — mirror shared-core/components
            linkerOpts.add("-lsqlite3")
        }
    }

    sourceSets {
        commonMain.dependencies {
            // api so iOS framework `export(...)` directives find these
            api(project(":shared-core"))
            api(project(":shared-components"))
            api(libs.androidx.lifecycle.viewmodel)

            implementation(libs.koin.core)
            implementation(libs.kotlinx.coroutines.core)
        }

        commonTest.dependencies {
            implementation(kotlin("test"))            // kotlin.test.Test — NEVER org.junit.Test (D-17 / Pitfall 18)
            implementation(libs.kotlinx.coroutines.test)
            implementation(libs.turbine)
            implementation(libs.kotest.assertions.core)
        }
    }
}

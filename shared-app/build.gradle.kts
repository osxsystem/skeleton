plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kmp.library)
    // NOTE: maven-publish and xcframework bridge plugins are intentionally ABSENT.
    // :shared-app is the showcase module and is NEVER published (D-11 / ARCHITECTURE.md).
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
    listOf(
        iosArm64(),
        iosSimulatorArm64(),
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "SkeletonApp"     // never exported; just for compilation
        }
    }

    sourceSets {
        commonMain.dependencies {
            // implementation (not api) — showcase consumes the library; types must not flow through
            implementation(project(":shared-core"))
            implementation(project(":shared-components"))
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


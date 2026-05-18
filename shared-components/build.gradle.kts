plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kmp.library)   // com.android.kotlin.multiplatform.library (D-14 / SCAF-03)
    alias(libs.plugins.skie)                  // co.touchlab.skie (D-15, D-16)
    alias(libs.plugins.kmmbridge)             // co.touchlab.kmmbridge (D-07)
    alias(libs.plugins.vanniktech.publish)
}

kotlin {
    android {
        namespace = "dev.viethung.components"
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
            // Umbrella framework name — MUST be SkeletonKit (D-15 / Pitfall 21)
            baseName = "SkeletonKit"

            // Export :shared-core types so iOS sees them through a single framework import
            export(project(":shared-core"))
            export(libs.androidx.lifecycle.viewmodel)

            // SQLDelight NativeSqliteDriver requires libsqlite3 (Pitfall 19) — mirror :shared-core
            linkerOpts.add("-lsqlite3")
        }
    }

    sourceSets {
        commonMain.dependencies {
            // api: :shared-core types flow through to consumers of :shared-components
            api(project(":shared-core"))
            api(libs.androidx.lifecycle.viewmodel)

            implementation(libs.koin.core)
            implementation(libs.kotlinx.coroutines.core)
        }

        androidMain.dependencies {
            implementation(libs.androidx.lifecycle.runtime.compose)
            implementation(libs.androidx.lifecycle.viewmodel.compose)
        }

        commonTest.dependencies {
            implementation(kotlin("test"))            // kotlin.test.Test — NOT org.junit.Test (D-17 / Pitfall 18)
            implementation(libs.kotlinx.coroutines.test)
            implementation(libs.turbine)
            implementation(libs.kotest.assertions.core)
        }
    }
}

// SKIE configuration (D-15, D-16)
// NOTE: SKIE 0.10.11 does not support Kotlin 2.3.21 (supports up to 2.3.20).
// Disabled temporarily — re-enable when SKIE releases Kotlin 2.3.21 support.
// See: https://github.com/touchlab/SKIE/releases
skie {
    isEnabled = false
    analytics {
        enabled.set(false)
    }
}

// KMMBridge: emit XCFramework locally — no remote publish in Phase 1 (D-07)
// spm() uses KMMBridge default output; real SPM repo push deferred to Phase 7 per D-07
kmmbridge {
    // Remote publish wiring deferred to Phase 7 (D-07); local XCFramework only for now
    spm()
    // Framework name must match baseName in kotlin {} block
    frameworkName.set("SkeletonKit")       // matches baseName = "SkeletonKit"
}

// vanniktech maven-publish dry-run wiring (D-06)
mavenPublishing {
    coordinates(
        groupId    = "dev.viethung",
        artifactId = "shared-components",
        version    = "0.1.0-SNAPSHOT",
    )
    pom {
        name.set("Skeleton Shared Components")
        description.set("KMP shared component ViewModels — forms, amount input, navigation, notifications")
        url.set("https://github.com/viethung097/skeleton")
        licenses {
            license {
                name.set("MIT License")
                url.set("https://opensource.org/licenses/MIT")
            }
        }
        developers {
            developer {
                id.set("viethung097")
                name.set("Do Viet Hung")
                email.set("viethung097@gmail.com")
            }
        }
    }
}

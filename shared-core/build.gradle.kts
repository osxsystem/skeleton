plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kmp.library)   // com.android.kotlin.multiplatform.library (D-14 / SCAF-03)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.sqldelight)
    alias(libs.plugins.vanniktech.publish)
}

kotlin {
    android {
        namespace = "dev.viethung.core"
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
            baseName = "SkeletonCore"         // internal; umbrella is in :shared-components
            // SQLDelight NativeSqliteDriver requires libsqlite3 (D-18 / Pitfall 19)
            linkerOpts.add("-lsqlite3")
            // Keychain APIs used by KeychainSessionStore (iosMain)
            linkerOpts.addAll(listOf("-framework", "Security"))
        }
    }

    sourceSets {
        commonMain.dependencies {
            // Lifecycle ViewModel — api so types are visible downstream
            api(libs.androidx.lifecycle.viewmodel)

            // Koin DI
            implementation(libs.koin.core)

            // Ktor client
            implementation(libs.ktor.client.core)
            implementation(libs.ktor.client.content.negotiation)
            implementation(libs.ktor.client.logging)
            implementation(libs.ktor.serialization.json)

            // SQLDelight coroutines
            implementation(libs.sqldelight.coroutines)

            // KotlinX
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.serialization.json)
        }

        androidMain.dependencies {
            implementation(libs.ktor.client.okhttp)
            implementation(libs.sqldelight.android.driver)
            implementation(libs.androidx.security.crypto)
        }

        iosMain.dependencies {
            implementation(libs.ktor.client.darwin)
            implementation(libs.sqldelight.native.driver)
        }

        commonTest.dependencies {
            implementation(kotlin("test"))            // kotlin.test.Test — NOT org.junit.Test (D-17 / Pitfall 18)
            implementation(libs.kotlinx.coroutines.test)
            implementation(libs.turbine)
            implementation(libs.kotest.assertions.core)
        }
    }
}

sqldelight {
    databases {
        create("AppDatabase") {
            packageName.set("dev.viethung.core.db")
            // .sq files live in src/commonMain/sqldelight/dev/viethung/core/db/
        }
    }
}

// vanniktech maven-publish dry-run wiring (D-06)
// No signing key required — publishToMavenLocal only; real Central publish in Phase 7
mavenPublishing {
    coordinates(
        groupId    = "dev.viethung",
        artifactId = "shared-core",
        version    = "0.1.0-SNAPSHOT",
    )
    pom {
        name.set("Skeleton Shared Core")
        description.set("KMP shared core module — DI, networking, persistence, base repos")
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

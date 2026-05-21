plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kmp.library)
    alias(libs.plugins.kotlinx.atomicfu)
    alias(libs.plugins.vanniktech.publish)
}

// atomicfu Gradle plugin creates a 'transformAndroidMainAtomicfu' task that depends on
// 'androidMainClasses', which does not exist in AGP 9.x's KMP android target.
// Kotlin IR mode (used since Kotlin 2.x) handles atomicfu transformation automatically at
// the compiler level, so the separate Gradle transformation is unnecessary for all variants.
// Disable JVM/Android bytecode transformation to avoid the spurious task dependency.
atomicfu {
    transformJvm = false
}

kotlin {
    android {
        namespace = "dev.viethung.skylog"
        compileSdk = 36
        minSdk = 23
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
        }
    }

    jvm {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
        }
    }

    listOf(
        iosArm64(),
        iosX64(),
        iosSimulatorArm64(),
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "SkylogCore"
        }
    }

    sourceSets {
        commonMain.dependencies {
            api(libs.kotlinx.coroutines.core)
            api(libs.kotlinx.datetime)
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
            implementation(libs.kotlinx.coroutines.test)
            implementation(libs.turbine)
            implementation(libs.kotest.assertions.core)
        }
    }
}

mavenPublishing {
    coordinates(
        groupId    = "dev.viethung",
        artifactId = "skylog-core",
        version    = "0.1.0-SNAPSHOT",
    )
    pom {
        name.set("Skylog Core")
        description.set("KMP logging engine — Skylog facade, Logger, InMemoryLogWriter, platform default writers")
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

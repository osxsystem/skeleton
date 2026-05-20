pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "skeleton"

include(
    ":shared-core",
    ":shared-components",
    ":shared-app",
    ":androidApp",
    ":server",
    ":number-input",
)

// The reference checkout directory for AndroidX/Compose source code is intentionally
// excluded — it is not a Gradle project module and must not be included here.

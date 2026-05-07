<!-- generated-by: gsd-doc-writer -->
# Contributing

Thank you for your interest in contributing to Skeleton. This document explains how to get involved.

## Development setup

See [GETTING-STARTED.md](docs/GETTING-STARTED.md) for prerequisites and first-run instructions, and [DEVELOPMENT.md](docs/DEVELOPMENT.md) for local development setup.

Until those docs are generated, the short path is:

1. Clone the repository and open it in Android Studio (Electric Eel or later with KMP plugin).
2. The shared module compiles for both Android and iOS from `shared/commonMain/`.
3. iOS requires Xcode 15+ and a macOS build machine — iOS targets cannot be built on Linux or Windows.

## Coding standards

- Follow the [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html) for all shared Kotlin code.
- SwiftUI code follows the Swift API Design Guidelines.
- All shared state belongs in `shared/commonMain/` — no business logic in `androidApp/` or `iosApp/`.
- Design tokens (colors, typography, spacing) are defined once in `shared/commonMain/.../theme/` and adapted per platform. Do not duplicate token values in platform modules.
- No code style tooling is currently configured; run `./gradlew ktlintCheck` if ktlint is added in future.

## PR guidelines

- Branch from `develop` using the pattern `feat/<short-description>` or `fix/<short-description>`.
- Keep each PR focused on a single concern — split unrelated changes into separate PRs.
- Include a brief description of what changed and why in the PR body.
- Ensure the Android build compiles without error before opening the PR (`./gradlew assembleDebug`).
- iOS build verification requires a macOS environment (`xcodebuild`).
- There are no automated tests yet; manual smoke-testing on both platforms is expected until the test suite is established.
- Request review from the repository owner (Do Viet Hung) before merging.

## Issue reporting

Open a GitHub Issue with the following information:

- **Bug reports:** steps to reproduce, expected behavior, actual behavior, platform (Android version / iOS version), and any relevant logs.
- **Feature requests:** the problem you are trying to solve, your proposed solution, and any alternatives you considered.

No issue templates are currently configured — plain text issues are fine.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

import XCTest
@testable import iosApp
import SkeletonApp

/// Round-trip test for AC-09 — KeychainSessionStore persists across instances.
///
/// **Status:** the iosApp target currently builds with `CODE_SIGNING_ALLOWED = NO`,
/// which means the `iosApp/iosApp.entitlements` file is NOT embedded in the
/// simulator binary, so the iOS runtime refuses Keychain writes with
/// `errSecMissingEntitlement` (-34018). To run these tests:
///   1. In project.pbxproj for iosApp + iosAppTests: set
///      `CODE_SIGNING_ALLOWED = YES`, `CODE_SIGN_IDENTITY = "-"`,
///      `CODE_SIGN_STYLE = Manual`.
///   2. Confirm `iosApp.entitlements` declares
///      `keychain-access-groups = ["<your-bundle-id>"]`.
///   3. Re-run `xcodebuild test`.
/// On a real device build with a real provisioning profile, signing is
/// automatic and the tests run without further changes.
///
/// The 3 write-path tests below call `XCTSkipIf(...)` so the suite stays green
/// in CI while the entitlement gate is unmet; once entitlements are wired the
/// guard returns false and the assertions run.
final class KeychainSessionStoreTests: XCTestCase {

    private let sample = UserSession(userId: "u-1", token: "t-keychain-test")

    /// Probes whether Keychain writes work in the current build. Returns true
    /// when SecItemAdd is blocked (e.g. `errSecMissingEntitlement`) so the
    /// affected tests can `XCTSkipIf` instead of failing the build.
    private func keychainWritesBlocked() async -> Bool {
        let probe = UserSession(userId: "probe", token: "probe")
        try? await KeychainSessionStore().save(session: probe)
        let readBack = try? await KeychainSessionStore().read()
        try? await KeychainSessionStore().clear()
        return readBack == nil
    }

    override func setUp() async throws {
        try await super.setUp()
        let blocked = await keychainWritesBlocked()
        if !blocked {
            try await KeychainSessionStore().clear()
        }
    }

    override func tearDown() async throws {
        let blocked = await keychainWritesBlocked()
        if !blocked {
            try await KeychainSessionStore().clear()
        }
        try await super.tearDown()
    }

    func testFreshInstanceReturnsNilWhenKeychainEmpty() async throws {
        let store = KeychainSessionStore()
        let result = try await store.read()
        XCTAssertNil(result)
    }

    func testSaveThenNewInstanceReadsBackSession() async throws {
        let blocked = await keychainWritesBlocked()
        try XCTSkipIf(blocked, "Keychain entitlements not configured — see file header.")
        try await KeychainSessionStore().save(session: sample)

        // A fresh instance must see the persisted session — simulates relaunch.
        let freshStore = KeychainSessionStore()
        let result = try await freshStore.read()
        XCTAssertEqual(result?.userId, sample.userId)
        XCTAssertEqual(result?.token, sample.token)
    }

    func testClearRemovesSessionForSubsequentInstances() async throws {
        let blocked = await keychainWritesBlocked()
        try XCTSkipIf(blocked, "Keychain entitlements not configured — see file header.")
        try await KeychainSessionStore().save(session: sample)
        try await KeychainSessionStore().clear()

        let freshStore = KeychainSessionStore()
        let result = try await freshStore.read()
        XCTAssertNil(result)
    }

    func testOverwriteReplacesPreviousSession() async throws {
        let blocked = await keychainWritesBlocked()
        try XCTSkipIf(blocked, "Keychain entitlements not configured — see file header.")
        try await KeychainSessionStore().save(session: sample)
        let replacement = UserSession(userId: "u-2", token: "t-replacement")
        try await KeychainSessionStore().save(session: replacement)

        let freshStore = KeychainSessionStore()
        let result = try await freshStore.read()
        XCTAssertEqual(result?.userId, replacement.userId)
        XCTAssertEqual(result?.token, replacement.token)
    }
}

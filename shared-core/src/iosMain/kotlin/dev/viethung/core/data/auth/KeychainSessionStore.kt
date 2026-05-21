package dev.viethung.core.data.auth

import dev.viethung.core.data.remote.auth.UserSession
import kotlinx.cinterop.BetaInteropApi
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.alloc
import kotlinx.cinterop.convert
import kotlinx.cinterop.interpretCPointer
import kotlinx.cinterop.interpretObjCPointerOrNull
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.objcPtr
import kotlinx.cinterop.ptr
import kotlinx.cinterop.usePinned
import kotlinx.cinterop.value
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json
import platform.CoreFoundation.CFDictionaryRef
import platform.CoreFoundation.CFStringRef
import platform.CoreFoundation.CFTypeRefVar
import platform.CoreFoundation.kCFBooleanTrue
import platform.Foundation.NSData
import platform.Foundation.NSMutableDictionary
import platform.Foundation.NSNumber
import platform.Foundation.NSString
import platform.Foundation.NSUTF8StringEncoding
import platform.Foundation.create
import platform.Foundation.dataUsingEncoding
import platform.Security.SecItemAdd
import platform.Security.SecItemCopyMatching
import platform.Security.SecItemDelete
import platform.Security.errSecSuccess
import platform.Security.kSecAttrAccessible
import platform.Security.kSecAttrAccessibleAfterFirstUnlock
import platform.Security.kSecAttrAccount
import platform.Security.kSecAttrService
import platform.Security.kSecClass
import platform.Security.kSecClassGenericPassword
import platform.Security.kSecMatchLimit
import platform.Security.kSecMatchLimitOne
import platform.Security.kSecReturnData
import platform.Security.kSecUseDataProtectionKeychain
import platform.Security.kSecValueData

@OptIn(ExperimentalForeignApi::class, BetaInteropApi::class)
class KeychainSessionStore : SessionStore {

    private val _session = MutableStateFlow(readFromKeychain())
    override val session: StateFlow<UserSession?> = _session.asStateFlow()

    override suspend fun save(session: UserSession) {
        val payload = json.encodeToString(session)
        val data = stringToNs(payload).dataUsingEncoding(NSUTF8StringEncoding) ?: return
        deleteEntry()
        val attrs = baseQuery().apply {
            setObject(data, forKey = ns(kSecValueData))
            setObject(ns(kSecAttrAccessibleAfterFirstUnlock), forKey = ns(kSecAttrAccessible))
        }
        val status = SecItemAdd(attrs.toCF(), null)
        if (status == errSecSuccess) {
            _session.value = session
        }
        // On non-success (e.g. errSecMissingEntitlement in a test runner with no entitlements),
        // we silently no-op. Callers can verify success via read() returning the saved value.
    }

    override suspend fun read(): UserSession? = _session.value

    override suspend fun clear() {
        deleteEntry()
        _session.value = null
    }

    private fun readFromKeychain(): UserSession? {
        val query = baseQuery().apply {
            setObject(asNumber(kCFBooleanTrue!!), forKey = ns(kSecReturnData))
            setObject(ns(kSecMatchLimitOne), forKey = ns(kSecMatchLimit))
        }
        return memScoped {
            val resultRef = alloc<CFTypeRefVar>()
            val status = SecItemCopyMatching(query.toCF(), resultRef.ptr)
            if (status != errSecSuccess) return@memScoped null
            val cf = resultRef.value ?: return@memScoped null
            val data = interpretObjCPointerOrNull<NSData>(cf.rawValue) ?: return@memScoped null
            val ns = NSString.create(data, NSUTF8StringEncoding) ?: return@memScoped null
            runCatching { json.decodeFromString<UserSession>(ns.toString()) }.getOrNull()
        }
    }

    private fun deleteEntry() {
        SecItemDelete(baseQuery().toCF())
    }

    private fun baseQuery(): NSMutableDictionary = NSMutableDictionary().apply {
        setObject(ns(kSecClassGenericPassword), forKey = ns(kSecClass))
        setObject(stringToNs(SERVICE), forKey = ns(kSecAttrService))
        setObject(stringToNs(ACCOUNT), forKey = ns(kSecAttrAccount))
        // Use the modern data-protection keychain — works in unit-test binaries that lack a host bundle.
        setObject(asNumber(kCFBooleanTrue!!), forKey = ns(kSecUseDataProtectionKeychain))
    }

    private fun ns(cf: CFStringRef?): NSString =
        interpretObjCPointerOrNull<NSString>(cf!!.rawValue)!!

    private fun asNumber(cf: platform.CoreFoundation.CFBooleanRef): NSNumber =
        interpretObjCPointerOrNull<NSNumber>(cf.rawValue)!!

    private fun NSMutableDictionary.toCF(): CFDictionaryRef =
        interpretCPointer(this.objcPtr())!!

    private fun stringToNs(s: String): NSString {
        val bytes = s.encodeToByteArray()
        return bytes.usePinned { pinned ->
            val data = NSData.create(
                bytes = pinned.addressOf(0),
                length = bytes.size.convert(),
            )
            NSString.create(data, NSUTF8StringEncoding)
        } ?: error("UTF-8 decode failed in stringToNs")
    }

    private companion object {
        const val SERVICE = "dev.viethung.skeleton.auth"
        const val ACCOUNT = "current"
        val json: Json = Json
    }
}

import Foundation
import CryptoKit
import IOKit
import Security
import Darwin

/// A local, per-installation AES-256 key. The key never enters the login keychain,
/// so rebuilding the self-signed app cannot trigger a keychain access prompt.
/// The hardware UUID is mixed into the derived key to make copied vault files
/// unreadable on another Mac; the random seed remains the actual secret.
struct ClipboardVault: Sendable {
    enum VaultError: Error { case invalidKey, unavailableKey, invalidCiphertext }

    private let key: SymmetricKey

    init(directory: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let keyURL = directory.appendingPathComponent("clipboard.key")
        let seed: Data
        if manager.fileExists(atPath: keyURL.path) {
            seed = try Data(contentsOf: keyURL)
        } else {
            var bytes = [UInt8](repeating: 0, count: 32)
            let randomStatus = bytes.withUnsafeMutableBytes { raw in
                SecRandomCopyBytes(kSecRandomDefault, raw.count, raw.baseAddress!)
            }
            guard randomStatus == errSecSuccess else {
                throw VaultError.unavailableKey
            }
            let fd = Darwin.open(keyURL.path, O_CREAT | O_EXCL | O_WRONLY, 0o600)
            if fd >= 0 {
                let written = bytes.withUnsafeBytes { raw -> Int in
                    var offset = 0
                    while offset < raw.count {
                        let count = Darwin.write(fd, raw.baseAddress!.advanced(by: offset), raw.count - offset)
                        if count < 0 && errno == EINTR { continue }
                        if count <= 0 { break }
                        offset += count
                    }
                    return offset
                }
                Darwin.close(fd)
                guard written == bytes.count else {
                    try? manager.removeItem(at: keyURL)
                    throw VaultError.unavailableKey
                }
                seed = Data(bytes)
            } else if errno == EEXIST {
                seed = try Data(contentsOf: keyURL)
            } else {
                throw VaultError.unavailableKey
            }
        }
        guard seed.count == 32 else { throw VaultError.invalidKey }
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        guard let hardwareID = Self.hardwareUUID(), !hardwareID.isEmpty else {
            throw VaultError.unavailableKey
        }
        key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: seed),
                                     salt: Data(hardwareID.utf8),
                                     info: Data("HyperMac Clipboard AES-GCM v1".utf8),
                                     outputByteCount: 32)
    }

    func seal(_ plain: Data, context: String) throws -> Data {
        let box = try AES.GCM.seal(plain, using: key, authenticating: Data(context.utf8))
        guard let combined = box.combined else { throw VaultError.invalidCiphertext }
        return combined
    }

    func open(_ cipher: Data, context: String) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: cipher)
        return try AES.GCM.open(box, using: key, authenticating: Data(context.utf8))
    }

    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString,
                                               kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
    }
}

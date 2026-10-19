import CryptoKit
import Foundation
import Security

struct SigningSetupError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func requireSuccess(_ status: OSStatus, _ operation: String) throws {
    guard status == errSecSuccess else {
        let reason = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        throw SigningSetupError(message: "\(operation): \(reason)")
    }
}

func runOpenSSL(_ arguments: [String], input: Data? = nil) throws -> Data {
    let process = Process()
    let output = Pipe()
    let standardInput = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    process.standardInput = input == nil ? FileHandle.nullDevice : standardInput.fileHandleForReading
    try process.run()
    if let input {
        try standardInput.fileHandleForWriting.write(contentsOf: input)
        try standardInput.fileHandleForWriting.close()
    }
    let result = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw SigningSetupError(message: "OpenSSL \(arguments.first ?? "operation") failed (\(process.terminationStatus)); no key material was logged.")
    }
    return result
}

func existingIdentity(in keychain: SecKeychain) throws -> SecIdentity? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassIdentity,
        kSecMatchSearchList as String: [keychain],
        kSecMatchLimit as String: kSecMatchLimitAll,
        kSecReturnRef as String: true
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    try requireSuccess(status, "Look up signing identities")
    let matches = try (result as? [SecIdentity] ?? []).filter { identity in
        var certificate: SecCertificate?
        try requireSuccess(SecIdentityCopyCertificate(identity, &certificate), "Read identity certificate")
        return certificate.map { SecCertificateCopySubjectSummary($0) as String? == "Altdock" } ?? false
    }
    guard matches.count <= 1 else { throw SigningSetupError(message: "Multiple Altdock identities exist; refusing to select or replace one automatically.") }
    return matches.first
}

func rejectPartialIdentity(in keychain: SecKeychain) throws {
    for itemClass in [kSecClassCertificate, kSecClassKey] {
        let query: [String: Any] = [
            kSecClass as String: itemClass,
            kSecAttrLabel as String: "Altdock",
            kSecMatchSearchList as String: [keychain],
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        guard status == errSecItemNotFound else {
            throw SigningSetupError(message: "An Altdock Keychain item already exists without a matching identity, or lookup failed (\(status)). Nothing was replaced.")
        }
    }
}

func createIdentity(in keychain: SecKeychain) throws -> SecIdentity {
    try rejectPartialIdentity(in: keychain)
    let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("tmp-workspaces/\(UUID().uuidString)/tmp")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
    let configuration = directory.appendingPathComponent("code-signing.cnf")
    try """
    [req]
    distinguished_name = subject
    x509_extensions = code_signing
    prompt = no
    [subject]
    CN = Altdock
    [code_signing]
    basicConstraints = critical,CA:FALSE
    keyUsage = critical,digitalSignature
    extendedKeyUsage = critical,codeSigning
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid
    """.write(to: configuration, atomically: true, encoding: .utf8)
    var serial = [UInt8](repeating: 0, count: 20)
    try requireSuccess(SecRandomCopyBytes(kSecRandomDefault, serial.count, &serial), "Generate certificate serial")
    serial[0] = (serial[0] & 0x7f) | 0x01
    let serialHex = serial.map { String(format: "%02x", $0) }.joined()
    let now = Date()
    let calendar = Calendar(identifier: .gregorian)
    let expiry = calendar.date(byAdding: .year, value: 10, to: now)!
    let days = calendar.dateComponents([.day], from: now, to: expiry).day!
    let privateKey = try runOpenSSL(["genrsa", "3072"])
    let certificate = try runOpenSSL([
        "req", "-new", "-x509", "-sha256", "-days", String(days),
        "-set_serial", "0x\(serialHex)", "-key", "/dev/stdin", "-config", configuration.path
    ], input: privateKey)
    var trustedApplication: SecTrustedApplication?
    try requireSuccess(SecTrustedApplicationCreateFromPath("/usr/bin/codesign", &trustedApplication), "Authorize codesign")
    var access: SecAccess?
    try requireSuccess(SecAccessCreate("Altdock" as CFString, [trustedApplication!] as CFArray, &access), "Create key access controls")
    let usage = [kSecAttrCanSign] as CFArray
    let attributes = [kSecAttrIsPermanent, kSecAttrIsSensitive, kSecAttrIsExtractable] as CFArray
    var parameters = SecItemImportExportKeyParameters()
    parameters.version = UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION)
    parameters.accessRef = .passUnretained(access!)
    parameters.keyUsage = .passUnretained(usage)
    parameters.keyAttributes = .passUnretained(attributes)
    var format = SecExternalFormat.formatPEMSequence
    var itemType = SecExternalItemType.itemTypeAggregate
    var imported: CFArray?
    let combined = privateKey + certificate
    let status = withExtendedLifetime((access, usage, attributes)) {
        SecItemImport(combined as CFData, "Altdock.pem" as CFString, &format, &itemType, [], &parameters, keychain, &imported)
    }
    try requireSuccess(status, "Import Altdock certificate and exportable private key into login Keychain")
    guard let identity = try existingIdentity(in: keychain) else { throw SigningSetupError(message: "Import did not produce a matching Altdock identity. No replacement key was generated.") }
    return identity
}

func hasCodeSigningOnlyTrust(_ certificate: SecCertificate) -> Bool {
    var result: CFArray?
    guard SecTrustSettingsCopyTrustSettings(certificate, .user, &result) == errSecSuccess,
          let rules = result as? [[String: Any]], rules.count == 1,
          let rule = rules.first,
          let policyValue = rule[kSecTrustSettingsPolicy as String],
          CFGetTypeID(policyValue as CFTypeRef) == SecPolicyGetTypeID(),
          let properties = SecPolicyCopyProperties(policyValue as! SecPolicy) as? [String: Any]
    else { return false }
    return properties[kSecPolicyOid as String] as? String == kSecPolicyAppleCodeSigning as String
        && (rule[kSecTrustSettingsResult as String] as? NSNumber)?.uint32Value == SecTrustSettingsResult.trustRoot.rawValue
}

func configureIdentity(_ identity: SecIdentity) throws {
    var key: SecKey?
    var certificate: SecCertificate?
    try requireSuccess(SecIdentityCopyPrivateKey(identity, &key), "Locate private key")
    try requireSuccess(SecIdentityCopyCertificate(identity, &certificate), "Locate certificate")
    guard let key, let certificate else { throw SigningSetupError(message: "Incomplete signing identity") }
    try requireSuccess(SecItemUpdate(
        [kSecClass as String: kSecClassKey, kSecValueRef as String: key] as CFDictionary,
        [kSecAttrLabel as String: "Altdock"] as CFDictionary
    ), "Name the private key Altdock")
    let attributes = SecKeyCopyAttributes(key) as? [String: Any] ?? [:]
    guard attributes[kSecAttrIsExtractable as String] as? Bool == true else {
        throw SigningSetupError(message: "The private key is not exportable; the identity was not replaced.")
    }
    guard let policy = SecPolicyCreateWithProperties(kSecPolicyAppleCodeSigning, nil) else {
        throw SigningSetupError(message: "Code-signing trust policy unavailable")
    }
    let rule: [String: Any] = [
        kSecTrustSettingsPolicy as String: policy,
        kSecTrustSettingsResult as String: NSNumber(value: SecTrustSettingsResult.trustRoot.rawValue)
    ]
    if !hasCodeSigningOnlyTrust(certificate) {
        print("Certificate and key are installed. Waiting for macOS approval of user-only code-signing trust…")
        fflush(stdout)
        try requireSuccess(SecTrustSettingsSetTrustSettings(certificate, .user, [rule] as CFArray), "Set user-only code-signing trust")
    }
    let fingerprint = Insecure.SHA1.hash(data: SecCertificateCopyData(certificate) as Data).map { String(format: "%02X", $0) }.joined()
    print("Identity: Altdock")
    print("Keychain: login")
    print("Certificate SHA-1: \(fingerprint)")
    print("Private key: RSA 3072, exportable; automatic key access restricted to /usr/bin/codesign")
    print("Trust: code signing only, user domain")
    print("No certificate/private-key backup files were created. No Altdock binary was rebuilt or re-signed.")
}

if !CommandLine.arguments.contains("--create") {
    print("Usage: swift -suppress-warnings scripts/create-signing-identity.swift --create")
    print("Creates or reuses the Altdock identity in the login Keychain. macOS may request Keychain/trust approval.")
    exit(0)
}

do {
    let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Keychains/login.keychain-db").path
    var keychain: SecKeychain?
    try requireSuccess(SecKeychainOpen(path, &keychain), "Open login Keychain")
    guard let keychain else { throw SigningSetupError(message: "Login Keychain unavailable") }
    let identity = try existingIdentity(in: keychain) ?? createIdentity(in: keychain)
    try configureIdentity(identity)
} catch {
    fputs("Signing setup failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}

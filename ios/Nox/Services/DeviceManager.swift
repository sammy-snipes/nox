import Foundation
import Security
import SwiftUI

class DeviceManager: ObservableObject {
    @Published var deviceToken: String
    @Published var isRegistered: Bool = false
    @Published var isEnrolled: Bool = false

    private static let keychainKey = "com.nox.device_token"

    init() {
        if let existing = Self.readFromKeychain() {
            deviceToken = existing
        } else {
            let newToken = UUID().uuidString.lowercased()
            Self.saveToKeychain(newToken)
            deviceToken = newToken
        }
    }

    func register() async {
        do {
            let response = try await APIClient.shared.registerDevice(deviceToken: deviceToken)
            await MainActor.run {
                isRegistered = true
                isEnrolled = response.enrolled
            }
        } catch {
            print("device registration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Keychain

    private static func saveToKeychain(_ value: String) {
        deleteFromKeychain()
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

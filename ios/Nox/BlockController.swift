import Foundation
import Combine
import FamilyControls
import ManagedSettings

/// Core of nox. Everything is on-device:
/// - FamilyControls for Screen Time authorization + the app/website picker
/// - ManagedSettings to actually shield the chosen apps at the OS level
///
/// No network, no account, no server. The selection and blocking state live
/// in UserDefaults; the shield lives in a ManagedSettingsStore.
@MainActor
final class BlockController: ObservableObject {
    enum AuthState { case unknown, denied, approved }

    @Published var authState: AuthState = .unknown
    @Published var selection = FamilyActivitySelection()
    @Published var isBlocking = false

    private let store = ManagedSettingsStore(named: .nox)
    private let defaults = UserDefaults.standard
    private let selectionKey = "nox.selection"
    private let blockingKey = "nox.isBlocking"

    init() {
        loadSelection()
        isBlocking = defaults.bool(forKey: blockingKey)
        refreshAuth()
    }

    // MARK: - Authorization

    func refreshAuth() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: authState = .approved
        case .denied: authState = .denied
        default: authState = .unknown
        }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuth()
        } catch {
            authState = .denied
        }
    }

    // MARK: - Selection

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        if let data = try? JSONEncoder().encode(newSelection) {
            defaults.set(data, forKey: selectionKey)
        }
        // If a block is live, re-apply so edits take effect immediately.
        if isBlocking { applyShield() }
    }

    private func loadSelection() {
        guard let data = defaults.data(forKey: selectionKey),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = decoded
    }

    // MARK: - Blocking

    func startBlocking() {
        applyShield()
        isBlocking = true
        defaults.set(true, forKey: blockingKey)
    }

    func stopBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        isBlocking = false
        defaults.set(false, forKey: blockingKey)
    }

    private func applyShield() {
        store.shield.applications =
            selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories =
            selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains =
            selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories =
            selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }
}

extension ManagedSettingsStore.Name {
    static let nox = Self("nox")
}

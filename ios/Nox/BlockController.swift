import Foundation
import Combine
import FamilyControls
import ManagedSettings

/// Core of nox. Everything is on-device:
/// - FamilyControls for Screen Time authorization + the app picker
/// - ManagedSettings to shield the chosen apps and filter the typed domains
///
/// No network, no account, no server. State lives in UserDefaults; the block
/// lives in a ManagedSettingsStore.
@MainActor
final class BlockController: ObservableObject {
    enum AuthState { case unknown, denied, approved }

    @Published var authState: AuthState = .unknown
    @Published var hasGrantedOnce = false
    @Published var selection = FamilyActivitySelection()
    @Published var blockedDomains: [String] = []
    @Published var isBlocking = false

    /// How long a turn-off takes once you start it.
    @Published var unlockDelayMinutes: Int = 5
    /// When the current turn-off was started (nil = no turn-off in progress).
    @Published var unlockStartedAt: Date?

    private let store = ManagedSettingsStore(named: .nox)
    private let defaults = UserDefaults.standard

    private enum Key {
        static let selection = "nox.selection"
        static let domains = "nox.domains"
        static let blocking = "nox.isBlocking"
        static let delay = "nox.delayMinutes"
        static let unlockStartedAt = "nox.unlockStartedAt"
        static let granted = "nox.granted"
    }

    init() {
        loadSelection()
        blockedDomains = defaults.stringArray(forKey: Key.domains) ?? []
        isBlocking = defaults.bool(forKey: Key.blocking)
        unlockDelayMinutes = defaults.object(forKey: Key.delay) as? Int ?? 5
        unlockStartedAt = defaults.object(forKey: Key.unlockStartedAt) as? Date
        hasGrantedOnce = defaults.bool(forKey: Key.granted)
        refreshAuth()
    }

    // MARK: - Authorization

    func refreshAuth() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            authState = .approved
            if !hasGrantedOnce {
                hasGrantedOnce = true
                defaults.set(true, forKey: Key.granted)
            }
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

    // MARK: - Apps

    var appCount: Int { selection.applicationTokens.count }
    var categoryCount: Int { selection.categoryTokens.count }

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        if let data = try? JSONEncoder().encode(newSelection) {
            defaults.set(data, forKey: Key.selection)
        }
        if isBlocking { applyShield() }
    }

    private func loadSelection() {
        guard let data = defaults.data(forKey: Key.selection),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = decoded
    }

    // MARK: - Domains

    func addDomain(_ raw: String) {
        let domain = normalize(raw)
        guard !domain.isEmpty, !blockedDomains.contains(domain) else { return }
        blockedDomains.append(domain)
        defaults.set(blockedDomains, forKey: Key.domains)
        if isBlocking { applyShield() }
    }

    func removeDomain(_ domain: String) {
        blockedDomains.removeAll { $0 == domain }
        defaults.set(blockedDomains, forKey: Key.domains)
        if isBlocking { applyShield() }
    }

    private func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://", "www."] where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
        }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        return s
    }

    var hasSomethingToBlock: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !blockedDomains.isEmpty
    }

    // MARK: - On / off

    func startBlocking() {
        applyShield()
        isBlocking = true
        defaults.set(true, forKey: Key.blocking)
    }

    private func applyShield() {
        store.shield.applications =
            selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories =
            selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains =
            selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if blockedDomains.isEmpty {
            store.webContent.blockedByFilter = nil
        } else {
            let domains = Set(blockedDomains.map { WebDomain(domain: $0) })
            store.webContent.blockedByFilter = .auto(domains, except: [])
        }

        // hardening while a block is live (cleared on turn-off):
        store.application.denyAppRemoval = true                // can't delete apps to escape
        store.dateAndTime.requireAutomaticDateAndTime = true   // can't fast-forward the clock past the timer
    }

    private func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.webContent.blockedByFilter = nil
        store.application.denyAppRemoval = nil
        store.dateAndTime.requireAutomaticDateAndTime = nil
    }

    // MARK: - Turn-off delay

    var unlockReadyAt: Date? {
        unlockStartedAt?.addingTimeInterval(TimeInterval(unlockDelayMinutes * 60))
    }

    var isUnlockPending: Bool { unlockStartedAt != nil }

    func setDelay(_ minutes: Int) {
        guard !isBlocking else { return }   // can't shorten the wait mid-block
        unlockDelayMinutes = minutes
        defaults.set(minutes, forKey: Key.delay)
    }

    /// Start the turn-off countdown. Timestamp persists, so closing the app
    /// doesn't dodge the wait.
    func beginUnlock() {
        guard isBlocking, unlockStartedAt == nil else { return }
        let now = Date()
        unlockStartedAt = now
        defaults.set(now, forKey: Key.unlockStartedAt)
    }

    /// Abandon the turn-off. Next attempt starts the full wait over.
    func cancelUnlock() {
        unlockStartedAt = nil
        defaults.removeObject(forKey: Key.unlockStartedAt)
    }

    /// Finish turning off — only valid once the delay has elapsed.
    func completeUnlock() {
        guard let ready = unlockReadyAt, Date() >= ready else { return }
        clearShield()
        isBlocking = false
        defaults.set(false, forKey: Key.blocking)
        cancelUnlock()
    }
}

extension ManagedSettingsStore.Name {
    static let nox = Self("nox")
}

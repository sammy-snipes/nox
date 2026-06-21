import SwiftUI

struct BlocklistView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var domains: [BlockedDomain] = []
    @State private var apps: [BlockedApp] = []
    @State private var activeSession: BlockSession?
    @State private var showAddDomain = false
    @State private var showAddApp = false
    @State private var showUnblock = false
    @State private var showSettings = false
    @State private var pendingRemoveDomain: BlockedDomain?
    @State private var pendingRemoveApp: BlockedApp?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                // Domains section
                Section {
                    ForEach(domains) { domain in
                        HStack {
                            Text(domain.domain)
                                .font(Theme.mono(.body))
                                .foregroundColor(Theme.text)
                            Spacer()
                            Button(action: {
                                if activeSession != nil {
                                    pendingRemoveDomain = domain
                                    showUnblock = true
                                } else {
                                    removeDomain(domain)
                                }
                            }) {
                                Text("[x]")
                                    .font(Theme.mono(.body))
                                    .foregroundColor(Theme.text)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Theme.background)
                        .listRowSeparatorTint(Theme.border)
                    }

                    Button(action: { showAddDomain = true }) {
                        Text("+ add domain")
                            .font(Theme.mono(.body))
                            .foregroundColor(Theme.text)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.border)
                } header: {
                    Text("blocked domains")
                        .font(Theme.mono(.caption))
                        .foregroundColor(Theme.text)
                        .textCase(nil)
                }

                // Apps section
                Section {
                    ForEach(apps) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.displayName)
                                    .font(Theme.mono(.body))
                                    .foregroundColor(Theme.text)
                                Text(app.bundleId)
                                    .font(Theme.mono(.caption2))
                                    .foregroundColor(Theme.text)
                            }
                            Spacer()
                            Button(action: {
                                if activeSession != nil {
                                    pendingRemoveApp = app
                                    showUnblock = true
                                } else {
                                    removeApp(app)
                                }
                            }) {
                                Text("[x]")
                                    .font(Theme.mono(.body))
                                    .foregroundColor(Theme.text)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Theme.background)
                        .listRowSeparatorTint(Theme.border)
                    }

                    Button(action: { showAddApp = true }) {
                        Text("+ add app")
                            .font(Theme.mono(.body))
                            .foregroundColor(Theme.text)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.border)
                } header: {
                    Text("blocked apps")
                        .font(Theme.mono(.caption))
                        .foregroundColor(Theme.text)
                        .textCase(nil)
                }

                // Session section
                Section {
                    if let session = activeSession, session.isActive {
                        Button(action: { showUnblock = true }) {
                            Text("[ unblock ]")
                                .font(Theme.mono(.body))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.background)
                    } else {
                        Button(action: { activateSession() }) {
                            Text("[ activate ]")
                                .font(Theme.mono(.body))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.background)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .font(Theme.mono(.caption))
                            .foregroundColor(Theme.text)
                            .listRowBackground(Theme.background)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .refreshable {
                await loadData()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("nox")
                        .font(Theme.mono(.title2))
                        .foregroundColor(Theme.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Text(">")
                            .font(Theme.mono(.body))
                            .foregroundColor(Theme.text)
                    }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showAddDomain) {
                AddDomainView(onAdded: { Task { await loadData() } })
            }
            .sheet(isPresented: $showAddApp) {
                AddAppView(onAdded: { Task { await loadData() } })
            }
            .navigationDestination(isPresented: $showUnblock) {
                if let session = activeSession {
                    UnblockView(session: session, onUnblocked: {
                        Task { await loadData() }
                    })
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        do {
            let blocklist = try await APIClient.shared.getBlocklist()
            let session = try await APIClient.shared.getActiveSession()
            await MainActor.run {
                domains = blocklist.domains
                apps = blocklist.apps
                activeSession = session
                error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }

    private func removeDomain(_ domain: BlockedDomain) {
        Task {
            do {
                try await APIClient.shared.removeDomain(id: domain.id)
                await loadData()
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func removeApp(_ app: BlockedApp) {
        Task {
            do {
                try await APIClient.shared.removeApp(id: app.id)
                await loadData()
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func activateSession() {
        Task {
            do {
                let session = try await APIClient.shared.startSession(endsAt: nil, unlockMethod: "type_to_unlock")
                await MainActor.run {
                    activeSession = session
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

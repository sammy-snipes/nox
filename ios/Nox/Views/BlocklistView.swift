import SwiftUI
import FamilyControls

struct BlocklistView: View {
    @EnvironmentObject var controller: BlockController
    @State private var showPicker = false
    @State private var showAddDomain = false
    @State private var showUnblock = false
    @State private var showSettings = false

    private var locked: Bool { controller.isBlocking }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    appsSection
                    domainsSection
                }
                .padding(24)
            }
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) { actionBar }
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
            .familyActivityPicker(
                isPresented: $showPicker,
                selection: Binding(
                    get: { controller.selection },
                    set: { controller.saveSelection($0) }
                )
            )
            .sheet(isPresented: $showAddDomain) { AddDomainView() }
            .navigationDestination(isPresented: $showUnblock) { UnblockView() }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: Sections

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("blocked apps")
            row("apps", controller.appCount)
            row("categories", controller.categoryCount)
            Button(action: { if !locked { showPicker = true } }) {
                Text(locked ? "edit (locked while on)" : "+ choose apps")
                    .font(Theme.mono(.body))
                    .foregroundColor(Theme.text)
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .opacity(locked ? 0.4 : 1)
        }
    }

    private var domainsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("blocked domains")
            if controller.blockedDomains.isEmpty {
                Text("none")
                    .font(Theme.mono(.body))
                    .foregroundColor(Theme.text)
                    .opacity(0.4)
            } else {
                ForEach(controller.blockedDomains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                            .font(Theme.mono(.body))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Button(action: { controller.removeDomain(domain) }) {
                            Text("[x]")
                                .font(Theme.mono(.body))
                                .foregroundColor(Theme.text)
                        }
                        .buttonStyle(.plain)
                        .disabled(locked)
                        .opacity(locked ? 0.3 : 1)
                    }
                }
            }
            Button(action: { if !locked { showAddDomain = true } }) {
                Text(locked ? "+ add domain (locked while on)" : "+ add domain")
                    .font(Theme.mono(.body))
                    .foregroundColor(Theme.text)
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .opacity(locked ? 0.4 : 1)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle().frame(height: 1).foregroundColor(Theme.border)
            Group {
                if controller.isBlocking {
                    actionButton(controller.isUnlockPending ? "[ resume turn-off ]" : "[ turn off ]") {
                        showUnblock = true
                    }
                } else {
                    actionButton("[ turn on ]") { controller.startBlocking() }
                        .disabled(!controller.hasSomethingToBlock)
                        .opacity(controller.hasSomethingToBlock ? 1 : 0.3)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
    }

    // MARK: Helpers

    private func header(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.mono(.caption))
                .foregroundColor(Theme.text)
            Rectangle().frame(height: 1).foregroundColor(Theme.border)
        }
    }

    private func row(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label)
                .font(Theme.mono(.body))
                .foregroundColor(Theme.text)
            Spacer()
            Text("\(count)")
                .font(Theme.mono(.body))
                .foregroundColor(Theme.text)
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .terminalButton()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

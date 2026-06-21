import SwiftUI
import FamilyControls

struct BlocklistView: View {
    @EnvironmentObject var controller: BlockController
    @State private var showPicker = false
    @State private var showUnblock = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("blocked")
                        .font(Theme.mono(.caption))
                        .foregroundColor(Theme.text)
                    Rectangle().frame(height: 1).foregroundColor(Theme.border)

                    row("apps", controller.selection.applicationTokens.count)
                    row("categories", controller.selection.categoryTokens.count)
                    row("websites", controller.selection.webDomainTokens.count)
                }

                Button(action: { showPicker = true }) {
                    Text(controller.isBlocking ? "edit (locked while active)" : "+ choose what to block")
                        .font(Theme.mono(.body))
                        .foregroundColor(Theme.text)
                }
                .buttonStyle(.plain)
                .disabled(controller.isBlocking)
                .opacity(controller.isBlocking ? 0.3 : 1)

                Spacer()

                if controller.isBlocking {
                    Button(action: { showUnblock = true }) {
                        Text("[ unblock ]")
                            .terminalButton()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { controller.startBlocking() }) {
                        Text("[ activate ]")
                            .terminalButton()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(!controller.hasSelection)
                    .opacity(controller.hasSelection ? 1 : 0.3)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Theme.background)
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
            .navigationDestination(isPresented: $showUnblock) {
                UnblockView()
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
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
}

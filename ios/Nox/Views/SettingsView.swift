import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var controller: BlockController
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("settings")
                .font(Theme.mono(.title2))
                .foregroundColor(Theme.text)

            field("screen time", controller.authState == .approved ? "approved" : "not approved")
            field("status", controller.isBlocking ? "blocking" : "idle")
            field("apps blocked", "\(controller.selection.applicationTokens.count)")
            field("websites blocked", "\(controller.selection.webDomainTokens.count)")

            Spacer()

            Text("nox keeps everything on this device. no account, no server, no network. uninstalling nox clears its restrictions.")
                .font(Theme.mono(.caption))
                .foregroundColor(Theme.text)
                .lineSpacing(4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Text("<")
                        .font(Theme.mono(.body))
                        .foregroundColor(Theme.text)
                }
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.mono(.caption))
                .foregroundColor(Theme.text)
            Text(value)
                .font(Theme.mono(.body))
                .foregroundColor(Theme.text)
        }
    }
}

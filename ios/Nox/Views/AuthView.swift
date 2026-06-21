import SwiftUI

struct AuthView: View {
    @EnvironmentObject var controller: BlockController
    @State private var requesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("nox")
                .font(Theme.mono(.largeTitle))
                .foregroundColor(Theme.text)

            Text("nox removes features from your phone.\n\nit needs screen time access to block apps at the os level. nothing leaves this device — no account, no server, no network.")
                .font(Theme.mono(.body))
                .foregroundColor(Theme.text)
                .lineSpacing(4)

            if controller.authState == .denied {
                Text("access denied. enable it under settings > screen time, then reopen nox.")
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)
            }

            Spacer()

            Button(action: grant) {
                Text(requesting ? "requesting..." : "[ grant access ]")
                    .terminalButton()
            }
            .disabled(requesting)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background)
    }

    private func grant() {
        requesting = true
        Task {
            await controller.requestAuthorization()
            requesting = false
        }
    }
}

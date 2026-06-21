import SwiftUI

struct AddAppView: View {
    @Environment(\.dismiss) var dismiss
    @State private var bundleId = ""
    @State private var displayName = ""
    @State private var error: String?
    @State private var isLoading = false
    var onAdded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("add app")
                .font(Theme.mono(.title2))
                .foregroundColor(Theme.text)

            VStack(alignment: .leading, spacing: 20) {
                TextField("bundle id", text: $bundleId)
                    .monoTextField()
                    .tint(Theme.text)

                TextField("name", text: $displayName)
                    .monoTextField()
                    .tint(Theme.text)
            }

            if let error {
                Text(error)
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)
            }

            Button(action: addApp) {
                Text("[ add ]")
                    .terminalButton()
            }
            .disabled(isLoading)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background)
        .presentationBackground(Theme.background)
    }

    private func addApp() {
        guard !bundleId.isEmpty, !displayName.isEmpty else {
            error = "enter bundle id and name"
            return
        }
        isLoading = true
        error = nil

        Task {
            do {
                _ = try await APIClient.shared.addApp(bundleId: bundleId, displayName: displayName)
                await MainActor.run {
                    onAdded()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

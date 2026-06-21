import SwiftUI

struct AddDomainView: View {
    @Environment(\.dismiss) var dismiss
    @State private var domain = ""
    @State private var error: String?
    @State private var isLoading = false
    var onAdded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("add domain")
                .font(Theme.mono(.title2))
                .foregroundColor(Theme.text)

            TextField("domain", text: $domain)
                .monoTextField()
                .tint(Theme.text)

            if let error {
                Text(error)
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)
            }

            Button(action: addDomain) {
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

    private func addDomain() {
        guard !domain.isEmpty else {
            error = "enter a domain"
            return
        }
        isLoading = true
        error = nil

        Task {
            do {
                _ = try await APIClient.shared.addDomain(domain: domain)
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

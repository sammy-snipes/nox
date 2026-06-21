import SwiftUI

struct AddDomainView: View {
    @EnvironmentObject var controller: BlockController
    @Environment(\.dismiss) var dismiss
    @State private var text = ""

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Text("add domain")
                    .font(Theme.mono(.title3))
                    .foregroundColor(Theme.text)

                Text("type a site to block. e.g. reddit.com")
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)

                TextField("", text: $text)
                    .monoTextField()
                    .keyboardType(.URL)
                    .tint(Theme.text)
                    .onSubmit(add)

                HStack {
                    Button(action: { dismiss() }) {
                        Text("[ cancel ]").terminalButton()
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: add) {
                        Text("[ add ]").terminalButton()
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }

                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.height(260)])
        .preferredColorScheme(.dark)
    }

    private func add() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        controller.addDomain(trimmed)
        dismiss()
    }
}

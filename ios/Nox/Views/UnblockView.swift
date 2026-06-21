import SwiftUI

struct NoPasteTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: UIFont
    var textColor: UIColor
    var onTextChange: (String) -> Void

    func makeUIView(context: Context) -> NoPasteUITextField {
        let field = NoPasteUITextField()
        field.placeholder = placeholder
        field.font = font
        field.textColor = textColor
        field.backgroundColor = .clear
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.white.withAlphaComponent(0.3),
                .font: font,
            ]
        )
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.delegate = context.coordinator
        field.tintColor = .white
        return field
    }

    func updateUIView(_ uiView: NoPasteUITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NoPasteTextField

        init(_ parent: NoPasteTextField) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let textRange = Range(range, in: current) else { return false }
            let updated = current.replacingCharacters(in: textRange, with: string)
            parent.text = updated
            parent.onTextChange(updated)
            return false
        }
    }
}

class NoPasteUITextField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

struct UnblockView: View {
    @Environment(\.dismiss) var dismiss
    let session: BlockSession
    var onUnblocked: () -> Void

    static let unlockText = "I am choosing to remove the restrictions I placed on myself. I understand that I set these boundaries for a reason, and that this moment of weakness will pass. I am making a deliberate choice to prioritize short-term comfort over my long-term goals. This is not what I want."

    @State private var typedText = ""
    @State private var showReset = false
    @State private var error: String?
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("type to unblock")
                .font(Theme.mono(.title3))
                .foregroundColor(Theme.text)

            Text(Self.unlockText)
                .font(Theme.mono(.caption))
                .foregroundColor(Theme.text)
                .lineSpacing(4)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.border)

            NoPasteTextField(
                text: $typedText,
                placeholder: "start typing...",
                font: UIFont.monospacedSystemFont(ofSize: 16, weight: .regular),
                textColor: .white,
                onTextChange: handleTextChange
            )
            .frame(height: 44)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.border)

            HStack {
                Spacer()
                Text("\(typedText.count) / \(Self.unlockText.count)")
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)
            }

            if showReset {
                Text("typo. reset.")
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)
            }

            if let error {
                Text(error)
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background)
        .navigationBarBackButtonHidden(true)
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
    }

    private func handleTextChange(_ newText: String) {
        let target = Self.unlockText
        let targetPrefix = String(target.prefix(newText.count))

        if newText == target {
            submitUnblock()
            return
        }

        if !target.hasPrefix(newText) {
            typedText = ""
            showReset = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showReset = false
            }
        }
    }

    private func submitUnblock() {
        guard !isSubmitting else { return }
        isSubmitting = true

        Task {
            do {
                try await APIClient.shared.submitUnblock(sessionId: session.id, unlockText: typedText)
                await MainActor.run {
                    onUnblocked()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}

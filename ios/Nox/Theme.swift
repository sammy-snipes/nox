import SwiftUI

struct Theme {
    static let background = Color.black
    static let text = Color.white
    static let border = Color.white

    static func mono(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced)
    }
}

struct MonoTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.mono(.body))
            .foregroundColor(Theme.text)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding(.vertical, 8)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Theme.border),
                alignment: .bottom
            )
    }
}

struct TerminalButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.mono(.body))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.background)
            .overlay(
                Rectangle()
                    .stroke(Theme.border, lineWidth: 1)
            )
            .cornerRadius(0)
    }
}

extension View {
    func monoTextField() -> some View {
        modifier(MonoTextFieldStyle())
    }

    func terminalButton() -> some View {
        modifier(TerminalButtonStyle())
    }
}

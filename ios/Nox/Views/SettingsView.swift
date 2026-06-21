import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var controller: BlockController
    @Environment(\.dismiss) var dismiss

    private let presets = [1, 5, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("settings")
                .font(Theme.mono(.title2))
                .foregroundColor(Theme.text)

            field("screen time", controller.authState == .approved ? "approved" : "not approved")
            field("status", controller.isBlocking ? "on (blocking)" : "off")

            VStack(alignment: .leading, spacing: 12) {
                Text("turn-off delay")
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)
                Text("after you start a turn-off, this is how long you wait before it actually turns off.")
                    .font(Theme.mono(.caption2))
                    .foregroundColor(Theme.text)
                    .opacity(0.6)

                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { minutes in
                        Button(action: { controller.setDelay(minutes) }) {
                            Text("\(minutes)m")
                                .font(Theme.mono(.body))
                                .foregroundColor(controller.unlockDelayMinutes == minutes ? Theme.background : Theme.text)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(controller.unlockDelayMinutes == minutes ? Theme.text : Theme.background)
                                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .disabled(controller.isBlocking)
                .opacity(controller.isBlocking ? 0.3 : 1)

                if controller.isBlocking {
                    Text("locked while nox is on. turn off first to change.")
                        .font(Theme.mono(.caption2))
                        .foregroundColor(Theme.text)
                }
            }

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

import SwiftUI

/// Turning nox off isn't instant: you start a countdown and have to wait out
/// the delay you set. Leave this screen and the wait resets to full.
struct UnblockView: View {
    @EnvironmentObject var controller: BlockController
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(now: context.date)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: cancel) {
                    Text("<")
                        .font(Theme.mono(.body))
                        .foregroundColor(Theme.text)
                }
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { controller.beginUnlock() }
    }

    private func content(now: Date) -> some View {
        let remaining = max(0, controller.unlockReadyAt?.timeIntervalSince(now) ?? 0)
        let ready = remaining <= 0

        return VStack(alignment: .leading, spacing: 24) {
            Text("turn off nox")
                .font(Theme.mono(.title3))
                .foregroundColor(Theme.text)

            Text("you set a \(controller.unlockDelayMinutes) minute delay. wait it out, then confirm. go back and it resets to \(controller.unlockDelayMinutes):00.")
                .font(Theme.mono(.caption))
                .foregroundColor(Theme.text)
                .lineSpacing(4)

            Rectangle().frame(height: 1).foregroundColor(Theme.border)

            Text(format(remaining))
                .font(.system(size: 56, weight: .regular, design: .monospaced))
                .foregroundColor(Theme.text)

            if ready {
                Button(action: confirm) {
                    Text("[ confirm — turn nox off ]")
                        .terminalButton()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                Text("waiting...")
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func confirm() {
        controller.completeUnlock()
        dismiss()
    }

    private func cancel() {
        controller.cancelUnlock()
        dismiss()
    }
}

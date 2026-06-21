import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("settings")
                .font(Theme.mono(.title2))
                .foregroundColor(Theme.text)

            VStack(alignment: .leading, spacing: 8) {
                Text("device")
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)

                Text(String(deviceManager.deviceToken.prefix(8)) + "...")
                    .font(Theme.mono(.body))
                    .foregroundColor(Theme.text)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("status")
                    .font(Theme.mono(.caption))
                    .foregroundColor(Theme.text)

                Text(deviceManager.isEnrolled ? "enrolled" : "not enrolled")
                    .font(Theme.mono(.body))
                    .foregroundColor(Theme.text)
            }

            Spacer()

            Button(action: {
                deviceManager.isEnrolled = false
                dismiss()
            }) {
                Text("re-enroll")
                    .terminalButton()
            }
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
}

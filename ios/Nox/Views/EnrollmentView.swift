import SwiftUI

struct EnrollmentView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 32) {
                Text("enrollment")
                    .font(Theme.mono(.title2))
                    .foregroundColor(Theme.text)

                VStack(alignment: .leading, spacing: 16) {
                    Text("to enforce blocks, nox needs to install a device profile. this cannot be bypassed.")
                        .font(Theme.mono(.body))
                        .foregroundColor(Theme.text)

                    Text("tap below to open safari and install the profile. return here when done.")
                        .font(Theme.mono(.caption))
                        .foregroundColor(Theme.text)
                }

                Button(action: openEnrollment) {
                    Text("install profile")
                        .terminalButton()
                }

                Spacer()

                Button(action: {
                    deviceManager.isEnrolled = true
                }) {
                    Text("done")
                        .terminalButton()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Theme.background)
        }
    }

    private func openEnrollment() {
        guard let url = APIClient.shared.getEnrollmentURL() else { return }
        UIApplication.shared.open(url)
    }
}

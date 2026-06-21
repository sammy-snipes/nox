import SwiftUI

struct ContentView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Text("nox")
                        .font(Theme.mono(.largeTitle))
                        .foregroundColor(Theme.text)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            } else if !deviceManager.isEnrolled {
                EnrollmentView()
            } else {
                BlocklistView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if !deviceManager.isRegistered {
                await deviceManager.register()
            }
            isLoading = false
        }
    }
}

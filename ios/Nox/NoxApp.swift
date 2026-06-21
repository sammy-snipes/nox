import SwiftUI

@main
struct NoxApp: App {
    @StateObject private var deviceManager = DeviceManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deviceManager)
                .onAppear {
                    APIClient.shared.configure(deviceManager: deviceManager)
                }
        }
    }
}

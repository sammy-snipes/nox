import SwiftUI

@main
struct NoxApp: App {
    @StateObject private var controller = BlockController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { controller.refreshAuth() }
        }
    }
}

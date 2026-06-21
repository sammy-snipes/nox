import SwiftUI

@main
struct NoxApp: App {
    @StateObject private var controller = BlockController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .preferredColorScheme(.dark)
        }
    }
}

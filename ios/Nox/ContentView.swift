import SwiftUI

struct ContentView: View {
    @EnvironmentObject var controller: BlockController

    var body: some View {
        Group {
            // Once granted, skip the grant screen for good (unless explicitly revoked).
            if controller.authState == .approved
                || (controller.hasGrantedOnce && controller.authState != .denied) {
                BlocklistView()
            } else {
                AuthView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

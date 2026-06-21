import SwiftUI

struct ContentView: View {
    @EnvironmentObject var controller: BlockController

    var body: some View {
        Group {
            switch controller.authState {
            case .approved:
                BlocklistView()
            default:
                AuthView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

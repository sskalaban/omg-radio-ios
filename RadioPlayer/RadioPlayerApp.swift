import SwiftUI

@main
struct RadioPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            StationListView()
                .preferredColorScheme(.dark)
        }
    }
}

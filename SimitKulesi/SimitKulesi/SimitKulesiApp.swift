import SwiftUI

@main
struct SimitKulesiApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

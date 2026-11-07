import AppIntents
import Observation
import SwiftUI

@main
struct QRPayApp: App {
    @State private var router = Router()
    @State private var store = CardStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .environment(store)
                .onOpenURL { router.handle($0) }
        }
    }
}

@Observable
final class Router {
    var showScanner = false

    func handle(_ url: URL) {
        if url.scheme == "qrpay", url.host == "scan" {
            showScanner = true
        }
    }
}

/// "Hey Siri, QR ile öde" ve Kısayollar uygulaması için.
struct QRPayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenScannerIntent(),
            phrases: ["\(.applicationName) ile öde", "\(.applicationName) karekod okut"],
            shortTitle: "QR ile Öde",
            systemImageName: "qrcode.viewfinder"
        )
    }
}

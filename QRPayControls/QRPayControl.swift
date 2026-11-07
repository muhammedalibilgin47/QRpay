import AppIntents
import SwiftUI
import WidgetKit

@main
struct QRPayControlsBundle: WidgetBundle {
    var body: some Widget {
        QRPayControl()
    }
}

/// iOS 18 Denetim Merkezi / Kilit Ekranı / Eylem düğmesi denetimi.
struct QRPayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.tiyzi.qrpay.scan") {
            ControlWidgetButton(action: OpenScannerIntent()) {
                Label("QR ile Öde", systemImage: "qrcode.viewfinder")
            }
        }
        .displayName("QR ile Öde")
        .description("Karekod okuyucuyu açar, kayıtlı kartınla ödersin.")
    }
}

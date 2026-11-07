import AppIntents
import Foundation

/// Denetim Merkezi düğmesi, Siri, Kısayollar ve Eylem düğmesi bu intent'i çalıştırır.
/// Uygulamayı qrpay://scan adresiyle açar, uygulama da direkt karekod okuyucuyu gösterir.
struct OpenScannerIntent: AppIntent {
    static let title: LocalizedStringResource = "QR ile Öde"
    static let description = IntentDescription("Karekod okuyucuyu açar ve kayıtlı kartınla ödeme yapar.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "qrpay://scan")!))
    }
}

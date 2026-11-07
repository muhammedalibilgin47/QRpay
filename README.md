# QR Öde (iPhone, iOS 18+)

Kartını ekle, TR Karekod okut, Face ID ile öde. Denetim Merkezi, Kilit Ekranı, Eylem düğmesi ve Siri'den ("QR Öde ile öde") tek dokunuşla açılır.

## Özellikler
- Kart ekleme: Luhn kontrolü, Visa / Mastercard / Troy / Amex tanıma
- Kart numarası ve CVV telefonda saklanmaz. Yalnızca son 4 hane ve token şifreli Anahtar Zinciri'nde durur
- Kamerayla karekod okuma, TR Karekod (EMV) çözümleme ve CRC doğrulama (bozuk ya da sahte karekodu reddeder)
- Dinamik karekodda tutar otomatik gelir, statik karekodda tutarı siz girersiniz
- Ödeme öncesi Face ID / şifre onayı
- iOS 18 Denetim Merkezi denetimi: "QR ile Öde"

## Kurulum (Mac gerekir)
1. Xcode 16 veya daha yenisini kurun.
2. `brew install xcodegen`
3. Bu klasörde `xcodegen` komutunu çalıştırın. `QRPay.xcodeproj` oluşur.
4. Projeyi açın, Signing & Capabilities'te iki hedef için de (QRPay, QRPayControls) Team'inizi seçin.
5. iPhone'u bağlayıp ▶︎ ile çalıştırın.

## Denetim Merkezi'ne ekleme
Denetim Merkezi'ni açın → boş bir yere basılı tutun → **Denetim Ekle** → "QR ile Öde"yi seçin.
Aynı denetimi Kilit Ekranı'na ya da Eylem düğmesine de (Ayarlar → Eylem Düğmesi → Denetim) atayabilirsiniz.

## ⚠️ Gerçek ödeme için
Uygulama şu an **demo modunda**: ödeme ekranı çalışır ama para çekmez (`DemoPaymentProvider`).
Gerçek para hareketi için TR Karekod ile ödemeyi destekleyen, BDDK/TCMB lisanslı bir ödeme kuruluşu, elektronik para kuruluşu ya da bankayla anlaşmanız ve onların SDK'sını kullanmanız gerekir. Kart verisini kendi sunucunuzda tutmak PCI-DSS yükümlülüğü getirir. Bu yüzden kart, kuruluşun SDK'sıyla doğrudan tokenize edilmeli.

Gerçek sağlayıcıya geçmek için `QRPay/Payment/PaymentProvider.swift` dosyasında `PaymentProvider` protokolünü uygulayan bir sınıf yazın ve `Payments.provider` satırını değiştirin. Uygulamanın geri kalanı aynen kalır.

## Dosyalar
- `QRPay/` uygulama (kartlar, okuyucu, ödeme)
- `QRPayControls/` Denetim Merkezi denetimi (WidgetKit uzantısı)
- `Shared/OpenScannerIntent.swift` denetim, Siri ve Kısayollar için ortak intent

# E-IMZO integratsiyasi

## 1. Bundle ID ro'yxatdan o'tkazish (majburiy)

`info@peachdev.uz` ga yuboring:

- Bundle ID (`CFBundleIdentifier`)
- Ilova nomi
- Kompaniya nomi
- Kontakt email va telefon

Tasdiqlangunicha SDK `BlockedView` ko'rsatadi.

---

## 2. Info.plist

### Kamera (QR scanner uchun — majburiy)

```xml
<key>NSCameraUsageDescription</key>
<string>QR-kod o'qish uchun kamera kerak</string>
```

### NFC (ID karta uchun — ixtiyoriy)

```xml
<key>NFCReaderUsageDescription</key>
<string>ID-karta orqali kalit o'qish uchun NFC kerak</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
  <string>65696D7A6F617070</string>
</array>
```

---

## 3. Entitlements (NFC uchun — ixtiyoriy)

Apple Developer Console'da NFC entitlement so'rang (bir martalik). Keyin `*.entitlements` ga qo'shing:

```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
  <string>TAG</string>
</array>
```

---

## 4. Foydalanish

```swift
import Muhr

struct ContentView: View {
    @State private var showEimzo = false
    @State private var deepLink: String?

    var body: some View {
        Button("Imzolash") { showEimzo = true }
            .sheet(isPresented: $showEimzo) {
                Muhr.eimzo.makeView(deepLink: deepLink) { result in
                    switch result {
                    case .success(let res):
                        print(res.signatureHex)
                        print(res.serialNumber ?? "")
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                    showEimzo = false
                    deepLink = nil
                }
            }
            .onOpenURL { url in
                guard url.scheme == "eimzo" else { return }
                deepLink = url.absoluteString
                showEimzo = true
            }
    }
}
```

### Test rejimi

```swift
// Muhr.eimzo default production (m.e-imzo.uz)
// Test uchun alohida instance:
let testEimzo = EImzoProvider(isTestMode: true)
```

---

## Xulosa

| Narsa | Majburligi |
|---|---|
| Bundle ID ro'yxati | Majburiy |
| `NSCameraUsageDescription` | Majburiy |
| NFC entitlement + permission | Faqat ID karta kerak bo'lsa |

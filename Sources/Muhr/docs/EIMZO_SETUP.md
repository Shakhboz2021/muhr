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

## 4. Sozlash (App launch da bir marta)

E-IMZO server base URL'ini `AppDelegate` yoki `App.init` da bering:

```swift
import Muhr

@main
struct MyApp: App {
    init() {
        Muhr.configure(
            eimzoBaseURL: URL(string: "https://your-backend.uz/api")!
        )
    }
}
```

Test serveri uchun:

```swift
Muhr.configure(
    eimzoBaseURL: URL(string: "https://your-backend.uz/api")!,
    isTestMode: true   // m.test.e-imzo.uz ga ulanadi
)
```

---

## 5. Foydalanish

### A. Matn imzolash (to'liq avtomat)

```swift
import Muhr

struct ContentView: View {
    @State private var showEimzo = false

    var body: some View {
        Button("Imzolash") { showEimzo = true }
            .sheet(isPresented: $showEimzo) {
                Muhr.eimzo.sign(string: "Imzolanadigan matn") { result in
                    switch result {
                    case .success(let res):
                        print(res.signatureHex)
                        print(res.serialNumber ?? "")
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                    showEimzo = false
                }
            }
    }
}
```

### B. Data imzolash (xotiradagi binary)

```swift
.sheet(isPresented: $showEimzo) {
    Muhr.eimzo.sign(data: pdfData, fileName: "contract.pdf") { result in
        showEimzo = false
    }
}
```

### C. Fayl imzolash (diskdan)

```swift
.sheet(isPresented: $showEimzo) {
    Muhr.eimzo.sign(fileURL: pdfURL) { result in
        showEimzo = false
    }
}
```

### D. Encodable struct imzolash

```swift
struct Contract: Encodable {
    let id: Int
    let amount: Double
}

.sheet(isPresented: $showEimzo) {
    Muhr.eimzo.sign(encodable: Contract(id: 1, amount: 500_000)) { result in
        showEimzo = false
    }
}
```

### E. Tashqi deeplink (boshqa ilovadan yoki serverdan)

```swift
.sheet(isPresented: $showEimzo) {
    Muhr.eimzo.sign(deepLink: incomingLink) { result in
        showEimzo = false
    }
}
.onOpenURL { url in
    guard url.scheme == "eimzo" else { return }
    incomingLink = url.absoluteString
    showEimzo = true
}
```

---

## 6. To'liq flow (ichida nima bo'ladi)

```
App                    Muhr                  E-IMZO Server
 │                       │                        │
 │  makeSignView(string) │                        │
 │──────────────────────>│                        │
 │                       │  POST /auth            │
 │                       │  {content, fileName}   │
 │                       │───────────────────────>│
 │                       │  {state, documentId,   │
 │                       │   challenge}           │
 │                       │<───────────────────────│
 │                       │                        │
 │          EImzoSDK UI ko'rsatiladi (QR / NFC)   │
 │          Foydalanuvchi E-IMZO ilovasi bilan     │
 │          skanerlaydi va tasdiqlaydi             │
 │                       │                        │
 │                       │  POST /upload          │
 │                       │  {pkcs7, documentId,   │
 │                       │   serialNumber}        │
 │                       │───────────────────────>│
 │                       │                        │
 │  onComplete(MuhrSignResult)                    │
 │<──────────────────────│                        │
```

---

## Xulosa

| Narsa | Majburligi |
|---|---|
| Bundle ID ro'yxati | Majburiy |
| `NSCameraUsageDescription` | Majburiy |
| `Muhr.configure(eimzoBaseURL:)` | Majburiy |
| NFC entitlement + permission | Faqat ID karta kerak bo'lsa |
| `isTestMode: true` | Faqat test muhitida |

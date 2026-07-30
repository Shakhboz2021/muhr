# Muhr — Provider'lar haqida

Muhr uchta imzolash provider'ini qo'llab-quvvatlaydi: **Styx**, **Metin**, va **E-IMZO**.
Har biri arxitektura, talablar va foydalanish uslubi jihatidan farq qiladi.

---

## Taqqoslash jadvali

| | Styx | Metin | E-IMZO |
|---|---|---|---|
| Sertifikat joylashuvi | Qurilmada (Keychain) | Serverda | E-IMZO serveri |
| Imzolash | Kod orqali | Kod orqali | UI orqali (foydalanuvchi) |
| Autentifikatsiya | Parol (`.p12` shifri) | PIN kod | Foydalanuvchi o'zi |
| Internet kerakmi | Yo'q | Ha | Ha |
| Ixtiyoriy ma'lumot imzolash | Ha | Ha | Yo'q (server tokeni) |
| Server integratsiyasi | Kerak emas | Kerak | Kerak |

---

## Styx

### Qanday ishlaydi

`.p12` / `.pfx` fayl qurilmaning **Keychain**'ida saqlanadi. Imzolash vaqtida foydalanuvchidan parol so'raladi — parol `.p12` ni ochish uchun ishlatiladi. Internet talab qilinmaydi, hamma narsa oflayn ishlaydi.

```
Foydalanuvchi     App                    Keychain
     |             |                        |
     |  .p12 yuklash va parol kiritish       |
     |------------>|                        |
     |             | saveToKeychain()       |
     |             |----------------------->|
     |             |                        |
     |  Imzolash uchun parol kiritish        |
     |------------>|                        |
     |             | getFromKeychain()      |
     |             |----------------------->|
     |             |<--- .p12 data ---------|
     |             | SecKeyCreateSignature()|
     |             |-------> signatureHex   |
```

**Xavfsizlik modeli:**
- Keychain service: `<BundleID>.styx`
- Account key: `SHA256(login + password)`
- 3 marta noto'g'ri parol → Keychain tozalanadi

### Talablar

- Internet: **kerak emas**
- Server: **kerak emas**
- Foydalanuvchi qurilmasida `.p12` / `.pfx` fayl bo'lishi kerak

### Foydalanish

**1. Sertifikat o'rnatish (bir marta):**

```swift
// Foydalanuvchi Documents papkasidan fayl tanlaydi
let fileURL: URL = ...
let p12Data = try Data(contentsOf: fileURL)

let certInfo = try await Muhr.styx.importCertificate(
    data: p12Data,
    password: "sertifikat_paroli",
    login: "user_login"
)
// yoki Muhr UI:
Muhr.certificatePickerView(login: "user_login") { cert in
    print("O'rnatildi: \(cert.commonName)")
}
```

**2. Imzolash:**

```swift
let data = "imzolanadigan matn".data(using: .utf8)!

let result = try await Muhr.styx.sign(
    data: data,
    password: "sertifikat_paroli",
    login: "user_login"
)
print(result.signatureHex)

// yoki Muhr UI:
Muhr.signingView(data: data, login: "user_login") { result in
    print(result.signatureHex)
}
```

**3. CMS/PKCS#7 imzolash (server bilan mos format):**

```swift
let cmsData = try await Muhr.styx.signCMS(
    data: data,
    password: "sertifikat_paroli",
    login: "user_login"
)
let cmsBase64 = cmsData.base64EncodedString()
```

---

## Metin

### Qanday ishlaydi

Sertifikat va private key **Metin serverida** saqlanadi — qurilmada hech narsa yo'q. Imzolash so'rovi server orqali o'tadi: app PIN kodni serverga yuboradi, server imzolaydi va natijani qaytaradi.

```
App                  Metin Server
 |                        |
 | initialize(baseUrl)    |
 |----------------------->|
 |                        |
 | addCertificate(...)    |  <- Bir marta (ro'yxatdan o'tish)
 |----------------------->|
 |<--- serialNumber ------|
 |                        |
 | sign(pinCode, message, serialNumber)
 |----------------------->|
 |<--- signatureBase64 ---|
```

**Xavfsizlik modeli:**
- Private key hech qachon qurilmaga tushmaydi
- PIN noto'g'ri kiritilsa server tries'ni kamaytiradi
- PIN bloklanishi server tomonida boshqariladi

### Talablar

- **Internet**: Ha (har bir imzolashda)
- **Server**: Metin serveri URL'i (`base_url`)
- **Sozlash**: `initialize(baseUrl:)` chaqirilishi shart

### Foydalanish

**1. Sozlash:**

```swift
let metin = MetinProvider(
    configuration: ProviderConfiguration(
        type: .metin,
        additionalParameters: ["base_url": "https://api.metin.uz"]
    )
)
try await metin.initialize()
```

**2. Sertifikat qo'shish (bir marta):**

```swift
let result = try await metin.addCertificate(
    userId: "server_user_id",
    emailAddress: "user@example.com",
    commonName: "Ism Familiya",
    organizationUnitName: "Bo'lim",
    organizationName: "Tashkilot",
    streetAddress: "Manzil",
    localityName: "Toshkent",
    stateOrProvinceName: "Toshkent",
    countryName: .UZ,
    pinfl: "12345678901234",
    pinCode: "123456"
)
// result.serialNumber ni saqlang — keyinchalik sign uchun kerak
```

**3. Imzolash:**

```swift
// serialNumber bilan
let signature = try await metin.sign(
    pinCode: "123456",
    message: "imzolanadigan matn",  // yoki Base64 string
    serialNumber: savedSerialNumber
)

// pinfl/inn bilan
let signature = try await metin.sign(
    pinCode: "123456",
    message: "imzolanadigan matn",
    pinfl: "12345678901234",
    inn: nil
)

// Bir nechta xabar birdan
let signatures = try await metin.sign(
    pinCode: "123456",
    messages: ["xabar1", "xabar2"],
    serialNumber: savedSerialNumber
)
```

**4. CMS imzolash:**

```swift
let signedCMS = try await metin.signCMS(
    cms: "",  // bo'sh = yangi CMS
    pinCode: "123456",
    serialNumber: savedSerialNumber
)
```

---

## E-IMZO

### Qanday ishlaydi

E-IMZO — O'zbekiston davlat ERI tizimi. Imzolash to'liq **SDK UI** ichida bo'ladi: foydalanuvchi QR kod skanerlaydi yoki ID kartasini NFC orqali ulaydi. Sizning server E-IMZO serveridan `qc` token oladi va uni app'ga uzatadi.

```
App                 Sizning Server       E-IMZO Server
 |                        |                    |
 |  "Imzolash kerak"       |                    |
 |----------------------->|                    |
 |                        | signRequest()      |
 |                        |------------------->|
 |                        |<--- qc token ------|
 |<--- deepLink: eimzo://sign?qc=... ----------|
 |                        |                    |
 | EImzoView(deepLink:)   |                    |
 | [foydalanuvchi imzolaydi — QR yoki NFC]     |
 |                        |                    |
 | onSignComplete(signatureHex, serialNumber)  |
 |                        |                    |
 | signatureHex -----------|                    |
 |                        | verify(sig)        |
 |                        |------------------->|
```

**Xavfsizlik modeli:**
- Sertifikat E-IMZO serverida yoki foydalanuvchining ID kartasida
- App faqat UI ko'rsatadi, imzoni o'zi yaratmaydi
- `qc` token bir martalik va muddatli

### Talablar

- **Internet**: Ha
- **Bundle ID ro'yxati**: `info@peachdev.uz` ga yuborish kerak (bloklanmaslik uchun)
- **Kamera ruxsati**: QR skaner uchun majburiy
- **NFC** (ixtiyoriy): ID karta uchun

**Info.plist:**

```xml
<!-- Majburiy -->
<key>NSCameraUsageDescription</key>
<string>QR-kod o'qish uchun kamera kerak</string>

<!-- ID karta kerak bo'lsa -->
<key>NFCReaderUsageDescription</key>
<string>ID-karta orqali kalit o'qish uchun NFC kerak</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
  <string>65696D7A6F617070</string>
</array>
```

**Entitlements** (NFC uchun):

```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
  <string>TAG</string>
</array>
```

### Foydalanish

```swift
import Muhr

struct ContentView: View {
    @State private var showEimzo = false
    @State private var deepLink: String?

    var body: some View {
        Button("E-IMZO bilan imzolash") {
            // Serverdan deepLink olib, keyin sheetni oching
            Task {
                deepLink = try await fetchDeepLinkFromServer()
                showEimzo = true
            }
        }
        .sheet(isPresented: $showEimzo) {
            Muhr.eimzo.makeView(deepLink: deepLink) { result in
                switch result {
                case .success(let res):
                    // res.signatureHex — imzo
                    // res.serialNumber — sertifikat raqami
                    sendToServer(res.signatureHex)
                case .failure(let error):
                    print(error.localizedDescription)
                }
                showEimzo = false
                deepLink = nil
            }
        }
        // Boshqa ilovadan (browser/QR) kelgan deep link
        .onOpenURL { url in
            guard url.scheme == "eimzo" else { return }
            deepLink = url.absoluteString
            showEimzo = true
        }
    }
}
```

**Test rejimi:**

```swift
// Muhr.eimzo — production (m.e-imzo.uz)
// Test uchun alohida instance:
let testEimzo = EImzoProvider(isTestMode: true)  // m.test.e-imzo.uz
```

> **Eslatma:** Test va production serverlaridan kelgan `qc` tokenlar bir-biri bilan mos kelmaydi. Qaysi muhitda ishlasangiz, `isTestMode` ham mos bo'lishi kerak.

---

## Provider tanlash bo'yicha tavsiya

| Holat | Provider |
|---|---|
| Bank ilovasi, server bor, qurilmada kalit kerak emas | **Metin** |
| Offline ishlashi kerak, foydalanuvchi o'z `.p12` faylini boshqaradi | **Styx** |
| Davlat tizimi, E-IMZO portal bilan integratsiya | **E-IMZO** |
| Bir ilovada bir nechta tizim | Hammasini bir vaqtda ishlatsa bo'ladi |

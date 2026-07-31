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
| Server integratsiyasi | Kerak emas | Kerak | Kerak |
| Sozlash | Kerak emas | `initialize()` | `Muhr.configure(eimzoBaseURL:)` |

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

**3. CMS/PKCS#7 imzolash:**

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
- **Sozlash**: `initialize()` chaqirilishi shart

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
    message: "imzolanadigan matn",
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

E-IMZO — O'zbekiston davlat ERI tizimi. Muhr barcha network qadamlarini avtomatik boshqaradi: app faqat imzolanadigan kontent va base URL beradi.

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
 │          EImzoSDK UI (QR skaner yoki NFC)       │
 │          Foydalanuvchi E-IMZO ilovasi bilan     │
 │          tasdiqlaydi                            │
 │                       │                        │
 │                       │  POST /upload          │
 │                       │  {pkcs7, documentId,   │
 │                       │   serialNumber}        │
 │                       │───────────────────────>│
 │                       │                        │
 │  onComplete(MuhrSignResult)                    │
 │<──────────────────────│                        │
```

**Xavfsizlik modeli:**
- Sertifikat E-IMZO serverida yoki foydalanuvchining ID kartasida
- App faqat UI ko'rsatadi, imzoni o'zi yaratmaydi
- Network (auth → upload) Muhr ichida boshqariladi

### Talablar

- **Internet**: Ha
- **Bundle ID ro'yxati**: `info@peachdev.uz` ga yuborish kerak
- **Kamera ruxsati**: QR skaner uchun majburiy
- **NFC** (ixtiyoriy): ID karta uchun
- **`Muhr.configure(eimzoBaseURL:)`**: App launch da chaqirilishi shart

### Sozlash

```swift
@main
struct MyApp: App {
    init() {
        Muhr.configure(
            eimzoBaseURL: URL(string: "https://your-backend.uz/api")!
        )
    }
}
```

### Foydalanish

**Matn imzolash:**

```swift
.sheet(isPresented: $showEimzo) {
    Muhr.eimzo.sign(string: "Imzolanadigan matn") { result in
        switch result {
        case .success(let res):
            print(res.signatureHex)    // PKCS7 imzo
            print(res.serialNumber ?? "") // Sertifikat raqami
        case .failure(let error):
            print(error.localizedDescription)
        }
        showEimzo = false
    }
}
```

**Data imzolash (xotiradagi binary):**

```swift
.sheet(isPresented: $showEimzo) {
    Muhr.eimzo.sign(data: pdfData, fileName: "contract.pdf") { result in
        showEimzo = false
    }
}
```

**Fayl imzolash (diskdan):**

```swift
.sheet(isPresented: $showEimzo) {
    Muhr.eimzo.sign(fileURL: pdfURL) { result in
        showEimzo = false
    }
}
```

**Encodable struct imzolash:**

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

**Tashqi deeplink (serverdan yoki boshqa ilovadan):**

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

**Test rejimi:**

```swift
Muhr.configure(
    eimzoBaseURL: URL(string: "https://your-backend.uz/api")!,
    isTestMode: true  // m.test.e-imzo.uz ga ulanadi
)
```

> **Eslatma:** Test va production serverlaridan kelgan tokenlar bir-biri bilan mos kelmaydi.

---

## Provider tanlash bo'yicha tavsiya

| Holat | Provider |
|---|---|
| Offline ishlashi kerak, foydalanuvchi o'z `.p12` faylini boshqaradi | **Styx** |
| Bank ilovasi, server bor, qurilmada kalit kerak emas | **Metin** |
| Davlat tizimi, E-IMZO portal bilan integratsiya | **E-IMZO** |
| Bir ilovada bir nechta tizim | Hammasini bir vaqtda ishlatsa bo'ladi |

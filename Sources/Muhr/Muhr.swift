//
//  Muhr.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

/// Muhr - Xavfsizlik kutubxonasi
///
/// Raqamli imzo (ERI/ЭЦП) va shifrlash funksionalligi.
///
/// ## Imkoniyatlar:
/// - X.509 sertifikat bilan imzolash
/// - Ma'lumotlarni shifrlash
/// - Keychain integratsiyasi
///
/// ## Foydalanish:
/// ```swift
/// import Muhr
///
/// // Imzolash
/// let signature = try await Muhr.sign(data)
///
/// // Shifrlash (kelajakda)
/// let encrypted = try Muhr.encrypt(data)
/// ```
public enum Muhr {

    /// Kutubxona versiyasi
    public static let version = "1.0.0"

    /// Build raqami
    public static let build = 1
}

//
//  GetCertificatesUseCase.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Get Certificates Use Case
/// Sertifikatlar ro'yxatini olish uchun UseCase
///
/// Keychain'dagi barcha sertifikatlarni turli filtrlash
/// va saralash opsiyalari bilan qaytaradi.
///
/// ## Foydalanish:
/// ```swift
/// let useCase = GetCertificatesUseCase(repository: repository)
///
/// // Barcha sertifikatlar
/// let all = try await useCase.execute()
///
/// // Faqat valid sertifikatlar
/// let valid = try await useCase.execute(filter: .validOnly)
///
/// // Qidirish
/// let found = try await useCase.execute(
///     filter: .search("Muhammad")
/// )
/// ```
public final class GetCertificatesUseCase: Sendable {

    // MARK: - Dependencies

    private let certificateRepository: CertificateRepository

    // MARK: - Initializer

    /// UseCase yaratish
    ///
    /// - Parameter certificateRepository: Sertifikat repository
    public init(certificateRepository: CertificateRepository) {
        self.certificateRepository = certificateRepository
    }

    // MARK: - Execute

    /// Sertifikatlar ro'yxatini olish
    ///
    /// - Parameters:
    ///   - filter: Filtrlash opsiyasi
    ///   - sortBy: Saralash opsiyasi
    /// - Returns: Sertifikatlar ro'yxati
    /// - Throws: `MuhrError`
    public func execute(
        filter: CertificateFilter = .all,
        sortBy: CertificateSortOption = .commonName
    ) async throws -> [CertificateInfo] {

        // 1. Barcha sertifikatlarni olish
        var certificates = try await certificateRepository.getAllCertificates()

        // 2. Filtrlash
        certificates = applyFilter(certificates, filter: filter)

        // 3. Saralash
        certificates = applySorting(certificates, sortBy: sortBy)

        return certificates
    }

    /// ID bo'yicha sertifikat olish
    ///
    /// - Parameter id: Sertifikat ID'si (serial number)
    /// - Returns: Sertifikat yoki nil
    /// - Throws: `MuhrError`
    public func execute(id: String) async throws -> CertificateInfo? {
        try await certificateRepository.getCertificate(by: id)
    }

    /// Default sertifikatni olish
    ///
    /// - Returns: Default sertifikat yoki nil
    /// - Throws: `MuhrError`
    public func executeGetDefault() async throws -> CertificateInfo? {
        try await certificateRepository.getDefaultCertificate()
    }

    /// Sertifikatlar sonini olish
    ///
    /// - Parameter filter: Filtrlash opsiyasi
    /// - Returns: Sertifikatlar soni
    /// - Throws: `MuhrError`
    public func executeCount(filter: CertificateFilter = .all) async throws
        -> Int
    {
        let certificates = try await execute(filter: filter)
        return certificates.count
    }

    // MARK: - Private Methods

    /// Filtrlash
    private func applyFilter(
        _ certificates: [CertificateInfo],
        filter: CertificateFilter
    ) -> [CertificateInfo] {

        switch filter {
        case .all:
            return certificates

        case .validOnly:
            return certificates.filter { $0.isValid }

        case .expiredOnly:
            return certificates.filter { $0.isExpired }

        case .expiringSoon(let days):
            return certificates.filter {
                $0.isValid && $0.daysUntilExpiry <= days
            }

        case .canSign:
            return certificates.filter { $0.canSign }

        case .search(let query):
            let lowercasedQuery = query.lowercased()
            return certificates.filter { cert in
                cert.commonName.lowercased().contains(lowercasedQuery)
                    || cert.organization?.lowercased().contains(lowercasedQuery)
                        == true
                    || cert.pinfl?.contains(query) == true
                    || cert.stir?.contains(query) == true
            }

        case .byAlgorithm(let algorithm):
            return certificates.filter { $0.algorithm == algorithm }

        case .custom(let predicate):
            return certificates.filter(predicate)
        }
    }

    /// Saralash
    private func applySorting(
        _ certificates: [CertificateInfo],
        sortBy: CertificateSortOption
    ) -> [CertificateInfo] {

        switch sortBy {
        case .commonName:
            return certificates.sorted { $0.commonName < $1.commonName }

        case .commonNameDescending:
            return certificates.sorted { $0.commonName > $1.commonName }

        case .expiryDate:
            return certificates.sorted { $0.validTo < $1.validTo }

        case .expiryDateDescending:
            return certificates.sorted { $0.validTo > $1.validTo }

        case .issueDate:
            return certificates.sorted { $0.validFrom < $1.validFrom }

        case .issueDateDescending:
            return certificates.sorted { $0.validFrom > $1.validFrom }

        case .organization:
            return certificates.sorted {
                ($0.organization ?? "") < ($1.organization ?? "")
            }

        case .custom(let comparator):
            return certificates.sorted(by: comparator)
        }
    }
}

// MARK: - Certificate Filter
/// Sertifikat filtrlash opsiyalari
public enum CertificateFilter: Sendable {

    /// Barcha sertifikatlar
    case all

    /// Faqat valid (muddati tugamagan) sertifikatlar
    case validOnly

    /// Faqat muddati tugagan sertifikatlar
    case expiredOnly

    /// Tez orada muddati tugaydigan sertifikatlar
    /// - Parameter days: Qancha kun ichida
    case expiringSoon(days: Int)

    /// Imzolash mumkin bo'lgan (private key bor)
    case canSign

    /// Qidirish (CN, Organization, PINFL, STIR)
    case search(String)

    /// Algoritm bo'yicha
    case byAlgorithm(SignatureAlgorithm)

    /// Custom filter
    case custom(@Sendable (CertificateInfo) -> Bool)
}

// MARK: - Certificate Sort Option
/// Sertifikat saralash opsiyalari
public enum CertificateSortOption: Sendable {

    /// Ism bo'yicha (A-Z)
    case commonName

    /// Ism bo'yicha (Z-A)
    case commonNameDescending

    /// Tugash sanasi bo'yicha (tez tugaydiganlar birinchi)
    case expiryDate

    /// Tugash sanasi bo'yicha (kech tugaydiganlar birinchi)
    case expiryDateDescending

    /// Berilgan sana bo'yicha (eskilar birinchi)
    case issueDate

    /// Berilgan sana bo'yicha (yangilar birinchi)
    case issueDateDescending

    /// Tashkilot bo'yicha
    case organization

    /// Custom sorting
    case custom(@Sendable (CertificateInfo, CertificateInfo) -> Bool)
}

// MARK: - Convenience Extensions
extension GetCertificatesUseCase {

    /// Imzolash uchun mos sertifikatlar
    ///
    /// Valid va private key bor sertifikatlar.
    public func executeSigningCertificates() async throws -> [CertificateInfo] {
        return try await execute(
            filter: .canSign,
            sortBy: .expiryDateDescending
        )
    }

    /// Tez orada tugaydigan sertifikatlar (30 kun)
    public func executeExpiringSoon() async throws -> [CertificateInfo] {
        return try await execute(
            filter: .expiringSoon(days: 30),
            sortBy: .expiryDate
        )
    }

    /// Sertifikat bormi?
    public func executeHasAnyCertificate() async throws -> Bool {
        let count = try await executeCount()
        return count > 0
    }

    /// Valid sertifikat bormi?
    public func executeHasValidCertificate() async throws -> Bool {
        let count = try await executeCount(filter: .validOnly)
        return count > 0
    }
}

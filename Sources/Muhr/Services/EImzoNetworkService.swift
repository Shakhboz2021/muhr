//
//  EImzoNetworkService.swift
//  Muhr
//

import Foundation

// MARK: - EImzoRequest

public struct EImzoRequest: Equatable, Sendable {
    public let siteId: String
    public let documentId: String
    public let hash: String
    public let crc32: String?
    public let callbackScheme: String?

    public init(
        siteId: String,
        documentId: String,
        hash: String,
        crc32: String? = nil,
        callbackScheme: String? = nil
    ) {
        self.siteId = siteId
        self.documentId = documentId
        self.hash = hash
        self.crc32 = crc32
        self.callbackScheme = callbackScheme
    }
}

// MARK: - DeepLink Builder

public func generateEImzoDeepLink(from request: EImzoRequest) -> URL? {
    var components = URLComponents()
    components.scheme = "eimzo"
    components.host = "sign"

    var items: [URLQueryItem] = [
        URLQueryItem(name: "siteId", value: request.siteId),
        URLQueryItem(name: "documentId", value: request.documentId),
        URLQueryItem(name: "hash", value: request.hash),
    ]
    if let crc32 = request.crc32, !crc32.trimmingCharacters(in: .whitespaces).isEmpty {
        items.append(URLQueryItem(name: "crc32", value: crc32))
    }
    if let scheme = request.callbackScheme, !scheme.trimmingCharacters(in: .whitespaces).isEmpty {
        items.append(URLQueryItem(name: "redirect", value: "\(scheme)://eimzo-callback"))
    }
    components.queryItems = items
    return components.url
}

// MARK: - Response Models

public struct EImzoAuthResponse: Decodable, Sendable {
    public let state: String
    public let documentId: String
    public let challenge: String
}

public struct EImzoStatusResponse: Decodable, Sendable {
    public let status: Int

    /// `true` agar foydalanuvchi E-IMZO ilovasida imzolashni tugatgan bo'lsa
    public var isCompleted: Bool { status == 1 }

    /// `true` agar E-IMZO ilovasi imzolashni kutayotgan bo'lsa
    public var isPending: Bool { status == 2 }
}

// MARK: - EImzoNetworkService

/// E-IMZO mobil autentifikatsiya REST API
///
/// Sequence:
/// 1. `auth()` → documentId, challenge olish
/// 2. `status(documentId:)` → E-IMZO ilovasi imzolashini kutish (polling)
/// 3. `upload(pkcs7:documentId:serialNumber:)` → imzoni serverga yuklash
actor EImzoNetworkService {

    // MARK: - Properties

    private let baseURL: URL
    private let session: URLSession

    // MARK: - Init

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Endpoints

    /// 1-qadam: Autentifikatsiya sessiyasini boshlash
    ///
    /// - Parameters:
    ///   - contentBase64: Imzolanadigan kontent (Base64 encoded)
    ///   - fileName: Fayl nomi (ko'rsatish uchun)
    ///   - lang: Til kodi ("uz", "ru", "en")
    /// - Returns: `state`, `documentId`, `challenge`
    func auth(contentBase64: String, fileName: String = "document", lang: String = "uz") async throws -> EImzoAuthResponse {
        let url = baseURL.appendingPathComponent("frontend/mobile/auth")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "lang": lang,
            "content": contentBase64,
            "fileName": fileName,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    /// 2-qadam: E-IMZO ilovasidan imzo kutish (polling)
    ///
    /// Status 2 = kutilmoqda, 1 = bajarildi
    ///
    /// - Parameter documentId: `auth()` dan kelgan document ID
    func status(documentId: String) async throws -> EImzoStatusResponse {
        let url = baseURL.appendingPathComponent("frontend/mobile/status")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["documentId": documentId])
        return try await perform(request)
    }

    /// 3-qadam: PKCS7 imzoni serverga yuklash
    ///
    /// - Parameters:
    ///   - pkcs7: Base64 formatidagi PKCS7 imzo
    ///   - documentId: `auth()` dan kelgan document ID
    ///   - serialNumber: Sertifikat seriya raqami
    func upload(pkcs7: String, documentId: String, serialNumber: String) async throws {
        let url = baseURL.appendingPathComponent("frontend/mobile/upload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "pkcs7": pkcs7,
            "documentId": documentId,
            "serialNumber": serialNumber,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        try await performVoid(request)
    }

    // MARK: - Private

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MuhrError.invalidServerResponse
        }
    }

    private func performVoid(_ request: URLRequest) async throws {
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MuhrError.invalidServerResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw MuhrError.networkError(reason: "HTTP \(http.statusCode)")
        }
    }
}

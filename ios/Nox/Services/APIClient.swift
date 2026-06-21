import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case badRequest(String)
    case serverError(Int)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "unauthorized"
        case .badRequest(let msg): return msg
        case .serverError(let code): return "server error: \(code)"
        case .decodingError: return "decoding error"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

struct DeviceResponse: Codable {
    let id: UUID
    let deviceToken: String
    let enrolled: Bool
    let createdAt: Date
}

struct BlocklistResponse: Codable {
    let domains: [BlockedDomain]
    let apps: [BlockedApp]
}

class APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = "http://localhost:8000"
    #else
    private let baseURL = "http://localhost:8000"
    #endif

    private var deviceManager: DeviceManager?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    func configure(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
    }

    // MARK: - Device

    func registerDevice(deviceToken: String) async throws -> DeviceResponse {
        let body: [String: String] = ["device_token": deviceToken]
        return try await post("/api/v1/device/register", body: body)
    }

    // MARK: - Blocklist

    func getBlocklist() async throws -> BlocklistResponse {
        return try await get("/api/v1/blocklist")
    }

    func addDomain(domain: String) async throws -> BlockedDomain {
        let body: [String: String] = ["domain": domain]
        return try await post("/api/v1/blocklist/domains", body: body)
    }

    func removeDomain(id: UUID) async throws {
        try await delete("/api/v1/blocklist/domains/\(id.uuidString)")
    }

    func addApp(bundleId: String, displayName: String) async throws -> BlockedApp {
        let body: [String: String] = ["bundle_id": bundleId, "display_name": displayName]
        return try await post("/api/v1/blocklist/apps", body: body)
    }

    func removeApp(id: UUID) async throws {
        try await delete("/api/v1/blocklist/apps/\(id.uuidString)")
    }

    // MARK: - Sessions

    func startSession(endsAt: Date?, unlockMethod: String) async throws -> BlockSession {
        var body: [String: String] = ["unlock_method": unlockMethod]
        if let endsAt {
            let formatter = ISO8601DateFormatter()
            body["ends_at"] = formatter.string(from: endsAt)
        }
        return try await post("/api/v1/sessions", body: body)
    }

    func getActiveSession() async throws -> BlockSession? {
        do {
            let session: BlockSession = try await get("/api/v1/sessions/active")
            return session
        } catch APIError.badRequest {
            return nil
        } catch APIError.serverError(let code) where code == 404 {
            return nil
        }
    }

    func submitUnblock(sessionId: UUID, unlockText: String) async throws {
        let body: [String: String] = ["unlock_text": unlockText]
        let _: EmptyResponse = try await post("/api/v1/sessions/\(sessionId.uuidString)/unblock", body: body)
    }

    // MARK: - Enrollment

    func getEnrollmentURL() -> URL? {
        guard let token = deviceManager?.deviceToken else { return nil }
        return URL(string: "\(baseURL)/api/v1/enroll/profile?device_token=\(token)")
    }

    // MARK: - HTTP helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "GET")
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    private func delete(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode)
        }
    }

    private func buildRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.badRequest("invalid url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = deviceManager?.deviceToken {
            request.setValue(token, forHTTPHeaderField: "X-Device-Token")
        }
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.decodingError
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown"
            if http.statusCode >= 400 && http.statusCode < 500 {
                throw APIError.badRequest(message)
            }
            throw APIError.serverError(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}

private struct EmptyResponse: Decodable {}

import Foundation

// MARK: - API Client (Cross-Platform)
actor APIClient {
    static let shared = APIClient()

    private let baseURL = "https://cuongthai.com"
    private let storage = StorageManager.shared

    private init() {}

    // MARK: - Request (expects `data` in the envelope)

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await perform(endpoint)
        let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard apiResponse.success, let responseData = apiResponse.data else {
            throw APIError.serverError(apiResponse.message ?? "Unknown error")
        }
        return responseData
    }

    // MARK: - Send (envelope carries no `data` — report, block, change-password…)

    @discardableResult
    func send(_ endpoint: APIEndpoint) async throws -> String? {
        let data = try await perform(endpoint)
        // Some endpoints answer `{success, message}` with no `data` key at all,
        // which `request()` would reject. Only the success flag matters here.
        let envelope = try? JSONDecoder().decode(EmptyEnvelope.self, from: data)
        if let envelope, envelope.success == false {
            throw APIError.serverError(envelope.message ?? "Unknown error")
        }
        return envelope?.message
    }

    // MARK: - Upload (multipart)

    /// POST /api/v1/files/upload — one file, field name `file`.
    /// Returns the public URL the feed should render.
    func upload(data fileData: Data,
                fileName: String,
                mimeType: String,
                category: String = "social") async throws -> UploadedFile {
        guard let url = URL(string: baseURL + "/api/v1/files/upload") else {
            throw APIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = storage.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"category\"\r\n\r\n")
        append("\(category)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(EmptyEnvelope.self, from: responseData),
               let message = envelope.message {
                throw APIError.serverError(message)
            }
            throw APIError.serverError("Tải ảnh lên thất bại (\(http.statusCode))")
        }

        let decoded = try JSONDecoder().decode(APIResponse<UploadedFile>.self, from: responseData)
        guard decoded.success, let file = decoded.data else {
            throw APIError.serverError(decoded.message ?? "Tải ảnh lên thất bại")
        }
        return file
    }

    // MARK: - Transport

    private func perform(_ endpoint: APIEndpoint, isRetry: Bool = false) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = storage.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Query params for GET
        if let params = endpoint.queryParams, endpoint.method == "GET" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            if let queryURL = components?.url { request.url = queryURL }
        }

        // Body for POST/PUT/PATCH/DELETE
        if let body = endpoint.body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        if httpResponse.statusCode == 401 {
            // Don't recurse: a 401 on the refresh call itself means the session is dead.
            if case .refreshToken = endpoint {
                storage.clearAuthTokens()
                throw APIError.unauthorized
            }
            if !isRetry, await refreshToken() {
                return try await perform(endpoint, isRetry: true)
            }
            throw APIError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let envelope = try? JSONDecoder().decode(EmptyEnvelope.self, from: data),
               let message = envelope.message {
                throw APIError.serverError(message)
            }
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }

        return data
    }

    private func refreshToken() async -> Bool {
        guard let refreshToken = storage.getRefreshToken() else { return false }
        do {
            // Backend returns a fresh AuthResponse — persist the new tokens,
            // otherwise the retried request re-sends the expired one and 401s again.
            let res: AuthResponse = try await request(.refreshToken(refreshToken))
            storage.saveAuthToken(res.token, refreshToken: res.refreshToken ?? refreshToken)
            return true
        } catch {
            storage.clearAuthTokens()
            return false
        }
    }
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL, noData, unauthorized, unknown
    case decodingError(Error)
    case serverError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .unauthorized: return "Please login again"
        case .unknown: return "An unknown error occurred"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        case .serverError(let m): return m
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        }
    }
}

// MARK: - API Response
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let message: String?
}

/// The envelope without its payload — used for endpoints that answer
/// `{success, message}` and for decoding error bodies.
struct EmptyEnvelope: Decodable {
    let success: Bool
    let message: String?
}


/// Response of POST /api/v1/files/upload.
struct UploadedFile: Decodable {
    let url: String
    let key: String?
    let thumbnail: String?
    let width: Int?
    let height: Int?
}

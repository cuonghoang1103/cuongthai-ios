import Foundation
import os

// MARK: - API Client (Cross-Platform)
actor APIClient {
    static let shared = APIClient()

    private static let log = Logger(subsystem: "com.cuongthai.app", category: "api")

    /// Ghi ra ĐÚNG trường nào sai và sai kiểu gì. `DecodingError` mang đủ
    /// thông tin đó, nhưng `localizedDescription` vứt hết — chỉ còn câu
    /// "The data couldn't be read", đọc xong vẫn không biết sửa ở đâu.
    static func ghiLoiGiaiMa(_ error: Error, duong: String) {
        guard let loi = error as? DecodingError else {
            log.error("[\(duong, privacy: .public)] giải mã hỏng: \(String(describing: error), privacy: .public)")
            return
        }
        let moTa: String
        switch loi {
        case .keyNotFound(let key, let ctx):
            moTa = "THIẾU KHOÁ '\(key.stringValue)' tại \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .typeMismatch(let kieu, let ctx):
            moTa = "SAI KIỂU, mong \(kieu) tại \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let kieu, let ctx):
            moTa = "GIÁ TRỊ NULL cho \(kieu) tại \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let ctx):
            moTa = "DỮ LIỆU HỎNG tại \(ctx.codingPath.map(\.stringValue).joined(separator: ".")): \(ctx.debugDescription)"
        @unknown default:
            moTa = String(describing: loi)
        }
        log.error("[\(duong, privacy: .public)] \(moTa, privacy: .public)")
    }

    private let baseURL = "https://cuongthai.com"
    private let storage = StorageManager.shared

    private init() {}

    // MARK: - Request (expects `data` in the envelope)

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await perform(endpoint)
        let apiResponse: APIResponse<T>
        do {
            apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        } catch {
            // Bọc lại: lỗi gốc của JSONDecoder là tiếng Anh và hiện thẳng ra
            // màn hình ("The data couldn't be read because it isn't in the
            // correct format") — vừa khó hiểu vừa không nói được sai ở đâu.
            throw APIError.decodingError(error)
        }
        guard apiResponse.success, let responseData = apiResponse.data else {
            throw APIError.serverError(apiResponse.message ?? "Máy chủ không trả về dữ liệu")
        }
        return responseData
    }

    // MARK: - Danh sách phân trang
    //
    // Backend KHÔNG có một hình dạng danh sách thống nhất. Đo thật 19/08/2026,
    // có tới bốn kiểu:
    //   /social/posts            → { data: [...], pagination: {nextCursor, hasNextPage} }
    //   /social/posts/:id/comments → y hệt trên
    //   /users/:id/posts         → { data: {items, nextCursor, hasMore} }   ← lồng
    //   /messages/threads        → { data: [...] }                          ← không phân trang
    //   /courses                 → { data: [...], pagination: {page, total, totalPages} }
    //
    // Model cũ giả định MỌI danh sách đều là kiểu lồng `{items,nextCursor,hasMore}`,
    // nên bảng tin, bình luận, tin nhắn và khoá học đều giải mã HỎNG. Trên màn
    // hình nó hiện ra thành "Không có tin nhắn nào" / "Chưa có bài viết" — nói
    // sai thành "trống rỗng" thay vì "hỏng".
    //
    // `requestList` đọc kiểu `data` là MẢNG + `pagination` nằm ngoài.
    func requestList<T: Decodable>(_ endpoint: APIEndpoint) async throws -> (items: [T], nextCursor: Int?, hasMore: Bool) {
        let raw = try await perform(endpoint)
        do {
            let envelope = try JSONDecoder().decode(DanhSachEnvelope<T>.self, from: raw)
            guard envelope.success else {
                throw APIError.serverError(envelope.message ?? "Không tải được danh sách")
            }
            return (
                envelope.data ?? [],
                envelope.pagination?.nextCursor,
                envelope.pagination?.hasNextPage ?? false
            )
        } catch let error as APIError {
            throw error
        } catch {
            Self.ghiLoiGiaiMa(error, duong: endpoint.path)
            throw APIError.decodingError(error)
        }
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
            // Với ĐĂNG NHẬP / ĐĂNG KÝ, 401 nghĩa là SAI THÔNG TIN, không phải
            // phiên hết hạn. Bản cũ ném thẳng `.unauthorized` nên người gõ sai
            // mật khẩu nhận được câu "Please login again" — vừa là tiếng Anh,
            // vừa nói sai chuyện, vừa che mất lý do thật máy chủ đã gửi kèm.
            switch endpoint {
            case .login, .register, .oauthToken, .changePassword:
                throw Self.loiTuThan(data) ?? APIError.serverError("Sai tên đăng nhập hoặc mật khẩu.")
            case .refreshToken:
                // Không đệ quy: 401 ngay trên lệnh làm mới nghĩa là phiên chết hẳn.
                storage.clearAuthTokens()
                throw APIError.unauthorized
            default:
                break
            }
            if !isRetry, await refreshToken() {
                return try await perform(endpoint, isRetry: true)
            }
            throw APIError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw Self.loiTuThan(data)
                ?? APIError.serverError("Máy chủ trả lỗi \(httpResponse.statusCode).")
        }

        return data
    }

    /// Rút câu giải thích máy chủ gửi kèm. Câu đó luôn sát thực tế hơn bất cứ
    /// câu chung chung nào ta tự bịa ở client.
    private static func loiTuThan(_ data: Data) -> APIError? {
        guard let envelope = try? JSONDecoder().decode(EmptyEnvelope.self, from: data),
              let message = envelope.message, !message.isEmpty
        else { return nil }
        return .serverError(message)
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
        // Người dùng đọc những câu này, nên chúng phải bằng tiếng Việt và nói
        // đúng chuyện. "Please login again" từng hiện ra khi gõ sai mật khẩu.
        case .invalidURL: return "Địa chỉ không hợp lệ."
        case .noData: return "Máy chủ không trả về dữ liệu."
        case .unauthorized: return "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại."
        case .unknown: return "Có lỗi không xác định."
        case .decodingError: return "Dữ liệu trả về không đúng định dạng."
        case .serverError(let m): return m
        case .networkError: return "Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại."
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


/// Envelope cho danh sách: `data` là MẢNG, `pagination` nằm NGOÀI `data`.
struct DanhSachEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: [T]?
    let pagination: BackendPagination?
    let message: String?
}

/// Backend dùng hai bộ tên khác nhau tuỳ endpoint (`nextCursor/hasNextPage`
/// cho feed & bình luận, `page/total/totalPages` cho khoá học). Khai cả hai,
/// tất cả optional, để một model đọc được mọi nơi.
struct BackendPagination: Decodable {
    let nextCursor: Int?
    let hasNextPage: Bool?
    let limit: Int?
    let page: Int?
    let total: Int?
    let totalPages: Int?
}

import Foundation

// ════════════════════════════════════════════════════════════════
// HỌC TIẾNG ANH BẰNG VIDEO — mô hình + gọi API
//
// Nguồn: 1.030 video bài giảng tiếng Anh đã có trên web, kèm phụ đề đã làm
// sạch (336.669 câu · 4,8 triệu từ). Không phải video tự tải lên — ta chỉ
// nhúng trình phát chính thức của YouTube.
// ════════════════════════════════════════════════════════════════

struct DanhMucVideo: Decodable, Identifiable, Hashable {
    let courseId: Int
    let title: String
    let slug: String?
    let thumbnail: String?
    let soVideo: Int

    var id: Int { courseId }
}

struct VideoHoc: Decodable, Identifiable, Hashable {
    let lessonId: Int
    let videoId: String
    let tieuDe: String
    let giay: Int?
    let soCau: Int
    let soTu: Int

    var id: Int { lessonId }

    /// "12 phút · 284 câu". Người học cần biết bài dài bao lâu TRƯỚC khi mở —
    /// mở ra thấy video 90 phút là đóng lại luôn.
    var moTaNgan: String {
        var p: [String] = []
        if let g = giay, g > 0 { p.append("\(max(1, g / 60)) phút") }
        p.append("\(soCau) câu")
        return p.joined(separator: " · ")
    }
}

struct CauPhuDe: Decodable, Identifiable, Hashable {
    let t: Double
    let en: String

    var id: String { "\(t)-\(en.prefix(12))" }

    var mocChu: String {
        let g = Int(t)
        return String(format: "%d:%02d", g / 60, g % 60)
    }
}

struct GoiPhuDe: Decodable {
    let lessonId: Int
    let videoId: String
    let tieuDe: String
    let soCau: Int
    let soTu: Int
    let cues: [CauPhuDe]
    let dichVi: [String]?
}

enum VideoHocAPI {
    static func danhMuc() async throws -> [DanhMucVideo] {
        try await APIClient.shared.request(.videoDanhMuc)
    }
    static func videoCuaKhoa(_ id: Int) async throws -> [VideoHoc] {
        try await APIClient.shared.request(.videoCuaKhoa(id: id))
    }
    static func phuDe(_ lessonId: Int) async throws -> GoiPhuDe {
        try await APIClient.shared.request(.videoPhuDe(lessonId: lessonId))
    }

    /// Gửi đoạn ghi âm nhại theo, nhận BẢN PHIÊN ÂM.
    ///
    /// Dựng multipart bằng tay như `guiAudioChamNoi` của IELTS: `APIClient`
    /// chỉ biết JSON, và thêm một nhánh multipart vào đó để dùng đúng hai
    /// chỗ là đổi một tầng chung lấy một tiện nghi nhỏ.
    static func nhai(duong: URL, cau: String) async throws -> KetQuaNhai {
        let bien = "Bien-\(UUID().uuidString)"
        var than = Data()
        func them(_ s: String) { than.append(s.data(using: .utf8)!) }

        them("--\(bien)\r\nContent-Disposition: form-data; name=\"cau\"\r\n\r\n")
        them(cau + "\r\n")
        them("--\(bien)\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"nhai.m4a\"\r\n")
        them("Content-Type: audio/m4a\r\n\r\n")
        than.append(try Data(contentsOf: duong))
        them("\r\n--\(bien)--\r\n")

        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/video-hoc/nhai") else {
            throw APIError.serverError("URL không hợp lệ")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(bien)", forHTTPHeaderField: "Content-Type")
        if let tok = StorageManager.shared.getAuthToken() {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        // Chỉ phiên âm (không chấm LLM) nên nhanh hơn `cham-noi` nhiều — 45s
        // là rộng rãi. Để 120s như bên kia thì lúc mạng chập chờn người học
        // ngồi nhìn vòng quay hai phút rồi mới biết là hỏng.
        req.timeoutInterval = 45
        req.httpBody = than

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.serverError("Không có phản hồi")
        }
        if http.statusCode == 401 { throw APIError.unauthorized }
        let goi = try JSONDecoder().decode(APIResponse<KetQuaNhai>.self, from: data)
        guard goi.success, let d = goi.data else {
            throw APIError.serverError(goi.message ?? "Máy chủ từ chối bản ghi")
        }
        return d
    }
}

struct KetQuaNhai: Decodable {
    let chu: String
    let imLang: Bool
}

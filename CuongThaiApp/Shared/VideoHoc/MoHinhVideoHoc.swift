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
}

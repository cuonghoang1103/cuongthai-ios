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
    /// Tiêu đề tiếng Việt. Tách từ `EN|||VI` ở backend — 963/963 bài đều có
    /// dấu này, và trước 19/09/2026 app hiện nguyên cục lên màn hình.
    let tieuDeVi: String?
    let giay: Int?
    let soCau: Int
    let soTu: Int
    /// `nil` = video bài giảng của web. `"youtube"`/`"tiktok"` = video người
    /// dùng tự thêm — khi đó `lessonId` ÂM và phụ đề nằm ở endpoint khác.
    var nguon: String? = nil
    /// Nhóm lớn (tầng ngoài của hàng chip): academy · hoathinh · nhac · …
    var nhomLon: String? = nil
    /// Ảnh bìa do máy chủ cấp (video TikTok không nằm trên CDN của YouTube).
    var anhBiaUrl: String? = nil

    var id: Int { lessonId }

    /// Video người dùng tự thêm: `lessonId` âm, và id thật là trị tuyệt đối.
    var laCuaToi: Bool { lessonId < 0 }
    var idCuaToi: Int { abs(lessonId) }

    /// Ảnh bìa lấy thẳng CDN của YouTube — không tốn R2, không cần backend
    /// lưu gì. `hqdefault` (480×360) luôn tồn tại; `maxresdefault` trả 404
    /// với video không có bản HD nên KHÔNG dùng.
    var anhBia: URL? {
        if let u = anhBiaUrl, !u.isEmpty { return URL(string: u) }
        return URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
    }

    /// "12:30" — hiện đè góc ảnh bìa như YouTube. `nil` khi chưa biết thời
    /// lượng (650/963 bài chưa có, đo 19/09/2026) — thà không hiện gì còn
    /// hơn hiện "0:00".
    var thoiLuong: String? {
        guard let g = giay, g > 0 else { return nil }
        let p = g / 60, gi = g % 60
        return p >= 60
            ? String(format: "%d:%02d:%02d", p / 60, p % 60, gi)
            : String(format: "%d:%02d", p, gi)
    }

    /// "12 phút · 284 câu". Người học cần biết bài dài bao lâu TRƯỚC khi mở —
    /// mở ra thấy video 90 phút là đóng lại luôn.
    var moTaNgan: String {
        var p: [String] = []
        if let g = giay, g > 0 { p.append("\(max(1, g / 60)) phút") }
        p.append("\(soCau) câu")
        return p.joined(separator: " · ")
    }
}

// MARK: - Thư viện (một lời gọi lấy tất cả)

struct NhomVideo: Decodable, Identifiable, Hashable {
    let ma: String
    let ten: String
    let icon: String
    let soKhoa: Int
    let soVideo: Int

    var id: String { ma }
}

/// Nhóm lớn dùng khi THÊM video — bảng tĩnh ở máy khách để người dùng chọn
/// được ngay lúc dán link, không phải chờ một lời gọi mạng nữa.
enum NhomLonChon: String, CaseIterable, Identifiable {
    case hoathinh, nhac, giaitri, lichsu, kinhdoanh, kynangmem, khoahoc
    case tintuc, doisong, game, thethao, hoc, khac

    var id: String { rawValue }
    var ten: String {
        switch self {
        case .hoathinh:  return "Hoạt hình & Phim"
        case .nhac:      return "Âm nhạc"
        case .giaitri:   return "Giải trí & Hài"
        case .lichsu:    return "Lịch sử"
        case .kinhdoanh: return "Kinh doanh"
        case .kynangmem: return "Kỹ năng"
        case .khoahoc:   return "Khoa học & Công nghệ"
        case .tintuc:    return "Tin tức"
        case .doisong:   return "Đời sống & Du lịch"
        case .game:      return "Game"
        case .thethao:   return "Thể thao"
        case .hoc:       return "Học thuật khác"
        case .khac:      return "Khác"
        }
    }
    var icon: String {
        switch self {
        case .hoathinh:  return "film"
        case .nhac:      return "music.note"
        case .giaitri:   return "face.smiling"
        case .lichsu:    return "building.columns"
        case .kinhdoanh: return "chart.line.uptrend.xyaxis"
        case .kynangmem: return "person.2.wave.2"
        case .khoahoc:   return "atom"
        case .tintuc:    return "newspaper"
        case .doisong:   return "figure.walk"
        case .game:      return "gamecontroller"
        case .thethao:   return "sportscourt"
        case .hoc:       return "book"
        case .khac:      return "square.grid.2x2"
        }
    }
}

struct KhoaVideo: Decodable, Identifiable, Hashable {
    let courseId: Int
    let title: String
    let slug: String?
    /// Tầng NGOÀI: 'academy' cho bài giảng của web, còn lại là video tự thêm.
    let nhomLon: String
    /// Tầng TRONG — chỉ có nghĩa bên trong Academy (Lập trình Web, Backend…).
    let nhom: String?
    let soVideo: Int
    let video: [VideoHoc]

    var id: Int { courseId }
    /// Hàng gom video tự thêm dùng courseId âm, không mở được trang môn học.
    var laKhoaThat: Bool { courseId > 0 }
}

struct ThuVienVideo: Decodable {
    /// Tầng ngoài: Academy · Hoạt hình & Phim · Âm nhạc · Lịch sử…
    let nhomLon: [NhomVideo]
    /// Tầng trong của Academy.
    let nhom: [NhomVideo]
    let khoa: [KhoaVideo]
    /// Mã video đã thích, mới nhất trước. Dương = bài giảng, âm = tự thêm.
    let yeuThich: [Int]
    /// Video người dùng tự thêm. Mặc định rỗng để bản backend cũ (chưa có
    /// khoá này) vẫn giải mã được — Swift chỉ tự dùng `decodeIfPresent` cho
    /// kiểu Optional, mảng có giá trị mặc định thì KHÔNG, nên phải tự viết
    /// `init(from:)` ở dưới.
    let cuaToi: [VideoHoc]

    static let rong = ThuVienVideo(nhomLon: [], nhom: [], khoa: [], yeuThich: [], cuaToi: [])

    init(nhomLon: [NhomVideo], nhom: [NhomVideo], khoa: [KhoaVideo],
         yeuThich: [Int], cuaToi: [VideoHoc]) {
        self.nhomLon = nhomLon; self.nhom = nhom; self.khoa = khoa
        self.yeuThich = yeuThich; self.cuaToi = cuaToi
    }

    private enum CodingKeys: String, CodingKey { case nhomLon, nhom, khoa, yeuThich, cuaToi }

    /// ⚠️ TỰ VIẾT, không để Swift tự sinh. `Decodable` tự sinh đòi ĐỦ MỌI
    /// khoá kể cả khi thuộc tính có giá trị mặc định — thiếu một khoá là cả
    /// gói hỏng, và ở tầng trên `try?` sẽ nuốt lỗi thành "không có video".
    init(from bo: Decoder) throws {
        let c = try bo.container(keyedBy: CodingKeys.self)
        nhomLon = try c.decodeIfPresent([NhomVideo].self, forKey: .nhomLon) ?? []
        nhom = try c.decodeIfPresent([NhomVideo].self, forKey: .nhom) ?? []
        khoa = try c.decodeIfPresent([KhoaVideo].self, forKey: .khoa) ?? []
        yeuThich = try c.decodeIfPresent([Int].self, forKey: .yeuThich) ?? []
        cuaToi = try c.decodeIfPresent([VideoHoc].self, forKey: .cuaToi) ?? []
    }
}

struct KetQuaYeuThich: Decodable {
    let ma: Int
    let yeuThich: Bool
}

/// Kết quả khi thêm một video.
struct VideoDaThem: Decodable {
    let id: Int
    let tieuDe: String
    let soCau: Int
    let soTu: Int
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
    let tieuDeVi: String?
    let soCau: Int
    let soTu: Int
    let cues: [CauPhuDe]
    let dichVi: [String]?
}

enum VideoHocAPI {
    static func danhMuc() async throws -> [DanhMucVideo] {
        try await APIClient.shared.request(.videoDanhMuc)
    }
    /// Cả thư viện trong MỘT lời gọi. Màn duyệt vẽ hàng ngang có ảnh bìa nên
    /// cần video của nhiều khoá cùng lúc — gọi `/khoa/:id` từng khoá là 48
    /// lời gọi mỗi lần mở màn hình.
    static func thuVien() async throws -> ThuVienVideo {
        try await APIClient.shared.request(.videoThuVien)
    }
    static func videoCuaKhoa(_ id: Int) async throws -> [VideoHoc] {
        try await APIClient.shared.request(.videoCuaKhoa(id: id))
    }
    static func phuDe(_ lessonId: Int) async throws -> GoiPhuDe {
        try await APIClient.shared.request(.videoPhuDe(lessonId: lessonId))
    }
    /// Phụ đề của một video NGƯỜI DÙNG tự thêm.
    static func phuDeCuaToi(_ id: Int) async throws -> GoiPhuDe {
        try await APIClient.shared.request(.videoPhuDeCuaToi(id: id))
    }
    /// Phụ đề cho bất kỳ video nào — tự chọn đúng endpoint.
    static func phuDeCua(_ v: VideoHoc) async throws -> GoiPhuDe {
        v.laCuaToi ? try await phuDeCuaToi(v.idCuaToi) : try await phuDe(v.lessonId)
    }
    static func themVideo(url: String, nhomLon: String?) async throws -> VideoDaThem {
        try await APIClient.shared.request(.videoThemCuaToi(url: url, nhomLon: nhomLon))
    }
    /// Bật/tắt yêu thích. Trả về trạng thái SAU khi đổi.
    static func doiYeuThich(_ ma: Int) async throws -> Bool {
        let r: KetQuaYeuThich = try await APIClient.shared.request(.videoYeuThich(ma: ma))
        return r.yeuThich
    }
    static func doiNhomVideo(_ id: Int, nhomLon: String) async throws {
        _ = try await APIClient.shared.requestRaw(.videoDoiNhom(id: id, nhomLon: nhomLon))
    }
    static func xoaVideoCuaToi(_ id: Int) async throws {
        _ = try await APIClient.shared.requestRaw(.videoXoaCuaToi(id: id))
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

        // Âm thanh đi tới Groq Whisper — cần đồng ý chia sẻ (5.1.2(i)).
        try await DongYChiaSeAI.batBuoc()
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

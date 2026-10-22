import Foundation

// ════════════════════════════════════════════════════════════════
// CÁC ĐƯỜNG API CỦA MÀN HỌC ACADEMY (22/10/2026)
//
// Gom về MỘT `case hocBai(HocBaiAPI)` trong `APIEndpoint` thay vì mười một
// case rải khắp bốn `switch` của tệp đó: nhiều nhánh cùng sửa `APIEndpoint`
// một lúc, và mỗi case mới là bốn chỗ chèn dễ giẫm nhau. Ở đây đường dẫn,
// phương thức và thân nằm sát nhau — sai một chỗ là thấy ngay chỗ kia.
//
// Truy vấn (`?gon=1`, `?resolve=1`, `?truoc=`) GHÉP THẲNG vào đường dẫn, đúng
// cách `getCoursesBySemester` đang làm — nên khoá đệm ngoại tuyến (tính từ
// `path`) phân biệt được hai bản gọn/đầy đủ.
//
// Chỉ `import Foundation`: thư mục `Network` còn dựng vào app Quản trị + CT Work.
// ════════════════════════════════════════════════════════════════

enum HocBaiAPI {
    /// `GET /courses/:slug?gon=1` — trang giới thiệu khoá: đủ cây chương→bài
    /// (cả bài bị khoá, để hiện ổ khoá) nhưng KHÔNG kèm `content` nặng.
    case khoaGon(slug: String)
    /// `GET /courses/:id/documents` — tài liệu cấp khoá (cần ghi danh/Pro).
    case taiLieuKhoa(courseId: Int)
    /// `GET /courses/documents/:id/download?resolve=1` ⇒ `{url, fileType, title}` (URL ký 5 phút).
    case moTaiLieu(id: Int)
    /// `GET /courses/lessons/:id/assignments`
    case baiTapCuaBai(lessonId: Int)
    /// `POST /courses/assignments/submit` `{assignmentId, submissionUrl, notes}`
    case nopBaiTap(assignmentId: Int, duongDan: String, ghiChu: String?)
    /// `POST /courses/lessons/:id/duration` `{seconds}` — máy chủ chỉ ghi khi đang là 0.
    case baoThoiLuong(lessonId: Int, giay: Int)
    /// `GET /courses/lessons/:id/ai/asks[?truoc=<id>]` — 40 câu một trang + `conNua`.
    case cauHoiThuongGap(lessonId: Int, truoc: Int?)
    /// `GET /code-lab/practice/:courseSlug/:lessonSlug`
    case boLuyenCodeLab(courseSlug: String, lessonSlug: String)
    /// `POST /notes/ghi-nhanh/khoa/luu` — "Lưu vào sổ tay" một đoạn của bài.
    case luuDoanSoTay(courseSlug: String, lessonId: Int, text: String, laCode: Bool)
    /// `GET /notes/ghi-nhanh/khoa/:slug/bai/:id` — các đoạn đã lưu của bài này.
    case doanSoTayCuaBai(courseSlug: String, lessonId: Int)
    /// `GET /certificates/course/:id` — 404 khi chưa đủ điều kiện.
    case chungChiKhoa(courseId: Int)

    var duong: String {
        switch self {
        case .khoaGon(let s): return "/api/v1/courses/\(Self.ma(s))?gon=1"
        case .taiLieuKhoa(let id): return "/api/v1/courses/\(id)/documents"
        case .moTaiLieu(let id): return "/api/v1/courses/documents/\(id)/download?resolve=1"
        case .baiTapCuaBai(let l): return "/api/v1/courses/lessons/\(l)/assignments"
        case .nopBaiTap: return "/api/v1/courses/assignments/submit"
        case .baoThoiLuong(let l, _): return "/api/v1/courses/lessons/\(l)/duration"
        case .cauHoiThuongGap(let l, let t):
            if let t, t > 0 { return "/api/v1/courses/lessons/\(l)/ai/asks?truoc=\(t)" }
            return "/api/v1/courses/lessons/\(l)/ai/asks"
        case .boLuyenCodeLab(let k, let b): return "/api/v1/code-lab/practice/\(Self.ma(k))/\(Self.ma(b))"
        case .luuDoanSoTay: return "/api/v1/notes/ghi-nhanh/khoa/luu"
        case .doanSoTayCuaBai(let k, let l): return "/api/v1/notes/ghi-nhanh/khoa/\(Self.ma(k))/bai/\(l)"
        case .chungChiKhoa(let id): return "/api/v1/certificates/course/\(id)"
        }
    }

    var phuongThuc: String {
        switch self {
        case .nopBaiTap, .baoThoiLuong, .luuDoanSoTay: return "POST"
        default: return "GET"
        }
    }

    var than: [String: Any]? {
        switch self {
        case let .nopBaiTap(id, url, ghiChu):
            var m: [String: Any] = ["assignmentId": id, "submissionUrl": url]
            if let g = ghiChu?.trimmingCharacters(in: .whitespacesAndNewlines), !g.isEmpty { m["notes"] = g }
            return m
        case let .baoThoiLuong(_, giay): return ["seconds": giay]
        case let .luuDoanSoTay(k, l, t, code):
            return ["courseSlug": k, "lessonId": l, "text": String(t.prefix(5000)), "laCode": code]
        default: return nil
        }
    }

    /// Mã hoá MỘT đoạn đường dẫn (slug lạ có dấu/khoảng trắng không làm vỡ URL).
    private static func ma(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))) ?? s
    }
}

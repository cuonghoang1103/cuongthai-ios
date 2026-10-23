import Foundation

// ════════════════════════════════════════════════════════════════
// CÁC ĐƯỜNG API MỚI CỦA VỞ (23/10/2026)
//
// Thẻ ôn từ trang Vở · chữ nhận dạng lên máy chủ (tìm trên web) · link chỉ
// xem một trang. Gom về MỘT `case voMoi(VoMoiAPI)` trong `APIEndpoint` (cùng
// lý do với `HocBaiAPI`): mỗi đường mới khỏi phải chèn vào bốn `switch` của
// tệp đó, nơi nhiều nhánh cùng sửa một lúc.
//
// Hợp đồng ở `src/routes/vo.routes.ts` (backend). Chỉ `import Foundation`:
// thư mục `Network` còn dựng vào app Quản trị + CT Work.
// ════════════════════════════════════════════════════════════════

enum VoMoiAPI {
    /// `POST /vo/chu` `{ trangs: [{ clientId, chu }] }` — chữ Vision đọc được
    /// trên iPad, để web tìm được chữ viết tay. ⇒ `{ daLuu, khongThay }`.
    case dayChu(trangs: [[String: Any]])
    /// `POST /vo/on-the/rut/viec` — AI rút ý chính + câu hỏi + thẻ từ MỘT trang,
    /// CHẠY NỀN (`{viec}` ngay), hỏi lại bằng `xemRutThe`.
    case rutThe(than: [String: Any])
    case xemRutThe(viec: String)
    /// `POST /vo/on-the` — lưu thẻ người dùng đã duyệt (idempotent theo `clientId`).
    case luuThe(than: [String: Any])
    /// `GET /vo/on-the/trang?clientId=` — ý chính + thẻ của một trang.
    case theCuaTrang(clientId: String)
    /// `GET /vo/on-the/hom-nay?gioiHan=&den=&tuNgay=`
    case theHomNay(gioiHan: Int, den: String, tuNgay: String)
    /// `POST /vo/on-the/:id/cham` `{ muc: lai|kho|tot|de }`
    case chamThe(id: Int, muc: String)
    case suaThe(id: Int, truoc: String, sau: String)
    case xoaThe(id: Int)
    /// `POST /vo/trang/:noteId/chia-se` ⇒ `{ token, duongDan }`; `DELETE` = thu hồi.
    case taoLinh(noteId: Int)
    case thuHoiLinh(noteId: Int)

    var duong: String {
        switch self {
        case .dayChu: return "/api/v1/vo/chu"
        case .rutThe: return "/api/v1/vo/on-the/rut/viec"
        case .xemRutThe(let v): return "/api/v1/vo/on-the/rut/viec/\(Self.ma(v))"
        case .luuThe: return "/api/v1/vo/on-the"
        case .theCuaTrang(let c): return "/api/v1/vo/on-the/trang?clientId=\(Self.ma(c))"
        case .theHomNay(let n, let den, let tu):
            return "/api/v1/vo/on-the/hom-nay?gioiHan=\(n)&den=\(Self.ma(den))&tuNgay=\(Self.ma(tu))"
        case .chamThe(let id, _): return "/api/v1/vo/on-the/\(id)/cham"
        case .suaThe(let id, _, _), .xoaThe(let id): return "/api/v1/vo/on-the/\(id)"
        case .taoLinh(let id), .thuHoiLinh(let id): return "/api/v1/vo/trang/\(id)/chia-se"
        }
    }

    var phuongThuc: String {
        switch self {
        case .xemRutThe, .theCuaTrang, .theHomNay: return "GET"
        case .suaThe: return "PATCH"
        case .xoaThe, .thuHoiLinh: return "DELETE"
        default: return "POST"
        }
    }

    var than: [String: Any]? {
        switch self {
        case .dayChu(let ds): return ["trangs": ds]
        case .rutThe(let t), .luuThe(let t): return t
        case .chamThe(_, let muc): return ["muc": muc]
        case .suaThe(_, let a, let b): return ["truoc": a, "sau": b]
        default: return nil
        }
    }

    /// Thân ảnh base64 ~0,5–1,5MB — 60 giây mặc định là sát khi mạng yếu.
    var choLau: Bool {
        if case .rutThe = self { return true }
        return false
    }

    /// Mã hoá MỘT đoạn đường dẫn / giá trị truy vấn.
    private static func ma(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? s
    }
}

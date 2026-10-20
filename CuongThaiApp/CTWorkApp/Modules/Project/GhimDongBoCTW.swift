import Foundation

// MARK: - Ghim mô-đun ĐỒNG BỘ với web — `users.preferences.work.navPins` (21/10/2026)
//
// Nguồn sự thật như web (`shell/navPins.ts` + `shell/sidebarNav.ts`): `GET/PATCH /api/v1/users/me/preferences`,
// khoá `preferences.work.navPins = { "<projectId>": { pin: [...], hide: [...] } }`.
//   · `pin`  = mục NGOÀI bộ cốt lõi kéo lên điều hướng chính; `hide` = mục cốt lõi cất vào "More". Vắng = chưa tuỳ chỉnh.
//   · Bộ cốt lõi theo loại dự án = `coreFor(kind, template, type)` của web (Kanban bỏ Backlog).
//   · PATCH CHỈ gửi `{preferences:{work:{navPins:{<pid>: entry|null}}}}` — máy chủ gộp theo TỪNG dự án (`mergeNavPins`),
//     không đụng ngôn ngữ CT Work, hồ sơ Academy hay mục khác của cùng route (app chính PATCH `academy` ở đây).
// Mã mục = đoạn đường web (`board`, `docs`, `timeline`…) = id mô-đun iOS. Mục chỉ có trên iOS (`ai`, `calendar`, `time`,
// `sprints`, `classes`, `agents`, `workspace`) ghi y nguyên — web lọc theo mục nó có (`byPath.has`) nên bỏ qua vô hại, và
// `togglePin` của web giữ nguyên mục lạ khi người dùng ghim trên web. `list` của web không phải mô-đun iOS (List nằm trên
// công tắc Board · Backlog · List của trang dự án) ⇒ iOS không đụng tới nó.

struct CTWGhimMuc: Codable, Equatable {
    var pin: [String] = []
    var hide: [String] = []
    var daTuyChinh: Bool { !pin.isEmpty || !hide.isEmpty }
}

enum CTWGhim {
    /// `CORE_BY_KIND` của web.
    static let cotLoiTheoLoai: [String: [String]] = [
        "PERSONAL": ["board", "list", "docs", "timeline"],
        "SCHOOL": ["board", "backlog", "list", "docs", "chat", "meetings", "submit", "timeline"],
        "SOFTWARE": ["backlog", "board", "list", "docs", "chat", "code", "releases"],
        "CLIENT": ["backlog", "board", "list", "docs", "chat", "code", "releases", "approvals", "portal"],
    ]
    /// `CORE_BY_TEMPLATE` của web.
    static let cotLoiTheoMau: [String: [String]] = [
        "SWT301": ["tests"], "SWR302": ["requirements", "wiegers"], "CAPSTONE": ["requirements", "wiegers"], "SWP391": ["requirements"],
    ]
    /// Mục cốt lõi CHỈ CÓ trên iOS: trợ lý AI (web mở bằng nút nổi, không nằm trên thanh bên) — bỏ ghim được như mục khác.
    static let cotLoiRiengIOS = ["ai"]

    /// `sidebarKind` của web.
    static func loaiDuAn(kind: String?, template: String?) -> String {
        if let k = kind, cotLoiTheoLoai[k] != nil { return k }
        switch template ?? "" {
        case "FREELANCE", "COMPANY": return "CLIENT"
        case "SWR302", "SWT301", "SWP391", "CAPSTONE": return "SCHOOL"
        default: return "SOFTWARE"
        }
    }

    /// `coreFor` của web (giữ cả `list` — web cần nó; iOS bỏ qua khi dựng điều hướng).
    static func cotLoiWeb(kind: String?, template: String?, type: String?) -> [String] {
        var out = cotLoiTheoLoai[loaiDuAn(kind: kind, template: template)] ?? []
        for x in cotLoiTheoMau[template ?? ""] ?? [] where !out.contains(x) { out.append(x) }
        return type == "KANBAN" ? out.filter { $0 != "backlog" } : out
    }

    /// Bộ cốt lõi của app iOS = web + mục riêng iOS.
    static func cotLoi(kind: String?, template: String?, type: String?) -> [String] {
        var out = cotLoiWeb(kind: kind, template: template, type: type)
        for x in cotLoiRiengIOS where !out.contains(x) { out.append(x) }
        return out
    }

    static func laChinh(_ id: String, cotLoi: [String], _ e: CTWGhimMuc?) -> Bool {
        if e?.hide.contains(id) == true { return false }
        return cotLoi.contains(id) || e?.pin.contains(id) == true
    }

    /// `togglePin` của web.
    static func doiGhim(_ id: String, bat: Bool, cotLoi: [String], _ e: CTWGhimMuc?) -> CTWGhimMuc {
        var pin = (e?.pin ?? []).filter { $0 != id }
        var hide = (e?.hide ?? []).filter { $0 != id }
        let trongCotLoi = cotLoi.contains(id)
        if bat && !trongCotLoi { pin.append(id) }
        if !bat && trongCotLoi { hide.append(id) }
        return CTWGhimMuc(pin: pin, hide: hide)
    }

    /// `primaryOrder` của web: cốt lõi theo thứ tự loại dự án, rồi mục đã ghim theo thứ tự ghim.
    static func thuTuChinh(cotLoi: [String], _ e: CTWGhimMuc?) -> [String] {
        var out = cotLoi.filter { laChinh($0, cotLoi: cotLoi, e) }
        for p in e?.pin ?? [] where !out.contains(p) { out.append(p) }
        return out
    }

    /// Mặc định CŨ của app (trước 21/10, ghim chung mọi dự án, lưu cục bộ).
    static let macDinhCu = ["ai", "board", "backlog", "chat", "docs", "meetings", "calendar", "code"]

    /// Chuyển lựa chọn cũ (một danh sách cho MỌI dự án) sang mục của MỘT dự án: chỉ giữ những gì người dùng ĐÃ ĐỔI so
    /// với mặc định cũ — ghim thêm ⇒ `pin` (nếu không thuộc cốt lõi mới), bỏ ghim mục cũ ⇒ `hide` (nếu thuộc cốt lõi mới).
    /// Không đổi gì ⇒ nil (để bộ cốt lõi theo loại dự án quyết định, như web).
    static func tuBanCu(_ cu: [String], cotLoi: [String]) -> CTWGhimMuc? {
        let them = cu.filter { !macDinhCu.contains($0) && !cotLoi.contains($0) }
        let bo = macDinhCu.filter { !cu.contains($0) && cotLoi.contains($0) }
        let e = CTWGhimMuc(pin: them, hide: bo)
        return e.daTuyChinh ? e : nil
    }

    /// Thân PATCH: chỉ khoá `work.navPins` của MỘT dự án (`NSNull` = về mặc định).
    static func thanPatch(pid: Int, _ e: CTWGhimMuc?) -> [String: Any] {
        let gt: Any = e.map { ["pin": $0.pin, "hide": $0.hide] } ?? NSNull()
        return ["preferences": ["work": ["navPins": [String(pid): gt]]]]
    }
}

// MARK: API

/// `GET /users/me/preferences` — chỉ đọc `preferences.work.navPins` (giải mã khoan dung: mục hỏng bỏ qua).
struct CTWTuyChonNguoiDung: Decodable {
    var navPins: [String: CTWGhimMuc] = [:]
    private enum K: String, CodingKey { case preferences }
    private enum P: String, CodingKey { case work }
    private enum W: String, CodingKey { case navPins }
    private struct Muc: Decodable {
        var pin: [String]?
        var hide: [String]?
        private enum K: String, CodingKey { case pin, hide }
        init(from decoder: Decoder) throws {
            let c = try? decoder.container(keyedBy: K.self)
            pin = (try? c?.decodeIfPresent([String].self, forKey: .pin)) ?? nil
            hide = (try? c?.decodeIfPresent([String].self, forKey: .hide)) ?? nil
        }
    }

    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: K.self),
              let p = try? c.nestedContainer(keyedBy: P.self, forKey: .preferences),
              let w = try? p.nestedContainer(keyedBy: W.self, forKey: .work),
              let m = try? w.decodeIfPresent([String: Muc].self, forKey: .navPins) else { return }
        for (k, v) in m { navPins[k] = CTWGhimMuc(pin: v.pin ?? [], hide: v.hide ?? []) }
    }
}

extension CTWAPI {
    /// ⚠️ Route NGOÀI `/api/v1/work` ⇒ không đi `workGoi`. GET dùng case sẵn có `layTuyChonNguoiDung`; PATCH dùng
    /// `tuyChinh` (đường dẫn gói trong hàm có kiểu này — nơi gọi không gõ chuỗi) để không phải sửa APIEndpoint.swift chung.
    static var tuyChonNguoiDung: APIEndpoint { .layTuyChonNguoiDung }
    static func luuGhim(pid: Int, _ e: CTWGhimMuc?) -> APIEndpoint {
        .tuyChinh(duong: "/api/v1/users/me/preferences", phuongThuc: "PATCH", than: CTWGhim.thanPatch(pid: pid, e))
    }
}

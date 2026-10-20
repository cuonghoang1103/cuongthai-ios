import Foundation

// MARK: - Tên MẶC ĐỊNH của trạng thái / loại thẻ — dịch khi HIỂN THỊ (21/10/2026, như web `i18n/names.ts`)
//
// Tên trạng thái / loại thẻ là DỮ LIỆU của dự án (đội tự đổi được, JQL tìm theo tên gốc). Chỉ dịch phần hiển thị của
// những tên MẶC ĐỊNH do mẫu dự án tạo ("To Do", "In Progress", "Story", "Bug"…); tên tự đặt giữ nguyên.
// ⛔ KHÔNG BAO GIỜ gửi tên đã dịch lên máy chủ (bộ lọc JQL, đổi trạng thái theo tên…) — luôn gửi `name` gốc.
//
// Bảng dịch: `CTWorkApp/TenMacDinhCTW.xcstrings` (khoá `st.*` / `ty.*`, bản vi lấy đúng `i18n/vi/status.ts` của web).
// App chính (cũng biên dịch tệp này) không có bảng + `CTWDinhDang.locale` = en_US ⇒ trả nguyên tên.

enum CTWTen {
    /// Tên trạng thái mặc định (thường hoá, bỏ khoảng trắng hai đầu) ⇒ khoá bảng dịch. Cùng danh sách `STATUS` của web.
    static let khoaTrangThai: [String: String] = [
        "to do": "st.toDo", "in progress": "st.inProgress", "done": "st.done", "in review": "st.inReview",
        "code review": "st.codeReview", "qa": "st.qa", "backlog": "st.backlog", "open": "st.open",
        "closed": "st.closed", "fixed": "st.fixed", "reopened": "st.reopened", "retest": "st.retest",
        "selected": "st.selected", "doing": "st.doing",
    ]
    /// Cùng danh sách `TYPE` của web.
    static let khoaLoai: [String: String] = [
        "epic": "ty.epic", "story": "ty.story", "task": "ty.task", "bug": "ty.bug",
        "requirement": "ty.requirement", "test": "ty.test", "sub-task": "ty.subtask", "subtask": "ty.subtask",
    ]

    /// Tên trạng thái để HIỂN THỊ theo ngôn ngữ app. Tiếng Anh / tên tự đặt ⇒ nguyên văn.
    static func trangThai(_ ten: String) -> String { dich(ten, khoaTrangThai) ?? ten }

    /// Tên loại thẻ để HIỂN THỊ theo ngôn ngữ app.
    static func loai(_ ten: String) -> String { dich(ten, khoaLoai) ?? ten }

    /// Tên trạng thái cho chip/cột: tên mặc định đã dịch giữ nguyên chữ hoa của bản dịch; còn lại viết kiểu câu như web
    /// (`CTWKieuWeb.chuCau`: "IN REVIEW" ⇒ "In review").
    static func trangThaiCau(_ ten: String) -> String {
        dich(ten, khoaTrangThai) ?? CTWKieuWeb.chuCau(ten)
    }

    /// nil = không dịch (tiếng Anh, tên tự đặt, hoặc app không có bảng).
    static func dich(_ ten: String, _ bang: [String: String]) -> String? {
        guard CTWDinhDang.laTiengViet, let k = bang[ten.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] else { return nil }
        let v = Bundle.main.localizedString(forKey: k, value: "\u{0}", table: "TenMacDinhCTW")
        return v == "\u{0}" || v == k ? nil : v
    }
}

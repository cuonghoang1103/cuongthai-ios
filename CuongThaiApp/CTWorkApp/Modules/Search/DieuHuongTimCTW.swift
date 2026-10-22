import SwiftUI

// MARK: - Tìm mọi thứ (⌘K) — lối vào + điều hướng tới kết quả (21/10/2026)
//
// Lối vào (luôn với tới):
//   · nút kính lúp ở thanh trên của MỌI màn gốc (My Work, Projects, Chat, Inbox, Account; iPad: cột chi tiết) — gắn MỘT
//     chỗ ở `CotNganXepCTW` (KhungCTW.swift), mô-đun không phải làm gì;
//   · iPad: dòng "Search ⌘K" đầu thanh bên;
//   · ⌘K trên bàn phím (iPad/iPhone có bàn phím rời) — nút ẩn ở `GanTimKiemCTW`.
// Màn tìm là MỘT tấm phủ của khung (`DieuHuongTimCTW.tamPhu`); chọn kết quả ⇒ đóng tấm phủ rồi đi bằng các lối có sẵn:
//   thẻ ⇒ `AppState.ctWorkDich` (như thông báo đẩy) · mô-đun ⇒ `AppState.muc` + `dichCho` (như deep link) ·
//   dự án ⇒ `AppState.luaChon` · List/JQL ⇒ `jqlCho` (DanhSachCTW nhận) · tìm mọi thẻ ⇒ `chuMyWork` (ô tìm My Work) ·
//   Tin nhắn/Thành viên (cấp ứng dụng) ⇒ `KhoTinNhanCTW.moMoDun` (iPhone: phân đoạn của tab Chat) · người ⇒ hồ sơ / chat 1-1.

/// Câu JQL chờ màn List (Backlog › All issues) của dự án `pid` nhận. `id` mới mỗi lần ⇒ cùng câu vẫn chạy lại.
struct JqlChoCTW: Equatable {
    var pid: Int
    var jql: String
    var id = UUID()
}

@MainActor
final class DieuHuongTimCTW: ObservableObject {
    static let shared = DieuHuongTimCTW()

    /// MỘT tấm phủ cho mọi thứ màn tìm mở ra (bẫy C5: một view một `.sheet`).
    enum TamPhu: Identifiable {
        case timKiem(String)
        case taoThe(CTWProjectConfig)
        case chonDuAn
        case caiDatThongBao
        case taoCuongMini(CTWWorkspace, CTWDauVaoCM?)
        case duAnMoi(CTWWorkspace)
        /// Ô soạn bài Bảng tin (lệnh "Đăng bài").
        case dangBai

        var id: String {
            switch self {
            case .timKiem: return "tim"
            case .taoThe(let c): return "tao-\(c.id)"
            case .chonDuAn: return "duan"
            case .caiDatThongBao: return "tb"
            case .taoCuongMini(let w, _): return "cm-\(w.id)"
            case .duAnMoi(let w): return "moi-\(w.id)"
            case .dangBai: return "dangBai"
            }
        }
    }

    @Published var tamPhu: TamPhu?
    @Published var jqlCho: JqlChoCTW?
    /// Chữ cần đặt vào ô tìm của My Work ("Search all issues for …" — như `/work/search?q=` của web).
    @Published var chuMyWork: String?

    private init() {}

    private var app: AppState { AppState.shared }

    func moTimKiem(_ q: String = "") {
        if case .timKiem = tamPhu { tamPhu = nil; return }   // ⌘K lần nữa ⇒ đóng (như web)
        tamPhu = .timKiem(q)
    }

    /// Đóng màn tìm rồi chạy `viec` sau khi tấm phủ đã khuất (đẩy màn trong lúc tấm phủ đang đóng hay bị rơi).
    func dongRoi(_ viec: @escaping @MainActor () -> Void) {
        tamPhu = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            viec()
        }
    }

    /// Đổi sang tấm phủ khác (tạo thẻ, chọn dự án…) — đóng hẳn cái cũ trước (đổi `item` tại chỗ đôi khi không mở).
    func doiTamPhu(_ t: TamPhu) {
        tamPhu = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            tamPhu = t
        }
    }

    // MARK: Đích

    func moThe(slug: String, ma: String, so: Int) {
        app.muc = .viecCuaToi
        app.ctWorkDich = CTWDich(slug: slug, maDuAn: ma, so: so)
    }

    /// Mô-đun của dự án đang chọn. iPhone: tab Projects đẩy màn mô-đun (`TrangDuAnCTW` đọc `dichCho`); iPad: mục thanh bên.
    func moMoDun(_ id: String, phanCon: [String] = []) {
        guard let m = CTWDangKyMoDun.moDun(id) else { return }
        // Mô-đun cấp ứng dụng (Tin nhắn, Thành viên): không cần dự án, không đọc `dichCho`.
        if m.capUngDung { KhoTinNhanCTW.shared.moMoDun(m.id); return }
        guard let l = app.luaChon else { app.muc = .moDun(id); return }
        // `tk` mới mỗi lần ⇒ `.task(id: dichCho)` luôn chạy lại dù vừa mở đúng mô-đun này.
        let d = DuongDanCTW(slug: l.slug, maDuAn: l.maDuAn, doan: m.doanWeb ?? m.id, phanCon: phanCon, tham: ["tk": UUID().uuidString])
        let dich = DichMoDunCTW(moDun: m.id, pid: l.pid, duongDan: d)
        app.muc = .moDun(m.id)
        app.dichCho = dich
        // Mô-đun không đọc `dichCho` thì cờ nằm lại ⇒ trang dự án (iPhone) chạy lại `.task(id:)` mỗi lần hiện lại và đẩy
        // mô-đun lần nữa. Gỡ cờ CỦA MÌNH sau khi mọi màn đã kịp đọc.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if AppState.shared.dichCho == dich { AppState.shared.dichCho = nil }
        }
    }

    /// Dự án khác ⇒ chọn rồi mở Board (iPhone: tab Projects về gốc, công tắc Board).
    func moDuAn(_ l: LuaChonCTW) {
        app.luaChon = l
        moMoDun("board")
    }

    /// Trang tài liệu (có thể ở dự án khác) — đi đúng đường deep link `/work/<ws>/<KEY>/docs/<n>`.
    func moTrang(slug: String, ma: String, so: Int) {
        DinhTuyenCTW.mo(duongDan: "/work/\(CTWAPI.doan(slug))/\(CTWAPI.doan(ma))/docs/\(so)?tk=\(UUID().uuidString)")
    }

    /// List (Backlog › All issues) của dự án đang chọn với câu JQL sẵn.
    func moJql(_ jql: String) {
        guard let l = app.luaChon else { return }
        jqlCho = JqlChoCTW(pid: l.pid, jql: jql)
        moMoDun("backlog", phanCon: ["list"])
    }

    /// Tìm mọi thẻ (My Work › ô tìm + bộ lọc) với chữ sẵn.
    func moTimMoiThe(_ q: String) {
        app.muc = .viecCuaToi
        chuMyWork = q
    }

    func moKhongGian(slug: String) {
        app.muc = .viecCuaToi
        app.ctWorkDich = CTWDich(slug: slug)
    }
}

// MARK: - Đếm "hay dùng" (theo người dùng, chỉ trên máy)

/// Số lần mở mỗi chức năng (`MucTimCTW.id`: "mod:board", "app:inbox"…) — màn tìm trống hiện mục hay dùng nhất.
/// Đếm khi mở qua màn tìm và khi mở mô-đun ở bất cứ đâu (`ManMoDunCTW`).
@MainActor
enum DungNhieuCTW {
    private static var khoa: String {
        "com.cuongthai.ctwork.timKiem.dungNhieu.\(AppState.shared.currentUser.map { String($0.id) } ?? "_")"
    }

    static func bang() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: khoa) as? [String: Int]) ?? [:]
    }

    static func dem(_ id: String) {
        var b = bang()
        b[id, default: 0] += 1
        if b.count > 60 {   // giữ gọn: bỏ mục ít dùng nhất
            for (k, _) in b.sorted(by: { $0.value < $1.value }).prefix(b.count - 60) { b[k] = nil }
        }
        UserDefaults.standard.set(b, forKey: khoa)
    }
}

// MARK: - Nút + gắn vào khung

/// Kính lúp ở thanh trên của màn gốc.
struct NutTimKiemCTW: View {
    var body: some View {
        Button { DieuHuongTimCTW.shared.moTimKiem() } label: {
            Image(systemName: "magnifyingglass")
        }
        .accessibilityLabel(Text("Search everything"))
        .accessibilityIdentifier("search.open")
    }
}

/// Gắn ở `KhungCTW`: ⌘K + tấm phủ tìm kiếm (và các tấm phủ nó mở: tạo thẻ, chọn dự án, CuongMini…).
struct GanTimKiemCTW: ViewModifier {
    @ObservedObject private var dh = DieuHuongTimCTW.shared
    @EnvironmentObject private var app: AppState
    @Environment(\.horizontalSizeClass) private var beRong

    func body(content: Content) -> some View {
        content
            .background {
                // Nút ẩn chỉ để giữ phím tắt ⌘K (hiện trong bảng phím tắt khi giữ ⌘ trên iPad).
                Button("Search") { dh.moTimKiem() }
                    .keyboardShortcut("k", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
            .sheet(item: $dh.tamPhu) { t in
                switch t {
                case .timKiem(let q):
                    TimKiemCTW(chuDau: q, rong: beRong == .regular)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .taoThe(let cfg):
                    CTWCreateIssueView(cauHinh: cfg, sprintId: nil) { _ in }
                case .chonDuAn:
                    ChonDuAnCTW()
                case .caiDatThongBao:
                    CaiDatThongBaoTamPhuCTW()
                case .dangBai:
                    SoanBaiCTW(noi: nil)
                case .taoCuongMini(let w, let dv):
                    TaoCuongMiniCTW(ws: w, mangSang: dv) { p in chonDuAnMoi(w, id: p.id, ma: p.key, ten: p.name) }
                case .duAnMoi(let w):
                    TaoDuAnCTW(ws: w) { p in
                        chonDuAnMoi(w, id: p.id, ma: p.key, ten: p.name)
                    } sangCuongMini: { dv in
                        dh.doiTamPhu(.taoCuongMini(w, dv))   // mang theo mô tả đã gõ
                    }
                }
            }
            #if DEBUG
            // `CT_XEM_MAN=tim` (+ `CT_XEM_TIM=<chữ>`) ⇒ mở sẵn màn tìm với máy chủ giả.
            .task {
                guard XemThuCTW.man?.lowercased() == "tim", dh.tamPhu == nil else { return }
                try? await Task.sleep(nanoseconds: 900_000_000)
                dh.tamPhu = .timKiem(ProcessInfo.processInfo.environment["CT_XEM_TIM"] ?? "")
            }
            #endif
    }

    private func chonDuAnMoi(_ ws: CTWWorkspace, id: Int, ma: String, ten: String) {
        dh.tamPhu = nil
        app.luaChon = LuaChonCTW(slug: ws.slug, tenKhongGian: ws.name, pid: id, maDuAn: ma, tenDuAn: ten)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            DieuHuongTimCTW.shared.moMoDun("board")
        }
    }
}

/// Cài đặt thông báo mở từ màn tìm (ở Account nó là màn được ĐẨY, ở đây là tấm phủ ⇒ cần khung + nút Đóng).
private struct CaiDatThongBaoTamPhuCTW: View {
    @Environment(\.dismiss) private var dong
    var body: some View {
        NavigationStack {
            CaiDatThongBaoCTW()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
        }
    }
}

extension View {
    /// Gắn tìm kiếm toàn cục (⌘K + tấm phủ). Chỉ gắn MỘT lần, ở `KhungCTW`.
    func ctwTimKiemToanCuc() -> some View { modifier(GanTimKiemCTW()) }
}

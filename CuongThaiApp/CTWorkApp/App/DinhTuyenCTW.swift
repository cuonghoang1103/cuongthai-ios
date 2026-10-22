import Foundation

// MARK: - Mở một đích trong app từ đường dẫn
//
// Ba nguồn cùng đi qua đây:
//   · `ctwork://work/<ws>/<KEY>/issue/12`, `ctwork://issue/KEY-12` (app chính, người dùng dán)
//   · `https://cuongthai.com/work/...` (Universal Link — cần AASA ở máy chủ)
//   · `duongDan` trong gói thông báo đẩy (`/work/<ws>/<KEY>/issue/12?comment=3`,
//     `/work/<ws>/<KEY>/chat?c=4&m=99`, `/work/<ws>/<KEY>/docs/3`)
//
// Luật định tuyến:
//   1. `/issue/<n>` ⇒ LÕI: mở thẻ trong tab My Work.
//   2. `/<doan>/…` ⇒ MÔ-ĐUN có `doanWeb == doan` (Core/CTWDangKyMoDun.swift):
//      chọn đúng dự án, chuyển tới chỗ của mô-đun, đặt `AppState.dichCho` để
//      mô-đun tự mở phần con. Mô-đun mới nhận deep link KHÔNG cần sửa tệp này.
//   3. Không mô-đun nào nhận ⇒ mở bảng của dự án.
//   (Bảng tin: `/work/<ws>/feed?post=` ⇒ `KhoBangTinCTW.moBai` — My Work đẩy màn bài.)

enum DinhTuyenCTW {
    @MainActor
    static func mo(url: URL) {
        if url.scheme == "ctwork" {
            // Widget "My work today" / "Timer" khi không có thẻ cụ thể.
            if url.host == "mywork" { AppState.shared.muc = .viecCuaToi; return }
            // `ctwork://dm/<threadId>` — tin nhắn riêng (chạm thông báo đẩy), `ctwork://members` — Thành viên.
            if url.host == "dm", let tid = url.pathComponents.dropFirst().first.flatMap(Int.init) {
                KhoTinNhanCTW.shared.moHoiThoai(tid)
                return
            }
            if url.host == "members" { AppState.shared.muc = .moDun("thanh-vien"); return }
            if url.host == "issue" {
                let khoa = url.pathComponents.dropFirst().first ?? ""
                Task { await moTheoKhoa(khoa) }
                return
            }
            let duong = "/" + (url.host ?? "") + url.path + (url.query.map { "?" + $0 } ?? "")
            mo(duongDan: duong)
            return
        }
        mo(duongDan: url.absoluteString)
    }

    @MainActor
    static func mo(duongDan: String) {
        if duongDan.hasPrefix("ctwork://"), let u = URL(string: duongDan) { mo(url: u); return }
        let app = AppState.shared
        guard app.isAuthenticated, let d = DuongDanCTW.tach(duongDan) else { return }

        // Bảng tin: `/work/<ws>/feed?post=<id>(&comment=<cid>)` — MỌI bài (cả bài dự án) dùng đường cấp không gian
        // (hợp đồng api-backend `docs/ctw-feed-hop-dong-api.md` §9) ⇒ My Work đẩy màn bài, cuộn tới bình luận.
        if let f = DichBangTin.tach(duongDan) {
            KhoBangTinCTW.shared.moBai(f)
            return
        }
        // `/work/<ws>/feed` (trang bảng tin không gian của web) ⇒ bảng tin không gian; chưa biết phạm vi ⇒ My Work › Bảng tin.
        if d.maDuAn == "feed", d.doan == nil {
            if let s = KhoBangTinCTW.shared.khongGian(slug: d.slug) { KhoBangTinCTW.shared.moKhongGian(s.workspace) }
            else { UserDefaults.standard.set(2, forKey: "ctw.myWork.che"); app.muc = .viecCuaToi }
            return
        }

        if d.doan == "issue", let ma = d.maDuAn, let so = d.phanCon.first.flatMap(Int.init) {
            app.muc = .viecCuaToi
            app.ctWorkDich = CTWDich(slug: d.slug, maDuAn: ma, so: so)
            return
        }
        guard let ma = d.maDuAn else {
            app.muc = .viecCuaToi
            app.ctWorkDich = CTWDich(slug: d.slug)
            return
        }
        guard let doan = d.doan, let m = CTWDangKyMoDun.moDun(choDoan: doan) else {
            app.muc = .viecCuaToi
            app.ctWorkDich = CTWDich(slug: d.slug, maDuAn: ma)
            return
        }
        Task {
            let pid = await chonDuAn(slug: d.slug, ma: ma)
            app.muc = .moDun(m.id)
            app.dichCho = DichMoDunCTW(moDun: m.id, pid: pid, duongDan: d)
        }
    }

    /// Chọn dự án theo slug + mã (giữ nguyên nếu đang chọn đúng nó).
    @MainActor
    static func chonDuAn(slug: String, ma: String) async -> Int? {
        let app = AppState.shared
        if let l = app.luaChon, l.slug == slug, l.maDuAn.caseInsensitiveCompare(ma) == .orderedSame { return l.pid }
        guard let r: CTWResolve = try? await APIClient.shared.request(.workTimDuAn(slug: slug, ma: ma)) else { return nil }
        app.luaChon = LuaChonCTW(slug: slug, tenKhongGian: slug, pid: r.projectId, maDuAn: ma, tenDuAn: ma)
        return r.projectId
    }

    /// `KEY-12` ⇒ tìm thẻ qua `/search` để biết không gian, rồi mở.
    @MainActor
    static func moTheoKhoa(_ khoa: String) async {
        let k = khoa.uppercased()
        guard k.contains("-"),
              let r: CTWSearchResult = try? await APIClient.shared.request(CTWAPI.timToanCuc(q: k, limit: 5)),
              let the = r.items?.first(where: { ($0.key ?? "").uppercased() == k }),
              let slug = the.workspace?.slug, let ma = the.project?.key else { return }
        AppState.shared.muc = .viecCuaToi
        AppState.shared.ctWorkDich = CTWDich(slug: slug, maDuAn: ma, so: the.number)
    }
}

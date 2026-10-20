import SwiftUI

// MARK: - "Hiện dần" (19/10/2026) — điều hướng chỉ còn mô-đun CỐT LÕI, phần còn lại trong "More"
//
// Phản hồi người dùng: app "nhiều chức năng, tự show ra tất cả nút nhìn rối, khó dùng". Trang dự án (iPhone) và
// thanh bên (iPad) từng liệt kê ~40 mô-đun. Giờ:
//   · mặc định chỉ hiện các mô-đun CỐT LÕI theo LOẠI DỰ ÁN (như web `coreFor` — `CTWGhim.cotLoi`) — mô-đun dự án tắt /
//     không có quyền vẫn ẩn;
//   · mọi mô-đun khác nằm trong "More": lưới theo nhóm + ô tìm (`ManThemCTW`);
//   · người dùng GHIM / BỎ GHIM mô-đun lên điều hướng chính (nhấn giữ ô, hoặc nút ghim). Từ 21/10/2026 ghim THEO NGƯỜI
//     DÙNG + DỰ ÁN và ĐỒNG BỘ với web/app desktop qua `users.preferences.work.navPins` (GhimDongBoCTW.swift).

@MainActor
final class GhimMoDunCTW: ObservableObject {
    static let shared = GhimMoDunCTW()

    /// Bản đệm máy này (theo user id) — vẽ ngay khi mở app, và là chỗ lùi khi chưa đọc được máy chủ.
    private static func khoaDem(_ uid: String) -> String { "com.cuongthai.ctwork.navPins.\(uid)" }
    /// Lựa chọn CŨ (trước 21/10: một danh sách cho mọi dự án) — chuyển một lần rồi xoá (`CTWGhim.tuBanCu`).
    private static let khoaCu = "com.cuongthai.ctwork.ghimMoDun"

    /// `projectId` (chuỗi) ⇒ mục ghim — cùng hình dạng `navPins` của web.
    /// Đọc trong `body` (qua `daGhim`) ⇒ nạp bản đệm KHÔNG phát thay đổi (tránh "publishing changes from within view
    /// updates"); ghi sau đó (`banDo = …`) mới phát.
    private var kho: [String: CTWGhimMuc] = [:]
    private(set) var banDo: [String: CTWGhimMuc] {
        get { kho }
        set { objectWillChange.send(); kho = newValue }
    }
    private var uidDaNap: String?
    private var dangDongBo = false
    private var daDongBo = Set<String>()

    private init() {}

    private var nguoi: String { AppState.shared.currentUser.map { String($0.id) } ?? "_" }
    private var cfg: CTWProjectConfig? { AppState.shared.cauHinhDuAn }

    /// Nạp bản đệm của người đang đăng nhập (đổi tài khoản ⇒ nạp lại) và đồng bộ với máy chủ một lần mỗi phiên.
    private func damBao() {
        let u = nguoi
        if uidDaNap != u {
            uidDaNap = u
            kho = (UserDefaults.standard.data(forKey: Self.khoaDem(u))).flatMap { try? JSONDecoder().decode([String: CTWGhimMuc].self, from: $0) } ?? [:]
        }
        if u != "_", !daDongBo.contains(u), !dangDongBo {
            dangDongBo = true
            Task { await dongBo() }
        }
    }

    func cotLoi(_ c: CTWProjectConfig?) -> [String] { CTWGhim.cotLoi(kind: c?.kind, template: c?.template, type: c?.type) }

    func muc(_ c: CTWProjectConfig?) -> CTWGhimMuc? {
        damBao()
        guard let c else { return nil }
        return banDo[String(c.id)]
    }

    /// Thứ tự điều hướng chính của dự án đang chọn (chưa lọc theo mô-đun hiện được).
    var ghim: [String] { CTWGhim.thuTuChinh(cotLoi: cotLoi(cfg), muc(cfg)) }

    func laGhim(_ id: String) -> Bool { CTWGhim.laChinh(id, cotLoi: cotLoi(cfg), muc(cfg)) }

    var daTuyChinh: Bool { muc(cfg)?.daTuyChinh == true }

    func doi(_ id: String) {
        guard let c = cfg else { return }
        let e = CTWGhim.doiGhim(id, bat: !laGhim(id), cotLoi: cotLoi(c), muc(c))
        dat(pid: c.id, e.daTuyChinh ? e : nil)
        CTWRung.chon()
    }

    func veMacDinh() {
        guard let c = cfg else { return }
        dat(pid: c.id, nil)
    }

    private func dat(pid: Int, _ e: CTWGhimMuc?) {
        banDo[String(pid)] = e
        ghiDem()
        let ep = CTWAPI.luuGhim(pid: pid, e)
        Task { _ = try? await APIClient.shared.send(ep) }   // hỏng mạng ⇒ bản đệm vẫn giữ, lần sau ghi lại khi đổi
    }

    private func ghiDem() {
        if let d = try? JSONEncoder().encode(banDo) { UserDefaults.standard.set(d, forKey: Self.khoaDem(nguoi)) }
    }

    /// Đọc máy chủ (máy chủ thắng — như web), rồi chuyển lựa chọn cũ của máy này sang dự án đang chọn (một lần).
    func dongBo() async {
        defer { dangDongBo = false }
        let u = nguoi
        guard u != "_" else { return }
        guard let tc: CTWTuyChonNguoiDung = try? await APIClient.shared.request(CTWAPI.tuyChonNguoiDung) else { return }
        guard u == nguoi else { return }
        daDongBo.insert(u)
        if !tc.navPins.isEmpty || banDo.isEmpty { banDo = tc.navPins }
        // Chuyển lựa chọn cũ — chỉ áp cho dự án đang chọn, chỉ khi máy chủ chưa có mục cho dự án đó.
        var cu = (UserDefaults.standard.dictionary(forKey: Self.khoaCu) as? [String: [String]]) ?? [:]
        if let l = cu[u] {
            if let c = cfg, banDo[String(c.id)] == nil, let e = CTWGhim.tuBanCu(l, cotLoi: cotLoi(c)) { dat(pid: c.id, e) }
            cu[u] = nil
            UserDefaults.standard.set(cu, forKey: Self.khoaCu)
        }
        ghiDem()
    }
}

extension CTWDangKyMoDun {
    /// Mô-đun hiện trên điều hướng chính: đã ghim VÀ hiện được với dự án đang chọn — theo thứ tự ghim (như web).
    @MainActor
    static func daGhim(_ cfg: CTWProjectConfig?) -> [CTWModule] {
        let g = GhimMoDunCTW.shared.ghim
        let hien = hienDuoc(cfg)
        return g.compactMap { id in hien.first { $0.id == id } }
    }

    /// Số mô-đun hiện được nhưng KHÔNG ghim (đếm trên dòng "More").
    @MainActor
    static func soConLai(_ cfg: CTWProjectConfig?) -> Int {
        let g = Set(GhimMoDunCTW.shared.ghim)
        return hienDuoc(cfg).filter { !g.contains($0.id) }.count
    }
}

/// iPhone: đẩy màn "More" trong tab Projects.
struct RouteThemCTW: Hashable {}

// MARK: - Màn "More": lưới mô-đun theo nhóm + tìm + ghim

struct ManThemCTW: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.horizontalSizeClass) private var beRong
    @ObservedObject private var ghim = GhimMoDunCTW.shared
    @State private var tim = ""

    private var nhom: [(nhom: CTWNhomMoDun, ds: [CTWModule])] {
        let q = tim.trimmingCharacters(in: .whitespaces).lowercased()
        return CTWDangKyMoDun.theoNhom(app.cauHinhDuAn).compactMap { n in
            let ds = q.isEmpty ? n.ds : n.ds.filter { $0.ten.lowercased().contains(q) || $0.moTa.lowercased().contains(q) || n.nhom.ten.lowercased().contains(q) }
            return ds.isEmpty ? nil : (n.nhom, ds)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                Text(beRong == .regular ? "Pin the tools you use most — pinned tools appear in the sidebar. Touch and hold a tool to pin or unpin it." : "Pin the tools you use most — pinned tools appear in Projects. Touch and hold a tool to pin or unpin it.")
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // Đợt B (21/10/2026): ghim theo DỰ ÁN, đồng bộ với thanh bên web / app desktop (`work.navPins`).
                Label("Pins are saved per project and sync with CT Work on the web and desktop.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if nhom.isEmpty {
                    CTWOTrong(bieuTuong: "magnifyingglass", tieuDe: String(localized: "No tools match “\(tim)”"))
                }
                ForEach(nhom, id: \.nhom) { n in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(n.nhom.ten).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: beRong == .regular ? 200 : 150), spacing: 12)], spacing: 12) {
                            ForEach(n.ds) { m in OMoDunCTW(m: m) }
                        }
                    }
                }
                if ghim.daTuyChinh {
                    Button("Reset pinned tools") { ghim.veMacDinh() }
                        .font(.ctw(size: 14)).frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("More tools")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $tim, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tools")
    }
}

/// Một ô mô-đun: chạm ⇒ mở; nút ghim ở góc (≥ 44 pt) + nhấn giữ ⇒ Pin/Unpin.
private struct OMoDunCTW: View {
    let m: CTWModule
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @Environment(\.horizontalSizeClass) private var beRong
    @ObservedObject private var ghim = GhimMoDunCTW.shared

    var body: some View {
        let daGhim = ghim.laGhim(m.id)
        // Ô và nút ghim KHÔNG chồng nhau (ZStack từng làm chạm nút ghim lọt xuống ô ⇒ mở mô-đun thay vì ghim).
        HStack(alignment: .top, spacing: 0) {
            Button { mo() } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: m.bieuTuong)
                        .font(.ctw(size: 17, weight: .semibold)).foregroundColor(AppColors.primary)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                    Text(m.ten).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    if !m.moTa.isEmpty {
                        Text(m.moTa).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding([.leading, .vertical], 12)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button { ghim.doi(m.id) } label: {
                    Label(daGhim ? (beRong == .regular ? String(localized: "Unpin from sidebar") : String(localized: "Unpin from Projects")) : (beRong == .regular ? String(localized: "Pin to sidebar") : String(localized: "Pin to Projects")),
                          systemImage: daGhim ? "pin.slash" : "pin")
                }
            }
            .accessibilityLabel(daGhim ? String(localized: "\(m.ten), pinned") : m.ten)
            .accessibilityHint(m.moTa)
            .accessibilityIdentifier("more.\(m.id)")
            Button { ghim.doi(m.id) } label: {
                Image(systemName: daGhim ? "pin.fill" : "pin")
                    .font(.ctw(size: 13, weight: .semibold))
                    .foregroundColor(daGhim ? AppColors.primary : AppColors.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(daGhim ? "Unpin \(m.ten)" : "Pin \(m.ten)")
        }
        .ctwThe(14)
    }

    private func mo() {
        if beRong == .regular || m.viTriIPhone == .tabRieng {
            app.muc = .moDun(m.id)
        } else {
            nganXep.duong.append(RouteMoDunCTW(id: m.id))
        }
    }
}

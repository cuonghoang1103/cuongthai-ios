import SwiftUI

// MARK: - "Hiện dần" (19/10/2026) — điều hướng chỉ còn mô-đun CỐT LÕI, phần còn lại trong "More"
//
// Phản hồi người dùng: app "nhiều chức năng, tự show ra tất cả nút nhìn rối, khó dùng". Trang dự án (iPhone) và
// thanh bên (iPad) từng liệt kê ~40 mô-đun. Giờ:
//   · mặc định chỉ hiện các mô-đun CỐT LÕI (`GhimMoDunCTW.macDinh`) — mô-đun dự án tắt / không có quyền vẫn ẩn;
//   · mọi mô-đun khác nằm trong "More": lưới theo nhóm + ô tìm (`ManThemCTW`);
//   · người dùng GHIM / BỎ GHIM mô-đun lên điều hướng chính (nhấn giữ ô, hoặc nút ghim). Nhớ THEO NGƯỜI DÙNG
//     (UserDefaults, khoá theo user id) — hai tài khoản trên một máy không dùng chung lựa chọn.

@MainActor
final class GhimMoDunCTW: ObservableObject {
    static let shared = GhimMoDunCTW()

    /// Cốt lõi: AI (tính năng mới, ghim sẵn — bỏ ghim được) · Board · Backlog/issues · Chat · Docs · Meetings · Calendar ·
    /// Code (tự ẩn khi dự án chưa nối repo).
    static let macDinh = ["ai", "board", "backlog", "chat", "docs", "meetings", "calendar", "code"]

    private let khoa = "com.cuongthai.ctwork.ghimMoDun"
    @Published private(set) var banDo: [String: [String]]

    private init() {
        banDo = (UserDefaults.standard.dictionary(forKey: khoa) as? [String: [String]]) ?? [:]
    }

    private var nguoi: String { AppState.shared.currentUser.map { String($0.id) } ?? "_" }

    var ghim: [String] { banDo[nguoi] ?? Self.macDinh }

    func laGhim(_ id: String) -> Bool { ghim.contains(id) }

    func doi(_ id: String) {
        var g = ghim
        if let i = g.firstIndex(of: id) { g.remove(at: i) } else { g.append(id) }
        banDo[nguoi] = g
        UserDefaults.standard.set(banDo, forKey: khoa)
        CTWRung.chon()
    }

    func veMacDinh() {
        banDo[nguoi] = nil
        UserDefaults.standard.set(banDo, forKey: khoa)
    }
}

extension CTWDangKyMoDun {
    /// Mô-đun hiện trên điều hướng chính: đã ghim VÀ hiện được với dự án đang chọn.
    @MainActor
    static func daGhim(_ cfg: CTWProjectConfig?) -> [CTWModule] {
        let g = Set(GhimMoDunCTW.shared.ghim)
        return hienDuoc(cfg).filter { g.contains($0.id) }
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
                Text("Pin the tools you use most — pinned tools appear in \(beRong == .regular ? "the sidebar" : "Projects"). Touch and hold a tool to pin or unpin it.")
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if nhom.isEmpty {
                    CTWOTrong(bieuTuong: "magnifyingglass", tieuDe: "No tools match “\(tim)”")
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
                if ghim.banDo[AppState.shared.currentUser.map { String($0.id) } ?? "_"] != nil {
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
                    Label(daGhim ? "Unpin from \(beRong == .regular ? "sidebar" : "Projects")" : "Pin to \(beRong == .regular ? "sidebar" : "Projects")",
                          systemImage: daGhim ? "pin.slash" : "pin")
                }
            }
            .accessibilityLabel("\(m.ten)\(daGhim ? ", pinned" : "")")
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

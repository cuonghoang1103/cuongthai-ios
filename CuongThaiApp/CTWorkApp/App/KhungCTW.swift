import SwiftUI

// MARK: - Gốc app: đồng ý quy tắc → đăng nhập → khung chính

struct GocCTW: View {
    @EnvironmentObject private var app: AppState
    /// Cỡ chữ hệ thống — đổi lúc app đang mở ⇒ dựng lại cả cây để `.ctw(size:)` đọc tỉ lệ mới (CTWUI/CTWCoChu.swift).
    @Environment(\.dynamicTypeSize) private var coChuHeThong

    var body: some View {
        Group {
            if !app.daDongYDieuKhoan {
                DongYQuyTacCTW { app.dongYDieuKhoan() }
            } else if !app.isAuthenticated {
                DangNhapCTW()
            } else {
                KhungCTW()
            }
        }
        .id(coChuHeThong)
        .animation(.easeInOut(duration: 0.2), value: app.isAuthenticated)
        .animation(.easeInOut(duration: 0.2), value: app.daDongYDieuKhoan)
    }
}

// MARK: - Khung chính
//
// iPhone (cỡ ngang hẹp): TabView — My Work · Projects · [mô-đun `.tabRieng`, hiện là
// Chat] · Inbox · Account. Mô-đun `.trangDuAn` nằm trong trang Projects.
// iPad (cỡ ngang rộng): NavigationSplitView — thanh bên theo NHÓM mô-đun.
// Chọn theo `horizontalSizeClass` (không theo thiết bị) ⇒ iPad Slide Over hẹp
// tự về thanh tab.

struct KhungCTW: View {
    @Environment(\.horizontalSizeClass) private var beRong

    var body: some View {
        if beRong == .regular { KhungRongCTW() } else { KhungTabCTW() }
    }
}

/// Mô-đun làm tab riêng trên iPhone (vd Chat).
@MainActor private var moDunTab: [CTWModule] {
    CTWDangKyMoDun.dangKyMoDun.filter { $0.viTriIPhone == .tabRieng }.sorted { $0.thuTu < $1.thuTu }
}

struct KhungTabCTW: View {
    @EnvironmentObject private var app: AppState

    /// Tab đang chọn: mô-đun thuộc trang dự án ⇒ tab Projects.
    private var chon: Binding<MucCTW> {
        Binding(
            get: {
                if case .moDun(let id) = app.muc, CTWDangKyMoDun.moDun(id)?.viTriIPhone != .tabRieng { return .duAn }
                if app.muc == .them { return .duAn }
                return app.muc
            },
            set: { app.muc = $0 })
    }

    var body: some View {
        TabView(selection: chon) {
            CotCTW(muc: .viecCuaToi).tabItem { Label(MucCTW.viecCuaToi.ten, systemImage: MucCTW.viecCuaToi.bieuTuong) }
                .tag(MucCTW.viecCuaToi)
            CotCTW(muc: .duAn).tabItem { Label(MucCTW.duAn.ten, systemImage: MucCTW.duAn.bieuTuong) }
                .tag(MucCTW.duAn)
            ForEach(moDunTab) { m in
                CotCTW(muc: .moDun(m.id)).tabItem { Label(m.ten, systemImage: m.bieuTuong) }
                    .badge(m.id == "chat" ? app.chatChuaDoc : 0)
                    .tag(MucCTW.moDun(m.id))
            }
            CotCTW(muc: .hopThu).tabItem { Label(MucCTW.hopThu.ten, systemImage: MucCTW.hopThu.bieuTuong) }
                .badge(app.hopThuChuaDoc)
                .tag(MucCTW.hopThu)
            CotCTW(muc: .taiKhoan).tabItem { Label(MucCTW.taiKhoan.ten, systemImage: MucCTW.taiKhoan.bieuTuong) }
                .tag(MucCTW.taiKhoan)
        }
    }
}

/// iPad: thanh bên. ⚠️ Mục PHẢI là `NavigationLink(value:)` — `.tag()` trong
/// `List(selection:)` chết câm trên iOS (bài học app chính 16/09/2026).
struct KhungRongCTW: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject private var ghim = GhimMoDunCTW.shared
    @State private var moChon = false
    @StateObject private var nganXepChiTiet = NganXepCTW()

    var body: some View {
        NavigationSplitView {
            List(selection: Binding<MucCTW?>(get: { app.muc }, set: { if let m = $0 { app.muc = m } })) {
                Section {
                    Button { moChon = true } label: {
                        HStack(spacing: 10) {
                            Text(app.luaChon?.maDuAn ?? "—")
                                .font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.onPrimary)
                                .frame(minWidth: 40, minHeight: 32)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.primary))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.luaChon?.tenDuAn ?? "Choose a project").font(.ctw(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Text(app.luaChon?.tenKhongGian ?? "No project selected").font(.ctw(size: 12))
                                    .foregroundColor(AppColors.textSecondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up.chevron.down").font(.ctw(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Switch project")
                    muc(.viecCuaToi)
                    muc(.hopThu)
                }
                // "Hiện dần" (19/10/2026): chỉ mô-đun ĐÃ GHIM (mặc định = cốt lõi); còn lại trong "More tools".
                Section("Project") {
                    ForEach(CTWDangKyMoDun.daGhim(app.cauHinhDuAn)) { m in muc(.moDun(m.id)) }
                    muc(.them)
                }
                Section { muc(.taiKhoan) }
            }
            .navigationTitle("CT Work")
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            CotCTW(muc: app.muc == .duAn ? .viecCuaToi : app.muc, nganXepNgoai: nganXepChiTiet).id(app.muc)
        }
        // ⚠️ iPad: màn được ĐẨY trong cột detail (navigationDestination) lấy environment từ NavigationSplitView, KHÔNG
        // từ NavigationStack của cột ⇒ `NganXepCTW` gắn ở cột không tới ⇒ màn con đọc nó là SIGTRAP (đo 19/10/2026:
        // Docs › trang › Version history, Code › Source › thư mục). Ngăn xếp detail vì thế do khung giữ và gắn ở đây.
        .environmentObject(nganXepChiTiet)
        .onChange(of: app.muc) { _, _ in nganXepChiTiet.veDau() }
        .sheet(isPresented: $moChon) { ChonDuAnCTW() }
    }

    private func muc(_ m: MucCTW) -> some View {
        NavigationLink(value: m) {
            Label(m.ten, systemImage: m.bieuTuong)
                .badge(m == .hopThu ? app.hopThuChuaDoc : (m == .moDun("chat") ? app.chatChuaDoc : 0))
        }
    }
}

/// Một cột/tab: NavigationStack riêng + ngăn xếp cho mô-đun đẩy màn.
struct CotCTW: View {
    let muc: MucCTW
    /// iPad: ngăn xếp do `KhungRongCTW` giữ và gắn vào CẢ NavigationSplitView (xem dưới). iPhone: nil ⇒ cột tự giữ.
    var nganXepNgoai: NganXepCTW? = nil
    @StateObject private var rieng = NganXepCTW()

    var body: some View {
        CotNganXepCTW(muc: muc, nganXep: nganXepNgoai ?? rieng)
    }
}

private struct CotNganXepCTW: View {
    let muc: MucCTW
    @ObservedObject var nganXep: NganXepCTW

    var body: some View {
        NavigationStack(path: $nganXep.duong) {
            noiDung
                .ctwDichDen()
        }
        .environmentObject(nganXep)
    }

    @ViewBuilder private var noiDung: some View {
        switch muc {
        case .viecCuaToi: ViecCuaToiCTW()
        case .duAn: TrangDuAnCTW()
        case .hopThu: HopThuCTW()
        case .taiKhoan: TaiKhoanCTW()
        case .them: ManThemCTW()
        case .moDun(let id): ManMoDunCTW(id: id)
        }
    }
}

// MARK: - Màn chưa chọn dự án

struct ChuaChonDuAnCTW: View {
    let lyDo: String
    @State private var moChon = false

    var body: some View {
        CTWOTrong(bieuTuong: "rectangle.3.group.fill", tieuDe: "Choose a project", moTa: lyDo,
                  nut: "Choose project") { moChon = true }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.backgroundPrimary)
            .sheet(isPresented: $moChon) { ChonDuAnCTW() }
    }
}

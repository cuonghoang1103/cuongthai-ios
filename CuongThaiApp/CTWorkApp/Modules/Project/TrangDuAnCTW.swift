import SwiftUI

// MARK: - Trang dự án (tab Projects trên iPhone)
//
// Đầu trang: dự án đang chọn + nút đổi dự án. Dưới: mọi mô-đun `.trangDuAn`
// đã đăng ký (Core/CTWDangKyMoDun.swift), chia theo nhóm, ẩn mô-đun mà dự án
// tắt. Thêm mô-đun mới KHÔNG phải sửa tệp này.

struct TrangDuAnCTW: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    /// MỘT tấm phủ cho cả màn (bẫy C5: hai `.sheet` cùng view chỉ cái cuối chạy).
    @State private var tamPhu: TamPhu?
    private enum TamPhu: String, Identifiable { case chonDuAn, web; var id: String { rawValue } }

    var body: some View {
        Group {
            if let l = app.luaChon {
                List {
                    Section { dau(l) }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    ForEach(nhom, id: \.nhom) { n in
                        Section(n.nhom.ten) {
                            ForEach(n.ds) { m in
                                NavigationLink(value: RouteMoDunCTW(id: m.id)) { hang(m) }
                            }
                        }
                    }
                    Section {
                        Button { tamPhu = .web } label: {
                            Label("Open project on the web", systemImage: "safari")
                        }
                    } footer: {
                        Text("Opens cuongthai.com in a secure in-app browser.")
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await app.napCauHinhDuAn() }
            } else {
                ChuaChonDuAnCTW(lyDo: "Pick the workspace and project you want to work on. CT Work remembers your choice.")
            }
        }
        .navigationTitle("Projects")
        .sheet(item: $tamPhu) { t in
            switch t {
            case .chonDuAn: ChonDuAnCTW()
            case .web:
                if let l = app.luaChon, let u = URL(string: "\(APIClient.diaChiGoc)/work/\(CTWAPI.doan(l.slug))/\(CTWAPI.doan(l.maDuAn))") {
                    SafariCTW(url: u).ignoresSafeArea()
                }
            }
        }
        // Đích chờ của một mô-đun trong trang này (vd trang tài liệu từ thông
        // báo) ⇒ mở mô-đun; mô-đun tự mở phần con rồi xoá cờ.
        .task(id: app.dichCho) {
            guard let d = app.dichCho, let m = CTWDangKyMoDun.moDun(d.moDun), m.viTriIPhone == .trangDuAn else { return }
            var p = NavigationPath()
            p.append(RouteMoDunCTW(id: m.id))
            nganXep.duong = p
        }
        #if DEBUG
        .onAppear {
            if let id = XemThuCTW.moDunMoSan, nganXep.duong.isEmpty { nganXep.duong.append(RouteMoDunCTW(id: id)) }
        }
        #endif
    }

    private var nhom: [(nhom: CTWNhomMoDun, ds: [CTWModule])] {
        CTWDangKyMoDun.theoNhom(app.cauHinhDuAn).compactMap { n in
            let ds = n.ds.filter { $0.viTriIPhone == .trangDuAn }
            return ds.isEmpty ? nil : (nhom: n.nhom, ds: ds)
        }
    }

    private func dau(_ l: LuaChonCTW) -> some View {
        HStack(spacing: 14) {
            Text(l.maDuAn)
                .font(.system(size: 15, weight: .heavy).monospaced())
                .foregroundColor(AppColors.onPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [AppColors.primaryLight, AppColors.primary], startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tenDuAn).font(.system(size: 19, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(moTaDuAn(l)).font(.system(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            Button { tamPhu = .chonDuAn } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(AppColors.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .foregroundColor(AppColors.primary)
            .accessibilityLabel("Switch project")
        }
        .padding(16)
        .ctwThe(16)
        .padding(.vertical, 4)
    }

    private func moTaDuAn(_ l: LuaChonCTW) -> String {
        var p = [l.tenKhongGian]
        if let t = app.cauHinhDuAn?.type { p.append(t.capitalized) }
        if let r = app.cauHinhDuAn?.role { p.append(r.capitalized) }
        return p.joined(separator: " · ")
    }

    private func hang(_ m: CTWModule) -> some View {
        HStack(spacing: 13) {
            Image(systemName: m.bieuTuong)
                .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(m.ten).font(.system(size: 16, weight: .medium)).foregroundColor(AppColors.textPrimary)
                if !m.moTa.isEmpty {
                    Text(m.moTa).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

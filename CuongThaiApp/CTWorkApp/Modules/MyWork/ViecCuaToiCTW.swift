import SwiftUI

// MARK: - Tab Việc của tôi (+ tìm kiếm toàn cục)

struct ViecCuaToiCTW: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tim = ""
    /// 0 = Issues (My Work của lõi) · 1 = Agenda (`/me/agenda`, xuyên dự án).
    @AppStorage("ctw.myWork.che") private var che = 0

    var body: some View {
        Group {
            if tim.trimmingCharacters(in: .whitespaces).count >= 2 {
                TimKiemCTW(q: tim)
            } else {
                // Công tắc nằm TRONG danh sách (hàng đầu) ⇒ cùng lề với ô tìm và các thẻ — trước 20/10 nó đệm 16 pt
                // riêng nên rộng hơn ô tìm và lệch với ô đếm (ảnh chủ app trên iPhone Pro Max, lề hệ thống 20 pt).
                if che == 1 { AgendaCuaToiCTW(dau: AnyView(congTac)) } else { DanhSachViecCTW(dau: AnyView(congTac)) }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("My Work")
        .searchable(text: $tim, prompt: "Search issues in all projects")
        // Đích từ thông báo/đường dẫn. `.task(id:)` vì cờ có thể được đặt
        // TRƯỚC khi màn tồn tại (mở nguội từ thông báo).
        .task(id: app.ctWorkDich) {
            guard let d = app.ctWorkDich else { return }
            app.ctWorkDich = nil
            tim = ""
            var p = NavigationPath()
            if let ma = d.maDuAn, let so = d.so {
                p.append(CTWRoute.theTheoMa(slug: d.slug, ma: ma, so: so))
            } else if let ma = d.maDuAn {
                p.append(CTWRoute.bangTheoMa(slug: d.slug, ma: ma))
            } else {
                p.append(CTWRoute.khongGian(slug: d.slug, ten: d.slug))
            }
            nganXep.duong = p
        }
    }
}

extension ViecCuaToiCTW {
    fileprivate var congTac: some View {
        Picker("View", selection: $che) {
            Text("Issues").tag(0)
            Text("Agenda").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 4)
    }
}

struct TimKiemCTW: View {
    let q: String
    @State private var kq: CTWSearchResult?
    @State private var loi: String?

    var body: some View {
        List {
            if let loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear) }
            if let kq, (kq.items ?? []).isEmpty {
                Text("No issues match “\(q)”.").foregroundColor(AppColors.textSecondary)
            }
            ForEach(kq?.items ?? []) { i in
                if let slug = i.workspace?.slug, let ma = i.project?.key {
                    NavigationLink(value: CTWRoute.theTheoMa(slug: slug, ma: ma, so: i.number)) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: CTW.bieuTuongLoai(key: i.type?.key))
                                .font(.ctw(size: 10, weight: .bold)).foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(CTW.mau(i.type?.color, macDinh: AppColors.info)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(i.title).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                                HStack(spacing: 8) {
                                    Text(i.key ?? "").font(.ctw(size: 12, weight: .semibold).monospaced())
                                        .foregroundColor(AppColors.textSecondary)
                                    if let s = i.status?.name {
                                        Text(s).font(.ctw(size: 11, weight: .semibold))
                                            .foregroundColor(CTW.mauNhom(i.status?.category))
                                    }
                                    Text(i.project?.name ?? "").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if kq == nil && loi == nil { ProgressView() } }
        .task(id: q) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                kq = try await APIClient.shared.request(CTWAPI.timToanCuc(q: q))
                loi = nil
            } catch {
                if !Task.isCancelled { loi = CTW.loi(error) }
            }
        }
    }
}

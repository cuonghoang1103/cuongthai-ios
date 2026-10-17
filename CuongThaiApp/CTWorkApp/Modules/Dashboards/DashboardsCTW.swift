import SwiftUI

// MARK: - Danh sách dashboard + mẫu báo cáo (Report builder, chỉ xem)
//
// `GET /dashboards` (của mình + được chia sẻ). Chưa có ⇒ nút tạo "Project overview"
// (`POST /dashboards/overview` — bộ widget mặc định của máy chủ). Sắp xếp/sửa widget làm
// trên web (kéo-thả nhiều cột) — app xem và làm mới.

struct RouteDashboardCTW: Hashable {
    var pid: Int
    var dashboard: CTWDashboardDb
}

struct RouteMauBaoCaoCTW: Hashable {
    var pid: Int
    var ref: String
    var ten: String
}

struct DashboardsCTW: View {
    let pid: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var ds: TaiCTW<[CTWDashboardDb]> = .dangTai
    @State private var mau: CTWDsMauBaoCaoDb?
    @State private var loi: String?
    @State private var dangTao = false

    var body: some View {
        KhungTaiCTW(trangThai: ds, thuLai: { Task { await tai() } }) { ds in
            List {
                if let loi {
                    CTWErrorBanner(text: loi) { self.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                Section {
                    if ds.isEmpty {
                        VStack(spacing: 10) {
                            CTWOTrong(bieuTuong: "rectangle.3.group", tieuDe: "No dashboards yet",
                                      moTa: "Start with the project overview — KPIs, flow, workload and recent activity in one place.")
                            Button { Task { await taoTongQuan() } } label: {
                                if dangTao { ProgressView() } else { Text("Create project overview").bold() }
                            }
                            .buttonStyle(.borderedProminent).disabled(dangTao)
                        }
                        .frame(maxWidth: .infinity).padding(.bottom, 12)
                        .listRowBackground(Color.clear)
                    }
                    ForEach(ds) { d in
                        NavigationLink(value: RouteDashboardCTW(pid: pid, dashboard: d)) { hang(d) }
                    }
                } header: { if !ds.isEmpty { Text("Dashboards") } }
                if let m = mau, !((m.builtins ?? []) + (m.templates ?? [])).isEmpty {
                    Section {
                        ForEach((m.builtins ?? []) + (m.templates ?? [])) { t in
                            NavigationLink(value: RouteMauBaoCaoCTW(pid: pid, ref: t.ref, ten: t.name ?? "Report")) {
                                HStack(spacing: 12) {
                                    Image(systemName: t.builtin == true ? "doc.richtext" : "doc.text")
                                        .font(.system(size: 15, weight: .semibold)).foregroundColor(CTWMauChuoi.mau(6))
                                        .frame(width: 34, height: 34)
                                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CTWMauChuoi.mau(6).opacity(0.12)))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.name ?? "Report").font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                                        if let d = t.description, !d.isEmpty {
                                            Text(d).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } header: { Text("Report templates") } footer: {
                        Text("Reports are filled with live project data. Edit templates and schedule deliveries on the web.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Dashboards")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if ds.giaTri == nil { await tai() } }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "dashboards" else { return }
            defer { app.dichCho = nil }
            if ds.giaTri == nil { await tai() }
            if let id = d.duongDan.tham["d"].flatMap(Int.init) ?? d.duongDan.phanCon.first.flatMap(Int.init),
               let db = ds.giaTri?.first(where: { $0.id == id }) {
                nganXep.duong.append(RouteDashboardCTW(pid: pid, dashboard: db))
            }
        }
        #if DEBUG
        .task {
            guard let c = XemThuCTW.conCua("dashboards"), !c.isEmpty, nganXep.duong.count <= 1 else { return }
            try? await Task.sleep(nanoseconds: 700_000_000)
            if c == "report", let m = mau, let t = (m.builtins ?? []).first {
                nganXep.duong.append(RouteMauBaoCaoCTW(pid: pid, ref: t.ref, ten: t.name ?? "Report"))
            } else if let db = ds.giaTri?.first(where: { String($0.id) == c }) ?? ds.giaTri?.first {
                nganXep.duong.append(RouteDashboardCTW(pid: pid, dashboard: db))
            }
        }
        #endif
    }

    private func hang(_ d: CTWDashboardDb) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(d.name ?? "Dashboard").font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                Text("\((d.widgets ?? []).count) widget\((d.widgets ?? []).count == 1 ? "" : "s")" + (d.shared == true ? " · Shared" : " · Private"))
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
            if d.shared == true { Image(systemName: "person.2.fill").font(.system(size: 11)).foregroundColor(AppColors.textTertiary) }
        }
        .padding(.vertical, 2)
    }

    private func tai() async {
        do {
            let r: [CTWDashboardDb] = try await APIClient.shared.request(CTWAPI.dsDashboard(pid: pid))
            ds = .xong(r)
        } catch {
            if ds.giaTri == nil { ds = .loi(CTW.loi(error)) } else { loi = CTW.loi(error) }
        }
        // Mẫu báo cáo: 403 (khách/GUEST) ⇒ ẩn mục, không báo lỗi.
        mau = try? await APIClient.shared.request(CTWAPI.dsMauBaoCao(pid: pid))
    }

    private func taoTongQuan() async {
        dangTao = true
        defer { dangTao = false }
        do {
            let d: CTWDashboardDb = try await APIClient.shared.request(CTWAPI.dashboardTongQuan(pid: pid))
            CTWRung.thanhCong()
            await tai()
            nganXep.duong.append(RouteDashboardCTW(pid: pid, dashboard: d))
        } catch {
            loi = CTW.loi(error)
        }
    }
}

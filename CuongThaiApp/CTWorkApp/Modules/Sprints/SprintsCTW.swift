import SwiftUI

// MARK: - Danh sách sprint (ACTIVE → PLANNED → CLOSED)
//
// `GET /sprints?includeClosed=true`. Sprint đang chạy có thẻ lớn: mục tiêu, tiến độ thời gian,
// nút xem chi tiết. Người có quyền `manageSprints`: tạo / sửa / bắt đầu / hoàn tất / xoá.

@MainActor
final class SprintsVM: ObservableObject {
    let pid: Int
    @Published var ds: TaiCTW<[CTWSprintDu]> = .dangTai
    @Published var loi: String?
    @Published var dangGhi = false

    init(pid: Int) { self.pid = pid }

    func tai() async {
        do {
            let r: [CTWSprintDu] = try await APIClient.shared.request(CTWAPI.dsSprint(pid: pid))
            ds = .xong(TinhSprintCTW.sap(r))
        } catch {
            if ds.giaTri == nil { ds = .loi(CTW.loi(error)) } else { loi = CTW.loi(error) }
        }
    }

    /// Chạy một lệnh ghi rồi tải lại. Trả câu lỗi (nil = xong).
    @discardableResult
    func ghi(_ e: APIEndpoint) async -> String? {
        dangGhi = true
        defer { dangGhi = false }
        do {
            try await APIClient.shared.send(e)
            CTWRung.thanhCong()
            await tai()
            return nil
        } catch {
            CTWRung.loi()
            return CTW.loi(error)
        }
    }
}

/// Tấm phủ của màn sprint — MỘT `.sheet(item:)` (bẫy C5).
enum TamPhuSprintCTW: Identifiable {
    case tao
    case sua(CTWSprintDu)
    case batDau(CTWSprintDu)
    case hoanTat(CTWSprintDu)
    var id: String {
        switch self {
        case .tao: return "tao"
        case .sua(let s): return "sua-\(s.id)"
        case .batDau(let s): return "bd-\(s.id)"
        case .hoanTat(let s): return "ht-\(s.id)"
        }
    }
}

struct RouteSprintCTW: Hashable {
    var pid: Int
    var sid: Int
}

struct SprintsCTW: View {
    let pid: Int
    @StateObject private var vm: SprintsVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tamPhu: TamPhuSprintCTW?
    @State private var xoa: CTWSprintDu?
    @State private var hienDaDong = false

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: SprintsVM(pid: pid))
    }

    private var quanLy: Bool { app.cauHinhDuAn?.permissions?.manageSprints == true }

    var body: some View {
        KhungTaiCTW(trangThai: vm.ds, thuLai: { Task { await vm.tai() } }) { ds in
            danhSach(ds)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Sprints")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if quanLy {
                ToolbarItem(placement: .primaryAction) {
                    Button { tamPhu = .tao } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Create sprint")
                }
            }
        }
        .sheet(item: $tamPhu) { t in
            BangSprintCTW(tamPhu: t, pid: pid, dsKhac: vm.ds.giaTri ?? []) { e in await vm.ghi(e) }
        }
        .confirmationDialog("Delete this sprint?", isPresented: Binding(get: { xoa != nil }, set: { if !$0 { xoa = nil } }),
                            titleVisibility: .visible, presenting: xoa) { s in
            Button("Delete \(s.ten)", role: .destructive) { Task { vm.loi = await vm.ghi(CTWAPI.xoaSprint(pid: pid, sid: s.id)) } }
        } message: { _ in
            Text("Its issues move back to the backlog. Only sprints that haven't started can be deleted.")
        }
        .refreshable { await vm.tai() }
        .task { if vm.ds.giaTri == nil { await vm.tai() } }
        #if DEBUG
        .task {
            if let con = XemThuCTW.conCua("sprints"), let so = Int(con), nganXep.duong.count <= 1 {
                try? await Task.sleep(nanoseconds: 400_000_000)
                nganXep.duong.append(RouteSprintCTW(pid: pid, sid: so))
            }
        }
        #endif
    }

    @ViewBuilder
    private func danhSach(_ ds: [CTWSprintDu]) -> some View {
        let dangChay = ds.filter(\.dangChay)
        let keHoach = ds.filter(\.chuaBatDau)
        let daDong = ds.filter(\.daDong)
        List {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if ds.isEmpty {
                CTWOTrong(bieuTuong: "flag.checkered", tieuDe: "No sprints yet",
                          moTa: "Sprints group the work your team commits to for a few weeks.",
                          nut: quanLy ? "Create sprint" : nil, hanhDong: quanLy ? { tamPhu = .tao } : nil)
                    .listRowBackground(Color.clear)
            }
            ForEach(dangChay) { s in
                Section {
                    TheSprintChayCTW(sprint: s)
                        .background(NavigationLink("", value: RouteSprintCTW(pid: pid, sid: s.id)).opacity(0))
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .contextMenu { menu(s) }
                } header: { tieuDe("Active", "flag.fill", nil) }
            }
            if !keHoach.isEmpty {
                Section {
                    ForEach(keHoach) { s in hang(s) }
                } header: { tieuDe("Planned", "calendar", keHoach.count) }
            }
            if !daDong.isEmpty {
                Section {
                    if hienDaDong {
                        ForEach(daDong) { s in hang(s) }
                    } else {
                        Button { withAnimation { hienDaDong = true } } label: {
                            Label("Show \(daDong.count) completed sprint\(daDong.count == 1 ? "" : "s")", systemImage: "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                } header: { tieuDe("Completed", "checkmark.seal", daDong.count) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func tieuDe(_ t: String, _ b: String, _ n: Int?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: b)
            Text(t)
            if let n { Text("\(n)").foregroundColor(AppColors.textTertiary) }
        }
        .font(.system(size: 13, weight: .semibold))
    }

    private func hang(_ s: CTWSprintDu) -> some View {
        NavigationLink(value: RouteSprintCTW(pid: pid, sid: s.id)) {
            HStack(spacing: 12) {
                Image(systemName: s.daDong ? "checkmark.circle.fill" : "flag")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(s.daDong ? AppColors.success : AppColors.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.ten).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    Text(phu(s)).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if s.daDong, let c = s.committedPoints, c > 0 {
                    Text("\(CTWSo.gon(s.completedPoints ?? 0))/\(CTWSo.gon(c))")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.vertical, 3)
        }
        .contextMenu { menu(s) }
        .swipeActions(edge: .trailing) {
            if quanLy && s.chuaBatDau {
                Button(role: .destructive) { xoa = s } label: { Label("Delete", systemImage: "trash") }
                Button { tamPhu = .batDau(s) } label: { Label("Start", systemImage: "play.fill") }.tint(AppColors.primary)
            }
        }
    }

    private func phu(_ s: CTWSprintDu) -> String {
        var p: [String] = []
        if let a = NgayCTW.ngayCua(s.startAt).flatMap(NgayCTW.nganTu), let b = NgayCTW.ngayCua(s.endAt).flatMap(NgayCTW.nganTu) {
            p.append("\(a) – \(b)")
        } else if s.chuaBatDau {
            p.append("Not started")
        }
        if let g = s.goal, !g.isEmpty { p.append(g) }
        return p.joined(separator: " · ")
    }

    @ViewBuilder
    private func menu(_ s: CTWSprintDu) -> some View {
        if quanLy {
            if !s.daDong { Button { tamPhu = .sua(s) } label: { Label("Edit", systemImage: "pencil") } }
            if s.chuaBatDau { Button { tamPhu = .batDau(s) } label: { Label("Start sprint", systemImage: "play.fill") } }
            if s.dangChay { Button { tamPhu = .hoanTat(s) } label: { Label("Complete sprint", systemImage: "checkmark.seal") } }
            if s.chuaBatDau { Button(role: .destructive) { xoa = s } label: { Label("Delete", systemImage: "trash") } }
        }
    }
}

/// Thẻ lớn cho sprint đang chạy: tên, mục tiêu, thời gian đã trôi, số ngày còn.
struct TheSprintChayCTW: View {
    let sprint: CTWSprintDu

    var body: some View {
        let con = TinhSprintCTW.ngayConLai(endAt: sprint.endAt)
        let troi = TinhSprintCTW.thoiGianDaQua(startAt: sprint.startAt, endAt: sprint.endAt) ?? 0
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sprint.ten).font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    if let a = NgayCTW.ngayCua(sprint.startAt).flatMap(NgayCTW.nganTu),
                       let b = NgayCTW.ngayCua(sprint.endAt).flatMap(NgayCTW.nganTu) {
                        Text("\(a) – \(b)").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer()
                if let con {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(abs(con))").font(.system(size: 24, weight: .bold).monospacedDigit())
                            .foregroundColor(con < 0 ? AppColors.error : AppColors.textPrimary)
                        Text(con < 0 ? "days over" : (con == 1 ? "day left" : "days left"))
                            .font(.system(size: 11, weight: .medium)).foregroundColor(AppColors.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if let g = sprint.goal, !g.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "target").foregroundColor(AppColors.primary).font(.system(size: 13, weight: .semibold))
                    Text(g).font(.system(size: 14)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: troi).tint(con.map { $0 < 0 } == true ? AppColors.error : AppColors.primary)
                Text("\(Int((troi * 100).rounded()))% of the time elapsed")
                    .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            HStack {
                Text("View burndown & progress").font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.primary)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundColor(AppColors.primary)
            }
        }
        .padding(16)
        .ctwThe(16)
        .accessibilityElement(children: .combine)
    }
}

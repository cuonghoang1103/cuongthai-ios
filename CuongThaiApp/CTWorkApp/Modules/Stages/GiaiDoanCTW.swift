import SwiftUI

// MARK: - Giai đoạn dự án — dòng thời gian dọc
//
// Mỗi giai đoạn: vòng trạng thái (biểu tượng + chữ — không chỉ dựa vào màu), tiến độ thẻ
// doneCount/issueCount, ngày bắt đầu/xong, thẻ cổng (mở thẻ), cờ "đang chờ duyệt cổng".
// Chỉ xem — kích hoạt giai đoạn / xin duyệt cổng là thao tác quản trị, làm trên web.

@MainActor
final class GiaiDoanVM: ObservableObject {
    let pid: Int
    @Published var trangThai: TaiCTW<[GiaiDoanCTW]> = .dangTai
    @Published var tat = false

    init(pid: Int) { self.pid = pid }

    func tai() async {
        do {
            let ds: [GiaiDoanCTW] = try await APIClient.shared.request(CTWAPI.dsGiaiDoan(pid: pid))
            trangThai = .xong(ds.sorted { ($0.n ?? 0, $0.id) < ($1.n ?? 0, $1.id) })
            tat = false
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "MODULE_DISABLED" { tat = true; trangThai = .xong([]); return }
            if trangThai.giaTri == nil { trangThai = .loi(CTW.loi(error)) }
        }
    }
}

struct GiaiDoanDuAnCTW: View {
    let pid: Int
    let maDuAn: String
    @StateObject private var vm: GiaiDoanVM
    @EnvironmentObject private var app: AppState

    init(pid: Int, maDuAn: String) {
        self.pid = pid
        self.maDuAn = maDuAn
        _vm = StateObject(wrappedValue: GiaiDoanVM(pid: pid))
    }

    var body: some View {
        KhungTaiCTW(trangThai: vm.trangThai, thuLai: { Task { await vm.tai() } }) { ds in
            if vm.tat {
                CTWOTrong(bieuTuong: "flag.slash", tieuDe: "Stages are off",
                          moTa: "This project doesn't use stage-gated delivery. A project admin can turn on Stages in project settings.")
                    .frame(maxHeight: .infinity)
            } else if ds.isEmpty {
                CTWOTrong(bieuTuong: "flag.checkered", tieuDe: "No stages yet",
                          moTa: "Stages split delivery into phases, each closed by a gate review.")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        tomTat(ds)
                        VStack(spacing: 0) {
                            ForEach(Array(ds.enumerated()), id: \.element.id) { i, g in
                                hang(g, dau: i == 0, cuoi: i == ds.count - 1)
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Stages")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.tai() }
        .refreshable { await vm.tai() }
        .task(id: app.dichCho) {
            guard app.dichCho?.moDun == "stages" else { return }
            app.dichCho = nil
        }
    }

    private func tomTat(_ ds: [GiaiDoanCTW]) -> some View {
        let t = TomTatGiaiDoanCTW.tinh(ds)
        return HStack(spacing: 14) {
            CTWVongTienDo(tiLe: t.tong == 0 ? 0 : Double(t.xong) / Double(t.tong), co: 58, mau: AppColors.success,
                          chu: "\(t.xong)/\(t.tong)")
            VStack(alignment: .leading, spacing: 4) {
                Text("\(t.xong) of \(t.tong) stages done").font(.ctw(size: 17, weight: .bold)).foregroundColor(AppColors.textPrimary)
                if let h = t.hienTai {
                    Text("Current: \(h)").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                } else if t.xong == t.tong {
                    Text("All stages complete").font(.ctw(size: 14)).foregroundColor(AppColors.success)
                } else {
                    Text("No stage is active yet").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .ctwThe(16)
    }

    static func kieu(_ s: String?) -> (ten: String, bieuTuong: String, mau: Color) {
        switch s {
        case "DONE": return ("Done", "checkmark.circle.fill", AppColors.success)
        case "ACTIVE": return ("Active", "play.circle.fill", AppColors.primary)
        case "GATE_REVIEW": return ("Gate review", "hourglass.circle.fill", AppColors.warning)
        default: return ("Not started", "circle.dashed", AppColors.textTertiary)
        }
    }

    private func hang(_ g: GiaiDoanCTW, dau: Bool, cuoi: Bool) -> some View {
        let k = Self.kieu(g.status)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle().fill(dau ? Color.clear : AppColors.border).frame(width: 2, height: 14)
                Image(systemName: k.bieuTuong).font(.ctw(size: 24, weight: .semibold)).foregroundColor(k.mau)
                    .background(Circle().fill(AppColors.backgroundPrimary))
                Rectangle().fill(cuoi ? Color.clear : AppColors.border).frame(width: 2).frame(maxHeight: .infinity)
            }
            .frame(width: 28)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("STAGE \(g.n ?? 0)").font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text(k.ten).font(.ctw(size: 11, weight: .semibold)).foregroundColor(k.mau)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(k.mau.opacity(0.12)))
                }
                Text(g.name).font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                if (g.issueCount ?? 0) > 0 {
                    HStack(spacing: 8) {
                        CTWThanhTienDo(doan: [CTWDoanTienDo(ten: "Done", giaTri: Double(g.doneCount ?? 0), mau: AppColors.success),
                                              CTWDoanTienDo(ten: "Open", giaTri: Double(max((g.issueCount ?? 0) - (g.doneCount ?? 0), 0)), mau: AppColors.backgroundTertiary)],
                                       cao: 6)
                        Text("\(g.doneCount ?? 0)/\(g.issueCount ?? 0) issues").font(.ctw(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundColor(AppColors.textSecondary).fixedSize()
                    }
                } else {
                    Text("No issues linked to this stage").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                }
                if let ngay = dongNgay(g) {
                    Label(ngay, systemImage: "calendar").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                if g.pendingApprovalId != nil {
                    Label("Gate approval pending", systemImage: "person.badge.clock")
                        .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.warning)
                }
                if let c = g.gateIssue, let so = c.number {
                    NavigationLink(value: CTWRoute.the(pid: pid, so: so)) {
                        HStack(spacing: 6) {
                            Image(systemName: c.resolvedAt != nil ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                                .foregroundColor(c.resolvedAt != nil ? AppColors.success : AppColors.primary)
                            Text("Gate").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            Text(g.gateIssueKey ?? "\(maDuAn)-\(so)").font(.ctw(size: 12, weight: .medium).monospaced())
                                .foregroundColor(AppColors.textSecondary)
                            Text(c.title ?? "").font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundTertiary.opacity(0.7)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .ctwThe(14)
            .padding(.bottom, 12)
            .overlay(alignment: .leading) {
                if g.status == "ACTIVE" || g.status == "GATE_REVIEW" {
                    RoundedRectangle(cornerRadius: 2).fill(k.mau).frame(width: 3).padding(.vertical, 14).padding(.bottom, 12)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stage \(g.n ?? 0), \(g.name), \(k.ten)")
    }

    private func dongNgay(_ g: GiaiDoanCTW) -> String? {
        let a = NgayCTW.thoiDiem(g.startedAt), b = NgayCTW.thoiDiem(g.completedAt)
        switch (a, b) {
        case let (a?, b?): return "\(NgayCTW.ngan(a)) – \(NgayCTW.ngan(b)) · \(max(NgayCTW.soNgay(a, b), 0) + 1) days"
        case let (a?, nil): return "Started \(NgayCTW.day(a)) · day \(max(NgayCTW.soNgay(a, Date()), 0) + 1)"
        case let (nil, b?): return "Completed \(NgayCTW.day(b))"
        default: return nil
        }
    }
}

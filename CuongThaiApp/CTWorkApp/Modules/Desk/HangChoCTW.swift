import SwiftUI

// MARK: - Service desk — HÀNG CHỜ ticket
//
// `GET /projects/:pid/desk/queue?view=&sort=&q=` (tối đa 500, có `truncated`).
// Mỗi hàng có hai viên SLA (phản hồi đầu + giải quyết) màu theo trạng thái —
// người trực bàn nhìn là biết ticket nào sắp vỡ hạn.

struct RouteTicketCTW: Hashable { var pid: Int; var so: Int }

@MainActor
final class HangChoVM: ObservableObject {
    let pid: Int
    @Published var du: CTWDeskHang?
    @Published var loi: String?
    @Published var biChan: String?
    @Published var cheDo = "open"
    @Published var sapXep = "sla"

    init(pid: Int) { self.pid = pid }

    func tai(q: String) async {
        do {
            du = try await APIClient.shared.request(CTWAPI.deskHang(pid: pid, cheDo: cheDo, q: q, sapXep: sapXep))
            loi = nil
        } catch {
            if Task.isCancelled { return }
            if DichVuLoi.biChan(error) { biChan = DichVuLoi.cau(error) } else { loi = DichVuLoi.cau(error) }
        }
    }
}

struct HangChoCTW: View {
    let pid: Int
    @StateObject private var vm: HangChoVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tim = ""

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: HangChoVM(pid: pid))
    }

    private var chip: [CTWChipLoc] {
        CTWDesk.cheDo.map { c in
            let n = vm.du?.counts?[c.ma]
            return CTWChipLoc(id: c.ma, nhan: n.map { "\(c.nhan) \($0)" } ?? c.nhan, bieuTuong: c.bieuTuong, bat: vm.cheDo == c.ma)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let b = vm.biChan {
                    CTWOTrong(bieuTuong: "lock.shield", tieuDe: String(localized: "Service desk unavailable"), moTa: b)
                } else {
                    CTWThanhLoc(chip: chip) { c in vm.cheDo = c.id }
                        .padding(.horizontal, -Spacing.md)
                    if let l = vm.loi { CTWErrorBanner(text: l) { vm.loi = nil } }
                    if let ds = vm.du?.items {
                        if ds.isEmpty {
                            CTWOTrong(bieuTuong: "tray", tieuDe: tim.isEmpty ? String(localized: "No tickets here") : String(localized: "No matches"),
                                      moTa: tim.isEmpty ? String(localized: "Tickets in this view will show up here.") : String(localized: "Try a different search."))
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(ds) { t in
                                    NavigationLink(value: RouteTicketCTW(pid: pid, so: t.number)) { HangTicketCTW(t: t) }
                                        .buttonStyle(.plain)
                                }
                            }
                            if vm.du?.truncated == true {
                                Text("Showing the first 500 tickets. Narrow the view or search to see more.")
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                            }
                        }
                    } else if vm.loi == nil {
                        CTWKhungTai(soHang: 5).padding(.horizontal, -Spacing.md)
                    }
                }
            }
            .padding(Spacing.md)
            .dvBeRong(820)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Service desk")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $tim, placement: .toolbar, prompt: "Search tickets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort", selection: $vm.sapXep) {
                        Text("SLA due first").tag("sla")
                        Text("Priority").tag("priority")
                        Text("Newest").tag("created")
                        Text("Recently updated").tag("updated")
                    }
                } label: { Image(systemName: "arrow.up.arrow.down") }
                .accessibilityLabel("Sort")
            }
        }
        .refreshable { await vm.tai(q: tim) }
        .task(id: "\(vm.cheDo)|\(vm.sapXep)|\(tim)") {
            if !tim.isEmpty { try? await Task.sleep(nanoseconds: 300_000_000) }
            guard !Task.isCancelled else { return }
            await vm.tai(q: tim)
        }
        // Đích `/work/<ws>/<KEY>/desk/<số>` hoặc `?ticket=<số>` ⇒ mở ticket.
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "desk" else { return }
            defer { app.dichCho = nil }
            if let so = d.duongDan.phanCon.first.flatMap(Int.init) ?? d.duongDan.tham["ticket"].flatMap(Int.init) {
                nganXep.duong.append(RouteTicketCTW(pid: pid, so: so))
            }
        }
        #if DEBUG
        .onAppear {
            if XemThuCTW.conCua("desk") == "ticket", nganXep.duong.count <= 1 {
                nganXep.duong.append(RouteTicketCTW(pid: pid, so: 52))
            }
        }
        #endif
    }
}

struct HangTicketCTW: View {
    let t: CTWDeskMuc

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: CTWDesk.bieuTuongLoai(t.requestType))
                    .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.primary)
                Text(t.key ?? "#\(t.number)").font(.ctw(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
                if let p = t.priority { CTWNhanNho(chu: p, mau: CTWDesk.mauUuTien(p)) }
                if t.channel == "PORTAL" { CTWNhanNho(chu: String(localized: "Portal"), bieuTuong: "globe") }
                Spacer(minLength: 0)
                if let s = t.status {
                    CTWChipChu(chu: s.name, mau: s.color.map { CTW.mau($0) } ?? CTW.mauNhom(s.category))
                }
            }
            Text(t.title).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                VienSla(ten: String(localized: "Response"), s: t.firstResponse)
                VienSla(ten: String(localized: "Resolve"), s: t.resolution)
                Spacer(minLength: 0)
                if t.waiting == true { Image(systemName: "pause.circle.fill").foregroundColor(AppColors.textSecondary).accessibilityLabel("Waiting on customer") }
                CTWAvatar(user: t.requester, size: 22)
                Image(systemName: "arrow.right").font(.ctw(size: 9)).foregroundColor(AppColors.textTertiary)
                CTWAvatar(user: t.assignee, size: 22)
            }
        }
        .padding(14)
        .ctwThe(14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Viên SLA nhỏ: tên + nhãn, màu theo trạng thái.
struct VienSla: View {
    let ten: String
    let s: CTWSla?
    var body: some View {
        let m = CTWDesk.mauSla(s)
        HStack(spacing: 4) {
            Image(systemName: s?.paused == true ? "pause.fill" : (s?.status == "MET" ? "checkmark" : "clock"))
                .font(.ctw(size: 9, weight: .bold))
            Text("\(ten) · \(CTWDesk.nhanSla(s))").font(.ctw(size: 11, weight: .semibold)).lineLimit(1).fixedSize()
        }
        .foregroundColor(m)
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Capsule().fill(m.opacity(0.12)))
        .accessibilityLabel("\(ten) SLA: \(CTWDesk.nhanSla(s))")
    }
}

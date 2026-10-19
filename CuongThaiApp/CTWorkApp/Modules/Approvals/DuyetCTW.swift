import SwiftUI

// MARK: - Phê duyệt — danh sách (Waiting on me · All)
//
// "Waiting on me" đọc `GET /me/approvals` (xuyên dự án, CHỈ bước đang tới lượt
// mình) rồi lọc theo dự án đang chọn — đúng như web. "All" đọc
// `GET /projects/:pid/approvals?status=` (mới nhất trước).

@MainActor
final class DuyetVM: ObservableObject {
    let pid: Int
    @Published var choToi: [CTWDuyet]?
    @Published var tatCa: [CTWDuyet]?
    @Published var locTrangThai: String?
    @Published var loi: String?
    @Published var tatMoDun = false

    init(pid: Int) { self.pid = pid }

    func tai() async {
        do {
            async let a: [CTWDuyet] = APIClient.shared.request(CTWAPI.duyetChoToi())
            async let b: [CTWDuyet] = APIClient.shared.request(CTWAPI.dsDuyet(pid: pid, trangThai: locTrangThai))
            let (x, y) = try await (a, b)
            choToi = x.filter { ($0.project?.id ?? $0.projectId) == pid }
            tatCa = y
            loi = nil
        } catch {
            if GovLoi.laTatMoDun(error) { tatMoDun = true; return }
            loi = CTW.loi(error)
        }
    }

    func taiTatCa() async {
        do { tatCa = try await APIClient.shared.request(CTWAPI.dsDuyet(pid: pid, trangThai: locTrangThai)); loi = nil }
        catch { loi = CTW.loi(error) }
    }
}

struct DuyetCTW: View {
    let pid: Int
    @StateObject private var vm: DuyetVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tab = 0

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: DuyetVM(pid: pid))
    }

    private static let locChip: [(id: String?, nhan: String)] = [
        (nil, "All"), ("PENDING", "Pending"), ("APPROVED", "Approved"), ("REJECTED", "Rejected"), ("CANCELLED", "Cancelled"),
    ]

    var body: some View {
        List {
            Section {
                Picker("View", selection: $tab) {
                    Text("Waiting on me\(vm.choToi.map { $0.isEmpty ? "" : " (\($0.count))" } ?? "")").tag(0)
                    Text("All").tag(1)
                }
                .pickerStyle(.segmented)
                if tab == 1 {
                    CTWThanhLoc(chip: Self.locChip.map { CTWChipLoc(id: $0.id ?? "ALL", nhan: $0.nhan, bat: vm.locTrangThai == $0.id) }) { c in
                        vm.locTrangThai = c.id == "ALL" ? nil : c.id
                        Task { await vm.taiTatCa() }
                    }
                    .padding(.horizontal, -Spacing.md)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if vm.tatMoDun {
                GovTatMoDun(ten: "Approvals").listRowBackground(Color.clear)
            } else if let ds = tab == 0 ? vm.choToi : vm.tatCa {
                if ds.isEmpty {
                    CTWOTrong(bieuTuong: tab == 0 ? "checkmark.seal" : "tray",
                              tieuDe: tab == 0 ? "Nothing waiting on you" : "No approvals",
                              moTa: tab == 0 ? "When someone asks you to sign off an issue, document, change request or stage gate, it shows up here."
                                            : "Approval requests for this project appear here.")
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(ds) { a in
                            NavigationLink(value: RouteDuyetCTW(pid: pid, id: a.id)) { GovHangDuyet(a: a, toi: app.currentUser?.id) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.choToi == nil && vm.loi == nil && !vm.tatMoDun { CTWKhungTai(soHang: 5) } }
        .navigationTitle("Approvals")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.tai() }
        .task { if vm.choToi == nil { await vm.tai() } }
        // Đích `/work/<ws>/<KEY>/approvals?id=<id>` (thông báo "cần bạn duyệt").
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "approvals" else { return }
            defer { app.dichCho = nil }
            if let id = (d.duongDan.tham["id"] ?? d.duongDan.phanCon.first).flatMap(Int.init) {
                nganXep.duong.append(RouteDuyetCTW(pid: pid, id: id))
            }
        }
        #if DEBUG
        .onAppear {
            if XemThuCTW.conCua("approvals") == "detail", nganXep.duong.count <= 1 {
                nganXep.duong.append(RouteDuyetCTW(pid: pid, id: 41))
            }
            if XemThuCTW.conCua("approvals") == "all" { tab = 1 }
        }
        #endif
    }
}

/// Một hàng phê duyệt.
struct GovHangDuyet: View {
    let a: CTWDuyet
    var toi: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: a.bieuTuong)
                .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(a.nhanDoiTuong).font(.ctw(size: 12, weight: .semibold).monospaced())
                        .foregroundColor(AppColors.textSecondary).lineLimit(1)
                    if let p = a.project?.key, a.project?.id != a.projectId { Text(p).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
                }
                Text(a.title ?? "Approval").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    CTWChipChu(chu: a.status)
                    if a.canDecide == true { CTWNhanNho(chu: "Your turn", bieuTuong: "hand.point.right.fill", mau: AppColors.primary) }
                    if a.contentChanged == true { CTWNhanNho(chu: "Changed", bieuTuong: "exclamationmark.triangle.fill", mau: AppColors.warning) }
                }
                HStack(spacing: 8) {
                    GovChongAvatar(users: a.dsBuoc.compactMap(\.approver), size: 20)
                    Text("\(a.soDaDuyet)/\(a.dsBuoc.count) approved").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    Spacer(minLength: 0)
                    if a.dangCho, let han = CTW.ngayNgan(a.dueAt) {
                        Label("Due \(han)", systemImage: "calendar").font(.ctw(size: 12, weight: a.quaHan ? .semibold : .regular))
                            .foregroundColor(a.quaHan ? AppColors.error : AppColors.textSecondary).labelStyle(.titleAndIcon)
                    } else if let t = GovNgay.tuongDoi(a.decidedAt ?? a.createdAt) {
                        Text(t).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI

// MARK: - Releases — danh sách phiên bản
//
// UNRELEASED trước (thứ tự `position` của máy chủ), RELEASED sau, ARCHIVED gập lại. Mỗi hàng:
// trạng thái (biểu tượng + chữ), ngày phát hành (quá hạn đỏ + biểu tượng), tiến độ done/total.
// Tạo phiên bản chỉ khi có quyền `manageSprints` (máy chủ: `sprint.manage`).

struct RoutePhienBanCTW: Hashable {
    var pid: Int
    var id: Int
    var ten: String
}

@MainActor
final class ReleasesVM: ObservableObject {
    let pid: Int
    @Published var trangThai: TaiCTW<[PhienBanCTW]> = .dangTai

    init(pid: Int) { self.pid = pid }

    func tai() async {
        do {
            let ds: [PhienBanCTW] = try await APIClient.shared.request(CTWAPI.dsPhienBan(pid: pid))
            trangThai = .xong(ds)
        } catch {
            if trangThai.giaTri == nil { trangThai = .loi(CTW.loi(error)) }
        }
    }
}

struct ReleasesCTW: View {
    let pid: Int
    @StateObject private var vm: ReleasesVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var moTao = false
    @State private var moLuuTru = false

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: ReleasesVM(pid: pid))
    }

    private var quanLy: Bool { app.cauHinhDuAn?.permissions?.manageSprints == true }

    var body: some View {
        KhungTaiCTW(trangThai: vm.trangThai, thuLai: { Task { await vm.tai() } }) { ds in
            if ds.isEmpty {
                CTWOTrong(bieuTuong: "shippingbox", tieuDe: String(localized: "No versions yet"),
                          moTa: String(localized: "Versions group the issues you plan to ship together and track how close they are."),
                          nut: quanLy ? String(localized: "New version") : nil, hanhDong: quanLy ? { moTao = true } : nil)
                    .frame(maxHeight: .infinity)
            } else {
                danhSach(ds)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Releases")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if quanLy {
                ToolbarItem(placement: .primaryAction) {
                    Button { moTao = true } label: { Image(systemName: "plus") }.accessibilityLabel("New version")
                }
            }
        }
        .sheet(isPresented: $moTao) {
            TaoPhienBanCTW(pid: pid) { Task { await vm.tai() } }
        }
        .task { await vm.tai() }
        .refreshable { await vm.tai() }
        // Deep link `/work/<ws>/<KEY>/releases?v=<id>` ⇒ mở thẳng phiên bản. Xoá cờ ở CUỐI.
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "releases" else { return }
            defer { app.dichCho = nil }
            if let v = d.duongDan.tham["v"].flatMap(Int.init) {
                nganXep.duong.append(RoutePhienBanCTW(pid: pid, id: v, ten: String(localized: "Release")))
            }
        }
        #if DEBUG
        .onAppear {
            if let c = XemThuCTW.conCua("releases"), let v = Int(c), nganXep.duong.count <= 1 {
                nganXep.duong.append(RoutePhienBanCTW(pid: pid, id: v, ten: String(localized: "Release")))
            }
        }
        #endif
    }

    private func danhSach(_ ds: [PhienBanCTW]) -> some View {
        let chua = ds.filter { $0.status == "UNRELEASED" || $0.status == nil }
        let da = ds.filter(\.daPhatHanh).sorted { ($0.releasedAt ?? $0.releaseDate ?? "") > ($1.releasedAt ?? $1.releaseDate ?? "") }
        let luu = ds.filter(\.daLuuTru)
        return List {
            if let ke = chua.first {
                Section { tomTat(ke) }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if !chua.isEmpty {
                Section { ForEach(chua) { hang($0) } } header: { dauMuc("Unreleased", chua.count) }
            }
            if !da.isEmpty {
                Section { ForEach(da) { hang($0) } } header: { dauMuc("Released", da.count) }
            }
            if !luu.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $moLuuTru) {
                        ForEach(luu) { hang($0) }
                    } label: {
                        Label("Archived (\(luu.count))", systemImage: "archivebox").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func dauMuc(_ t: LocalizedStringKey, _ n: Int) -> some View {
        HStack {
            Text(t)
            Spacer()
            Text("\(n)").foregroundColor(AppColors.textTertiary)
        }
        .font(.ctw(size: 13, weight: .semibold))
    }

    /// Thẻ "phát hành kế tiếp" ở đầu danh sách — câu hỏi hay gặp nhất khi đang ở ngoài.
    private func tomTat(_ v: PhienBanCTW) -> some View {
        NavigationLink(value: RoutePhienBanCTW(pid: pid, id: v.id, ten: v.name)) {
            HStack(spacing: 14) {
                CTWVongTienDo(tiLe: v.tiLe, co: 58, mau: v.overdue == true ? AppColors.error : AppColors.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT RELEASE").font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.textTertiary)
                    Text(v.name).font(.ctw(size: 18, weight: .bold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    Text(dongNgay(v)).font(.ctw(size: 13)).foregroundColor(v.overdue == true ? AppColors.error : AppColors.textSecondary)
                    Text("\(v.done ?? 0) of \(v.total ?? 0) issues done").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            }
            .padding(16)
            .ctwThe(16)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func hang(_ v: PhienBanCTW) -> some View {
        NavigationLink(value: RoutePhienBanCTW(pid: pid, id: v.id, ten: v.name)) {
            HangPhienBanCTW(v: v)
        }
    }

    fileprivate func dongNgay(_ v: PhienBanCTW) -> String { PhienBanChuCTW.dongNgay(v) }
}

/// Câu ngày của một phiên bản — dùng chung danh sách + chi tiết + lịch.
enum PhienBanChuCTW {
    static func dongNgay(_ v: PhienBanCTW) -> String {
        if v.daPhatHanh, let d = NgayCTW.ngay(v.releasedAt.flatMap(NgayCTW.ngayCua) ?? v.releaseDate) { return String(localized: "Released \(NgayCTW.day(d))") }
        guard let r = NgayCTW.ngay(v.releaseDate) else { return String(localized: "No release date") }
        let con = NgayCTW.soNgay(Date(), r)
        if v.overdue == true || con < 0 { return String(localized: "Overdue · was due \(NgayCTW.ngan(r))") }
        if con == 0 { return String(localized: "Releases today") }
        return con == 1 ? String(localized: "Releases \(NgayCTW.ngan(r)) · in 1 day") : String(localized: "Releases \(NgayCTW.ngan(r)) · in \(con) days")
    }

    static func trangThai(_ s: String?) -> (ten: String, bieuTuong: String, mau: Color) {
        switch s {
        case "RELEASED": return (String(localized: "Released"), "checkmark.seal.fill", AppColors.success)
        case "ARCHIVED": return (String(localized: "Archived"), "archivebox.fill", AppColors.textTertiary)
        default: return (String(localized: "Unreleased"), "shippingbox", CTWMauChuoi.mau(0))
        }
    }
}

struct HangPhienBanCTW: View {
    let v: PhienBanCTW

    var body: some View {
        let tt = PhienBanChuCTW.trangThai(v.status)
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: tt.bieuTuong).font(.ctw(size: 14, weight: .semibold)).foregroundColor(tt.mau)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tt.mau.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.name).font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    HStack(spacing: 4) {
                        if v.overdue == true { Image(systemName: "exclamationmark.circle.fill").font(.ctw(size: 10, weight: .bold)) }
                        Text(PhienBanChuCTW.dongNgay(v)).font(.ctw(size: 12))
                    }
                    .foregroundColor(v.overdue == true ? AppColors.error : AppColors.textSecondary)
                }
                Spacer(minLength: 0)
                Text(tt.ten).font(.ctw(size: 11, weight: .semibold)).foregroundColor(tt.mau)
            }
            HStack(spacing: 8) {
                CTWThanhTienDo(doan: [CTWDoanTienDo(ten: String(localized: "Done"), giaTri: Double(v.done ?? 0), mau: AppColors.success),
                                      CTWDoanTienDo(ten: String(localized: "Not done"), giaTri: Double(max((v.total ?? 0) - (v.done ?? 0), 0)), mau: AppColors.backgroundTertiary)],
                               cao: 6)
                Text("\(v.done ?? 0)/\(v.total ?? 0)").font(.ctw(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tạo phiên bản

struct TaoPhienBanCTW: View {
    let pid: Int
    let xong: () -> Void
    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var moTa = ""
    @State private var coBatDau = false
    @State private var batDau = Date()
    @State private var coPhatHanh = true
    @State private var phatHanh = Date().addingTimeInterval(14 * 86400)
    @State private var dangLuu = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { CTWErrorBanner(text: loi) }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
                Section("Version") {
                    TextField("Name, e.g. 1.2.0", text: $ten)
                    TextField("Description (optional)", text: $moTa, axis: .vertical).lineLimit(2...5)
                }
                Section("Dates") {
                    Toggle("Start date", isOn: $coBatDau)
                    if coBatDau { DatePicker("Starts", selection: $batDau, displayedComponents: .date) }
                    Toggle("Release date", isOn: $coPhatHanh)
                    if coPhatHanh { DatePicker("Releases", selection: $phatHanh, displayedComponents: .date) }
                }
            }
            .navigationTitle("New version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await luu() } }.bold()
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty || dangLuu)
                }
            }
        }
    }

    private func luu() async {
        if coBatDau && coPhatHanh && batDau > phatHanh { loi = String(localized: "The start date must be before the release date."); return }
        dangLuu = true
        defer { dangLuu = false }
        do {
            let t = moTa.trimmingCharacters(in: .whitespacesAndNewlines)
            let _: PhienBanCTW = try await APIClient.shared.request(CTWAPI.taoPhienBan(
                pid: pid, ten: ten.trimmingCharacters(in: .whitespaces), moTa: t.isEmpty ? nil : t,
                batDau: coBatDau ? CTW.chuoiNgay(batDau) : nil, phatHanh: coPhatHanh ? CTW.chuoiNgay(phatHanh) : nil))
            CTWRung.thanhCong()
            xong()
            dong()
        } catch {
            CTWRung.loi()
            loi = CTW.loi(error)
        }
    }
}

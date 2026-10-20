import SwiftUI

// MARK: - CT Work — bảng chọn dùng khi SỬA THẺ (20/10/2026)
//
// Bảng chọn gốc của iOS (Menu, DatePicker, List có dấu ✓) bọc thành tấm phủ nhỏ.
// Mọi bảng chọn nhận `luu: async -> Bool` — `true` ⇒ tự đóng; `false` ⇒ ở lại (lỗi đã hiện ở màn thẻ).

/// Móc mà app CT Work cắm vào chi tiết thẻ (app chính để `nil` ⇒ ẩn phần đó).
struct CTWIssueMoRong {
    /// Nút Start timer / Log time cho một thẻ (`NutGhiGioTheCTW` của mô-đun Time).
    var nutGhiGio: ((_ pid: Int, _ so: Int, _ tieuDe: String, _ daGhi: @escaping () -> Void) -> AnyView)?
    /// Liên kết mở một trang tài liệu (đích điều hướng của mô-đun Docs).
    var lienKetTrang: ((_ pid: Int, _ so: Int, _ ten: String, _ nhan: AnyView) -> AnyView)?
}

/// Chọn NHIỀU (nhãn, component, trường nhiều lựa chọn).
struct CTWChonNhieuView: View {
    struct Muc: Identifiable, Hashable {
        var id: String
        var ten: String
        var mau: String?
    }
    let tieuDe: String
    let muc: [Muc]
    let banDau: Set<String>
    let luu: (Set<String>) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var chon: Set<String> = []
    @State private var tim = ""
    @State private var dangLuu = false
    @State private var daNap = false

    var body: some View {
        NavigationStack {
            List {
                let ds = tim.isEmpty ? muc : muc.filter { $0.ten.localizedCaseInsensitiveContains(tim) }
                if ds.isEmpty {
                    Text("No matches").foregroundColor(AppColors.textSecondary)
                }
                ForEach(ds) { m in
                    Button {
                        if chon.contains(m.id) { chon.remove(m.id) } else { chon.insert(m.id) }
                        CTWRung.chon()
                    } label: {
                        HStack(spacing: 10) {
                            if let mau = m.mau {
                                Circle().fill(CTW.mau(mau, macDinh: AppColors.textSecondary)).frame(width: 10, height: 10)
                            }
                            Text(verbatim: m.ten).foregroundColor(AppColors.textPrimary)
                            Spacer()
                            if chon.contains(m.id) {
                                Image(systemName: "checkmark").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                            }
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(chon.contains(m.id) ? .isSelected : [])
                }
            }
            .searchable(text: $tim, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(tieuDe)
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button("Save") {
                            Task { dangLuu = true; if await luu(chon) { dong() }; dangLuu = false }
                        }
                        .fontWeight(.semibold)
                        .disabled(chon == banDau)
                    }
                }
            }
            .onAppear { if !daNap { chon = banDau; daNap = true } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Nhập MỘT giá trị chữ/số (story point, ước lượng, trường chữ/số/URL, lý do cờ).
struct CTWNhapGiaTriView: View {
    let tieuDe: String
    var nhan: String = ""
    var goiY: String = ""
    var chuThich: String?
    let banDau: String
    var banPhim: KieuBanPhim = .chu
    /// Câu lỗi khi không hợp lệ (chuỗi đã cắt khoảng trắng, không rỗng).
    var kiemTra: ((String) -> String?)?
    /// Cho phép để trống (= xoá giá trị).
    var choTrong = true
    let luu: (String) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var chu = ""
    @State private var loi: String?
    @State private var dangLuu = false
    @State private var daNap = false
    @FocusState private var dangGo: Bool

    enum KieuBanPhim { case chu, so, url, nhieuDong }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if banPhim == .nhieuDong {
                        TextField(goiY, text: $chu, axis: .vertical).lineLimit(3...8).focused($dangGo)
                    } else {
                        TextField(goiY, text: $chu)
                            .focused($dangGo)
                            #if os(iOS)
                            .keyboardType(banPhim == .so ? .decimalPad : (banPhim == .url ? .URL : .default))
                            .textInputAutocapitalization(banPhim == .chu ? .sentences : .never)
                            #endif
                            .autocorrectionDisabled(banPhim != .chu)
                            .onSubmit { Task { await luuNgay() } }
                    }
                } header: {
                    if !nhan.isEmpty { Text(verbatim: nhan) }
                } footer: {
                    if let loi { Text(loi).foregroundColor(AppColors.error) }
                    else if let chuThich { Text(verbatim: chuThich) }
                }
            }
            .navigationTitle(tieuDe)
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button("Save") { Task { await luuNgay() } }
                            .fontWeight(.semibold)
                            .disabled(!choTrong && chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onAppear {
                if !daNap { chu = banDau; daNap = true }
                dangGo = true
            }
        }
        .presentationDetents([.height(banPhim == .nhieuDong ? 320 : 260), .medium])
    }

    private func luuNgay() async {
        let t = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty, let l = kiemTra?(t) { loi = l; CTWRung.loi(); return }
        if t.isEmpty && !choTrong { return }
        dangLuu = true
        if await luu(t) { dong() }
        dangLuu = false
    }
}

/// Chọn một NGÀY (YYYY-MM-DD, không múi giờ) — có nút "Remove".
struct CTWChonNgayView: View {
    let tieuDe: String
    let banDau: String?
    /// `nil` = xoá ngày.
    let luu: (String?) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var ngay = Date()
    @State private var dangLuu = false
    @State private var daNap = false

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(tieuDe, selection: $ngay, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                if banDau != nil {
                    Section {
                        Button(role: .destructive) { Task { await ghi(nil) } } label: {
                            Label("Remove date", systemImage: "calendar.badge.minus")
                        }
                    }
                }
            }
            .navigationTitle(tieuDe)
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button("Save") { Task { await ghi(CTW.chuoiNgay(ngay)) } }.fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                guard !daNap else { return }
                daNap = true
                // Ngày lưu YYYY-MM-DD không múi giờ — dựng theo lịch MÁY để không lệch một ngày ở UTC+7.
                if let d = CTW.ngay(banDau) {
                    let p = d.split(separator: "-").compactMap { Int($0) }
                    if p.count == 3, let n = Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) { ngay = n }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func ghi(_ v: String?) async {
        dangLuu = true
        if await luu(v) { dong() }
        dangLuu = false
    }
}

/// Chọn THẺ CHA (epic cho thẻ thường, thẻ thường cho sub-task) — tìm theo mã/tiêu đề.
struct CTWChonTheView: View {
    let tieuDe: String
    let pid: Int
    let cfg: CTWProjectConfig
    /// Loại thẻ được chọn (id). Rỗng = mọi loại.
    let loai: [Int]
    var loaiTru: Set<Int> = []
    var choBoChon: Bool = false
    var nhanBoChon: String = ""
    var gomXong = false
    let chon: (CTWIssueCard?) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var tim = ""
    @State private var ds: [CTWIssueCard]?
    @State private var loi: String?
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            List {
                if let loi { CTWErrorBanner(text: loi) }
                if choBoChon {
                    Button { Task { await ghi(nil) } } label: {
                        Label(nhanBoChon, systemImage: "minus.circle").foregroundColor(AppColors.textPrimary)
                    }
                }
                if let ds {
                    let loc = ds.filter { !loaiTru.contains($0.id) }
                    if loc.isEmpty {
                        Text(tim.isEmpty ? "No open issues to choose from." : "No matches")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    ForEach(loc) { c in
                        Button { Task { await ghi(c) } } label: {
                            HStack(spacing: 8) {
                                CTWTypeIcon(type: cfg.loai(c.typeId), size: 12)
                                Text(verbatim: "\(cfg.key)-\(c.number)").font(.ctw(size: 12, weight: .medium).monospaced())
                                    .foregroundColor(AppColors.textSecondary)
                                Text(verbatim: c.title).foregroundColor(AppColors.textPrimary).lineLimit(2)
                                Spacer(minLength: 0)
                                CTWStatusChip(status: cfg.trangThai(c.statusId))
                            }
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .searchable(text: $tim, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search by key or title"))
            .navigationTitle(tieuDe)
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                if dangLuu { ToolbarItem(placement: .confirmationAction) { ProgressView() } }
            }
            .task(id: tim) {
                if !tim.isEmpty { try? await Task.sleep(nanoseconds: 300_000_000) }
                guard !Task.isCancelled else { return }
                await tai()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func tai() async {
        do {
            // "NW-12" / "12" ⇒ tìm theo số (máy chủ tìm `q` trong tiêu đề + số).
            var q = tim.trimmingCharacters(in: .whitespaces)
            if q.uppercased().hasPrefix(cfg.key.uppercased() + "-") { q = String(q.dropFirst(cfg.key.count + 1)) }
            let r: CTWIssueList = try await APIClient.shared.request(CTWAPI.dsTheLoc(pid: pid, loai: loai, q: q, gomXong: gomXong))
            ds = r.items ?? []
            loi = nil
        } catch {
            if ds == nil { ds = [] }
            loi = CTW.loi(error)
        }
    }

    private func ghi(_ c: CTWIssueCard?) async {
        dangLuu = true
        if await chon(c) { dong() }
        dangLuu = false
    }
}

import SwiftUI

// MARK: - Tiết kiệm

struct TietKiemView: View {
    @ObservedObject var vm: TienVM
    @State private var daNap = false
    @State private var moSo = false
    @State private var moMucTieu = false
    @State private var gopVao: MucTieuTietKiem?

    var body: some View {
        List {
            Section {
                HStack {
                    Text(T("Đang gửi")).font(.bodyMedium).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(DinhDangTien.day(dangGui.reduce(0) { $0 + $1.amount }))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.secondary)
                }
            }

            Section {
                if dangGui.isEmpty {
                    Text(T("Chưa có sổ tiết kiệm nào."))
                        .font(.bodySmall).foregroundStyle(AppColors.textTertiary)
                } else {
                    ForEach(dangGui) { s in dongSo(s) }
                }
                Button { moSo = true } label: {
                    Label(T("Thêm sổ tiết kiệm"), systemImage: "plus.circle")
                }
            } header: { Text(T("Sổ tiết kiệm")) }

            Section {
                if vm.dsMucTieuTietKiem.isEmpty {
                    Text(T("Chưa đặt mục tiêu nào — ví dụ “Quỹ khẩn cấp 20 triệu”."))
                        .font(.bodySmall).foregroundStyle(AppColors.textTertiary)
                } else {
                    ForEach(vm.dsMucTieuTietKiem) { m in
                        Button { gopVao = m } label: { dongMucTieu(m) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        _ = try? await TienAPI.xoaMucTieuTietKiem(id: m.id)
                                        await vm.napTietKiem()
                                    }
                                } label: { Label(T("Xoá"), systemImage: "trash") }
                            }
                    }
                }
                Button { moMucTieu = true } label: {
                    Label(T("Thêm mục tiêu tiết kiệm"), systemImage: "plus.circle")
                }
            } header: { Text(T("Mục tiêu tiết kiệm")) } footer: {
                Text(T("Chạm vào một mục tiêu để góp thêm tiền vào đó."))
            }

            if !daRut.isEmpty {
                Section(T("Đã rút")) {
                    ForEach(daRut) { s in
                        HStack {
                            Text(s.bankName).foregroundStyle(AppColors.textTertiary)
                            Spacer()
                            Text(DinhDangTien.day(s.amount, s.currency))
                                .font(.caption).foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Tiết kiệm"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard !daNap else { return }
            daNap = true
            await vm.napTietKiem()
        }
        .refreshable { await vm.napTietKiem() }
        .sheet(isPresented: $moSo) { ThemSoTietKiemView(vm: vm) }
        .sheet(isPresented: $moMucTieu) { ThemMucTieuTietKiemView(vm: vm) }
        .sheet(item: $gopVao) { m in GopMucTieuView(vm: vm, mucTieu: m) }
    }

    private var dangGui: [SoTietKiem] { vm.dsTietKiem.filter { $0.status != "WITHDRAWN" } }
    private var daRut: [SoTietKiem] { vm.dsTietKiem.filter { $0.status == "WITHDRAWN" } }

    private func dongSo(_ s: SoTietKiem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(s.bankName).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(DinhDangTien.day(s.amount, s.currency))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.secondary)
            }
            HStack(spacing: 6) {
                Text("\(soGon(s.interestRatePerYear))%/\(T("năm"))")
                Text("· \(s.termMonths) \(T("tháng"))")
                Text("· \(T("đáo hạn")) \(NgayTien.ngayDay(s.maturityDate))")
                    .foregroundStyle(dapHan(s) ? AppColors.success : AppColors.textTertiary)
            }
            .font(.caption2).foregroundStyle(AppColors.textTertiary)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task {
                    _ = try? await TienAPI.xoaTietKiem(id: s.id)
                    await vm.napTietKiem(); await vm.napBang()
                }
            } label: { Label(T("Xoá"), systemImage: "trash") }
            Button {
                Task {
                    _ = try? await TienAPI.rutTietKiem(id: s.id, viId: vm.viMacDinh?.id, kemLai: true)
                    await vm.napTietKiem(); await vm.napBang(); await vm.napDanhMuc()
                }
            } label: { Label(T("Rút"), systemImage: "arrow.down.to.line") }
            .tint(AppColors.secondary)
        }
    }

    private func dapHan(_ s: SoTietKiem) -> Bool {
        (NgayTien.conBaoNhieuNgay(s.maturityDate) ?? 99) <= 0
    }

    private func dongMucTieu(_ m: MucTieuTietKiem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(m.icon ?? "🎯") \(m.name)")
                    .font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(DinhDangTien.ngan(m.currentAmount)) / \(DinhDangTien.ngan(m.targetAmount))")
                    .font(.caption).foregroundStyle(AppColors.textSecondary)
            }
            ThanhTienDoTien(tiLe: m.tiLe, mau: m.tiLe >= 1 ? AppColors.success : AppColors.primary, cao: 6)
            if let h = m.deadline {
                Text("\(T("Hạn")) \(NgayTien.ngayDay(h))")
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func soGon(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    }
}

struct ThemSoTietKiemView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.dismiss) private var dong

    @State private var nganHang = ""
    @State private var soTienChu = ""
    @State private var laiChu = "5"
    @State private var soThang = 6
    @State private var ngayGui = NgayTien.homNay()
    @State private var viId: Int?
    @State private var dangLuu = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField(T("Ngân hàng / nơi gửi"), text: $nganHang) }
                Section { ONhapTien(nhan: T("Số tiền gửi"), chu: $soTienChu) }
                Section {
                    HStack {
                        Text(T("Lãi suất %/năm"))
                        Spacer()
                        TextField("0", text: $laiChu)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("%").foregroundStyle(AppColors.textTertiary)
                    }
                    Stepper("\(T("Kỳ hạn")): \(soThang) \(T("tháng"))", value: $soThang, in: 1...60)
                    ChonNgayTien(nhan: T("Ngày gửi"), ngay: $ngayGui)
                    if !vm.dsVi.isEmpty { ChonVi(dsVi: vm.dsVi, viId: $viId) }
                } footer: {
                    Text(T("Chọn ví để app trừ tiền khỏi ví đó. Bỏ trống thì chỉ ghi nhận sổ, số dư ví không đổi."))
                }
                if let l = loi { Section { Text(l).font(.caption).foregroundStyle(AppColors.error) } }
            }
            .navigationTitle(T("Thêm sổ tiết kiệm"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }
                        .disabled(nganHang.trimmingCharacters(in: .whitespaces).isEmpty
                                  || (DinhDangTien.doc(soTienChu) ?? 0) <= 0 || dangLuu)
                }
            }
        }
    }

    private func luu() async {
        guard let t = DinhDangTien.doc(soTienChu), t > 0 else { return }
        dangLuu = true
        defer { dangLuu = false }
        var m: [String: Any] = [
            "bankName": nganHang.trimmingCharacters(in: .whitespaces),
            "amount": t,
            "interestRatePerYear": Double(laiChu.replacingOccurrences(of: ",", with: ".")) ?? 0,
            "termMonths": soThang,
            "startDate": ngayGui,
        ]
        if let v = viId { m["walletId"] = v }
        do {
            _ = try await TienAPI.themTietKiem(m)
            await vm.napTietKiem(); await vm.napBang(); await vm.napDanhMuc()
            dong()
        } catch { loi = error.localizedDescription }
    }
}

struct ThemMucTieuTietKiemView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.dismiss) private var dong

    @State private var ten = ""
    @State private var dichChu = ""
    @State private var coHan = false
    @State private var han = NgayTien.homNay()
    @State private var bieuTuong = "🎯"
    @State private var dangLuu = false

    private let goiY = ["🎯", "💻", "🏍", "🏠", "✈️", "🚑", "🎓", "💍"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(T("Tên mục tiêu"), text: $ten)
                    ONhapTien(nhan: T("Cần bao nhiêu"), chu: $dichChu)
                }
                Section(T("Biểu tượng")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(goiY, id: \.self) { e in
                                Button { bieuTuong = e } label: {
                                    Text(e).font(.titleLarge)
                                        .frame(width: 42, height: 42)
                                        .background(bieuTuong == e ? AppColors.primary.opacity(0.2) : AppColors.backgroundTertiary)
                                        .cornerRadius(CornerRadius.medium)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section {
                    Toggle(T("Đặt hạn chót"), isOn: $coHan)
                    if coHan { ChonNgayTien(nhan: T("Hạn"), ngay: $han) }
                }
            }
            .navigationTitle(T("Mục tiêu tiết kiệm"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty
                                  || (DinhDangTien.doc(dichChu) ?? 0) <= 0 || dangLuu)
                }
            }
        }
    }

    private func luu() async {
        guard let d = DinhDangTien.doc(dichChu), d > 0 else { return }
        dangLuu = true
        defer { dangLuu = false }
        _ = try? await TienAPI.themMucTieuTietKiem(ten: ten, dich: d, hanChot: coHan ? han : nil, bieuTuong: bieuTuong)
        await vm.napTietKiem()
        dong()
    }
}

struct GopMucTieuView: View {
    @ObservedObject var vm: TienVM
    let mucTieu: MucTieuTietKiem
    @Environment(\.dismiss) private var dong

    @State private var soTienChu = ""
    @State private var viId: Int?
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("\(mucTieu.icon ?? "🎯") \(mucTieu.name)")
                        Spacer()
                        Text("\(DinhDangTien.ngan(mucTieu.currentAmount)) / \(DinhDangTien.ngan(mucTieu.targetAmount))")
                            .font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    ThanhTienDoTien(tiLe: mucTieu.tiLe)
                }
                Section {
                    ONhapTien(nhan: T("Góp thêm"), chu: $soTienChu)
                    if !vm.dsVi.isEmpty { ChonVi(dsVi: vm.dsVi, viId: $viId) }
                }
            }
            .navigationTitle(T("Góp vào mục tiêu"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Góp")) { Task { await gop() } }
                        .disabled((DinhDangTien.doc(soTienChu) ?? 0) <= 0 || dangLuu)
                }
            }
            .task { viId = vm.viMacDinh?.id }
        }
    }

    private func gop() async {
        guard let t = DinhDangTien.doc(soTienChu), t > 0 else { return }
        dangLuu = true
        defer { dangLuu = false }
        _ = try? await TienAPI.gopMucTieuTietKiem(id: mucTieu.id, soTien: t, viId: viId)
        await vm.napTietKiem(); await vm.napBang(); await vm.napDanhMuc()
        dong()
    }
}

// MARK: - Đầu tư

struct DauTuView: View {
    @ObservedObject var vm: TienVM
    @State private var daNap = false
    @State private var moThem = false
    @State private var capNhat: KhoanDauTu?

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Vốn đã bỏ")).font(.caption).foregroundStyle(AppColors.textSecondary)
                        Text(DinhDangTien.day(taiSan.reduce(0) { $0 + $1.amount }))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(T("Giá trị hiện tại")).font(.caption).foregroundStyle(AppColors.textSecondary)
                        Text(DinhDangTien.day(taiSan.reduce(0) { $0 + ($1.currentValue ?? $1.amount) }))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(tongLaiLo >= 0 ? AppColors.success : AppColors.error)
                    }
                }
                if tongLaiLo != 0 {
                    Text("\(tongLaiLo >= 0 ? "+" : "−")\(DinhDangTien.day(abs(tongLaiLo)))")
                        .font(.captionBold)
                        .foregroundStyle(tongLaiLo >= 0 ? AppColors.success : AppColors.error)
                }
            } header: { Text(T("Tài sản")) }

            if vm.dsDauTu.isEmpty {
                Section {
                    KhungTrongTien(bieuTuong: "chart.pie", tieuDe: T("Chưa có khoản đầu tư nào"),
                                   moTa: T("Tài sản (vàng, cổ phiếu…) hoặc đầu tư vào bản thân (khoá học, thiết bị)."),
                                   tenNut: T("Thêm khoản đầu tư")) { moThem = true }
                }
                .listRowBackground(Color.clear)
            } else {
                if !taiSan.isEmpty {
                    Section(T("Tài sản")) {
                        ForEach(taiSan) { d in
                            Button { capNhat = d } label: { dongDauTu(d) }.buttonStyle(.plain)
                                .swipeActions(edge: .trailing) { nutXoa(d) }
                        }
                    }
                }
                if !banThan.isEmpty {
                    Section(T("Đầu tư vào bản thân")) {
                        ForEach(banThan) { d in
                            dongDauTu(d)
                                .swipeActions(edge: .trailing) { nutXoa(d) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Đầu tư"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { moThem = true } label: { Image(systemName: "plus") }
            }
        }
        .task {
            guard !daNap else { return }
            daNap = true
            await vm.napDauTu()
        }
        .refreshable { await vm.napDauTu() }
        .sheet(isPresented: $moThem) { ThemDauTuView(vm: vm) }
        .sheet(item: $capNhat) { d in CapNhatGiaTriView(vm: vm, khoan: d) }
    }

    private var taiSan: [KhoanDauTu] { vm.dsDauTu.filter { $0.type == "ASSET" && $0.status != "SOLD" } }
    private var banThan: [KhoanDauTu] { vm.dsDauTu.filter { $0.type == "SELF" } }
    private var tongLaiLo: Double { taiSan.reduce(0) { $0 + ($1.laiLo ?? 0) } }

    private func nutXoa(_ d: KhoanDauTu) -> some View {
        Button(role: .destructive) {
            Task {
                _ = try? await TienAPI.xoaDauTu(id: d.id)
                await vm.napDauTu(); await vm.napBang()
            }
        } label: { Label(T("Xoá"), systemImage: "trash") }
    }

    private func dongDauTu(_ d: KhoanDauTu) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(d.name).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(DinhDangTien.day(d.currentValue ?? d.amount, d.currency))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
            HStack(spacing: 6) {
                Text(NgayTien.ngayDay(d.date))
                Text("· \(T("vốn")) \(DinhDangTien.ngan(d.amount))")
                if let ll = d.laiLo, ll != 0 {
                    Text("· \(ll > 0 ? "+" : "−")\(DinhDangTien.ngan(abs(ll)))")
                        .foregroundStyle(ll > 0 ? AppColors.success : AppColors.error)
                }
            }
            .font(.caption2).foregroundStyle(AppColors.textTertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct ThemDauTuView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.dismiss) private var dong

    @State private var loai = "ASSET"
    @State private var ten = ""
    @State private var vonChu = ""
    @State private var ngay = NgayTien.homNay()
    @State private var viId: Int?
    @State private var ghiChu = ""
    @State private var dangLuu = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(T("Loại"), selection: $loai) {
                        Text(T("Tài sản (vàng, cổ phiếu…)")).tag("ASSET")
                        Text(T("Vào bản thân (khoá học, thiết bị)")).tag("SELF")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    TextField(T("Tên khoản đầu tư"), text: $ten)
                    ONhapTien(nhan: T("Số tiền bỏ ra"), chu: $vonChu)
                    ChonNgayTien(nhan: T("Ngày"), ngay: $ngay)
                    if !vm.dsVi.isEmpty { ChonVi(dsVi: vm.dsVi, viId: $viId) }
                    TextField(loai == "SELF" ? T("Kỳ vọng nhận được gì") : T("Ghi chú"),
                              text: $ghiChu, axis: .vertical).lineLimit(1...3)
                }
                if let l = loi { Section { Text(l).font(.caption).foregroundStyle(AppColors.error) } }
            }
            .navigationTitle(T("Thêm khoản đầu tư"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty
                                  || (DinhDangTien.doc(vonChu) ?? 0) <= 0 || dangLuu)
                }
            }
        }
    }

    private func luu() async {
        guard let t = DinhDangTien.doc(vonChu), t > 0 else { return }
        dangLuu = true
        defer { dangLuu = false }
        var m: [String: Any] = ["type": loai, "name": ten.trimmingCharacters(in: .whitespaces),
                                "amount": t, "date": ngay]
        if let v = viId { m["walletId"] = v }
        if !ghiChu.isEmpty { m[loai == "SELF" ? "expectedOutcome" : "note"] = ghiChu }
        if loai == "ASSET" { m["currentValue"] = t }
        do {
            _ = try await TienAPI.themDauTu(m)
            await vm.napDauTu(); await vm.napBang(); await vm.napDanhMuc()
            dong()
        } catch { loi = error.localizedDescription }
    }
}

struct CapNhatGiaTriView: View {
    @ObservedObject var vm: TienVM
    let khoan: KhoanDauTu
    @Environment(\.dismiss) private var dong
    @State private var giaTriChu = ""
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(khoan.name).font(.bodyLarge)
                        Spacer()
                        Text("\(T("vốn")) \(DinhDangTien.day(khoan.amount))")
                            .font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                }
                Section {
                    ONhapTien(nhan: T("Giá trị bây giờ"), chu: $giaTriChu)
                } footer: {
                    Text(T("Giá trị do bạn tự cập nhật — app không lấy giá thị trường."))
                }
            }
            .navigationTitle(T("Cập nhật giá trị"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }
                        .disabled((DinhDangTien.doc(giaTriChu) ?? 0) <= 0 || dangLuu)
                }
            }
            .task { giaTriChu = String(Int(khoan.currentValue ?? khoan.amount)) }
        }
    }

    private func luu() async {
        guard let v = DinhDangTien.doc(giaTriChu), v > 0 else { return }
        dangLuu = true
        defer { dangLuu = false }
        _ = try? await TienAPI.capNhatGiaTri(id: khoan.id, giaTri: v)
        await vm.napDauTu(); await vm.napBang()
        dong()
    }
}

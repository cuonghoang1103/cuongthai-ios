import SwiftUI

// MARK: - Danh sách nợ

struct NoView: View {
    @ObservedObject var vm: TienVM
    @State private var moThem = false
    @State private var daNap = false

    var body: some View {
        List {
            if !vm.dsNo.isEmpty { khoiTong }

            if vm.dsNo.isEmpty {
                Section {
                    KhungTrongTien(bieuTuong: "checkmark.seal", tieuDe: T("Không có khoản nợ nào"),
                                   moTa: T("Thêm khoản nợ để app tự tính lịch trả và nhắc bạn trước hạn 3 ngày."),
                                   tenNut: T("Thêm khoản nợ")) { moThem = true }
                }
                .listRowBackground(Color.clear)
            } else {
                Section(T("Đang nợ")) {
                    ForEach(dangNo) { n in
                        NavigationLink { ChiTietNoView(vm: vm, noId: n.id) } label: { dongNo(n) }
                    }
                }
                if !daTraXong.isEmpty {
                    Section(T("Đã trả xong")) {
                        ForEach(daTraXong) { n in
                            NavigationLink { ChiTietNoView(vm: vm, noId: n.id) } label: { dongNo(n) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Nợ"))
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
            if vm.dsNo.isEmpty { await vm.napNo() }
        }
        .refreshable { await vm.napNo() }
        .sheet(isPresented: $moThem) { ThemNoView(vm: vm) }
    }

    private var dangNo: [No] { vm.dsNo.filter { $0.status != "PAID_OFF" } }
    private var daTraXong: [No] { vm.dsNo.filter { $0.status == "PAID_OFF" } }

    private var khoiTong: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Còn phải trả")).font(.caption).foregroundStyle(AppColors.textSecondary)
                    Text(DinhDangTien.day(dangNo.reduce(0) { $0 + ($1.computed?.remaining ?? 0) }))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.warning)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(T("Lãi đã trả")).font(.caption).foregroundStyle(AppColors.textSecondary)
                    Text(DinhDangTien.day(vm.dsNo.reduce(0) { $0 + ($1.computed?.interestPaid ?? 0) }))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func dongNo(_ n: No) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(n.lenderName).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(DinhDangTien.day(n.computed?.remaining ?? 0, n.currency))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(n.status == "PAID_OFF" ? AppColors.success : AppColors.warning)
            }
            if n.status != "PAID_OFF" {
                ThanhTienDoTien(tiLe: (n.computed?.progressPct ?? 0) / 100, mau: AppColors.success, cao: 5)
            }
            HStack(spacing: 6) {
                Text(tenBen(n.lenderType)).font(.caption2).foregroundStyle(AppColors.textTertiary)
                if let d = n.computed?.nextDueDate {
                    Text("· \(T("Kỳ tới")) \(NgayTien.ngayGon(d))")
                        .font(.caption2)
                        .foregroundStyle(quaHan(d) ? AppColors.error : AppColors.textTertiary)
                }
                if let l = n.computed?.interestPerDay, l > 0 {
                    Text("· \(DinhDangTien.ngan(l))/\(T("ngày"))")
                        .font(.caption2).foregroundStyle(AppColors.error)
                }
                Spacer()
                Text("\(Int(n.computed?.progressPct ?? 0))%")
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private func quaHan(_ d: String) -> Bool { (NgayTien.conBaoNhieuNgay(d) ?? 1) < 0 }
    private func tenBen(_ m: String) -> String {
        No.tenBenChoVay.first { $0.0 == m }.map { T($0.1) } ?? m
    }
}

// MARK: - Chi tiết một khoản nợ

struct ChiTietNoView: View {
    @ObservedObject var vm: TienVM
    let noId: Int
    @Environment(\.dismiss) private var dong

    @State private var no: No?
    @State private var dangTai = true
    @State private var kyDangTra: KyNo?
    @State private var hoiXoa = false

    var body: some View {
        List {
            if let n = no {
                Section { tomTat(n) }

                if let lich = n.schedule, !lich.isEmpty {
                    Section {
                        ForEach(lich.sorted { $0.installmentNo < $1.installmentNo }) { k in
                            dongKy(k, n)
                        }
                    } header: {
                        Text("\(T("Lịch trả")) — \(lich.filter { $0.isPaid }.count)/\(lich.count) \(T("kỳ"))")
                    } footer: {
                        Text(T("Chạm vào ô tròn để tích đã trả. Tích rồi thì app ngừng nhắc kỳ đó."))
                    }
                }

                if let g = n.note, !g.isEmpty {
                    Section(T("Ghi chú")) { Text(g).font(.bodyMedium) }
                }

                Section {
                    Button(role: .destructive) { hoiXoa = true } label: {
                        Label(T("Xoá khoản nợ"), systemImage: "trash")
                    }
                }
            } else if dangTai {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(no?.lenderName ?? T("Khoản nợ"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await nap() }
        .refreshable { await nap() }
        .sheet(item: $kyDangTra) { k in
            ChonViTraView(vm: vm, ky: k) { viId in
                Task {
                    await vm.doiTichKy(noId: noId, kyId: k.id, dangTich: false, viId: viId)
                    await nap()
                }
            }
        }
        .alert(T("Xoá khoản nợ này?"), isPresented: $hoiXoa) {
            Button(T("Huỷ"), role: .cancel) {}
            Button(T("Xoá"), role: .destructive) {
                Task {
                    _ = try? await TienAPI.xoaNo(id: noId)
                    await vm.napNo()
                    dong()
                }
            }
        } message: {
            Text(T("Cả lịch trả và các lần trả đã ghi đều mất theo. Không khôi phục được."))
        }
    }

    private func nap() async {
        dangTai = true
        defer { dangTai = false }
        no = try? await TienAPI.chiTietNo(id: noId)
    }

    private func tomTat(_ n: No) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Còn phải trả")).font(.caption).foregroundStyle(AppColors.textSecondary)
                    Text(DinhDangTien.day(n.computed?.remaining ?? 0, n.currency))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.warning)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(T("Gốc vay")).font(.caption).foregroundStyle(AppColors.textSecondary)
                    Text(DinhDangTien.day(n.principal, n.currency))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            ThanhTienDoTien(tiLe: (n.computed?.progressPct ?? 0) / 100, mau: AppColors.success)

            HStack(spacing: Spacing.md) {
                oNho(T("Lãi suất"), laiSuat(n))
                oNho(T("Đã trả gốc"), DinhDangTien.ngan(n.computed?.paidPrincipal ?? 0))
                oNho(T("Lãi đã trả"), DinhDangTien.ngan(n.computed?.interestPaid ?? 0))
            }
            if let l = n.computed?.interestPerDay, l > 0 {
                Text("\(T("Mỗi ngày chưa trả tốn thêm")) \(DinhDangTien.day(l))")
                    .font(.caption).foregroundStyle(AppColors.error)
            }
        }
        .padding(.vertical, 4)
    }

    private func oNho(_ nhan: String, _ gt: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(nhan).font(.caption2).foregroundStyle(AppColors.textTertiary)
            Text(gt).font(.captionBold).foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func laiSuat(_ n: No) -> String {
        switch n.interestType {
        case "NO_INTEREST": return T("Không lãi")
        case "DAILY_PERCENT": return "\(soGon(n.interestRate))%/\(T("ngày"))"
        default: return "\(soGon(n.interestRate))%/\(T("tháng"))"
        }
    }

    private func soGon(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    }

    private func dongKy(_ k: KyNo, _ n: No) -> some View {
        HStack(spacing: Spacing.sm) {
            Button {
                if k.isPaid {
                    Task {
                        await vm.doiTichKy(noId: noId, kyId: k.id, dangTich: true, viId: nil)
                        await nap()
                    }
                } else {
                    // Trả một kỳ thì phải trừ tiền khỏi MỘT ví cụ thể — hỏi
                    // trước. Tự chọn ví đầu danh sách là âm thầm rút tiền khỏi
                    // một cái ví người dùng không định đụng tới.
                    kyDangTra = k
                }
            } label: {
                Image(systemName: k.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.titleMedium)
                    .foregroundStyle(k.isPaid ? AppColors.success : AppColors.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(T("Kỳ")) \(k.installmentNo) · \(NgayTien.ngayDay(k.dueDate))")
                    .font(.bodyMedium)
                    .foregroundStyle(k.isPaid ? AppColors.textTertiary : AppColors.textPrimary)
                    .strikethrough(k.isPaid)
                Text("\(T("Gốc")) \(DinhDangTien.ngan(k.principalPart)) · \(T("lãi")) \(DinhDangTien.ngan(k.interestPart))")
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 1) {
                Text(DinhDangTien.day(k.amountDue, n.currency))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(k.isPaid ? AppColors.textTertiary : AppColors.textPrimary)
                if !k.isPaid, let con = NgayTien.conBaoNhieuNgay(k.dueDate) {
                    Text(con < 0 ? "\(T("quá")) \(-con)\(T("n"))" : (con == 0 ? T("hôm nay") : "\(T("còn")) \(con)\(T("n"))"))
                        .font(.caption2)
                        .foregroundStyle(con < 0 ? AppColors.error : (con <= 3 ? AppColors.warning : AppColors.textTertiary))
                }
            }
        }
    }
}

// MARK: - Chọn ví khi tích đã trả

struct ChonViTraView: View {
    @ObservedObject var vm: TienVM
    let ky: KyNo
    let xong: (Int?) -> Void
    @Environment(\.dismiss) private var dong
    @State private var viId: Int?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(T("Kỳ")); Spacer()
                        Text("\(ky.installmentNo) · \(NgayTien.ngayDay(ky.dueDate))")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    HStack {
                        Text(T("Số tiền")); Spacer()
                        Text(DinhDangTien.day(ky.amountDue))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                }
                Section {
                    ForEach(vm.dsVi) { v in
                        Button { viId = v.id } label: {
                            HStack {
                                Text(v.bieuTuong)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(v.name).foregroundStyle(AppColors.textPrimary)
                                    Text(DinhDangTien.day(v.balance, v.currency))
                                        .font(.caption).foregroundStyle(AppColors.textTertiary)
                                }
                                Spacer()
                                if viId == v.id {
                                    Image(systemName: "checkmark").foregroundStyle(AppColors.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button { viId = nil } label: {
                        HStack {
                            Text(T("Không trừ ví nào")).foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            if viId == nil { Image(systemName: "checkmark").foregroundStyle(AppColors.primary) }
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(T("Trừ tiền từ ví"))
                } footer: {
                    Text(T("Chọn “không trừ ví nào” nếu bạn đã trả bằng tiền không nằm trong ví nào của app."))
                }
            }
            .navigationTitle(T("Tích đã trả"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Xong")) { xong(viId); dong() }
                }
            }
            .task { viId = vm.viMacDinh?.id }
        }
    }
}

// MARK: - Thêm khoản nợ

struct ThemNoView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.dismiss) private var dong

    @State private var ten = ""
    @State private var ben = "LOAN_APP"
    @State private var gocChu = ""
    @State private var kieuLai = "FLAT_MONTHLY"
    @State private var laiChu = "0"
    @State private var soThang = 6
    @State private var ngayBatDau = NgayTien.homNay()
    @State private var ngayTraTrongThang = 5
    @State private var ghiChu = ""
    @State private var dangLuu = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(T("Tên bên cho vay"), text: $ten)
                    Picker(T("Loại"), selection: $ben) {
                        ForEach(No.tenBenChoVay, id: \.0) { m, t in Text(T(t)).tag(m) }
                    }
                }
                Section { ONhapTien(nhan: T("Số tiền vay (gốc)"), chu: $gocChu) }
                Section {
                    Picker(T("Kiểu lãi"), selection: $kieuLai) {
                        ForEach(No.tenKieuLai, id: \.0) { m, t in Text(T(t)).tag(m) }
                    }
                    if kieuLai != "NO_INTEREST" {
                        HStack {
                            Text(kieuLai == "DAILY_PERCENT" ? T("Lãi %/ngày") : T("Lãi %/tháng"))
                            Spacer()
                            TextField("0", text: $laiChu)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text("%").foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    Stepper("\(T("Số kỳ")): \(soThang)", value: $soThang, in: 1...120)
                    ChonNgayTien(nhan: T("Ngày vay"), ngay: $ngayBatDau)
                    Stepper("\(T("Ngày trả hàng tháng")): \(ngayTraTrongThang)", value: $ngayTraTrongThang, in: 1...28)
                } footer: {
                    Text(T("App tự dựng lịch trả theo các thông số này, rồi nhắc bạn 8h · 12h · 19h từ 3 ngày trước mỗi kỳ cho tới khi bạn tích đã trả."))
                }
                Section { TextField(T("Ghi chú"), text: $ghiChu, axis: .vertical).lineLimit(1...4) }
                if let l = loi {
                    Section { Text(l).font(.caption).foregroundStyle(AppColors.error) }
                }
            }
            .navigationTitle(T("Thêm khoản nợ"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty
                                  || (DinhDangTien.doc(gocChu) ?? 0) <= 0 || dangLuu)
                }
            }
        }
    }

    private func luu() async {
        guard let goc = DinhDangTien.doc(gocChu), goc > 0 else { return }
        dangLuu = true
        defer { dangLuu = false }
        // Dấu phẩy thập phân của bàn phím Việt: `Double("1,5")` là nil, và nil
        // ở đây thành lãi 0% — một khoản nợ ghi sai thành không lãi.
        let lai = kieuLai == "NO_INTEREST" ? 0 : (Double(laiChu.replacingOccurrences(of: ",", with: ".")) ?? 0)
        var m: [String: Any] = [
            "lenderName": ten.trimmingCharacters(in: .whitespaces),
            "lenderType": ben,
            "principal": goc,
            "interestType": kieuLai,
            "interestRate": lai,
            "startDate": ngayBatDau,
            "termMonths": soThang,
            "paymentDay": ngayTraTrongThang,
        ]
        if !ghiChu.isEmpty { m["note"] = ghiChu }
        do {
            _ = try await TienAPI.themNo(m)
            await vm.napNo()
            await vm.napBang()
            dong()
        } catch {
            loi = error.localizedDescription
        }
    }
}

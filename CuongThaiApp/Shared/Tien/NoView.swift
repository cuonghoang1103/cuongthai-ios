import SwiftUI

// MARK: - Danh sách nợ

/// Màn Nợ. Phần TỔNG HỢP (tổng còn phải trả, lãi còn lại, tháng này, quá
/// hạn, lịch theo tháng) lấy từ gói `/finance/phan-tich` — máy chủ đã quy
/// USD ra VND và tính lãi đúng theo từng kiểu. Chưa có gói đó (mạng chập
/// chờn, máy chủ cũ) thì rơi về khối tổng cũ, cộng từ danh sách.
struct NoView: View {
    @ObservedObject var vm: TienVM
    @State private var moThem = false
    @State private var daNap = false
    @Environment(\.horizontalSizeClass) private var beRong

    var body: some View {
        List {
            if let no = vm.phanTich?.no, let t = no.tong, !vm.dsNo.isEmpty {
                khoiTongMayChu(no, t)
                khoiQuaHanSapHan(no)
                khoiLichTheoThang(no)
                khoiChienLuoc
                khoiTatToanHomNay(no)
            } else if !vm.dsNo.isEmpty {
                khoiTong
            }

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
            let canNo = vm.dsNo.isEmpty, canPT = vm.phanTich == nil
            await withTaskGroup(of: Void.self) { g in
                if canNo { g.addTask { await vm.napNo() } }
                if canPT { g.addTask { await vm.napPhanTich() } }
            }
        }
        .refreshable {
            await withTaskGroup(of: Void.self) { g in
                g.addTask { await vm.napNo() }
                g.addTask { await vm.napPhanTich() }
            }
        }
        .sheet(isPresented: $moThem) { ThemNoView(vm: vm) }
    }

    private var dangNo: [No] { vm.dsNo.filter { $0.status != "PAID_OFF" } }
    private var daTraXong: [No] { vm.dsNo.filter { $0.status == "PAID_OFF" } }

    // MARK: Tổng (máy chủ)

    private func khoiTongMayChu(_ no: PhanTichNoTong, _ t: TongNoPT) -> some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Tổng còn phải trả (gốc + lãi)"))
                            .font(.caption).foregroundStyle(AppColors.textSecondary)
                        Text(DinhDangTien.day(t.tongConPhaiTra ?? 0))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(T("Hết nợ")).font(.caption).foregroundStyle(AppColors.textSecondary)
                        Text(t.ngayHetNo.map { NgayTien.ngayDay($0) } ?? "—")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                        if let s = t.soKhoanDangNo {
                            Text("\(s) \(T("khoản đang nợ"))").font(.caption2).foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm, alignment: .top),
                                         count: beRong == .regular ? 4 : 2),
                          alignment: .leading, spacing: Spacing.sm) {
                    OChiSoTien(nhan: T("Gốc còn lại"), giaTri: DinhDangTien.ngan(t.gocConLai ?? 0),
                               mau: AppColors.textPrimary,
                               phu: t.gocBanDau.map { "\(T("Vay ban đầu")) \(DinhDangTien.ngan($0))" })
                    OChiSoTien(nhan: T("Lãi còn phải trả"), giaTri: DinhDangTien.ngan(t.laiConPhaiTra ?? 0),
                               mau: AppColors.error,
                               phu: t.tongLaiCaKhoan.map { "\(T("Cả khoản")) \(DinhDangTien.ngan($0))" })
                    OChiSoTien(nhan: T("Phải trả tháng này"),
                               giaTri: DinhDangTien.ngan(no.thangNay?.tongNghiaVu ?? 0),
                               mau: AppColors.accent,
                               phu: "\(T("Còn")) \(DinhDangTien.ngan(no.thangNay?.conPhaiTra ?? 0)) (\(T("lãi")) \(DinhDangTien.ngan(no.thangNay?.laiTrongDo ?? 0))) · \(T("đã trả")) \(DinhDangTien.ngan(no.thangNay?.daTra ?? 0))")
                    OChiSoTien(nhan: T("Lãi đã trả"), giaTri: DinhDangTien.ngan(t.laiDaTra ?? 0),
                               mau: AppColors.textSecondary)
                }
                if let q = no.thangNay?.quaHanThangTruoc, (q.soKy ?? 0) > 0 {
                    Label("\(T("Còn")) \(q.soKy ?? 0) \(T("kỳ quá hạn từ tháng trước")): \(DinhDangTien.day(q.tong ?? 0))",
                          systemImage: "exclamationmark.octagon.fill")
                        .font(.caption).foregroundStyle(AppColors.error)
                }
                if vm.phanTich?.coUsdChuaQuyDoi == true {
                    Text(T("Có khoản USD chưa quy đổi được — chưa cộng vào tổng."))
                        .font(.caption2).foregroundStyle(AppColors.accent)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Quá hạn / sắp đến hạn

    @ViewBuilder
    private func khoiQuaHanSapHan(_ no: PhanTichNoTong) -> some View {
        if let qh = no.quaHan, !qh.isEmpty {
            Section {
                ForEach(qh) { k in
                    NavigationLink { ChiTietNoView(vm: vm, noId: k.debtId ?? 0) } label: { dongKyCanhBao(k, quaHan: true) }
                }
            } header: {
                Label(T("Quá hạn"), systemImage: "exclamationmark.octagon.fill").foregroundStyle(AppColors.error)
            }
        }
        if let sh = no.sapDenHan, !sh.isEmpty {
            Section {
                ForEach(sh) { k in
                    NavigationLink { ChiTietNoView(vm: vm, noId: k.debtId ?? 0) } label: { dongKyCanhBao(k, quaHan: false) }
                }
            } header: {
                Label(T("Sắp đến hạn"), systemImage: "clock.badge.exclamationmark").foregroundStyle(AppColors.accent)
            }
        }
    }

    private func dongKyCanhBao(_ k: KyCanhBaoPT, quaHan: Bool) -> some View {
        let mau = quaHan ? AppColors.error : AppColors.accent
        return HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 2).fill(mau).frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(k.ten ?? "").font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                Text("\(T("Kỳ")) \(k.ky ?? 0) · \(k.ngay.map { NgayTien.ngayDay($0) } ?? "")")
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(DinhDangTien.day(k.soTien ?? 0, k.tienTe ?? "VND"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(quaHan ? AppColors.error : AppColors.textPrimary)
                Text(quaHan
                     ? "\(T("quá")) \(k.soNgayQuaHan ?? 0) \(T("ngày"))"
                     : ((k.conNgay ?? 0) == 0 ? T("hôm nay") : "\(T("còn")) \(k.conNgay ?? 0) \(T("ngày"))"))
                    .font(.caption2).fontWeight(.semibold).foregroundStyle(mau)
            }
        }
    }

    // MARK: Lịch theo tháng

    @ViewBuilder
    private func khoiLichTheoThang(_ no: PhanTichNoTong) -> some View {
        if let ds = no.lichTheoThang, !ds.isEmpty {
            Section {
                ForEach(ds.prefix(3)) { t in
                    HStack {
                        Text(HienThiPhanTich.thangGon(t.thang))
                            .font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                            .frame(width: 64, alignment: .leading)
                        Text("\(T("gốc")) \(DinhDangTien.ngan(t.goc ?? 0)) · \(T("lãi")) \(DinhDangTien.ngan(t.lai ?? 0))")
                            .font(.caption).foregroundStyle(AppColors.textSecondary)
                        Spacer(minLength: 4)
                        Text(DinhDangTien.ngan(t.tong ?? 0))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
                NavigationLink { LichTraTheoThangView(ds: ds) } label: {
                    Label(T("Xem 12 tháng tới + biểu đồ gốc/lãi"), systemImage: "chart.bar.fill")
                        .font(.bodyMedium).foregroundStyle(AppColors.primary)
                }
            } header: {
                Text(T("Lịch trả theo tháng"))
            } footer: {
                Text(T("Chỉ gồm các kỳ chưa trả, quy ra VND."))
            }
        }
    }

    // MARK: Chiến lược

    private var khoiChienLuoc: some View {
        Section {
            NavigationLink { ChienLuocNoView(vm: vm) } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.titleMedium).foregroundStyle(AppColors.success)
                        .frame(width: 34, height: 34)
                        .background(AppColors.success.opacity(0.14))
                        .cornerRadius(CornerRadius.small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Nên trả khoản nào trước")).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                        Text(T("Nhập số tiền trả thêm mỗi tháng hoặc một khoản có sẵn — so sánh 4 cách trả và xem nên dồn tiền vào đâu."))
                            .font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Tất toán hôm nay

    @ViewBuilder
    private func khoiTatToanHomNay(_ no: PhanTichNoTong) -> some View {
        let ds = (no.tatToanHomNay ?? []).filter { ($0.tietKiem ?? 0) > 0 }
        if !ds.isEmpty {
            Section {
                ForEach(ds.prefix(5)) { k in
                    NavigationLink { ChiTietNoView(vm: vm, noId: k.debtId ?? 0) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(k.ten ?? "").font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                                    if k.chuaKhaiPhi == true {
                                        Text(T("chưa khai phí"))
                                            .font(.system(size: 10, weight: .semibold))
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background(AppColors.accent.opacity(0.15))
                                            .foregroundStyle(AppColors.accent)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("\(T("Cần")) \(DinhDangTien.day(k.chiPhiTatToan ?? 0, k.tienTe ?? "VND")) · \(T("bỏ")) \(k.soKyBoQua ?? 0) \(T("kỳ"))")
                                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
                            }
                            Spacer(minLength: 4)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(DinhDangTien.ngan(k.tietKiem ?? 0, k.tienTe ?? "VND"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.success)
                                Text(T("tiết kiệm")).font(.caption2).foregroundStyle(AppColors.textTertiary)
                            }
                        }
                    }
                }
            } header: {
                Text(T("Nếu tất toán hôm nay"))
            } footer: {
                Text(T("Mở một khoản để chọn ngày khác, xem giả định và ghi nhận đã tất toán."))
            }
        }
    }

    // MARK: Tổng cũ (dự phòng khi chưa có gói phân tích)

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
            Divider().padding(.vertical, 2)
            HStack(spacing: Spacing.sm) {
                oLai(T("Lãi mỗi tháng"), vm.tongLaiMoiThang, AppColors.error)
                oLai(T("Lãi còn phải trả"), vm.tongLaiConPhaiTra, AppColors.warning)
                oLai(T("Lãi cả khoản"), vm.tongLaiCaKhoan, AppColors.textSecondary)
            }
            if let l = vm.loiPhanTich {
                Text("\(T("Chưa tải được phân tích")): \(l)").font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private func oLai(_ nhan: String, _ v: Double, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(nhan).font(.caption2).foregroundStyle(AppColors.textTertiary)
            Text(DinhDangTien.ngan(v))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(mau).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Một dòng nợ

    private func dongNo(_ n: No) -> some View {
        let pt = vm.phanTich?.no?.cacKhoan?.first { $0.id == n.id }
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(n.lenderName).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                if (pt?.quaHan?.soKy ?? 0) > 0 {
                    Text(T("quá hạn"))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(AppColors.error.opacity(0.15))
                        .foregroundStyle(AppColors.error)
                        .clipShape(Capsule())
                }
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
                if let d = n.computed?.nextDueDate, n.status != "PAID_OFF" {
                    Text("· \(T("Kỳ tới")) \(NgayTien.ngayGon(d))")
                        .font(.caption2)
                        .foregroundStyle(quaHan(d) ? AppColors.error : AppColors.textTertiary)
                }
                if let ls = pt?.laiSuat?.thucNam, ls > 0, n.status != "PAID_OFF" {
                    // Lãi suất THỰC năm — con số so sánh được giữa các khoản,
                    // kể cả lãi phẳng / lãi ngày vốn "trông rẻ".
                    Text("· \(T("lãi thực")) \(HienThiPhanTich.phanTram(ls))/\(T("năm"))")
                        .font(.caption2).foregroundStyle(AppColors.error)
                } else if let l = n.computed?.interestPerDay, l > 0 {
                    Text("· \(DinhDangTien.ngan(l))/\(T("ngày"))")
                        .font(.caption2).foregroundStyle(AppColors.error)
                } else if n.status != "PAID_OFF", n.laiKyToi > 0 {
                    Text("· \(T("lãi")) \(DinhDangTien.ngan(n.laiKyToi))/\(T("tháng"))")
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
    @Environment(\.horizontalSizeClass) private var beRong

    @State private var no: No?
    @State private var dangTai = true
    @State private var loi: String?
    @State private var hoiXoa = false
    @State private var bang: BangNo?

    /// MỘT `.sheet(item:)` cho mọi bảng (CLAUDE.md C5).
    enum BangNo: Identifiable {
        case traKy(KyNo)
        case tatToan
        case suaPhi
        var id: String {
            switch self {
            case .traKy(let k): return "ky-\(k.id)"
            case .tatToan: return "tatToan"
            case .suaPhi: return "suaPhi"
            }
        }
    }

    var body: some View {
        List {
            if let n = no {
                Section { tomTat(n) }

                if let pt = n.phanTich {
                    if let q = pt.quaHan, (q.soKy ?? 0) > 0 {
                        Section {
                            Label("\(q.soKy ?? 0) \(T("kỳ quá hạn")) · \(DinhDangTien.day(q.soTien ?? 0, n.currency)) · \(T("lâu nhất")) \(q.lauNhatNgay ?? 0) \(T("ngày"))",
                                  systemImage: "exclamationmark.octagon.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.error)
                        }
                        .listRowBackground(AppColors.error.opacity(0.10))
                    }
                    khoiLaiSuat(pt, n)
                    khoiTienLai(pt, n)
                }

                khoiTatToanVaPhi(n)

                khoiLich(n)

                if let t = n.phanTich?.thieuDuLieu, !t.isEmpty {
                    Section(T("Thiếu dữ liệu")) {
                        ForEach(t, id: \.self) { Text($0).font(.caption).foregroundStyle(AppColors.accent) }
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
            } else if let l = loi {
                Section {
                    KhungTrongTien(bieuTuong: "exclamationmark.icloud", tieuDe: T("Chưa tải được khoản nợ"),
                                   moTa: l, tenNut: T("Thử lại")) { Task { await nap() } }
                }
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
        .sheet(item: $bang) { b in
            switch b {
            case .traKy(let k):
                ChonViTraView(vm: vm,
                              nhanKy: "\(k.installmentNo) · \(NgayTien.ngayDay(k.dueDate))",
                              soTien: k.amountDue,
                              tienTe: no?.currency ?? "VND") { viId in
                    Task {
                        await vm.doiTichKy(noId: noId, kyId: k.id, dangTich: false, viId: viId)
                        await nap()
                    }
                }
            case .tatToan:
                TatToanSomView(vm: vm, noId: noId, tenNo: no?.lenderName ?? "") {
                    Task { await nap() }
                }
            case .suaPhi:
                SuaPhiTraTruocView(noId: noId, hienTai: no?.prepayFeePct) {
                    Task {
                        await nap()
                        await vm.napPhanTich()
                    }
                }
            }
        }
        .alert(T("Xoá khoản nợ này?"), isPresented: $hoiXoa) {
            Button(T("Huỷ"), role: .cancel) {}
            Button(T("Xoá"), role: .destructive) {
                Task {
                    _ = try? await TienAPI.xoaNo(id: noId)
                    await vm.napNo()
                    await vm.napPhanTich()
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
        do {
            no = try await TienAPI.chiTietNo(id: noId)
            loi = nil
        } catch {
            if case APIError.unauthorized = error { return }
            loi = error.localizedDescription
        }
    }

    private var daXong: Bool { no?.status == "PAID_OFF" || no?.phanTich?.daTatToan == true }

    // MARK: Tóm tắt

    private func tomTat(_ n: No) -> some View {
        let pt = n.phanTich
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pt != nil ? T("Còn phải trả (gốc + lãi)") : T("Còn phải trả"))
                        .font(.caption).foregroundStyle(AppColors.textSecondary)
                    Text(DinhDangTien.day(pt?.tongConPhaiTra ?? n.computed?.remaining ?? 0, n.currency))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(daXong ? AppColors.success : AppColors.warning)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(T("Gốc vay")).font(.caption).foregroundStyle(AppColors.textSecondary)
                    Text(DinhDangTien.day(n.principal, n.currency))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(HienThiPhanTich.tenKieuLai(n.interestType))
                        .font(.caption2).foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.trailing)
                }
            }
            ThanhTienDoTien(tiLe: (n.computed?.progressPct ?? 0) / 100, mau: AppColors.success)

            HStack(spacing: Spacing.md) {
                oNho(T("Lãi suất"), laiSuat(n))
                oNho(T("Gốc còn lại"), DinhDangTien.ngan(pt?.gocConLai ?? n.computed?.remaining ?? 0, n.currency))
                oNho(T("Đã trả gốc"), DinhDangTien.ngan(pt?.gocDaTra ?? n.computed?.paidPrincipal ?? 0, n.currency))
            }
            if let k = pt?.kyToi, !daXong {
                Text("\(T("Kỳ tới")): \(T("kỳ")) \(k.ky ?? 0) · \(k.ngay.map { NgayTien.ngayDay($0) } ?? "") · \(DinhDangTien.day(k.tong ?? 0, n.currency))")
                    .font(.caption).foregroundStyle(AppColors.textSecondary)
            }
            if let l = pt?.laiMoiNgay ?? n.computed?.interestPerDay, l > 0 {
                Text("\(T("Mỗi ngày chưa trả tốn thêm")) \(DinhDangTien.day(l, n.currency))")
                    .font(.caption).foregroundStyle(AppColors.error)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Lãi suất

    private func khoiLaiSuat(_ pt: PhanTichKhoanNo, _ n: No) -> some View {
        let ls = pt.laiSuat
        let chenh = (ls?.thucNam ?? 0) - (ls?.danhNghiaNam ?? 0)
        return Section {
            HStack(spacing: Spacing.sm) {
                OChiSoTien(nhan: T("Danh nghĩa"),
                           giaTri: "\(HienThiPhanTich.phanTram(ls?.danhNghiaNam, soLe: 2))/\(T("năm"))",
                           mau: AppColors.textPrimary,
                           phu: "\(HienThiPhanTich.phanTram(ls?.danhNghiaThang, soLe: 3))/\(T("tháng"))")
                OChiSoTien(nhan: T("Thực (IRR)"),
                           giaTri: "\(HienThiPhanTich.phanTram(ls?.thucNam, soLe: 2))/\(T("năm"))",
                           mau: chenh > 0.5 ? AppColors.error : AppColors.textPrimary,
                           phu: "\(HienThiPhanTich.phanTram(ls?.thucThang, soLe: 3))/\(T("tháng"))")
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        } header: {
            Text(T("Lãi suất"))
        } footer: {
            Text(chenh > 0.5
                 ? T("Lãi suất thực cao hơn danh nghĩa: lãi đang tính trên số tiền bạn không còn giữ (lãi phẳng) hoặc cộng dồn theo ngày. So sánh các khoản bằng lãi suất THỰC.")
                 : T("Lãi suất thực = chi phí vay thật theo dòng tiền từng kỳ (IRR). Dùng con số này để so sánh các khoản với nhau."))
        }
    }

    // MARK: Tiền lãi

    private func khoiTienLai(_ pt: PhanTichKhoanNo, _ n: No) -> some View {
        Section(T("Tiền lãi & tất toán")) {
            dongSo(T("Lãi đã trả"), DinhDangTien.day(pt.laiDaTra ?? 0, n.currency), AppColors.textSecondary)
            dongSo(T("Lãi còn phải trả"), DinhDangTien.day(pt.laiConPhaiTra ?? 0, n.currency), AppColors.error)
            dongSo(T("Tổng lãi cả khoản"), DinhDangTien.day(pt.tongLaiCaKhoan ?? 0, n.currency), AppColors.textPrimary)
            dongSo(T("Tổng phải trả cả khoản"), DinhDangTien.day(pt.tongPhaiTraCaKhoan ?? 0, n.currency), AppColors.textPrimary)
            if let d = pt.ngayTatToanDuKien {
                dongSo(T("Tất toán dự kiến"), NgayTien.ngayDay(d)
                       + (pt.soKyConLai.map { " · \(T("còn")) \($0) \(T("kỳ"))" } ?? ""), AppColors.primary)
            }
            if let c = pt.chenhLechThucTra, abs(c) >= 1 {
                dongSo(T("Chênh lệch trả thực tế so với lịch"), DinhDangTien.day(c, n.currency), AppColors.accent)
            }
        }
    }

    // MARK: Tất toán sớm + phí

    private func khoiTatToanVaPhi(_ n: No) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Phí trả trước hạn")).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                    if let p = n.prepayFeePct ?? n.phanTich?.phiTraTruocPct {
                        Text("\(HienThiPhanTich.phanTram(p, soLe: 3)) \(T("trên số gốc trả trước"))")
                            .font(.caption).foregroundStyle(AppColors.textSecondary)
                    } else {
                        Text(T("Chưa khai — mô phỏng đang tính phí 0"))
                            .font(.caption).foregroundStyle(AppColors.accent)
                    }
                }
                Spacer()
                Button(T("Sửa")) { bang = .suaPhi }
                    .font(.buttonSmall)
                    .buttonStyle(.bordered)
            }
            if !daXong {
                Button { bang = .tatToan } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(AppColors.success)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Mô phỏng tất toán sớm")).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                            Text(T("Chọn ngày → xem chi phí, tiết kiệm; ghi nhận khi đã trả xong."))
                                .font(.caption).foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(AppColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(T("Trả trước hạn"))
        }
    }

    // MARK: Lịch trả

    @ViewBuilder
    private func khoiLich(_ n: No) -> some View {
        if let lich = n.phanTich?.lich, !lich.isEmpty {
            let daTra = lich.filter { $0.trangThai == "DA_TRA" }.count
            Section {
                if beRong == .regular { hangTieuDeLich }
                ForEach(lich, id: \.ma) { k in dongKyPT(k, n) }
            } header: {
                Text("\(T("Lịch trả")) — \(daTra)/\(lich.count) \(T("kỳ"))")
            } footer: {
                Text(T("Chạm vào ô tròn để tích đã trả. Tích rồi thì app ngừng nhắc kỳ đó."))
            }
        } else if let lich = n.schedule, !lich.isEmpty {
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
    }

    private var hangTieuDeLich: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 26)
            Text(T("Kỳ")).frame(width: 110, alignment: .leading)
            Text(T("Gốc")).frame(maxWidth: .infinity, alignment: .trailing)
            Text(T("Lãi")).frame(maxWidth: .infinity, alignment: .trailing)
            Text(T("Tổng")).frame(maxWidth: .infinity, alignment: .trailing)
            Text(T("Dư nợ còn lại")).frame(maxWidth: .infinity, alignment: .trailing)
            Text(T("Trạng thái")).frame(width: 120, alignment: .trailing)
        }
        .font(.captionBold).foregroundStyle(AppColors.textTertiary)
    }

    private func nutTich(_ daTra: Bool, kyId: Int?, n: No, mau: Color) -> some View {
        Button {
            guard let id = kyId, let ky = n.schedule?.first(where: { $0.id == id }) else { return }
            if daTra {
                Task {
                    await vm.doiTichKy(noId: noId, kyId: id, dangTich: true, viId: nil)
                    await nap()
                }
            } else {
                // Trả một kỳ thì phải trừ tiền khỏi MỘT ví cụ thể — hỏi
                // trước. Tự chọn ví đầu danh sách là âm thầm rút tiền khỏi
                // một cái ví người dùng không định đụng tới.
                bang = .traKy(ky)
            }
        } label: {
            Image(systemName: daTra ? "checkmark.circle.fill" : "circle")
                .font(.titleMedium)
                .foregroundStyle(mau)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(daTra ? T("Bỏ tích đã trả") : T("Tích đã trả kỳ này"))
    }

    private func dongKyPT(_ k: KyLichPT, _ n: No) -> some View {
        let (chu, mau) = trangThai(k)
        let daTra = k.trangThai == "DA_TRA"
        let tt = n.currency
        return Group {
            if beRong == .regular {
                HStack(spacing: 8) {
                    nutTich(daTra, kyId: k.id, n: n, mau: daTra ? AppColors.success : mau)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(T("Kỳ")) \(k.ky ?? 0)").font(.bodyMedium)
                        Text(k.ngay.map { NgayTien.ngayDay($0) } ?? "").font(.caption2).foregroundStyle(AppColors.textTertiary)
                    }
                    .frame(width: 110, alignment: .leading)
                    Text(DinhDangTien.day(k.goc ?? 0, tt)).frame(maxWidth: .infinity, alignment: .trailing)
                    Text(DinhDangTien.day(k.lai ?? 0, tt)).foregroundStyle(AppColors.error.opacity(daTra ? 0.6 : 1))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(DinhDangTien.day(k.tong ?? 0, tt)).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .trailing)
                    Text(DinhDangTien.day(k.duNoSau ?? 0, tt)).foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    chipTrangThai(chu, mau).frame(width: 120, alignment: .trailing)
                }
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(daTra ? AppColors.textTertiary : AppColors.textPrimary)
            } else {
                HStack(spacing: Spacing.sm) {
                    nutTich(daTra, kyId: k.id, n: n, mau: daTra ? AppColors.success : mau)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(T("Kỳ")) \(k.ky ?? 0) · \(k.ngay.map { NgayTien.ngayDay($0) } ?? "")")
                            .font(.bodyMedium)
                            .foregroundStyle(daTra ? AppColors.textTertiary : AppColors.textPrimary)
                        Text("\(T("Gốc")) \(DinhDangTien.ngan(k.goc ?? 0, tt)) · \(T("lãi")) \(DinhDangTien.ngan(k.lai ?? 0, tt))")
                            .font(.caption2).foregroundStyle(AppColors.textTertiary)
                        Text("\(T("Dư nợ còn lại")) \(DinhDangTien.ngan(k.duNoSau ?? 0, tt))")
                            .font(.caption2).foregroundStyle(AppColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(DinhDangTien.day(k.tong ?? 0, tt))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(daTra ? AppColors.textTertiary : AppColors.textPrimary)
                        chipTrangThai(chu, mau)
                    }
                }
            }
        }
        .listRowBackground(k.trangThai == "QUA_HAN" ? AppColors.error.opacity(0.07)
                           : (k.trangThai == "HOM_NAY" ? AppColors.accent.opacity(0.07) : nil))
    }

    private func trangThai(_ k: KyLichPT) -> (String, Color) {
        let n = k.soNgayQuaHan ?? 0
        switch k.trangThai {
        case "DA_TRA": return (T("Đã trả"), AppColors.success)
        case "QUA_HAN": return ("\(T("Quá hạn")) \(n) \(T("ngày"))", AppColors.error)
        case "HOM_NAY": return (T("Hôm nay"), AppColors.accent)
        default:
            if n < 0, -n <= 7 { return ("\(T("Còn")) \(-n) \(T("ngày"))", AppColors.accent) }
            return (T("Chưa đến"), AppColors.textTertiary)
        }
    }

    private func chipTrangThai(_ chu: String, _ mau: Color) -> some View {
        Text(chu)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(mau.opacity(0.14))
            .foregroundStyle(mau)
            .clipShape(Capsule())
            .lineLimit(1)
    }

    // MARK: Tiện

    private func oNho(_ nhan: String, _ gt: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(nhan).font(.caption2).foregroundStyle(AppColors.textTertiary)
            Text(gt).font(.captionBold).foregroundStyle(AppColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dongSo(_ nhan: String, _ gt: String, _ mau: Color) -> some View {
        HStack {
            Text(nhan).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
            Spacer(minLength: 8)
            Text(gt).font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(mau).multilineTextAlignment(.trailing)
        }
    }

    private func laiSuat(_ n: No) -> String {
        switch n.interestType {
        case "NO_INTEREST": return T("Không lãi")
        default:
            let dv: String
            switch n.rateUnit ?? (n.interestType == "DAILY_PERCENT" ? "DAY" : "MONTH") {
            case "DAY": dv = T("ngày")
            case "YEAR": dv = T("năm")
            default: dv = T("tháng")
            }
            return "\(soGon(n.interestRate))%/\(dv)"
        }
    }

    private func soGon(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    }

    /// Dòng lịch kiểu CŨ — chỉ dùng khi máy chủ chưa trả khối `phanTich`.
    private func dongKy(_ k: KyNo, _ n: No) -> some View {
        HStack(spacing: Spacing.sm) {
            Button {
                if k.isPaid {
                    Task {
                        await vm.doiTichKy(noId: noId, kyId: k.id, dangTich: true, viId: nil)
                        await nap()
                    }
                } else {
                    bang = .traKy(k)
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
    /// Nhận GIÁ TRỊ RỜI chứ không nhận `KyNo`: màn tổng quan chỉ có
    /// `KyNoSapToi` (không có `installmentNo`, không có phần gốc/lãi). Buộc
    /// nó phải dựng một `KyNo` giả để gọi được bảng này là mời gọi bịa số.
    let nhanKy: String
    let soTien: Double
    let tienTe: String
    let xong: (Int?) -> Void
    @Environment(\.dismiss) private var dong
    @State private var viId: Int?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(T("Kỳ")); Spacer()
                        Text(nhanKy).foregroundStyle(AppColors.textSecondary)
                    }
                    HStack {
                        Text(T("Số tiền")); Spacer()
                        Text(DinhDangTien.day(soTien, tienTe))
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
    @State private var tienTe = "VND"
    @State private var gocChu = ""
    @State private var kieuLai = "EQUAL_PRINCIPAL"
    @State private var laiChu = "0"
    /// `MONTH` | `YEAR`; lãi ngày thì luôn `DAY` (máy chủ chỉ nhận DAY cho kiểu đó).
    @State private var donViLai = "YEAR"
    @State private var soThang = 12
    @State private var ngayBatDau = NgayTien.homNay()
    @State private var ngayTraTrongThang = 5
    @State private var phiChu = ""
    @State private var ghiChu = ""
    @State private var dangLuu = false
    @State private var loi: String?

    private var laLaiNgay: Bool { kieuLai == "DAILY_PERCENT" }
    private var phi: Double? { Double(phiChu.replacingOccurrences(of: ",", with: ".")) }
    private var phiHopLe: Bool { phiChu.isEmpty || (phi.map { $0 >= 0 && $0 <= 100 } ?? false) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(T("Tên bên cho vay"), text: $ten)
                    Picker(T("Loại"), selection: $ben) {
                        ForEach(No.tenBenChoVay, id: \.0) { m, t in Text(T(t)).tag(m) }
                    }
                    Picker(T("Tiền tệ"), selection: $tienTe) {
                        Text("VND ₫").tag("VND")
                        Text("USD $").tag("USD")
                    }
                    .pickerStyle(.segmented)
                }
                Section { ONhapTien(nhan: T("Số tiền vay (gốc)"), chu: $gocChu, tienTe: tienTe) }
                Section {
                    Picker(T("Kiểu lãi"), selection: $kieuLai) {
                        ForEach(No.tenKieuLai, id: \.0) { m, t in Text(T(t)).tag(m) }
                    }
                    if kieuLai != "NO_INTEREST" {
                        HStack {
                            Text(T("Lãi suất"))
                            Spacer()
                            TextField("0", text: $laiChu)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text(laLaiNgay ? T("%/ngày") : (donViLai == "YEAR" ? T("%/năm") : T("%/tháng")))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        if !laLaiNgay {
                            Picker(T("Đơn vị lãi"), selection: $donViLai) {
                                Text(T("%/tháng")).tag("MONTH")
                                Text(T("%/năm")).tag("YEAR")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    Stepper("\(T("Số kỳ (tháng)")): \(soThang)", value: $soThang, in: 1...360)
                    ChonNgayTien(nhan: T("Ngày vay"), ngay: $ngayBatDau)
                    Stepper("\(T("Ngày trả hàng tháng")): \(ngayTraTrongThang)", value: $ngayTraTrongThang, in: 1...28)
                } header: {
                    Text(T("Lãi & kỳ hạn"))
                } footer: {
                    Text(moTaKieuLai)
                }
                Section {
                    HStack {
                        Text(T("Phí trả trước hạn"))
                        Spacer()
                        TextField(T("chưa biết"), text: $phiChu)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("%").foregroundStyle(AppColors.textTertiary)
                    }
                    if !phiHopLe {
                        Text(T("Nhập số từ 0 đến 100.")).font(.caption).foregroundStyle(AppColors.error)
                    }
                } footer: {
                    Text(T("% trên số gốc trả trước hạn, xem trong hợp đồng. Để trống nếu chưa biết — sửa được sau."))
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
                                  || (DinhDangTien.doc(gocChu) ?? 0) <= 0 || !phiHopLe || dangLuu)
                }
            }
            .onChange(of: kieuLai) { cu, moi in
                // Đổi sang/khỏi lãi ngày thì đơn vị cũ không còn hợp lệ.
                if moi == "DAILY_PERCENT" { donViLai = "DAY" }
                else if cu == "DAILY_PERCENT" || donViLai == "DAY" { donViLai = "YEAR" }
            }
        }
    }

    private var moTaKieuLai: String {
        switch kieuLai {
        case "EQUAL_PRINCIPAL":
            return T("Mỗi kỳ trả phần gốc bằng nhau + lãi trên dư nợ còn lại: kỳ đầu cao nhất rồi giảm dần. Kiểu vay ngân hàng phổ biến ở Việt Nam.")
        case "REDUCING_BALANCE":
            return T("Mỗi kỳ trả MỘT số tiền bằng nhau; bên trong, lãi tính trên dư nợ giảm dần nên phần gốc tăng dần.")
        case "FLAT_MONTHLY":
            return T("Lãi tính trên GỐC BAN ĐẦU suốt kỳ hạn, dù đã trả bớt — lãi suất thực cao gần gấp đôi con số quảng cáo.")
        case "INTEREST_ONLY":
            return T("Mỗi tháng chỉ trả lãi; toàn bộ gốc trả ở kỳ cuối.")
        case "DAILY_PERCENT":
            return T("Lãi tính theo ngày trên dư nợ (app vay, ví trả sau).")
        default:
            return T("Chỉ trả gốc, chia đều các kỳ.")
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
            "currency": tienTe,
            "interestType": kieuLai,
            "interestRate": lai,
            "startDate": ngayBatDau,
            "termMonths": soThang,
            "paymentDay": ngayTraTrongThang,
        ]
        if kieuLai != "NO_INTEREST" { m["rateUnit"] = laLaiNgay ? "DAY" : donViLai }
        if !phiChu.isEmpty, let p = phi { m["prepayFeePct"] = p }
        if !ghiChu.isEmpty { m["note"] = ghiChu }
        do {
            _ = try await TienAPI.themNo(m)
            await vm.napNo()
            await vm.sauKhiGhiTien()
            dong()
        } catch {
            loi = error.localizedDescription
        }
    }
}

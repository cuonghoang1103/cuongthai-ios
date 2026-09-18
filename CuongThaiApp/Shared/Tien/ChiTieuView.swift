import SwiftUI

// MARK: - Danh sách chi tiêu

struct ChiTieuView: View {
    @ObservedObject var vm: TienVM
    @State private var moGhi = false
    @State private var dangSua: KhoanChi?
    @State private var daNap = false

    var body: some View {
        List {
            Section {
                ChonNhomChi(dsNhom: vm.dsNhom, nhomId: $vm.locNhomId, choPhepTatCa: true)
                    .listRowInsets(EdgeInsets(top: 6, leading: Spacing.md, bottom: 6, trailing: Spacing.md))
            }
            .listRowBackground(Color.clear)

            if vm.dsChi.isEmpty {
                Section {
                    KhungTrongTien(bieuTuong: "cart", tieuDe: T("Chưa có khoản chi nào"),
                                   moTa: T("Ghi khoản đầu tiên của \(NgayTien.tenThang(vm.thang).lowercased())"),
                                   tenNut: T("Ghi khoản chi")) { moGhi = true }
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(theoNgay, id: \.0) { ngay, khoan in
                    Section {
                        ForEach(khoan) { k in
                            Button { dangSua = k } label: { dongChi(k) }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await vm.xoaChi(id: k.id) }
                                    } label: { Label(T("Xoá"), systemImage: "trash") }
                                }
                        }
                    } header: {
                        HStack {
                            Text(NgayTien.ngayDay(ngay))
                            Spacer()
                            Text(DinhDangTien.day(khoan.reduce(0) { $0 + $1.amount }))
                                .foregroundStyle(AppColors.error)
                        }
                        .font(.captionBold)
                    }
                }

                if vm.conTrangChi {
                    Section {
                        Button { Task { await vm.taiThemChi() } } label: {
                            HStack { Spacer(); Text(T("Tải thêm")).font(.bodyMedium); Spacer() }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Chi tiêu"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { moGhi = true } label: { Image(systemName: "plus") }
            }
        }
        .task {
            guard !daNap else { return }
            daNap = true
            await vm.napChi()
        }
        // `.onChange` chứ không `.task(id:)`: bộ lọc nhóm đổi SAU khi màn đã
        // dựng, và `.task(id:)` sẽ chạy thêm một lượt nạp thừa ngay lúc mở.
        .onChange(of: vm.locNhomId) { _, _ in Task { await vm.napChi() } }
        .refreshable { await vm.napChi() }
        .sheet(isPresented: $moGhi) { GhiChiView(vm: vm, sua: nil) }
        .sheet(item: $dangSua) { k in GhiChiView(vm: vm, sua: k) }
    }

    /// Gom theo ngày. Backend đã sắp `date desc, id desc`, nên chỉ cần giữ
    /// nguyên thứ tự gặp — sort lại bằng chuỗi ngày là đủ và ổn định.
    private var theoNgay: [(String, [KhoanChi])] {
        var thu: [String: [KhoanChi]] = [:]
        var thuTu: [String] = []
        for k in vm.dsChi {
            let ngay = String(k.date.prefix(10))
            if thu[ngay] == nil { thu[ngay] = []; thuTu.append(ngay) }
            thu[ngay]?.append(k)
        }
        return thuTu.map { ($0, thu[$0] ?? []) }
    }

    private func dongChi(_ k: KhoanChi) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(k.category?.bieuTuong ?? "🏷️").font(.titleMedium)
            VStack(alignment: .leading, spacing: 1) {
                Text(k.category?.name ?? T("Chưa phân nhóm"))
                    .font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                if let d = k.description, !d.isEmpty {
                    Text(d).font(.caption).foregroundStyle(AppColors.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text("−" + DinhDangTien.day(k.amount, k.currency))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.error)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Ghi / sửa khoản chi

struct GhiChiView: View {
    @ObservedObject var vm: TienVM
    let sua: KhoanChi?
    @Environment(\.dismiss) private var dong

    @State private var soTienChu = ""
    @State private var nhomId: Int?
    @State private var viId: Int?
    @State private var ngay = NgayTien.homNay()
    @State private var moTa = ""
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ONhapTien(nhan: T("Số tiền"), chu: $soTienChu)
                }
                Section {
                    if vm.dsNhom.isEmpty {
                        Text(T("Chưa có nhóm chi nào. Vào Ví › Nhóm chi tiêu để tạo."))
                            .font(.caption).foregroundStyle(AppColors.warning)
                    } else {
                        ChonNhomChi(dsNhom: vm.dsNhom, nhomId: $nhomId)
                    }
                    if vm.dsVi.isEmpty {
                        Text(T("Chưa có ví nào. Thêm ví trước khi ghi chi."))
                            .font(.caption).foregroundStyle(AppColors.warning)
                    } else {
                        ChonVi(dsVi: vm.dsVi, viId: $viId)
                    }
                    ChonNgayTien(nhan: T("Ngày"), ngay: $ngay)
                    TextField(T("Ghi chú (không bắt buộc)"), text: $moTa)
                }
            }
            .navigationTitle(sua == nil ? T("Ghi khoản chi") : T("Sửa khoản chi"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Huỷ")) { dong() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }
                        .disabled(!hopLe || dangLuu)
                }
            }
            .task {
                if let s = sua {
                    soTienChu = String(Int(s.amount))
                    nhomId = s.categoryId
                    viId = s.walletId
                    ngay = String(s.date.prefix(10))
                    moTa = s.description ?? ""
                } else {
                    nhomId = vm.dsNhom.first?.id
                    viId = vm.viMacDinh?.id
                }
            }
        }
    }

    private var soTien: Double? {
        guard let v = DinhDangTien.doc(soTienChu), v > 0 else { return nil }
        return v
    }
    private var hopLe: Bool { soTien != nil && nhomId != nil && viId != nil }

    private func luu() async {
        guard let t = soTien, let n = nhomId, let v = viId else { return }
        dangLuu = true
        defer { dangLuu = false }
        let ok: Bool
        if let s = sua {
            ok = await vm.suaChi(id: s.id, nhomId: n, viId: v, soTien: t, ngay: ngay, moTa: moTa)
        } else {
            ok = await vm.themChi(nhomId: n, viId: v, soTien: t, ngay: ngay, moTa: moTa)
        }
        if ok { dong() }
    }
}

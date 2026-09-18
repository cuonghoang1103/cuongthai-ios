import SwiftUI

// MARK: - Ví

struct ViView: View {
    @ObservedObject var vm: TienVM
    @State private var moThem = false
    @State private var dangSua: Vi?
    @State private var moChuyen = false
    @State private var moNhomChi = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text(T("Tổng số dư")).font(.bodyMedium).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(DinhDangTien.day(vm.dsVi.reduce(0) { $0 + $1.balance }))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                }
            }

            if vm.dsVi.isEmpty {
                Section {
                    KhungTrongTien(bieuTuong: "wallet.pass", tieuDe: T("Chưa có ví nào"),
                                   moTa: T("Ví là nơi tiền đi ra đi vào: tiền mặt, ngân hàng, ví điện tử."),
                                   tenNut: T("Thêm ví")) { moThem = true }
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(vm.dsVi) { v in
                        Button { dangSua = v } label: {
                            HStack(spacing: Spacing.sm) {
                                Text(v.bieuTuong).font(.titleLarge)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(v.name).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                                    Text(tenLoai(v.type)).font(.caption).foregroundStyle(AppColors.textTertiary)
                                }
                                Spacer(minLength: 0)
                                Text(DinhDangTien.day(v.balance, v.currency))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(v.balance < 0 ? AppColors.error : AppColors.textPrimary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Button { moChuyen = true } label: {
                        Label(T("Chuyển tiền giữa hai ví"), systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(vm.dsVi.count < 2)
                }
            }

            Section {
                Button { moNhomChi = true } label: {
                    Label(T("Nhóm chi tiêu & ngân sách"), systemImage: "square.grid.2x2")
                }
            } footer: {
                Text(T("Nhóm chi là cách app biết bạn tiêu vào việc gì. Đặt ngân sách tháng cho nhóm nào thì màn Tổng quan theo dõi nhóm đó."))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Ví"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { moThem = true } label: { Image(systemName: "plus") }
            }
        }
        .refreshable { await vm.napDanhMuc() }
        .sheet(isPresented: $moThem) { SuaViView(vm: vm, vi: nil) }
        .sheet(item: $dangSua) { v in SuaViView(vm: vm, vi: v) }
        .sheet(isPresented: $moChuyen) { ChuyenViView(vm: vm) }
        .sheet(isPresented: $moNhomChi) { NhomChiView(vm: vm) }
    }

    private func tenLoai(_ m: String) -> String {
        Vi.tenLoai.first { $0.0 == m }.map { T($0.1) } ?? m
    }
}

struct SuaViView: View {
    @ObservedObject var vm: TienVM
    let vi: Vi?
    @Environment(\.dismiss) private var dong

    @State private var ten = ""
    @State private var loai = "CASH"
    @State private var bieuTuong = ""
    @State private var soDuChu = "0"
    @State private var dangLuu = false
    @State private var loi: String?
    @State private var hoiXoa = false

    private let goiY = ["💵", "🏦", "📱", "💳", "🐷", "👛", "💰", "🪙"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(T("Tên ví"), text: $ten)
                    Picker(T("Loại"), selection: $loai) {
                        ForEach(Vi.tenLoai, id: \.0) { m, t in Text(T(t)).tag(m) }
                    }
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
                if vi == nil {
                    Section {
                        ONhapTien(nhan: T("Số dư ban đầu"), chu: $soDuChu)
                    } footer: {
                        Text(T("Số tiền đang có trong ví này ngay lúc tạo. Sau đó số dư tự đổi theo các khoản thu/chi."))
                    }
                } else {
                    Section {
                        Button(role: .destructive) { hoiXoa = true } label: {
                            Label(T("Xoá ví"), systemImage: "trash")
                        }
                    } footer: {
                        Text(T("Ví đang có giao dịch thì không xoá được — hãy để đó, lịch sử cần nó."))
                    }
                }
                if let l = loi {
                    Section { Text(l).font(.caption).foregroundStyle(AppColors.error) }
                }
            }
            .navigationTitle(vi == nil ? T("Thêm ví") : T("Sửa ví"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty || dangLuu)
                }
            }
            .task {
                if let v = vi {
                    ten = v.name; loai = v.type; bieuTuong = v.icon ?? ""
                }
            }
            .alert(T("Xoá ví này?"), isPresented: $hoiXoa) {
                Button(T("Huỷ"), role: .cancel) {}
                Button(T("Xoá"), role: .destructive) { Task { await xoa() } }
            }
        }
    }

    private func luu() async {
        dangLuu = true
        defer { dangLuu = false }
        do {
            if let v = vi {
                _ = try await TienAPI.suaVi(id: v.id, ten: ten, loai: loai, bieuTuong: bieuTuong)
            } else {
                _ = try await TienAPI.themVi(ten: ten, loai: loai,
                                             soDu: DinhDangTien.doc(soDuChu) ?? 0,
                                             bieuTuong: bieuTuong, tienTe: "VND")
            }
            await vm.napDanhMuc()
            await vm.napBang()
            dong()
        } catch { loi = error.localizedDescription }
    }

    private func xoa() async {
        guard let v = vi else { return }
        do {
            _ = try await TienAPI.xoaVi(id: v.id)
            await vm.napDanhMuc()
            await vm.napBang()
            dong()
        } catch { loi = error.localizedDescription }
    }
}

struct ChuyenViView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.dismiss) private var dong

    @State private var tuId: Int?
    @State private var denId: Int?
    @State private var soTienChu = ""
    @State private var ghiChu = ""
    @State private var dangLuu = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(T("Từ ví")) { ChonVi(dsVi: vm.dsVi, viId: $tuId) }
                Section(T("Sang ví")) { ChonVi(dsVi: vm.dsVi.filter { $0.id != tuId }, viId: $denId) }
                Section {
                    ONhapTien(nhan: T("Số tiền"), chu: $soTienChu)
                    TextField(T("Ghi chú"), text: $ghiChu)
                }
                if let l = loi {
                    Section { Text(l).font(.caption).foregroundStyle(AppColors.error) }
                }
            }
            .navigationTitle(T("Chuyển tiền"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Chuyển")) { Task { await chuyen() } }
                        .disabled(tuId == nil || denId == nil || tuId == denId
                                  || (DinhDangTien.doc(soTienChu) ?? 0) <= 0 || dangLuu)
                }
            }
            .task { tuId = vm.dsVi.first?.id; denId = vm.dsVi.dropFirst().first?.id }
        }
    }

    private func chuyen() async {
        guard let t = tuId, let d = denId, let v = DinhDangTien.doc(soTienChu), v > 0 else { return }
        dangLuu = true
        defer { dangLuu = false }
        do {
            _ = try await TienAPI.chuyenVi(tu: t, den: d, soTien: v, ghiChu: ghiChu)
            await vm.napDanhMuc()
            await vm.napBang()
            dong()
        } catch { loi = error.localizedDescription }
    }
}

// MARK: - Nhóm chi & ngân sách

struct NhomChiView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.dismiss) private var dong
    @State private var dangSua: NhomChi?
    @State private var moThem = false

    var body: some View {
        NavigationStack {
            List {
                if vm.dsNhom.isEmpty {
                    Section {
                        KhungTrongTien(bieuTuong: "square.grid.2x2", tieuDe: T("Chưa có nhóm nào"),
                                       moTa: T("Ăn uống, Đi lại, Học hành…"),
                                       tenNut: T("Thêm nhóm")) { moThem = true }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(vm.dsNhom) { n in
                        Button { dangSua = n } label: {
                            HStack(spacing: Spacing.sm) {
                                Text(n.bieuTuong).font(.titleMedium)
                                Text(n.name).foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                if let ns = n.monthlyBudget, ns > 0 {
                                    Text(DinhDangTien.ngan(ns))
                                        .font(.caption).foregroundStyle(AppColors.textTertiary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    _ = try? await TienAPI.xoaNhomChi(id: n.id)
                                    await vm.napDanhMuc()
                                }
                            } label: { Label(T("Xoá"), systemImage: "trash") }
                        }
                    }
                }
            }
            .navigationTitle(T("Nhóm chi"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { moThem = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $moThem) { SuaNhomChiView(vm: vm, nhom: nil) }
            .sheet(item: $dangSua) { n in SuaNhomChiView(vm: vm, nhom: n) }
        }
    }
}

struct SuaNhomChiView: View {
    @ObservedObject var vm: TienVM
    let nhom: NhomChi?
    @Environment(\.dismiss) private var dong

    @State private var ten = ""
    @State private var bieuTuong = ""
    @State private var nganSachChu = ""
    @State private var dangLuu = false
    @State private var loi: String?

    private let goiY = ["🍜", "🚌", "🏠", "📚", "💊", "🎮", "👕", "☕️", "🎁", "✈️", "💡", "🐶"]

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField(T("Tên nhóm"), text: $ten) }
                Section(T("Biểu tượng")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 46))], spacing: Spacing.sm) {
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
                Section {
                    ONhapTien(nhan: T("Ngân sách mỗi tháng"), chu: $nganSachChu)
                } footer: {
                    Text(T("Để trống nếu nhóm này không cần theo dõi ngân sách."))
                }
                if let l = loi { Section { Text(l).font(.caption).foregroundStyle(AppColors.error) } }
            }
            .navigationTitle(nhom == nil ? T("Thêm nhóm") : T("Sửa nhóm"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty || dangLuu)
                }
            }
            .task {
                if let n = nhom {
                    ten = n.name
                    bieuTuong = n.icon ?? ""
                    if let ns = n.monthlyBudget, ns > 0 { nganSachChu = String(Int(ns)) }
                }
            }
        }
    }

    private func luu() async {
        dangLuu = true
        defer { dangLuu = false }
        let ns = DinhDangTien.doc(nganSachChu)
        do {
            if let n = nhom {
                _ = try await TienAPI.suaNhomChi(id: n.id, ten: ten, bieuTuong: bieuTuong, nganSach: ns)
            } else {
                _ = try await TienAPI.themNhomChi(ten: ten, bieuTuong: bieuTuong, nganSach: ns)
            }
            await vm.napDanhMuc()
            await vm.napBang()
            dong()
        } catch { loi = error.localizedDescription }
    }
}

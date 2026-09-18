import SwiftUI

// MARK: - Thu nhập

struct ThuNhapView: View {
    @ObservedObject var vm: TienVM
    @State private var moGhi = false
    @State private var daNap = false
    @State private var dsNguon: [NguonThu] = []

    var body: some View {
        List {
            Section {
                HStack {
                    Text(T("Tổng thu")).font(.bodyMedium).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(DinhDangTien.day(vm.dsThu.reduce(0) { $0 + $1.amount }))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.success)
                }
            } header: { Text(NgayTien.tenThang(vm.thang)) }

            if vm.dsThu.isEmpty {
                Section {
                    KhungTrongTien(bieuTuong: "briefcase", tieuDe: T("Chưa ghi khoản thu nào"),
                                   moTa: T("Lương, thưởng, tăng ca, freelance…"),
                                   tenNut: T("Ghi khoản thu")) { moGhi = true }
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(vm.dsThu) { t in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(AppColors.success)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tenLoai(t.type)).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                                Text(NgayTien.ngayDay(t.date) + (t.note.map { " · \($0)" } ?? ""))
                                    .font(.caption).foregroundStyle(AppColors.textTertiary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Text("+" + DinhDangTien.day(t.amount, t.currency))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.success)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await vm.xoaThu(id: t.id) }
                            } label: { Label(T("Xoá"), systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Thu nhập"))
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
            await vm.napThu()
            dsNguon = (try? await TienAPI.dsNguonThu()) ?? []
        }
        .refreshable { await vm.napThu() }
        .sheet(isPresented: $moGhi) { GhiThuView(vm: vm, dsNguon: dsNguon) }
    }

    private func tenLoai(_ m: String) -> String {
        KhoanThu.tenLoai.first { $0.0 == m }.map { T($0.1) } ?? m
    }
}

struct GhiThuView: View {
    @ObservedObject var vm: TienVM
    let dsNguon: [NguonThu]
    @Environment(\.dismiss) private var dong

    @State private var soTienChu = ""
    @State private var viId: Int?
    @State private var loai = "SALARY"
    @State private var nguonId: Int?
    @State private var ngay = NgayTien.homNay()
    @State private var ghiChu = ""
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            Form {
                Section { ONhapTien(nhan: T("Số tiền"), chu: $soTienChu) }
                Section {
                    Picker(T("Loại"), selection: $loai) {
                        ForEach(KhoanThu.tenLoai, id: \.0) { m, ten in
                            Text(T(ten)).tag(m)
                        }
                    }
                    if !dsNguon.isEmpty {
                        Picker(T("Nguồn"), selection: $nguonId) {
                            Text(T("Không chọn")).tag(Int?.none)
                            ForEach(dsNguon) { n in Text(n.name).tag(Int?.some(n.id)) }
                        }
                    }
                    if vm.dsVi.isEmpty {
                        Text(T("Chưa có ví nào. Thêm ví trước."))
                            .font(.caption).foregroundStyle(AppColors.warning)
                    } else {
                        ChonVi(dsVi: vm.dsVi, viId: $viId)
                    }
                    ChonNgayTien(nhan: T("Ngày"), ngay: $ngay)
                    TextField(T("Ghi chú (không bắt buộc)"), text: $ghiChu)
                }
            }
            .navigationTitle(T("Ghi khoản thu"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }
                        .disabled(DinhDangTien.doc(soTienChu) ?? 0 <= 0 || viId == nil || dangLuu)
                }
            }
            .task { viId = vm.viMacDinh?.id }
        }
    }

    private func luu() async {
        guard let t = DinhDangTien.doc(soTienChu), t > 0, let v = viId else { return }
        dangLuu = true
        defer { dangLuu = false }
        if await vm.themThu(viId: v, soTien: t, ngay: ngay, loai: loai, nguonId: nguonId, ghiChu: ghiChu) {
            dong()
        }
    }
}

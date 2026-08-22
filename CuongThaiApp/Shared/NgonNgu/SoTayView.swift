import SwiftUI

// MARK: - Bộ nạp

@MainActor
final class SoTayVM: ObservableObject {
    @Published var thuMuc: [ThuMucSoTay] = []
    @Published var muc: [MucSoTayGon] = []
    @Published var dangTai = false
    @Published var loi: String?

    let code: String
    init(code: String) { self.code = code }

    var soToiHan: Int { muc.filter(\.toiHan).count }
    var mucToiHan: [MucSoTayGon] { muc.filter(\.toiHan) }

    func con(_ chaId: Int?) -> [ThuMucSoTay] {
        thuMuc.filter { $0.parentId == chaId }.sorted { $0.sortOrder < $1.sortOrder }
    }
    func mucTrong(_ thuMucId: Int?) -> [MucSoTayGon] {
        muc.filter { $0.folderId == thuMucId }
    }
    /// Đếm CẢ cây con, không chỉ một tầng — thư mục hiện "0 mục" trong khi bên
    /// trong còn thư mục con đầy chữ thì người ta tưởng mình mất dữ liệu.
    func demSau(_ thuMucId: Int) -> Int {
        var tong = mucTrong(thuMucId).count
        for c in con(thuMucId) { tong += demSau(c.id) }
        return tong
    }

    func tai() async {
        dangTai = true; defer { dangTai = false }
        do {
            let cay: CaySoTay = try await APIClient.shared.request(.caySoTay(code: code))
            thuMuc = cay.folders
            muc = cay.entries
            loi = nil
        } catch {
            loi = error.localizedDescription
        }
    }

    func taoThuMuc(_ ten: String, icon: String?, cha: Int?) async {
        do {
            let _: ThuMucSoTay = try await APIClient.shared.request(
                .taoThuMucSoTay(code: code, ten: ten, icon: icon, chaId: cha))
            await tai()
        } catch { loi = error.localizedDescription }
    }

    func xoaThuMuc(_ id: Int) async {
        do {
            struct R: Codable { let id: Int }
            let _: R = try await APIClient.shared.request(.xoaThuMucSoTay(id: id))
            await tai()
        } catch { loi = error.localizedDescription }
    }

    func xoaMuc(_ id: Int) async {
        // Bỏ khỏi danh sách ngay rồi mới gọi mạng; hỏng thì nạp lại nên nó
        // hiện về, chứ không biến mất vĩnh viễn trên màn hình mà còn ở máy chủ.
        let truoc = muc
        muc.removeAll { $0.id == id }
        do {
            struct R: Codable { let id: Int }
            let _: R = try await APIClient.shared.request(.xoaMucSoTay(id: id))
        } catch {
            muc = truoc
            loi = error.localizedDescription
        }
    }
}

// MARK: - Màn hình sổ tay

struct SoTayView: View {
    let ngonNgu: NgonNgu
    /// `nil` = đang ở gốc.
    var thuMucHienTai: ThuMucSoTay?
    @ObservedObject var vm: SoTayVM

    @State private var moTaoThuMuc = false
    @State private var moTaoMuc = false
    @State private var tenMoi = ""

    /// Lối vào từ ngoài: tự dựng bộ nạp cho ngôn ngữ đó.
    init(ngonNgu: NgonNgu) {
        self.ngonNgu = ngonNgu
        self.thuMucHienTai = nil
        self.vm = SoTayVM(code: ngonNgu.code)
    }
    /// Đi sâu vào một thư mục — DÙNG LẠI bộ nạp của tầng trên, không gọi mạng
    /// lại: cả cây đã nằm sẵn trong bộ nhớ từ lần tải đầu.
    init(ngonNgu: NgonNgu, thuMuc: ThuMucSoTay, vm: SoTayVM) {
        self.ngonNgu = ngonNgu
        self.thuMucHienTai = thuMuc
        self.vm = vm
    }

    private var thuMucCon: [ThuMucSoTay] { vm.con(thuMucHienTai?.id) }
    private var mucTrongDay: [MucSoTayGon] { vm.mucTrong(thuMucHienTai?.id) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                if thuMucHienTai == nil, vm.soToiHan > 0 {
                    NavigationLink {
                        OnTapSoTayView(ngonNgu: ngonNgu, vm: vm)
                    } label: {
                        theOnTap(vm.soToiHan)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(thuMucCon) { t in
                    NavigationLink {
                        SoTayView(ngonNgu: ngonNgu, thuMuc: t, vm: vm)
                    } label: {
                        hangThuMuc(t)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await vm.xoaThuMuc(t.id) }
                        } label: { Label("Xoá thư mục", systemImage: "trash") }
                    }
                }

                ForEach(mucTrongDay) { m in
                    NavigationLink {
                        MucSoTayView(ngonNgu: ngonNgu, mucId: m.id, vm: vm)
                    } label: {
                        hangMuc(m)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await vm.xoaMuc(m.id) }
                        } label: { Label("Xoá mục", systemImage: "trash") }
                    }
                }

                if thuMucCon.isEmpty && mucTrongDay.isEmpty && !vm.dangTai {
                    manTrong
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(thuMucHienTai?.name ?? "Sổ tay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { tenMoi = ""; moTaoThuMuc = true } label: {
                        Label("Thư mục mới", systemImage: "folder.badge.plus")
                    }
                    Button { moTaoMuc = true } label: {
                        Label("Mục mới", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Thư mục mới", isPresented: $moTaoThuMuc) {
            TextField("Tên thư mục", text: $tenMoi)
            Button("Huỷ", role: .cancel) { }
            Button("Tạo") {
                let t = tenMoi.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                Task { await vm.taoThuMuc(t, icon: nil, cha: thuMucHienTai?.id) }
            }
        }
        .navigationDestination(isPresented: $moTaoMuc) {
            MucSoTayView(ngonNgu: ngonNgu, mucId: nil, thuMucId: thuMucHienTai?.id, vm: vm)
        }
        .task { if vm.muc.isEmpty && vm.thuMuc.isEmpty { await vm.tai() } }
    }

    // MARK: Các mảnh

    private func theOnTap(_ so: Int) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AppColors.onPrimary)
                .frame(width: 42, height: 42)
                .background(Circle().fill(AppColors.primary))
            VStack(alignment: .leading, spacing: 2) {
                Text("Ôn tập sổ tay")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(so) mục tới hạn")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .strokeBorder(AppColors.primary.opacity(0.35), lineWidth: 1))
        )
    }

    private func hangThuMuc(_ t: ThuMucSoTay) -> some View {
        HStack(spacing: Spacing.md) {
            Text(t.icon ?? "📁").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text("\(vm.demSau(t.id)) mục")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(AppColors.backgroundCard))
    }

    private func hangMuc(_ m: MucSoTayGon) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: m.loai.bieuTuong)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: m.loai.mau))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(hex: m.loai.mau).opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(m.title)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text(m.loai.ten)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: m.loai.mau))
                    if let r = m.reading, !r.isEmpty {
                        Text("· \(r)")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            if m.toiHan {
                Circle().fill(AppColors.primary).frame(width: 7, height: 7)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(AppColors.backgroundCard))
    }

    private var manTrong: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)
            Text(vm.loi ?? (thuMucHienTai == nil
                 ? "Sổ tay còn trống. Bấm + để thêm mục, hoặc bấm \"Lưu vào sổ tay\" ở màn Dịch và Kiểm ngữ pháp."
                 : "Thư mục này chưa có gì."))
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
    }
}

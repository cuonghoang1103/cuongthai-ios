import SwiftUI

/// Kỳ học — để app biết "tuần thứ mấy" và tuần nào là tuần thi.
struct HocKyView: View {
    @ObservedObject var vm: TongQuanVM
    @State private var them = false
    @State private var sua: HocKy?

    var body: some View {
        List {
            if vm.hocKy.isEmpty {
                Section {
                    Text(T("Chưa có kỳ học nào. Thêm một kỳ để bảng tuần hiện “Tuần 3/10” và tô đậm tuần thi."))
                        .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                }
            }
            ForEach(vm.hocKy) { k in
                Button { sua = k } label: { hang(k) }.buttonStyle(.plain)
            }
            .onDelete { idx in
                for i in idx { let k = vm.hocKy[i]; Task { await xoa(k) } }
            }
        }
        .navigationTitle(T("Kỳ học"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { them = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $them) { NavigationStack { SuaHocKyView(vm: vm, ky: nil) } }
        .sheet(item: $sua) { k in NavigationStack { SuaHocKyView(vm: vm, ky: k) } }
        .task { await vm.napHocKy() }
    }

    private func hang(_ k: HocKy) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(k.ten).font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    if k.dangHoc {
                        Text(T("đang học"))
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundColor(AppColors.onPrimary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.primary))
                    }
                }
                Text(String(format: T("Bắt đầu %@ · %d tuần · thi tuần %d"),
                            ngay(k), k.soTuan, k.tuanThi))
                    .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                if let t = k.tuan() {
                    Text(String(format: T("Hiện đang ở tuần %d"), t))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(t == k.tuanThi ? AppColors.error : AppColors.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 3)
    }

    private func ngay(_ k: HocKy) -> String {
        guard let d = k.ngayBatDau else { return String(k.batDau.prefix(10)) }
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"
        return f.string(from: d)
    }

    private func xoa(_ k: HocKy) async {
        do { try await APIClient.shared.send(.xoaHocKy(id: k.id)); await vm.napHocKy() }
        catch { vm.loi = error.localizedDescription }
    }
}

struct SuaHocKyView: View {
    @ObservedObject var vm: TongQuanVM
    let ky: HocKy?
    @Environment(\.dismiss) private var dismiss

    @State private var ten = ""
    @State private var batDau = Date()
    @State private var soTuan = 10
    @State private var tuanThi = 8
    @State private var dangHoc = true
    @State private var dangLuu = false
    @State private var loi: String?

    var body: some View {
        Form {
            Section {
                TextField(T("Tên kỳ — vd Fall 2026"), text: $ten)
                DatePicker(T("Bắt đầu"), selection: $batDau, displayedComponents: .date)
                Stepper(String(format: T("Số tuần: %d"), soTuan), value: $soTuan, in: 1...52)
                Stepper(String(format: T("Tuần thi: %d"), tuanThi), value: $tuanThi, in: 1...soTuan)
                Toggle(T("Đây là kỳ đang học"), isOn: $dangHoc)
            } header: {
                Text(T("Kỳ học"))
            } footer: {
                // Nói rõ hai điều dễ gây bất ngờ.
                Text(T("Ngày bắt đầu được đưa về thứ Hai của tuần đó. Chỉ một kỳ được đánh dấu đang học — đặt kỳ này thì kỳ cũ tự bỏ dấu."))
            }
            if let loi {
                Section { Text(loi).font(.system(size: 13)).foregroundColor(AppColors.error) }
            }
        }
        .navigationTitle(ky == nil ? T("Thêm kỳ học") : T("Sửa kỳ học"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                if dangLuu { ProgressView() }
                else {
                    Button(T("Lưu")) { Task { await luu() } }
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onChange(of: soTuan) { _, m in if tuanThi > m { tuanThi = m } }
        .onAppear {
            guard let k = ky else { return }
            ten = k.ten
            batDau = k.ngayBatDau ?? Date()
            soTuan = k.soTuan; tuanThi = k.tuanThi; dangHoc = k.dangHoc
        }
    }

    private func luu() async {
        dangLuu = true; loi = nil
        defer { dangLuu = false }
        let p: [String: Any] = [
            "ten": ten.trimmingCharacters(in: .whitespaces),
            "batDau": PhamViViec.dinhDang.string(from: batDau),
            "soTuan": soTuan, "tuanThi": tuanThi, "dangHoc": dangHoc,
        ]
        do {
            if let k = ky { try await APIClient.shared.send(.suaHocKy(id: k.id, p)) }
            else { try await APIClient.shared.send(.themHocKy(p)) }
            await vm.napHocKy()
            Haptics.xong()
            dismiss()
        } catch { loi = error.localizedDescription }
    }
}

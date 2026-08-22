import SwiftUI

// MARK: - Bộ nạp

@MainActor
final class CodeLabVM: ObservableObject {
    @Published var bai: [BaiTapCode] = []
    @Published var tong = 0
    @Published var dangTai = false
    @Published var loi: String?

    @Published var doKho: DoKho?
    @Published var ngonNgu: String?
    @Published var tim = ""

    private var trang = 1
    private var hetTrang = false
    private var viecTim: Task<Void, Never>?

    /// Ngôn ngữ hay gặp nhất trong kho. Không gọi API để lấy danh sách vì
    /// backend không có route đó — và đây là bộ lọc, sai vài mục không chết.
    static let dsNgonNgu = ["python", "javascript", "typescript", "java", "c", "cpp", "csharp", "go", "sql"]

    func nap(lai: Bool) async {
        if lai { trang = 1; hetTrang = false }
        guard !dangTai, !(hetTrang && !lai) else { return }
        dangTai = true; defer { dangTai = false }
        do {
            let t: TrangBaiTapCode = try await APIClient.shared.request(
                .dsBaiTapCode(nhom: nil, doKho: doKho?.rawValue, ngonNgu: ngonNgu,
                              tim: tim.trimmingCharacters(in: .whitespaces), trang: trang))
            if lai { bai = t.exercises } else { bai += t.exercises }
            tong = t.total
            hetTrang = t.page >= t.totalPages
            trang += 1
            loi = bai.isEmpty ? "Không tìm thấy bài nào khớp." : nil
        } catch {
            loi = error.localizedDescription
        }
    }

    /// Gõ tới đâu tìm tới đó, nhưng CHỜ 350ms: mỗi lượt tìm là một trang
    /// ~296KB, bắn theo từng phím là đốt băng thông của người dùng.
    func timLai() {
        viecTim?.cancel()
        viecTim = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.nap(lai: true)
        }
    }
}

// MARK: - Danh sách

struct CodeLabView: View {
    @StateObject private var vm = CodeLabVM()

    var body: some View {
        VStack(spacing: 0) {
            oTim
            boLoc
            if vm.dangTai && vm.bai.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.bai.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 40)).foregroundColor(AppColors.textTertiary)
                    Text(vm.loi ?? "Chưa có bài nào.")
                        .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        Text("\(vm.tong) bài")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(vm.bai) { b in
                            NavigationLink { BaiTapCodeView(bai: b) } label: { hang(b) }
                                .buttonStyle(.plain)
                                .onAppear {
                                    // Nạp thêm khi chạm bài GẦN CUỐI, không
                                    // phải bài cuối: chạm bài cuối rồi mới nạp
                                    // là người dùng thấy khựng một nhịp.
                                    if b.id == vm.bai.suffix(4).first?.id {
                                        Task { await vm.nap(lai: false) }
                                    }
                                }
                        }
                        if vm.dangTai { ProgressView().padding(.vertical, Spacing.md) }
                    }
                    .padding(Spacing.md)
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Code Lab")
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.bai.isEmpty { await vm.nap(lai: true) } }
    }

    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
            TextField("Tìm bài tập", text: $vm.tim)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: vm.tim) { _, _ in vm.timLai() }
            if !vm.tim.isEmpty {
                Button { vm.tim = ""; vm.timLai() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.sm + 2)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
    }

    private var boLoc: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(DoKho.allCases, id: \.rawValue) { k in
                    vien(k.ten, mau: k.mau, chon: vm.doKho == k) {
                        vm.doKho = vm.doKho == k ? nil : k
                        Task { await vm.nap(lai: true) }
                    }
                }
                Divider().frame(height: 18)
                ForEach(CodeLabVM.dsNgonNgu, id: \.self) { n in
                    vien(n, mau: 0x64748B, chon: vm.ngonNgu == n) {
                        vm.ngonNgu = vm.ngonNgu == n ? nil : n
                        Task { await vm.nap(lai: true) }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.vertical, Spacing.sm)
    }

    private func vien(_ chu: String, mau: UInt32, chon: Bool, _ bam: @escaping () -> Void) -> some View {
        Button(action: bam) {
            Text(chu)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(chon ? AppColors.onPrimary : Color(hex: mau))
                .padding(.horizontal, Spacing.sm + 2)
                .padding(.vertical, 6)
                .background(Capsule().fill(chon ? Color(hex: mau) : Color(hex: mau).opacity(0.14)))
        }
        .buttonStyle(.plain)
    }

    private func hang(_ b: BaiTapCode) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(b.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2).multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.sm) {
                Text(b.doKho.ten)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: b.doKho.mau))
                    .padding(.horizontal, Spacing.sm).padding(.vertical, 2)
                    .background(Capsule().fill(Color(hex: b.doKho.mau).opacity(0.15)))
                if let l = b.language {
                    Text(l).font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
                if b.phut > 0 {
                    Text("· \(b.phut)′").font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
                if let s = b.solveCount, s > 0 {
                    Text("· \(s) lượt giải").font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}

// MARK: - Lối vào từ tab Học

struct CodeLabEntryCard: View {
    var body: some View {
        NavigationLink { CodeLabView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x1E293B), Color(hex: 0x475569)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Code Lab")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    // Số đo thật, không phải câu quảng cáo: nói ngay kho lớn
                    // cỡ nào để người ta biết có đáng mở không.
                    Text("12.549 bài tập · 9 ngôn ngữ · lọc theo độ khó")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(AppColors.backgroundCard)
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .strokeBorder(AppColors.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Bộ nạp

@MainActor
final class SnippetVM: ObservableObject {
    @Published var ds: [Snippet] = []
    @Published var danhMuc: [DanhMucSnippet] = []
    @Published var chonDanhMuc: Int?
    @Published var tim = ""
    @Published var dangTai = false
    @Published var loi: String?

    private var trang = 1
    private var het = false
    private var viecTim: Task<Void, Never>?
    private let moiTrang = 20

    func nap(lai: Bool) async {
        if lai { trang = 1; het = false }
        guard !dangTai, !(het && !lai) else { return }
        dangTai = true; defer { dangTai = false }
        do {
            let t: [Snippet] = try await APIClient.shared.request(
                .dsSnippet(danhMuc: chonDanhMuc, ngonNgu: nil,
                           tim: tim.trimmingCharacters(in: .whitespaces), trang: trang))
            if lai { ds = t } else { ds += t }
            // `pagination` nằm ngoài `data` nên `APIResponse` không lấy được:
            // suy hết trang bằng "trang này trả về ÍT hơn số yêu cầu".
            het = t.count < moiTrang
            trang += 1
            loi = ds.isEmpty ? "Không tìm thấy mẩu nào." : nil
        } catch { loi = error.localizedDescription }

        if danhMuc.isEmpty,
           let dm: [DanhMucSnippet] = try? await APIClient.shared.request(.dsDanhMucSnippet) {
            // Chỉ giữ danh mục THỰC SỰ có mẩu, sắp theo số lượng giảm dần.
            // Đo thật: 20 danh mục nhưng chỉ 4 có nội dung — lọc theo
            // `parentId` (như bản đầu tôi viết) giữ nguyên cả 20, tức 16 nút
            // bấm vào ra trống.
            danhMuc = dm.filter { $0.soMau > 0 }.sorted { $0.soMau > $1.soMau }
        }
    }

    func timLai() {
        viecTim?.cancel()
        viecTim = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.nap(lai: true)
        }
    }
}

// MARK: - Danh sách

struct SnippetsView: View {
    @StateObject private var vm = SnippetVM()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
                TextField("Tìm mẩu mã, lệnh cài đặt…", text: $vm.tim)
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

            if !vm.danhMuc.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(vm.danhMuc) { d in
                            Button {
                                vm.chonDanhMuc = vm.chonDanhMuc == d.id ? nil : d.id
                                Task { await vm.nap(lai: true) }
                            } label: {
                                Text("\(d.name) \(d.soMau)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .foregroundColor(vm.chonDanhMuc == d.id ? AppColors.onPrimary : AppColors.textSecondary)
                                    .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 6)
                                    .background(Capsule().fill(vm.chonDanhMuc == d.id
                                                               ? AppColors.primary : AppColors.backgroundTertiary))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .padding(.vertical, Spacing.sm)
            }

            if vm.dangTai && vm.ds.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.ds.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "curlybraces").font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)
                    Text(vm.loi ?? "Chưa có mẩu nào.")
                        .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(vm.ds) { s in
                            NavigationLink { SnippetChiTietView(mau: s) } label: { hang(s) }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if s.id == vm.ds.suffix(4).first?.id {
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
        .navigationTitle("Mẩu mã")
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.ds.isEmpty { await vm.nap(lai: true) } }
    }

    private func hang(_ s: Snippet) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(s.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2).multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if let d = s.description, !d.isEmpty {
                Text(d)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            HStack(spacing: Spacing.sm) {
                if let l = s.language, !l.isEmpty {
                    Text(l)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, Spacing.sm).padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.primary.opacity(0.14)))
                }
                if s.cacKhoi.count > 1 {
                    Text("\(s.cacKhoi.count) khối mã")
                        .font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
                if let c = s.copyCount, c > 0 {
                    Text("· \(c) lượt chép").font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}

// MARK: - Chi tiết

struct SnippetChiTietView: View {
    let mau: Snippet
    @State private var vuaChep: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(mau.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let d = mau.description, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(mau.cacKhoi) { k in khoi(k) }

                if let e = mau.explanation, !e.isEmpty { doanChu("GIẢI THÍCH", e) }
                if let n = mau.noteContent, !n.isEmpty { doanChu("GHI CHÚ", n) }

                if let t = mau.tagNames, !t.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(t, id: \.self) { x in
                                Text(x).font(.system(size: 11))
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
                                    .background(Capsule().fill(AppColors.backgroundTertiary))
                            }
                        }
                    }
                }
                Spacer(minLength: Spacing.xl)
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(mau.tenDanhMuc)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Nội dung có thể là HTML (mẩu soạn trên web) hoặc chữ thuần. Dò bằng
    /// thẻ mở đầu — đưa HTML thô vào `Text` thì người đọc thấy đầy `<p>`.
    private func doanChu(_ ten: String, _ chu: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ten).font(.system(size: 10, weight: .bold)).kerning(0.5)
                .foregroundColor(AppColors.textTertiary)
            if chu.contains("<p") || chu.contains("<ul") || chu.contains("<h") {
                RichContent(html: chu)
            } else {
                Text(chu).font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func khoi(_ k: Snippet.KhoiMa) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                if let n = k.name ?? k.language, !n.isEmpty {
                    Text(n).font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                Spacer()
                Button { chep(k) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: vuaChep == k.id ? "checkmark" : "doc.on.doc")
                        Text(vuaChep == k.id ? "Đã chép" : "Chép")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(vuaChep == k.id ? AppColors.success : AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(k.code ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                    .textSelection(.enabled)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.small).fill(AppColors.backgroundTertiary))
        }
    }

    private func chep(_ k: Snippet.KhoiMa) {
        #if os(iOS)
        UIPasteboard.general.string = k.code ?? ""
        #endif
        withAnimation { vuaChep = k.id }
        // Ghi nhận lượt chép để số "lượt chép" trên web phản ánh cả người dùng
        // app. Hỏng thì kệ — không được để một lời gọi thống kê chắn việc chép.
        Task { _ = try? await APIClient.shared.send(.ghiNhanChep(id: mau.id)) }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run { if vuaChep == k.id { vuaChep = nil } }
        }
    }
}

// MARK: - Lối vào từ tab Học

struct SnippetEntryCard: View {
    var body: some View {
        NavigationLink { SnippetsView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x7A45E8), Color(hex: 0xA78BFA)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mẩu mã")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Lệnh cài môi trường, chép một chạm")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.85)
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
                        .strokeBorder(Color(hex: 0x7A45E8).opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

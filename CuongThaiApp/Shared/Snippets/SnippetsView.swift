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
            loi = ds.isEmpty ? T("Không tìm thấy snippet nào.") : nil
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
                TextField(T("Tìm snippet, lệnh cài đặt…"), text: $vm.tim)
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
                        the(nhan: T("Tất cả"), chon: vm.chonDanhMuc == nil) {
                            vm.chonDanhMuc = nil
                            Task { await vm.nap(lai: true) }
                        }
                        ForEach(vm.danhMuc) { d in
                            the(nhan: DanhMucSnippet.tenGon(d.name),
                                chon: vm.chonDanhMuc == d.id) {
                                vm.chonDanhMuc = vm.chonDanhMuc == d.id ? nil : d.id
                                Task { await vm.nap(lai: true) }
                            }
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
                    Text(vm.loi ?? T("Chưa có snippet nào."))
                        .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { cuon in
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        NeoDauTrang()
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
                        // Thanh tab nổi che mất thẻ cuối — chừa chỗ cho nó.
                        Color.clear.frame(height: 72)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                }
                // Ô tìm và hàng thẻ danh mục GHIM phía trên vùng cuộn, nên
                // đổi danh mục hay gõ tìm lúc đang cuộn sâu là danh sách mới
                // mở ra ở giữa chừng. Bám vào `id` bài ĐẦU TIÊN chứ không bám
                // vào ô lọc: `nap(lai:)` chạy bất đồng bộ, nghe theo ô lọc là
                // cuộn xong rồi danh sách cũ mới bị thay.
                .onChange(of: vm.ds.first?.id) { _, _ in cuon.veDauTrang() }
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Snippets")
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.ds.isEmpty { await vm.nap(lai: true) } }
    }

    /// Thẻ lọc danh mục.
    ///
    /// ⚠️ KHÔNG hiện số đếm. `_count.snippets` của máy chủ SAI: đo 28/08/2026
    /// nó báo Lab211 = 3 trong khi gọi `?categoryId=1` chỉ trả về **1**, và
    /// tổng cộng lại thành 53 trong khi danh sách thật có **51**. Một con số
    /// sai ngay trên nút lọc — bấm "3" ra 1 mẩu — đọc như app hỏng, tệ hơn
    /// hẳn so với không có số. App cũng không tự đếm được: `pagination` nằm
    /// ngoài `data` nên `APIResponse` không lấy tới.
    ///
    /// ⚠️ Tên đầy đủ dài cỡ "FPTU — Cài đặt môi trường học": để nguyên thì MỘT
    /// thẻ chiếm gần hết bề ngang và đẩy các thẻ còn lại ra ngoài mép phải,
    /// người dùng không biết là còn thẻ để cuộn tới. Xem `DanhMucSnippet.tenGon`.
    private func the(nhan: String, chon: Bool, lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Text(nhan)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(chon ? AppColors.onPrimary : AppColors.textSecondary)
                .padding(.horizontal, Spacing.sm + 4)
                .padding(.vertical, 6)
                .background(Capsule().fill(chon ? AppColors.primary : AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
    }

    private func hang(_ s: Snippet) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm + 2) {
            // Neo thị giác. 51 mẩu mà thẻ nào cũng chữ trắng trên nền xám thì
            // không quét mắt được — một ô màu theo ngôn ngữ là nhận ra ngay.
            VStack(spacing: 3) {
                Text(NgonNguMa.nhan(s.ngonNguHien))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(NgonNguMa.mau(s.ngonNguHien))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(NgonNguMa.mau(s.ngonNguHien).opacity(0.15)))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(NgonNguMa.mau(s.ngonNguHien).opacity(0.35), lineWidth: 1))
                if s.cacKhoi.count > 1 {
                    Text("\(s.cacKhoi.count)×")
                        .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                if let c = s.category?.name, !c.isEmpty {
                    Text(DanhMucSnippet.tenGon(c).uppercased())
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.6)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }
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
                        .padding(.top, 1)
                }
                if let tags = s.tagNames, !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(3), id: \.self) { t in
                            Text(t)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 5)
                                    .fill(AppColors.backgroundTertiary))
                        }
                        if tags.count > 3 {
                            Text("+\(tags.count - 3)")
                                .font(.system(size: 9.5)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(.top, 3)
                }
                soLieu(s)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
                .overlay(alignment: .leading) {
                    // Vạch màu ngôn ngữ chạy dọc mép trái — web dùng
                    // `border-l-2`, giữ cùng ngôn ngữ thị giác.
                    UnevenRoundedRectangle(topLeadingRadius: CornerRadius.large,
                                           bottomLeadingRadius: CornerRadius.large)
                        .fill(NgonNguMa.mau(s.ngonNguHien).opacity(0.55))
                        .frame(width: 3)
                }
        )
    }

    /// Hàng số liệu — web có, app trước đây bỏ hết trừ lượt chép.
    @ViewBuilder private func soLieu(_ s: Snippet) -> some View {
        let muc: [(String, Int)] = [
            ("doc.on.doc", s.copyCount ?? 0),
            ("eye", s.viewCount ?? 0),
            ("heart", s.upvoteCount ?? 0),
            ("bubble.left", s.commentCount ?? 0),
        ].filter { $0.1 > 0 }
        if !muc.isEmpty {
            HStack(spacing: 10) {
                ForEach(muc, id: \.0) { m in
                    HStack(spacing: 3) {
                        Image(systemName: m.0).font(.system(size: 9))
                        Text("\(m.1)").font(.system(size: 10).monospacedDigit())
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.top, 5)
        }
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
            // ⚠️ `.fixedSize(horizontal: true, …)` là BẮT BUỘC. Không có nó
            // thì `Text` vẫn nhận bề rộng khung đề xuất và tự CẮT CỤT dòng
            // dài — `ScrollView(.horizontal)` bọc ngoài chẳng có gì để cuộn
            // tới, nhìn y như đã cuộn được. Với trang toàn lệnh cài đặt thì
            // đó là mất luôn nội dung: dòng
            //   `curl -o- https://raw.githubusercontent.com/nvm-sh/...`
            // hiện ra cụt ở giữa URL.
            ScrollView(.horizontal, showsIndicators: true) {
                Text(k.code ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.trailing, Spacing.sm)
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
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x7A45E8), Color(hex: 0xA78BFA)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Snippets")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(T("Lệnh cài môi trường, chép một chạm"))
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

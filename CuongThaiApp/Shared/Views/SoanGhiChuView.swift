import SwiftUI

/// Soạn ghi chú bằng Markdown.
///
/// ⚠️ Lưu PHẢI gửi CẢ `contentJson` lẫn `contentHtml`. Trình soạn của web nạp
/// `contentJson`; chỉ gửi HTML thì API trả 200, tìm kiếm vẫn thấy, mà mở ghi
/// chú trên web ra là **TRẮNG TINH**. Không có lỗi ở tầng nào để mà thấy.
///
/// Cố ý dùng Markdown thay vì trình soạn giàu định dạng: trình soạn thật của
/// web là TipTap chạy trong trình duyệt: muốn có trên iOS phải nhúng cả nó vào
/// WKWebView. Markdown thì chuyển qua lại được, ổn định qua nhiều lần mở-lưu
/// (đã đo), và gõ trên điện thoại cũng nhanh.
struct SoanGhiChuView: View {
    let ghiChu: Note
    let luuXong: (Note) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tieuDe: String
    @State private var than: String
    @State private var dangLuu = false
    @State private var loi: String?
    @State private var hienXemTruoc = false
    @FocusState private var dangGoThan: Bool

    init(ghiChu: Note, luuXong: @escaping (Note) -> Void) {
        self.ghiChu = ghiChu
        self.luuXong = luuXong
        _tieuDe = State(initialValue: ghiChu.title)
        _than = State(initialValue: TiptapSangMarkdown.chuyen(anyCodable: ghiChu.contentJson))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Tiêu đề", text: $tieuDe)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.sm)

                Divider().background(AppColors.divider)

                if hienXemTruoc {
                    ScrollView {
                        RichContent(html: MarkdownSangTiptap.chuyen(than).html)
                            .padding(Spacing.md)
                    }
                } else {
                    TextEditor(text: $than)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(AppColors.backgroundPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .focused($dangGoThan)

                    thanhCongCu
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(hienXemTruoc ? "Xem trước" : "Soạn")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: Spacing.md) {
                        Button {
                            dangGoThan = false
                            withAnimation { hienXemTruoc.toggle() }
                        } label: {
                            Image(systemName: hienXemTruoc ? "pencil" : "eye")
                        }
                        Button {
                            Task { await luu() }
                        } label: {
                            if dangLuu { ProgressView() } else { Text("Lưu").fontWeight(.semibold) }
                        }
                        .disabled(dangLuu)
                    }
                }
            }
            .alert("Lưu ghi chú", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: { Text(loi ?? "") }
        }
    }

    /// Hàng nút chèn cú pháp — trên điện thoại không ai muốn gõ tay `**`.
    private var thanhCongCu: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                nut("Tiêu đề", "textformat.size") { chen("## ", dauDong: true) }
                nut("Đậm", "bold") { bocChon("**") }
                nut("Nghiêng", "italic") { bocChon("*") }
                nut("Mã", "chevron.left.forwardslash.chevron.right") { bocChon("`") }
                nut("Gạch đầu dòng", "list.bullet") { chen("- ", dauDong: true) }
                nut("Đánh số", "list.number") { chen("1. ", dauDong: true) }
                nut("Trích", "text.quote") { chen("> ", dauDong: true) }
                nut("Khối mã", "curlybraces") { chen("\n```\n\n```\n") }
                nut("Kẻ ngang", "minus") { chen("\n---\n") }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 7)
        }
        .background(AppColors.backgroundSecondary)
    }

    private func nut(_ ten: String, _ icon: String, _ cham: @escaping () -> Void) -> some View {
        Button(action: cham) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AppColors.primary)
                .frame(width: 38, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ten)
    }

    private func chen(_ chu: String, dauDong: Bool = false) {
        if dauDong && !than.isEmpty && !than.hasSuffix("\n") { than += "\n" }
        than += chu
        dangGoThan = true
    }

    /// Không đọc được vùng chọn của `TextEditor` từ SwiftUI, nên chèn cặp dấu ở
    /// CUỐI rồi để con trỏ vào giữa — vẫn nhanh hơn gõ tay bốn dấu sao.
    private func bocChon(_ dau: String) {
        than += "\(dau)\(dau)"
        dangGoThan = true
    }

    private func luu() async {
        dangLuu = true
        defer { dangLuu = false }
        let kq = MarkdownSangTiptap.chuyen(than)
        do {
            let moi: Note = try await APIClient.shared.request(.updateNote(id: ghiChu.id, [
                "title": tieuDe.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : tieuDe,
                // CẢ HAI. Xem chú thích đầu file.
                "contentJson": kq.json,
                "contentHtml": kq.html,
            ]))
            Haptics.xong()
            luuXong(moi)
            dismiss()
        } catch {
            loi = error.localizedDescription
        }
    }
}

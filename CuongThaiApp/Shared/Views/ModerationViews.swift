import SwiftUI

// MARK: - Report sheet (App Store Guideline 1.2)

struct ReportSheet: View {
    enum Target: Identifiable {
        case post(id: Int, authorId: Int, authorName: String)
        case comment(postId: Int, commentId: Int, authorName: String)

        // Two `.sheet` modifiers on one view fight over the presentation slot
        // in SwiftUI — every screen here presents ONE `.sheet(item:)` instead.
        var id: String {
            switch self {
            case .post(let id, _, _): return "post-\(id)"
            case .comment(_, let commentId, _): return "comment-\(commentId)"
            }
        }

        var title: String {
            switch self {
            case .post: return "Báo cáo bài viết"
            case .comment: return "Báo cáo bình luận"
            }
        }

        var authorName: String {
            switch self {
            case .post(_, _, let name), .comment(_, _, let name): return name
            }
        }
    }

    let target: Target
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var moderation = ModerationStore.shared

    @State private var reason: ReportReason = .harassment
    @State private var details = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var didSend = false
    @State private var alsoBlockAuthor = false

    var body: some View {
        NavigationStack {
            Form {
                if didSend {
                    Section {
                        Label("Đã gửi báo cáo", systemImage: "checkmark.seal.fill")
                            .foregroundColor(AppColors.success)
                        Text("Đội kiểm duyệt sẽ xem xét trong vòng 24 giờ. Nội dung này đã được ẩn khỏi màn hình của bạn.")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                } else {
                    Section("Lý do") {
                        Picker("Lý do", selection: $reason) {
                            ForEach(ReportReason.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Section("Mô tả thêm (không bắt buộc)") {
                        TextField("Điều gì khiến bạn thấy nội dung này vi phạm?", text: $details, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    if case .post(_, let authorId, let name) = target, authorId > 0 {
                        Section {
                            Toggle("Chặn luôn \(name)", isOn: $alsoBlockAuthor)
                        } footer: {
                            Text("Chặn sẽ ẩn toàn bộ bài viết của người này và chặn họ nhắn tin cho bạn.")
                        }
                    }

                    if let errorMessage {
                        Section { Text(errorMessage).foregroundColor(AppColors.error) }
                    }

                    Section {
                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSending { ProgressView() } else { Text("Gửi báo cáo") }
                                Spacer()
                            }
                        }
                        .disabled(isSending)
                    }
                }
            }
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(didSend ? "Xong" : "Huỷ") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        isSending = true
        errorMessage = nil
        do {
            switch target {
            case .post(let id, let authorId, _):
                try await moderation.report(postId: id, reason: reason, details: details)
                if alsoBlockAuthor, authorId > 0 {
                    try await moderation.block(userId: authorId, reason: reason.rawValue)
                }
            case .comment(let postId, let commentId, _):
                try await moderation.reportComment(
                    postId: postId, commentId: commentId, reason: reason, details: details
                )
            }
            didSend = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}

// MARK: - The ••• menu shown on every post

struct PostModerationMenu: View {
    let post: SocialPost
    /// Gọi lại khi bài bị XOÁ — nơi gọi phải bỏ nó khỏi danh sách, không thì
    /// bài đã xoá vẫn nằm đó tới lần tải lại.
    var daXoa: (() -> Void)? = nil
    /// Tự suy ra thay vì bắt mỗi nơi gọi phải truyền — HomeView quên truyền
    /// nên "Báo cáo" và "Chặn <chính mình>" hiện trên bài của chính người
    /// dùng. Vô lý, và chặn chính mình thì backend cũng từ chối.
    private var laBaiCuaMinh: Bool {
        post.author.id == AppState.shared.currentUser?.id
    }

    @ObservedObject private var moderation = ModerationStore.shared
    @State private var showReport = false
    @State private var showBlockConfirm = false
    @State private var daLuu: Bool
    @State private var hoiXoa = false
    @State private var hienSuaBai = false
    @State private var daGhim = false
    @State private var quyen: String
    @State private var loi: String?

    init(post: SocialPost, daXoa: (() -> Void)? = nil) {
        self.post = post
        self.daXoa = daXoa
        _daLuu = State(initialValue: post.isSaved)
        _quyen = State(initialValue: post.visibility)
    }

    private static let cacQuyen: [(String, String, String)] = [
        ("PUBLIC",  "Công khai", "globe"),
        ("FRIENDS", "Bạn bè",    "person.2"),
        ("PRIVATE", "Chỉ mình tôi", "lock"),
    ]

    private var tenQuyen: String {
        Self.cacQuyen.first { $0.0 == quyen }?.1 ?? "Công khai"
    }
    private var bieuTuongQuyen: String {
        Self.cacQuyen.first { $0.0 == quyen }?.2 ?? "globe"
    }

    private func doiGhim() async {
        Haptics.cham()
        do {
            // Máy chủ trả `{ pinned: Bool }` — trạng thái SAU khi đảo. Đọc từ
            // đó chứ không tự lật cờ ở client: mỗi người chỉ ghim được MỘT
            // bài, nên ghim bài này có thể đã bỏ ghim bài khác.
            struct KetQua: Decodable { let pinned: Bool }
            let kq: KetQua = try await APIClient.shared.request(.ghimBaiViet(id: post.id))
            daGhim = kq.pinned
        } catch { loi = error.localizedDescription; Haptics.hong() }
    }

    private func doiQuyen(_ moi: String) async {
        let cu = quyen
        quyen = moi
        Haptics.cham()
        do {
            let _: SocialPost = try await APIClient.shared
                .request(.suaBaiViet(id: post.id, ["visibility": moi]))
        } catch {
            quyen = cu
            loi = error.localizedDescription
            Haptics.hong()
        }
    }

    private func xoa() async {
        do {
            let _: EmptyResponse = try await APIClient.shared.request(.xoaBaiViet(id: post.id))
            Haptics.xong()
            daXoa?()
        } catch { loi = error.localizedDescription; Haptics.hong() }
    }

    /// Đổi trạng thái lưu. Đổi trên máy trước cho tay bấm thấy phản hồi ngay,
    /// hỏng thì trả lại.
    private func doiLuu() async {
        let muon = !daLuu
        daLuu = muon
        Haptics.cham()
        do {
            try await APIClient.shared.send(
                muon ? .savePost(id: post.id, folder: nil) : .unsavePost(id: post.id),
            )
        } catch {
            daLuu = !muon
            Haptics.hong()
        }
    }

    var body: some View {
        Menu {
            // "Lưu" phải nằm ở ĐÂY. Trước đây nó chỉ có trong màn chi tiết bài,
            // nên tab "Đã lưu" ở hồ sơ hướng dẫn người dùng "chạm ••• rồi chọn
            // Lưu" — một chỉ dẫn không thực hiện được từ bảng tin.
            Button {
                Task { await doiLuu() }
            } label: {
                Label(daLuu ? "Bỏ lưu" : "Lưu bài viết",
                      systemImage: daLuu ? "bookmark.fill" : "bookmark")
            }

            Button {
                moderation.hide(postId: post.id)
            } label: {
                Label("Ẩn bài viết này", systemImage: "eye.slash")
            }

            if laBaiCuaMinh {
                Divider()

                Button { Task { await doiGhim() } } label: {
                    Label(daGhim ? "Bỏ ghim khỏi hồ sơ" : "Ghim lên hồ sơ",
                          systemImage: daGhim ? "pin.slash" : "pin")
                }

                // Đổi quyền riêng tư ngay trong menu — vào màn sửa chỉ để đổi
                // một mức thì thừa ba cú bấm.
                Menu {
                    ForEach(Self.cacQuyen, id: \.0) { ma, ten, icon in
                        Button { Task { await doiQuyen(ma) } } label: {
                            Label(ten + (quyen == ma ? " ✓" : ""), systemImage: icon)
                        }
                    }
                } label: {
                    Label("Quyền riêng tư: \(tenQuyen)", systemImage: bieuTuongQuyen)
                }

                Button { hienSuaBai = true } label: {
                    Label("Sửa bài viết", systemImage: "pencil")
                }

                Button(role: .destructive) { hoiXoa = true } label: {
                    Label("Xoá bài viết", systemImage: "trash")
                }
            }

            if !laBaiCuaMinh {
                Button(role: .destructive) {
                    showReport = true
                } label: {
                    Label("Báo cáo bài viết", systemImage: "flag")
                }

                Button(role: .destructive) {
                    showBlockConfirm = true
                } label: {
                    Label("Chặn \(post.author.name)", systemImage: "hand.raised")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(target: .post(id: post.id, authorId: post.author.id, authorName: post.author.name))
        }
        .alert("Chặn \(post.author.name)?", isPresented: $showBlockConfirm) {
            Button("Huỷ", role: .cancel) { }
            Button("Chặn", role: .destructive) {
                Task { try? await moderation.block(userId: post.author.id) }
            }
        } message: {
            Text("Bạn sẽ không thấy bài viết của người này nữa và họ không thể nhắn tin cho bạn. Có thể bỏ chặn trong Cài đặt.")
        }
        .alert("Xoá bài viết?", isPresented: $hoiXoa) {
            Button("Huỷ", role: .cancel) { }
            Button("Xoá", role: .destructive) { Task { await xoa() } }
        } message: {
            Text("Bài viết cùng mọi bình luận và lượt thích sẽ bị xoá. Không khôi phục lại được.")
        }
        .sheet(isPresented: $hienSuaBai) {
            SuaBaiVietView(post: post, quyenBanDau: quyen) { noiDungMoi, quyenMoi in
                quyen = quyenMoi
            }
        }
        .alert("Bài viết", isPresented: .constant(loi != nil)) {
            Button("OK") { loi = nil }
        } message: { Text(loi ?? "") }
    }
}

// MARK: - Sửa bài viết

struct SuaBaiVietView: View {
    let post: SocialPost
    let quyenBanDau: String
    /// Gọi lại với nội dung và quyền mới, để menu ngoài cập nhật nhãn.
    let xong: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var noiDung: String
    @State private var quyen: String
    @State private var dangLuu = false
    @State private var loi: String?

    init(post: SocialPost, quyenBanDau: String, xong: @escaping (String, String) -> Void) {
        self.post = post
        self.quyenBanDau = quyenBanDau
        self.xong = xong
        _noiDung = State(initialValue: post.content)
        _quyen = State(initialValue: quyenBanDau)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nội dung") {
                    TextEditor(text: $noiDung)
                        .frame(minHeight: 200)
                        .font(.bodyMedium)
                }
                Section("Ai xem được") {
                    Picker("Quyền riêng tư", selection: $quyen) {
                        Label("Công khai", systemImage: "globe").tag("PUBLIC")
                        Label("Bạn bè", systemImage: "person.2").tag("FRIENDS")
                        Label("Chỉ mình tôi", systemImage: "lock").tag("PRIVATE")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Text("Ảnh và video đính kèm không sửa được ở đây — máy chủ chỉ nhận đổi nội dung chữ và quyền riêng tư. Muốn đổi ảnh thì xoá bài rồi đăng lại.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .navigationTitle("Sửa bài viết")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await luu() } } label: {
                        if dangLuu { ProgressView() } else { Text("Lưu").fontWeight(.semibold) }
                    }
                    .disabled(dangLuu)
                }
            }
            .alert("Sửa bài", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: { Text(loi ?? "") }
        }
    }

    private func luu() async {
        dangLuu = true
        defer { dangLuu = false }
        do {
            let _: SocialPost = try await APIClient.shared.request(
                .suaBaiViet(id: post.id, ["content": noiDung, "visibility": quyen]))
            Haptics.xong()
            xong(noiDung, quyen)
            dismiss()
        } catch { loi = error.localizedDescription }
    }
}

// MARK: - Blocked users (Settings → Danh sách chặn)

struct BlockedUsersView: View {
    @ObservedObject private var moderation = ModerationStore.shared
    @State private var errorMessage: String?

    var body: some View {
        List {
            if moderation.blockedUsers.isEmpty {
                Section {
                    Text(moderation.isLoading ? "Đang tải…" : "Bạn chưa chặn ai.")
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                Section {
                    ForEach(moderation.blockedUsers) { user in
                        HStack(spacing: Spacing.md) {
                            UserAvatarView(url: user.avatarUrl, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            Button("Bỏ chặn") {
                                Task {
                                    do { try await moderation.unblock(userId: user.id) }
                                    catch { errorMessage = error.localizedDescription }
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.buttonSmall)
                        }
                    }
                } footer: {
                    Text("Người bị chặn không thể nhắn tin cho bạn, và bài viết của họ được ẩn khỏi bảng tin.")
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundColor(AppColors.error) }
            }
        }
        .navigationTitle("Danh sách chặn")
        .navigationBarTitleDisplayMode(.inline)
        .task { await moderation.refreshBlocks() }
        .refreshable { await moderation.refreshBlocks() }
    }
}

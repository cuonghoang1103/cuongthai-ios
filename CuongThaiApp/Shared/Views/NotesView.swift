import SwiftUI

// MARK: - Notes View
struct NotesView: View {
    @StateObject private var viewModel = NotesViewModel()
    @State private var selectedSubject: NoteSubject?
    @State private var showNewSubject = false
    @State private var showNewChapter = false
    @State private var selectedSubjectForChapter: NoteSubject?
    @State private var tuKhoa = ""
    @State private var ketQua: [KetQuaTimGhiChu] = []
    @State private var dangTim = false
    @State private var hienSoDo = false
    @State private var hienTroLy = false
    @State private var hienLoc = false
    @State private var monSua: NoteSubject?
    @State private var tenMonMoi = ""
    @State private var hoiXoaMon: NoteSubject?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    if !tuKhoa.trimmingCharacters(in: .whitespaces).isEmpty {
                        khoiKetQuaTim
                    } else if viewModel.isLoading && viewModel.notesTree == nil {
                        loadingView
                    } else if let tree = viewModel.notesTree {
                        recentNotesSection(tree)
                        subjectsSection(tree)
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Ghi chú")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $tuKhoa, prompt: "Tìm trong mọi ghi chú")
            .onChange(of: tuKhoa) { _, moi in
                // Hoãn 350ms: gõ "toán" là 4 lượt gọi mạng cho một lần tìm, và
                // lượt về sau có thể tới TRƯỚC lượt trước rồi đè kết quả đúng.
                viecTim?.cancel()
                let khoa = moi.trimmingCharacters(in: .whitespaces)
                guard !khoa.isEmpty else { ketQua = []; return }
                viecTim = Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    await tim(khoa)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Menu chỉ còn MỘT mục thì bỏ menu, bấm phát ăn ngay.
                    // "Nhập ghi chú" đã gỡ: backend không có đường nhập nào.
                    HStack(spacing: Spacing.md) {
                        Button { hienLoc = true } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .accessibilityLabel("Lọc và thùng rác")

                        Button { hienSoDo = true } label: {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .accessibilityLabel("Sơ đồ liên kết")

                        Button { hienTroLy = true } label: {
                            Image(systemName: "sparkles").foregroundColor(AppColors.textPrimary)
                        }
                        .accessibilityLabel("Trợ lý ghi chú")

                        Button { showNewSubject = true } label: {
                            Image(systemName: "plus").foregroundColor(AppColors.textPrimary)
                        }
                        .accessibilityLabel("Môn học mới")
                    }
                }
            }
            .sheet(isPresented: $hienLoc) { LocGhiChuView() }
            .sheet(isPresented: $hienSoDo) { SoDoGhiChuView() }
            .alert("Đổi tên môn", isPresented: Binding(get: { monSua != nil },
                                                       set: { if !$0 { monSua = nil } })) {
                TextField("Tên môn", text: $tenMonMoi)
                Button("Lưu") {
                    if let m = monSua {
                        Task { await viewModel.suaMon(m.id, ten: tenMonMoi); monSua = nil }
                    }
                }
                Button("Huỷ", role: .cancel) { monSua = nil }
            }
            .alert("Xoá môn học?", isPresented: Binding(get: { hoiXoaMon != nil },
                                                        set: { if !$0 { hoiXoaMon = nil } })) {
                Button("Xoá", role: .destructive) {
                    if let m = hoiXoaMon { Task { await viewModel.xoaMon(m.id); hoiXoaMon = nil } }
                }
                Button("Huỷ", role: .cancel) { hoiXoaMon = nil }
            } message: {
                Text("Mọi ghi chú trong môn này cũng bị xoá theo.")
            }
            .sheet(isPresented: $hienTroLy) { TroLyGhiChuView() }
            .sheet(isPresented: $showNewSubject) {
                NewSubjectView { name, color, emoji in
                    Task {
                        await viewModel.createSubject(name: name, color: color, emoji: emoji)
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadNotesTree()
                }
            }
            .refreshable {
                await viewModel.loadNotesTree()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Đang tải ghi chú...")
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, Spacing.xxl)
    }

    @State private var viecTim: Task<Void, Never>?

    private var khoiKetQuaTim: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(dangTim ? "Đang tìm…" : "\(ketQua.count) kết quả")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                if dangTim { ProgressView().scaleEffect(0.7) }
            }

            if !dangTim && ketQua.isEmpty {
                Text("Không thấy ghi chú nào khớp.")
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }

            ForEach(ketQua) { n in
                NavigationLink {
                    GhiChuChiTietView(ghiChuId: n.id) { Task { await viewModel.loadNotesTree() } }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(n.title.isEmpty ? "Untitled" : n.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        if let sn = n.snippet, !sn.isEmpty {
                            Text(sn)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(2)
                        }
                        Text(TimeFormatter.formatTimeAgo(n.updatedAt))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().background(AppColors.divider)
            }
        }
    }

    private func tim(_ khoa: String) async {
        dangTim = true
        defer { dangTim = false }
        // Tìm hỏng thì để danh sách rỗng — màn hình đã nói rõ "0 kết quả",
        // ném thêm hộp thoại lỗi ở đây chỉ chắn mất ô tìm.
        ketQua = (try? await APIClient.shared
            .request(.timGhiChu(q: khoa, subjectId: nil, tag: nil))) ?? []
    }

    private func recentNotesSection(_ tree: NotesTree) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Gần đây")

            if let recentNotes = tree.recentNotes, !recentNotes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(recentNotes.prefix(10)) { note in
                            NavigationLink {
                                GhiChuChiTietView(ghiChuId: note.id) {
                                    Task { await viewModel.loadNotesTree() }
                                }
                            } label: {
                                RecentNoteCard(note: note)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                emptyRecentView
            }
        }
    }

    private func subjectsSection(_ tree: NotesTree) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Môn học")

            if tree.subjects.isEmpty {
                emptySubjectsView
            } else {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(tree.subjects) { subject in
                        NavigationLink {
                            MonGhiChuView(mon: subject) { await viewModel.loadNotesTree() }
                        } label: {
                            SubjectCard(subject: subject)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { monSua = subject; tenMonMoi = subject.name } label: {
                                Label("Đổi tên", systemImage: "pencil")
                            }
                            Button(role: .destructive) { hoiXoaMon = subject } label: {
                                Label("Xoá môn", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)

            Spacer()
        }
    }

    private var emptyRecentView: some View {
        HStack {
            Spacer()
            VStack(spacing: Spacing.sm) {
                Image(systemName: "doc.text")
                    .font(.system(size: 30))
                    .foregroundColor(AppColors.textTertiary)
                Text("Chưa có ghi chú nào")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, Spacing.lg)
    }

    private var emptySubjectsView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "folder")
                .font(.system(size: 50))
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: Spacing.sm) {
                Text("Chưa có môn học nào")
                    .font(.titleMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Tạo môn học để bắt đầu ghi chú")
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
            }

            Button {
                showNewSubject = true
            } label: {
                Text("Tạo môn học")
                    .primaryButtonStyle()
            }
            .padding(.horizontal, Spacing.xl)
        }
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Recent Note Card
/// ⚠️ KHÔNG được là `Button`. Thẻ này nằm trong `NavigationLink`, mà Button
/// lồng trong NavigationLink NUỐT cú chạm — link không bao giờ kích hoạt và
/// bấm vào không có gì xảy ra. Đây là view thuần, để link bọc ngoài lo.
struct RecentNoteCard: View {
    let note: NoteSummary

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(AppColors.primary)

                    Spacer()

                    Text(TimeFormatter.formatTimeAgo(note.updatedAt))
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                Spacer()
            }
            .padding(Spacing.md)
            .frame(width: 150, height: 120)
            .background(AppColors.backgroundCard)
            .cornerRadius(CornerRadius.medium)
        }
    }
}

// MARK: - Subject Card
/// ⚠️ KHÔNG được là `Button` — xem chú thích ở `RecentNoteCard`.
struct SubjectCard: View {
    let subject: NoteSubject

    var body: some View {
        Group {
            HStack(spacing: Spacing.md) {
                // Subject Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: subject.color ?? "#8C5AF0")?.opacity(0.2) ?? AppColors.primary.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Text(subject.emoji ?? "📚")
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.name)
                        .font(.titleSmall)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: Spacing.md) {
                        if let chapters = subject.chapters {
                            Label("\(chapters.count) chương", systemImage: "book.pages")
                        }
                        if let notesCount = subject.notesCount {
                            Label("\(notesCount) ghi chú", systemImage: "doc.text")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(AppColors.backgroundCard)
            .cornerRadius(CornerRadius.medium)
        }
    }
}

// MARK: - New Subject View
struct NewSubjectView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var selectedColor = "#8C5AF0"
    @State private var selectedEmoji = "📚"

    let colors = ["#8C5AF0", "#06B6D4", "#10B981", "#F59E0B", "#EF4444", "#EC4899"]
    let emojis = ["📚", "📐", "🧪", "🌍", "🎨", "🎵", "💻", "📖", "🔬", "🏛️"]

    let onSave: (String, String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Tên môn học") {
                    TextField("Nhập tên môn học", text: $name)
                }

                Section("Màu sắc") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.md) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color) ?? AppColors.primary)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                            }
                        }
                    }
                }

                Section("Biểu tượng") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: Spacing.md) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.title)
                                    .padding(Spacing.sm)
                                    .background(selectedEmoji == emoji ? AppColors.primary.opacity(0.2) : Color.clear)
                                    .cornerRadius(CornerRadius.small)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Môn học mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tạo") {
                        onSave(name, selectedColor, selectedEmoji)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Notes View Model
@MainActor
class NotesViewModel: ObservableObject {
    @Published var notesTree: NotesTree?
    @Published var isLoading = false
    @Published var error: String?

    func loadNotesTree() async {
        isLoading = true
        error = nil

        do {
            notesTree = try await APIClient.shared.request(.getNotesTree)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// ⚠️ Trước đây hàm này là VỎ — chỉ có chú thích "API call would be made
    /// here" rồi tải lại cây, nên bấm "Tạo" không tạo gì cả và cũng không báo
    /// lỗi. Đây là chỗ duy nhất trong app còn sót lại kiểu đó.
    func createSubject(name: String, color: String, emoji: String) async {
        let ten = name.trimmingCharacters(in: .whitespaces)
        guard !ten.isEmpty else { error = "Chưa nhập tên môn học."; return }
        do {
            let _: NoteSubject = try await APIClient.shared
                .request(.taoMon(name: ten, color: color, emoji: emoji))
            Haptics.xong()
            await loadNotesTree()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func suaMon(_ id: Int, ten: String) async {
        do {
            let _: NoteSubject = try await APIClient.shared.request(.suaMon(id: id, ["name": ten]))
            await loadNotesTree()
        } catch { self.error = error.localizedDescription }
    }

    func xoaMon(_ id: Int) async {
        do {
            let _: EmptyResponse = try await APIClient.shared.request(.xoaMon(id: id))
            Haptics.xong()
            await loadNotesTree()
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    NotesView()
}

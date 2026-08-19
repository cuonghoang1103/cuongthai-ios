import SwiftUI

// MARK: - Notes View
struct NotesView: View {
    @StateObject private var viewModel = NotesViewModel()
    @State private var selectedSubject: NoteSubject?
    @State private var showNewSubject = false
    @State private var showNewChapter = false
    @State private var selectedSubjectForChapter: NoteSubject?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    if viewModel.isLoading && viewModel.notesTree == nil {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Menu chỉ còn MỘT mục thì bỏ menu, bấm phát ăn ngay.
                    // "Nhập ghi chú" đã gỡ: backend không có đường nhập nào.
                    Button {
                        showNewSubject = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .accessibilityLabel("Môn học mới")
                }
            }
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

    private func recentNotesSection(_ tree: NotesTree) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Gần đây")

            if let recentNotes = tree.recentNotes, !recentNotes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(recentNotes.prefix(10)) { note in
                            RecentNoteCard(note: note) {
                                // Open note
                            }
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
                        SubjectCard(subject: subject) {
                            selectedSubject = subject
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
struct RecentNoteCard: View {
    let note: NoteSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
struct SubjectCard: View {
    let subject: NoteSubject
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

    func createSubject(name: String, color: String, emoji: String) async {
        // API call would be made here
        await loadNotesTree()
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

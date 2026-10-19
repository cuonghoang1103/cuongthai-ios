import SwiftUI
import QuickLook

// MARK: - CTWUI — bộ chọn người / trạng thái / ưu tiên · soạn markdown · xem tệp

/// Bảng CHỌN NGƯỜI (giao việc, lọc theo người). Có ô tìm, "Me" lên đầu,
/// AI agent gắn nhãn (4.7). `nhieu = true` cho chọn nhiều (lọc).
struct CTWChonNguoiView: View {
    let ds: [CTWUser]
    var toi: Int?
    var nhieu = false
    var choPhepTrong = true
    @Binding var chon: Set<Int>
    var xong: (() -> Void)?
    @Environment(\.dismiss) private var dong
    @State private var tim = ""

    private var loc: [CTWUser] {
        let s = ds.filter { tim.isEmpty || $0.ten.localizedCaseInsensitiveContains(tim) || ($0.username ?? "").localizedCaseInsensitiveContains(tim) }
        return s.sorted { a, b in
            if a.id == toi { return true }
            if b.id == toi { return false }
            if a.laAgent != b.laAgent { return !a.laAgent }
            return a.ten.localizedCaseInsensitiveCompare(b.ten) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if choPhepTrong && tim.isEmpty {
                    hang(nil)
                }
                ForEach(loc) { u in hang(u) }
            }
            .searchable(text: $tim, prompt: "Search people")
            .navigationTitle(nhieu ? "People" : "Assignee")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                if nhieu {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { xong?(); dong() }.bold() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func hang(_ u: CTWUser?) -> some View {
        let id = u?.id ?? 0
        return Button {
            CTWRung.chon()
            if nhieu {
                if chon.contains(id) { chon.remove(id) } else { chon.insert(id) }
            } else {
                chon = [id]
                xong?()
                dong()
            }
        } label: {
            HStack(spacing: 12) {
                CTWAvatar(user: u, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(u.map { $0.id == toi ? "\($0.ten) (me)" : $0.ten } ?? "Unassigned")
                            .foregroundColor(AppColors.textPrimary)
                        if u?.laAgent == true { CTWNhanAI() }
                    }
                    if let n = u?.username { Text("@\(n)").font(.caption).foregroundColor(AppColors.textSecondary) }
                }
                Spacer()
                if chon.contains(id) { Image(systemName: "checkmark").foregroundColor(AppColors.primary).fontWeight(.semibold) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Menu CHỌN TRẠNG THÁI — chỉ liệt kê bước chuyển quy trình cho phép.
struct CTWChonTrangThaiMenu: View {
    let cauHinh: CTWProjectConfig
    let loai: Int
    let hienTai: Int
    let chon: (CTWStatus) -> Void

    var body: some View {
        Menu {
            ForEach(cauHinh.trangThaiDich(loai: loai, tu: hienTai)) { s in
                Button { chon(s) } label: {
                    if s.id == hienTai { Label(s.name, systemImage: "checkmark") } else { Text(s.name) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                CTWStatusChip(status: cauHinh.trangThai(hienTai))
                Image(systemName: "chevron.up.chevron.down").font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary)
            }
        }
        .accessibilityLabel("Status: \(cauHinh.trangThai(hienTai)?.name ?? "")")
    }
}

/// Menu CHỌN ƯU TIÊN (1 Highest … 5 Lowest).
struct CTWChonUuTienMenu: View {
    let hienTai: Int?
    let chon: (Int) -> Void

    var body: some View {
        let p = CTW.uuTien(hienTai)
        Menu {
            ForEach(CTW.doUuTien, id: \.so) { m in
                Button { chon(m.so) } label: { Label(m.ten, systemImage: m.so == p.so ? "checkmark" : m.bieuTuong) }
            }
        } label: {
            HStack(spacing: 6) {
                CTWPriorityIcon(priority: hienTai)
                Text(p.ten).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
            }
        }
    }
}

// MARK: - Soạn markdown nhẹ

/// Ô SOẠN có thanh định dạng (đậm, nghiêng, mã, danh sách, việc, liên kết) và
/// nút Xem trước. Kết quả là markdown thô — chat gửi thẳng; bình luận/mô tả
/// thẻ cần TipTap thì dùng `CTWNode.docTuChu` (mỗi dòng một đoạn).
struct CTWSoanMarkdown: View {
    @Binding var chu: String
    var goiY = "Write something…"
    var dongToiThieu = 4
    @State private var xemTruoc = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                nut("bold", "Bold") { boc("**") }
                nut("italic", "Italic") { boc("_") }
                nut("chevron.left.forwardslash.chevron.right", "Code") { boc("`") }
                nut("list.bullet", "Bulleted list") { dauDong("- ") }
                nut("checklist", "Checklist") { dauDong("- [ ] ") }
                nut("link", "Link") { chu += (chu.isEmpty || chu.hasSuffix(" ") || chu.hasSuffix("\n") ? "" : " ") + "[title](https://)" }
                Spacer()
                Toggle(isOn: $xemTruoc) { Image(systemName: "eye") }
                    .toggleStyle(.button)
                    .accessibilityLabel("Preview")
            }
            .foregroundColor(AppColors.textSecondary)
            if xemTruoc {
                ScrollView {
                    CTWMarkdownView(markdown: chu.isEmpty ? "_Nothing to preview_" : chu, coChu: 15)
                        .padding(12)
                }
                .frame(minHeight: CGFloat(dongToiThieu) * 22)
                .ctwThe(10)
            } else {
                TextField(goiY, text: $chu, axis: .vertical)
                    .lineLimit(dongToiThieu...16)
                    .font(.ctw(size: 15))
                    .padding(12)
                    .ctwThe(10)
            }
        }
    }

    private func nut(_ icon: String, _ ten: String, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) { Image(systemName: icon).frame(width: 36, height: 32) }
            .buttonStyle(.borderless)
            .accessibilityLabel(ten)
    }

    private func boc(_ k: String) { chu += k + "text" + k }

    private func dauDong(_ d: String) {
        if !chu.isEmpty && !chu.hasSuffix("\n") { chu += "\n" }
        chu += d
    }
}

// MARK: - Xem ảnh / tệp

/// Tải một url ký sẵn về thư mục tạm rồi mở bằng Xem nhanh (QuickLook): ảnh,
/// PDF, tài liệu văn phòng, video… Dùng: `.ctwXemTep($url)` + `CTWXemTep.taiVe`.
enum CTWXemTep {
    static func taiVe(url: URL, ten: String, khoa: String) async throws -> URL {
        let (tam, _) = try await URLSession.shared.download(from: url)
        let thu = FileManager.default.temporaryDirectory.appendingPathComponent("ctw-\(khoa)", isDirectory: true)
        try? FileManager.default.createDirectory(at: thu, withIntermediateDirectories: true)
        let dich = thu.appendingPathComponent(ten.isEmpty ? "file" : ten)
        try? FileManager.default.removeItem(at: dich)
        try FileManager.default.moveItem(at: tam, to: dich)
        return dich
    }
}

extension View {
    func ctwXemTep(_ url: Binding<URL?>) -> some View { quickLookPreview(url) }
}

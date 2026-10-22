import SwiftUI
#if os(iOS)
import QuickLook
import SafariServices
#endif

// ════════════════════════════════════════════════════════════════
// TÀI LIỆU + BÀI TẬP CỦA BÀI HỌC
//
// Tài liệu nằm trên R2 RIÊNG TƯ: phải xin URL ký 5 phút
// (`/courses/documents/:id/download?resolve=1`) rồi mới mở được. PDF mở bằng
// PDFKit (`XemPdfView`), ảnh/Word/PowerPoint tải về rồi xem bằng Quick Look,
// liên kết ngoài mở trong Safari của app.
//
// Bài tập nộp link: nộp NGAY trong app (`POST /courses/assignments/submit`)
// — không đẩy sang web (App Store 4.2: "hãy làm trên web" là dấu hiệu xấu).
// ════════════════════════════════════════════════════════════════

/// Cái cần mở sau khi đã xin được đường dẫn.
enum DichMoTaiLieu: Identifiable, Equatable {
    case pdf(URL, tieuDe: String)
    case web(URL)
    case tep(URL)

    var id: String {
        switch self {
        case .pdf(let u, _): return "pdf-" + u.absoluteString
        case .web(let u): return "web-" + u.absoluteString
        case .tep(let u): return "tep-" + u.absoluteString
        }
    }
}

enum MoTaiLieu {
    /// Xin đường dẫn và (với tệp không phải PDF) tải về thư mục tạm để Quick Look đọc.
    static func chuanBi(_ d: TaiLieuBai) async throws -> DichMoTaiLieu {
        if d.kieu == .lienKet {
            // Liên kết ngoài: máy chủ trả 302 thẳng tới trang đích (không có JSON).
            guard let s = d.fileUrl, let u = URL(string: s) else { throw APIError.invalidURL }
            return .web(u)
        }
        let l: LinkTaiLieu = try await APIClient.shared.request(.hocBai(.moTaiLieu(id: d.id)))
        guard let u = URL(string: l.url) else { throw APIError.invalidURL }
        if (l.fileType ?? "").lowercased() == "link" { return .web(u) }
        if d.kieu == .pdf { return .pdf(u, tieuDe: d.title) }
        // Quick Look cần tệp CỤC BỘ có đuôi đúng.
        let (tam, resp) = try await URLSession.shared.download(from: u)
        if let h = resp as? HTTPURLResponse, !(200...299).contains(h.statusCode) {
            throw APIError.serverError(String(format: T("Máy chủ trả lỗi %d."), h.statusCode))
        }
        let duoi = TaiLieuBai.duoi(d.title) ?? TaiLieuBai.duoi(d.fileUrl ?? "") ?? TaiLieuBai.duoi(u.path) ?? "bin"
        let ten = d.title.replacingOccurrences(of: "/", with: "-")
        let thuMuc = FileManager.default.temporaryDirectory.appendingPathComponent("tai-lieu-bai", isDirectory: true)
        try? FileManager.default.createDirectory(at: thuMuc, withIntermediateDirectories: true)
        var dich = thuMuc.appendingPathComponent(ten)
        if TaiLieuBai.duoi(ten) == nil { dich.appendPathExtension(duoi) }
        try? FileManager.default.removeItem(at: dich)
        try FileManager.default.moveItem(at: tam, to: dich)
        return .tep(dich)
    }
}

/// Danh sách tài liệu (của bài hoặc của khoá).
struct DanhSachTaiLieu: View {
    let tieuDe: String
    let ds: [TaiLieuBai]
    var ghiChu: String? = nil
    let khiMo: (DichMoTaiLieu) -> Void

    @State private var dangMo: Int?
    @State private var loi: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(tieuDe, systemImage: "paperclip")
                .font(.titleSmall).foregroundColor(AppColors.textPrimary)
            if let ghiChu, !ghiChu.isEmpty {
                Text(ghiChu).font(.bodySmall).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                ForEach(Array(ds.enumerated()), id: \.element.id) { i, d in
                    Button { Task { await mo(d) } } label: { hang(d) }
                        .buttonStyle(.plain)
                        .disabled(dangMo != nil)
                    if i < ds.count - 1 { Divider().padding(.leading, 52) }
                }
            }
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous).fill(AppColors.backgroundSecondary))
            if let loi {
                Label(loi, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundColor(AppColors.warning)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
    }

    private func hang(_ d: TaiLieuBai) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: d.bieuTuong)
                .font(.system(size: 17)).foregroundColor(AppColors.primary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(d.title.theoApp).font(.bodyMedium).foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading).lineLimit(2)
                Text([nhanKieu(d), d.nhanCo].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundColor(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            if dangMo == d.id {
                ProgressView()
            } else {
                Image(systemName: d.kieu == .lienKet ? "arrow.up.forward" : "eye")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(T("Mở tài liệu"))
    }

    private func nhanKieu(_ d: TaiLieuBai) -> String {
        switch d.kieu {
        case .pdf: return "PDF"
        case .anh: return T("Ảnh")
        case .office: return (TaiLieuBai.duoi(d.title) ?? "Office").uppercased()
        case .lienKet: return T("Liên kết")
        case .khac: return (TaiLieuBai.duoi(d.title) ?? T("Tệp")).uppercased()
        }
    }

    private func mo(_ d: TaiLieuBai) async {
        Haptics.cham()
        dangMo = d.id
        loi = nil
        defer { dangMo = nil }
        do {
            khiMo(try await MoTaiLieu.chuanBi(d))
        } catch {
            loi = error.localizedDescription
            Haptics.hong()
        }
    }
}

/// Bài tập nộp link của bài + trạng thái bài nộp của chính mình.
struct DanhSachBaiTapNop: View {
    let ds: [BaiTapNop]
    let khiNop: (BaiTapNop) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(T("Bài tập nộp"), systemImage: "tray.and.arrow.up")
                .font(.titleSmall).foregroundColor(AppColors.textPrimary)
            ForEach(ds) { a in the(a) }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
    }

    private func the(_ a: BaiTapNop) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(a.title.theoApp).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.sm)
                nhanTrangThai(a)
            }
            if let hd = a.instructions, !hd.isEmpty {
                Text(hd.lotTheHTML).font(.bodySmall).foregroundColor(AppColors.textSecondary)
                    .lineLimit(6).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Spacing.md) {
                if let h = a.deadline, let d = Date.tuChuoiISO(h) {
                    Label(d.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .foregroundColor(d < Date() ? AppColors.error : AppColors.textTertiary)
                }
                if let m = a.maxScore { Label(String(format: T("Thang điểm %g"), m), systemImage: "star") }
            }
            .font(.caption).foregroundColor(AppColors.textTertiary)
            if let n = a.mySubmission {
                VStack(alignment: .leading, spacing: 3) {
                    if let u = n.submissionUrl, let url = URL(string: u) {
                        Link(destination: url) {
                            Label(u, systemImage: "link").lineLimit(1)
                        }
                        .font(.caption)
                    }
                    if let g = n.grade { Text(String(format: T("Điểm: %g"), g)).font(.captionBold).foregroundColor(AppColors.success) }
                    if let f = n.feedback, !f.isEmpty {
                        Text(T("Nhận xét:") + " " + f).font(.caption).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Button {
                Haptics.cham(); khiNop(a)
            } label: {
                Label(a.mySubmission == nil ? T("Nộp bài") : T("Nộp lại"), systemImage: "paperplane.fill")
                    .font(.buttonSmall).foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous).fill(AppColors.backgroundSecondary))
    }

    @ViewBuilder
    private func nhanTrangThai(_ a: BaiTapNop) -> some View {
        let (chu, mau): (String, Color) = {
            guard let n = a.mySubmission else { return (T("Chưa nộp"), AppColors.textTertiary) }
            if n.grade != nil || (n.status ?? "").uppercased() == "GRADED" { return (T("Đã chấm"), AppColors.success) }
            return (T("Đã nộp"), AppColors.info)
        }()
        Text(chu).font(.system(size: 11, weight: .bold)).foregroundColor(mau)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(mau.opacity(0.14)))
    }
}

/// Màn nộp một bài tập: link bài làm (GitHub, Drive…) + ghi chú.
struct NopBaiTapView: View {
    let baiTap: BaiTapNop
    let khiXong: (NopBai) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var duong = ""
    @State private var ghiChu = ""
    @State private var dangGui = false
    @State private var loi: String?

    private var hopLe: Bool {
        let s = duong.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: s), let sc = u.scheme?.lowercased() else { return false }
        return (sc == "https" || sc == "http") && u.host != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(baiTap.title.theoApp).font(.titleSmall)
                    if let hd = baiTap.instructions, !hd.isEmpty {
                        Text(hd.lotTheHTML).font(.bodySmall).foregroundColor(AppColors.textSecondary)
                    }
                }
                Section {
                    TextField("https://github.com/…", text: $duong)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: { Text(T("Link bài làm")) } footer: {
                    Text(T("Dán link GitHub, Google Drive, OneDrive… nơi giảng viên mở được."))
                }
                Section(T("Ghi chú (tuỳ chọn)")) {
                    TextField(T("Ghi chú cho giảng viên"), text: $ghiChu, axis: .vertical)
                        .lineLimit(2...6)
                }
                if let loi {
                    Section { Label(loi, systemImage: "exclamationmark.triangle.fill").foregroundColor(AppColors.error) }
                }
            }
            .navigationTitle(baiTap.mySubmission == nil ? T("Nộp bài") : T("Nộp lại"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangGui { ProgressView() } else {
                        Button(T("Gửi")) { Task { await gui() } }.disabled(!hopLe)
                    }
                }
            }
            .onAppear {
                duong = baiTap.mySubmission?.submissionUrl ?? ""
                ghiChu = baiTap.mySubmission?.notes ?? ""
            }
        }
    }

    private func gui() async {
        dangGui = true
        loi = nil
        defer { dangGui = false }
        do {
            let n: NopBai = try await APIClient.shared.request(.hocBai(.nopBaiTap(
                assignmentId: baiTap.id, duongDan: duong.trimmingCharacters(in: .whitespacesAndNewlines), ghiChu: ghiChu)))
            Haptics.xong()
            khiXong(n)
            dismiss()
        } catch {
            Haptics.hong()
            loi = error.localizedDescription
        }
    }
}

#if os(iOS)
/// Quick Look cho tệp đã tải về (ảnh, Word, PowerPoint, Excel…).
struct XemTepNhanh: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let c = QLPreviewController()
        c.dataSource = context.coordinator
        return UINavigationController(rootViewController: c)
    }
    func updateUIViewController(_ c: UINavigationController, context: Context) {}
    func makeCoordinator() -> Nguon { Nguon(url: url) }

    final class Nguon: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in c: QLPreviewController) -> Int { 1 }
        func previewController(_ c: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as QLPreviewItem }
    }
}
#endif

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if os(iOS)
import QuickLook
#endif

// ════════════════════════════════════════════════════════════════
// BA KIỂU CÂU PE TRONG APP — thay cho câu "hãy làm trên web" (App Store 4.2)
//
//   CODE  — gõ mã ngay trong app (Q1.c, Q2.c… tự đóng gói .zip), HOẶC chọn
//           một tệp .zip đã làm ở máy tính (Tệp / iCloud Drive)
//   WRITE — viết bài (tiếng Anh) + đính kèm ẢNH sơ đồ (chụp hoặc chọn)
//   SPEAK — thu âm từng câu hỏi phụ; đề chưa có câu hỏi thì máy chủ sinh
// ════════════════════════════════════════════════════════════════

// MARK: - CODE

struct KhungCodeThi: View {
    @ObservedObject var vm: LamBaiVM
    let cau: CauHoiThi
    @State private var cao: CGFloat = 260
    @State private var chonZip = false
    @State private var loiZip: String?

    private var ma: Binding<String> {
        Binding(get: { vm.maCode[cau.id] ?? "" }, set: { vm.maCode[cau.id] = $0 })
    }
    private var soDong: Int { (vm.maCode[cau.id] ?? "").isEmpty ? 0 : (vm.maCode[cau.id] ?? "").components(separatedBy: "\n").count }
    private var thuTuCode: Int { (vm.cauCode.firstIndex { $0.id == cau.id } ?? 0) + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "doc.plaintext").font(.caption)
                if vm.loaiPE == "CODE" {
                    Text(String(format: T("Bài làm câu này nộp thành tệp %@"), TepMaNguon.ten(thuTu: thuTuCode, ngonNgu: cau.language)))
                } else {
                    Text(T("Gõ code ngay tại đây — AI chấm theo tiêu chí"))
                }
                Spacer(minLength: 0)
                if let s = cau.starterCode, !s.isEmpty, (vm.maCode[cau.id] ?? "") != s {
                    Button(T("Về mã cho sẵn")) { vm.maCode[cau.id] = s }
                        .font(.caption.weight(.semibold))
                }
            }
            .font(.caption)
            .foregroundColor(AppColors.textTertiary)

            #if os(iOS)
            TrinhSuaMa(ma: ma, chieuCao: $cao, goiY: T("// Viết code của bạn ở đây…"),
                       nhanTroNang: T("Ô soạn mã câu") + " \(vm.viTri + 1)")
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).strokeBorder(AppColors.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            #endif

            Text(String(format: T("%d dòng"), soDong))
                .font(.caption2).foregroundColor(AppColors.textTertiary).monospacedDigit()

            if vm.loaiPE == "CODE" { theZip }
        }
        .fileImporter(isPresented: $chonZip, allowedContentTypes: [.zip]) { kq in
            napZip(kq)
        }
    }

    /// Làm ở máy tính rồi nộp bằng điện thoại — đúng cách web nhận bài.
    private var theZip: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "doc.zipper").foregroundColor(AppColors.primary)
                Text(T("Làm ở máy tính? Nộp cả bài bằng một tệp .zip"))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            if let z = vm.zipChon {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.success)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(z.ten).font(.footnote.weight(.medium)).lineLimit(1)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(z.duLieu.count), countStyle: .file)
                             + " · " + T("sẽ nộp tệp này thay cho phần đã gõ"))
                            .font(.caption2).foregroundColor(AppColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                    Button(T("Bỏ")) { vm.zipChon = nil }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.error)
                }
            } else {
                Text(T("Nén các tệp Q1.c, Q2.c… thành MỘT tệp .zip (tối đa 30MB). Không chọn thì app tự đóng gói phần bạn gõ ở trên."))
                    .font(.caption).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { chonZip = true } label: {
                    Label(T("Chọn tệp .zip"), systemImage: "folder")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            if let l = loiZip {
                Text(l).font(.caption).foregroundColor(AppColors.error)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundColor(AppColors.border))
    }

    private func napZip(_ kq: Result<URL, Error>) {
        loiZip = nil
        switch kq {
        case .failure(let e): loiZip = e.localizedDescription
        case .success(let u):
            let mo = u.startAccessingSecurityScopedResource()
            defer { if mo { u.stopAccessingSecurityScopedResource() } }
            do {
                let d = try Data(contentsOf: u)
                guard d.count <= GuiBaiThi.tranZip else { loiZip = T("Tệp vượt 30MB — máy chủ không nhận."); return }
                // Chữ ký "PK\u{3}\u{4}" — chặn chọn nhầm tệp khác đổi đuôi .zip.
                guard d.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]) else { loiZip = T("Tệp này không phải .zip hợp lệ."); return }
                vm.zipChon = TepZipChon(ten: u.lastPathComponent, duLieu: d)
                Haptics.xong()
            } catch { loiZip = error.localizedDescription }
        }
    }
}

// MARK: - WRITE

/// Câu yêu cầu VẼ sơ đồ (Context / Use-Case / ERD) — web nhận ra bằng chính
/// đề bài (`/\b(diagram|erd)\b/i`), đã đối chiếu với cả 22 đề PE SWR302.
enum CauVeSoDo {
    static func la(_ deBai: String) -> Bool {
        deBai.range(of: #"\b(diagram|erd)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

struct KhungVietThi: View {
    @ObservedObject var vm: LamBaiVM
    let cau: CauHoiThi
    @State private var mucAnh: PhotosPickerItem?
    @State private var moMayAnh = false
    @State private var dangNapAnh = false
    @State private var loiAnh: String?
    @FocusState private var dangGo: Bool

    private var bai: Binding<String> {
        Binding(get: { vm.baiViet[cau.id] ?? "" }, set: { vm.baiViet[cau.id] = $0 })
    }
    private var soTu: Int { (vm.baiViet[cau.id] ?? "").split { $0.isWhitespace || $0.isNewline }.count }
    private var laSoDo: Bool { CauVeSoDo.la(cau.prompt) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if laSoDo { theAnh }

            ZStack(alignment: .topLeading) {
                TextEditor(text: bai)
                    .focused($dangGo)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 280)
                    .autocorrectionDisabled(false)
                    .accessibilityLabel(T("Bài viết câu") + " \(vm.viTri + 1)")
                if (vm.baiViet[cau.id] ?? "").isEmpty {
                    Text(laSoDo ? T("Mô tả thêm sơ đồ bằng chữ (không bắt buộc)…")
                                : T("Viết câu trả lời bằng tiếng Anh tại đây…"))
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 15).padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(dangGo ? AppColors.primary : AppColors.border, lineWidth: dangGo ? 1.5 : 1))

            HStack {
                Text(String(format: T("%d từ"), soTu)).monospacedDigit()
                Text("·")
                Text(T("Viết bằng tiếng Anh — AI chấm theo tiêu chí"))
                Spacer()
                if dangGo {
                    Button(T("Xong")) { dangGo = false }.font(.caption.weight(.semibold))
                }
            }
            .font(.caption2)
            .foregroundColor(AppColors.textTertiary)

            if !laSoDo { theAnh }
        }
        .onChange(of: mucAnh) { _, m in
            guard let m else { return }
            Task { await napAnh(m) }
        }
        #if os(iOS)
        .sheet(isPresented: $moMayAnh) {
            MayAnh { d in nhanAnh(d) }.ignoresSafeArea()
        }
        #endif
    }

    private var theAnh: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(laSoDo ? T("Ảnh sơ đồ bạn vẽ (AI chấm theo ảnh này)")
                         : T("Đính kèm ảnh (không bắt buộc)"),
                  systemImage: "photo.on.rectangle")
                .font(.footnote.weight(.semibold))
                .foregroundColor(laSoDo ? AppColors.textPrimary : AppColors.textSecondary)

            #if os(iOS)
            if let d = vm.anhSoDo[cau.id], let anh = UIImage(data: d) {
                Image(uiImage: anh)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .accessibilityLabel(T("Ảnh sơ đồ đã đính kèm"))
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(d.count), countStyle: .file))
                        .font(.caption2).foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Button(role: .destructive) { vm.anhSoDo[cau.id] = nil; mucAnh = nil } label: {
                        Label(T("Xoá ảnh"), systemImage: "trash").font(.footnote)
                    }
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    PhotosPicker(selection: $mucAnh, matching: .images) {
                        Label(T("Chọn ảnh"), systemImage: "photo")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    if MayAnh.coMayAnh {
                        Button { moMayAnh = true } label: {
                            Label(T("Chụp ảnh"), systemImage: "camera")
                                .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                    if dangNapAnh { ProgressView().controlSize(.small) }
                }
            }
            #endif
            if let l = loiAnh { Text(l).font(.caption).foregroundColor(AppColors.error) }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundSecondary))
    }

    private func napAnh(_ m: PhotosPickerItem) async {
        dangNapAnh = true; defer { dangNapAnh = false }
        loiAnh = nil
        do {
            guard let d = try await m.loadTransferable(type: Data.self) else { loiAnh = T("Không đọc được ảnh."); return }
            nhanAnh(d)
        } catch { loiAnh = error.localizedDescription }
    }

    private func nhanAnh(_ d: Data) {
        #if os(iOS)
        // Nén về JPEG (HEIC của iPhone máy chủ không nhận — chỉ png/jpeg/webp/gif).
        guard let j = NenAnhThi.jpeg(d) else { loiAnh = T("Ảnh này không mở được."); return }
        guard j.count <= GuiBaiThi.tranAnh else { loiAnh = T("Ảnh vẫn quá 8MB sau khi nén."); return }
        vm.anhSoDo[cau.id] = j
        Haptics.xong()
        #endif
    }
}

// MARK: - SPEAK

#if os(iOS)
struct KhungNoiThi: View {
    @ObservedObject var vm: LamBaiVM
    @ObservedObject var ghiAm: GhiAmThi
    let cau: CauHoiThi

    /// JPD (tiếng Nhật) trả lời bằng tiếng Nhật — máy chủ chọn ngôn ngữ nhận
    /// giọng theo mã môn (`courseCode` bắt đầu bằng "JPD").
    private var tiengNhat: Bool { (vm.deGoc?.maMon ?? "").uppercased().hasPrefix("JPD") }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label(tiengNhat ? T("Trả lời bằng TIẾNG NHẬT. AI nghe, chấm nội dung và phát âm.")
                            : T("Trả lời bằng TIẾNG ANH. AI nghe, chấm nội dung và phát âm."),
                  systemImage: "waveform")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)

            if vm.cauNoi.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Text(T("Đề này chưa có câu hỏi nói. Tạo câu hỏi từ chủ đề để luyện:"))
                        .font(.footnote).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await vm.sinhCauNoi() }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.dangSinhCauNoi { ProgressView().tint(.white) }
                            Text(vm.dangSinhCauNoi ? T("Đang tạo…") : T("Tạo câu hỏi"))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.lg).padding(.vertical, 10)
                        .background(Capsule().fill(AppColors.primary))
                    }
                    .buttonStyle(.nhan)
                    .disabled(vm.dangSinhCauNoi)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
            }

            ForEach(Array(vm.cauNoi.enumerated()), id: \.offset) { i, p in
                theCau(i, p)
            }

            if let l = ghiAm.loi {
                Label(l, systemImage: "mic.slash")
                    .font(.footnote).foregroundColor(AppColors.error)
            }
        }
    }

    private func theCau(_ i: Int, _ p: CauNoiPhu) -> some View {
        let dangThu = ghiAm.dangThu == i
        let coBan = ghiAm.tep[i] != nil
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text("\(i + 1)")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(coBan ? AppColors.success : AppColors.primary))
                NoiDungThi(chu: p.text, coChu: 15)
            }
            if let a = p.imageUrl, !a.isEmpty {
                AnhCauHoi(duong: DuongDanThi.day(a)?.absoluteString ?? a, caoToiDa: 220)
            }
            HStack(spacing: Spacing.sm) {
                Button {
                    if dangThu { ghiAm.dungThu() } else { Task { await ghiAm.batDau(i) } }
                } label: {
                    Label(dangThu ? T("Dừng") : (coBan ? T("Thu lại") : T("Thu âm")),
                          systemImage: dangThu ? "stop.fill" : "mic.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(dangThu ? .white : AppColors.error)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(dangThu ? AppColors.error : AppColors.error.opacity(0.12)))
                }
                .buttonStyle(.nhan)
                .disabled(ghiAm.dangThu != nil && !dangThu)

                if dangThu {
                    // Thanh mức âm — thấy ngay micro có bắt được tiếng không.
                    Capsule().fill(AppColors.backgroundTertiary)
                        .frame(width: 60, height: 6)
                        .overlay(alignment: .leading) {
                            Capsule().fill(AppColors.error).frame(width: 60 * CGFloat(ghiAm.muc), height: 6)
                        }
                        .animation(.linear(duration: 0.2), value: ghiAm.muc)
                        .accessibilityHidden(true)
                    Text(String(format: "%d:%02d / %d:%02d", ghiAm.giayDaThu / 60, ghiAm.giayDaThu % 60,
                                GhiAmThi.tranGiay / 60, GhiAmThi.tranGiay % 60))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(AppColors.textSecondary)
                } else if coBan {
                    Button { ghiAm.phat(i) } label: {
                        Image(systemName: ghiAm.dangPhat == i ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ghiAm.dangPhat == i ? T("Dừng nghe lại") : T("Nghe lại bản thu"))
                    Label(T("Đã thu"), systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.success)
                    Spacer(minLength: 0)
                    Button(role: .destructive) { ghiAm.xoa(i) } label: {
                        Image(systemName: "trash").font(.footnote)
                    }
                    .accessibilityLabel(T("Xoá bản thu"))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .strokeBorder(dangThu ? AppColors.error : Color.clear, lineWidth: 1.5))
    }
}
#endif

// MARK: - Hướng dẫn + tệp cho sẵn

struct HuongDanDeView: View {
    let de: DeDangLam?
    let deGoc: DeThi
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ngonNguDe) private var ngonNgu

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(deGoc.ten(ngonNgu))
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let m = de?.description ?? deGoc.description, !m.isEmpty {
                    Text(m.tachSongNgu(ngonNgu))
                        .font(.subheadline).foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let u = de?.attachmentUrl ?? deGoc.attachmentUrl, !u.isEmpty {
                    TepDinhKemDe(duong: u, ten: de?.attachmentName ?? deGoc.attachmentName)
                }
                if let h = de?.instructions, !h.isEmpty {
                    NoiDungThi(chu: h, coChu: 15)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Hướng dẫn làm bài"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button(T("Xong")) { dismiss() } }
        }
    }
}

/// Tệp "Given" của đề PE: tải về máy rồi xem nhanh (Quick Look) hoặc chia
/// sẻ / lưu vào Tệp để mở ở máy tính.
struct TepDinhKemDe: View {
    let duong: String
    let ten: String?
    @Environment(\.ngonNguDe) private var ngonNgu
    @State private var tepMay: URL?
    @State private var xemNhanh: URL?
    @State private var dangTai = false
    @State private var loi: String?

    private var tenHien: String {
        (ten?.isEmpty == false ? ten! : T("Tải tệp đề (Given)|||Tải tệp đề (Given)")).tachSongNgu(ngonNgu)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tenHien).font(.subheadline.weight(.semibold)).foregroundColor(AppColors.textPrimary)
                    Text(DuongDanThi.day(duong)?.lastPathComponent ?? duong)
                        .font(.caption.monospaced()).foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: Spacing.sm) {
                if let u = tepMay {
                    Button { xemNhanh = u } label: {
                        Label(T("Xem"), systemImage: "eye").font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    ShareLink(item: u) {
                        Label(T("Lưu / chia sẻ"), systemImage: "square.and.arrow.up").font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button { Task { await tai() } } label: {
                        HStack(spacing: 6) {
                            if dangTai { ProgressView().controlSize(.small) }
                            Label(T("Tải về"), systemImage: "arrow.down.circle").font(.footnote.weight(.semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primary)
                    .disabled(dangTai)
                }
            }
            Text(T("Giải nén, làm bài trong IDE/VS Code, giữ nguyên tên tệp rồi nộp lại bằng .zip — hoặc gõ thẳng trong app."))
                .font(.caption2).foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            if let l = loi { Text(l).font(.caption).foregroundColor(AppColors.error) }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.primary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).strokeBorder(AppColors.primary.opacity(0.35), lineWidth: 1))
        #if os(iOS)
        .quickLookPreview($xemNhanh)
        #endif
    }

    private func tai() async {
        guard let u = DuongDanThi.day(duong) else { loi = T("Địa chỉ tệp không hợp lệ."); return }
        dangTai = true; defer { dangTai = false }
        loi = nil
        do {
            var req = URLRequest(url: u)
            if let token = StorageManager.shared.getAuthToken() {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (tam, resp) = try await URLSession.shared.download(for: req)
            if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
                loi = String(format: T("Tải tệp thất bại (mã %d)."), h.statusCode); return
            }
            let thuMuc = FileManager.default.temporaryDirectory.appendingPathComponent("tep-de-thi", isDirectory: true)
            try? FileManager.default.createDirectory(at: thuMuc, withIntermediateDirectories: true)
            let dich = thuMuc.appendingPathComponent(u.lastPathComponent.isEmpty ? "tep-de.zip" : u.lastPathComponent)
            try? FileManager.default.removeItem(at: dich)
            try FileManager.default.moveItem(at: tam, to: dich)
            tepMay = dich
            Haptics.xong()
        } catch { loi = error.localizedDescription }
    }
}

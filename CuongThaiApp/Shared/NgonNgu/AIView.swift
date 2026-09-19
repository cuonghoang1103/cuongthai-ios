import SwiftUI

// ════════════════════════════════════════════════════════════════
// HAI CÔNG CỤ AI: dịch · kiểm ngữ pháp
//
// ⚠️ Cả hai đòi tài khoản Pro/Max (`isProEffective` ở backend). Không xử
// riêng thì người dùng thường bấm vào và nhận một dòng lỗi thô — phải nói
// thẳng đây là tính năng Pro.
// ════════════════════════════════════════════════════════════════

private func laLoiPro(_ e: Error) -> Bool {
    let s = e.localizedDescription.lowercased()
    return s.contains("pro/max") || s.contains("pro / max") || s.contains("403")
}

private struct BangPro: View {
    let viec: String
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundColor(AppColors.accent)
            Text("\(viec) dành cho tài khoản Pro")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text("Các mục khác trong Ngoại ngữ vẫn dùng bình thường.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.accent.opacity(0.10)))
    }
}

// ── Dịch ────────────────────────────────────────────────────────

struct DichView: View {
    let ngonNgu: NgonNgu

    @State private var nhap = ""
    @State private var sangTiengNuocNgoai = true
    @State private var kq: KetQuaDich?
    @State private var dangChay = false
    @State private var loi: String?
    @State private var canPro = false
    @FocusState private var dangGo: Bool
    @ObservedObject private var doc = DocTu.shared

    private var nhan: (String, String) {
        sangTiengNuocNgoai ? ("Tiếng Việt", ngonNgu.name) : (ngonNgu.name, "Tiếng Việt")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                doiChieu

                TextEditor(text: $nhap)
                    .font(.system(size: 16))
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundCard))
                    .focused($dangGo)
                    .overlay(alignment: .topLeading) {
                        if nhap.isEmpty {
                            Text("Nhập nội dung cần dịch…")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textTertiary)
                                .padding(.horizontal, Spacing.sm + 5)
                                .padding(.top, Spacing.sm + 8)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    dangGo = false
                    Task { await dich() }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if dangChay { ProgressView().tint(.white) }
                        Text(dangChay ? "Đang dịch…" : "Dịch")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Capsule().fill(
                        nhap.trimmingCharacters(in: .whitespaces).isEmpty || dangChay
                        ? AppColors.primary.opacity(0.4) : AppColors.primary))
                }
                .disabled(nhap.trimmingCharacters(in: .whitespaces).isEmpty || dangChay)
                .buttonStyle(.plain)

                if canPro { BangPro(viec: "Dịch văn bản") }
                else if let l = loi {
                    Text(l).font(.system(size: 13)).foregroundColor(AppColors.error)
                }

                if let k = kq { ketQua(k); nutLuu(k) }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Dịch")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var doiChieu: some View {
        HStack(spacing: Spacing.sm) {
            Text(nhan.0).font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    sangTiengNuocNgoai.toggle(); kq = nil
                }
                Haptics.cham()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 28)
                    .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Đổi chiều dịch")
            Text(nhan.1).font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }
    }

    @ViewBuilder
    private func ketQua(_ k: KetQuaDich) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let t = k.translation, !t.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(alignment: .top) {
                        Text(t)
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textPrimary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        // Chỉ đọc khi kết quả là tiếng NƯỚC NGOÀI. Bộ đọc
                        // không có tiếng Việt, và ép nó đọc tiếng Việt bằng
                        // giọng Nhật thì ra một tràng vô nghĩa.
                        if sangTiengNuocNgoai, DocTu.doDuoc(ngonNgu.code) {
                            Button {
                                doc.doc(t, code: ngonNgu.code, id: -1)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 34, height: 30)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Nghe bản dịch")
                        }
                    }
                    if let r = k.reading, !r.isEmpty {
                        Text(r).font(.system(size: 14)).foregroundColor(AppColors.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard))
            }

            if let l = k.literal, !l.isEmpty { phu("Dịch sát nghĩa", l) }
            if let n = k.notes, !n.isEmpty { phu("Ghi chú", n) }
            if let a = k.alternatives, !a.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("CÁCH NÓI KHÁC")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textTertiary).kerning(0.5)
                    ForEach(a) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.text ?? "")
                                .font(.system(size: 15))
                                .foregroundColor(AppColors.textPrimary)
                                .textSelection(.enabled)
                            // Chính dòng này mới là thứ đáng học: nói RÕ khi
                            // nào nên dùng cách này thay vì cách kia.
                            if let n = p.note, !n.isEmpty {
                                Text(n)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundTertiary))
            }
        }
    }

    /// Lưu bản dịch: tiêu đề là câu NGUỒN, thân là bản dịch — mở sổ tay ra
    /// thấy ngay mình đã hỏi gì, chứ không phải một câu tiếng Nhật trơ trọi.
    @ViewBuilder
    private func nutLuu(_ k: KetQuaDich) -> some View {
        if let t = k.translation, !t.isEmpty {
            NutLuuSoTay(ngonNgu: ngonNgu, loai: .dich,
                        tieuDe: nhap, than: t,
                        cachDoc: k.reading, nghia: k.literal)
        }
    }

    private func phu(_ ten: String, _ chu: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ten.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.textTertiary).kerning(0.5)
            Text(chu).font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundTertiary))
    }

    private func dich() async {
        dangChay = true; loi = nil; canPro = false; kq = nil
        defer { dangChay = false }
        do {
            kq = try await APIClient.shared.request(
                .aiDich(code: ngonNgu.code, chu: nhap, sangTiengNuocNgoai: sangTiengNuocNgoai))
        } catch {
            if laLoiPro(error) { canPro = true } else { loi = error.localizedDescription }
        }
    }
}

// ── Kiểm ngữ pháp ───────────────────────────────────────────────

struct KiemNguPhapView: View {
    let ngonNgu: NgonNgu

    @State private var nhap = ""
    @State private var kq: KetQuaKiemNguPhap?
    @State private var dangChay = false
    @State private var loi: String?
    @State private var canPro = false
    @FocusState private var dangGo: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Viết một câu bằng \(ngonNgu.name), AI sẽ chỉ ra chỗ sai.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)

                TextEditor(text: $nhap)
                    .font(.system(size: 16))
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundCard))
                    .focused($dangGo)

                Button {
                    dangGo = false
                    Task { await kiem() }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if dangChay { ProgressView().tint(.white) }
                        Text(dangChay ? "Đang kiểm…" : "Kiểm tra")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Capsule().fill(
                        nhap.trimmingCharacters(in: .whitespaces).isEmpty || dangChay
                        ? AppColors.primary.opacity(0.4) : AppColors.primary))
                }
                .disabled(nhap.trimmingCharacters(in: .whitespaces).isEmpty || dangChay)
                .buttonStyle(.plain)

                if canPro { BangPro(viec: "Kiểm tra ngữ pháp") }
                else if let l = loi {
                    Text(l).font(.system(size: 13)).foregroundColor(AppColors.error)
                }

                if let k = kq {
                    ketQua(k)
                    if let c = k.corrected, !c.isEmpty {
                        NutLuuSoTay(ngonNgu: ngonNgu, loai: .kiemNguPhap,
                                    tieuDe: nhap, than: c, cachDoc: nil,
                                    nghia: k.issues?.compactMap { $0.suggestion }.joined(separator: " · "))
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Kiểm ngữ pháp")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func ketQua(_ k: KetQuaKiemNguPhap) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let d = k.score {
                HStack(spacing: Spacing.sm) {
                    Text("\(d)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(d >= 80 ? AppColors.success
                                       : d >= 50 ? AppColors.warning : AppColors.error)
                    Text("/ 100").font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
                    Spacer()
                }
            }

            // Nhận xét chung: backend vẫn gửi từ đầu, app cũ không khai nên
            // vứt đi mất — mà đây là phần người học đọc được nhiều nhất.
            if !k.nhanXet.isEmpty {
                NoiDungMarkdown(noiDung: k.nhanXet)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color(hex: k.mauKetLuan).opacity(0.12)))
            }

            if let c = k.corrected, !c.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CÂU ĐÃ SỬA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textTertiary).kerning(0.5)
                    Text(c).font(.system(size: 17)).foregroundColor(AppColors.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.success.opacity(0.12)))
            }

            if let ds = k.issues, !ds.isEmpty {
                ForEach(ds) { l in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(l.tenMuc)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: l.mauMuc)))
                        if let o = l.original, !o.isEmpty {
                            Text(o).font(.system(size: 15))
                                .foregroundColor(AppColors.textSecondary)
                                .strikethrough()
                        }
                        if let s = l.suggestion, !s.isEmpty {
                            Text(s).font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        if let e = l.explanation, !e.isEmpty {
                            Text(e).font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundCard))
                }
            } else if k.corrected != nil {
                Text("Không tìm thấy lỗi nào. 👏")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.success)
            }
        }
    }

    private func kiem() async {
        dangChay = true; loi = nil; canPro = false; kq = nil
        defer { dangChay = false }
        do {
            kq = try await APIClient.shared.request(.aiKiemNguPhap(code: ngonNgu.code, chu: nhap))
        } catch {
            if laLoiPro(error) { canPro = true } else { loi = error.localizedDescription }
        }
    }
}

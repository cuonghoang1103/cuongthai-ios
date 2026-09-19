import SwiftUI

/// Bảng hiện ra khi chạm vào một từ / một đoạn trong bài IELTS.
///
/// Thứ tự cố ý: **cái không tốn gì trước, cái gọi AI sau.**
///   1. Có trong `glossary` của bài → hiện nghĩa NGAY, không gọi mạng.
///   2. Nút đọc to — máy tự đọc, không gọi mạng.
///   3. Sáu câu hỏi đặt sẵn → mỗi câu một lượt AI.
///   4. Ô gõ câu hỏi tự do.
///
/// Gọi AI ngay khi mở bảng sẽ tốn một lượt model cho MỌI cú chạm nhầm, mà
/// chạm nhầm thì nhiều hơn chạm đúng khi đang đọc bằng ngón tay.
struct HoiVeChuView: View {
    let chu: String
    let boiCanh: String
    let tuKho: TuKho?

    @Environment(\.dismiss) private var dong
    @State private var dapAn: [String: String] = [:]
    @State private var dangHoi: String?
    @State private var cauTuGo = ""
    @State private var thieuKhoaAI = false

    private static let cacY: [(ma: String, ten: String, bt: String)] = [
        ("nghia", "Nghĩa là gì", "text.book.closed"),
        ("doc", "Đọc thế nào", "waveform"),
        ("dich", "Dịch cả câu", "character.bubble"),
        ("nguphap", "Ngữ pháp ở đây", "curlybraces"),
        ("day", "Dạy tôi phần này", "graduationcap"),
        ("dethi", "Hay ra dạng đề nào", "doc.badge.gearshape"),
    ]

    private var laMotTu: Bool {
        chu.split(separator: " ").count == 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    theChu
                    if let t = tuKho { theTuKho(t) }
                    luoiY
                    ForEach(Self.cacY, id: \.ma) { y in
                        if let d = dapAn[y.ma] { theDapAn(T(y.ten), d) }
                    }
                    if let d = dapAn["tudo"] { theDapAn(T("Trả lời"), d) }
                    oGoCauHoi
                }
                .padding(Spacing.md)
                .padding(.bottom, 40)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(laMotTu ? T("Tra từ") : T("Hỏi về đoạn này"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } } }
        }
        #if os(iOS)
        .presentationDetents(laMotTu ? [.medium, .large] : [.large])
        #endif
    }

    // MARK: Chữ đã chọn

    private var theChu: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(chu)
                .font(laMotTu ? .system(size: 26, weight: .semibold) : .bodyLarge)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.sm) {
                Button { DocTu.shared.doc(chu, code: "en") } label: {
                    Label(T("Đọc to"), systemImage: "speaker.wave.2.fill").font(.captionBold)
                }
                .buttonStyle(.plain).foregroundStyle(AppColors.primary)

                Button { DocTu.shared.doc(chu, code: "en", chamHon: true) } label: {
                    Label(T("Đọc chậm"), systemImage: "tortoise.fill").font(.captionBold)
                }
                .buttonStyle(.plain).foregroundStyle(AppColors.secondary)

                Spacer()
                #if os(iOS)
                Button { UIPasteboard.general.string = chu } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(AppColors.textTertiary)
                #endif
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    /// Từ này đã có sẵn trong phần "Từ khó" của bài — khỏi gọi AI.
    private func theTuKho(_ t: TuKho) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(T("Có trong từ khó của bài"), systemImage: "checkmark.seal.fill")
                .font(.caption2).foregroundStyle(AppColors.success)
            Text(t.ipa).font(.caption).foregroundStyle(AppColors.textTertiary)
            Text(t.vi).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.success.opacity(0.10))
        .cornerRadius(CornerRadius.large)
    }

    // MARK: Nút câu hỏi

    private var luoiY: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.sm)], spacing: Spacing.sm) {
            ForEach(Self.cacY, id: \.ma) { y in
                Button { Task { await hoi(y.ma) } } label: {
                    HStack(spacing: 6) {
                        if dangHoi == y.ma {
                            ProgressView().scaleEffect(0.7).frame(width: 16)
                        } else {
                            Image(systemName: y.bt).font(.caption).frame(width: 16)
                        }
                        Text(T(y.ten)).font(.bodySmall).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(dapAn[y.ma] != nil ? AppColors.textTertiary : AppColors.textPrimary)
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(CornerRadius.medium)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(dangHoi != nil)
            }
        }
    }

    /// Gỡ dấu markdown còn sót.
    ///
    /// Lời dặn "không dùng markdown" trong prompt ăn phần lớn lượt, nhưng
    /// KHÔNG phải mọi lượt — và một câu trả lời có `**từ**` giữa câu trông
    /// như lỗi hiển thị. Gỡ ở đây rẻ hơn là tin vào lời dặn.
    private static func goDau(_ s: String) -> String {
        s.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    private func theDapAn(_ ten: String, _ chu: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(ten).font(.captionBold).foregroundStyle(AppColors.primary)
            Text(Self.goDau(chu)).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var oGoCauHoi: some View {
        HStack(spacing: Spacing.sm) {
            TextField(T("Hỏi điều khác…"), text: $cauTuGo, axis: .vertical)
                .lineLimit(1...3)
                .padding(.horizontal, Spacing.sm + 2).padding(.vertical, Spacing.sm)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.large)
            Button { Task { await hoi(nil) } } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 28))
                    .foregroundStyle(guiDuoc ? AppColors.primary : AppColors.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!guiDuoc)
        }
    }

    private var guiDuoc: Bool {
        dangHoi == nil && cauTuGo.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    // MARK: Gọi

    private func hoi(_ y: String?) async {
        let khoa = y ?? "tudo"
        // Đã hỏi rồi thì hiện lại đáp án cũ, không gọi lần hai. Bấm hai lần
        // cùng một nút là chuyện thường khi mạng chậm, và mỗi lần là một lượt
        // model có tính tiền.
        if dapAn[khoa] != nil, y != nil { return }
        dangHoi = khoa
        defer { dangHoi = nil }

        var than: [String: Any] = ["chu": chu, "boiCanh": boiCanh]
        if let y { than["y"] = y } else { than["cauHoi"] = cauTuGo.trimmingCharacters(in: .whitespacesAndNewlines) }

        do {
            let kq: TraLoiHoiChu = try await APIClient.shared.request(.ieltsHoiAI(than))
            if let t = kq.traLoi, !t.isEmpty {
                dapAn[khoa] = t
                if y == nil { cauTuGo = "" }
            } else if kq.lyDo == "ai_unavailable" {
                thieuKhoaAI = true
                dapAn[khoa] = T("AI đang tắt trên máy chủ. Phần “Từ khó” và bản dịch của bài vẫn dùng được.")
            }
        } catch {
            dapAn[khoa] = error.localizedDescription
        }
    }
}

struct TraLoiHoiChu: Decodable {
    let traLoi: String?
    let lyDo: String?
}

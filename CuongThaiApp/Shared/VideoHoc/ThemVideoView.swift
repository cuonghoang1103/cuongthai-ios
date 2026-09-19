#if os(iOS)
import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════
// THÊM VIDEO — dán link YouTube/TikTok
//
// Máy chủ lấy phụ đề bằng `yt-dlp` rồi làm sạch (phụ đề tự động của YouTube
// chạy kiểu cửa sổ trượt, không làm sạch thì 70% chữ bị lặp). Việc đó mất
// 10-60 giây tuỳ video dài, nên màn này phải nói rõ đang làm gì — một vòng
// quay câm 40 giây là thứ người ta bấm huỷ.
// ════════════════════════════════════════════════════════════════

struct ThemVideoView: View {
    /// Gọi lại sau khi thêm xong để màn duyệt nạp lại.
    let xong: () async -> Void

    @Environment(\.dismiss) private var dong
    @State private var lien = ""
    @State private var dangThem = false
    @State private var loi: String?
    @State private var ketQua: VideoDaThem?
    @State private var nhom: NhomLonChon? = nil

    /// Link đã dán sẵn từ Share Extension (nếu có).
    init(lienSan: String? = nil, xong: @escaping () async -> Void) {
        self.xong = xong
        _lien = State(initialValue: lienSan ?? "")
    }

    private var hopLe: Bool {
        let s = lien.lowercased()
        return s.contains("youtube.com") || s.contains("youtu.be")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "link").foregroundStyle(AppColors.textTertiary)
                        TextField(T("Dán link YouTube"), text: $lien)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .disabled(dangThem)
                        if !lien.isEmpty {
                            Button { lien = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        if let s = UIPasteboard.general.string { lien = s }
                    } label: {
                        Label(T("Dán từ bộ nhớ tạm"), systemImage: "doc.on.clipboard")
                    }
                    .disabled(dangThem)
                } header: {
                    Text(T("Link video"))
                } footer: {
                    if !lien.isEmpty && !hopLe {
                        Text(T("Hiện chỉ nhận link YouTube. TikTok chưa dùng được: trình phát nhúng của họ không cho tua theo phụ đề nên chữ sẽ không khớp với tiếng."))
                            .foregroundStyle(AppColors.error)
                    }
                }

                Section {
                    // Chọn nhóm LÚC THÊM, không bắt vào sửa sau: video giải
                    // trí mà rơi vào "Khác" thì lần sau tìm không ra, và
                    // không ai quay lại dọn.
                    Picker(T("Xếp vào nhóm"), selection: $nhom) {
                        Text(T("Tự đoán theo YouTube")).tag(nil as NhomLonChon?)
                        ForEach(NhomLonChon.allCases) { n in
                            Label(n.ten, systemImage: n.icon).tag(n as NhomLonChon?)
                        }
                    }
                    .disabled(dangThem)
                } header: {
                    Text(T("Danh mục"))
                } footer: {
                    Text(T("Hoạt hình, nhạc, lịch sử… nằm riêng khỏi Academy để xem giải trí mà vẫn nghe tiếng Anh."))
                }

                Section {
                    Button {
                        Task { await them() }
                    } label: {
                        HStack {
                            if dangThem {
                                ProgressView().controlSize(.small)
                                Text(T("Đang lấy phụ đề…"))
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text(T("Thêm video"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hopLe || dangThem)
                    .listRowBackground(Color.clear)
                }

                if dangThem {
                    Section {
                        Label(T("Video dài có thể mất 30-60 giây. Cứ để màn này mở."),
                              systemImage: "clock")
                            .font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                }

                if let l = loi {
                    Section {
                        Label(l, systemImage: "exclamationmark.triangle.fill")
                            .font(.bodySmall).foregroundStyle(AppColors.error)
                    }
                }

                if let k = ketQua {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(T("Đã thêm"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.success)
                            Text(k.tieuDe).font(.bodyMedium)
                                .foregroundStyle(AppColors.textPrimary)
                            Text(String(format: T("%d câu phụ đề · %d từ"), k.soCau, k.soTu))
                                .font(.caption).foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Label(T("Cách nhanh hơn: chia sẻ thẳng từ app"), systemImage: "square.and.arrow.up")
                            .font(.bodySmall.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(T("Trong app YouTube: mở video → Chia sẻ → chọn CuongThai. Video sẽ tự vào đây."))
                            .font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text(T("Mẹo"))
                } footer: {
                    Text(T("Video phải có phụ đề (kể cả phụ đề tự động) thì mới học được. Máy chủ không tải video về — vẫn xem bằng trình phát chính thức."))
                }
            }
            .navigationTitle(T("Thêm video"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Đóng")) { dong() }.disabled(dangThem)
                }
            }
        }
    }

    private func them() async {
        dangThem = true
        loi = nil
        ketQua = nil
        defer { dangThem = false }
        do {
            let k = try await VideoHocAPI.themVideo(
                url: lien.trimmingCharacters(in: .whitespacesAndNewlines),
                nhomLon: nhom?.rawValue)
            ketQua = k
            lien = ""
            await xong()
        } catch {
            loi = error.localizedDescription
        }
    }
}
#endif

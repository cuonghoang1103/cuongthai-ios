#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// HỌC TIẾNG ANH BẰNG VIDEO — danh mục → danh sách → màn học
// ════════════════════════════════════════════════════════════════

struct VideoHocView: View {
    @State private var danhMuc: [DanhMucVideo] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var tim = ""

    private var loc: [DanhMucVideo] {
        let t = tim.trimmingCharacters(in: .whitespaces).lowercased()
        return t.isEmpty ? danhMuc : danhMuc.filter { $0.title.lowercased().contains(t) }
    }

    private var tongVideo: Int { danhMuc.reduce(0) { $0 + $1.soVideo } }

    var body: some View {
        Group {
            if dangTai {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let l = loi {
                KhungTrongTien(bieuTuong: "wifi.slash", tieuDe: T("Không tải được"), moTa: l)
            } else if danhMuc.isEmpty {
                KhungTrongTien(bieuTuong: "play.rectangle",
                               tieuDe: T("Chưa có video nào có phụ đề"),
                               moTa: T("Phụ đề được nạp lúc deploy. Thử lại sau lần deploy tới."))
            } else {
                danhSach
            }
        }
        .navigationTitle(T("Học bằng video"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $tim, prompt: T("Tìm chủ đề"))
        .task { await nap() }
    }

    private var danhSach: some View {
        List {
            Section {
                // Nói TỔNG ngay đầu: người học cần biết kho to cỡ nào trước
                // khi quyết định có đầu tư thời gian vào đây không.
                Text(String(format: T("%d video tiếng Anh có phụ đề, chia theo môn."), tongVideo))
                    .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
            }
            .listRowBackground(Color.clear)

            ForEach(loc) { d in
                NavigationLink { DanhSachVideoView(danhMuc: d) } label: {
                    HStack(spacing: Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.primary.opacity(0.14))
                                .frame(width: 52, height: 52)
                            Image(systemName: "play.rectangle.fill")
                                .font(.title3).foregroundStyle(AppColors.primary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.title).font(.bodyMedium)
                                .foregroundStyle(AppColors.textPrimary).lineLimit(2)
                            Text("\(d.soVideo) video")
                                .font(.caption).foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func nap() async {
        dangTai = true
        defer { dangTai = false }
        do { danhMuc = try await VideoHocAPI.danhMuc() }
        catch { loi = error.localizedDescription }
    }
}

// MARK: - Video trong một môn

struct DanhSachVideoView: View {
    let danhMuc: DanhMucVideo

    @State private var ds: [VideoHoc] = []
    @State private var dangTai = true

    var body: some View {
        List {
            if dangTai { ProgressView().frame(maxWidth: .infinity) }
            ForEach(ds) { v in
                NavigationLink { ManHocVideoView(video: v) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(v.tieuDe).font(.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(v.moTaNgan).font(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(danhMuc.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            dangTai = true
            defer { dangTai = false }
            ds = (try? await VideoHocAPI.videoCuaKhoa(danhMuc.courseId)) ?? []
        }
    }
}
#endif

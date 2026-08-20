import SwiftUI
#if os(iOS)
import PhotosUI
#endif

// ════════════════════════════════════════════════════════════════
// HÀNG TIN (stories) — vòng tròn ở đầu hộp thư
//
// `/stories/feed` trả MỘT tin mới nhất cho mỗi người. Bấm vào một vòng thì mới
// gọi `/stories/user/:id` để lấy đủ tin của người đó — tải sẵn hết ngay từ đầu
// là kéo về hàng chục ảnh mà người dùng có thể không mở cái nào.
// ════════════════════════════════════════════════════════════════

struct HangTinView: View {
    @StateObject private var vm = HangTinViewModel()
    @State private var dangMo: Tin?
    #if os(iOS)
    @State private var anhChon: [PhotosPickerItem] = []
    #endif

    var body: some View {
        Group {
            if vm.dangTai && vm.ds.isEmpty {
                // Khung xương thay vì để trống: hàng tin nằm trên cùng, để
                // trống rồi bung ra làm cả danh sách hội thoại nhảy xuống.
                hangXuong
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        oTinCuaBan
                        ForEach(vm.ds) { t in
                            Button {
                                Haptics.cham()
                                dangMo = t
                            } label: {
                                oTin(t)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 10)
                }
            }
        }
        .task { await vm.tai() }
        #if os(iOS)
        .onChange(of: anhChon) { _, moi in
            Task { await vm.dangTin(moi); anhChon = [] }
        }
        .fullScreenCover(item: $dangMo) { t in
            XemTinView(tinDauTien: t) { Task { await vm.tai() } }
        }
        #endif
        .alert("Tin", isPresented: .constant(vm.loi != nil)) {
            Button("OK") { vm.loi = nil }
        } message: { Text(vm.loi ?? "") }
    }

    private var hangXuong: some View {
        HStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(spacing: 5) {
                    Circle().fill(AppColors.backgroundTertiary).frame(width: 62, height: 62)
                    Capsule().fill(AppColors.backgroundTertiary).frame(width: 44, height: 9)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .redacted(reason: .placeholder)
    }

    private var oTinCuaBan: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(url: AppState.shared.currentUser?.avatarUrl, size: 62)
                    .overlay(Circle().stroke(AppColors.border, lineWidth: 1))
                if vm.dangDang {
                    Circle().fill(.black.opacity(0.45)).frame(width: 62, height: 62)
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.onPrimary, AppColors.primary)
                        .background(Circle().fill(AppColors.backgroundPrimary).frame(width: 18, height: 18))
                        .offset(x: 2, y: 2)
                }
            }
            Text("Tin của bạn")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 68)
        .overlay {
            #if os(iOS)
            PhotosPicker(selection: $anhChon, maxSelectionCount: 1, matching: .images) {
                Color.clear
            }
            .disabled(vm.dangDang)
            #endif
        }
    }

    private func oTin(_ t: Tin) -> some View {
        VStack(spacing: 5) {
            UserAvatarView(url: t.user?.avatarUrl, size: 62)
                .overlay(
                    // Vòng gradient khi CHƯA xem, vòng xám mảnh khi đã xem —
                    // đúng quy ước Instagram/Messenger, người dùng đọc được
                    // ngay mà không cần chữ.
                    Circle().strokeBorder(
                        t.daXem
                            ? AnyShapeStyle(AppColors.border)
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: 0xF9CE34), Color(hex: 0xEE2A7B), Color(hex: 0x6228D7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)),
                        lineWidth: t.daXem ? 1 : 2.5)
                    .padding(-3)
                )
            Text(t.tenNguoi)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 68)
    }
}

@MainActor
final class HangTinViewModel: ObservableObject {
    @Published var ds: [Tin] = []
    @Published var dangTai = false
    @Published var dangDang = false
    @Published var loi: String?

    func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            ds = try await APIClient.shared.request(.layHangTin)
        } catch {
            // Hàng tin hỏng KHÔNG được làm hỏng cả hộp thư — nuốt lỗi, để
            // hàng trống, danh sách hội thoại vẫn chạy bình thường.
            ds = []
        }
    }

    #if os(iOS)
    func dangTin(_ items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        dangDang = true
        defer { dangDang = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            loi = "Không đọc được ảnh này."
            return
        }
        do {
            // Tin dùng `/files/upload` (trả URL) chứ KHÔNG phải
            // `/messages/upload` (trả fileId) — `POST /stories` nhận `mediaUrl`
            // dạng chuỗi, không nhận id file.
            let loai = item.supportedContentTypes.first
            let tep = try await APIClient.shared.upload(
                data: data,
                fileName: "tin.\(loai?.preferredFilenameExtension ?? "jpg")",
                mimeType: loai?.preferredMIMEType ?? "image/jpeg",
                category: "social")
            let _: Tin = try await APIClient.shared
                .request(.taoTin(mediaUrl: tep.url, mediaType: "IMAGE", caption: nil))
            await tai()
        } catch {
            loi = error.localizedDescription
        }
    }
    #endif
}

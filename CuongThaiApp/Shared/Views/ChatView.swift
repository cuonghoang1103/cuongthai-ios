import SwiftUI
import Combine
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Chat View
struct ChatView: View {
    let thread: MessageThread
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var showAttachmentOptions = false
    @State private var showUserProfile = false
    @State private var dangTimKiem = false
    @State private var tuKhoa = ""
    @State private var hienEmoji = false
    @State private var thongBaoTat: String?
    /// Apple 1.2: chặn đối phương ngay trong hội thoại (cạnh "Báo cáo").
    @ObservedObject private var kiemDuyet = ModerationStore.shared
    @State private var hoiChanDoiPhuong = false
    #if os(iOS)
    @State private var anhDangChon: [PhotosPickerItem] = []
    @State private var videoDangChon: [PhotosPickerItem] = []
    #endif
    @State private var hienChonTep = false
    @State private var hienChonGif = false
    /// Tin đang bị nhấn giữ — khung chat vẽ lớp phủ kiểu Messenger cho nó.
    @State private var tinDangGiu: Message?
    @State private var traLoiTin: Message?
    @State private var hienDatBietDanh = false
    @State private var hienChonNen = false
    @State private var hienMayAnh = false
    /// Bốn nút tắt thu lại khi đang gõ, bung ra khi ô chữ trống.
    @State private var dangGo = false
    @StateObject private var ghiAm = GhiAmThoai()
    @State private var nen: NenChat = .macDinh
    @State private var bietDanhMoi = ""
    /// Bản hội thoại có thể ĐỔI tại chỗ — `thread` truyền vào là `let`, mà đặt
    /// biệt danh xong thì tiêu đề phải đổi ngay chứ không đợi mở lại màn.
    @State private var hoiThoaiSua: MessageThread?
    @StateObject private var viTri = DoViTri()
    @ObservedObject private var realtime = RealtimeClient.shared
    @FocusState private var isInputFocused: Bool
    /// Nút quay lại tự vẽ — thanh hệ thống đã ẩn nên không còn nút của nó.
    @Environment(\.dismiss) private var dismiss
    /// Người dùng có đang nhìn phần cuối hội thoại không. Quyết định cả việc
    /// tự cuộn khi có tin mới lẫn việc hiện nút nhảy-về-cuối.
    @State private var dangODay = true
    @State private var daCuonLanDau = false


    /// Hội thoại đang dùng để hiển thị: bản đã sửa nếu có, không thì bản gốc.
    private var hoiThoai: MessageThread { hoiThoaiSua ?? thread }

    var body: some View {
        VStack(spacing: 0) {
            thanhDau
            if dangTimKiem { thanhTimKiem }
            messagesList
                .background(
                    // Chỉ phủ sau KHUNG TIN. Phủ cả ô nhập thì chữ đang gõ nằm
                    // trên gradient và mất tương phản.
                    nen.lop.ignoresSafeArea(edges: .horizontal)
                )
            if hienEmoji { bangEmoji }
            inputBar
        }
        .modifier(LopPhuGiuTin(tinDangGiu: $tinDangGiu, viewModel: viewModel,
                               hanhDong: hanhDongCho))
        .background(AppColors.backgroundPrimary)
        // Thanh đầu TỰ VẼ, không dùng `.toolbar`.
        //
        // ⚠️ iOS 26 đổi thanh điều hướng sang kiểu kính và **bọc MỖI mục
        // trong một viên nang riêng**. Nút quay lại một viên, avatar+tên một
        // viên, hai nút phải một viên — nhìn thành ba cục xám rời rạc, tên
        // người bị bóp cụt vì vùng bên trái có bề ngang giới hạn, và tin nhắn
        // lộ qua nền trong suốt. Đo thật trên iPhone 16 Pro Max / iOS 27.
        //
        // Messenger đặt tất cả trong MỘT hàng liền. Muốn vậy thì phải bỏ hẳn
        // thanh hệ thống — không có tham số nào bảo nó đừng bọc viên nang.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showUserProfile) {
            if let userId = thread.peer?.id {
                UserProfileView(userId: userId)
            }
        }
        .modifier(VongDoiChat(thread: thread, viewModel: viewModel, realtime: realtime,
                              messageText: $messageText, thongBaoTat: $thongBaoTat))
        .modifier(DinhKemChat(hienChonTep: $hienChonTep, guiTep: guiTep))
        #if os(iOS)
        .onChange(of: anhDangChon) { _, moi in
            Task { await guiAnhDaChon(moi) }
        }
        .onChange(of: videoDangChon) { _, moi in
            Task { await guiVideoDaChon(moi) }
        }
        #endif
        .alert(hoiThoai.bietDanh == nil ? "Đặt biệt danh" : "Đổi biệt danh",
               isPresented: $hienDatBietDanh) {
            TextField("Biệt danh", text: $bietDanhMoi)
                .oKhongTuSua()
            Button("Lưu") { Task { await luuBietDanh(bietDanhMoi) } }
            if hoiThoai.bietDanh != nil {
                Button("Xoá biệt danh", role: .destructive) { Task { await luuBietDanh("") } }
            }
            Button("Huỷ", role: .cancel) { }
        } message: {
            Text("Chỉ MÌNH BẠN thấy biệt danh này. Người kia vẫn thấy tên thật của họ.")
        }
        .modifier(MayAnhVaGhiAm(hienMayAnh: $hienMayAnh, dangGo: $dangGo,
                                coChu: coChu, ghiAm: ghiAm, chup: chupXong))
        .sheet(isPresented: $hienChonNen) {
            BangChonNen(dangChon: $nen) { KhoNenChat.ghi(thread.id, $0) }
        }
        .onAppear { nen = KhoNenChat.doc(thread.id) }
        .sheet(isPresented: $hienChonGif) {
            BangChonGif { url in
                Task { await viewModel.guiGif(url) }
                withAnimation { showAttachmentOptions = false }
            }
        }
        .alert("Vị trí", isPresented: .constant(viTri.loi != nil)) {
            Button("OK") { viTri.loi = nil }
        } message: {
            Text(viTri.loi ?? "")
        }
    }

    #if os(iOS)
    /// Video đi CÙNG đường tải lên với ảnh, nên vẫn dính trần 10MB của
    /// `/messages/upload`. Kiểm cỡ ở client để báo trước, thay vì tải lên rồi
    /// mới nhận 413 sau vài chục giây.
    private func guiVideoDaChon(_ items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.error = "Không đọc được video này."
            videoDangChon = []
            return
        }
        guard data.count <= 10 * 1024 * 1024 else {
            viewModel.error = "Video nặng \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) — máy chủ chỉ nhận tối đa 10MB."
            videoDangChon = []
            return
        }
        let loai = item.supportedContentTypes.first
        let duoi = loai?.preferredFilenameExtension ?? "mp4"
        let mime = loai?.preferredMIMEType ?? "video/mp4"
        await viewModel.guiAnh([(data, "video.\(duoi)", mime)],
                               kem: messageText.trimmingCharacters(in: .whitespacesAndNewlines))
        messageText = ""
        videoDangChon = []
        withAnimation { showAttachmentOptions = false }
    }
    #endif

    /// Máy chủ cắt còn 100 ký tự và từ chối đặt cho chính mình; alias rỗng =
    /// xoá biệt danh.
    private func luuBietDanh(_ chu: String) async {
        guard let peerId = hoiThoai.peer?.id else { return }
        let sach = chu.trimmingCharacters(in: .whitespaces)
        do {
            let _: BietDanhTraVe = try await APIClient.shared
                .request(.datBietDanh(threadId: thread.id, targetId: peerId, alias: sach))
            if sach.isEmpty {
                // Máy chủ THAY `displayName` bằng biệt danh, nên khi xoá thì
                // app không còn biết tên thật là gì — phải hỏi lại. Đường
                // `/threads/:id` không áp biệt danh nên nó trả đúng tên thật.
                if let lai: MessageThread = try? await APIClient.shared
                    .request(.layHoiThoai(threadId: thread.id)) {
                    hoiThoaiSua = lai
                } else {
                    hoiThoaiSua = hoiThoai.doiBietDanh(nil)
                }
            } else {
                hoiThoaiSua = hoiThoai.doiBietDanh(sach)
            }
            // Báo cho màn danh sách. Nó giữ mảng hội thoại riêng và không có
            // cách nào biết ta vừa đổi tên ở đây.
            AppState.shared.bietDanhDoi.send(
                (threadId: thread.id, ten: hoiThoaiSua?.displayName ?? sach))
            Haptics.xong()
        } catch {
            thongBaoTat = error.localizedDescription
        }
    }

    private func guiViTri() async {
        guard let toado = await viTri.doMotLan() else { return }
        await viewModel.guiViTri(vido: toado.latitude, kinhdo: toado.longitude)
        withAnimation { showAttachmentOptions = false }
    }

    // ── Thanh đầu ───────────────────────────────────────────────
    //
    // Một hàng: quay lại · avatar · tên + trạng thái · gọi · menu.
    // Đúng thứ tự của Messenger, và quan trọng hơn là đúng MỘT khung.
    private var thanhDau: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    // Vùng chạm 44pt theo hướng dẫn của Apple — mũi tên vẽ ra
                    // chỉ rộng ~12pt, để trần thì rất hay bấm trượt.
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Quay lại")

            Button {
                showUserProfile = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    UserAvatarView(url: hoiThoai.avatarUrl, size: 38)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(hoiThoai.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        // Trước đây dòng này ghi cứng "Đang hoạt động" cho mọi
                        // người, kể cả người đã offline hàng tháng — một lời
                        // nói dối nhỏ mà người dùng phát hiện ngay.
                        Text(dongTrangThai)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    // Tên dài phải CO LẠI chứ không được đẩy hai nút phải ra
                    // ngoài màn hình.
                    .layoutPriority(-1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Có `peer` là gọi được — kể cả hội thoại `ADMIN`.
            //
            // ⚠️ Bản đầu tôi chặn thêm `type == "USER"` với lý do "ADMIN là
            // kênh hỗ trợ, không có người kia cố định". SAI: hội thoại ADMIN
            // có đủ `userId` và `adminUserId`, máy chủ tính `peer` cho cả hai
            // loại, và `call.socket.ts` KHÔNG hề phân biệt — nó chỉ kiểm
            // người gọi có trong phòng không. Tôi tự bịa ra một giới hạn máy
            // chủ không có, và nó đội lốt "hạn chế có chủ ý" nên nhìn mã
            // không ai thấy sai. Người dùng phát hiện: hội thoại này mất nút
            // gọi trong khi hội thoại khác vẫn có.
            //
            // Gọi VIDEO chưa có nút: nút không ăn là thứ App Store đánh rớt
            // theo 2.1.
            if let ban = hoiThoai.peer {
                Button {
                    BoGoi.shared.batDauGoi(
                        threadId: hoiThoai.id,
                        toUserId: ban.id,
                        ten: hoiThoai.displayName,
                        anh: hoiThoai.avatarUrl,
                    )
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 19))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 38, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Gọi thoại cho \(hoiThoai.displayName)")
            }

            Menu {
            Button {
                withAnimation { dangTimKiem.toggle() }
                if !dangTimKiem { tuKhoa = "" }
            } label: {
                Label(dangTimKiem ? "Đóng tìm kiếm" : "Tìm trong hội thoại",
                      systemImage: "magnifyingglass")
            }

            Button {
                hienChonNen = true
            } label: {
                Label("Đổi hình nền", systemImage: "photo.on.rectangle.angled")
            }

            Button {
                bietDanhMoi = hoiThoai.bietDanh ?? ""
                hienDatBietDanh = true
            } label: {
                Label(hoiThoai.bietDanh == nil ? "Đặt biệt danh" : "Đổi biệt danh",
                      systemImage: "textformat.abc")
            }

            Divider()

            Menu {
                Button("15 phút") { Task { await tatThongBao(15) } }
                Button("1 giờ") { Task { await tatThongBao(60) } }
                Button("8 giờ") { Task { await tatThongBao(480) } }
                Button("1 ngày") { Task { await tatThongBao(1440) } }
                Button("Cho tới khi bật lại") { Task { await tatThongBao(nil) } }
                Divider()
                Button("Bật lại thông báo") { Task { await tatThongBao(0) } }
            } label: {
                Label("Tắt thông báo", systemImage: "bell.slash")
            }

            Button(role: .destructive) {
                Task { await baoCaoHoiThoai() }
            } label: {
                Label("Báo cáo hội thoại", systemImage: "flag")
            }

            // Chỉ hội thoại 1-1 với người dùng thật — kênh hỗ trợ (ADMIN)
            // không có ai để chặn.
            if hoiThoai.laNhanRieng, let peerId = hoiThoai.peer?.id {
                if kiemDuyet.blockedUserIds.contains(peerId) {
                    Button {
                        Task {
                            do {
                                try await kiemDuyet.unblock(userId: peerId)
                                thongBaoTat = T("Đã bỏ chặn") + " \(hoiThoai.displayName)"
                            } catch { thongBaoTat = error.localizedDescription }
                        }
                    } label: {
                        Label(T("Bỏ chặn"), systemImage: "hand.raised.slash")
                    }
                } else {
                    Button(role: .destructive) {
                        hoiChanDoiPhuong = true
                    } label: {
                        Label(T("Chặn") + " \(hoiThoai.displayName)", systemImage: "hand.raised")
                    }
                }
            }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Tuỳ chọn hội thoại")
            // Gắn vào CHÍNH cái Menu, không gắn vào thân màn — thân màn đã có
            // sẵn nhiều sheet/alert.
            .confirmationDialog(T("Chặn") + " \(hoiThoai.displayName)?",
                                isPresented: $hoiChanDoiPhuong, titleVisibility: .visible) {
                Button(T("Chặn"), role: .destructive) {
                    guard let peerId = hoiThoai.peer?.id else { return }
                    Task {
                        do {
                            try await kiemDuyet.block(userId: peerId)
                            Haptics.xong()
                            thongBaoTat = T("Đã chặn") + " \(hoiThoai.displayName)"
                        } catch { thongBaoTat = error.localizedDescription }
                    }
                }
                Button(T("Huỷ"), role: .cancel) { }
            } message: {
                Text(T("Người này sẽ không nhắn tin được cho bạn, và bài viết, tin, bình luận của họ được ẩn. Có thể bỏ chặn trong Cài đặt → Danh sách chặn."))
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 52)
        // Nền ĐẶC. Bỏ thanh hệ thống rồi thì không còn lớp mờ nào của nó nữa —
        // để trong suốt là tin nhắn cuộn lên nằm đè lên tên người.
        .background(AppColors.backgroundSecondary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColors.divider).frame(height: 0.5)
        }
    }

    private var doiPhuongDangGo: Bool {
        guard let tap = realtime.dangGo[thread.id] else { return false }
        return tap.contains { $0 != AppState.shared.currentUser?.id }
    }

    /// Trạng thái của người đối diện, gộp hai nguồn.
    ///
    /// ⚠️ Bản cũ CHỈ nhìn socket, nên vừa mở app là ai cũng "Ngoại tuyến":
    /// `presence:update` chỉ phát khi người kia ĐỔI trạng thái, mà lúc mình
    /// vừa nối thì không có ai vừa đổi cả. `lastActiveAt` lấp đúng khoảng đó.
    private var ttHoatDong: TrangThaiHoatDong.KetQua {
        let id = thread.peer?.id
        return TrangThaiHoatDong.tinh(
            mocHoatDong: TrangThaiHoatDong.docMoc(thread.peer?.lastActiveAt),
            socketBaoOnline: id.map { realtime.truyenTuyen.contains($0) } ?? false)
    }

    private var dongTrangThai: String {
        if doiPhuongDangGo { return "đang gõ…" }

        // ⚠️ KHÔNG in `realtime.trangThai.moTa` ra đây.
        //
        // `TrangThai.chuaNoi.moTa` là chuỗi "Ngoại tuyến", nhưng nó nói về
        // SOCKET CỦA MÌNH chứ không nói gì về người kia. Đặt nó ngay dưới tên
        // một người là biến trạng thái mạng của mình thành lời khẳng định về
        // họ — và đó là lời khẳng định mình không có cơ sở nào để đưa ra.
        // Đo thật 17/09/2026: máy ảo chưa nối được socket, và mọi hội thoại
        // đều hiện "Ngoại tuyến" kể cả với người vừa nhắn xong.
        //
        // Chưa nối được thì vẫn còn `lastActiveAt` từ API — dùng nó. Không có
        // nốt thì im, chứ không đoán.
        if realtime.trangThai == .dangNoi && ttHoatDong.chu.isEmpty {
            return "Đang kết nối…"
        }
        // Rỗng = người kia đã tắt công tắc hiện trạng thái, hoặc chưa có dữ
        // liệu. Im lặng, không được suy ra "Ngoại tuyến".
        return ttHoatDong.chu
    }

    private var mauTrangThai: Color {
        if doiPhuongDangGo { return AppColors.primary }
        return ttHoatDong.trucTuyen ? AppColors.success : AppColors.textTertiary
    }

    /// Các nhóm tin sau khi lọc theo từ khoá. Lọc ngay trên máy vì backend
    /// không có endpoint tìm trong hội thoại — chỉ tìm được trong số tin ĐÃ
    /// tải; thanh tìm kiếm nói rõ điều đó thay vì im lặng để người dùng tưởng
    /// đã tìm hết lịch sử.
    private var nhomHienThi: [MessageGroup] {
        let goc = viewModel.groupedMessages
        let khoa = tuKhoa.trimmingCharacters(in: .whitespaces)
        guard !khoa.isEmpty else { return goc }
        return goc.compactMap { nhom in
            let khop = nhom.messages.filter { $0.noiDung.localizedCaseInsensitiveContains(khoa) }
            return khop.isEmpty ? nil : MessageGroup(date: nhom.date, messages: khop)
        }
    }

    private var soTinKhop: Int { nhomHienThi.reduce(0) { $0 + $1.messages.count } }

    private var thanhTimKiem: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondary)
                TextField("Tìm trong hội thoại", text: $tuKhoa)
                    .foregroundColor(AppColors.textPrimary)
                    .autocorrectionDisabled()
                if !tuKhoa.isEmpty {
                    Button {
                        tuKhoa = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                Button("Đóng") {
                    withAnimation { dangTimKiem = false }
                    tuKhoa = ""
                }
                .font(.buttonSmall)
                .foregroundColor(AppColors.primary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            if !tuKhoa.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(soTinKhop == 0
                     ? "Không thấy tin nào khớp trong \(viewModel.messages.count) tin đã tải"
                     : "\(soTinKhop) tin khớp trong \(viewModel.messages.count) tin đã tải")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.sm)
            }
        }
        .background(AppColors.backgroundSecondary)
    }

    private var coChu: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func chupXong(_ data: Data) {
        Task {
            await viewModel.guiAnh([(data, "chup.jpg", "image/jpeg")],
                                   kem: messageText.trimmingCharacters(in: .whitespaces))
            messageText = ""
        }
    }

    private func nutThanh(_ icon: String, _ cham: @escaping () -> Void) -> some View {
        Button(action: cham) {
            Image(systemName: icon)
                .font(.system(size: 21))
                .foregroundColor(AppColors.primary)
                .frame(width: 30, height: 34)
        }
        .buttonStyle(.plain)
    }

    /// Thanh thay chỗ ô nhập trong lúc ghi. Cố ý CHIẾM CHỖ ô nhập thay vì nổi
    /// đè lên: đang ghi mà vẫn gõ được thì người dùng gõ xong bấm gửi và mất
    /// đoạn ghi.
    private var thanhGhiAm: some View {
        HStack(spacing: 12) {
            Button {
                _ = ghiAm.dungLai(huy: true)
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.error)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(AppColors.error)
                .frame(width: 9, height: 9)
                .opacity(ghiAm.giay % 2 == 0 ? 1 : 0.25)
                .animation(.easeInOut(duration: 0.4), value: ghiAm.giay)

            Text(String(format: "%d:%02d", ghiAm.giay / 60, ghiAm.giay % 60))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .monospacedDigit()

            Text("Đang ghi…")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Button {
                guard let kq = ghiAm.dungLai() else {
                    viewModel.error = "Đoạn ghi quá ngắn."
                    return
                }
                Haptics.cham()
                Task {
                    await viewModel.guiAnh([(kq.data, "thoai-\(kq.giay)s.m4a", "audio/m4a")], kem: "")
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(AppColors.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var bangEmoji: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Self.emojiHayDung, id: \.self) { e in
                    Button {
                        messageText += e
                    } label: {
                        Text(e).font(.system(size: 30))
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(AppColors.backgroundSecondary)
    }

    private static let emojiHayDung = [
        "❤️", "😂", "😍", "👍", "🔥", "🎉", "😊", "😢", "😮", "😡",
        "🙏", "👏", "💯", "✅", "🤔", "😅", "🥰", "😭", "🤣", "💪",
    ]

    // MARK: - Hành động

    private func tatThongBao(_ phut: Int?) async {
        guard let id = viewModel.thread?.id else { return }
        do {
            try await APIClient.shared.send(.muteThread(id: id, durationMinutes: phut))
            thongBaoTat = phut == 0 ? "Đã bật lại thông báo" : "Đã tắt thông báo hội thoại này"
        } catch {
            thongBaoTat = error.localizedDescription
        }
    }

    private func baoCaoHoiThoai() async {
        guard let id = viewModel.thread?.id else { return }
        do {
            try await APIClient.shared.send(.reportThread(id: id, reason: "HARASSMENT"))
            thongBaoTat = "Đã gửi báo cáo. Đội kiểm duyệt xem xét trong 24 giờ."
        } catch {
            thongBaoTat = error.localizedDescription
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if viewModel.isLoading && viewModel.messages.isEmpty {
                        ProgressView()
                            .padding(.top, Spacing.xxl)
                    } else {
                        // Tin CŨ nằm trên đỉnh, nên móc "tải thêm" phải ở đây.
                        // Bản cũ đặt nó dưới đáy — tức cuộn xuống tin MỚI NHẤT
                        // mới đi tải tin cũ, và ở đáy thì nó luôn hiện sẵn nên
                        // vòng tải chạy ngay lúc mở.
                        if viewModel.hasMore {
                            HStack(spacing: 6) {
                                if viewModel.dangTaiThem {
                                    ProgressView().scaleEffect(0.7)
                                    Text("Đang tải tin cũ…")
                                } else {
                                    Text("Kéo lên để xem tin cũ hơn")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(nen.laNenToi ? .white.opacity(0.7) : AppColors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .onAppear {
                                Task { await viewModel.loadMoreMessages() }
                            }
                        }

                        ForEach(nhomHienThi, id: \.date) { group in
                            // Dải ngày kiểu Messenger: viên thuốc ở GIỮA, có
                            // nền mờ riêng để đọc được cả khi đặt hình nền.
                            Text(group.date)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(nen.laNenToi ? .white.opacity(0.85) : AppColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(nen == .macDinh
                                                   ? AppColors.backgroundTertiary.opacity(0.9)
                                                   : Color.black.opacity(nen.laNenToi ? 0.28 : 0.10))
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)

                            ForEach(group.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: viewModel.isFromCurrentUser(message),
                                    showAvatar: viewModel.shouldShowAvatar(for: message, in: group.messages),
                                    daXem: viewModel.tinCuoiDaXem == message.id,
                                    thaCamXuc: { e in Task { await viewModel.doiCamXuc(message, e) } },
                                    traLoi: { traLoiTin = message },
                                    thuHoi: { Task { await viewModel.thuHoi(message) } },
                                    xoa: { Task { await viewModel.xoaTin(message) } },
                                    hienGio: viewModel.laCuoiCum(message, in: group.messages),
                                    giuTin: { tinDangGiu = message }
                                )
                                .id(message.id)
                            }
                        }

                    }

                    // Mốc vô hình ở ĐÁY. `LazyVStack` chỉ dựng thứ nằm trong
                    // tầm nhìn, nên mốc này rời tầm nhìn đúng lúc người dùng
                    // cuộn lên đọc tin cũ — đó là tín hiệu để hiện nút nhảy
                    // về cuối, không cần đo toạ độ cuộn.
                    Color.clear
                        .frame(height: 1)
                        .id(MOC_DAY)
                        .onAppear { dangODay = true }
                        .onDisappear { dangODay = false }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let tinCuoi = viewModel.messages.last else { return }

                // ⚠️ LẦN ĐẦU PHẢI NHẢY THẲNG, KHÔNG ĐƯỢC CÓ HIỆU ỨNG.
                //
                // `LazyVStack` chưa dựng những tin nằm ngoài tầm nhìn nên nó
                // KHÔNG biết chúng cao bao nhiêu. Cuộn có hiệu ứng tới một
                // mục ở xa là nó tính theo chiều cao ước lượng rồi dừng giữa
                // chừng — đúng cái người dùng gặp: mở hội thoại ra thì nằm ở
                // GIỮA, phải tự kéo xuống mới đọc được tin mới nhất.
                //
                // Nhảy thẳng hai lần: lần đầu ép dựng phần dưới, lần sau sửa
                // lại sai số chiều cao vừa lộ ra.
                if !daCuonLanDau {
                    daCuonLanDau = true
                    proxy.scrollTo(tinCuoi.id, anchor: .bottom)
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(60))
                        proxy.scrollTo(tinCuoi.id, anchor: .bottom)
                    }
                    return
                }

                // Đang đọc tin cũ mà bị giật xuống đáy là rất khó chịu. Chỉ
                // tự cuộn khi người dùng vốn đã ở cuối; nếu không thì để nút
                // nhảy-về-cuối làm việc đó.
                //
                // Điều này cũng lo luôn ca TẢI THÊM TIN CŨ: lúc đó người dùng
                // đang ở trên đỉnh nên `dangODay` đã là false.
                guard dangODay else { return }
                withAnimation { proxy.scrollTo(tinCuoi.id, anchor: .bottom) }
            }
            .overlay(alignment: .bottomTrailing) {
                if !dangODay && !viewModel.messages.isEmpty {
                    Button {
                        if let tinCuoi = viewModel.messages.last {
                            withAnimation { proxy.scrollTo(tinCuoi.id, anchor: .bottom) }
                        }
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.55))
                                    .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
                            )
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    }
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, Spacing.md)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Về tin nhắn mới nhất")
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dangODay)
        }
    }

    private let MOC_DAY = "moc-day-hoi-thoai"

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.divider)

            if let cha = traLoiTin {
                thanhTraLoi(cha)
            }

            Group {
            if ghiAm.dangGhi {
                thanhGhiAm
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    // Bốn nút tắt kiểu Messenger. Chúng THU LẠI thành một mũi
                    // tên khi đang gõ — bốn biểu tượng cộng bàn phím đẩy ô chữ
                    // xuống còn một mẩu hẹp trên máy nhỏ.
                    if dangGo {
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) { dangGo = false }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 26, height: 34)
                        }
                        .buttonStyle(.plain)
                    } else {
                        nutThanh("plus.circle.fill") {
                            withAnimation { showAttachmentOptions.toggle() }
                        }
                        #if os(iOS)
                        // Máy mô phỏng KHÔNG có máy ảnh — ẩn hẳn nút thay vì để
                        // bấm vào ra màn hình đen.
                        if MayAnh.coMayAnh {
                            nutThanh("camera.fill") { hienMayAnh = true }
                        }
                        PhotosPicker(selection: $anhDangChon, maxSelectionCount: 5, matching: .images) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 30, height: 34)
                        }
                        #endif
                        nutThanh("mic.fill") { Task { await ghiAm.batDau() } }
                    }

                    HStack(alignment: .bottom, spacing: 6) {
                        TextField("Tin nhắn", text: $messageText, axis: .vertical)
                            .font(.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1...5)
                            .focused($isInputFocused)
                            .padding(.leading, 12)
                            .padding(.vertical, 8)

                        Button {
                            withAnimation { hienEmoji.toggle() }
                            if hienEmoji { isInputFocused = false }
                        } label: {
                            Image(systemName: hienEmoji ? "keyboard" : "face.smiling")
                                .font(.system(size: 19))
                                .foregroundColor(hienEmoji ? AppColors.primary : AppColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 10)
                        .padding(.bottom, 7)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppColors.backgroundTertiary)
                    )

                    // Ô trống thì nút gửi thành 👍 — bấm một cái là gửi luôn.
                    // Bản cũ để nút mờ và TẮT, tức một điểm bấm không ăn.
                    Button {
                        if coChu {
                            sendMessage()
                        } else {
                            Haptics.cham()
                            Task { await viewModel.sendMessage("👍") }
                        }
                    } label: {
                        if coChu {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(AppColors.primary)
                        } else {
                            Text("👍").font(.system(size: 25))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            }
            .background(AppColors.backgroundSecondary)

            // Attachment options
            if showAttachmentOptions {
                attachmentOptions
            }
        }
    }

    // Chỉ giữ hai nút LÀM ĐƯỢC THẬT. Video / Vị trí / Liên hệ trước đây là
    // nút rỗng — bấm vào không có gì xảy ra, trông y như app hỏng. Cả hai nút
    // dưới đi chung đường `POST /messages/upload` (trần 10MB).
    private var attachmentOptions: some View {
        HStack(spacing: Spacing.xl) {
            #if os(iOS)
            PhotosPicker(selection: $videoDangChon, maxSelectionCount: 1, matching: .videos) {
                nutDinhKem(icon: "video", title: "Video")
            }
            #endif

            Button {
                hienChonGif = true
            } label: {
                nutDinhKem(icon: "square.stack.3d.down.right", title: "GIF")
            }
            .buttonStyle(.plain)

            Button {
                Task { await guiViTri() }
            } label: {
                nutDinhKem(icon: viTri.dangDo ? "location.fill" : "location", title: "Vị trí")
            }
            .buttonStyle(.plain)
            .disabled(viTri.dangDo)

            Button {
                hienChonTep = true
            } label: {
                nutDinhKem(icon: "folder", title: "Tệp")
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundSecondary)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Thanh hiện tin đang được trả lời. Không có nó thì bấm "Trả lời" xong
    /// không thấy gì đổi, và tin gửi ra lại gắn vào một tin người dùng đã quên.
    private func thanhTraLoi(_ cha: Message) -> some View {
        HStack(spacing: Spacing.sm) {
            Rectangle().fill(AppColors.primary).frame(width: 3, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("Đang trả lời \(cha.sender?.name ?? "tin nhắn")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                Text(cha.xemTruoc.isEmpty ? "Tin nhắn" : cha.xemTruoc)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                traLoiTin = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundTertiary.opacity(0.5))
    }

    private func nutDinhKem(icon: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppColors.primary)
                .frame(width: 44, height: 44)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(Circle())
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    #if os(iOS)
    /// Đọc ảnh đã chọn rồi gửi. `loadTransferable` trả `Data` ĐÃ giải mã sang
    /// định dạng gốc của ảnh — kể cả ảnh HEIC của iPhone, nên không phải tự
    /// chuyển đổi.
    private func guiAnhDaChon(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var gui: [(data: Data, ten: String, mime: String)] = []
        for (i, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            // `supportedContentTypes` có thể RỖNG với ảnh chụp màn hình và ảnh
            // đồng bộ từ iCloud — mặc định về jpeg thay vì bỏ qua tấm ảnh.
            let loai = item.supportedContentTypes.first
            let duoi = loai?.preferredFilenameExtension ?? "jpg"
            let mime = loai?.preferredMIMEType ?? "image/jpeg"
            gui.append((data, "anh-\(i + 1).\(duoi)", mime))
        }
        guard !gui.isEmpty else { return }
        await viewModel.guiAnh(gui, kem: messageText.trimmingCharacters(in: .whitespacesAndNewlines))
        messageText = ""
        anhDangChon = []
        withAnimation { showAttachmentOptions = false }
    }
    #endif

    private func guiTep(_ ketQua: Result<URL, Error>) {
        guard case .success(let url) = ketQua else { return }
        Task {
            // File ngoài hộp cát của app cần xin quyền đọc rồi TRẢ LẠI, không
            // thì lần chọn sau bị từ chối im lặng.
            let mo = url.startAccessingSecurityScopedResource()
            defer { if mo { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                viewModel.error = "Không đọc được tệp này."
                return
            }
            await viewModel.guiAnh([(data, url.lastPathComponent, "application/octet-stream")],
                                   kem: messageText.trimmingCharacters(in: .whitespacesAndNewlines))
            messageText = ""
            withAnimation { showAttachmentOptions = false }
        }
    }

    private func sendMessage() {
        AmThanh.shared.phat(.guiDi, am: 0.32)
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Haptics.cham()

        let cha = traLoiTin?.id
        Task {
            await viewModel.sendMessage(messageText, traLoi: cha)
            messageText = ""
            traLoiTin = nil
        }
    }
    /// Hành động cho một tin — đúng bộ Messenger có, bỏ những cái app chưa làm.
    private func hanhDongCho(_ tin: Message) -> [HanhDongTin] {
        var ds: [HanhDongTin] = [
            HanhDongTin(ten: "Trả lời", icon: "arrowshape.turn.up.left") { traLoiTin = tin },
            HanhDongTin(ten: "Sao chép", icon: "doc.on.doc") {
                #if os(iOS)
                UIPasteboard.general.string = tin.noiDung
                #endif
            },
        ]
        if viewModel.isFromCurrentUser(tin) {
            ds.append(HanhDongTin(ten: "Thu hồi", icon: "arrow.uturn.backward") {
                Task { await viewModel.thuHoi(tin) }
            })
            ds.append(HanhDongTin(ten: "Xoá", icon: "trash", doTuoi: true) {
                Task { await viewModel.xoaTin(tin) }
            })
        }
        return ds
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showAvatar: Bool
    /// Vẽ "Đã xem" dưới ĐÚNG tin cuối người kia đã đọc, như Messenger.
    var daXem: Bool = false
    var thaCamXuc: ((String) -> Void)? = nil
    var traLoi: (() -> Void)? = nil
    var thuHoi: (() -> Void)? = nil
    var xoa: (() -> Void)? = nil
    /// Hiện giờ dưới bong bóng. Messenger CHỈ hiện ở tin cuối mỗi cụm, không
    /// phải mỗi tin — dán giờ vào từng dòng làm khung chat rời rạc hẳn ra.
    var hienGio: Bool = true

    /// Khung chat cầm cờ này — bong bóng chỉ báo "tôi bị giữ", việc vẽ lớp
    /// phủ là của khung chat (nó mới có toàn màn hình để vẽ).
    var giuTin: (() -> Void)? = nil

    private var mauChu: Color { isFromCurrentUser ? AppColors.onPrimary : AppColors.textPrimary }
    private var mauNen: Color { isFromCurrentUser ? AppColors.primary : AppColors.backgroundTertiary }

    /// Cỡ chữ trong bong bóng.
    ///
    /// ⚠️ Trước 17/09/2026 dùng `.bodyMedium` = **14pt cố định**. Messenger
    /// của Facebook dùng ~17pt, và 14pt là cỡ của chú thích chứ không phải
    /// của câu người ta đang nói với nhau — đọc lâu mỏi mắt, và trên máy màn
    /// lớn nhìn như chữ bị thu nhỏ.
    ///
    /// `@ScaledMetric` để nó lớn lên theo cỡ chữ hệ thống: `.font(.system(
    /// size:))` trần thì Dynamic Type KHÔNG đụng tới được, và tin nhắn là thứ
    /// người dùng chỉnh cỡ chữ nhiều nhất trong cả máy.
    @ScaledMetric(relativeTo: .body) private var coChu: CGFloat = 17

    /// Bong bóng không được kéo hết bề ngang: Messenger chặn quanh 3/4 màn hình
    /// rồi mới xuống dòng, nhờ vậy mắt còn thấy được lề và biết ai đang nói.
    ///
    /// ⚠️ `UIScreen.main` là bề ngang MÀN HÌNH, không phải bề ngang chỗ bong
    /// bóng thật sự nằm. Từ 16/09/2026 app chạy trên iPad: ở đó khung chat là
    /// CỘT PHẢI của `BoCucCotDoi`, hẹp hơn màn hình nhiều, và trong Split View
    /// thì cả cửa sổ cũng chỉ bằng nửa màn. Lấy 74% của 1366pt ra 1011pt —
    /// rộng hơn cả cột chứa nó, nên "3/4" thành "tràn hết", đúng thứ quy tắc
    /// này sinh ra để tránh. Trần 520pt giữ dòng chữ ở độ dài đọc được, đúng
    /// cách iMessage làm trên iPad.
    private var tranNgang: CGFloat {
        #if os(iOS)
        return min(UIScreen.main.bounds.width * 0.74, 520)
        #else
        return 420
        #endif
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            } else {
                if showAvatar {
                    UserAvatarView(url: message.sender?.avatarUrl, size: 28)
                } else {
                    Spacer().frame(width: 28)
                }
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                if message.daXoaHoacThuHoi {
                    Text("Tin nhắn đã được thu hồi")
                        .font(.system(size: coChu))
                        .italic()
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                } else {
                    if let cha = message.parentMessage {
                        traLoiTrichDan(cha)
                    }

                    // Vị trí đi trước: nó thay cho cả dòng chữ chứa link, chứ
                    // không hiện thêm link thô bên dưới.
                    if let vt = message.viTri {
                        theViTri(vido: vt.vido, kinhdo: vt.kinhdo)
                    } else if !message.anh.isEmpty {
                        luoiAnh(message.anh)
                    }

                    ForEach(message.tepKhongPhaiAnh) { tep in
                        if (tep.mimeType ?? "").hasPrefix("audio/") {
                            TinThoaiView(tep: tep, mauChu: mauChu, mauNen: mauNen)
                        } else {
                            theTep(tep)
                        }
                    }

                    if !message.noiDung.isEmpty && message.viTri == nil {
                        Text(message.noiDung)
                            .font(.system(size: coChu))
                            // Dòng thưa ra một chút: 17pt sát nhau đọc nặng,
                            // và Messenger cũng để khoảng thở giữa các dòng.
                            .lineSpacing(2)
                            .foregroundColor(mauChu)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(mauNen)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .frame(maxWidth: tranNgang,
                                   alignment: isFromCurrentUser ? .trailing : .leading)
                            // ⚠️ KHÔNG bật `.textSelection(.enabled)` ở đây.
                            //
                            // Bộ chọn văn bản của iOS NUỐT cử chỉ nhấn giữ:
                            // giữ bong bóng thì hiện menu "Copy | Share | Look
                            // Up" của hệ thống, còn menu cảm xúc của mình
                            // KHÔNG BAO GIỜ chạy. Đo thật 21/08/2026: nhật ký
                            // ghi 0 lần vào `onLongPressGesture`, trong khi 16
                            // neo toạ độ vẫn báo về đủ — tức mọi thứ khác lành,
                            // chỉ cú chạm là không tới nơi.
                            //
                            // Messenger cũng không cho bôi đen chữ trong bong
                            // bóng; muốn chép thì dùng "Sao chép" trong menu
                            // nhấn giữ, và app đã có sẵn mục đó.
                    }
                }

                if let ds = message.reactions, !ds.isEmpty {
                    chipCamXuc(ds)
                }

                if hienGio || daXem {
                    HStack(spacing: 4) {
                        if hienGio {
                            Text(TimeFormatter.gioTrongChat(message.createdAt))
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        if isFromCurrentUser && daXem {
                            // Chữ chứ không phải dấu tích: hai dấu tích
                            // đặc/rỗng nhìn lướt không phân biệt được.
                            Text(hienGio ? "· Đã xem" : "Đã xem")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            // ⚠️ Không có Spacer đuôi thì hàng tin ĐẾN chỉ rộng bằng nội
            // dung và bị khung chứa CĂN GIỮA — mép trái bong bóng trôi theo
            // độ dài chữ, cả cột nhìn ngoằn ngoèo. Spacer ép hàng nở hết bề
            // ngang để bong bóng dán vào mép trái cố định, đối xứng với
            // Spacer(minLength: 60) mà tin ĐI đã có ở đầu hàng.
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, hienGio ? 3 : 1)
        .contentShape(Rectangle())
        // Báo toạ độ thật của bong bóng lên khung chat, để lớp phủ nhấc nó
        // lên ĐÚNG chỗ nó đang nằm thay vì nhảy ra giữa màn hình.
        .anchorPreference(key: NeoTinKey.self, value: .bounds) { [message.id: $0] }
        .onLongPressGesture {
            guard !message.daXoaHoacThuHoi else { return }
            Haptics.cham()
            giuTin?()
        }
    }



    // MARK: Chip cảm xúc

    private func chipCamXuc(_ ds: [MessageReaction]) -> some View {
        HStack(spacing: 3) {
            ForEach(ds) { r in
                Button {
                    thaCamXuc?(r.emoji)
                } label: {
                    HStack(spacing: 2) {
                        Text(r.emoji).font(.system(size: 12))
                        if r.count > 1 {
                            Text("\(r.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(AppColors.backgroundSecondary)
                    )
                    .overlay(
                        Capsule().stroke(
                            r.coCua(AppState.shared.currentUser?.id)
                                ? AppColors.primary : AppColors.border,
                            lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 1)
    }

    // MARK: Thẻ vị trí

    private func theViTri(vido: Double, kinhdo: Double) -> some View {
        Button {
            guard let u = URL(string: "https://www.google.com/maps/search/?api=1&query=\(vido),\(kinhdo)")
            else { return }
            #if os(iOS)
            UIApplication.shared.open(u)
            #else
            NSWorkspace.shared.open(u)
            #endif
        } label: {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle().fill(AppColors.primary.opacity(0.15))
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 17))
                        .foregroundColor(AppColors.primary)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Vị trí đã chia sẻ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(mauChu)
                    Text(String(format: "%.5f, %.5f", vido, kinhdo))
                        .font(.system(size: 11))
                        .foregroundColor(mauChu.opacity(0.75))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(mauChu.opacity(0.6))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(mauNen)
            .cornerRadius(CornerRadius.large)
        }
        .buttonStyle(.plain)
    }

    // MARK: Ảnh

    /// Ảnh trong tin nhắn.
    ///
    /// ⚠️ Bản cũ ép MỌI ảnh vào ô VUÔNG cứng (220pt cho một ảnh, 108pt cho
    /// nhiều) bằng `.fill` + `.clipped()`. Hậu quả: ảnh dọc bị xén đầu xén
    /// chân, ảnh ngang bị cắt hai bên — và vì ô cứng không liên quan gì tới
    /// `tranNgang` của bong bóng chữ, tin có ảnh và tin có chữ lệch mép nhau,
    /// cả cột nhìn răng cưa. Đây đúng là chỗ người dùng nói "gửi ảnh là lệch
    /// nhất".
    ///
    /// Nay theo đúng cách Messenger làm:
    ///   · MỘT ảnh  → giữ TỈ LỆ GỐC, rộng bằng `tranNgang`
    ///   · NHIỀU ảnh → lưới vuông (cắt là đúng ở đây, để lưới thẳng hàng),
    ///                 nhưng cạnh ô tính TỪ `tranNgang` chứ không gõ cứng
    @ViewBuilder
    private func luoiAnh(_ ds: [String]) -> some View {
        if ds.count == 1 {
            anhDon(ds[0])
        } else {
            let cot = ds.count == 2 ? 2 : (ds.count == 4 ? 2 : 3)
            let khe: CGFloat = 3
            let canh = (tranNgang - khe * CGFloat(cot - 1)) / CGFloat(cot)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(canh), spacing: khe),
                                     count: cot),
                      spacing: khe) {
                ForEach(Array(ds.enumerated()), id: \.offset) { _, duong in
                    anhMot(duong, canh: canh)
                }
            }
            .frame(width: tranNgang, alignment: isFromCurrentUser ? .trailing : .leading)
        }
    }

    /// Một ảnh đứng riêng — giữ tỉ lệ gốc.
    @ViewBuilder
    private func anhDon(_ duong: String) -> some View {
        if let url = URL(string: duong) {
            KFImage(url)
                .placeholder {
                    // Giữ chỗ theo tỉ lệ 4:3 để hàng không NHẢY khi ảnh về.
                    // Không giữ chỗ thì chiều cao là 0 rồi bật lên, và cả
                    // danh sách giật một cái mỗi lần một ảnh tải xong.
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.backgroundTertiary)
                        ProgressView().scaleEffect(0.8)
                    }
                    .frame(width: tranNgang, height: tranNgang * 0.75)
                }
                .resizable()
                .aspectRatio(contentMode: .fit)
                // Trần chiều cao: ảnh dọc rất dài chiếm trọn màn hình thì
                // người dùng mất ngữ cảnh cuộc trò chuyện.
                .frame(maxWidth: tranNgang, maxHeight: 340)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// Một ô trong lưới nhiều ảnh. Ở đây cắt vuông là ĐÚNG — lưới phải thẳng
    /// hàng thì mắt mới đọc được là "một chùm ảnh".
    ///
    /// ⚠️ Dùng `KFImage` chứ không `AsyncImage`: `AsyncImage` không có nhớ
    /// đệm đĩa, nên cuộn lên rồi cuộn xuống là tải lại từ đầu — tốn dữ liệu
    /// của người dùng và ảnh nhấp nháy mỗi lượt. Kingfisher đã là thư viện
    /// sẵn có của dự án, không thêm phụ thuộc nào.
    @ViewBuilder
    private func anhMot(_ duong: String, canh: CGFloat) -> some View {
        if let url = URL(string: duong) {
            KFImage(url)
                .placeholder {
                    ZStack {
                        AppColors.backgroundTertiary
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: canh, height: canh)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: Tệp không phải ảnh

    private func theTep(_ tep: MessageAttachment) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "doc.fill")
                .font(.system(size: 18))
                .foregroundColor(mauChu.opacity(0.9))
            VStack(alignment: .leading, spacing: 1) {
                Text(tep.fileName ?? "Tệp đính kèm")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(mauChu)
                    .lineLimit(1)
                if let n = tep.fileSize {
                    Text(Self.coChu(n))
                        .font(.system(size: 11))
                        .foregroundColor(mauChu.opacity(0.75))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(mauNen)
        .cornerRadius(CornerRadius.large)
        .onTapGesture { moTep(tep) }
    }

    private func moTep(_ tep: MessageAttachment) {
        guard let url = URL(string: tep.url) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private static func coChu(_ byte: Int) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(byte))
    }

    // MARK: Trích dẫn tin được trả lời

    private func traLoiTrichDan(_ cha: MessageParent) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(cha.senderName ?? "Tin nhắn")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
            Text((cha.content?.isEmpty ?? true) ? "Tin nhắn đã thu hồi" : (cha.content ?? ""))
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.backgroundTertiary.opacity(0.6))
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(AppColors.primary).frame(width: 2)
        }
    }
}

// MARK: - Grouped Messages
struct MessageGroup {
    let date: String
    let messages: [Message]
}

// MARK: - Chat View Model
@MainActor
class ChatViewModel: ObservableObject {
    @Published var thread: MessageThread?
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasMore = true
    @Published var dangTaiThem = false
    @Published var dangGuiAnh = false
    /// Mốc người kia đã đọc tới. `nil` = chưa từng mở hội thoại.
    @Published var mocDocCuaNguoiKia: Date?
    @Published private(set) var localUnreadCount: Int = 0

    private var cursor: Int?

    /// Chèn tin nhận qua socket. Bỏ qua nếu đã có — tin do CHÍNH MÌNH gửi
    /// quay về qua socket sẽ trùng với bản đã thêm lạc quan lúc bấm Gửi.
    func chenTinMoi(_ tin: Message) {
        guard !messages.contains(where: { $0.id == tin.id }) else { return }
        messages.append(tin)
    }

    /// Số tin mỗi lượt. Máy chủ chặn trần ở 100.
    private static let moiLuot = 50

    func loadMessages() async {
        guard let threadId = thread?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // `/threads/:id/messages` trả MẢNG TRẦN, mới nhất trước, và KHÔNG
            // kèm con trỏ trang. Nhưng nó CÓ nhận `?cursor=` (máy chủ lọc
            // `id < cursor`), nên con trỏ phải tự suy ra từ id nhỏ nhất đang
            // giữ. Bản cũ đặt cứng `hasMore = false` vì tưởng máy chủ không
            // phân trang — thật ra có, chỉ là không trả con trỏ về.
            let response: (items: [Message], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(
                    .getMessages(threadId: threadId, cursor: nil, limit: Self.moiLuot)
                )
            // `listMessages` lấy 50 tin MỚI NHẤT (`id desc`) rồi `.reverse()`
            // trước khi trả — nên mảng về đã là CŨ TRƯỚC, MỚI SAU, dùng thẳng.
            // Bản cũ còn `.reversed()` thêm một lần nữa, tức lộn ngược cả
            // khung chat; không ai thấy vì tin nhắn chưa từng giải mã được.
            messages = response.items
            cursor = messages.first?.id
            hasMore = response.items.count >= Self.moiLuot
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMoreMessages() async {
        guard let threadId = thread?.id, hasMore, !isLoading, !dangTaiThem,
              let cursor else { return }
        dangTaiThem = true
        defer { dangTaiThem = false }

        do {
            let response: (items: [Message], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(
                    .getMessages(threadId: threadId, cursor: cursor, limit: Self.moiLuot)
                )
            // Lọc trùng phòng khi có tin chen vào giữa hai lượt gọi.
            let daCo = Set(messages.map(\.id))
            let them = response.items.filter { !daCo.contains($0.id) }
            messages.insert(contentsOf: them, at: 0)
            self.cursor = messages.first?.id
            hasMore = response.items.count >= Self.moiLuot
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Gửi ảnh

    /// Tải ảnh lên rồi gửi kèm tin. Ảnh đi qua `POST /messages/upload` để lấy
    /// `fileId` — máy chủ nhận `fileIds: [Int]`, KHÔNG nhận URL.
    func guiAnh(_ duLieu: [(data: Data, ten: String, mime: String)], kem chu: String) async {
        guard let threadId = thread?.id, !duLieu.isEmpty else { return }
        dangGuiAnh = true
        defer { dangGuiAnh = false }

        do {
            var ids: [Int] = []
            for anh in duLieu {
                let ket = try await APIClient.shared.taiLenChat(
                    data: anh.data, fileName: anh.ten, mimeType: anh.mime
                )
                ids.append(ket.fileId)
            }
            let tin: Message = try await APIClient.shared.request(
                .sendMessageWithFiles(threadId: threadId, content: chu, fileIds: ids)
            )
            chenTinMoi(tin)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Cảm xúc / GIF / vị trí / thu hồi

    /// Sáu cảm xúc của Messenger, đúng thứ tự quen mắt.
    static let camXuc = ["❤️", "😆", "😮", "😢", "😡", "👍"]

    /// Bật/tắt một cảm xúc. Đổi TẠI CHỖ trước khi gọi mạng để nút phản hồi tức
    /// thì; máy chủ trả về bản gộp thật thì ghi đè lại.
    /// Cảm xúc CHÍNH MÌNH đã thả cho tin này — để khoanh tròn nó trong bảng
    /// nhấn giữ. `nil` = chưa thả gì.
    func camXucCuaToi(_ tin: Message) -> String? {
        let toi = AppState.shared.currentUser?.id
        return tin.reactions?.first { $0.coCua(toi) }?.emoji
    }

    func doiCamXuc(_ tin: Message, _ emoji: String) async {
        guard let toi = AppState.shared.currentUser?.id else { return }
        guard let i = messages.firstIndex(where: { $0.id == tin.id }) else { return }

        let cu = messages[i].reactions ?? []
        messages[i] = messages[i].thayCamXuc(Self.gopTaiCho(cu, emoji: emoji, userId: toi))

        do {
            let moi: [MessageReaction] = try await APIClient.shared
                .request(.toggleMessageReaction(messageId: tin.id, emoji: emoji))
            if let j = messages.firstIndex(where: { $0.id == tin.id }) {
                messages[j] = messages[j].thayCamXuc(moi)
            }
        } catch {
            // Trả lại đúng trạng thái cũ, đừng để nút "dính" ở trạng thái sai.
            if let j = messages.firstIndex(where: { $0.id == tin.id }) {
                messages[j] = messages[j].thayCamXuc(cu)
            }
            self.error = error.localizedDescription
        }
    }

    private static func gopTaiCho(_ ds: [MessageReaction], emoji: String, userId: Int) -> [MessageReaction] {
        var m = ds
        if let i = m.firstIndex(where: { $0.emoji == emoji }) {
            var ids = m[i].userIds
            if let k = ids.firstIndex(of: userId) {
                ids.remove(at: k)
            } else {
                ids.append(userId)
            }
            if ids.isEmpty { m.remove(at: i) }
            else { m[i] = MessageReaction(emoji: emoji, count: ids.count, userIds: ids) }
        } else {
            m.append(MessageReaction(emoji: emoji, count: 1, userIds: [userId]))
        }
        return m
    }

    /// Socket `message:updated` — người kia thả cảm xúc / thu hồi tin.
    func apDungThayDoi(messageId: Int, reactions: [MessageReaction]?, thuHoi: Bool?, daXoa: Bool?) {
        guard let i = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[i] = messages[i].apDung(reactions: reactions, thuHoi: thuHoi, daXoa: daXoa)
    }

    func guiGif(_ url: String) async {
        guard let threadId = thread?.id else { return }
        do {
            let tin: Message = try await APIClient.shared
                .request(.sendMessageMedia(threadId: threadId, url: url, kind: "gif"))
            chenTinMoi(tin)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Gửi vị trí dạng link Google Maps — máy chủ không có trường toạ độ, và
    /// link thì web đọc được luôn. App tự nhận ra link này để vẽ thẻ bản đồ.
    func guiViTri(vido: Double, kinhdo: Double) async {
        let link = "https://www.google.com/maps/search/?api=1&query=\(vido),\(kinhdo)"
        await sendMessage("📍 Vị trí của tôi: \(link)")
    }

    // ⚠️⚠️ `request()` ĐÒI vỏ có khoá `data`; `send()` thì không.
    //
    // Ba đường dưới đây trả về `{ success: true }` TRƠN — không `data`. Gọi
    // bằng `request()` là nó ném `serverError("Máy chủ không trả về dữ liệu")`
    // NGAY CẢ KHI máy chủ đã làm xong việc. Tin đã thu hồi/xoá thật trên máy
    // chủ, mà app tưởng hỏng nên không cập nhật gì — người dùng thấy "bấm
    // không ăn". Đo thật 21/08/2026:
    //
    //   POST   /messages/:id/recall  → res.json({ success: true })
    //   DELETE /messages/:id         → res.json({ success: true })
    //   PATCH  /threads/:id/read     → res.json({ success: true })
    //
    // Đã rà cả hai kho: 15 đường của backend trả vỏ trơn, và ĐÚNG ba đường
    // trên là chỗ app gọi nhầm bằng `request()`.
    func thuHoi(_ tin: Message) async {
        do {
            try await APIClient.shared.send(.recallMessage(messageId: tin.id))
            apDungThayDoi(messageId: tin.id, reactions: nil, thuHoi: true, daXoa: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func xoaTin(_ tin: Message) async {
        do {
            try await APIClient.shared.send(.deleteMessage(messageId: tin.id))
            messages.removeAll { $0.id == tin.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: "Đã xem"

    /// Mốc đọc của người kia. Tin nào gửi trước mốc này thì người ta đã xem.
    func taiMocDoc() async {
        guard let threadId = thread?.id else { return }
        guard let ds: [MocDoc] = try? await APIClient.shared
            .request(.getThreadReads(threadId: threadId)) else { return }
        let toi = AppState.shared.currentUser?.id
        mocDocCuaNguoiKia = ds.filter { $0.userId != toi }.compactMap(\.moc).max()
    }

    /// Socket `thread:read` bắn lúc người kia mở hội thoại — cập nhật ngay mà
    /// không phải gọi lại API.
    func capNhatMocDoc(_ moc: Date) {
        if let cu = mocDocCuaNguoiKia, cu >= moc { return }
        mocDocCuaNguoiKia = moc
    }

    /// Tin CUỐI CÙNG do mình gửi mà người kia đã đọc — chỉ vẽ "Đã xem" dưới
    /// đúng tin đó, như Messenger, thay vì gắn nhãn lên mọi tin.
    var tinCuoiDaXem: Int? {
        guard let moc = mocDocCuaNguoiKia, let toi = AppState.shared.currentUser?.id else { return nil }
        return messages.last(where: { $0.senderId == toi && ($0.ngayGio ?? .distantFuture) <= moc })?.id
    }

    func sendMessage(_ content: String, traLoi cha: Int? = nil) async {
        guard let threadId = thread?.id else { return }

        // Hiện ngay tin tạm rồi mới gọi máy chủ. Id âm để chắc chắn không đụng
        // id thật — bản cũ bốc số ngẫu nhiên trong 100000...999999, mà id thật
        // rơi vào đúng khoảng đó thì tin thật bị thay nhầm.
        let tempMessage = Message(
            id: -Int(Date().timeIntervalSince1970 * 1000) % 1_000_000_000,
            threadId: threadId,
            senderId: AppState.shared.currentUser?.id ?? 0,
            sender: AppState.shared.currentUser,
            content: content,
            mediaUrl: nil,
            mediaKind: nil,
            deleted: nil,
            recalled: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            attachments: nil,
            parentMessageId: cha,
            parentMessage: nil,
            hasAttachment: nil,
            reactions: nil
        )

        messages.append(tempMessage)

        do {
            let newMessage: Message = try await APIClient.shared.request(
                .sendMessage(threadId: threadId, content: content, type: "text", parentMessageId: cha)
            )

            // Replace temp message with real one
            if let index = messages.firstIndex(where: { $0.id == tempMessage.id }) {
                messages[index] = newMessage
            }
        } catch {
            // Remove temp message on error
            messages.removeAll { $0.id == tempMessage.id }
            self.error = error.localizedDescription
        }
    }

    func markAsRead() async {
        guard let threadId = thread?.id else { return }

        do {
            try await APIClient.shared.send(.markRead(threadId: threadId))
            // Hạ huy hiệu NGAY. Trước đây chỉ `fetchUnreadCounts()` lúc mở
            // app mới hạ được, nên đọc xong thoát ra là biểu tượng vẫn treo
            // số cũ tới lần mở app sau.
            await MainActor.run {
                AppState.shared.unreadMessages = max(0, AppState.shared.unreadMessages - 1)
                AppState.shared.dongBoHuyHieu()
            }
            localUnreadCount = 0
        } catch {
            // Silently fail
        }
    }

    var groupedMessages: [MessageGroup] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let calendar = Calendar.current
        var groups: [String: [Message]] = [:]

        for message in messages {
            let date = ISO8601DateFormatter().date(from: message.createdAt) ?? Date()
            let key: String

            if calendar.isDateInToday(date) {
                key = "Hôm nay"
            } else if calendar.isDateInYesterday(date) {
                key = "Hôm qua"
            } else {
                key = formatter.string(from: date)
            }

            groups[key, default: []].append(message)
        }

        return groups.map { MessageGroup(date: $0.key, messages: $0.value) }
            .sorted { group1, group2 in
                guard let msg1 = group1.messages.first,
                      let msg2 = group2.messages.first else { return false }
                let date1 = ISO8601DateFormatter().date(from: msg1.createdAt) ?? Date()
                let date2 = ISO8601DateFormatter().date(from: msg2.createdAt) ?? Date()
                return date1 < date2
            }
    }

    func isFromCurrentUser(_ message: Message) -> Bool {
        message.senderId == AppState.shared.currentUser?.id
    }

    /// Tin CUỐI của một cụm: tin kế tiếp khác người gửi, hoặc cách nhau quá 5
    /// phút. Chỉ tin như vậy mới hiện giờ — giống Messenger.
    func laCuoiCum(_ message: Message, in ds: [Message]) -> Bool {
        guard let i = ds.firstIndex(where: { $0.id == message.id }) else { return true }
        guard i < ds.count - 1 else { return true }
        let sau = ds[i + 1]
        if sau.senderId != message.senderId { return true }
        guard let a = message.ngayGio, let b = sau.ngayGio else { return true }
        return b.timeIntervalSince(a) > 5 * 60
    }

    func shouldShowAvatar(for message: Message, in messages: [Message]) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return true }

        if index == messages.count - 1 { return true }

        let nextMessage = messages[index + 1]
        return nextMessage.senderId != message.senderId
    }
}

#Preview {
    NavigationStack {
        ChatView(thread: MessageThread(
            id: 1,
            type: "USER",
            peer: ThreadPeer(id: 1, username: "test", displayName: "Test User", avatarUrl: nil, alias: nil),
            lastMessage: nil,
            unreadCount: 0,
            createdAt: nil,
            updatedAt: nil,
            preferences: nil
        ))
    }
}


// MARK: - Tách bớt cho trình biên dịch
//
// Thân `ChatView` từng dài tới mức `swiftc` bỏ cuộc: "unable to type-check this
// expression in reasonable time". Gộp chuỗi bộ điều chỉnh vào hai `ViewModifier`
// làm mỗi khối nhỏ lại đủ để suy kiểu.

private struct VongDoiChat: ViewModifier {
    let thread: MessageThread
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var realtime: RealtimeClient
    @Binding var messageText: String
    @Binding var thongBaoTat: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                viewModel.thread = thread
                AppState.shared.hoiThoaiDangMo = thread.id
                // Hội thoại vừa tạo chưa có trong danh sách máy chủ tự cho vào
                // lúc bắt tay, nên phải xin vào phòng.
                realtime.vaoPhong(threadId: thread.id)
                Task {
                    await viewModel.loadMessages()
                    // Mở hội thoại = đã đọc. Bản cũ có hàm `markAsRead()` nhưng
                    // KHÔNG chỗ nào gọi, nên huy hiệu chưa đọc không tắt.
                    await viewModel.markAsRead()
                    await viewModel.taiMocDoc()
                }
            }
            // Tin mới đẩy thẳng vào danh sách, không hỏi lại API.
            .onReceive(realtime.tinMoi) { su in
                guard su.threadId == thread.id else { return }

                // ⚠️ TIẾNG BÁO CHỈ PHÁT Ở ĐÂY, KHÔNG PHÁT Ở TẦNG APP.
                //
                // Tin nhắn về thì máy nhận CẢ hai đường: sự kiện socket này
                // VÀ một thông báo đẩy. `willPresent` trong `ThongBaoDay` đã
                // xin `[.banner, .sound, .badge]`, nên hội thoại KHÔNG mở đã
                // có tiếng của hệ thống rồi. Thêm tiếng ở tầng app nữa là
                // kêu hai lần cho một tin.
                //
                // Đúng hội thoại đang mở thì `willPresent` trả `[]` — im
                // hoàn toàn. Đó mới là khoảng trống, và nó lấp ở đây.
                if su.message.senderId != AppState.shared.currentUser?.id {
                    // Khẽ thôi: người dùng đang nhìn thẳng vào màn hình, tiếng
                    // này chỉ để xác nhận chứ không phải để gọi họ quay lại.
                    AmThanh.shared.phat(.tinNhanToi, am: 0.4)
                }

                viewModel.chenTinMoi(su.message)
                // Đang mở hội thoại mà tin tới thì coi như đọc luôn, không thì
                // huy hiệu chưa đọc nhảy lên ngay trước mắt người đang đọc.
                Task { await viewModel.markAsRead() }
            }
            .onReceive(realtime.tinDoi) { su in
                guard su.threadId == thread.id else { return }
                viewModel.apDungThayDoi(messageId: su.messageId, reactions: su.reactions,
                                        thuHoi: su.thuHoi, daXoa: su.daXoa)
            }
            // Người kia mở hội thoại → dời mốc "Đã xem" ngay.
            .onReceive(realtime.daDoc) { su in
                guard su.threadId == thread.id,
                      su.readerId != AppState.shared.currentUser?.id else { return }
                viewModel.capNhatMocDoc(su.readAt)
            }
            .onChange(of: messageText) { cu, moi in
                // Chỉ báo khi VỪA bắt đầu gõ và khi vừa xoá sạch, không phải mỗi
                // ký tự: gõ một câu 40 chữ là 40 gói tin cho cùng một thông tin.
                if cu.isEmpty && !moi.isEmpty {
                    realtime.baoDangGo(threadId: thread.id, dangGo: true)
                } else if !cu.isEmpty && moi.isEmpty {
                    realtime.baoDangGo(threadId: thread.id, dangGo: false)
                }
            }
            .onDisappear {
                AppState.shared.hoiThoaiDangMo = nil
                realtime.baoDangGo(threadId: thread.id, dangGo: false)
                Task { await viewModel.markAsRead() }
            }
            // Thu hồi / xoá / thả cảm xúc đều đặt `viewModel.error` khi hỏng —
            // mà TRƯỚC BẢN NÀY không chỗ nào hiện nó ra. Hỏng là im lặng
            // tuyệt đối, đúng cảm giác "menu không hoạt động".
            .alert("Không thực hiện được",
                   isPresented: Binding(get: { viewModel.error != nil },
                                        set: { if !$0 { viewModel.error = nil } })) {
                Button("OK") { viewModel.error = nil }
            } message: { Text(viewModel.error ?? "") }
            .alert("Hội thoại", isPresented: .constant(thongBaoTat != nil)) {
                Button("OK") { thongBaoTat = nil }
            } message: {
                Text(thongBaoTat ?? "")
            }
    }
}

private struct DinhKemChat: ViewModifier {
    @Binding var hienChonTep: Bool
    let guiTep: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $hienChonTep, allowedContentTypes: [.item]) { kq in
                guiTep(kq)
            }
    }
}


/// `PUT /threads/:id/nickname` trả nguyên hàng `ThreadNickname` của Prisma.
/// Chỉ cần biết nó thành công, nên khai tối thiểu.
struct BietDanhTraVe: Decodable {
    let alias: String?
}


private struct MayAnhVaGhiAm: ViewModifier {
    @Binding var hienMayAnh: Bool
    @Binding var dangGo: Bool
    let coChu: Bool
    @ObservedObject var ghiAm: GhiAmThoai
    let chup: (Data) -> Void

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .fullScreenCover(isPresented: $hienMayAnh) {
                MayAnh(xong: chup).ignoresSafeArea()
            }
            #endif
            // Gõ chữ đầu tiên thì bốn nút thu lại; xoá sạch thì bung ra.
            .onChange(of: coChu) { _, co in
                withAnimation(.easeOut(duration: 0.18)) { dangGo = co }
            }
            .alert("Ghi âm", isPresented: .constant(ghiAm.loi != nil)) {
                Button("OK") { ghiAm.loi = nil }
            } message: {
                Text(ghiAm.loi ?? "")
            }
    }
}


/// Lớp phủ nhấn giữ kiểu Messenger, tách khỏi `body` của ChatView.
///
/// ⚠️ Gộp thẳng vào `body` làm trình biên dịch bỏ cuộc: "unable to type-check
/// this expression in reasonable time". `body` của màn chat vốn đã dài, thêm
/// một `overlayPreferenceValue` lồng `GeometryReader` là quá sức suy kiểu.
private struct LopPhuGiuTin: ViewModifier {
    @Binding var tinDangGiu: Message?
    @ObservedObject var viewModel: ChatViewModel
    let hanhDong: (Message) -> [HanhDongTin]

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(NeoTinKey.self) { neo in
            // `overlayPreferenceValue` là chỗ DUY NHẤT đọc được toạ độ thật mà
            // bong bóng đã báo lên qua `anchorPreference`.
            if let tin = tinDangGiu, let a = neo[tin.id] {
                GeometryReader { g in
                    MenuGiuTin(
                        bongBong: AnyView(
                            MessageBubble(
                                message: tin,
                                isFromCurrentUser: viewModel.isFromCurrentUser(tin),
                                showAvatar: false,
                                hienGio: false
                            )
                        ),
                        khung: g[a],
                        cuaMinh: viewModel.isFromCurrentUser(tin),
                        camXuc: ChatViewModel.camXuc,
                        daChon: viewModel.camXucCuaToi(tin),
                        thaCamXuc: { e in Task { await viewModel.doiCamXuc(tin, e) } },
                        hanhDong: hanhDong(tin),
                        dong: { tinDangGiu = nil }
                    )
                }
                .ignoresSafeArea()
            }
        }
    }
}

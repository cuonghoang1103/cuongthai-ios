import SwiftUI
import PhotosUI

/// Trò chuyện với AI. Chữ hiện DẦN theo luồng SSE, không đợi cả câu.
struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AIChatViewModel()
    @State private var cauHoi = ""
    /// 0 = "đang suy nghĩ", 1 = "đợi tớ chút nhé". Xem `loiCho`.
    @State private var phaCho = 0
    @State private var hienChonModel = false
    @State private var dinhKem: [DinhKemAI] = []
    @State private var anhChon: [PhotosPickerItem] = []
    @State private var hienChonTep = false
    @FocusState private var dangGo: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.tin.isEmpty && !vm.dangTraLoi {
                    manChao
                } else {
                    khungTin
                }
                oNhap
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(vm.bacHienTai.ten)
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Bậc", selection: $vm.bac) {
                            ForEach(BacAI.allCases) { b in
                                Label(b.ten, systemImage: b.bieuTuong).tag(b)
                            }
                        }
                        Divider()
                        Button {
                            vm.hoiMoi()
                        } label: { Label("Cuộc trò chuyện mới", systemImage: "square.and.pencil") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("AI", isPresented: .constant(vm.loi != nil)) {
                Button("OK") { vm.loi = nil }
            } message: { Text(vm.loi ?? "") }
            .onChange(of: anhChon) { _, moi in
                guard !moi.isEmpty else { return }
                Task { await napAnh(moi) }
            }
            .fileImporter(isPresented: $hienChonTep,
                          allowedContentTypes: HanMucDinhKem.loaiTep,
                          allowsMultipleSelection: true) { napTep($0) }
            // Đổi xuống bậc nhanh thì bỏ đính kèm — bậc đó không nhận, giữ
            // lại chỉ làm người dùng tưởng nó vẫn gửi đi.
            .onChange(of: vm.bac) { _, b in
                if !b.nhanTep && !dinhKem.isEmpty {
                    dinhKem = []
                    vm.loi = "CuongMini3.11 chưa đọc được ảnh và tệp — đã bỏ phần đính kèm. Chọn Pro hoặc Max để gửi kèm."
                }
            }
        }
    }

    // MARK: Màn chào

    private var manChao: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.brandGradient)
                    .padding(.top, 60)
                Text("Hỏi CuongMini bất cứ điều gì")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text(vm.bacHienTai.moTa)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                VStack(spacing: 8) {
                    ForEach(Self.goiY, id: \.self) { g in
                        Button {
                            cauHoi = g
                            gui()
                        } label: {
                            HStack {
                                Text(g).font(.system(size: 14))
                                    .foregroundColor(AppColors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.backgroundSecondary))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
            }
        }
    }

    private static let goiY = [
        "Giải thích con trỏ trong C cho người mới",
        "Viết hàm Java đảo ngược một chuỗi",
        "Tóm tắt sự khác nhau giữa SQL và NoSQL",
        "Cho tôi 5 câu tiếng Anh dùng khi phỏng vấn",
    ]

    // MARK: Khung tin

    private var khungTin: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(vm.tin) { t in
                        BongBongAI(tin: t)
                            .id(t.id)
                    }
                    if vm.dangTraLoi {
                        dangLam
                            .id("dang-lam")
                    }
                    Color.clear.frame(height: 1).id("day")
                }
                .padding(Spacing.md)
            }
            // Cuộn theo chữ đang chảy — không thì người dùng phải tự vuốt
            // suốt lúc AI trả lời.
            .onChange(of: vm.tin.last?.noiDung) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("day", anchor: .bottom) }
            }
            .onChange(of: vm.tin.count) { _, _ in
                withAnimation { proxy.scrollTo("day", anchor: .bottom) }
            }
        }
    }

    /// Câu chờ hai nhịp.
    ///
    /// Nhịp đầu xưng tên cho người dùng biết ai đang trả lời, nhịp sau ở lại
    /// tới lúc có chữ. `buocHienTai` (tìm web, đổi model) là tin THẬT nên nó
    /// luôn được ưu tiên — không đè lời chào lên thông tin.
    private var loiCho: String {
        if let b = vm.buocHienTai, !b.isEmpty { return b }
        return phaCho == 0 ? "CuongMini đang suy nghĩ" : "Bạn đợi tớ chút nhé…"
    }

    private var dangLam: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text(loiCho)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: loiCho)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Capsule().fill(AppColors.backgroundSecondary))
        // `id:` là số tin — mỗi câu hỏi mới là một lượt chờ mới, nên nhịp phải
        // quay lại từ đầu. Thiếu cái này thì từ câu thứ hai trở đi người dùng
        // chỉ còn thấy nhịp sau.
        .task(id: vm.tin.count) {
            phaCho = 0
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if !Task.isCancelled { phaCho = 1 }
        }
    }

    // MARK: Ô nhập

    private var oNhap: some View {
        VStack(spacing: 0) {
            Divider().background(AppColors.divider)
            if !dinhKem.isEmpty { daiDinhKem }
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                // Ảnh/tệp CHỈ đi được ở bậc Claude — bậc nhanh nhận chuỗi
                // thuần, đính vào đó là rơi vào hư không mà không báo lỗi.
                if vm.bac.nhanTep { nutKep }
                TextField("Nhắn cho CuongMini…", text: $cauHoi, axis: .vertical)
                    .font(.bodyMedium)
                    .lineLimit(1...6)
                    .focused($dangGo)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 20)
                        .fill(AppColors.backgroundTertiary))

                if vm.dangTraLoi {
                    // Nút DỪNG — câu trả lời dài có thể chạy cả phút, không có
                    // nút này thì người dùng chỉ còn cách thoát màn hình.
                    Button { vm.dung() } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(AppColors.error)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { gui() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(guiDuoc ? AppColors.primary : AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!guiDuoc)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(AppColors.backgroundSecondary)
    }

    private var coChu: Bool { !cauHoi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: Đính kèm

    private var guiDuoc: Bool { coChu || !dinhKem.isEmpty }

    private var nutKep: some View {
        Menu {
            Button { hienChonTep = true } label: {
                Label("Tệp (PDF, Word, văn bản)", systemImage: "doc")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(AppColors.textSecondary)
        } primaryAction: {
            hienChonTep = true
        }
        .overlay(alignment: .center) {
            // PhotosPicker phải là nút RIÊNG, không lồng trong Menu được:
            // trình chọn ảnh của hệ thống cần chính nó trình bày sheet.
            PhotosPicker(selection: $anhChon,
                         maxSelectionCount: HanMucDinhKem.soAnh,
                         matching: .images) {
                Color.clear.frame(width: 28, height: 28)
            }
            .opacity(0.011)
        }
    }

    private var daiDinhKem: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dinhKem) { d in
                    HStack(spacing: 6) {
                        if d.laAnh, let ui = PlatformImage(data: d.duLieu) {
                            Image(platformImage: ui).resizable().scaledToFill()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        } else {
                            Image(systemName: d.bieuTuong).foregroundColor(AppColors.primary)
                        }
                        Text(d.ten).font(.system(size: 12)).lineLimit(1)
                            .foregroundColor(AppColors.textPrimary)
                        Button {
                            dinhKem.removeAll { $0.id == d.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.backgroundTertiary))
                }
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, 6)
        }
        .frame(maxHeight: 46)
    }

    /// Đọc ảnh vừa chọn. `PhotosPickerItem` chỉ giao dữ liệu bất đồng bộ.
    private func napAnh(_ mucs: [PhotosPickerItem]) async {
        for muc in mucs.prefix(HanMucDinhKem.soAnh) {
            guard let d = try? await muc.loadTransferable(type: Data.self) else { continue }
            // Nén lại: ảnh gốc iPhone ~4MB, mà cả thân yêu cầu bị chặn ở 10MB.
            // `jpegDataForUpload` còn thu nhỏ về 1600px trước khi nén.
            let nen = PlatformImage(data: d)?.jpegDataForUpload() ?? d
            dinhKem.append(DinhKemAI(ten: "ảnh.jpg", mime: "image/jpeg", duLieu: nen))
        }
        anhChon = []
    }

    private func napTep(_ kq: Result<[URL], Error>) {
        guard case .success(let urls) = kq else { return }
        for url in urls.prefix(HanMucDinhKem.soTep) {
            // Tệp ngoài hộp cát cần xin quyền rồi TRẢ LẠI, không thì lần chọn
            // sau bị từ chối im lặng.
            let mo = url.startAccessingSecurityScopedResource()
            defer { if mo { url.stopAccessingSecurityScopedResource() } }
            guard let d = try? Data(contentsOf: url) else {
                vm.loi = "Không đọc được “\(url.lastPathComponent)”."; continue
            }
            guard d.count <= HanMucDinhKem.byteMoiTep else {
                vm.loi = "“\(url.lastPathComponent)” nặng quá 6MB."; continue
            }
            dinhKem.append(DinhKemAI(ten: url.lastPathComponent,
                                     mime: HanMucDinhKem.mime(cho: url),
                                     duLieu: d))
        }
    }

    private func gui() {
        let c = cauHoi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty || !dinhKem.isEmpty else { return }
        let anh = dinhKem.filter(\.laAnh).map(\.dataURL)
        let tep = dinhKem.filter { !$0.laAnh }
        cauHoi = ""
        dinhKem = []
        dangGo = false
        Haptics.cham()
        vm.gui(c, anh: anh, tep: tep.map(\.dataURL), tenTep: tep.map(\.ten))
    }
}

// MARK: - Bong bóng

struct BongBongAI: View {
    let tin: TinAI
    @State private var daChep = false
    @State private var hienBaoCao = false

    var body: some View {
        VStack(alignment: tin.cuaNguoi ? .trailing : .leading, spacing: 4) {
            if tin.cuaNguoi {
                Text(tin.noiDung)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppColors.primary))
                    .frame(maxWidth: 300, alignment: .trailing)
            } else {
                // Câu trả lời dựng theo ĐÚNG luật của bài viết: tiêu đề, khối
                // mã tô màu, đường kẻ. AI hay trả lời kèm mã, để chữ trơn thì
                // mã dính liền văn xuôi và không đọc được.
                NoiDungBaiViet(noiDung: tin.noiDung)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !tin.dangChay {
                    HStack(spacing: Spacing.md) {
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = tin.noiDung
                            #endif
                            Haptics.cham(); daChep = true
                            Task { try? await Task.sleep(nanoseconds: 1_500_000_000); daChep = false }
                        } label: {
                            Label(daChep ? "Đã chép" : "Chép", systemImage: daChep ? "checkmark" : "doc.on.doc")
                        }
                        // App Store 1.2: người dùng phải báo cáo được câu trả
                        // lời không phù hợp. Backend đã có `/ai/feedback`.
                        Button { hienBaoCao = true } label: {
                            Label("Báo cáo", systemImage: "flag")
                        }
                        Spacer()
                        if let m = tin.model {
                            Text(m).font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: tin.cuaNguoi ? .trailing : .leading)
        .alert("Báo cáo câu trả lời", isPresented: $hienBaoCao) {
            Button("Gửi báo cáo", role: .destructive) {
                Task { _ = try? await APIClient.shared.send(.baoCaoTraLoiAI(messageId: tin.messageId)) }
            }
            Button("Huỷ", role: .cancel) { }
        } message: {
            Text("Câu trả lời này sai, gây hiểu lầm, hoặc không phù hợp? Báo cho chúng tôi để cải thiện.")
        }
    }
}

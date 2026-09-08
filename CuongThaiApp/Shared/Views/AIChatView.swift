import SwiftUI
import PhotosUI

/// Trò chuyện với AI. Chữ hiện DẦN theo luồng SSE, không đợi cả câu.
struct AIChatView: View {
    /// Câu hỏi điền sẵn khi mở màn. Dùng khi vào từ một ngữ cảnh cụ thể —
    /// vd bấm "Nhờ AI kiểm tra bài" ở một môn: câu mở đầu đã hướng sẵn sang
    /// "hỏi mình 5 câu", chứ để trống thì người dùng lại gõ "tóm tắt giúp
    /// mình" và mất đúng phần có ích (tự trả lời).
    var cauMoDau: String? = nil

    /// Bậc AI muốn mở sẵn. `nil` = giữ bậc người dùng chọn lần trước.
    /// Dùng khi vào từ một lối đã hứa hẹn sẵn một bậc cụ thể — vd thẻ "Chat
    /// nhanh với CuongMini Pro" ở trang chủ: mở ra mà đang ở bậc Mini thì
    /// đúng là nói một đằng làm một nẻo.
    var bacBanDau: BacAI? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AIChatViewModel()
    @State private var cauHoi = ""
    /// 0 = "đang suy nghĩ", 1 = "đợi tớ chút nhé". Xem `loiCho`.
    @State private var phaCho = 0
    @State private var hienChonModel = false
    @State private var dinhKem: [DinhKemAI] = []
    @State private var anhChon: [PhotosPickerItem] = []
    @State private var hienChonTep = false
    @State private var hienLichSu = false
    @StateObject private var ghiAm = GhiAmThoai()
    @StateObject private var mayDoc = MayDoc()
    @State private var hienNoiChuyen = false
    @State private var dangNhanDang = false
    @State private var hienMayAnh = false
    @State private var suaTin: TinAI?
    @State private var chuSua = ""
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
            .onAppear {
                // Chỉ điền khi ô còn trống: người dùng quay lại màn này giữa
                // chừng thì không được đè lên thứ họ đang gõ dở.
                if cauHoi.isEmpty, let c = cauMoDau { cauHoi = c }
                // Chỉ đặt khi hội thoại còn TRỐNG: quay lại màn giữa chừng mà
                // bị nhảy bậc thì những lượt đã hỏi và lượt sắp hỏi trả lời
                // bằng hai model khác nhau.
                if vm.tin.isEmpty, let b = bacBanDau { vm.bac = b }
            }
            .navigationTitle(vm.bacHienTai.ten)
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
                // Nút riêng, không giấu trong menu ⋮: đây là thứ người dùng
                // với tới nhiều thứ hai sau ô nhập.
                ToolbarItem(placement: .navigation) {
                    Button { hienLichSu = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
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
                        if !vm.tin.isEmpty {
                            ShareLink(item: vm.xuatMarkdown()) {
                                Label("Chia sẻ cuộc này", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Sửa câu hỏi", isPresented: .constant(suaTin != nil)) {
                TextField("Câu hỏi", text: $chuSua, axis: .vertical)
                Button("Huỷ", role: .cancel) { suaTin = nil }
                Button("Hỏi lại") {
                    if let t = suaTin { Task { await vm.suaVaHoiLai(t, thanh: chuSua) } }
                    suaTin = nil
                }
            } message: {
                Text("Mọi tin sau câu này sẽ bị bỏ.")
            }
            .alert("AI", isPresented: .constant(vm.loi != nil)) {
                Button("OK") { vm.loi = nil }
            } message: { Text(vm.loi ?? "") }
            // ⚠️ Máy đọc vốn nuốt lỗi: `MayDoc.loi` được gán nhưng KHÔNG chỗ
            // nào hiện nó, nên 429 "đang có 2 bản đọc chạy dở" trông y hệt
            // "bấm không ăn gì". Dồn vào đúng hộp báo lỗi đã có sẵn.
            .fullScreenCover(isPresented: $hienNoiChuyen) {
                CheDoNoiView(vm: vm, mayDoc: mayDoc)
            }
            .onChange(of: mayDoc.loi) { _, moi in
                guard let moi, !moi.isEmpty else { return }
                vm.loi = moi
                mayDoc.loi = nil
            }
            .onChange(of: anhChon) { _, moi in
                guard !moi.isEmpty else { return }
                Task { await napAnh(moi) }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $hienMayAnh) {
                MayAnh { d in
                    namBacNeuCan()
                    let nen = PlatformImage(data: d)?.jpegDataForUpload() ?? d
                    dinhKem.append(DinhKemAI(ten: "ảnh-chụp.jpg", mime: "image/jpeg", duLieu: nen))
                }
                .ignoresSafeArea()
            }
            #endif
            .sheet(isPresented: $hienLichSu) {
                LichSuChatView { p in Task { await vm.moCuoc(p) } }
            }
            .fileImporter(isPresented: $hienChonTep,
                          allowedContentTypes: HanMucDinhKem.loaiTep,
                          allowsMultipleSelection: true) { napTep($0) }
            // Đổi xuống bậc nhanh mà đang có đính kèm thì NÓI RA rồi bỏ —
            // giữ lại chỉ làm người dùng tưởng nó vẫn được gửi đi.
            .onChange(of: vm.bac) { _, b in
                if !b.nhanTep && !dinhKem.isEmpty {
                    dinhKem = []
                    vm.loi = "CuongMini3.11 chưa đọc được ảnh và tệp nên đã bỏ phần đính kèm."
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
                        BongBongAI(tin: t, mayDoc: mayDoc,
                                   taoLai: t.id == vm.tin.last?.id && !vm.dangTraLoi
                                           ? { vm.taoLai() } : nil,
                                   sua: t.cuaNguoi && !vm.dangTraLoi
                                        ? { chuSua = t.noiDung; suaTin = t } : nil)
                            .id(t.id)
                    }
                    if coChu || !dinhKem.isEmpty {
                    EmptyView()
                } else if !vm.dangTraLoi {
                    // Micro chỉ hiện khi CHƯA gõ gì — có chữ rồi thì chỗ đó là
                    // nút gửi, đổi qua đổi lại dưới ngón tay là bấm nhầm.
                    HStack(spacing: Spacing.lg) {
                        nutMicro
                        nutNoiChuyen
                    }
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
                // LUÔN hiện. Ẩn theo bậc thì người dùng mở app ở bậc mặc định
                // là không thấy nút nào và tưởng app không gửi được ảnh —
                // đúng thứ đã xảy ra. Đính kèm ở bậc nhanh thì tự nâng bậc.
                nutKep
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

    /// Mở chế độ nói chuyện rảnh tay.
    ///
    /// Khác `nutMicro` ở chỗ căn bản: micro chỉ ĐỌC CHÍNH TẢ vào ô nhập, còn
    /// đây là hội thoại — AI trả lời xong tự đọc lên rồi chờ lượt sau.
    private var nutNoiChuyen: some View {
        Button {
            Haptics.cham()
            hienNoiChuyen = true
        } label: {
            Image(systemName: "waveform.circle")
                .font(.system(size: 26))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Nói chuyện với CuongMini")
    }

    /// Giữ để nói, thả để gửi đi nhận dạng.
    private var nutMicro: some View {
        Image(systemName: dangNhanDang ? "waveform" : (ghiAm.dangGhi ? "mic.fill" : "mic"))
            .font(.system(size: 26))
            .foregroundColor(ghiAm.dangGhi ? AppColors.error : AppColors.textSecondary)
            .frame(width: 34, height: 34)
            .overlay(alignment: .top) {
                if ghiAm.dangGhi {
                    Text("\(ghiAm.giay)s")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.error)
                        .offset(y: -13)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !ghiAm.dangGhi, !dangNhanDang else { return }
                        Haptics.cham()
                        Task { await ghiAm.batDau() }
                    }
                    .onEnded { _ in ketThucNoi() }
            )
            .disabled(dangNhanDang)
    }

    private func ketThucNoi() {
        guard let thu = ghiAm.dungLai() else { return }
        dangNhanDang = true
        Task {
            defer { dangNhanDang = false }
            do {
                if let chu = try await GiongNoiAI.chuTuGiong(thu.data) {
                    // Ghép vào chữ đang có thay vì đè — người dùng có thể gõ
                    // một nửa rồi nói nốt.
                    cauHoi = cauHoi.isEmpty ? chu : cauHoi + " " + chu
                } else {
                    vm.loi = "Chưa nghe rõ, thử nói lại gần micro hơn nhé."
                }
            } catch {
                vm.loi = "Không nhận dạng được giọng nói."
            }
        }
    }

    /// Hai nút RIÊNG, không gộp vào Menu.
    ///
    /// ⚠️ `PhotosPicker` KHÔNG lồng được trong `Menu`: nó phải tự trình bày
    /// sheet của hệ thống, nên đặt trong Menu thì cú chạm bị Menu nuốt và chỉ
    /// mở được nhánh còn lại. Đã dính đúng lỗi này — bấm `+` luôn ra Tệp.
    private var nutKep: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $anhChon,
                         maxSelectionCount: HanMucDinhKem.soAnh,
                         matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.textSecondary)
            }
            #if os(iOS)
            if MayAnh.coMayAnh {
                Button { hienMayAnh = true } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 21))
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            #endif
            Button { hienChonTep = true } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 21))
                    .foregroundColor(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 6)
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

    /// Bậc nhanh không đọc được ảnh/tệp, nên đính kèm là tự nâng lên Pro.
    ///
    /// Nâng thay vì chặn: người dùng vừa chọn xong cái ảnh, chặn lại rồi bắt
    /// họ tự đi tìm bảng chọn bậc là một bước thừa mà họ không đoán ra.
    private func namBacNeuCan() {
        guard !vm.bac.nhanTep else { return }
        vm.bac = .pro
        vm.loi = "Đã chuyển sang CuongMini Pro — chỉ bậc Pro và Max mới đọc được ảnh và tệp."
    }

    /// Đọc ảnh vừa chọn. `PhotosPickerItem` chỉ giao dữ liệu bất đồng bộ.
    private func napAnh(_ mucs: [PhotosPickerItem]) async {
        for muc in mucs.prefix(HanMucDinhKem.soAnh) {
            guard let d = try? await muc.loadTransferable(type: Data.self) else { continue }
            // Nén lại: ảnh gốc iPhone ~4MB, mà cả thân yêu cầu bị chặn ở 10MB.
            // `jpegDataForUpload` còn thu nhỏ về 1600px trước khi nén.
            let nen = PlatformImage(data: d)?.jpegDataForUpload() ?? d
            namBacNeuCan()
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
            namBacNeuCan()
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
    /// Máy đọc dùng CHUNG cho cả khung chat, không phải mỗi bong bóng một cái:
    /// hai giọng chồng lên nhau là thứ không có nút nào dừng được.
    @ObservedObject var mayDoc: MayDoc
    /// `nil` = không cho tạo lại ở tin này (chỉ tin CUỐI mới cho).
    var taoLai: (() -> Void)?
    /// `nil` = không phải tin của mình.
    var sua: (() -> Void)?
    @State private var daChep = false
    @State private var hienBaoCao = false

    private var dangDocTin: Bool { mayDoc.dangDoc == tin.id && !mayDoc.dangCho }
    /// Máy đọc đang bận vì TIN NÀY — kể cả lúc còn đang nạp tiếng.
    private var mayBanVoiTinNay: Bool { mayDoc.dangDoc == tin.id }

    /// Chữ trên nút. Phải nói ra là đang chạy: bản cũ chỉ đổi cái biểu tượng
    /// nhỏ sang đồng hồ cát mà chữ vẫn là "Nghe", nên người dùng tưởng bấm
    /// hụt và bấm lại — mà bấm lại thì HUỶ mất lượt đang chạy.
    private var chuNutNghe: String {
        guard mayBanVoiTinNay else { return "Nghe" }
        if mayDoc.dangCho { return "Đang tạo…" }
        if mayDoc.tongMau > 1 { return "Dừng \(mayDoc.mau)/\(mayDoc.tongMau)" }
        return "Dừng"
    }

    /// Nguồn model đã đọc — bấm mở được, vì "theo một bài trên VnExpress" mà
    /// không kèm đường dẫn thì người đọc không kiểm chứng được gì.
    private var theNguon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(tin.nguon) { n in
                    Link(destination: URL(string: n.url) ?? URL(string: "https://cuongthai.com")!) {
                        HStack(spacing: 5) {
                            Image(systemName: "link").font(.system(size: 9))
                            Text(n.mien.isEmpty ? n.tieuDe : n.mien)
                                .font(.system(size: 11)).lineLimit(1)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 32)
    }

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
                    // Chạm-giữ để sửa: đặt một nút nhỏ cạnh mọi tin của mình
                    // thì khung chat rối, mà đây là việc thỉnh thoảng mới làm.
                    .contextMenu {
                        if let sua {
                            Button(action: sua) { Label("Sửa và hỏi lại", systemImage: "pencil") }
                        }
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = tin.noiDung
                            #endif
                        } label: { Label("Chép", systemImage: "doc.on.doc") }
                    }
                if sua != nil {
                    Text("Chạm giữ để sửa")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
            } else {
                // Câu trả lời dựng theo ĐÚNG luật của bài viết: tiêu đề, khối
                // mã tô màu, đường kẻ. AI hay trả lời kèm mã, để chữ trơn thì
                // mã dính liền văn xuôi và không đọc được.
                // Markdown chuẩn của model — KHÔNG dùng bộ dựng bài đăng,
                // xem đầu file NoiDungMarkdown.swift.
                NoiDungMarkdown(noiDung: tin.noiDung)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !tin.nguon.isEmpty { theNguon }
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
                        Button {
                            mayDoc.batTat(tin.id, chu: tin.noiDung)
                        } label: {
                            Label(chuNutNghe,
                                  systemImage: mayDoc.dangCho && mayBanVoiTinNay
                                    ? "hourglass"
                                    : (dangDocTin ? "stop.circle" : "speaker.wave.2"))
                        }
                        .foregroundColor(mayBanVoiTinNay ? AppColors.primary : AppColors.textSecondary)
                        if let taoLai {
                            Button(action: taoLai) {
                                Label("Tạo lại", systemImage: "arrow.clockwise")
                            }
                        }
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

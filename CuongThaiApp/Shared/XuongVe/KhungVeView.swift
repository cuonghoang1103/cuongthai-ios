import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif

/// Khung vẽ — nơi thật sự vẽ.
///
/// Hai chế độ, đổi bằng nút ở thanh trên:
///   · **Nét tay** — PencilKit nhận chạm, bảng công cụ của Apple hiện ra
///   · **Hình khối** — PencilKit KHÔNG nhận chạm nữa, chạm để chọn và kéo hình
///
/// ⚠️ Hai chế độ phải LOẠI TRỪ nhau. Để cả hai cùng nhận chạm thì kéo một ô
/// chữ nhật cũng vẽ ra một nét bút đi theo, và người dùng không hiểu vì sao
/// bản vẽ đầy vệt. Đây là cùng bài học với lớp tô của bài đọc.
struct KhungVeView: View {
    @State var banVe: BanVe
    @StateObject private var kho = KhoBanVe.chung
    @Environment(\.dismiss) private var dong

    @State private var cheDo: CheDo = .net
    @StateObject private var bo = BoBut()
    @State private var lanHoanTac = 0
    @State private var lanLamLai = 0
    @State private var lanXoaHet = 0
    @State private var dangChon: UUID?
    @State private var moThemHinh = false
    @State private var moCaiDat = false
    @State private var tiLe: CGFloat = 1
    @State private var tiLeGoc: CGFloat = 1
    @State private var bao: String?
    @State private var suaChu: HinhVe?

    enum CheDo: String, CaseIterable { case net, hinh }

    private var hinhDangChon: HinhVe? {
        banVe.hinh.first { $0.id == dangChon }
    }

    var body: some View {
        VStack(spacing: 0) {
            thanhCongCu
            // Thanh bút nằm TRONG màn, không phải bảng nổi của hệ thống —
            // bảng nổi có lúc không gắn được và khi đó không còn cách nào
            // đổi bút. Chỉ hiện ở chế độ vẽ nét.
            if cheDo == .net {
                ThanhBut(bo: bo,
                         hoanTac: { lanHoanTac += 1 },
                         lamLai: { lanLamLai += 1 },
                         xoaHet: { lanXoaHet += 1 })
                Divider()
            }
            khungGiay
            if cheDo == .hinh, hinhDangChon != nil { thanhSuaHinh }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(banVe.ten)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { xuatPNG() } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel(T("Xuất ảnh PNG"))
                Button { moCaiDat = true } label: { Image(systemName: "slider.horizontal.3") }
            }
        }
        .sheet(isPresented: $moThemHinh) { manThemHinh }
        .sheet(isPresented: $moCaiDat) { manCaiDat }
        .sheet(item: $suaChu) { h in manSuaChu(h) }
        .overlay(alignment: .bottom) {
            if let b = bao {
                Text(b).font(.captionBold).foregroundStyle(Color.white)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                    .background(Capsule().fill(Color.black.opacity(0.78)))
                    .padding(.bottom, Spacing.xl)
                    .transition(.opacity)
            }
        }
        .onDisappear { kho.luu(banVe) }
    }

    // MARK: Thanh công cụ

    private var thanhCongCu: some View {
        HStack(spacing: Spacing.sm) {
            Picker("", selection: $cheDo) {
                Label(T("Nét tay"), systemImage: "scribble").tag(CheDo.net)
                Label(T("Hình khối"), systemImage: "square.on.circle").tag(CheDo.hinh)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            if cheDo == .hinh {
                Button { moThemHinh = true } label: {
                    Label(T("Thêm hình"), systemImage: "plus")
                        .font(.buttonSmall)
                        .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 6)
                        .background(AppColors.primary).foregroundStyle(Color.white)
                        .cornerRadius(CornerRadius.full)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Chạm vào số % để về 100%. Phóng lạc rồi mà phải bấm − mười lần
            // mới về chỗ cũ là thứ làm người ta bỏ dùng nút phóng.
            Button { withAnimation(AppAnimations.quick) { tiLe = keo(tiLe / 1.3) } } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .accessibilityLabel(T("Thu nhỏ"))
            Button { withAnimation(AppAnimations.quick) { tiLe = keo(tiLe * 1.3) } } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .accessibilityLabel(T("Phóng to"))
            Button { withAnimation(AppAnimations.quick) { tiLe = 1 } } label: {
                Text("\(Int(tiLe * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 48)
            }
            .buttonStyle(.plain)
            Button { doiTiLe(-1) } label: { Image(systemName: "minus.magnifyingglass") }
                .buttonStyle(.plain).foregroundStyle(AppColors.textSecondary)
            Button { doiTiLe(1) } label: { Image(systemName: "plus.magnifyingglass") }
                .buttonStyle(.plain).foregroundStyle(AppColors.textSecondary)
            Button { vuaKhung() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .buttonStyle(.plain).foregroundStyle(AppColors.textSecondary)
                .accessibilityLabel(T("Vừa khung"))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
    }

    // MARK: Khung giấy

    private var khungGiay: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color(maHex: banVe.nen))
                    .frame(width: banVe.coKhung.width, height: banVe.coKhung.height)

                // Nền giấy nằm TRÊN màu nền, DƯỚI hình và nét — lưới phải
                // thấy được qua hình trong suốt, nhưng không che nét bút.
                GiayLuoi(kieu: banVe.giay, buoc: banVe.buocThat, co: banVe.coKhung)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 3)

                // Tầng hình khối nằm DƯỚI tầng nét tay: nét bút là thứ viết
                // thêm lên trên bố cục, không phải thứ bị bố cục che.
                ForEach(banVe.hinh) { h in
                    hinhKeoDuoc(h)
                }

                #if os(iOS)
                LopNetXuongVe(ma: banVe.id, choCham: cheDo == .net, bo: bo,
                              lanHoanTac: lanHoanTac, lanLamLai: lanLamLai,
                              lanXoaHet: lanXoaHet)
                    .frame(width: banVe.coKhung.width, height: banVe.coKhung.height)
                    .allowsHitTesting(cheDo == .net)
                #endif
            }
            .frame(width: banVe.coKhung.width, height: banVe.coKhung.height)
            .scaleEffect(tiLe, anchor: .topLeading)
            .frame(width: banVe.coKhung.width * tiLe, height: banVe.coKhung.height * tiLe)
            .padding(Spacing.lg)
        }
        .background(AppColors.backgroundTertiary)
        // Chụm hai ngón để phóng — cách phóng mà ai cầm iPad cũng thử đầu
        // tiên. Chỉ có hai nút ±25% thì người dùng chụm tay, thấy không ăn,
        // rồi kết luận là app không phóng được.
        //
        // ⚠️ Chỉ bật khi ĐANG Ở CHẾ ĐỘ HÌNH KHỐI. Ở chế độ nét tay, PencilKit
        // cần hai ngón cho thao tác của chính nó, và cướp cử chỉ đó làm việc
        // hoàn tác/cuộn của bảng vẽ hỏng.
        // ⚠️ Phóng phải chạy ở CẢ HAI chế độ. Bản cũ chỉ bật ở chế độ Hình,
        // nên đang vẽ bài giảng thì KHÔNG zoom được — mà vẽ mới là việc
        // chính. Người dùng báo 20/09/2026: "tôi zoom to zoom nhỏ bằng tay
        // không được".
        //
        // `.simultaneousGesture` chứ không `.gesture`: PencilKit cần giữ cử
        // chỉ vẽ của nó, thay hẳn thì hai ngón phóng được nhưng một ngón
        // không vẽ được nữa.
        .simultaneousGesture(phongHaiNgon)
        // ⚠️ Đo bề ngang bằng GeometryReader, KHÔNG qua `connectedScenes`.
        // Với Stage Manager có hai cửa sổ thì `connectedScenes.first` là cửa
        // sổ NÀO là chuyện may rủi — "vừa khung" sẽ tính theo bề ngang của
        // cửa sổ bên kia. Và kéo đổi cỡ cửa sổ thì số đo cũ thành sai mà
        // không có gì báo; cách này tự cập nhật.
        .background(GeometryReader { g in
            Color.clear
                .onAppear { rongKhungNhin = g.size.width }
                .onChange(of: g.size.width) { _, moi in rongKhungNhin = moi }
        })
    }

    /// Bề ngang khung nhìn, để tính "vừa khung".
    @State private var rongKhungNhin: CGFloat = 0

    private var phongHaiNgon: some Gesture {
        MagnifyGesture()
            .onChanged { g in
                if tiLeGoc == 0 { tiLeGoc = tiLe }
                tiLe = keo(tiLeGoc * g.magnification)
            }
            .onEnded { _ in tiLeGoc = tiLe }
    }

    /// Trần 8× chứ không 3×: bản vẽ khổ Web rộng 1440pt, muốn sửa một chi
    /// tiết 20pt thì 300% vẫn còn quá nhỏ để chạm trúng bằng ngón tay.
    private func keo(_ v: CGFloat) -> CGFloat { min(8, max(0.1, v)) }

    private func doiTiLe(_ huong: Int) {
        // Nhân/chia 1,25 thay vì cộng/trừ 0,25: ở mức 800% thì bước cộng
        // 0,25 là không thấy gì đổi, còn ở 25% thì nó nhảy gấp đôi.
        withAnimation(AppAnimations.quick) {
            tiLe = keo(huong > 0 ? tiLe * 1.25 : tiLe / 1.25)
            tiLeGoc = tiLe
        }
    }

    private func vuaKhung() {
        guard rongKhungNhin > 0 else { return }
        withAnimation(AppAnimations.quick) {
            tiLe = keo((rongKhungNhin - Spacing.lg * 2) / banVe.coKhung.width)
            tiLeGoc = tiLe
        }
    }


    private func hinhKeoDuoc(_ h: HinhVe) -> some View {
        let chon = dangChon == h.id && cheDo == .hinh
        return VeMotHinh(hinh: h)
            .frame(width: h.rong, height: h.cao)
            .overlay {
                if chon {
                    Rectangle().stroke(AppColors.primary, lineWidth: 1.5 / tiLe)
                    // Tay nắm ở góc dưới phải để đổi cỡ. Chia cho `tiLe` để
                    // nó giữ nguyên kích thước trên màn hình dù phóng to —
                    // không chia thì lúc thu nhỏ 25% nó bé tới mức không bắt
                    // được ngón tay.
                    Circle().fill(AppColors.primary)
                        .frame(width: 14 / tiLe, height: 14 / tiLe)
                        .offset(x: h.rong / 2, y: h.cao / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { g in
                                    doiHinh(h.id) {
                                        $0.rong = max(16, h.rong + g.translation.width / tiLe)
                                        $0.cao = max(16, h.cao + g.translation.height / tiLe)
                                    }
                                }
                                .onEnded { _ in kho.luu(banVe) }
                        )
                }
            }
            .offset(x: h.x, y: h.y)
            .gesture(
                cheDo == .hinh
                    ? DragGesture()
                        .onChanged { g in
                            dangChon = h.id
                            doiHinh(h.id) {
                                $0.x = h.x + g.translation.width / tiLe
                                $0.y = h.y + g.translation.height / tiLe
                            }
                        }
                        .onEnded { _ in kho.luu(banVe) }
                    : nil
            )
            .onTapGesture {
                guard cheDo == .hinh else { return }
                dangChon = h.id
                if h.loai == .chu { suaChu = h }
            }
    }

    private func doiHinh(_ id: UUID, _ sua: (inout HinhVe) -> Void) {
        guard let i = banVe.hinh.firstIndex(where: { $0.id == id }) else { return }
        sua(&banVe.hinh[i])
    }

    // MARK: Thanh sửa hình

    private var thanhSuaHinh: some View {
        VStack(spacing: Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(BangMau.mau, id: \.self) { m in
                        Button {
                            guard let id = dangChon else { return }
                            doiHinh(id) { h in
                                if h.loai == .chu { h.mauChu = m } else { h.mauNen = m }
                            }
                            kho.luu(banVe)
                        } label: {
                            Circle().fill(Color(maHex: m))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(AppColors.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }

            HStack(spacing: Spacing.md) {
                if let h = hinhDangChon, h.loai != .chu {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.lefthalf.filled").font(.caption)
                        Slider(value: Binding(
                            get: { hinhDangChon?.doMo ?? 1 },
                            set: { v in if let id = dangChon { doiHinh(id) { $0.doMo = v } } }
                        ), in: 0.1...1) { dung in if !dung { kho.luu(banVe) } }
                        .frame(width: 110)
                    }
                }
                Button {
                    guard let id = dangChon else { return }
                    banVe.hinh.removeAll { $0.id == id }
                    dangChon = nil
                    kho.luu(banVe)
                } label: {
                    Label(T("Xoá hình"), systemImage: "trash").font(.buttonSmall)
                }
                .buttonStyle(.plain).foregroundStyle(AppColors.error)
                Spacer()
                Button(T("Bỏ chọn")) { dangChon = nil }
                    .font(.buttonSmall).buttonStyle(.plain)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
    }

    // MARK: Thêm hình

    private var manThemHinh: some View {
        NavigationStack {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: Spacing.md)], spacing: Spacing.md) {
                ForEach(LoaiHinh.allCases) { l in
                    Button { them(l) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: l.bieuTuong)
                                .font(.system(size: 26)).foregroundStyle(AppColors.primary)
                            Text(l.ten).font(.caption).foregroundStyle(AppColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(AppColors.backgroundCard)
                        .cornerRadius(CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Thêm hình"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { moThemHinh = false } } }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    private func them(_ l: LoaiHinh) {
        // Đặt vào giữa khung chứ không ở góc (0,0): hình mới ở góc trên bên
        // trái thường nằm khuất sau thanh công cụ, và người dùng bấm Thêm mấy
        // lần liền vì tưởng nút không ăn.
        let rong: Double = l == .duong || l == .muiTen ? 160 : (l == .chu ? 200 : 140)
        let cao: Double = l == .duong || l == .muiTen ? 24 : (l == .chu ? 40 : 100)
        var h = HinhVe(loai: l,
                       x: (banVe.coKhung.width - rong) / 2,
                       y: (banVe.coKhung.height - cao) / 2,
                       rong: rong, cao: cao)
        if l == .chu { h.chu = T("Chữ mới") }
        banVe.hinh.append(h)
        dangChon = h.id
        kho.luu(banVe)
        moThemHinh = false
        cheDo = .hinh
        if l == .chu { suaChu = h }
    }

    private func manSuaChu(_ h: HinhVe) -> some View {
        NavigationStack {
            Form {
                Section(T("Nội dung")) {
                    TextField(T("Chữ"), text: Binding(
                        get: { banVe.hinh.first { $0.id == h.id }?.chu ?? "" },
                        set: { v in doiHinh(h.id) { $0.chu = v } }
                    ), axis: .vertical)
                    .lineLimit(1...5)
                }
                Section(T("Cỡ chữ")) {
                    Slider(value: Binding(
                        get: { banVe.hinh.first { $0.id == h.id }?.coChu ?? 20 },
                        set: { v in doiHinh(h.id) { $0.coChu = v } }
                    ), in: 10...72, step: 1)
                    Text("\(Int(banVe.hinh.first { $0.id == h.id }?.coChu ?? 20)) pt")
                        .font(.caption).foregroundStyle(AppColors.textTertiary)
                }
            }
            .navigationTitle(T("Sửa chữ"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Xong")) { kho.luu(banVe); suaChu = nil }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    // MARK: Cài đặt bản vẽ

    private var manCaiDat: some View {
        NavigationStack {
            Form {
                Section(T("Tên")) {
                    TextField(T("Tên bản vẽ"), text: $banVe.ten)
                }
                Section(T("Màu nền")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: Spacing.sm) {
                        ForEach(BangMau.mau, id: \.self) { m in
                            Button { banVe.nen = m } label: {
                                Circle().fill(Color(maHex: m))
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(
                                        banVe.nen == m ? AppColors.primary : AppColors.border,
                                        lineWidth: banVe.nen == m ? 3 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    Picker(T("Kiểu giấy"), selection: $banVe.giay) {
                        ForEach(KieuGiay.allCases) { g in
                            Label(g.ten, systemImage: g.bieuTuong).tag(g)
                        }
                    }
                    if banVe.giay != .trang {
                        HStack {
                            Text(T("Bước lưới")).font(.subheadline)
                            Slider(value: Binding(
                                get: { banVe.buocThat },
                                set: { banVe.buocLuoi = $0 }), in: 8...120, step: 2)
                            Text(String(format: "%.0f", banVe.buocThat))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(AppColors.textTertiary).frame(width: 32)
                        }
                    }
                } header: {
                    Text(T("Nền giấy"))
                } footer: {
                    Text(T("Ô vuông và ca-rô để vẽ trục toạ độ, hình học, bảng biểu. Tam giác đều để vẽ phối cảnh."))
                }
                Section(T("Khổ giấy")) {
                    Picker(T("Khổ"), selection: $banVe.kho) {
                        ForEach(KhoVe.allCases) { k in Text("\(k.ten) · \(k.moTa)").tag(k) }
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
            }
            .navigationTitle(T("Bản vẽ"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Xong")) { kho.luu(banVe); moCaiDat = false }
                }
            }
        }
    }

    // MARK: Xuất PNG

    /// Dựng ảnh từ CẢ HAI tầng rồi lưu vào Ảnh.
    ///
    /// Phải ghép tay chứ không chụp màn hình: ảnh chụp màn chỉ có phần đang
    /// nhìn thấy và mang theo cả thanh công cụ, còn bản vẽ có thể rộng hơn
    /// màn hình nhiều lần.
    private func xuatPNG() {
        #if os(iOS)
        let co = banVe.coKhung
        let tv = UIGraphicsImageRenderer(size: co)
        let anh = tv.image { ctx in
            UIColor(Color(maHex: banVe.nen)).setFill()
            ctx.fill(CGRect(origin: .zero, size: co))

            // Tầng hình: vẽ qua `ImageRenderer` của SwiftUI, đúng những gì
            // màn hình đang hiện — không vẽ lại bằng Core Graphics, vì hai
            // đường vẽ sẽ trôi khỏi nhau ngay lần sửa hình đầu tiên.
            let tang = ZStack(alignment: .topLeading) {
                ForEach(banVe.hinh) { h in
                    VeMotHinh(hinh: h).frame(width: h.rong, height: h.cao).offset(x: h.x, y: h.y)
                }
            }
            .frame(width: co.width, height: co.height, alignment: .topLeading)

            let r = ImageRenderer(content: tang)
            r.scale = 2
            if let ui = r.uiImage { ui.draw(in: CGRect(origin: .zero, size: co)) }

            if let d = try? Data(contentsOf: KhoBanVe.duongNet(banVe.id)),
               let dr = try? PKDrawing(data: d) {
                dr.image(from: CGRect(origin: .zero, size: co), scale: 2)
                    .draw(in: CGRect(origin: .zero, size: co))
            }
        }
        UIImageWriteToSavedPhotosAlbum(anh, nil, nil, nil)
        khoe(T("Đã lưu ảnh vào Ảnh"))
        #endif
    }

    private func khoe(_ c: String) {
        withAnimation { bao = c }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { if bao == c { bao = nil } }
        }
    }
}

// MARK: - Tầng nét tay

#if os(iOS)
struct LopNetXuongVe: UIViewRepresentable {
    let ma: UUID
    let choCham: Bool
    @ObservedObject var bo: BoBut
    /// Tăng để yêu cầu hoàn tác / làm lại / xoá hết.
    var lanHoanTac: Int = 0
    var lanLamLai: Int = 0
    var lanXoaHet: Int = 0

    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView()
        v.backgroundColor = .clear
        v.isOpaque = false
        v.drawingPolicy = .anyInput
        v.tool = bo.congCu
        // Cho phóng và kéo bằng ngón NGAY TRONG bảng vẽ: `PKCanvasView` vốn
        // là một `UIScrollView`, nhưng không đặt hai trần này thì nó không
        // phóng được — đúng chỗ người dùng kêu "zoom bằng tay không được".
        v.minimumZoomScale = 0.2
        v.maximumZoomScale = 6
        v.bouncesZoom = true
        if let d = try? Data(contentsOf: KhoBanVe.duongNet(ma)), let dr = try? PKDrawing(data: d) {
            v.drawing = dr
        }
        v.delegate = context.coordinator
        context.coordinator.ma = ma
        return v
    }

    func updateUIView(_ v: PKCanvasView, context: Context) {
        // Bảng công cụ chỉ hiện ở chế độ nét. Để nó nằm lại khi đã sang chế
        // độ hình thì nó che mất thanh sửa hình ở đáy màn.
        // ⚠️ `PKToolPicker.shared(for:)` phải nhận ĐÚNG cửa sổ chứa bảng vẽ
        // này, không phải `windows.first` của scene. Khi bật đa cửa sổ
        // (Stage Manager) thì `windows.first` có thể là cửa sổ KIA — bảng
        // công cụ gắn vào đó, và ở cửa sổ đang vẽ nó không hiện ra: câm
        // lặng, không lỗi. Đây đúng là bẫy "ToolPicker câm" đã gặp.
        // Công cụ theo thanh bút trong app. So trước khi gán: gán lại mỗi
        // khung hình làm PencilKit dựng lại bộ vẽ và nét đang kéo bị đứt.
        let moi = bo.congCu
        if !cungCongCu(v.tool, moi) { v.tool = moi }

        if context.coordinator.lanHoanTac != lanHoanTac {
            context.coordinator.lanHoanTac = lanHoanTac
            if lanHoanTac > 0 { v.undoManager?.undo() }
        }
        if context.coordinator.lanLamLai != lanLamLai {
            context.coordinator.lanLamLai = lanLamLai
            if lanLamLai > 0 { v.undoManager?.redo() }
        }
        if context.coordinator.lanXoaHet != lanXoaHet {
            context.coordinator.lanXoaHet = lanXoaHet
            if lanXoaHet > 0 { v.drawing = PKDrawing() }
        }

        gan(v)
        // ⚠️ `v.window` còn `nil` ở lần cập nhật ĐẦU — lúc đó `if let` lặng
        // lẽ không gắn gì và bảng công cụ KHÔNG BAO GIỜ hiện ra, không một
        // dòng lỗi. Người dùng báo 20/09/2026: "ấn nút không có tẩy, bút,
        // màu". Thử lại ở khung hình sau cho tới khi có cửa sổ thật.
        if v.window == nil {
            DispatchQueue.main.async { [weak v] in
                guard let v else { return }
                gan(v)
                if v.window == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak v] in
                        if let v { gan(v) }
                    }
                }
            }
        }

        func gan(_ v: PKCanvasView) {
            guard let cuaSo = v.window else { return }
            let picker = PKToolPicker.shared(for: cuaSo)
            picker?.addObserver(v)
            picker?.setVisible(choCham, forFirstResponder: v)
            if choCham { v.becomeFirstResponder() } else { v.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Luu { Luu() }

    /// So hai công cụ có "giống nhau đủ" không. `PKTool` không `Equatable`
    /// nên phải so tay từng thuộc tính.
    private func cungCongCu(_ a: PKTool, _ b: PKTool) -> Bool {
        if let x = a as? PKInkingTool, let y = b as? PKInkingTool {
            return x.inkType == y.inkType && x.color == y.color && abs(x.width - y.width) < 0.01
        }
        if let x = a as? PKEraserTool, let y = b as? PKEraserTool {
            return x.eraserType == y.eraserType && abs(x.width - y.width) < 0.01
        }
        return false
    }

    final class Luu: NSObject, PKCanvasViewDelegate {
        var ma: UUID?
        var lanHoanTac = 0
        var lanLamLai = 0
        var lanXoaHet = 0
        private var hen: DispatchWorkItem?

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            hen?.cancel()
            let d = canvasView.drawing.dataRepresentation()
            guard let m = ma else { return }
            let viec = DispatchWorkItem { try? d.write(to: KhoBanVe.duongNet(m), options: .atomic) }
            hen = viec
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.2, execute: viec)
        }
    }
}
#endif

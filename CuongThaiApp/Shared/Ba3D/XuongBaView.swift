import SwiftUI
#if canImport(SceneKit)
import SceneKit
#endif

// MARK: - Danh sách mô hình

/// Xưởng 3D — dựng mô hình bằng cách ghép khối.
///
/// ⚠️ NÓI RÕ GIỚI HẠN NGAY TRÊN MÀN HÌNH, không giấu trong tài liệu. Đây là
/// trình dựng KHỐI: ghép hộp/cầu/trụ/nón, đặt vị trí, xoay, phóng, tô màu,
/// xuất `.usdz`. Nó KHÔNG nặn từng đỉnh, không chạm khắc, không trải UV.
///
/// Người mở ra mà tưởng đây là Blender sẽ bỏ sau năm phút; người biết trước
/// nó ghép khối thì dùng đúng việc nó làm được.
struct XuongBaView: View {
    var coNutDong = false

    @StateObject private var kho = KhoCanhBa.chung
    @Environment(\.dismiss) private var dong
    @State private var tenMoi = ""
    @State private var moTao = false
    @State private var hoiXoa: CanhBa?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    theGioiHan
                    if kho.danhSach.isEmpty {
                        KhungTrongTien(bieuTuong: "cube.transparent",
                                       tieuDe: T("Chưa có mô hình nào"),
                                       moTa: T("Ghép khối thành hình, tô màu, rồi xuất ra .usdz để xem bằng AR hoặc gửi đi."),
                                       tenNut: T("Tạo mô hình")) { tenMoi = ""; moTao = true }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: Spacing.md)], spacing: Spacing.md) {
                            ForEach(kho.danhSach) { c in
                                NavigationLink { KhungBaView(canh: c) } label: { the(c) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) { hoiXoa = c } label: {
                                            Label(T("Xoá"), systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Xưởng 3D"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if coNutDong {
                    ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { tenMoi = ""; moTao = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $moTao) { manTao }
            .alert(T("Xoá mô hình này?"), isPresented: Binding(
                get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } })) {
                Button(T("Huỷ"), role: .cancel) { hoiXoa = nil }
                Button(T("Xoá"), role: .destructive) { if let c = hoiXoa { kho.xoa(c) }; hoiXoa = nil }
            }
            .task { kho.nap() }
        }
    }

    private var theGioiHan: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "info.circle.fill").foregroundStyle(AppColors.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(T("Đây là trình dựng KHỐI")).font(.captionBold)
                    .foregroundStyle(AppColors.textPrimary)
                Text(T("Ghép hộp, cầu, trụ, nón thành hình; đặt vị trí, xoay, phóng, tô màu, xuất .usdz. Chưa nặn được từng đỉnh hay chạm khắc — việc đó cần một trình dựng lưới riêng."))
                    .font(.caption).foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondary.opacity(0.10))
        .cornerRadius(CornerRadius.large)
    }

    private func the(_ c: CanhBa) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.medium).fill(Color(maHex: c.mauNen))
                Image(systemName: "cube.transparent")
                    .font(.system(size: 34)).foregroundStyle(.white.opacity(0.55))
            }
            .frame(height: 112)
            Text(c.ten).font(.bodyMedium).foregroundStyle(AppColors.textPrimary).lineLimit(1)
            Text("\(c.khoi.count) \(T("khối"))").font(.caption2).foregroundStyle(AppColors.textTertiary)
        }
        .padding(Spacing.sm)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var manTao: some View {
        NavigationStack {
            Form { Section { TextField(T("Tên mô hình"), text: $tenMoi) } }
                .navigationTitle(T("Mô hình mới"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { moTao = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(T("Tạo")) { _ = kho.moi(ten: tenMoi); moTao = false }
                    }
                }
        }
        // KHÔNG đặt `presentationDetents` ở đây. Trên iPad một sheet cao 220pt
        // là ô nổi nhỏ giữa màn, và vùng tối quanh nó đóng sheet khi chạm —
        // chạm trượt một chút là mất cả thứ vừa gõ. Sheet thường (kích thước
        // hệ thống tự chọn) rộng hơn và khó bấm nhầm hơn hẳn.
    }
}

// MARK: - Khung dựng

#if canImport(SceneKit) && os(iOS)
struct KhungBaView: View {
    @State var canh: CanhBa
    @StateObject private var kho = KhoCanhBa.chung

    @State private var dangChon: UUID?
    /// Tăng lên một là khung 3D đưa camera về khung mặc định.
    @State private var lanDongKhung = 0
    @State private var moThem = false
    @State private var moMau = false
    @State private var moNhapTep = false
    @State private var bao: String?
    @State private var chiaSe: URL?

    @State private var lichSu: [[KhoiBa]] = []
    @State private var lamLaiDuoc: [[KhoiBa]] = []
    /// Một cú kéo sinh hàng trăm lần gọi `keoKhoi`. Chỉ chụp lịch sử ở lần
    /// ĐẦU, không thì bấm hoàn tác một cái chỉ lùi được một milimét.
    @State private var dangKeo = false
    @State private var lanChupAnh = 0
    @State private var xemAR: URL?
    @State private var moNhanDay = false
    @State private var soBan = 4
    @State private var buocDay = SIMD3<Double>(1, 0, 0)

    private var khoiDangChon: KhoiBa? { canh.khoi.first { $0.id == dangChon } }

    /// Tách khỏi `body`: ba closure dựng ngay trong tham số khởi tạo là chỗ
    /// bộ suy kiểu của Swift hay bỏ cuộc nhất ("unable to type-check in
    /// reasonable time"), và nó không chỉ ra dòng nào có lỗi.
    private var khung3D: some View {
        CanhSceneKit(canh: canh,
                     chon: dangChon,
                     khiChon: chonKhoi,
                     khiKeo: keoKhoi,
                     khiThaKeo: luuNgay,
                     thuMucTep: KhoCanhBa.thuMucTep(canh.id),
                     lanDongKhung: lanDongKhung,
                     lanChupAnh: lanChupAnh,
                     khiChupXong: { anh in luuAnh(anh) })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(maHex: canh.mauNen))
            // Thả tệp từ Files/Split View thẳng vào cảnh. Trên iPad đây là
            // đường tự nhiên hơn hẳn menu → chọn tệp → duyệt thư mục.
            .dropDestination(for: URL.self) { ds, _ in
                guard let u = ds.first else { return false }
                let duoi = u.pathExtension.lowercased()
                guard ["usdz", "usd", "usda", "usdc", "obj", "dae", "scn"].contains(duoi) else {
                    khoe(T("Chỉ thả được mô hình 3D: .usdz, .obj, .dae"))
                    return false
                }
                nhapTuURL(u)
                return true
            }
    }

    /// Khối đã KHOÁ thì bỏ qua — sàn nằm dưới mọi thứ nên nó là thứ hay bị
    /// chạm trúng nhất khi người dùng nhắm vào khối bên trên.
    private func chonKhoi(_ id: UUID) {
        if canh.khoi.first(where: { $0.id == id })?.khoa == true { return }
        dangChon = id
    }

    // ════════════════════════════════════════════════════════════════
    // HOÀN TÁC / LÀM LẠI
    //
    // Trước 20/09/2026 xưởng KHÔNG có hoàn tác. Với một công cụ dựng hình
    // thì đó là thiếu sót nặng hơn mọi tính năng cao siêu: xoá nhầm một
    // khối là mất hẳn, kéo hỏng một cụm là phải tự kéo về bằng mắt.
    //
    // Lưu nguyên mảng khối thay vì lưu "thao tác nghịch đảo": cảnh nặng
    // nhất cũng chỉ vài trăm khối, mỗi khối là struct nhỏ — chép cả mảng
    // rẻ hơn nhiều so với công sức viết (và gỡ lỗi) từng phép nghịch đảo.
    // ════════════════════════════════════════════════════════════════

    /// Chụp trạng thái TRƯỚC khi đổi. Gọi ở ĐẦU mỗi thao tác làm đổi khối.
    private func ghiNho() {
        lichSu.append(canh.khoi)
        if lichSu.count > 60 { lichSu.removeFirst() }
        // Làm một việc mới thì nhánh "làm lại" cũ không còn nghĩa nữa.
        lamLaiDuoc.removeAll()
    }

    private func hoanTac() {
        guard let truoc = lichSu.popLast() else { return }
        lamLaiDuoc.append(canh.khoi)
        canh.khoi = truoc
        giuChonHopLe()
        kho.luu(canh)
    }

    private func lamLai() {
        guard let sau = lamLaiDuoc.popLast() else { return }
        lichSu.append(canh.khoi)
        canh.khoi = sau
        giuChonHopLe()
        kho.luu(canh)
    }

    /// Khối đang chọn có thể vừa biến mất sau khi lùi/tiến — để nguyên thì
    /// bảng chỉnh bám vào một id không còn ai, và mọi thanh trượt về 0.
    private func giuChonHopLe() {
        if let c = dangChon, !canh.khoi.contains(where: { $0.id == c }) { dangChon = nil }
    }

    private func luuNgay() { dangKeo = false; kho.luu(canh) }

    var body: some View {
        VStack(spacing: 0) {
            khung3D

            danhSachKhoi
            if khoiDangChon != nil { bangChinh }
        }
        .navigationTitle(canh.ten)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { hoanTac() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(lichSu.isEmpty)
                    .keyboardShortcut("z", modifiers: .command)
                    .accessibilityLabel(T("Hoàn tác"))
                Button { lamLai() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(lamLaiDuoc.isEmpty)
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .accessibilityLabel(T("Làm lại"))
                menuThem
                Menu {
                    Button { xuatGlb() } label: {
                        Label(T(".glb — cho game (three.js, Unity, Godot)"), systemImage: "cube.transparent")
                    }
                    Button { xuatObj() } label: {
                        Label(T(".obj + .mtl — mở được ở mọi phần mềm"), systemImage: "doc.on.doc")
                    }
                    Button { xuatUsdz() } label: {
                        Label(T(".usdz — gửi qua tin nhắn, xem AR"), systemImage: "arkit")
                    }
                } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel(T("Xuất"))
            }
        }
        .sheet(isPresented: $moThem) { manThem }
        .sheet(isPresented: $moNhanDay) { manNhanDay }
        .sheet(isPresented: $moMau) { manMau }
        .fileImporter(isPresented: $moNhapTep,
                      allowedContentTypes: [.usdz, .threeDContent, .item],
                      allowsMultipleSelection: false) { kq in nhapTep(kq) }
        .fullScreenCover(item: Binding(get: { xemAR.map { TepChiaSe(url: $0) } },
                                       set: { xemAR = $0?.url })) { t in
            XemAR(url: t.url).ignoresSafeArea()
        }
        .sheet(item: Binding(get: { chiaSe.map { TepChiaSe(url: $0) } },
                             set: { chiaSe = $0?.url })) { t in
            BangChiaSe(url: t.url)
        }
        .overlay(alignment: .bottom) {
            if let b = bao {
                Text(b).font(.captionBold).foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                    .background(Capsule().fill(.black.opacity(0.78)))
                    .padding(.bottom, Spacing.xl)
            }
        }
        .onDisappear { kho.luu(canh) }
    }

    /// Tách khỏi `.toolbar` vì bộ suy kiểu của Swift bỏ dịch khi `Menu` chứa
    /// cả `Toggle` lẫn `Picker` có `Binding` dựng tại chỗ.
    private var menuThem: some View {
        Menu {
            Button { moMau = true } label: { Label(T("Mẫu dựng sẵn"), systemImage: "square.stack.3d.up") }
            Button { moThem = true } label: { Label(T("Khối cơ bản"), systemImage: "cube") }
            Button { moNhapTep = true } label: { Label(T("Nhập tệp .usdz / .obj"), systemImage: "square.and.arrow.down") }
            Divider()
            Button { canh.luoi.toggle(); kho.luu(canh) } label: {
                Label(canh.luoi ? T("Tắt lưới sàn") : T("Bật lưới sàn"), systemImage: "grid")
            }
            Divider()
            Button { lanChupAnh += 1 } label: {
                Label(T("Chụp ảnh mô hình"), systemImage: "camera")
            }
            Button { moAR() } label: {
                Label(T("Xem trong phòng (AR)"), systemImage: "arkit")
            }
            Divider()
            Button { lanDongKhung += 1 } label: {
                Label(T("Đóng khung lại"), systemImage: "viewfinder")
            }
            Menu(T("Bắt điểm")) {
                ForEach([0.0, 0.25, 0.5, 1.0], id: \.self) { b in
                    Button { canh.buocBat = b; kho.luu(canh) } label: {
                        Label(b == 0 ? T("Tắt") : String(format: "%.2g", b),
                              systemImage: canh.buocBat == b ? "checkmark" : "")
                    }
                }
            }
        } label: { Image(systemName: "plus.circle") }
    }

    // MARK: Danh sách khối

    private var danhSachKhoi: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(canh.khoi) { k in
                    Button { if !k.khoa { dangChon = k.id } } label: {
                        HStack(spacing: 5) {
                            Image(systemName: k.khoa ? "lock.fill" : k.loai.bieuTuong).font(.caption)
                            Text(k.tenHien).font(.caption)
                            if k.nhom != nil {
                                Image(systemName: "link").font(.system(size: 9))
                                    .opacity(0.7)
                            }
                        }
                        .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 7)
                        .background(dangChon == k.id ? AppColors.primary : AppColors.backgroundTertiary)
                        .foregroundStyle(dangChon == k.id ? Color.white : AppColors.textPrimary)
                        .cornerRadius(CornerRadius.full)
                        .opacity(k.khoa ? 0.5 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.sm)
        }
        .background(AppColors.backgroundCard)
    }

    // MARK: Bảng chỉnh

    private var bangChinh: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Ba nhóm thanh trượt thay vì tay nắm kéo trong không gian 3D.
                // Tay nắm 3D nhìn thì sang nhưng chạm trượt liên tục trên màn
                // cảm ứng, và người dùng kéo nhầm trục mà không biết. Số trên
                // thanh trượt thì đọc được và lặp lại được.
                nhom(T("Vị trí"), [
                    ("X", \.x, -5.0...5.0), ("Y", \.y, -5.0...5.0), ("Z", \.z, -5.0...5.0),
                ])
                nhom(T("Xoay (độ)"), [
                    ("X", \.xoayX, -180.0...180.0), ("Y", \.xoayY, -180.0...180.0), ("Z", \.xoayZ, -180.0...180.0),
                ])
                nhom(T("Kích thước"), [
                    ("X", \.coX, 0.1...5.0), ("Y", \.coY, 0.1...5.0), ("Z", \.coZ, 0.1...5.0),
                ])

                Text(T("Màu & chất liệu")).font(.captionBold).foregroundStyle(AppColors.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(BangMau.mau, id: \.self) { m in
                            Button { ghiNho(); sua { $0.mau = m } } label: {
                                Circle().fill(Color(maHex: m)).frame(width: 26, height: 26)
                                    .overlay(Circle().stroke(AppColors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if khoiDangChon?.loai == .nhap {
                    Toggle(isOn: Binding(
                        get: { khoiDangChon?.toDe ?? false },
                        set: { v in ghiNho(); sua { $0.toDe = v } })) {
                        Text(T("Tô đè màu lên mô hình nhập"))
                            .font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                    }
                    Text(T("Tắt thì mô hình giữ vật liệu của tệp. Bật thì cả mô hình mang màu ở trên — dùng cho tệp .obj trần không kèm vật liệu."))
                        .font(.caption2).foregroundStyle(AppColors.textTertiary)
                }
                thanhTruot(T("Kim loại"), \.kimLoai, 0...1)
                thanhTruot(T("Nhám"), \.nham, 0...1)

                hangNut
            }
            .padding(Spacing.md)
        }
        .frame(height: 300)
        .background(AppColors.backgroundCard)
    }

    /// Hàng thao tác. Tách khỏi thân `bangChinh` vì lý do KỸ THUẬT: nhét sáu
    /// nút có closure vào cùng một `ScrollView` lồng trong `VStack` là quá
    /// nhiều cho bộ suy kiểu của Swift, và nó bỏ dịch chứ không báo lỗi rõ.
    private var hangNut: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                nutNho(T("Nhân đôi"), "plus.square.on.square", AppColors.primary) { nhanDoi(guong: false) }
                nutNho(T("Gương ↔"), "arrow.left.and.right", AppColors.secondary) { nhanDoi(guong: true) }
                nutNho(T("Xuống sàn"), "arrow.down.to.line", AppColors.accent) { datXuongSan() }
                nutNho(khoiDangChon?.nhom == nil ? T("Gộp nhóm") : T("Rời nhóm"),
                       "link", AppColors.primary) { doiNhom() }
                nutNho(khoiDangChon?.khoa == true ? T("Mở khoá") : T("Khoá"),
                       khoiDangChon?.khoa == true ? "lock.open" : "lock",
                       AppColors.textSecondary) { ghiNho(); sua { $0.khoa.toggle() }; kho.luu(canh) }
                menuBoolean
                nutNho(T("Nhân dãy"), "square.grid.3x1.below.line.grid.1x2",
                       AppColors.secondary) { moNhanDay = true }
                nutNho(T("Xoá"), "trash", AppColors.error) { xoaKhoi() }
            }
            .padding(.horizontal, 2)
        }
        .padding(.top, 2)
    }

    /// Phép Boolean: chọn PHÉP trước rồi chọn khối thứ hai.
    ///
    /// Không dùng "khối liền trước" như nút gộp nhóm: khoét là thao tác có
    /// hướng (A trừ B khác B trừ A), chọn nhầm khối là ra hình ngược hẳn mà
    /// người dùng không đoán được vì sao.
    private var menuBoolean: some View {
        Menu {
            if khacNgoaiKhoiChon.isEmpty {
                Text(T("Cần ít nhất hai khối"))
            } else {
                ForEach(PhepBa.allCases) { p in
                    Menu {
                        ForEach(khacNgoaiKhoiChon) { k in
                            Button(k.tenHien) { lamBoolean(p, voi: k.id) }
                        }
                    } label: { Label(p.ten, systemImage: p.bieuTuong) }
                }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "circle.lefthalf.filled").font(.system(size: 16))
                Text(T("Boolean")).font(.system(size: 10))
            }
            .foregroundStyle(AppColors.accent)
            .frame(width: 62, height: 44)
            .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(AppColors.accent.opacity(0.12)))
        }
    }

    private var khacNgoaiKhoiChon: [KhoiBa] {
        canh.khoi.filter { $0.id != dangChon && $0.loai != .phang }
    }

    /// Bảng nhân dãy.
    private var manNhanDay: some View {
        NavigationStack {
            Form {
                Section(T("Số bản")) {
                    Stepper(value: $soBan, in: 2...40) {
                        Text(String(format: T("%d bản"), soBan))
                    }
                }
                Section {
                    buocTruot("X", 0); buocTruot("Y", 1); buocTruot("Z", 2)
                } header: {
                    Text(T("Khoảng cách mỗi bước"))
                } footer: {
                    Text(T("Hàng rào thì đặt bước theo X; bậc thang thì X và Y cùng khác 0."))
                }
                Section {
                    Button {
                        nhanDay(so: soBan, dx: buocDay.x, dy: buocDay.y, dz: buocDay.z)
                        moNhanDay = false
                    } label: {
                        Label(T("Nhân dãy"), systemImage: "square.grid.3x1.below.line.grid.1x2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(buocDay == .zero)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(T("Nhân dãy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Đóng")) { moNhanDay = false }
                }
            }
        }
    }

    private func buocTruot(_ nhan: String, _ i: Int) -> some View {
        HStack {
            Text(nhan).font(.caption).frame(width: 18, alignment: .leading)
            Slider(value: Binding(get: { buocDay[i] }, set: { buocDay[i] = $0 }), in: -4...4, step: 0.05)
            Text(String(format: "%.2f", buocDay[i]))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.textTertiary).frame(width: 44, alignment: .trailing)
        }
    }

    private func nutNho(_ ten: String, _ bt: String, _ mau: Color, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            VStack(spacing: 2) {
                Image(systemName: bt).font(.system(size: 15))
                Text(ten).font(.system(size: 10))
            }
            .foregroundStyle(mau)
            .frame(minWidth: 58)
        }
        .buttonStyle(.plain)
    }

    /// Xoá cả NHÓM nếu khối thuộc nhóm — xoá lẻ một khối của cụm để lại năm
    /// mảnh rời không ai dọn.
    private func xoaKhoi() {
        ghiNho()
        guard let id = dangChon else { return }
        if let n = khoiDangChon?.nhom {
            canh.khoi.removeAll { $0.nhom == n }
        } else {
            canh.khoi.removeAll { $0.id == id }
        }
        dangChon = nil
        kho.luu(canh)
    }

    /// Kéo một khối. Khối thuộc NHÓM thì cả nhóm dời theo cùng độ lệch.
    private func keoKhoi(_ id: UUID, _ x: Double, _ y: Double, _ z: Double) {
        guard let i = canh.khoi.firstIndex(where: { $0.id == id }) else { return }
        if !dangKeo { ghiNho(); dangKeo = true }
        let dx = x - canh.khoi[i].x, dy = y - canh.khoi[i].y, dz = z - canh.khoi[i].z
        if let n = canh.khoi[i].nhom {
            for j in canh.khoi.indices where canh.khoi[j].nhom == n {
                canh.khoi[j].x += dx; canh.khoi[j].y += dy; canh.khoi[j].z += dz
            }
        } else {
            canh.khoi[i].x = x; canh.khoi[i].y = y; canh.khoi[i].z = z
        }
    }

    /// Nhân đôi, có thể LẬT GƯƠNG. Nhân vật đối xứng trái/phải là việc gặp ở
    /// mọi mô hình có tay chân — không có nút này thì mỗi bên dựng một lượt
    /// rồi tự canh cho cân, và không bao giờ cân.
    private func nhanDoi(guong: Bool) {
        guard let goc = khoiDangChon else { return }
        ghiNho()
        let cum = goc.nhom.map { n in canh.khoi.filter { $0.nhom == n } } ?? [goc]
        let nhomMoi: String? = goc.nhom == nil ? nil : MauDungSan.maNhom("cum")
        var idDau: UUID?
        for k in cum {
            var m = k
            m.id = UUID()
            m.nhom = nhomMoi
            if guong {
                m.x = -k.x
                m.xoayY = -k.xoayY
                m.xoayZ = -k.xoayZ
                m.ten = k.ten.isEmpty ? "" : k.ten + " ↔"
            } else {
                m.x = k.x + 0.6
            }
            canh.khoi.append(m)
            if idDau == nil { idDau = m.id }
        }
        dangChon = idDau
        kho.luu(canh)
    }

    /// Hạ khối chạm mặt sàn. Canh bằng mắt là việc không làm được: nhìn
    /// nghiêng thì lơ lửng 0,1 với chìm 0,1 trông y hệt nhau.
    private func datXuongSan() {
        ghiNho()
        sua { $0.y = -0.5 + DungCanh.nuaCao($0) }
        kho.luu(canh)
    }

    private func doiNhom() {
        guard let k = khoiDangChon else { return }
        ghiNho()
        if k.nhom != nil {
            sua { $0.nhom = nil }
        } else if let i = canh.khoi.firstIndex(where: { $0.id == k.id }), i > 0 {
            // Gộp với khối LIỀN TRƯỚC — thao tác hay dùng nhất là vừa dựng
            // thêm một khối cho cụm đang làm dở.
            let n = canh.khoi[i - 1].nhom ?? MauDungSan.maNhom("cum")
            if canh.khoi[i - 1].nhom == nil { canh.khoi[i - 1].nhom = n }
            canh.khoi[i].nhom = n
        }
        kho.luu(canh)
    }

    private func nhom(_ ten: String, _ truc: [(String, WritableKeyPath<KhoiBa, Double>, ClosedRange<Double>)]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ten).font(.captionBold).foregroundStyle(AppColors.textSecondary)
            ForEach(truc, id: \.0) { nhan, kp, khoang in
                thanhTruot(nhan, kp, khoang)
            }
        }
    }

    private func thanhTruot(_ nhan: String, _ kp: WritableKeyPath<KhoiBa, Double>, _ khoang: ClosedRange<Double>) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(nhan).font(.caption2).foregroundStyle(AppColors.textTertiary).frame(width: 52, alignment: .leading)
            Slider(value: Binding(
                get: { khoiDangChon?[keyPath: kp] ?? 0 },
                set: { v in sua { $0[keyPath: kp] = v } }
            ), in: khoang) { dung in
                // `dung == true` là lúc BẮT ĐẦU kéo thanh trượt.
                if dung { ghiNho() } else { kho.luu(canh) }
            }
            Text(String(format: "%.2f", khoiDangChon?[keyPath: kp] ?? 0))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.textTertiary).frame(width: 46, alignment: .trailing)
        }
    }

    private func sua(_ f: (inout KhoiBa) -> Void) {
        guard let id = dangChon, let i = canh.khoi.firstIndex(where: { $0.id == id }) else { return }
        f(&canh.khoi[i])
    }

    // MARK: Thêm khối

    private var manThem: some View {
        NavigationStack {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: Spacing.md)], spacing: Spacing.md) {
                ForEach(LoaiKhoi.allCases) { l in
                    Button {
                        ghiNho()
                        var k = KhoiBa(loai: l)
                        k.ten = "\(l.ten) \(canh.khoi.filter { $0.loai == l }.count + 1)"
                        canh.khoi.append(k)
                        dangChon = k.id
                        kho.luu(canh)
                        moThem = false
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: l.bieuTuong).font(.system(size: 26))
                                .foregroundStyle(AppColors.primary)
                            Text(l.ten).font(.caption).foregroundStyle(AppColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                        .background(AppColors.backgroundCard).cornerRadius(CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Thêm khối"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { moThem = false } } }
        }
        .presentationDetents([.medium])
    }

    // MARK: Mẫu dựng sẵn

    private var manMau: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)],
                          spacing: Spacing.md) {
                    ForEach(MauDungSan.tatCa) { m in
                        Button { chenMau(m) } label: { theMau(m) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Mẫu dựng sẵn"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { moMau = false } } }
        }
    }

    private func theMau(_ m: MauDungSan.Mau) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: m.bieuTuong)
                .font(.system(size: 28)).foregroundStyle(AppColors.primary)
            Text(T(m.ten)).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
            Text(T(m.moTa)).font(.caption2).foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
    }

    private func chenMau(_ m: MauDungSan.Mau) {
        ghiNho()
        let them = m.dung(MauDungSan.maNhom(m.nhom))
        canh.khoi.append(contentsOf: them)
        dangChon = them.first?.id
        kho.luu(canh)
        moMau = false
    }

    // MARK: Nhập tệp

    /// Chép tệp vào thư mục của CẢNH rồi mới tham chiếu.
    ///
    /// ⚠️ Không giữ URL gốc. Tệp người dùng chọn nằm ngoài hộp cát của app và
    /// quyền đọc nó chỉ sống trong phạm vi `startAccessingSecurityScopedResource`
    /// — giữ đường dẫn thì mở lại cảnh ngày mai là mô hình biến mất, mà lúc
    /// đó không còn gì để lần ra vì sao.
    private func nhapTep(_ kq: Result<[URL], Error>) {
        guard case .success(let ds) = kq, let u = ds.first else { return }
        nhapTuURL(u)
    }

    /// Nhận mô hình từ MỘT url — dùng chung cho nút "Nhập tệp" và cho cú THẢ.
    ///
    /// Tách ra vì hai lối vào phải xử lý y hệt nhau: cùng chép vào hộp cát,
    /// cùng dựng thử để bắt tệp hỏng. Viết hai bản là sớm muộn một bên quên
    /// mất một bước — và bên quên sẽ là bên ít người dùng hơn, nên lỗi nằm
    /// đó rất lâu.
    private func nhapTuURL(_ u: URL) {
        let mo = u.startAccessingSecurityScopedResource()
        defer { if mo { u.stopAccessingSecurityScopedResource() } }

        let duoi = u.pathExtension.isEmpty ? "usdz" : u.pathExtension
        let ten = "\(UUID().uuidString).\(duoi)"
        let dich = KhoCanhBa.thuMucTep(canh.id).appendingPathComponent(ten)
        do {
            try FileManager.default.copyItem(at: u, to: dich)
        } catch {
            khoe(T("Không đọc được tệp này"))
            return
        }
        // Dựng thử NGAY: tệp hỏng thì báo luôn, thay vì để lại một khối xám
        // rỗng trong cảnh mà người dùng không biết vì sao nó ở đó.
        guard (try? SCNScene(url: dich)) != nil else {
            try? FileManager.default.removeItem(at: dich)
            khoe(T("Không phải mô hình 3D đọc được (.usdz, .obj, .dae)"))
            return
        }
        ghiNho()
        var k = KhoiBa(loai: .nhap, ten: u.deletingPathExtension().lastPathComponent)
        k.tepNhap = ten
        // Đo chiều cao THẬT ngay lúc nhập, sau khi đã chuẩn hoá cỡ. Đo lúc
        // này là rẻ nhất — về sau `datXuongSan` chỉ đọc con số, không phải
        // dựng lại cảnh để hỏi SceneKit.
        k.caoGoc = DungCanh.caoSauChuanHoa(dich)
        canh.khoi.append(k)
        dangChon = k.id
        kho.luu(canh)
        khoe(T("Đã nhập mô hình"))
    }

    // MARK: Xuất .usdz

    /// `.usdz` là định dạng Apple dùng cho AR Quick Look: gửi qua tin nhắn là
    /// người nhận xem xoay được ngay, không cần cài gì. Đó là lý do xuất
    /// `.usdz` chứ không phải một định dạng "chuẩn hơn" mà không ai mở được
    /// trên điện thoại.
    /// Ghi ảnh vừa chụp ra tệp rồi mở bảng chia sẻ.
    private func luuAnh(_ anh: UIImage) {
        guard let d = anh.pngData() else { khoe(T("Không chụp được ảnh")); return }
        let t = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(canh.ten.replacingOccurrences(of: "/", with: "-")).png")
        do { try d.write(to: t); chiaSe = t }
        catch { khoe(T("Không lưu được ảnh")) }
    }

    /// Mở AR Quick Look: đặt mô hình ra bàn thật qua camera.
    ///
    /// Dùng CHUNG đường xuất `.usdz` nên mọi thứ đã sửa ở đó (kèm mô hình
    /// nhập, bỏ lưới sàn) tự có hiệu lực ở đây.
    private func moAR() {
        guard let d = dungTepUsdz() else { khoe(T("Không dựng được mô hình để xem AR")); return }
        xemAR = d
    }

    /// Dựng tệp `.usdz` tạm. Trả `nil` nếu ghi hỏng.
    private func dungTepUsdz() -> URL? {
        let scn = DungCanh.dung(canh, chon: nil,
                                thuMucTep: KhoCanhBa.thuMucTep(canh.id),
                                keLuoi: false)
        let d = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(canh.ten.replacingOccurrences(of: "/", with: "-")).usdz")
        return scn.write(to: d, options: nil, delegate: nil, progressHandler: nil) ? d : nil
    }

    /// Xuất `.glb` — định dạng đi được vào game.
    ///
    /// three.js và Babylon.js nạp thẳng cho web 3D game; Unity, Godot,
    /// Blender đều đọc. Máy KHÔNG xuất sẵn được (đo 20/09/2026: ModelIO
    /// xuất obj/ply/stl/usd, SceneKit ghi scn/usdz — không cái nào ra glb),
    /// nên bộ xuất là tự viết, và đã qua bộ kiểm chính thức của Khronos:
    /// 0 lỗi, 0 cảnh báo.
    private func xuatGlb() {
        let ms = Boolean3D.manhCuaCanh(canh, thuMucTep: KhoCanhBa.thuMucTep(canh.id))
        guard let d = DungGLB.glb(ms, tenMoHinh: canh.ten) else {
            khoe(T("Cảnh chưa có khối nào để xuất")); return
        }
        let t = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(tenTep).glb")
        do { try d.write(to: t); chiaSe = t }
        catch { khoe(T("Không ghi được tệp .glb")) }
    }

    /// Xuất `.obj` + `.mtl` gói trong một thư mục — phần mềm nào cũng mở.
    private func xuatObj() {
        let ms = Boolean3D.manhCuaCanh(canh, thuMucTep: KhoCanhBa.thuMucTep(canh.id))
        guard !ms.isEmpty else { khoe(T("Cảnh chưa có khối nào để xuất")); return }
        let (o, mtl) = DungGLB.obj(ms, tenMoHinh: tenTep)
        let thuMuc = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(tenTep)-obj", isDirectory: true)
        do {
            try? FileManager.default.removeItem(at: thuMuc)
            try FileManager.default.createDirectory(at: thuMuc, withIntermediateDirectories: true)
            try o.write(to: thuMuc.appendingPathComponent("\(tenTep).obj"),
                        atomically: true, encoding: .utf8)
            // ⚠️ `.mtl` phải nằm CẠNH `.obj` và đúng tên đã khai trong
            // `mtllib`, không thì mở ra mất sạch màu.
            try mtl.write(to: thuMuc.appendingPathComponent("\(tenTep).mtl"),
                          atomically: true, encoding: .utf8)
            chiaSe = thuMuc
        } catch { khoe(T("Không ghi được tệp .obj")) }
    }

    /// Tên tệp an toàn: bỏ dấu gạch chéo và khoảng trắng đầu/cuối.
    private var tenTep: String {
        let t = canh.ten.replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "mo-hinh" : t
    }

    private func xuatUsdz() {
        // ⚠️ PHẢI truyền `thuMucTep`. Thiếu nó thì `dungNut` không mở được
        // tệp nhập và rơi vào nhánh "khối xám thay thế" — tệp xuất ra có
        // mọi thứ ĐÚNG CHỖ nhưng mô hình nhập biến thành hộp xám, mà nhìn
        // trong app thì vẫn thấy mô hình nên không ai nghi ngờ gì.
        //
        // ⚠️ Và `keLuoi: false`: lưới sàn là đồ nghề của xưởng, không phải
        // một phần của mô hình. Kèm vào thì người nhận mở AR Quick Look ra
        // thấy 20×20 vạch kẻ lơ lửng quanh vật.
        if let d = dungTepUsdz() { chiaSe = d }
        else { khoe(T("Không xuất được tệp .usdz")) }
    }

    private func khoe(_ c: String) {
        withAnimation { bao = c }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { if bao == c { bao = nil } }
        }
    }
}

private struct TepChiaSe: Identifiable {
    let url: URL
    var id: String { url.path }
}

private struct BangChiaSe: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ c: UIActivityViewController, context: Context) {}
}

// MARK: - Dựng cảnh SceneKit

enum DungCanh {
    /// Hình học của một loại khối. Dựng mới mỗi lần gọi — `SCNGeometry` dùng
    /// chung giữa nhiều nút thì đổi vật liệu của một khối sẽ đổi luôn màu của
    /// mọi khối cùng loại.
    /// Nửa chiều cao THẬT của một khối, theo trục Y, ở tỉ lệ hiện tại.
    ///
    /// ⚠️ KHÔNG phải cứ `coY / 2`. Hình gốc của mỗi loại có chiều cao khác
    /// nhau: hộp/cầu/trụ/nón/mặt phẳng cao đúng 1, nhưng **xuyến nằm trong
    /// mặt phẳng XZ** nên chiều cao của nó chỉ bằng `2 × pipeRadius` = 0,32.
    /// Dùng `coY / 2` cho xuyến thì nút "Đặt xuống sàn" treo nó lơ lửng
    /// **0,34 đơn vị** trên sàn — nhìn nghiêng không thấy, xoay camera mới lộ.
    ///
    /// Khối NHẬP thì `chuanHoaCo` thu cạnh DÀI NHẤT về 1, nên mô hình bẹt
    /// (xe, bàn) có chiều cao nhỏ hơn 1 nhiều. Chiều cao thật được đo lúc
    /// nhập và cất trong `caoGoc`; chưa có thì lùi về 1 như cũ.
    static func nuaCao(_ k: KhoiBa) -> Double {
        let goc: Double
        switch k.loai {
        case .xuyen: goc = 0.32
        case .nhap:  goc = k.caoGoc ?? 1
        default:     goc = 1
        }
        return goc * k.coY / 2
    }

    static func hinhCua(_ l: LoaiKhoi) -> SCNGeometry {
        switch l {
        case .hop: return SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.02)
        case .cau: return SCNSphere(radius: 0.5)
        case .tru: return SCNCylinder(radius: 0.5, height: 1)
        case .non: return SCNCone(topRadius: 0, bottomRadius: 0.5, height: 1)
        case .phang: return SCNPlane(width: 1, height: 1)
        case .xuyen: return SCNTorus(ringRadius: 0.5, pipeRadius: 0.16)
        // Không bao giờ tới đây: khối nhập dựng từ tệp ở `dungNut`. Trả hộp
        // để `switch` đủ nhánh mà không phải `fatalError` — sập app vì một
        // tệp lạ là cái giá quá đắt cho một nhánh không tưởng.
        case .nhap: return SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        }
    }

    static func dungNut(_ k: KhoiBa, dangChon: Bool, thuMucTep: URL? = nil) -> SCNNode {
        let nut: SCNNode
        if k.loai == .nhap, let ten = k.tepNhap, let d = thuMucTep,
           let scn = try? SCNScene(url: d.appendingPathComponent(ten)) {
            // Gói cả tệp nhập vào MỘT nút bọc: mô hình `.usdz` thường có cả
            // cây nút con, và đặt vị trí lên từng nút con là hỏng hình.
            nut = SCNNode()
            for con in scn.rootNode.childNodes { nut.addChildNode(con) }
            // Kết quả phép Boolean đã đúng cỡ đúng chỗ — chuẩn hoá là hỏng.
            if !k.giuCo { chuanHoaCo(nut) }
        } else if k.loai == .nhap {
            // Tệp mất hoặc đọc không được: hiện một khối xám rỗng thay vì
            // KHÔNG HIỆN GÌ. Biến mất im lặng thì người dùng tưởng đã xoá
            // nhầm và đi tìm nút hoàn tác.
            nut = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.05))
            let m = SCNMaterial()
            m.diffuse.contents = UIColor.systemGray
            m.transparency = 0.45
            nut.geometry?.materials = [m]
        } else {
            nut = SCNNode(geometry: hinhCua(k.loai))
        }
        nut.name = k.id.uuidString
        apVao(nut, k, dangChon: dangChon)
        return nut
    }

    /// Chiều cao (trục Y) của một tệp mô hình SAU khi đã chuẩn hoá cỡ.
    /// `nil` nếu đọc không được — khi đó người gọi lùi về giả định cũ.
    static func caoSauChuanHoa(_ tep: URL) -> Double? {
        guard let scn = try? SCNScene(url: tep) else { return nil }
        let bo = SCNNode()
        for con in scn.rootNode.childNodes { bo.addChildNode(con) }
        chuanHoaCo(bo)
        let (lo, hi) = bo.boundingBox
        let cao = Double(hi.y - lo.y)
        return cao > 0.0001 ? cao : nil
    }

    /// Thu mô hình nhập về cỡ ~1 đơn vị.
    ///
    /// Tệp `.usdz` ngoài đời có đủ đơn vị: cái thì 1 đơn vị = 1 mét, cái thì
    /// 1 = 1 xentimet. Không chuẩn hoá thì có mô hình vào cảnh bé như hạt
    /// bụi, có mô hình to trùm kín camera — và cả hai trông y như "nhập
    /// hỏng".
    private static func chuanHoaCo(_ nut: SCNNode) {
        let (min, max) = nut.boundingBox
        let canh = Swift.max(max.x - min.x, Swift.max(max.y - min.y, max.z - min.z))
        guard canh > 0.0001 else { return }
        let ti = 1.0 / canh
        for con in nut.childNodes {
            con.scale = SCNVector3(con.scale.x * ti, con.scale.y * ti, con.scale.z * ti)
            con.position = SCNVector3(con.position.x * ti, con.position.y * ti, con.position.z * ti)
        }
    }

    /// Cập nhật một nút CÓ SẴN theo dữ liệu mới.
    ///
    /// Đổi loại khối thì phải thay hình học; còn lại chỉ sửa thuộc tính, nên
    /// SceneKit vẽ tiếp khung hình kế mà không dựng lại gì — đó là toàn bộ
    /// khác biệt giữa mượt và giật.
    /// Khoá cất bản vật liệu GỐC của mô hình nhập, để tắt "tô đè" thì trả
    /// lại được. Không cất thì bật một lần là mất vĩnh viễn chất liệu của
    /// tệp, và công tắc chỉ đi được MỘT CHIỀU — thứ tệ hơn cả không có.
    private static let khoaVlGoc = "vlGocCuaTepNhap"

    /// Tô một màu lên mọi hình trong cây nút của mô hình nhập.
    private static func toDeMau(_ goc: SCNNode, _ k: KhoiBa) {
        let mau = UIColor(Color(maHex: k.mau))
        duyetHinh(goc) { h in
            if h.value(forKey: khoaVlGoc) == nil { h.setValue(h.materials, forKey: khoaVlGoc) }
            let vl = SCNMaterial()
            vl.lightingModel = .physicallyBased
            vl.diffuse.contents = mau
            vl.metalness.contents = k.kimLoai
            vl.roughness.contents = k.nham
            vl.isDoubleSided = true
            h.materials = h.materials.isEmpty ? [vl] : h.materials.map { _ in vl }
        }
    }

    /// Trả mô hình nhập về đúng vật liệu của tệp.
    private static func boToDe(_ goc: SCNNode) {
        duyetHinh(goc) { h in
            if let cu = h.value(forKey: khoaVlGoc) as? [SCNMaterial] {
                h.materials = cu
                h.setValue(nil, forKey: khoaVlGoc)
            }
        }
    }

    /// Đi hết cây nút, bỏ qua nút viền sáng (nó có vật liệu riêng của nó).
    private static func duyetHinh(_ goc: SCNNode, _ lam: (SCNGeometry) -> Void) {
        func di(_ n: SCNNode) {
            if n.name != "vien", let h = n.geometry { lam(h) }
            n.childNodes.forEach(di)
        }
        di(goc)
    }

    static func apVao(_ nut: SCNNode, _ k: KhoiBa, dangChon: Bool) {
        // Khối NHẬP giữ nguyên hình và vật liệu của tệp — ép màu lên nó là
        // xoá sạch chất liệu mà người ta nhập nó vào để dùng.
        let laNhap = (k.loai == .nhap)
        let canDoiHinh = !laNhap && !hopKieu(nut.geometry, k.loai)
        if canDoiHinh { nut.geometry = hinhCua(k.loai) }

        if !laNhap {
            let vl = nut.geometry?.firstMaterial ?? SCNMaterial()
            vl.lightingModel = .physicallyBased
            vl.diffuse.contents = UIColor(Color(maHex: k.mau))
            vl.metalness.contents = k.kimLoai
            vl.roughness.contents = k.nham
            vl.isDoubleSided = (k.loai == .phang)
            nut.geometry?.materials = [vl]
        } else if k.toDe {
            // Phải đi xuống TẬN CÙNG cây nút: `nut` ở đây chỉ là cái bọc,
            // nó KHÔNG có `geometry`, nên đặt vật liệu lên nó thì không có
            // gì đổi màu cả — đúng cái bẫy làm ô màu nhìn như nút chết.
            toDeMau(nut, k)
        } else {
            boToDe(nut)
        }

        nut.position = SCNVector3(k.x, k.y, k.z)
        nut.eulerAngles = SCNVector3(k.xoayX * .pi / 180, k.xoayY * .pi / 180, k.xoayZ * .pi / 180)
        nut.scale = SCNVector3(k.coX, k.coY, k.coZ)

        // Viền chọn: thêm/gỡ nút con chứ không dựng lại nút cha.
        //
        // Dựng lại khi cỡ đổi — viền là KHUNG DÂY bao quanh hộp bao, mà hộp
        // bao đổi theo `co*`. Dựng lại 24 đỉnh thì rẻ, không phải dựng lại cảnh.
        let vienCu = nut.childNode(withName: "vien", recursively: false)
        let coNay = SCNVector3(k.coX, k.coY, k.coZ)
        let coCu = (vienCu?.value(forKey: khoaCoVien) as? NSValue)?.scnVector3Value
        let coDoi = coCu == nil || coCu!.x != coNay.x || coCu!.y != coNay.y || coCu!.z != coNay.z
        if dangChon {
            if vienCu == nil || canDoiHinh || coDoi {
                vienCu?.removeFromParentNode()
                let vien = nutVien(nut, co: coNay)
                vien.setValue(NSValue(scnVector3: coNay), forKey: khoaCoVien)
                nut.addChildNode(vien)
            }
        } else {
            vienCu?.removeFromParentNode()
        }
    }

    private static let khoaCoVien = "coLucDungVien"

    /// Khung dây 12 cạnh bao quanh khối đang chọn.
    ///
    /// ⚠️ KHÔNG dùng lại kiểu cũ — "chép hình rồi phóng to 1,04 lần, lật mặt
    /// trong" (inverted hull). Kiểu đó CHẾT với hình mỏng:
    ///   · `.phang` là `SCNPlane`, dày ĐÚNG BẰNG 0 — nhân 1,04 vẫn là 0, nên
    ///     vỏ vàng nằm TRÙNG KHÍT lên mặt thật.
    ///   · khối bẹt (coZ nhỏ) thì 4% của một số bé vẫn là số bé.
    /// Hai mặt cùng độ sâu ⇒ GPU chọn ngẫu nhiên từng điểm ảnh ⇒ loang lổ
    /// vàng/tím, và đổi mỗi lần camera nhích. Người dùng báo 19/09/2026:
    /// *"phóng to thu nhỏ nó cứ nháy nháy chập chờn màu vàng với tím"*.
    ///
    /// Khung dây thì nằm NGOÀI bề mặt theo một khoảng cách cố định trong
    /// không gian thật, nên không có mặt nào trùng mặt nào — đúng với mọi
    /// hình, kể cả mặt phẳng và mô hình nhập.
    private static func nutVien(_ nut: SCNNode, co: SCNVector3) -> SCNNode {
        // Tính hộp bao SAU khi đã gỡ viền cũ, nếu không nó tự bao lấy chính
        // mình và mỗi lần chọn lại là phình ra một nấc.
        let (mi, ma) = nut.boundingBox

        // Cách bề mặt 0,03 đơn vị THẬT. Chia cho `co` vì nút cha đã phóng
        // sẵn — không chia thì khối to viền dày, khối nhỏ viền nuốt cả khối.
        func le(_ c: Float) -> Float { 0.03 / max(abs(c), 0.05) }
        let lx = le(co.x), ly = le(co.y), lz = le(co.z)
        let x0 = mi.x - lx, x1 = ma.x + lx
        let y0 = mi.y - ly, y1 = ma.y + ly
        let z0 = mi.z - lz, z1 = ma.z + lz

        let g: [(Float, Float, Float)] = [
            (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
            (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
        ]
        let canh = [(0, 1), (1, 2), (2, 3), (3, 0),
                    (4, 5), (5, 6), (6, 7), (7, 4),
                    (0, 4), (1, 5), (2, 6), (3, 7)]
        var dinh: [SCNVector3] = []
        for (a, b) in canh {
            dinh.append(SCNVector3(g[a].0, g[a].1, g[a].2))
            dinh.append(SCNVector3(g[b].0, g[b].1, g[b].2))
        }

        let nguon = SCNGeometrySource(vertices: dinh)
        let phan = SCNGeometryElement(indices: (0..<Int32(dinh.count)).map { $0 },
                                      primitiveType: .line)
        let hinh = SCNGeometry(sources: [nguon], elements: [phan])
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(Color(maHex: "#FAD129"))
        m.lightingModel = .constant
        m.isDoubleSided = true
        // Không ghi vào bộ đệm độ sâu: khung dây không che vật nào, và đây
        // là lớp chốt cuối chống mọi tranh chấp độ sâu còn sót.
        m.writesToDepthBuffer = false
        hinh.materials = [m]

        let n = SCNNode(geometry: hinh)
        n.name = "vien"
        n.renderingOrder = 10
        return n
    }

    /// Hộp bao quanh một nút nhập, để vẽ viền chọn.

    private static func hopKieu(_ g: SCNGeometry?, _ l: LoaiKhoi) -> Bool {
        switch l {
        case .hop: return g is SCNBox
        case .cau: return g is SCNSphere
        case .tru: return g is SCNCylinder
        case .non: return g is SCNCone
        case .phang: return g is SCNPlane
        case .xuyen: return g is SCNTorus
        case .nhap: return true
        }
    }

    /// Lưới sàn 20×20, ô 1 đơn vị, trục X/Z tô sáng hơn.
    ///
    /// Vẽ bằng `SCNGeometry` đường thẳng chứ không bằng ảnh nền kẻ ô: ảnh thì
    /// mờ đi khi camera lại gần, còn đường thì sắc ở mọi khoảng cách.
    // ════════════════════════════════════════════════════════════════
    // GIZMO — ba mũi tên kéo theo trục
    //
    // Thanh trượt cho số CHÍNH XÁC, nhưng dựng hình là việc của mắt: muốn
    // đẩy cái tay sang phải một chút thì phải dò đúng thanh "X", kéo, nhìn
    // lên, kéo tiếp. Kéo tự do trong không gian thì lại không giữ được
    // trục — thả tay ra là khối lệch cả ba chiều.
    //
    // Mũi tên bám vào khối đang chọn giải đúng khoảng giữa đó.
    // ════════════════════════════════════════════════════════════════

    static let TEN_GIZMO = "gizmo"

    /// Ba mũi tên X (đỏ) · Y (xanh lá) · Z (xanh dương), theo quy ước
    /// Blender/Maya để người từng dùng phần mềm khác không phải học lại.
    static func nutGizmo(dai: Float) -> SCNNode {
        let goc = SCNNode()
        goc.name = TEN_GIZMO

        let truc: [(String, UIColor, SCNVector3)] = [
            ("x", .systemRed,   SCNVector3(0, 0, -Float.pi / 2)),
            ("y", .systemGreen, SCNVector3(0, 0, 0)),
            ("z", .systemBlue,  SCNVector3(Float.pi / 2, 0, 0)),
        ]
        for (ten, mau, xoay) in truc {
            let than = SCNNode(geometry: SCNCylinder(radius: CGFloat(dai) * 0.022,
                                                     height: CGFloat(dai)))
            let dau = SCNNode(geometry: SCNCone(topRadius: 0,
                                                bottomRadius: CGFloat(dai) * 0.075,
                                                height: CGFloat(dai) * 0.22))
            dau.position = SCNVector3(0, dai / 2 + dai * 0.11, 0)

            for n in [than, dau] {
                let m = SCNMaterial()
                m.diffuse.contents = mau
                m.emission.contents = mau.withAlphaComponent(0.55)
                m.lightingModel = .constant
                // Luôn vẽ ĐÈ lên mô hình: mũi tên chui vào trong khối thì
                // không bấm được, mà khối to là chuyện bình thường.
                m.readsFromDepthBuffer = false
                n.geometry?.materials = [m]
                n.renderingOrder = 900
            }

            let cum = SCNNode()
            cum.name = "\(TEN_GIZMO)-\(ten)"
            cum.addChildNode(than)
            cum.addChildNode(dau)
            // Đẩy nửa thân ra để gốc mũi tên nằm ở tâm khối.
            cum.pivot = SCNMatrix4MakeTranslation(0, -dai / 2, 0)
            cum.eulerAngles = xoay
            goc.addChildNode(cum)
        }
        return goc
    }

    /// Gắn/bỏ gizmo theo khối đang chọn. Gọi mỗi lần cập nhật cảnh.
    static func capNhatGizmo(_ scn: SCNScene, chon: UUID?) {
        let cu = scn.rootNode.childNode(withName: TEN_GIZMO, recursively: false)
        guard let id = chon,
              let nut = scn.rootNode.childNode(withName: id.uuidString, recursively: false)
        else { cu?.removeFromParentNode(); return }

        // Dài theo cỡ khối nhưng có trần dưới/trên: khối bé tí thì mũi tên
        // nhỏ đến mức không chạm trúng, khối to thì mũi tên dài quá màn.
        let (lo, hi) = nut.boundingBox
        let co = nut.scale
        let canh = max(abs(hi.x - lo.x) * co.x, max(abs(hi.y - lo.y) * co.y, abs(hi.z - lo.z) * co.z))
        let dai = min(max(canh * 1.5, 0.7), 4.0)

        // Dựng lại khi cỡ khối đổi nhiều; còn lại chỉ dời vị trí. Co giãn
        // nút có sẵn thì đầu mũi tên béo/nhọn theo, trông như hỏng.
        let caCu = cu.flatMap { $0.value(forKey: "dai") as? Float }
        if let g = cu, let d = caCu, abs(d - dai) <= 0.01 {
            g.position = nut.worldPosition
            return
        }
        cu?.removeFromParentNode()
        let moi = nutGizmo(dai: dai)
        moi.position = nut.worldPosition
        moi.setValue(dai, forKey: "dai")
        scn.rootNode.addChildNode(moi)
    }

    static func nutLuoi(o: Int = 20) -> SCNNode {
        let goc = SCNNode()
        goc.name = "luoi"
        let nua = Float(o) / 2
        var dinh: [SCNVector3] = []
        var truc: [SCNVector3] = []
        for i in 0...o {
            let v = Float(i) - nua
            // Đường trùng trục cho vào nhóm riêng để tô sáng hơn — không có
            // hai đường đó thì nhìn lưới không biết gốc toạ độ ở đâu.
            let m: [SCNVector3] = [
                SCNVector3(v, 0, -nua), SCNVector3(v, 0, nua),
                SCNVector3(-nua, 0, v), SCNVector3(nua, 0, v),
            ]
            if v == 0 { truc += m } else { dinh += m }
        }
        goc.addChildNode(nutDuong(dinh, mau: UIColor.white.withAlphaComponent(0.12)))
        goc.addChildNode(nutDuong(truc, mau: UIColor.white.withAlphaComponent(0.38)))
        goc.position = SCNVector3(0, -0.499, 0)   // ngay trên mặt sàn, không z-fight
        return goc
    }

    private static func nutDuong(_ dinh: [SCNVector3], mau: UIColor) -> SCNNode {
        let nguon = SCNGeometrySource(vertices: dinh)
        let chiSo = (0..<Int32(dinh.count)).map { $0 }
        let phan = SCNGeometryElement(indices: chiSo, primitiveType: .line)
        let hinh = SCNGeometry(sources: [nguon], elements: [phan])
        let m = SCNMaterial()
        m.diffuse.contents = mau
        m.lightingModel = .constant
        m.isDoubleSided = true
        hinh.materials = [m]
        let n = SCNNode(geometry: hinh)
        // ⚠️ KHÔNG đặt `categoryBitMask = 0` ở đây. Nhìn thì tưởng là "nút này
        // không nhận chạm", nhưng `SCNCamera` CŨNG có `categoryBitMask`, và
        // camera chỉ vẽ nút nào giao bit với nó — mask 0 giao với mọi thứ đều
        // bằng 0, nên nút TÀNG HÌNH. Đo thật 19/09/2026: lưới sàn dựng đúng,
        // thêm vào cảnh đúng, `canh.luoi == true`, và không thấy gì trên màn.
        // Lưới vốn đã không nuốt cú chạm rồi: `nutTai()` chỉ nhận nút có tên
        // là một UUID, mà lưới thì không có.
        return n
    }

    static func dung(_ canh: CanhBa, chon: UUID?, thuMucTep: URL? = nil,
                     keLuoi: Bool = true) -> SCNScene {
        let scn = SCNScene()
        scn.background.contents = UIColor(Color(maHex: canh.mauNen))

        for k in canh.khoi {
            scn.rootNode.addChildNode(dungNut(k, dangChon: k.id == chon, thuMucTep: thuMucTep))
        }

        if canh.luoi && keLuoi { scn.rootNode.addChildNode(nutLuoi()) }
        if keLuoi { capNhatGizmo(scn, chon: chon) }   // bản xuất thì không kèm

        // Đèn: một đèn chính có bóng + một đèn môi trường. Chỉ có đèn chính
        // thì mặt khuất đen kịt và mô hình nhìn như hai mảnh rời.
        let chinh = SCNNode()
        chinh.light = SCNLight()
        chinh.light?.type = .directional
        chinh.light?.intensity = 900
        chinh.light?.castsShadow = true
        chinh.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
        scn.rootNode.addChildNode(chinh)

        let moi = SCNNode()
        moi.light = SCNLight()
        moi.light?.type = .ambient
        moi.light?.intensity = 420
        scn.rootNode.addChildNode(moi)

        scn.rootNode.addChildNode(camKhung(canh))
        return scn
    }

    /// Camera tự ĐÓNG KHUNG vào mô hình, không nhìn cứng vào gốc toạ độ.
    ///
    /// Nhìn cứng vào (0,0,0) là sai vì mô hình đứng TRÊN sàn: một người que
    /// cao 3 đơn vị nằm trọn ở nửa trên, nên mở ra thấy hình dồn lên đỉnh màn
    /// còn 2/3 phía dưới trống trơn. Đo thật 19/09/2026 trên iPad, và đó là
    /// một trong những thứ làm xưởng nhìn nghiệp dư ngay giây đầu tiên.
    static func camKhung(_ canh: CanhBa) -> SCNNode {
        let cam = SCNNode()
        cam.camera = SCNCamera()

        // Hộp bao của cả cảnh, tính từ tâm ± nửa cỡ mỗi khối.
        var nhoX = 0.0, lonX = 0.0, nhoY = 0.0, lonY = 0.0, nhoZ = 0.0, lonZ = 0.0
        var coGi = false
        for k in canh.khoi {
            let hx = max(k.coX, 0.01) / 2, hy = max(k.coY, 0.01) / 2, hz = max(k.coZ, 0.01) / 2
            if !coGi {
                nhoX = k.x - hx; lonX = k.x + hx
                nhoY = k.y - hy; lonY = k.y + hy
                nhoZ = k.z - hz; lonZ = k.z + hz
                coGi = true
            } else {
                nhoX = min(nhoX, k.x - hx); lonX = max(lonX, k.x + hx)
                nhoY = min(nhoY, k.y - hy); lonY = max(lonY, k.y + hy)
                nhoZ = min(nhoZ, k.z - hz); lonZ = max(lonZ, k.z + hz)
            }
        }
        // Cảnh trống thì lấy một khung mặc định quanh gốc, đủ thấy lưới sàn.
        if !coGi { nhoX = -1; lonX = 1; nhoY = 0; lonY = 2; nhoZ = -1; lonZ = 1 }

        let tamX = (nhoX + lonX) / 2, tamY = (nhoY + lonY) / 2, tamZ = (nhoZ + lonZ) / 2
        // Bán kính cầu bao — dùng đường chéo chứ không dùng cạnh dài nhất,
        // nếu không thì mô hình dài theo đường chéo vẫn bị cắt góc.
        let cheo = (pow(lonX - nhoX, 2) + pow(lonY - nhoY, 2) + pow(lonZ - nhoZ, 2)).squareRoot()
        let xa = max(cheo * 1.35, 3.6)

        // Góc nhìn 3/4 quen thuộc của mọi trình dựng khối: chếch phải, hơi cao.
        let ngang = 0.62, cao = 0.42
        cam.position = SCNVector3(
            Float(tamX + xa * ngang),
            Float(tamY + xa * cao),
            Float(tamZ + xa * 0.78))
        cam.look(at: SCNVector3(Float(tamX), Float(tamY), Float(tamZ)))
        return cam
    }
}

/// Khung 3D: chạm để chọn, KÉO ĐỂ DỜI khối, hai ngón để xoay camera.
///
/// ⚠️ Kéo khối và xoay camera dùng CHUNG một ngón, nên phải phân xử: cử chỉ
/// kéo của ta chỉ nhận khi ngón đặt TRÚNG khối đang chọn; mọi chỗ khác nhường
/// cho bộ điều khiển camera của SceneKit. Không phân xử thì hoặc là không
/// xoay được cảnh, hoặc là chạm đâu cũng lôi khối đi.
struct CanhSceneKit: UIViewRepresentable {
    let canh: CanhBa
    let chon: UUID?
    let khiChon: (UUID) -> Void
    /// Trả về vị trí mới (đã bắt điểm) của khối đang kéo.
    let khiKeo: (UUID, Double, Double, Double) -> Void
    let khiThaKeo: () -> Void
    let thuMucTep: URL?
    /// Đổi số là đưa camera về khung mặc định — xem `camKhung`.
    let lanDongKhung: Int
    /// Tăng số này để yêu cầu chụp một tấm ảnh của cảnh.
    var lanChupAnh: Int = 0
    var khiChupXong: ((UIImage) -> Void)?

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = false
        v.antialiasingMode = .multisampling2X
        v.scene = DungCanh.dung(canh, chon: chon, thuMucTep: thuMucTep)

        let cham = UITapGestureRecognizer(target: context.coordinator, action: #selector(Dieu.cham(_:)))
        v.addGestureRecognizer(cham)

        let keo = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Dieu.keo(_:)))
        keo.maximumNumberOfTouches = 1
        keo.delegate = context.coordinator
        v.addGestureRecognizer(keo)

        context.coordinator.gan(v: v, khiChon: khiChon, khiKeo: khiKeo, khiTha: khiThaKeo)
        return v
    }

    /// ⚠️ KHÔNG DỰNG LẠI CẢ CẢNH Ở ĐÂY. Bản đầu làm thế và tự trấn an là "vài
    /// chục khối thì rẻ" — sai, và người dùng thấy ngay: kéo một thanh trượt
    /// là SwiftUI gọi `updateUIView` vài chục lần mỗi giây, mỗi lần vứt cả
    /// `SCNScene` đi dựng lại từ đầu. Kết quả là màu nháy, hình giật, và
    /// camera nhảy vì `pointOfView` sau khi gán cảnh mới là một NÚT KHÁC.
    ///
    /// Giờ sửa TẠI CHỖ: khối nào còn thì cập nhật, khối mới thì thêm, khối
    /// mất thì gỡ. Cảnh, đèn và camera không bao giờ bị đụng tới.
    func updateUIView(_ v: SCNView, context: Context) {
        context.coordinator.gan(v: v, khiChon: khiChon, khiKeo: khiKeo, khiTha: khiThaKeo)
        context.coordinator.dangChon = chon
        context.coordinator.buocBat = canh.buocBat

        guard let scn = v.scene else {
            v.scene = DungCanh.dung(canh, chon: chon, thuMucTep: thuMucTep)
            return
        }

        // Đóng khung lại: bay camera về chỗ `camKhung` tính, KHÔNG dựng lại
        // cảnh. Phải đặt thẳng lên `v.pointOfView` chứ không phải nút camera
        // trong cảnh — `allowsCameraControl` sau lần xoay đầu tiên đã trỏ
        // `pointOfView` sang nút điều khiển của chính nó, nên sửa nút cũ thì
        // không có gì nhúc nhích.
        if context.coordinator.lanChupAnh != lanChupAnh {
            context.coordinator.lanChupAnh = lanChupAnh
            if lanChupAnh > 0 { khiChupXong?(context.coordinator.chupAnh(v)) }
        }
        if context.coordinator.lanDongKhung != lanDongKhung {
            context.coordinator.lanDongKhung = lanDongKhung
            if let mat = v.pointOfView {
                let dich = DungCanh.camKhung(canh)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.35
                mat.position = dich.position
                mat.orientation = dich.orientation
                SCNTransaction.commit()
            }
        }

        // Lưới bật/tắt: thêm hoặc gỡ, không dựng lại cảnh.
        let luoiCu = scn.rootNode.childNode(withName: "luoi", recursively: false)
        if canh.luoi && luoiCu == nil { scn.rootNode.addChildNode(DungCanh.nutLuoi()) }
        if !canh.luoi { luoiCu?.removeFromParentNode() }

        let conLai = Set(canh.khoi.map(\.id.uuidString))
        // Gỡ khối đã xoá. Chỉ đụng nút CÓ TÊN là UUID — đèn và camera không
        // có tên nên chúng an toàn.
        for nut in scn.rootNode.childNodes {
            guard let t = nut.name, UUID(uuidString: t) != nil else { continue }
            if !conLai.contains(t) { nut.removeFromParentNode() }
        }

        for k in canh.khoi {
            let ten = k.id.uuidString
            if let nut = scn.rootNode.childNode(withName: ten, recursively: false) {
                DungCanh.apVao(nut, k, dangChon: k.id == chon)
            } else {
                scn.rootNode.addChildNode(DungCanh.dungNut(k, dangChon: k.id == chon, thuMucTep: thuMucTep))
            }
        }
        DungCanh.capNhatGizmo(scn, chon: chon)
    }

    func makeCoordinator() -> Dieu { Dieu() }

    final class Dieu: NSObject, UIGestureRecognizerDelegate {
        var khiChon: ((UUID) -> Void)?
        var khiKeo: ((UUID, Double, Double, Double) -> Void)?
        var khiTha: (() -> Void)?
        var dangChon: UUID?
        var lanDongKhung = 0
        var lanChupAnh = 0
        var buocBat: Double = 0

        /// Ảnh SẠCH của cảnh: giấu lưới sàn và viền chọn rồi mới chụp.
        ///
        /// Lưới và viền là đồ nghề của xưởng. Để nguyên thì tấm ảnh đem
        /// khoe có vạch kẻ chạy khắp nền và một khối bị bọc viền sáng —
        /// người xem tưởng đó là một phần của mô hình.
        func chupAnh(_ v: SCNView) -> UIImage {
            let luoi = v.scene?.rootNode.childNode(withName: "luoi", recursively: false)
            let anLuoi = luoi?.isHidden ?? false
            luoi?.isHidden = true

            var daAn: [SCNNode] = []
            v.scene?.rootNode.enumerateChildNodes { n, _ in
                if n.name == "vien", !n.isHidden { n.isHidden = true; daAn.append(n) }
            }

            let anh = v.snapshot()

            luoi?.isHidden = anLuoi
            for n in daAn { n.isHidden = false }
            return anh
        }

        private weak var view: SCNView?
        /// Độ sâu màn hình của khối lúc bắt đầu kéo. Giữ nguyên nó trong suốt
        /// cú kéo: tính lại mỗi khung hình thì khối trượt xa dần về phía chân
        /// trời, vì chiếu ngược một điểm màn hình cần biết độ sâu mà chính nó
        /// không mang theo.
        private var sauManHinh: Float = 0
        private var lechTheGioi = SCNVector3Zero
        /// Trục đang bị khoá trong cú kéo hiện tại ("x"/"y"/"z"), `nil` = tự do.
        private var trucKhoa: String?
        private var viTriDau = SCNVector3Zero

        func gan(v: SCNView,
                 khiChon: @escaping (UUID) -> Void,
                 khiKeo: @escaping (UUID, Double, Double, Double) -> Void,
                 khiTha: @escaping () -> Void) {
            self.view = v
            self.khiChon = khiChon
            self.khiKeo = khiKeo
            self.khiTha = khiTha
        }

        // MARK: Chạm để chọn

        @objc func cham(_ g: UITapGestureRecognizer) {
            guard let v = g.view as? SCNView else { return }
            guard let id = nutTai(g.location(in: v), v) else { return }
            khiChon?(id)
        }

        /// Khối nằm dưới một điểm màn hình. Bỏ qua lưới và đi ngược lên nút
        /// cha khi chạm trúng viền sáng hoặc một nút con của mô hình nhập.
        private func nutTai(_ diem: CGPoint, _ v: SCNView) -> UUID? {
            let ket = v.hitTest(diem, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: true,
            ])
            for h in ket {
                var n: SCNNode? = h.node
                while let cur = n {
                    // Chạm trúng mũi tên gizmo thì KHÔNG phải chọn khối —
                    // nếu không, mỗi lần định kéo trục lại thành chọn lại
                    // đúng khối đó, vô hại nhưng gizmo nhấp nháy.
                    if cur.name?.hasPrefix(DungCanh.TEN_GIZMO) == true { break }
                    if let t = cur.name, let id = UUID(uuidString: t) { return id }
                    n = cur.parent
                }
            }
            return nil
        }

        /// Trục gizmo nằm dưới một điểm màn hình: "x" | "y" | "z" | nil.
        private func trucTai(_ diem: CGPoint, _ v: SCNView) -> String? {
            let ket = v.hitTest(diem, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: true,
            ])
            for h in ket {
                var n: SCNNode? = h.node
                while let cur = n {
                    if let t = cur.name, t.hasPrefix(DungCanh.TEN_GIZMO + "-") {
                        return String(t.suffix(1))
                    }
                    n = cur.parent
                }
            }
            return nil
        }

        // MARK: Kéo để dời

        /// Chỉ cho cử chỉ kéo BẮT ĐẦU khi ngón đặt trúng khối ĐANG CHỌN.
        ///
        /// Đây là chỗ phân xử với bộ điều khiển camera: ngoài khối đó ra, mọi
        /// cú kéo đều là xoay cảnh. Không có chốt này thì kéo nền cũng lôi
        /// khối đi, và người dùng mất phương hướng ngay lần thử đầu.
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard g is UIPanGestureRecognizer, let v = view, let sel = dangChon else { return false }
            return nutTai(g.location(in: v), v) == sel
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { false }

        @objc func keo(_ g: UIPanGestureRecognizer) {
            guard let v = view, let id = dangChon,
                  let nut = v.scene?.rootNode.childNode(withName: id.uuidString, recursively: false)
            else { return }
            let diem = g.location(in: v)

            switch g.state {
            case .began:
                // Bắt đầu TRÊN một mũi tên ⇒ khoá vào trục đó cho tới khi
                // thả. Quyết một lần lúc chạm, không dò lại mỗi khung hình:
                // giữa chừng đầu ngón rời khỏi mũi tên là chuyện thường, mà
                // dò lại thì khối nhảy sang chế độ tự do ngay giữa cú kéo.
                trucKhoa = trucTai(diem, v)
                let tren = v.projectPoint(nut.worldPosition)
                sauManHinh = tren.z
                viTriDau = nut.worldPosition
                let theGioi = v.unprojectPoint(SCNVector3(Float(diem.x), Float(diem.y), sauManHinh))
                lechTheGioi = SCNVector3(nut.worldPosition.x - theGioi.x,
                                         nut.worldPosition.y - theGioi.y,
                                         nut.worldPosition.z - theGioi.z)
            case .changed:
                let theGioi = v.unprojectPoint(SCNVector3(Float(diem.x), Float(diem.y), sauManHinh))
                var moi = SCNVector3(theGioi.x + lechTheGioi.x,
                                     theGioi.y + lechTheGioi.y,
                                     theGioi.z + lechTheGioi.z)
                // Khoá hai trục còn lại về đúng vị trí lúc bắt đầu.
                switch trucKhoa {
                case "x": moi.y = viTriDau.y; moi.z = viTriDau.z
                case "y": moi.x = viTriDau.x; moi.z = viTriDau.z
                case "z": moi.x = viTriDau.x; moi.y = viTriDau.y
                default: break
                }
                khiKeo?(id, bat(Double(moi.x)), bat(Double(moi.y)), bat(Double(moi.z)))
            case .ended, .cancelled, .failed:
                trucKhoa = nil
                khiTha?()
            default: break
            }
        }

        /// Làm tròn về bội của `buocBat`. `0` thì để nguyên.
        private func bat(_ v: Double) -> Double {
            guard buocBat > 0 else { return v }
            return (v / buocBat).rounded() * buocBat
        }
    }
}
#else
struct KhungBaView: View {
    let canh: CanhBa
    var body: some View { Text(T("Xưởng 3D chỉ chạy trên iPhone/iPad")) }
}
#endif

#if os(iOS)
import QuickLook

/// AR Quick Look — đặt mô hình ra bàn thật qua camera.
///
/// Dùng `QLPreviewController` của hệ thống chứ không tự dựng phiên ARKit:
/// nó cho sẵn nút "AR", bắt mặt phẳng, đổ bóng tiếp xúc và chia sẻ — tự
/// làm lại là hàng trăm dòng để ra thứ kém hơn.
struct XemAR: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController()
        c.dataSource = context.coordinator
        return c
    }
    func updateUIViewController(_ c: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Nguon { Nguon(url: url) }

    final class Nguon: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in c: QLPreviewController) -> Int { 1 }
        func previewController(_ c: QLPreviewController,
                               previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}
#endif

#if os(iOS)
// ════════════════════════════════════════════════════════════════
// PHÉP BOOLEAN + NHÂN DÃY — hai thứ của Blender đáng bê sang nhất
// ════════════════════════════════════════════════════════════════

extension KhungBaView {

    /// Gộp / khoét / giao khối đang chọn với một khối khác.
    ///
    /// Kết quả là một lưới tự do, không còn là hộp hay cầu nữa, nên lưu
    /// thành tệp `.scn` rồi dựng lại bằng đúng đường của khối NHẬP — dùng
    /// lại toàn bộ máy móc sẵn có (vẽ, xuất, AR) thay vì thêm một loại khối
    /// thứ tám với một nhánh riêng ở khắp nơi.
    func lamBoolean(_ phep: PhepBa, voi idB: UUID) {
        guard let ka = khoiDangChon,
              let kb = canh.khoi.first(where: { $0.id == idB })
        else { return }

        // `.phang` dày bằng 0 nên không phải khối KÍN. Cắt nó bằng BSP ra
        // hình rác chứ không báo lỗi — chặn ở đây, nói rõ lý do.
        guard ka.loai != .phang, kb.loai != .phang else {
            khoe(T("Mặt phẳng không dùng được cho phép Boolean (nó không kín)"))
            return
        }

        let thuMuc = KhoCanhBa.thuMucTep(canh.id)
        let na = DungCanh.dungNut(ka, dangChon: false, thuMucTep: thuMuc)
        let nb = DungCanh.dungNut(kb, dangChon: false, thuMucTep: thuMuc)
        // Nhãn 0 = khối A, nhãn 1 = khối B — đi theo tới tận hình cuối.
        let da = Boolean3D.daGiac(na, vl: 0), db = Boolean3D.daGiac(nb, vl: 1)
        guard !da.isEmpty, !db.isEmpty else {
            khoe(T("Không đọc được lưới của một trong hai khối"))
            return
        }

        func vatLieu(_ k: KhoiBa) -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(Color(maHex: k.mau))
            m.metalness.contents = k.kimLoai
            m.roughness.contents = k.nham
            return m
        }
        let kq = Boolean3D.lam(phep, da, db)
        guard let (hinh, tam) = Boolean3D.dungHinhNhieuMau(
                kq, mau: [0: vatLieu(ka), 1: vatLieu(kb)]) else {
            khoe(phep == .giao ? T("Hai khối không chạm nhau nên không có phần giao")
                               : T("Phép này ra hình rỗng"))
            return
        }

        // Ghi ra tệp để lần mở sau vẫn còn — cảnh chỉ lưu dữ liệu, không
        // lưu lưới, nên không ghi tệp thì mở lại là mất hình.
        let ten = "\(UUID().uuidString).scn"
        let scn = SCNScene()
        // Vật liệu đã gán trong `dungHinhNhieuMau` — không đè lại, đè là
        // mất đúng cái vừa giữ được.
        scn.rootNode.addChildNode(SCNNode(geometry: hinh))
        guard scn.write(to: thuMuc.appendingPathComponent(ten),
                        options: nil, delegate: nil, progressHandler: nil) else {
            khoe(T("Không lưu được kết quả"))
            return
        }

        ghiNho()
        var moi = KhoiBa(loai: .nhap, ten: "\(ka.tenHien) \(phep == .gop ? "+" : phep == .khoet ? "−" : "∩") \(kb.tenHien)")
        moi.tepNhap = ten
        moi.giuCo = true
        moi.mau = ka.mau
        moi.kimLoai = ka.kimLoai
        moi.nham = ka.nham
        moi.x = tam.x; moi.y = tam.y; moi.z = tam.z

        // Hai khối nguồn biến mất — đó là cách Blender làm và cũng là điều
        // người dùng muốn: giữ lại thì chúng nằm chồng lên kết quả, che mất
        // đúng cái vừa tạo ra và trông như phép Boolean không chạy.
        canh.khoi.removeAll { $0.id == ka.id || $0.id == kb.id }
        canh.khoi.append(moi)
        dangChon = moi.id
        kho.luu(canh)
        khoe(T("Đã tạo hình mới"))
    }

    /// Nhân khối đang chọn thành một dãy cách đều.
    func nhanDay(so: Int, dx: Double, dy: Double, dz: Double) {
        guard let goc = khoiDangChon, so > 1 else { return }
        ghiNho()
        let cum = goc.nhom.map { n in canh.khoi.filter { $0.nhom == n } } ?? [goc]
        for i in 1..<so {
            let nhomMoi: String? = goc.nhom == nil ? nil : MauDungSan.maNhom("day")
            for k in cum {
                var m = k
                m.id = UUID()
                m.nhom = nhomMoi
                m.x = k.x + dx * Double(i)
                m.y = k.y + dy * Double(i)
                m.z = k.z + dz * Double(i)
                m.ten = k.ten.isEmpty ? "" : "\(k.ten) \(i + 1)"
                canh.khoi.append(m)
            }
        }
        kho.luu(canh)
        khoe(String(format: T("Đã nhân thành %d bản"), so))
    }
}
#endif

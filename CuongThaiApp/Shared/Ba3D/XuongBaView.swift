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
                     lanDongKhung: lanDongKhung)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(maHex: canh.mauNen))
    }

    /// Khối đã KHOÁ thì bỏ qua — sàn nằm dưới mọi thứ nên nó là thứ hay bị
    /// chạm trúng nhất khi người dùng nhắm vào khối bên trên.
    private func chonKhoi(_ id: UUID) {
        if canh.khoi.first(where: { $0.id == id })?.khoa == true { return }
        dangChon = id
    }

    private func luuNgay() { kho.luu(canh) }

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
                menuThem
                Button { xuatUsdz() } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel(T("Xuất .usdz"))
            }
        }
        .sheet(isPresented: $moThem) { manThem }
        .sheet(isPresented: $moMau) { manMau }
        .fileImporter(isPresented: $moNhapTep,
                      allowedContentTypes: [.usdz, .threeDContent, .item],
                      allowsMultipleSelection: false) { kq in nhapTep(kq) }
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
                            Button { sua { $0.mau = m } } label: {
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
                        set: { v in sua { $0.toDe = v } })) {
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
                       AppColors.textSecondary) { sua { $0.khoa.toggle() }; kho.luu(canh) }
                nutNho(T("Xoá"), "trash", AppColors.error) { xoaKhoi() }
            }
            .padding(.horizontal, 2)
        }
        .padding(.top, 2)
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
        sua { $0.y = -0.5 + $0.coY / 2 }
        kho.luu(canh)
    }

    private func doiNhom() {
        guard let k = khoiDangChon else { return }
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
            ), in: khoang) { dung in if !dung { kho.luu(canh) } }
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
        var k = KhoiBa(loai: .nhap, ten: u.deletingPathExtension().lastPathComponent)
        k.tepNhap = ten
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
    private func xuatUsdz() {
        let scn = DungCanh.dung(canh, chon: nil)
        let d = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(canh.ten.replacingOccurrences(of: "/", with: "-")).usdz")
        if scn.write(to: d, options: nil, delegate: nil, progressHandler: nil) {
            chiaSe = d
        } else {
            khoe(T("Không xuất được tệp .usdz"))
        }
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
            chuanHoaCo(nut)
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

    static func dung(_ canh: CanhBa, chon: UUID?, thuMucTep: URL? = nil) -> SCNScene {
        let scn = SCNScene()
        scn.background.contents = UIColor(Color(maHex: canh.mauNen))

        for k in canh.khoi {
            scn.rootNode.addChildNode(dungNut(k, dangChon: k.id == chon, thuMucTep: thuMucTep))
        }

        if canh.luoi { scn.rootNode.addChildNode(nutLuoi()) }

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
    }

    func makeCoordinator() -> Dieu { Dieu() }

    final class Dieu: NSObject, UIGestureRecognizerDelegate {
        var khiChon: ((UUID) -> Void)?
        var khiKeo: ((UUID, Double, Double, Double) -> Void)?
        var khiTha: (() -> Void)?
        var dangChon: UUID?
        var lanDongKhung = 0
        var buocBat: Double = 0

        private weak var view: SCNView?
        /// Độ sâu màn hình của khối lúc bắt đầu kéo. Giữ nguyên nó trong suốt
        /// cú kéo: tính lại mỗi khung hình thì khối trượt xa dần về phía chân
        /// trời, vì chiếu ngược một điểm màn hình cần biết độ sâu mà chính nó
        /// không mang theo.
        private var sauManHinh: Float = 0
        private var lechTheGioi = SCNVector3Zero

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
                    if let t = cur.name, let id = UUID(uuidString: t) { return id }
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
                let tren = v.projectPoint(nut.worldPosition)
                sauManHinh = tren.z
                let theGioi = v.unprojectPoint(SCNVector3(Float(diem.x), Float(diem.y), sauManHinh))
                lechTheGioi = SCNVector3(nut.worldPosition.x - theGioi.x,
                                         nut.worldPosition.y - theGioi.y,
                                         nut.worldPosition.z - theGioi.z)
            case .changed:
                let theGioi = v.unprojectPoint(SCNVector3(Float(diem.x), Float(diem.y), sauManHinh))
                let moi = SCNVector3(theGioi.x + lechTheGioi.x,
                                     theGioi.y + lechTheGioi.y,
                                     theGioi.z + lechTheGioi.z)
                khiKeo?(id, bat(Double(moi.x)), bat(Double(moi.y)), bat(Double(moi.z)))
            case .ended, .cancelled, .failed:
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

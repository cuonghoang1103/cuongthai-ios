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
    @State private var moThem = false
    @State private var bao: String?
    @State private var chiaSe: URL?

    private var khoiDangChon: KhoiBa? { canh.khoi.first { $0.id == dangChon } }

    var body: some View {
        VStack(spacing: 0) {
            CanhSceneKit(canh: canh, chon: dangChon) { id in dangChon = id }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(maHex: canh.mauNen))

            danhSachKhoi
            if khoiDangChon != nil { bangChinh }
        }
        .navigationTitle(canh.ten)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { moThem = true } label: { Image(systemName: "plus") }
                Button { xuatUsdz() } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel(T("Xuất .usdz"))
            }
        }
        .sheet(isPresented: $moThem) { manThem }
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

    // MARK: Danh sách khối

    private var danhSachKhoi: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(canh.khoi) { k in
                    Button { dangChon = k.id } label: {
                        HStack(spacing: 5) {
                            Image(systemName: k.loai.bieuTuong).font(.caption)
                            Text(k.tenHien).font(.caption)
                        }
                        .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 7)
                        .background(dangChon == k.id ? AppColors.primary : AppColors.backgroundTertiary)
                        .foregroundStyle(dangChon == k.id ? Color.white : AppColors.textPrimary)
                        .cornerRadius(CornerRadius.full)
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
                thanhTruot(T("Kim loại"), \.kimLoai, 0...1)
                thanhTruot(T("Nhám"), \.nham, 0...1)

                HStack {
                    Button {
                        guard let id = dangChon else { return }
                        canh.khoi.removeAll { $0.id == id }
                        dangChon = nil
                        kho.luu(canh)
                    } label: { Label(T("Xoá khối"), systemImage: "trash").font(.buttonSmall) }
                    .buttonStyle(.plain).foregroundStyle(AppColors.error)

                    Spacer()

                    Button {
                        guard var k = khoiDangChon else { return }
                        k.id = UUID()
                        k.x += 0.6
                        k.ten = ""
                        canh.khoi.append(k)
                        dangChon = k.id
                        kho.luu(canh)
                    } label: { Label(T("Nhân đôi"), systemImage: "plus.square.on.square").font(.buttonSmall) }
                    .buttonStyle(.plain).foregroundStyle(AppColors.primary)
                }
                .padding(.top, 2)
            }
            .padding(Spacing.md)
        }
        .frame(height: 300)
        .background(AppColors.backgroundCard)
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
    static func dung(_ canh: CanhBa, chon: UUID?) -> SCNScene {
        let scn = SCNScene()
        scn.background.contents = UIColor(Color(maHex: canh.mauNen))

        for k in canh.khoi {
            let hinh: SCNGeometry
            switch k.loai {
            case .hop: hinh = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.02)
            case .cau: hinh = SCNSphere(radius: 0.5)
            case .tru: hinh = SCNCylinder(radius: 0.5, height: 1)
            case .non: hinh = SCNCone(topRadius: 0, bottomRadius: 0.5, height: 1)
            case .phang: hinh = SCNPlane(width: 1, height: 1)
            case .xuyen: hinh = SCNTorus(ringRadius: 0.5, pipeRadius: 0.16)
            }

            let vl = SCNMaterial()
            vl.lightingModel = .physicallyBased
            vl.diffuse.contents = UIColor(Color(maHex: k.mau))
            vl.metalness.contents = k.kimLoai
            vl.roughness.contents = k.nham
            // Mặt phẳng phải thấy được từ CẢ HAI phía: quay camera xuống dưới
            // sàn mà sàn biến mất thì người dùng tưởng mình xoá nhầm.
            vl.isDoubleSided = (k.loai == .phang)
            hinh.materials = [vl]

            let nut = SCNNode(geometry: hinh)
            nut.name = k.id.uuidString
            nut.position = SCNVector3(k.x, k.y, k.z)
            nut.eulerAngles = SCNVector3(k.xoayX * .pi / 180, k.xoayY * .pi / 180, k.xoayZ * .pi / 180)
            nut.scale = SCNVector3(k.coX, k.coY, k.coZ)

            if k.id == chon {
                // Viền sáng quanh khối đang chọn. Dùng `SCNNode` bọc ngoài
                // phóng to 1,04 lần và vẽ mặt trong — rẻ hơn hẳn bộ lọc
                // outline và chạy được trên mọi máy.
                let vien = SCNNode(geometry: hinh.copy() as? SCNGeometry)
                let mv = SCNMaterial()
                mv.diffuse.contents = UIColor(Color(maHex: "#FAD129"))
                mv.isDoubleSided = true
                mv.cullMode = .front
                vien.geometry?.materials = [mv]
                vien.scale = SCNVector3(1.04, 1.04, 1.04)
                nut.addChildNode(vien)
            }
            scn.rootNode.addChildNode(nut)
        }

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

        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.position = SCNVector3(3.2, 2.6, 4.2)
        cam.look(at: SCNVector3(0, 0, 0))
        scn.rootNode.addChildNode(cam)

        return scn
    }
}

struct CanhSceneKit: UIViewRepresentable {
    let canh: CanhBa
    let chon: UUID?
    let khiChon: (UUID) -> Void

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = false
        v.antialiasingMode = .multisampling2X
        v.scene = DungCanh.dung(canh, chon: chon)
        let cham = UITapGestureRecognizer(target: context.coordinator, action: #selector(Dieu.cham(_:)))
        v.addGestureRecognizer(cham)
        context.coordinator.khiChon = khiChon
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        // Dựng lại cả cảnh mỗi lần đổi. Với vài chục khối thì rẻ, và nó bỏ
        // hẳn được một lớp mã đồng bộ từng nút — mà mã đồng bộ đó chính là
        // chỗ sinh ra những khối "sửa rồi mà không thấy đổi".
        let goc = v.pointOfView?.transform
        v.scene = DungCanh.dung(canh, chon: chon)
        // Giữ nguyên góc nhìn: dựng lại cảnh mà camera nhảy về vị trí đầu thì
        // mỗi lần kéo một thanh trượt là mất chỗ đang nhìn.
        if let g = goc { v.pointOfView?.transform = g }
        context.coordinator.khiChon = khiChon
    }

    func makeCoordinator() -> Dieu { Dieu() }

    final class Dieu: NSObject {
        var khiChon: ((UUID) -> Void)?

        @objc func cham(_ g: UITapGestureRecognizer) {
            guard let v = g.view as? SCNView else { return }
            let diem = g.location(in: v)
            guard let hit = v.hitTest(diem, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue]).first
            else { return }
            // Chạm trúng viền sáng (nút con) thì lấy nút CHA — nếu không thì
            // chạm vào khối đang chọn lại không chọn được gì.
            let ten = hit.node.name ?? hit.node.parent?.name
            if let t = ten, let id = UUID(uuidString: t) { khiChon?(id) }
        }
    }
}
#else
struct KhungBaView: View {
    let canh: CanhBa
    var body: some View { Text(T("Xưởng 3D chỉ chạy trên iPhone/iPad")) }
}
#endif

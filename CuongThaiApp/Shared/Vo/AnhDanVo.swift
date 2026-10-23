#if os(iOS)
import Foundation
import PencilKit
import SwiftData
import UIKit

// MARK: - Ảnh DÁN trong trang Vở (24/10/2026 — "Chụp đoạn bài vào Vở")
//
// Trước đợt này trang Vở chỉ nhận ảnh làm NỀN cả trang (`nenAnhTen`: trang sách quét). Đoạn bài chụp từ màn học
// là một mẩu nhỏ nằm GIỮA trang ghi chép, bên cạnh chữ viết tay — không phải nền.
//
// ⚠️ KHÔNG đụng `@Model`: thêm trường vào model đã lưu là con đường từng xoá sạch dữ liệu (bộ nhớ
// `feedback_them_truong_vao_model_da_luu_xoa_sach_du_lieu`). Ảnh dán là TỆP RIÊNG cạnh tệp nét, đúng tinh thần
// `KhoVo` ("tệp là nguồn sự thật"):
//
//   Documents/Vo/anhdan/<id trang>.json   — danh sách ảnh của trang (vị trí theo TOẠ ĐỘ TRANG, pt)
//   Documents/Vo/anhdan/<uuid>.png        — từng ảnh
//
// Lớp vẽ: giấy → nền tài liệu → ẢNH DÁN → mực (`BangVeVC`). Ảnh nhỏ dải trang + PDF xuất ra cũng vẽ ảnh dán
// (ảnh nhỏ là thứ web đọc được). Đồng bộ: CHƯA lên máy chủ (máy chủ chưa có cột cho nó) — chỉ ảnh nhỏ của trang
// (thứ web hiện) mang theo ảnh dán.

/// Một ảnh dán trên trang. Toạ độ TRANG (pt, gốc trên-trái) — cùng hệ với nét `PKDrawing`.
struct AnhDanTrang: Codable, Identifiable, Equatable {
    var id: UUID
    /// Tên tệp ảnh trong `Documents/Vo/anhdan/`.
    var ten: String
    var x: Double
    var y: Double
    var rong: Double
    var cao: Double
    /// Chú thích nguồn ("Dekiru · Bài 3") — để biết ảnh chụp từ bài nào.
    var nguon: String?
    var luc: Date

    var khung: CGRect { CGRect(x: x, y: y, width: rong, height: cao) }

    init(id: UUID = UUID(), ten: String, khung: CGRect, nguon: String?, luc: Date = Date()) {
        self.id = id
        self.ten = ten
        x = Double(khung.minX); y = Double(khung.minY)
        rong = Double(khung.width); cao = Double(khung.height)
        self.nguon = nguon
        self.luc = luc
    }

    // ⚠️ Viết tay: mọi khoá `decodeIfPresent` — thêm trường sau này không làm hỏng tệp cũ.
    private enum K: String, CodingKey { case id, ten, x, y, rong, cao, nguon, luc }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        ten = (try? c.decodeIfPresent(String.self, forKey: .ten)) ?? ""
        x = (try? c.decodeIfPresent(Double.self, forKey: .x)) ?? 0
        y = (try? c.decodeIfPresent(Double.self, forKey: .y)) ?? 0
        rong = (try? c.decodeIfPresent(Double.self, forKey: .rong)) ?? 0
        cao = (try? c.decodeIfPresent(Double.self, forKey: .cao)) ?? 0
        nguon = try? c.decodeIfPresent(String.self, forKey: .nguon)
        luc = (try? c.decodeIfPresent(Date.self, forKey: .luc)) ?? Date()
    }
}

enum KhoAnhDan {
    /// Phát khi danh sách ảnh dán của một trang đổi (`object` = `UUID` của trang).
    static let daDoi = Notification.Name("KhoAnhDan.daDoi")

    static var thuMuc: URL {
        let u = KhoVo.thuMucGoc.appendingPathComponent("anhdan", isDirectory: true)
        if !FileManager.default.fileExists(atPath: u.path) {
            try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        }
        return u
    }
    static func duongDanDs(_ idTrang: UUID) -> URL { thuMuc.appendingPathComponent("\(idTrang.uuidString).json") }
    static func duongDanAnh(_ ten: String) -> URL { thuMuc.appendingPathComponent(ten) }

    // MARK: Đọc / ghi danh sách

    static func ds(_ idTrang: UUID) -> [AnhDanTrang] {
        let u = duongDanDs(idTrang)
        guard let d = try? Data(contentsOf: u), !d.isEmpty else { return [] }
        do {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .secondsSince1970
            return try dec.decode([AnhDanTrang].self, from: d).filter { !$0.ten.isEmpty && $0.rong > 0 && $0.cao > 0 }
        } catch {
            // Không nuốt im lặng: tệp hỏng thì GIỮ LẠI để cứu, báo một dòng.
            NhatKy.vo.error("ảnh dán: đọc \(u.lastPathComponent) hỏng — \(error.localizedDescription)")
            try? FileManager.default.moveItem(at: u, to: u.appendingPathExtension("hong"))
            return []
        }
    }

    static func coAnh(_ idTrang: UUID) -> Bool {
        FileManager.default.fileExists(atPath: duongDanDs(idTrang).path)
    }

    @discardableResult
    static func luu(_ ds: [AnhDanTrang], cho idTrang: UUID) -> Bool {
        let u = duongDanDs(idTrang)
        if ds.isEmpty {
            try? FileManager.default.removeItem(at: u)
        } else {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .secondsSince1970
            guard let d = try? enc.encode(ds) else { return false }
            do { try d.write(to: u, options: .atomic) } catch {
                NhatKy.vo.error("ảnh dán: ghi hỏng — \(error.localizedDescription)")
                return false
            }
        }
        NotificationCenter.default.post(name: daDoi, object: idTrang)
        return true
    }

    // MARK: Ảnh

    private static let boNho: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 40
        return c
    }()

    static func anh(_ ten: String) -> UIImage? {
        if let a = boNho.object(forKey: ten as NSString) { return a }
        guard let a = UIImage(contentsOfFile: duongDanAnh(ten).path) else { return nil }
        boNho.setObject(a, forKey: ten as NSString)
        return a
    }

    // MARK: Đặt chỗ (thuần — có kiểm thử)

    /// Vùng ghi được của trang theo loại giấy: Cornell ⇒ cột "Ghi chép" (bên phải lề 30%, trên dải tóm tắt).
    static func vungGhi(giay: LoaiGiay, khoTrang: CGSize, khoGoc: CGSize) -> CGRect {
        let w = khoTrang.width, h = khoTrang.height
        switch giay {
        case .cornell:
            let trai = w * 0.30 + GiayNenView.mm(3)
            let phai = w - GiayNenView.mm(12)
            let day = GiayNenView.yTomTatCornell(h: h, hGoc: min(khoGoc.height, h))
            return CGRect(x: trai, y: GiayNenView.caoDong * 1.5, width: max(40, phai - trai),
                          height: max(40, day - GiayNenView.caoDong * 1.5 - 6))
        default:
            let le: CGFloat = 36
            return CGRect(x: le, y: le, width: max(40, w - 2 * le), height: max(40, h - 2 * le))
        }
    }

    /// Chỗ cho một ảnh mới cỡ `anh` (pt): ngay DƯỚI nội dung đã có (`dayNoiDung` = đáy nét + ảnh cũ, toạ độ
    /// trang), co cho vừa bề ngang vùng ghi (không phóng to quá cỡ thật). Trả thêm số pt cần NỐI DÀI trang
    /// (0 = vừa trang) — ảnh không bao giờ bị cắt ở đáy.
    static func viTriMoi(anh: CGSize, giay: LoaiGiay, khoTrang: CGSize, khoGoc: CGSize,
                         dayNoiDung: CGFloat) -> (khung: CGRect, canNoiThem: CGFloat) {
        let vung = vungGhi(giay: giay, khoTrang: khoTrang, khoGoc: khoGoc)
        let ty = min(1, vung.width / max(anh.width, 1))
        let w = max(20, anh.width * ty), h = max(20, anh.height * ty)
        let y = max(vung.minY, dayNoiDung + 12)
        let khung = CGRect(x: vung.minX, y: y, width: w, height: h)
        // Cornell: dải tóm tắt ở đáy GIỮ NGUYÊN bề cao khi nối dài ⇒ phần thiếu = (đáy ảnh − đáy vùng ghi).
        let thieu = max(0, khung.maxY - vung.maxY)
        return (khung, ceil(thieu))
    }

    /// Đáy nội dung đã có trên trang (nét + ảnh dán) theo toạ độ trang.
    static func dayNoiDung(net: PKDrawing, anh: [AnhDanTrang]) -> CGFloat {
        let dayNet = net.strokes.isEmpty ? 0 : net.bounds.maxY
        let dayAnh = anh.map { CGFloat($0.y + $0.cao) }.max() ?? 0
        return max(dayNet, dayAnh)
    }

    // MARK: Dán

    /// Dán `anh` (ảnh màn hình, `scale` thật) vào trang: lưu PNG, đặt chỗ dưới nội dung, nối dài trang nếu cần.
    /// `net` = bản vẽ ĐANG hiện (nếu khung vẽ của trang đang mở) — không thì đọc từ đĩa.
    @MainActor @discardableResult
    static func dan(_ anh: UIImage, vao t: TrangVo, nguon: String?, net: PKDrawing? = nil,
                    kho: ModelContext) -> AnhDanTrang? {
        guard let png = anh.pngData() else { return nil }
        let ten = "\(UUID().uuidString).png"
        do { try png.write(to: duongDanAnh(ten), options: .atomic) } catch {
            NhatKy.vo.error("ảnh dán: ghi ảnh hỏng — \(error.localizedDescription)")
            return nil
        }
        var ds = ds(t.id)
        let day = dayNoiDung(net: net ?? KhoVo.nap(t.id), anh: ds)
        // Cỡ theo POINT của màn hình (ảnh chụp ở scale thật): đoạn bài vào vở đúng cỡ đang đọc, co nếu rộng hơn cột.
        let co = CGSize(width: anh.size.width, height: anh.size.height)
        var (khung, noi) = viTriMoi(anh: co, giay: t.giay, khoTrang: t.khoTrang, khoGoc: t.khoGoc, dayNoiDung: day)
        if noi > 0 {
            let tran = t.chieuCaoThemToiDa
            let moi = min(tran, t.chieuCaoThem + Double(noi))
            if moi < t.chieuCaoThem + Double(noi) {
                // Hết chỗ nối dài: đặt ảnh ở đầu vùng ghi (chồng lên chữ còn hơn mất ảnh) — hiếm.
                let vung = vungGhi(giay: t.giay, khoTrang: t.khoTrang, khoGoc: t.khoGoc)
                khung.origin.y = vung.minY
            }
            t.chieuCaoThem = moi
        }
        let a = AnhDanTrang(ten: ten, khung: khung, nguon: nguon)
        ds.append(a)
        guard luu(ds, cho: t.id) else { return nil }
        t.suaLuc = Date()
        t.cuon?.suaLuc = Date()
        if let c = t.cuon { ThaoTacTrang.danhDauCay(c) }
        try? kho.save()
        dungLaiAnhNho(t)
        return a
    }

    /// Gỡ ảnh dán GẦN NHẤT của trang. Trả về còn bao nhiêu ảnh.
    @MainActor @discardableResult
    static func goCuoi(_ t: TrangVo) -> Int {
        var ds = ds(t.id)
        guard let cuoi = ds.popLast() else { return 0 }
        luu(ds, cho: t.id)
        try? FileManager.default.removeItem(at: duongDanAnh(cuoi.ten))
        t.suaLuc = Date()
        dungLaiAnhNho(t)
        return ds.count
    }

    /// Xoá sạch ảnh dán của trang (trang bị xoá).
    static func xoaHet(_ idTrang: UUID) {
        let ds = ds(idTrang)
        for a in ds { try? FileManager.default.removeItem(at: duongDanAnh(a.ten)) }
        try? FileManager.default.removeItem(at: duongDanDs(idTrang))
    }

    /// Nhân bản trang ⇒ ảnh dán đi theo (chép cả tệp ảnh: hai trang độc lập).
    static func nhanBan(tu nguon: UUID, sang dich: UUID) {
        let ds = ds(nguon)
        guard !ds.isEmpty else { return }
        var moi: [AnhDanTrang] = []
        for a in ds {
            let ten = "\(UUID().uuidString).png"
            if (try? FileManager.default.copyItem(at: duongDanAnh(a.ten), to: duongDanAnh(ten))) != nil {
                var b = a; b.id = UUID(); b.ten = ten; moi.append(b)
            }
        }
        luu(moi, cho: dich)
    }

    /// Trang được dựng lại với id mới (Hoàn tác xoá) ⇒ danh sách ảnh đổi chủ.
    static func doiTrang(tu cu: UUID, sang moi: UUID) {
        let a = duongDanDs(cu), b = duongDanDs(moi)
        guard FileManager.default.fileExists(atPath: a.path) else { return }
        try? FileManager.default.removeItem(at: b)
        try? FileManager.default.moveItem(at: a, to: b)
    }

    /// Vẽ ảnh dán của trang vào một context đang ở TOẠ ĐỘ TRANG (ảnh nhỏ dải trang, PDF).
    static func ve(_ idTrang: UUID, vao khung: (CGRect) -> CGRect = { $0 }) {
        for a in ds(idTrang) {
            guard let img = UIImage(contentsOfFile: duongDanAnh(a.ten).path) else { continue }
            img.draw(in: khung(a.khung))
        }
    }

    @MainActor
    private static func dungLaiAnhNho(_ t: TrangVo) {
        let net = KhoVo.nap(t.id)
        let id = t.id, kho = t.khoTrang, goc = t.khoGoc
        let pdf = t.nenPdfTen, pdfTr = t.nenPdfTrang, anh = t.nenAnhTen, giay = t.giay
        Task.detached(priority: .utility) {
            KhoVo.dungAnhNho(net, kho: kho, khoNen: goc, cho: id, nenPdfTen: pdf, nenPdfTrang: pdfTr,
                             nenAnhTen: anh, giay: giay)
        }
    }
}

// MARK: - Lớp ảnh dán trong khung vẽ

/// Lớp vẽ ảnh dán, là subview của `PKCanvasView` (cuộn/phóng cùng trang như nền giấy). Không nhận chạm.
final class LopAnhDanView: UIView {
    private(set) var idTrang: UUID
    private var ds: [AnhDanTrang] = []
    private var oAnh: [UIImageView] = []
    var tyLe: CGFloat = 1 { didSet { if tyLe != oldValue { setNeedsLayout() } } }

    init(idTrang: UUID) {
        self.idTrang = idTrang
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        napLai()
        NotificationCenter.default.addObserver(self, selector: #selector(doi(_:)), name: KhoAnhDan.daDoi, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) chưa dùng tới") }
    deinit { NotificationCenter.default.removeObserver(self) }

    var coAnh: Bool { !ds.isEmpty }

    @objc private func doi(_ n: Notification) {
        guard (n.object as? UUID) == idTrang else { return }
        DispatchQueue.main.async { [weak self] in self?.napLai() }
    }

    func napLai() {
        ds = KhoAnhDan.ds(idTrang)
        oAnh.forEach { $0.removeFromSuperview() }
        oAnh = ds.map { a in
            let v = UIImageView(image: KhoAnhDan.anh(a.ten))
            v.contentMode = .scaleToFill
            // Viền mảnh: nhìn ra đâu là mẩu dán, đâu là chữ viết tay.
            v.layer.borderWidth = 0.5
            v.layer.borderColor = UIColor.separator.cgColor
            v.layer.cornerRadius = 3
            v.clipsToBounds = true
            v.accessibilityLabel = a.nguon.map { "\(T("Ảnh dán từ")) \($0)" } ?? T("Ảnh dán")
            addSubview(v)
            return v
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (a, v) in zip(ds, oAnh) {
            let k = a.khung
            v.frame = CGRect(x: k.minX * tyLe, y: k.minY * tyLe, width: k.width * tyLe, height: k.height * tyLe)
        }
    }
}
#endif

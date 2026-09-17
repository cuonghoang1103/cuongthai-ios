#if os(iOS)
import Foundation
import PencilKit
import UIKit

/// Kho tệp nét vẽ trên đĩa máy.
///
/// ⚠️ **Tệp là nguồn sự thật, không phải SwiftData.** Nét vẽ nằm ở
/// `Documents/Vo/<id>.drawing`; SwiftData chỉ giữ tên trang, thứ tự, loại
/// giấy. Nếu kho SwiftData hỏng (đổi schema sai, máy hết pin giữa lúc ghi)
/// thì vở vẫn còn nguyên trên đĩa và dựng lại được. Làm ngược lại — nhét
/// `Data` của nét vẽ vào một cột SwiftData — là đặt cả năm học vào một tệp
/// duy nhất mà không có bản nào khác.
enum KhoVo {

    // MARK: Đường dẫn

    static var thuMucGoc: URL {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vo = doc.appendingPathComponent("Vo", isDirectory: true)
        taoNeuThieu(vo)
        return vo
    }

    private static var thuMucAnhNho: URL {
        let u = thuMucGoc.appendingPathComponent("thumb", isDirectory: true)
        taoNeuThieu(u)
        return u
    }

    static func duongDanNet(_ idTrang: UUID) -> URL {
        thuMucGoc.appendingPathComponent("\(idTrang.uuidString).drawing")
    }

    static func duongDanAnhNho(_ idTrang: UUID) -> URL {
        thuMucAnhNho.appendingPathComponent("\(idTrang.uuidString).png")
    }

    private static func taoNeuThieu(_ url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        // Vở là dữ liệu người dùng viết ra, không phải cache — phải vào iCloud
        // backup. Mặc định của Documents/ đã là vậy, nhưng nói rõ ra để lần
        // sau ai đó đổi sang Caches/ thì thấy ngay vì sao không nên.
    }

    // MARK: Đọc / ghi

    static func nap(_ idTrang: UUID) -> PKDrawing {
        let url = duongDanNet(idTrang)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            return PKDrawing()
        }
        do {
            return try PKDrawing(data: data)
        } catch {
            // Tệp hỏng: KHÔNG xoá. Đổi tên để người dùng còn cơ hội cứu, và
            // trả về trang trắng để app không sập giữa buổi học.
            let hong = url.appendingPathExtension("hong")
            try? FileManager.default.moveItem(at: url, to: hong)
            NhatKy.vo.error("Nét vẽ hỏng ở trang \(idTrang.uuidString), đã giữ lại tại \(hong.lastPathComponent)")
            return PKDrawing()
        }
    }

    /// Ghi NGUYÊN TỬ: ghi tệp tạm rồi tráo. Ghi đè thẳng lên tệp cũ mà máy
    /// tắt đúng lúc đó thì mất cả trang — và trang vở là thứ không dựng lại
    /// được từ đâu cả.
    @discardableResult
    static func ghi(_ drawing: PKDrawing, cho idTrang: UUID) -> Bool {
        let dich = duongDanNet(idTrang)
        let tam = thuMucGoc.appendingPathComponent("\(idTrang.uuidString).tmp")
        let data = drawing.dataRepresentation()
        do {
            try data.write(to: tam, options: .atomic)
            if FileManager.default.fileExists(atPath: dich.path) {
                _ = try FileManager.default.replaceItemAt(dich, withItemAt: tam)
            } else {
                try FileManager.default.moveItem(at: tam, to: dich)
            }
            return true
        } catch {
            NhatKy.vo.error("Ghi nét vẽ thất bại (\(idTrang.uuidString)): \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: tam)
            return false
        }
    }

    static func xoa(_ idTrang: UUID) {
        try? FileManager.default.removeItem(at: duongDanNet(idTrang))
        try? FileManager.default.removeItem(at: duongDanAnhNho(idTrang))
    }

    static func nhanBan(tu nguon: UUID, sang dich: UUID) {
        let a = duongDanNet(nguon), b = duongDanNet(dich)
        guard FileManager.default.fileExists(atPath: a.path) else { return }
        try? FileManager.default.removeItem(at: b)
        try? FileManager.default.copyItem(at: a, to: b)
    }

    // MARK: Ảnh thu nhỏ

    /// Vẽ ảnh nhỏ cho dải trang. Chạy ngoài luồng chính vì `image(from:scale:)`
    /// dựng lại toàn bộ nét — với trang viết dày nó tốn vài chục mili giây,
    /// đủ để dải trang giật khi cuộn.
    static func dungAnhNho(_ drawing: PKDrawing, kho: CGSize, cho idTrang: UUID) {
        let ty: CGFloat = 0.25
        let khoNho = CGSize(width: kho.width * ty, height: kho.height * ty)
        let anh = UIGraphicsImageRenderer(size: khoNho).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: khoNho))
            guard !drawing.bounds.isEmpty else { return }
            let net = drawing.image(from: CGRect(origin: .zero, size: kho), scale: ty)
            net.draw(in: CGRect(origin: .zero, size: khoNho))
        }
        if let png = anh.pngData() {
            try? png.write(to: duongDanAnhNho(idTrang), options: .atomic)
        }
    }

    static func anhNho(_ idTrang: UUID) -> UIImage? {
        guard let d = try? Data(contentsOf: duongDanAnhNho(idTrang)) else { return nil }
        return UIImage(data: d)
    }

    // MARK: Dọn dẹp

    /// Xoá tệp nét vẽ không còn trang nào trỏ tới (mồ côi sau khi xoá cuốn).
    ///
    /// ⚠️ Nhận VÀO danh sách id còn sống chứ không tự đi hỏi SwiftData: gọi
    /// lúc kho chưa nạp xong thì danh sách rỗng và hàm này xoá sạch vở.
    static func donMoCoi(idConSong: Set<UUID>) {
        guard !idConSong.isEmpty else { return }
        let fm = FileManager.default
        guard let ds = try? fm.contentsOfDirectory(at: thuMucGoc, includingPropertiesForKeys: nil) else { return }
        for url in ds where url.pathExtension == "drawing" {
            let ten = url.deletingPathExtension().lastPathComponent
            if let id = UUID(uuidString: ten), !idConSong.contains(id) {
                try? fm.removeItem(at: url)
                try? fm.removeItem(at: duongDanAnhNho(id))
            }
        }
    }

    /// Tổng dung lượng vở đang chiếm trên máy — hiện trong màn cài đặt để
    /// người dùng biết vở nặng bao nhiêu trước khi bật đồng bộ.
    static func dungLuong() -> Int64 {
        let fm = FileManager.default
        var tong: Int64 = 0
        for goc in [thuMucGoc, thuMucAnhNho] {
            guard let ds = try? fm.contentsOfDirectory(at: goc, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            for url in ds {
                let co = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                tong += Int64(co)
            }
        }
        return tong
    }
}
#endif

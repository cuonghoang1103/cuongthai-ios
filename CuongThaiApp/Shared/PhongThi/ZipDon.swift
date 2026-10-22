import Foundation

// ════════════════════════════════════════════════════════════════
// BỘ GHI .ZIP TỐI GIẢN — cho đề PE CODE
//
// `POST /exams/attempts/:id/submit-code` CHỈ nhận một tệp .zip (multer
// `zipUpload.single('file')`, trần 30MB) rồi `extractCodeFromZip` (AdmZip)
// rút các tệp mã nguồn ra chấm. Trên web người học tự nén ở máy; trên điện
// thoại thì người ta GÕ ngay trong app — nên app phải tự đóng gói các câu đã
// gõ thành `Q1.c`, `Q2.c`… y như bộ "Given" của đề.
//
// Chỉ ghi kiểu STORED (không nén, method 0): mã nguồn vài KB, nén chẳng lợi
// gì mà thêm cả một bộ deflate để sai. Apple có `Compression` nhưng nó ra
// luồng zlib/deflate THÔ, không ra định dạng .zip — vẫn phải tự ghi phần vỏ.
//
// Định dạng: PKWARE APPNOTE 6.3 — mỗi tệp một "local file header" + dữ liệu,
// rồi "central directory", rồi "end of central directory". Cờ bit 11 = tên
// tệp UTF-8 (tên có dấu vẫn đọc đúng ở AdmZip lẫn Finder).
// ════════════════════════════════════════════════════════════════

enum ZipDon {
    struct Tep {
        let ten: String
        let duLieu: Data
    }

    /// Đóng gói `tep` thành một tệp .zip (STORED). Tên trùng thì tệp sau
    /// được đổi tên `…-2` để không có hai mục cùng đường dẫn.
    static func dongGoi(_ tep: [Tep], luc: Date = Date()) -> Data {
        var ra = Data()
        var thuMuc = Data()
        let (gio, ngay) = gioDOS(luc)
        var daDung = Set<String>()

        for t in tep {
            var ten = t.ten.replacingOccurrences(of: "\\", with: "/")
            while ten.hasPrefix("/") { ten.removeFirst() }
            if ten.isEmpty { ten = "tep" }
            var duyNhat = ten
            var k = 2
            while daDung.contains(duyNhat) {
                let ns = ten as NSString
                let duoi = ns.pathExtension
                let goc = ns.deletingPathExtension
                duyNhat = duoi.isEmpty ? "\(goc)-\(k)" : "\(goc)-\(k).\(duoi)"
                k += 1
            }
            daDung.insert(duyNhat)

            let tenByte = Data(duyNhat.utf8)
            let crc = CRC32.tinh(t.duLieu)
            let co: UInt16 = 0x0800          // bit 11: tên UTF-8
            let viTri = UInt32(ra.count)

            // Local file header
            ra.ghi32(0x04034B50)
            ra.ghi16(20)                     // version needed: 2.0
            ra.ghi16(co)
            ra.ghi16(0)                      // method: stored
            ra.ghi16(gio); ra.ghi16(ngay)
            ra.ghi32(crc)
            ra.ghi32(UInt32(t.duLieu.count)) // compressed size
            ra.ghi32(UInt32(t.duLieu.count)) // uncompressed size
            ra.ghi16(UInt16(tenByte.count))
            ra.ghi16(0)                      // extra length
            ra.append(tenByte)
            ra.append(t.duLieu)

            // Central directory entry
            thuMuc.ghi32(0x02014B50)
            thuMuc.ghi16(0x031E)             // made by: Unix, 3.0
            thuMuc.ghi16(20)
            thuMuc.ghi16(co)
            thuMuc.ghi16(0)
            thuMuc.ghi16(gio); thuMuc.ghi16(ngay)
            thuMuc.ghi32(crc)
            thuMuc.ghi32(UInt32(t.duLieu.count))
            thuMuc.ghi32(UInt32(t.duLieu.count))
            thuMuc.ghi16(UInt16(tenByte.count))
            thuMuc.ghi16(0)                  // extra
            thuMuc.ghi16(0)                  // comment
            thuMuc.ghi16(0)                  // disk number
            thuMuc.ghi16(0)                  // internal attrs
            thuMuc.ghi32(0o100644 << 16)     // external attrs: tệp thường rw-r--r--
            thuMuc.ghi32(viTri)
            thuMuc.append(tenByte)
        }

        let batDauThuMuc = UInt32(ra.count)
        ra.append(thuMuc)
        // End of central directory
        ra.ghi32(0x06054B50)
        ra.ghi16(0); ra.ghi16(0)
        ra.ghi16(UInt16(tep.count)); ra.ghi16(UInt16(tep.count))
        ra.ghi32(UInt32(thuMuc.count))
        ra.ghi32(batDauThuMuc)
        ra.ghi16(0)                          // comment length
        return ra
    }

    /// Giờ/ngày kiểu MS-DOS (giờ địa phương, độ phân giải 2 giây).
    static func gioDOS(_ d: Date) -> (UInt16, UInt16) {
        let c = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: d)
        let nam = max(1980, c.year ?? 1980)
        let gio = UInt16(((c.hour ?? 0) << 11) | ((c.minute ?? 0) << 5) | ((c.second ?? 0) / 2))
        let ngay = UInt16(((nam - 1980) << 9) | ((c.month ?? 1) << 5) | (c.day ?? 1))
        return (gio, ngay)
    }
}

/// CRC-32 (IEEE 802.3, đa thức 0xEDB88320) — đúng loại .zip dùng.
enum CRC32 {
    private static let bang: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func tinh(_ d: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        d.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
            for b in p { crc = bang[Int((crc ^ UInt32(b)) & 0xFF)] ^ (crc >> 8) }
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func ghi16(_ v: UInt16) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
    mutating func ghi32(_ v: UInt32) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}

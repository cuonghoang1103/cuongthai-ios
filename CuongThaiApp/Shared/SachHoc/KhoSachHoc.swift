import Foundation
import CryptoKit

// ════════════════════════════════════════════════════════════════
// KHO SÁCH HỌC — tải + lưu đĩa theo phiên bản, đọc được ngoại tuyến.
//
// Nguồn: `https://cuongthai.com/sach-hoc/<khoa>/…` — JSON tĩnh web sinh lúc
// `next build` (frontend/scripts/sach-hoc-xuat.mts), nên MỖI LẦN DEPLOY WEB là
// app tự thấy nội dung mới; không có API, không qua APIClient (không có vỏ
// `{success,data}`). nginx dán `no-store` lên mọi thứ dưới `/` ⇒ app TỰ đệm:
//   index.json  → luôn hỏi mạng trước; hỏng mạng thì dùng bản đã lưu.
//   bai-<n>.json → lưu tên `bai-<n>.<hash>.json`; hash khớp mục lục ⇒ đọc đĩa,
//                  khỏi tải. Mất mạng ⇒ dùng bản cũ hơn nếu có (báo "bản đã lưu").
//
// ⚠️ DEBUG: biến môi trường `CT_SACHHOC_NGUON=/đường/tới/public/sach-hoc` ⇒ đọc
// thẳng thư mục do script sinh trên máy Mac (máy ảo đọc được ổ Mac) — kiểm
// trước khi deploy. Bản Release không đọc biến nào.
// ════════════════════════════════════════════════════════════════

enum LoiSachHoc: LocalizedError {
    case canCapNhatApp(Int)
    case khongCoMang
    case hong(String)

    var errorDescription: String? {
        switch self {
        case .canCapNhatApp: return "Nội dung khoá học mới hơn bản app này — hãy cập nhật app."
        case .khongCoMang: return "Chưa tải được khoá học. Kiểm tra mạng rồi thử lại — lần đầu cần mạng, sau đó học được cả khi ngoại tuyến."
        case .hong(let s): return s
        }
    }
}

actor KhoSachHoc {
    static let chung = KhoSachHoc()

    /// Gốc nguồn: thư mục chứa `<khoa>/index.json`.
    nonisolated static let goc: URL = {
        #if DEBUG
        let v = ProcessInfo.processInfo.environment["CT_SACHHOC_NGUON"] ?? ""
        if v.hasPrefix("/") { return URL(fileURLWithPath: v, isDirectory: true) }
        if v.hasPrefix("http") { return URL(string: v)! }
        #endif
        return URL(string: APIClient.diaChiGoc + "/sach-hoc/")!
    }()

    private let fm = FileManager.default
    private var dangTai: [String: Task<Data, Error>] = [:]

    private func thuMuc(_ khoa: String) -> URL {
        let goc = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let d = goc.appendingPathComponent("SachHoc", isDirectory: true).appendingPathComponent(khoa, isDirectory: true)
        try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    // MARK: Mạng / tệp nguồn

    private func taiNguon(_ khoa: String, _ tep: String) async throws -> Data {
        let k = "\(khoa)/\(tep)"
        if let t = dangTai[k] { return try await t.value }
        let url = Self.goc.appendingPathComponent(khoa).appendingPathComponent(tep)
        let t = Task<Data, Error> {
            if url.isFileURL { return try Data(contentsOf: url) }
            var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            r.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
            let (d, res) = try await URLSession.shared.data(for: r)
            guard let h = res as? HTTPURLResponse, h.statusCode == 200 else {
                throw LoiSachHoc.hong("Máy chủ trả \((res as? HTTPURLResponse)?.statusCode ?? 0) cho \(tep)")
            }
            return d
        }
        dangTai[k] = t
        defer { dangTai[k] = nil }
        return try await t.value
    }

    private static func bam(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    // MARK: Mục lục

    struct KetQuaMucLuc { let khoa: KhoaSH; let banLuu: Bool }

    /// Mục lục: hỏi nguồn trước; hỏng ⇒ bản lưu (`banLuu = true`).
    func mucLuc(_ khoa: String) async throws -> KetQuaMucLuc {
        let luu = thuMuc(khoa).appendingPathComponent("index.json")
        do {
            let d = try await taiNguon(khoa, "index.json")
            let k = try giaiMucLuc(d)
            try? d.write(to: luu, options: .atomic)
            return KetQuaMucLuc(khoa: k, banLuu: false)
        } catch let e as LoiSachHoc {
            if case .canCapNhatApp = e { throw e }
            if let d = try? Data(contentsOf: luu), let k = try? giaiMucLuc(d) { return KetQuaMucLuc(khoa: k, banLuu: true) }
            throw e
        } catch {
            if let d = try? Data(contentsOf: luu), let k = try? giaiMucLuc(d) { return KetQuaMucLuc(khoa: k, banLuu: true) }
            if error is DecodingError { throw LoiSachHoc.hong("Mục lục khoá học không đúng định dạng.") }
            throw LoiSachHoc.khongCoMang
        }
    }

    /// Chỉ bản đã lưu — để màn mở ra là có ngay, trước khi hỏi mạng.
    func mucLucDaLuu(_ khoa: String) -> KhoaSH? {
        let luu = thuMuc(khoa).appendingPathComponent("index.json")
        guard let d = try? Data(contentsOf: luu) else { return nil }
        return try? giaiMucLuc(d)
    }

    private func giaiMucLuc(_ d: Data) throws -> KhoaSH {
        struct Dau: Decodable { let schema: Int }
        if let s = try? JSONDecoder().decode(Dau.self, from: d), s.schema > SACH_HOC_SCHEMA {
            throw LoiSachHoc.canCapNhatApp(s.schema)
        }
        return try JSONDecoder().decode(KhoaSH.self, from: d)
    }

    // MARK: Tệp nội dung (bai-n, phu-id, chia, chu-han)

    struct KetQuaTep { let data: Data; let banCu: Bool }

    /// Tệp `tep` với hash mong đợi: đĩa có đúng hash ⇒ dùng; không ⇒ tải; mất mạng ⇒ bản cũ hơn nếu có.
    func tep(_ khoa: String, _ tep: String, hash: String) async throws -> KetQuaTep {
        let dir = thuMuc(khoa)
        let goc = (tep as NSString).deletingPathExtension
        let dung = dir.appendingPathComponent("\(goc).\(hash).json")
        if let d = try? Data(contentsOf: dung) { return KetQuaTep(data: d, banCu: false) }
        do {
            let d = try await taiNguon(khoa, tep)
            // Lưu theo hash THẬT của dữ liệu (lỡ mục lục và tệp lệch nhịp lúc deploy thì lần sau tải lại).
            let that = Self.bam(d)
            xoaBanCu(dir: dir, goc: goc)
            try? d.write(to: dir.appendingPathComponent("\(goc).\(that).json"), options: .atomic)
            return KetQuaTep(data: d, banCu: false)
        } catch {
            if let cu = banCuNhat(dir: dir, goc: goc), let d = try? Data(contentsOf: cu) { return KetQuaTep(data: d, banCu: true) }
            throw LoiSachHoc.khongCoMang
        }
    }

    /// Đã có trên đĩa đúng phiên bản chưa (để hiện dấu "đã tải" ở mục lục).
    func daCo(_ khoa: String, _ tep: String, hash: String) -> Bool {
        let goc = (tep as NSString).deletingPathExtension
        return fm.fileExists(atPath: thuMuc(khoa).appendingPathComponent("\(goc).\(hash).json").path)
    }

    private func cacBan(dir: URL, goc: String) -> [URL] {
        ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(goc + ".") && $0.pathExtension == "json" }
    }
    private func xoaBanCu(dir: URL, goc: String) { cacBan(dir: dir, goc: goc).forEach { try? fm.removeItem(at: $0) } }
    private func banCuNhat(dir: URL, goc: String) -> URL? {
        cacBan(dir: dir, goc: goc).max {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a < b
        }
    }

    /// Dung lượng đã lưu của một khoá (byte).
    func dungLuong(_ khoa: String) -> Int {
        ((try? fm.contentsOfDirectory(at: thuMuc(khoa), includingPropertiesForKeys: [.fileSizeKey])) ?? [])
            .reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    func xoaHet(_ khoa: String) {
        try? fm.removeItem(at: thuMuc(khoa))
    }

    // MARK: Giải mã (chạy trong actor ⇒ ngoài luồng chính — bài 950 KB)

    func buoi(_ khoa: String, _ b: BuoiSH) async throws -> (bai: [BaiSH], banCu: Bool) {
        guard let tep = b.tep, let hash = b.hash else { return ([], false) }
        let kq = try await self.tep(khoa, tep, hash: hash)
        do {
            return (try JSONDecoder().decode(TepBuoiSH.self, from: kq.data).bai, kq.banCu)
        } catch {
            throw LoiSachHoc.hong("Nội dung \(b.ten) không đúng định dạng.")
        }
    }

    func phu(_ khoa: String, _ m: MucPhuSH) async throws -> (bai: BaiSH, banCu: Bool) {
        let kq = try await tep(khoa, m.tep, hash: m.hash)
        do { return (try JSONDecoder().decode(TepPhuSH.self, from: kq.data).bai, kq.banCu) }
        catch { throw LoiSachHoc.hong("Nội dung “\(m.title)” không đúng định dạng.") }
    }

    func giai<T: Decodable>(_ khoa: String, _ t: TepSH, _: T.Type) async throws -> T {
        let kq = try await tep(khoa, t.tep, hash: t.hash)
        return try JSONDecoder().decode(T.self, from: kq.data)
    }
}

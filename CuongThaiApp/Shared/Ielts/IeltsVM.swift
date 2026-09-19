import Foundation
import SwiftUI

/// Gọi HTTP cho mảng IELTS. Tầng mạng thuần, không `@MainActor`.
enum IeltsAPI {
    private static var api: APIClient { .shared }

    static func loTrinh() async throws -> GoiLoTrinh { try await api.request(.ieltsLoTrinh) }

    static func phan<T: Decodable>(_ chang: String, _ phan: String, _ kieu: T.Type) async throws -> T {
        let goi: GoiNoiDung<T> = try await api.request(.ieltsPhanChang(chang: chang, phan: phan))
        return goi.payload
    }

    static func chung<T: Decodable>(_ phan: String, _ kieu: T.Type) async throws -> T {
        let goi: GoiNoiDung<T> = try await api.request(.ieltsChung(phan: phan))
        return goi.payload
    }

    static func tienDo(chang: String? = nil) async throws -> [MucTienDo] {
        let g: GoiTienDo = try await api.request(.ieltsTienDo(chang: chang))
        return g.items
    }

    @discardableResult
    static func ghiTienDo(_ items: [[String: Any]]) async throws -> KetQuaTrong {
        try await api.request(.ieltsGhiTienDo(items: items))
    }

    @discardableResult
    static func xoaTienDo(chang: String, phan: String, muc: String) async throws -> KetQuaTrong {
        try await api.request(.ieltsXoaTienDo(chang: chang, phan: phan, muc: muc))
    }
}

/// Trạng thái của cả mảng IELTS.
///
/// Nội dung tải theo TỪNG PHẦN và giữ lại trong bộ nhớ (`daTai`): mở tab Đọc
/// của chặng 1 là 48 KB, quay đi quay lại năm lần mà tải năm lần thì vừa chậm
/// vừa tốn tiền mạng của người học.
@MainActor
final class IeltsVM: ObservableObject {
    @Published var loTrinh: GoiLoTrinh?
    @Published var changDangXem = "stage1"

    @Published var baiDoc: [String: [BaiDocIelts]] = [:]
    @Published var baiNghe: [String: [BaiNgheIelts]] = [:]
    @Published var deViet: [String: [DeVietIelts]] = [:]
    @Published var chuDeNoi: [String: [ChuDeNoiIelts]] = [:]
    @Published var tuVung: [String: GoiTuVung] = [:]
    @Published var chuDiem: [String: [ChuDiemIelts]] = [:]

    /// Mục đã xong, khoá `"stage/kind/muc"`. Một `Set` chứ không mảng: màn
    /// danh sách hỏi "mục này xong chưa" cho từng dòng, mà mảng thì mỗi dòng
    /// là một lượt quét toàn bộ.
    @Published var daXong: Set<String> = []
    /// Mốc thời gian của mọi mục ĐÃ XONG — để tính chuỗi ngày và XP hôm nay.
    @Published var mocXong: [Date] = []
    /// Con đường đặt vào đây trước khi đẩy sang màn danh sách: "units#3"
    /// nghĩa là mở thẳng bài học thứ 3. Màn danh sách đọc rồi XOÁ NGAY —
    /// để lại thì lần sau mở danh sách bằng tay nó cũng tự nhảy vào bài cũ.
    @Published var moMuc: String?

    @Published var dangTai = false
    @Published var loi: String?
    @Published var daNapLanDau = false

    private var dangTaiPhan: Set<String> = []

    static func khoa(_ chang: String, _ phan: String, _ muc: String) -> String { "\(chang)/\(phan)/\(muc)" }

    func xong(_ chang: String, _ phan: String, _ muc: String) -> Bool {
        daXong.contains(Self.khoa(chang, phan, muc))
    }

    // MARK: - Nạp

    func napLoTrinh() async {
        dangTai = true
        defer { dangTai = false; daNapLanDau = true }
        do {
            async let lt = IeltsAPI.loTrinh()
            async let td = IeltsAPI.tienDo()
            let (a, b) = try await (lt, td)
            loTrinh = a
            daXong = Set(b.filter(\.xong).map { Self.khoa($0.stage, $0.kind, $0.muc) })
            let bo = ISO8601DateFormatter()
            bo.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let bo2 = ISO8601DateFormatter()
            mocXong = b.filter(\.xong).compactMap {
                // Hai bộ đọc: máy chủ trả ISO CÓ mili giây. Chỉ dùng bộ
                // không-mili thì mọi mốc đều `nil` và chuỗi ngày luôn bằng 0
                // — sai một cách im lặng, và trông y như "chưa học ngày nào".
                guard let s = $0.updatedAt else { return nil }
                return bo.date(from: s) ?? bo2.date(from: s)
            }
        } catch { ghiLoi(error) }
    }

    /// Nạp một phần nếu chưa có. Idempotent và chống gọi chồng — `.task` của
    /// SwiftUI chạy lại khi view dựng lại, và hai lượt tải cùng lúc thì lượt
    /// về sau ghi đè lượt về trước, có khi bằng dữ liệu cũ hơn.
    func napDoc(_ chang: String) async {
        await nap("readings", chang) { [weak self] in
            let v = try await IeltsAPI.phan(chang, "readings", [BaiDocIelts].self)
            self?.baiDoc[chang] = v
        }
    }

    func napNghe(_ chang: String) async {
        await nap("listenings", chang) { [weak self] in
            let v = try await IeltsAPI.phan(chang, "listenings", GoiNghe.self)
            self?.baiNghe[chang] = v.items
        }
    }

    func napViet(_ chang: String) async {
        await nap("writings", chang) { [weak self] in
            let v = try await IeltsAPI.phan(chang, "writings", [DeVietIelts].self)
            self?.deViet[chang] = v
        }
    }

    func napNoi(_ chang: String) async {
        await nap("speakings", chang) { [weak self] in
            let v = try await IeltsAPI.phan(chang, "speakings", GoiNoi.self)
            self?.chuDeNoi[chang] = v.topics
        }
    }

    func napTuVung(_ chang: String) async {
        await nap("vocab", chang) { [weak self] in
            let v = try await IeltsAPI.phan(chang, "vocab", GoiTuVung.self)
            self?.tuVung[chang] = v
        }
    }

    func napBaiHoc(_ chang: String) async {
        await nap("units", chang) { [weak self] in
            let v = try await IeltsAPI.phan(chang, "units", [ChuDiemIelts].self)
            self?.chuDiem[chang] = v
        }
    }

    private func nap(_ phan: String, _ chang: String, _ viec: @escaping () async throws -> Void) async {
        let k = "\(chang)/\(phan)"
        guard !dangTaiPhan.contains(k) else { return }
        dangTaiPhan.insert(k)
        defer { dangTaiPhan.remove(k) }
        do { try await viec() } catch { ghiLoi(error) }
    }

    // MARK: - Tiến độ

    /// Đánh dấu xong/chưa xong. Sửa ở app TRƯỚC rồi mới gọi mạng — tích một ô
    /// mà phải chờ máy chủ mới thấy nó đổi màu thì cảm giác như app đơ.
    func doiXong(_ chang: String, _ phan: String, _ muc: String, _ xong: Bool, diem: Int? = nil) async {
        let k = Self.khoa(chang, phan, muc)
        if xong { daXong.insert(k) } else { daXong.remove(k) }
        do {
            if xong {
                try await IeltsAPI.ghiTienDo([["stage": chang, "kind": phan, "muc": muc,
                                               "xong": true, "diem": diem as Any]])
            } else {
                try await IeltsAPI.xoaTienDo(chang: chang, phan: phan, muc: muc)
            }
            await lamMoiLoTrinh()
        } catch {
            // Trả lại đúng trạng thái cũ. Giữ nguyên vẻ "đã xong" khi máy chủ
            // từ chối là nói dối người học về tiến độ của chính họ.
            if xong { daXong.remove(k) } else { daXong.insert(k) }
            ghiLoi(error)
        }
    }

    /// Tích cả cụm — dùng khi học xong một danh sách từ vựng.
    func doiXongNhieu(_ chang: String, _ phan: String, _ mucs: [String], _ xong: Bool) async {
        guard !mucs.isEmpty else { return }
        for m in mucs {
            let k = Self.khoa(chang, phan, m)
            if xong { daXong.insert(k) } else { daXong.remove(k) }
        }
        do {
            if xong {
                try await IeltsAPI.ghiTienDo(mucs.map { ["stage": chang, "kind": phan, "muc": $0, "xong": true] })
            } else {
                for m in mucs { try await IeltsAPI.xoaTienDo(chang: chang, phan: phan, muc: m) }
            }
            await lamMoiLoTrinh()
        } catch { ghiLoi(error) }
    }

    private func lamMoiLoTrinh() async {
        // Chỉ lấy lại mục lục (nhẹ), không tải lại nội dung đã có.
        if let lt = try? await IeltsAPI.loTrinh() { loTrinh = lt }
    }

    // MARK: - Tiện

    var changHienTai: ChangIelts? { loTrinh?.chang.first { $0.id == changDangXem } }

    var bandCuaChang: ChangBand? {
        guard let s = loTrinh?.roadmap?.stages, let i = Int(changDangXem.dropFirst(5)), i >= 1, i <= s.count
        else { return nil }
        return s[i - 1]
    }

    private func ghiLoi(_ e: Error) {
        if case APIError.unauthorized = e { return }
        loi = e.localizedDescription
    }
}

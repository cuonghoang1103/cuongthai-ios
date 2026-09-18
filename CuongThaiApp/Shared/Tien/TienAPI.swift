import Foundation

/// Kết quả của mọi lệnh xoá trong mảng tiền nong — backend trả `{ id }`.
struct KetQuaId: Decodable { let id: Int }

/// Mọi lời gọi HTTP của mảng tiền nong, gom một chỗ.
///
/// Không có `@MainActor` ở đây: đây là tầng mạng thuần, gọi từ đâu cũng được.
/// Việc đưa kết quả về luồng chính là của `TienVM`.
enum TienAPI {
    private static var api: APIClient { .shared }

    // ─── Tổng quan ───────────────────────────────────────────
    static func bang(thang: String?) async throws -> BangTien {
        try await api.request(.tienBang(thang: thang))
    }

    // ─── Ví ──────────────────────────────────────────────────
    static func dsVi() async throws -> [Vi] { try await api.request(.tienDsVi) }

    static func themVi(ten: String, loai: String, soDu: Double, bieuTuong: String?, tienTe: String) async throws -> Vi {
        var m: [String: Any] = ["name": ten, "type": loai, "balance": soDu, "currency": tienTe]
        if let b = bieuTuong, !b.isEmpty { m["icon"] = b }
        return try await api.request(.tienThemVi(m))
    }

    static func suaVi(id: Int, ten: String, loai: String, bieuTuong: String?) async throws -> Vi {
        var m: [String: Any] = ["name": ten, "type": loai]
        if let b = bieuTuong, !b.isEmpty { m["icon"] = b }
        return try await api.request(.tienSuaVi(id: id, m))
    }

    static func luuTruVi(id: Int, luuTru: Bool) async throws -> Vi {
        try await api.request(.tienSuaVi(id: id, ["isArchived": luuTru]))
    }

    static func xoaVi(id: Int) async throws -> KetQuaId { try await api.request(.tienXoaVi(id: id)) }

    static func chuyenVi(tu: Int, den: Int, soTien: Double, ghiChu: String?) async throws -> KetQuaTrong {
        var m: [String: Any] = ["fromWalletId": tu, "toWalletId": den, "amount": soTien]
        if let g = ghiChu, !g.isEmpty { m["note"] = g }
        return try await api.request(.tienChuyenVi(m))
    }

    // ─── Nhóm chi ────────────────────────────────────────────
    static func dsNhomChi() async throws -> [NhomChi] { try await api.request(.tienDsNhomChi) }

    static func themNhomChi(ten: String, bieuTuong: String?, nganSach: Double?) async throws -> NhomChi {
        var m: [String: Any] = ["name": ten]
        if let b = bieuTuong, !b.isEmpty { m["icon"] = b }
        if let n = nganSach, n > 0 { m["monthlyBudget"] = n }
        return try await api.request(.tienThemNhomChi(m))
    }

    static func suaNhomChi(id: Int, ten: String, bieuTuong: String?, nganSach: Double?) async throws -> NhomChi {
        var m: [String: Any] = ["name": ten]
        if let b = bieuTuong, !b.isEmpty { m["icon"] = b }
        // `NSNull` chứ không bỏ trường: bỏ trường thì backend giữ nguyên ngân
        // sách cũ, nên người dùng KHÔNG xoá được ngân sách đã đặt.
        m["monthlyBudget"] = (nganSach ?? 0) > 0 ? nganSach! : NSNull()
        return try await api.request(.tienSuaNhomChi(id: id, m))
    }

    static func xoaNhomChi(id: Int) async throws -> KetQuaId { try await api.request(.tienXoaNhomChi(id: id)) }

    // ─── Chi tiêu ────────────────────────────────────────────
    static func dsChi(thang: String?, nhomId: Int?, trang: Int = 1) async throws -> TrangChi {
        let khung = thang.map { NgayTien.khungThang($0) }
        return try await api.request(.tienDsChi(tu: khung?.tu, den: khung?.den, nhomId: nhomId, trang: trang))
    }

    static func themChi(nhomId: Int, viId: Int, soTien: Double, ngay: String, moTa: String?) async throws -> KhoanChi {
        var m: [String: Any] = ["categoryId": nhomId, "walletId": viId, "amount": soTien, "date": ngay]
        if let d = moTa, !d.isEmpty { m["description"] = d }
        return try await api.request(.tienThemChi(m))
    }

    static func suaChi(id: Int, nhomId: Int, viId: Int, soTien: Double, ngay: String, moTa: String?) async throws -> KhoanChi {
        var m: [String: Any] = ["categoryId": nhomId, "walletId": viId, "amount": soTien, "date": ngay]
        m["description"] = (moTa?.isEmpty == false) ? moTa! : NSNull()
        return try await api.request(.tienSuaChi(id: id, m))
    }

    static func xoaChi(id: Int) async throws -> KetQuaId { try await api.request(.tienXoaChi(id: id)) }

    // ─── Thu nhập ────────────────────────────────────────────
    static func dsThu(thang: String?) async throws -> [KhoanThu] {
        try await api.request(.tienDsThu(thang: thang))
    }

    static func themThu(viId: Int, soTien: Double, ngay: String, loai: String, nguonId: Int?, ghiChu: String?) async throws -> KhoanThu {
        var m: [String: Any] = ["walletId": viId, "amount": soTien, "date": ngay, "type": loai]
        if let n = nguonId { m["sourceId"] = n }
        if let g = ghiChu, !g.isEmpty { m["note"] = g }
        return try await api.request(.tienThemThu(m))
    }

    static func xoaThu(id: Int) async throws -> KetQuaId { try await api.request(.tienXoaThu(id: id)) }

    static func dsNguonThu() async throws -> [NguonThu] { try await api.request(.tienDsNguonThu) }

    // ─── Nợ ──────────────────────────────────────────────────
    static func dsNo(trangThai: String? = nil) async throws -> [No] {
        try await api.request(.tienDsNo(trangThai: trangThai))
    }

    static func chiTietNo(id: Int) async throws -> No { try await api.request(.tienChiTietNo(id: id)) }

    static func themNo(_ m: [String: Any]) async throws -> No { try await api.request(.tienThemNo(m)) }

    static func xoaNo(id: Int) async throws -> KetQuaId { try await api.request(.tienXoaNo(id: id)) }

    /// Tích một kỳ là đã trả. `viId` để backend trừ tiền khỏi ví tương ứng —
    /// bỏ trống thì nó chỉ đánh dấu, số dư ví không đổi.
    static func traKy(noId: Int, kyId: Int, viId: Int?) async throws -> KetQuaTrong {
        var m: [String: Any] = [:]
        if let v = viId { m["walletId"] = v }
        return try await api.request(.tienTraKy(noId: noId, kyId: kyId, m))
    }

    static func huyTraKy(noId: Int, kyId: Int) async throws -> KetQuaTrong {
        try await api.request(.tienHuyTraKy(noId: noId, kyId: kyId))
    }

    // ─── Tiết kiệm ───────────────────────────────────────────
    static func dsTietKiem() async throws -> [SoTietKiem] { try await api.request(.tienDsTietKiem) }

    static func themTietKiem(_ m: [String: Any]) async throws -> SoTietKiem { try await api.request(.tienThemTietKiem(m)) }

    static func rutTietKiem(id: Int, viId: Int?, kemLai: Bool) async throws -> KetQuaTrong {
        var m: [String: Any] = ["includeInterest": kemLai]
        if let v = viId { m["walletId"] = v }
        return try await api.request(.tienRutTietKiem(id: id, m))
    }

    static func xoaTietKiem(id: Int) async throws -> KetQuaId { try await api.request(.tienXoaTietKiem(id: id)) }

    static func dsMucTieuTietKiem() async throws -> [MucTieuTietKiem] { try await api.request(.tienDsMucTieuTietKiem) }

    static func themMucTieuTietKiem(ten: String, dich: Double, hanChot: String?, bieuTuong: String?) async throws -> MucTieuTietKiem {
        var m: [String: Any] = ["name": ten, "targetAmount": dich]
        if let h = hanChot, !h.isEmpty { m["deadline"] = h }
        if let b = bieuTuong, !b.isEmpty { m["icon"] = b }
        return try await api.request(.tienThemMucTieuTietKiem(m))
    }

    static func gopMucTieuTietKiem(id: Int, soTien: Double, viId: Int?) async throws -> KetQuaTrong {
        var m: [String: Any] = ["amount": soTien]
        if let v = viId { m["walletId"] = v }
        return try await api.request(.tienGopMucTieuTietKiem(id: id, m))
    }

    static func xoaMucTieuTietKiem(id: Int) async throws -> KetQuaId { try await api.request(.tienXoaMucTieuTietKiem(id: id)) }

    // ─── Đầu tư ──────────────────────────────────────────────
    static func dsDauTu(loai: String? = nil) async throws -> [KhoanDauTu] {
        try await api.request(.tienDsDauTu(loai: loai))
    }

    static func themDauTu(_ m: [String: Any]) async throws -> KhoanDauTu { try await api.request(.tienThemDauTu(m)) }

    static func capNhatGiaTri(id: Int, giaTri: Double) async throws -> KhoanDauTu {
        try await api.request(.tienSuaDauTu(id: id, ["currentValue": giaTri]))
    }

    static func xoaDauTu(id: Int) async throws -> KetQuaId { try await api.request(.tienXoaDauTu(id: id)) }

    // ─── Mục tiêu chi tiêu ───────────────────────────────────
    static func mucTieu() async throws -> GoiMucTieu { try await api.request(.tienMucTieu) }

    static func datMucTieu(ky: String, soTien: Double) async throws -> KetQuaTrong {
        try await api.request(.tienDatMucTieu(ky: ky, soTien: soTien))
    }

    // ─── Cố vấn AI ───────────────────────────────────────────
    static func aiTomTat() async throws -> TraLoiCoVan { try await api.request(.tienAITomTat) }

    static func aiHoi(_ cauHoi: String) async throws -> TraLoiCoVan { try await api.request(.tienAIHoi(cauHoi: cauHoi)) }
}

/// Đáp án mà nơi gọi không quan tâm nội dung.
///
/// KHÔNG dùng `KetQuaId` cho những chỗ này: backend trả về ví, sổ, hay một
/// đối tượng khác tuỳ route, và ép một hình dạng cụ thể lên tất cả thì một
/// route đổi hình là ném `decodingError` cho một thao tác ĐÃ THÀNH CÔNG.
struct KetQuaTrong: Decodable {
    init(from decoder: Decoder) throws {}
}

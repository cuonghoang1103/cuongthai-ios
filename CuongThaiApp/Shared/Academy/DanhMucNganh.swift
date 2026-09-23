import SwiftUI

// ════════════════════════════════════════════════════════════════
// DANH MỤC NGÀNH — khối → ngành → ngành hẹp → khung 9 kỳ
//
// Dữ liệu nằm trong `KhungNganh.swift`, SINH BẰNG MÁY từ mã web bằng
// `scripts/sinh-khung-nganh.mjs`. Web thêm ngành / đổi khung thì chạy lại
// script đó — app không tự thấy.
//
// Phần lọc ở cuối tệp là bản chép của `components/academy/locTheoNganh.ts`.
// ⚠️ Đó là KIẾN THỨC về chương trình đào tạo (mã cũ ↔ mã mới, project OJT theo
// combo), không phải mã giao diện. Web sửa luật ở đó thì phải sửa cả ở đây —
// lệch nhau là hỏng CÂM: app vẫn chạy, chỉ thiếu môn.
// ════════════════════════════════════════════════════════════════

struct NganhHep: Decodable, Identifiable, Hashable {
    let id: String
    let code: String?
    let nameVi: String
    let name: String
    let icon: String
    /// Số môn (không trùng) trong khung của ngành hẹp này.
    let soMon: Int
}

struct Nganh: Decodable, Identifiable, Hashable {
    let id: String
    let nameVi: String
    let name: String
    let icon: String
    let comboNote: String?
    let curriculumCode: String?
    let curriculumId: Int?
    let credits: Int?
    /// Số môn của khung NỀN (chưa chọn ngành hẹp). Chỉ khối CNTT có; khối khác = 0.
    let soMonNen: Int
    let combos: [NganhHep]
}

struct KhoiNganh: Decodable, Identifiable, Hashable {
    let id: String
    let nameVi: String
    let name: String
    let icon: String
    let majors: [Nganh]
}

struct KyTrongKhung: Decodable, Hashable {
    let ky: Int
    let ma: [String]
}

struct NgheNghiep: Decodable {
    let summary: String
    let roles: [String]
}

/// Giai đoạn theo kỳ — bản chép `phaseOf()` trong `academyRoadmap.ts`.
struct GiaiDoan {
    let khoa: String
    let nhan: String
    let mau: Color
    let moTa: String

    static func cua(ky: Int) -> GiaiDoan {
        if ky <= 2 { return GiaiDoan(khoa: "foundation", nhan: "Nền tảng", mau: Color(hex: 0x22D3EE), moTa: "Toán, kỹ năng, lập trình cơ bản — bệ phóng cho mọi môn sau.") }
        if ky <= 5 { return GiaiDoan(khoa: "core", nhan: "Cốt lõi chuyên ngành", mau: Color(hex: 0x8B5CF6), moTa: "Cấu trúc dữ liệu, CSDL, OOP, web — kỹ năng \"xương sống\" của nghề.") }
        if ky == 6 { return GiaiDoan(khoa: "ojt", nhan: "Thực tập (OJT)", mau: Color(hex: 0xF59E0B), moTa: "Đi làm thực tế ở doanh nghiệp — biến kiến thức thành kinh nghiệm.") }
        return GiaiDoan(khoa: "advanced", nhan: "Chuyên sâu & Đồ án", mau: Color(hex: 0xA3E635), moTa: "Chuyên ngành hẹp + đồ án tốt nghiệp — làm ra sản phẩm thật, sẵn sàng đi làm.")
    }
}

final class DanhMucNganh {
    static let shared = DanhMucNganh()

    let khoi: [KhoiNganh]
    private let khung: [String: [KyTrongKhung]]
    private let tenMon: [String: String]
    private let ngheNghiep: [String: NgheNghiep]
    let goiYMon: [String: String]
    let maCuThayThe: [String: String]

    private struct Goi: Decodable {
        let khoi: [KhoiNganh]
        let khung: [String: [KyTrongKhung]]
        let tenMon: [String: String]
        let ngheNghiep: [String: NgheNghiep]
        let goiYMon: [String: String]
        let maCuThayThe: [String: String]
    }

    private init() {
        do {
            let g = try JSONDecoder().decode(Goi.self, from: Data(khungNganhJSON.utf8))
            khoi = g.khoi; khung = g.khung; tenMon = g.tenMon
            ngheNghiep = g.ngheNghiep; goiYMon = g.goiYMon; maCuThayThe = g.maCuThayThe
        } catch {
            // Tệp sinh bằng máy — hỏng ở đây là bộ sinh hỏng, phải thấy ngay khi chạy thử.
            assertionFailure("KhungNganh.swift không giải mã được: \(error)")
            khoi = []; khung = [:]; tenMon = [:]; ngheNghiep = [:]; goiYMon = [:]; maCuThayThe = [:]
        }
    }

    func khoi(_ id: String?) -> KhoiNganh? { khoi.first { $0.id == id } }
    func nganh(_ khoiId: String?, _ id: String?) -> Nganh? { khoi(khoiId)?.majors.first { $0.id == id } }
    func nganhHep(_ khoiId: String?, _ nganhId: String?, _ id: String?) -> NganhHep? {
        nganh(khoiId, nganhId)?.combos.first { $0.id == id }
    }

    /// Khối của một ngành. Dùng khi bản ghi trên máy chủ THIẾU `faculty` —
    /// bản sao cũ chỉ lưu `major`. Mã ngành là duy nhất qua mọi khối (bộ sinh đã kiểm).
    func khoiCua(nganh id: String) -> String? {
        khoi.first { $0.majors.contains { $0.id == id } }?.id
    }

    /// Khung 9 kỳ của đúng lựa chọn (đã bỏ ô "môn tự chọn" chưa có mã thật).
    /// Rỗng = không có khung — khối ngoài CNTT mà chưa chọn ngành hẹp.
    func khung(_ khoiId: String?, _ nganhId: String?, _ hepId: String?) -> [KyTrongKhung] {
        guard let khoiId, let nganhId else { return [] }
        return khung["\(khoiId)|\(nganhId)|\(hepId ?? "")"] ?? []
    }

    func tenMon(_ ma: String) -> String? { tenMon[ma.uppercased()] }

    /// Bản chép `careerFor()`: ngành hẹp → ngành → khối → CNTT.
    func ngheNghiep(_ khoiId: String?, _ nganhId: String?, _ hepId: String?) -> NgheNghiep? {
        [hepId, nganhId, khoiId, "it"].compactMap { $0 }.lazy.compactMap { self.ngheNghiep[$0] }.first
    }
}

// MARK: - Lọc môn theo ngành hẹp (bản chép locTheoNganh.ts)

struct MonHien: Identifiable {
    let course: Course
    /// Mã CŨ của cùng một môn — hiện kèm để sinh viên khoá cũ vẫn tìm ra.
    let laMaCu: Bool
    /// Project OJT gợi ý, không nằm trong khung giáo trình.
    let laProject: Bool
    var id: Int { course.id }
}

struct NhomKy: Identifiable {
    let id: Int
    let ten: String
    let moTa: String?
    let mon: [MonHien]
}

enum LocTheoNganh {
    /// Tên chuẩn hoá (phần tiếng Anh trước `|||`) để dò mã CŨ ↔ mã MỚI cùng môn.
    static func tenChuan(_ t: String) -> String {
        let dau = t.components(separatedBy: "|||").first ?? ""
        return String(dau.lowercased().unicodeScalars.filter {
            ("a"..."z").contains($0) || ("0"..."9").contains($0)
        }.map(Character.init))
    }

    static func maCua(_ c: Course) -> String {
        (c.courseCode ?? "").trimmingCharacters(in: .whitespaces).uppercased()
    }

    static func laProject(_ c: Course) -> Bool {
        maCua(c).range(of: #"^INT6\d\d$"#, options: .regularExpression) != nil
    }

    /// Đã chọn tới NGÀNH HẸP chưa — tức có lọc hay không. Khối CNTT chưa chọn
    /// combo VẪN lọc theo khung ngành nền; khối khác thì cần combo.
    static func coLoc(_ h: HoSoNganh) -> Bool {
        let dm = DanhMucNganh.shared
        guard h.isStudent == true, dm.nganh(h.faculty, h.major) != nil else { return false }
        return dm.nganhHep(h.faculty, h.major, h.combo) != nil || h.faculty == "it"
    }

    /// Project chỉ cho SE + combo Node.JS hoặc C#/.NET — đúng loại project web/app/API.
    static func hienProject(_ h: HoSoNganh) -> Bool {
        h.faculty == "it" && h.major == "se" && (h.combo == "react-nodejs" || h.combo == "dotnet")
    }

    private static let idKhung = 10_000
    private static let idProject = 19_999

    /// Xếp môn theo KỲ TRONG KHUNG NGÀNH, không theo ô `semester` của bản ghi.
    /// Một môn chỉ giữ được một kỳ trong DB, còn mỗi ngành xếp một kiểu
    /// (SSG105 là Kỳ 5 với SE nhưng Kỳ 4 với IA) — xếp theo DB thì luôn có ngành sai.
    /// `nil` = không lọc.
    static func xepTheoKhung(_ tatCa: [Course], hoSo h: HoSoNganh) -> [NhomKy]? {
        guard coLoc(h) else { return nil }
        let dm = DanhMucNganh.shared
        let plan = dm.khung(h.faculty, h.major, h.combo)
        guard !plan.isEmpty else { return nil }

        var daXep = Set<Int>()
        var nhom: [NhomKy] = []
        for k in plan {
            let ma = Set(k.ma.map { $0.uppercased() })
            let trongKhung = tatCa.filter { ma.contains(maCua($0)) }
            let tenTrong = Set(trongKhung.map { tenChuan($0.title) }.filter { !$0.isEmpty })
            let maCu = tatCa.filter { c in
                if ma.contains(maCua(c)) { return false }
                if let thay = dm.maCuThayThe[maCua(c)], ma.contains(thay) { return true }
                let t = tenChuan(c.title)
                return !t.isEmpty && tenTrong.contains(t)
            }
            let mon = (trongKhung.map { MonHien(course: $0, laMaCu: false, laProject: laProject($0)) }
                       + maCu.map { MonHien(course: $0, laMaCu: true, laProject: false) })
                .filter { !daXep.contains($0.id) }
            mon.forEach { daXep.insert($0.id) }
            nhom.append(NhomKy(id: idKhung + k.ky,
                               ten: k.ky == 0 ? "Kỳ chuẩn bị" : "Kỳ \(k.ky)",
                               moTa: "Xếp theo khung chương trình của ngành bạn đã chọn",
                               mon: mon))
        }

        if hienProject(h) {
            let pj = tatCa.filter { laProject($0) && !daXep.contains($0.id) }
            if !pj.isEmpty {
                nhom.append(NhomKy(id: idProject, ten: "Project gợi ý",
                                   moTa: "Nằm ngoài khung giáo trình — gợi ý theo combo bạn chọn",
                                   mon: pj.map { MonHien(course: $0, laMaCu: false, laProject: true) }))
            }
        }
        return nhom
    }
}

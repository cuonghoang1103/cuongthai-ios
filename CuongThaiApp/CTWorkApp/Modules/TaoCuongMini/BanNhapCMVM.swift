import Foundation
import SwiftUI

// MARK: - "Create with CuongMini" — trạng thái một bản nháp (như `SetupWizard.tsx` của web)
//
// Luồng: Điền (đề bài, tệp/link, thành viên, hạn) ⇒ CuongMini ĐỌC & tóm tắt (job máy chủ) ⇒ người dùng sửa/trả lời ⇒
// Chấp nhận ⇒ CuongMini LẬP KẾ HOẠCH (job) ⇒ xem & sửa kế hoạch (mô-đun, epic/story, sprint, thành viên) ⇒ Tạo (job) ⇒ Xong.
// Job chạy ở MÁY CHỦ: app hỏi lại mỗi 1,5 s khi `busy` (rời màn rồi quay lại vẫn theo dõi được).
// Lưu tự động 1 s sau lần sửa cuối; trước khi chạy job thì lưu ngay phần dở (job đọc bản trên máy chủ).
// iOS mặc định BẬT "Xem kế hoạch trước khi tạo" (đề bài của chủ app: xem/sửa bản nháp rồi mới tạo).

@MainActor
final class BanNhapCMVM: ObservableObject {
    let id: Int
    let ws: Int
    @Published var nhap: CTWBanNhapCM?
    @Published var loiTai: String?
    @Published var loi: String?
    @Published var dangGui = false
    @Published var luu: TrangThaiLuu = .yen
    /// Bản đang sửa cục bộ (không bị bản máy chủ đè khi người dùng đang gõ).
    @Published var dauVao = CTWDauVaoCM()
    @Published var hieu: CTWJSON?
    @Published var keHoach: CTWJSON?
    /// Ép xem lại phần điền / bản tóm tắt (nút "Sửa đầu vào", "Bản tóm tắt").
    @Published var ep: CheDoCM?

    enum TrangThaiLuu { case yen, dangLuu, daLuu, loi }

    private var ban = (dauVao: false, hieu: false, keHoach: false)
    private var phienBan = 0
    private var henLuu: Task<Void, Never>?
    private var hoiLai: Task<Void, Never>?
    private var trangThaiTruoc: String?

    init(id: Int, ws: Int) { self.id = id; self.ws = ws }


    // MARK: Chế độ hiển thị (như `view` của SetupWizard)

    var cheDo: CheDoCM {
        guard let d = nhap else { return .dien }
        if d.dangChay { return .tienDo }
        if d.status == "APPLIED" { return .xong }
        let hong = d.status == "FAILED" ? d.failedPhase : nil
        if ep == .dien { return .dien }
        if ep == .hieu, hieu != nil { return .hieu }
        if (d.status == "READY" || hong == "APPLYING"), keHoach != nil { return .keHoach }
        if (d.status == "UNDERSTOOD" || hong == "PLANNING" || (d.status == "READY" && keHoach == nil)), hieu != nil { return .hieu }
        return .dien
    }

    var suaDuoc: Bool { guard let d = nhap else { return false }; return !d.dangChay && d.status != "APPLIED" }
    var docDuoc: Bool { dauVao.docDuoc(coNguon: (nhap?.sources ?? []).contains { $0.status == "OK" }) }
    var buoc: Int {
        switch cheDo {
        case .xong: return 3
        case .keHoach: return 2
        case .hieu: return 1
        case .tienDo: return nhap?.status == "APPLYING" ? 2 : (nhap?.status == "PLANNING" ? 1 : 0)
        case .dien: return 0
        }
    }

    // MARK: Tải + hỏi lại khi job chạy

    func tai() async {
        do {
            let d: CTWBanNhapCM = try await APIClient.shared.request(CTWAPI.cmBanNhap(id: id))
            nhan(d)
            loiTai = nil
        } catch {
            if nhap == nil { loiTai = CTW.loi(error) }
        }
    }

    /// Nhận bản máy chủ: đồng bộ phần cục bộ khi đổi PHA (job xong), không đè thứ đang gõ.
    func nhan(_ d: CTWBanNhapCM) {
        let doiPha = trangThaiTruoc != nil && trangThaiTruoc != d.status
        if nhap == nil || (!ban.dauVao && (doiPha || nhap == nil)), let i = d.input { dauVao = i }
        if !ban.hieu, nhap == nil || doiPha || hieu == nil { hieu = d.understanding == .null ? nil : d.understanding }
        if !ban.keHoach, nhap == nil || doiPha || keHoach == nil { keHoach = d.plan == .null ? nil : d.plan }
        if doiPha { ep = nil }
        trangThaiTruoc = d.status
        nhap = d
        theoDoi()
    }

    private func theoDoi() {
        guard nhap?.dangChay == true else { hoiLai?.cancel(); hoiLai = nil; return }
        guard hoiLai == nil else { return }
        hoiLai = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard let self, !Task.isCancelled else { return }
                guard let d: CTWBanNhapCM = try? await APIClient.shared.request(CTWAPI.cmBanNhap(id: self.id)) else { continue }
                self.hoiLai = nil
                self.nhan(d)
                if d.dangChay == false {
                    if d.status == "FAILED" { CTWRung.loi() } else { CTWRung.thanhCong() }
                }
                return
            }
        }
    }

    func dung() { hoiLai?.cancel(); hoiLai = nil; henLuu?.cancel() }

    // MARK: Sửa + lưu tự động

    func suaDauVao(_ f: (inout CTWDauVaoCM) -> Void) {
        f(&dauVao)
        ban.dauVao = true
        henGio()
    }
    func suaHieu(_ f: (inout CTWJSON) -> Void) {
        guard var h = hieu else { return }
        f(&h); hieu = h
        ban.hieu = true
        henGio()
    }
    func suaKeHoach(_ f: (inout CTWJSON) -> Void) {
        guard var k = keHoach else { return }
        f(&k); keHoach = k
        ban.keHoach = true
        henGio()
    }

    private func henGio() {
        phienBan += 1
        let pb = phienBan
        henLuu?.cancel()
        henLuu = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, !Task.isCancelled, self.suaDuoc else { return }
            await self.luuNgay(phienBan: pb)
        }
    }

    /// Lưu phần dở NGAY (trước khi chạy job; job đọc bản trên máy chủ).
    func luuNgay(phienBan pb: Int? = nil) async {
        guard ban.dauVao || ban.hieu || ban.keHoach else { return }
        let gui = ban
        luu = .dangLuu
        do {
            let d: CTWBanNhapCM = try await APIClient.shared.request(CTWAPI.cmSua(
                id: id, dauVao: gui.dauVao ? dauVao : nil, hieu: gui.hieu ? hieu : nil, keHoach: gui.keHoach ? keHoach : nil))
            if pb == nil || pb == phienBan {
                ban = (false, false, false)
                // Kế hoạch đã lưu ⇒ lấy cảnh báo máy chủ tính lại.
                if gui.keHoach, let w = d.plan?["warnings"] { keHoach?["warnings"] = w }
                nhap = d
            }
            luu = .daLuu
        } catch {
            luu = .loi
            loi = CTW.loi(error)
        }
    }

    // MARK: Việc của CuongMini

    func chay(_ ep: @escaping () -> APIEndpoint) async {
        guard !dangGui else { return }
        dangGui = true
        defer { dangGui = false }
        henLuu?.cancel()
        await luuNgay()
        do {
            let d: CTWBanNhapCM = try await APIClient.shared.request(ep())
            self.ep = nil
            nhan(d)
        } catch {
            CTWRung.loi()
            loi = Self.cauLoi(error)
        }
    }

    func doc(docLai: String? = nil) async { await chay { [id] in CTWAPI.cmDoc(id: id, docLai: docLai) } }
    func chapNhan() async {
        let xt = dauVao.reviewFirst ?? true, gm = dauVao.team?.sendInvites ?? false, h = hieu
        await chay { [id] in CTWAPI.cmChapNhan(id: id, hieu: h, xemTruoc: xt, guiMoi: gm) }
    }
    func nhoSua(_ loiDan: String) async { await chay { [id] in CTWAPI.cmNhoSua(id: id, loiDan: loiDan) } }
    func canLai() async {
        await chay { [id] in CTWAPI.cmCanLai(id: id) }
        if let p = nhap?.plan, p != .null { keHoach = p }
    }
    func tao() async { let gm = dauVao.team?.sendInvites ?? false; await chay { [id] in CTWAPI.cmTao(id: id, guiMoi: gm) } }
    func thuLai() async {
        switch nhap?.failedPhase {
        case "READING": await doc()
        case "PLANNING": await chapNhan()
        default: await tao()
        }
    }
    func huy() async {
        do {
            let d: CTWBanNhapCM = try await APIClient.shared.request(CTWAPI.cmHuy(id: id))
            nhan(d)
        } catch { loi = Self.cauLoi(error) }
    }

    // MARK: Nguồn: link, tệp, danh sách thành viên

    func themLink(_ url: String, loai: String = "BRIEF") async -> Bool {
        await luuNgay()
        do {
            let r: CTWThemNguonCM = try await APIClient.shared.request(CTWAPI.cmThemLink(id: id, url: url, loai: loai))
            if let d = r.draft { nhap = d; if !ban.dauVao, let i = d.input { dauVao = i } }
            return true
        } catch { loi = Self.cauLoi(error); return false }
    }

    func themTep(_ url: URL, loai: String = "BRIEF") async {
        await luuNgay()
        dangGui = true
        defer { dangGui = false }
        do {
            let r = try await TaiTepCM.gui(id: id, tep: url, loai: loai)
            if let d = r.draft { nhap = d; if !ban.dauVao, let i = d.input { dauVao = i } }
            if let ds = r.roster?.rows, !ds.isEmpty { suaDauVao { let cu = $0.team?.members ?? []; $0.team?.members = cu + ds } }
            CTWRung.thanhCong()
        } catch { loi = Self.cauLoi(error) }
    }

    func xoaNguon(_ s: CTWNguonCM) async {
        do {
            let d: CTWBanNhapCM = try await APIClient.shared.request(CTWAPI.cmXoaNguon(id: id, sid: s.id))
            nhap = d
        } catch { loi = Self.cauLoi(error) }
    }

    /// Dán danh sách từ Excel/Sheets (cột tab) ⇒ máy chủ đọc tiêu đề Việt/Anh ⇒ thêm vào thành viên.
    func docDanhSach(_ chu: String) async -> Int {
        do {
            let r: CTWDanhSachCM = try await APIClient.shared.request(CTWAPI.cmDanhSach(ws: ws, chu: chu))
            let ds = r.rows ?? []
            if !ds.isEmpty { suaDauVao { let cu = $0.team?.members ?? []; $0.team?.members = cu + ds } }
            return ds.count
        } catch { loi = Self.cauLoi(error); return 0 }
    }

    /// Lỗi cho người dùng — không để lọt câu mời mua/mở khoá của máy chủ (3.1.1).
    nonisolated static func cauLoi(_ e: Error) -> String {
        if case APIError.coMa(let ma, let m) = e {
            switch ma {
            case "WORK_SETUP_KEY_REQUIRED", "WORK_SETUP_SAI_KHOA", "WORK_SETUP_CHUA_BAT":
                return String(localized: "This draft uses a model that isn't available in the app. Open it on the web, or start a new draft here.")
            case "WORK_SETUP_EMPTY": return String(localized: "Add a name, a goal, a brief or a file first.")
            case "WORK_SETUP_BUSY": return String(localized: "CuongMini is still working on this draft — wait a moment or cancel it.")
            case "WORK_SETUP_APPLIED": return String(localized: "This draft was already used to create projects — start a new one.")
            default: return CTW.coLoiMoiMua(m) ? String(localized: "This action isn't available right now.") : CTW.loi(e)
            }
        }
        return CTW.loi(e)
    }
}

enum CheDoCM: Equatable { case dien, hieu, keHoach, tienDo, xong }

// MARK: - Tải tệp lên bản nháp (multipart `file` + `category`) — ≤ 25 MB

enum TaiTepCM {
    static let toiDa = 25 * 1024 * 1024

    static func gui(id: Int, tep: URL, loai: String) async throws -> CTWThemNguonCM {
        let moKhoa = tep.startAccessingSecurityScopedResource()
        defer { if moKhoa { tep.stopAccessingSecurityScopedResource() } }
        let duLieu = try Data(contentsOf: tep)
        guard duLieu.count <= toiDa else {
            throw APIError.coMa(ma: "WORK_FILE_TOO_LARGE", thongDiep: String(localized: "Files must be 25 MB or smaller."))
        }
        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/work/setup-drafts/\(id)/files") else { throw APIError.invalidURL }
        let ranh = "ctw-\(UUID().uuidString)"
        var than = Data()
        func dong(_ s: String) { than.append(Data(s.utf8)) }
        dong("--\(ranh)\r\nContent-Disposition: form-data; name=\"category\"\r\n\r\n\(loai)\r\n")
        let ten = tep.lastPathComponent.replacingOccurrences(of: "\"", with: "")
        dong("--\(ranh)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(ten)\"\r\nContent-Type: \(mime(tep))\r\n\r\n")
        than.append(duLieu)
        dong("\r\n--\(ranh)--\r\n")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        req.setValue("multipart/form-data; boundary=\(ranh)", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = StorageManager.shared.getAuthToken() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (d, resp) = try await URLSession.shared.upload(for: req, from: than)
        let ma = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(ma) else { throw LuongAICTW.loiTuThan(d, trangThai: ma) }
        let goi = try JSONDecoder().decode(APIResponse<CTWThemNguonCM>.self, from: d)
        guard let r = goi.data else { throw APIError.serverError(goi.message ?? "") }
        return r
    }

    static func mime(_ u: URL) -> String {
        switch u.pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "zip": return "application/zip"
        case "csv": return "text/csv"
        case "txt", "md": return "text/plain"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        default: return "application/octet-stream"
        }
    }
}

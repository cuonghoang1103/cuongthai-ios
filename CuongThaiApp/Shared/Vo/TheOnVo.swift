#if os(iOS)
import PencilKit
import SwiftData
import SwiftUI
import UIKit

// MARK: - Thẻ ôn từ trang Vở (23/10/2026)
//
// AI đọc MỘT trang (ảnh trang + chữ Vision đọc trên máy làm gợi ý) rồi rút
// ý chính + câu hỏi tự kiểm + thẻ hai mặt. Người dùng SỬA/BỎ trước khi lưu —
// AI không bao giờ tự ghi thẳng vào lịch ôn.
//
// Thẻ lưu ở MÁY CHỦ (tái dùng `note_vocab_entries` của Notes, kind THE /
// CAU_HOI / Y_CHINH + lịch SM-2) ⇒ ôn được trên mọi máy và thấy được trên web
// (bộ thẻ của trang trong Notes). KHÔNG có bảng SwiftData mới: kho cục bộ không
// đổi, nên không có rủi ro nâng kho làm mất vở.

// MARK: Mô hình (khớp `vo.routes.ts`) — mọi trường `var` + optional (bẫy C4)

struct TrangCuaThe: Decodable, Hashable {
    var id: Int?
    var clientId: String?
    var tieuDe: String?
    var monTen: String?
    var cuonTen: String?
    var previewUrl: String?
}

struct TheOn: Decodable, Identifiable, Hashable {
    var id: Int
    var clientId: String?
    var truoc: String
    var sau: String
    var loai: String?
    var dueAt: String?
    var intervalDays: Int?
    var repetitions: Int?
    var lapses: Int?
    var lanOn: Int?
    var lanCuoi: String?
    var trang: TrangCuaThe?

    var laCauHoi: Bool { loai == "CAU_HOI" }
}

struct YChinhVo: Decodable, Identifiable, Hashable {
    var id: Int
    var noiDung: String
}

struct GoiTheTrang: Decodable {
    var noteId: Int?
    var yChinh: [YChinhVo]?
    var the: [TheOn]?
}

struct GoiTheHomNay: Decodable {
    var the: [TheOn]?
    var conLai: Int?
    var tong: Int?
    var daOnHomNay: Int?
}

struct KetQuaRutThe: Decodable {
    struct CauHoi: Decodable { var hoi: String; var dap: String }
    struct The: Decodable { var truoc: String; var sau: String }
    var xong: Bool?
    var yChinh: [String]?
    var cauHoi: [CauHoi]?
    var the: [The]?
    var model: String?
}

// MARK: Bản nháp người dùng duyệt

struct BanNhapThe: Identifiable, Equatable {
    var id = UUID()
    var truoc: String
    var sau: String
    /// "THE" hoặc "CAU_HOI"
    var loai: String
    var chon = true
}

struct BanNhapY: Identifiable, Equatable {
    var id = UUID()
    var noiDung: String
    var chon = true
}

// MARK: - Gọi máy chủ

@MainActor
enum TheOnVo {
    private struct Viec: Decodable { var viec: String? }

    /// Chữ trang để làm GỢI Ý (Vision trên máy) — dùng lại chữ đã đọc nếu còn
    /// mới, không thì đọc lại ngay (vài trăm ms, không mạng).
    static func chuCuaTrang(_ t: TrangVo) async -> String {
        if let c = t.chuNhanDang, let luc = t.nhanDangLuc, luc >= t.suaLuc { return c }
        let chu = await DocChuViet.doc(net: KhoVo.nap(t.id), khoTrang: t.khoTrang, khoNen: t.khoGoc,
                                       nenPdfTen: t.nenPdfTen, nenPdfTrang: t.nenPdfTrang,
                                       nenAnhTen: t.nenAnhTen)
        t.chuNhanDang = chu.isEmpty ? nil : chu
        t.nhanDangLuc = Date()
        return chu
    }

    /// Ảnh gửi AI: trang có nền tài liệu ⇒ cả trang (nội dung nằm ở nền);
    /// không thì CHỈ nét bút cắt sát (dòng kẻ làm model nhầm gạch chân).
    static func anhCuaTrang(_ t: TrangVo) -> Data? {
        if t.coNenTaiLieu || t.giay.laMauTrang {
            return XuatPdfVo.anhTrang(t, canhMax: 1600)?.jpegData(compressionQuality: 0.8)
        }
        return VietLaiTrang.anhGui(KhoVo.nap(t.id), khoTrang: t.khoTrang)
    }

    static func rut(_ t: TrangVo, tenMon: String, tenCuon: String) async throws -> KetQuaRutThe {
        try await DongYChiaSeAI.batBuoc()
        let goiY = await chuCuaTrang(t)
        let anh = anhCuaTrang(t)
        guard anh != nil || !goiY.isEmpty else {
            throw APIError.coMa(ma: "TRANG_TRONG", thongDiep: T("Trang này chưa có chữ nào để rút thẻ."))
        }
        var than: [String: Any] = [
            "goiY": String(goiY.prefix(6000)),
            "tieuDe": String((t.tieuDe ?? tenCuon).prefix(200)),
            "mon": String(tenMon.prefix(150)),
            "giay": t.loaiGiay,
        ]
        if let anh { than["anh"] = anh.base64EncodedString() }
        let kq: KetQuaRutThe = try await ViecNen.cho(han: 240, gui: {
            let v: Viec = try await APIClient.shared.request(.voMoi(.rutThe(than: than)))
            guard let id = v.viec else {
                throw APIError.coMa(ma: "AI_LOI", thongDiep: T("Máy chủ chưa nhận lượt rút thẻ — thử lại."))
            }
            return id
        }, xem: { id in
            let k: KetQuaRutThe = try await APIClient.shared.request(.voMoi(.xemRutThe(viec: id)))
            return k.xong == true ? k : nil
        })
        return kq
    }

    /// Lưu bản đã duyệt. Trang chưa lên máy chủ ⇒ đồng bộ một lượt trước.
    static func luu(_ t: TrangVo, yChinh: [String], the: [BanNhapThe]) async throws -> GoiTheTrang {
        if t.idMayChu == nil { await DongBoVo.shared.dongBo() }
        guard t.idMayChu != nil else {
            throw APIError.serverError(T("Trang chưa lên máy chủ — kiểm tra mạng / đăng nhập rồi thử lại."))
        }
        let than: [String: Any] = [
            "trangClientId": t.id.uuidString,
            "yChinh": yChinh,
            "the": the.map { ["clientId": $0.id.uuidString, "truoc": String($0.truoc.prefix(500)),
                              "sau": String($0.sau.prefix(4000)), "loai": $0.loai] },
        ]
        return try await APIClient.shared.request(.voMoi(.luuThe(than: than)))
    }

    static func homNay(gioiHan: Int = 80) async throws -> GoiTheHomNay {
        let iso = ISO8601DateFormatter()
        let cuoiNgay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        let dauNgay = Calendar.current.startOfDay(for: Date())
        return try await APIClient.shared.request(.voMoi(.theHomNay(gioiHan: gioiHan, den: iso.string(from: cuoiNgay),
                                                                    tuNgay: iso.string(from: dauNgay))))
    }

    static func cham(_ id: Int, _ muc: MucNhoThe) async throws -> TheOn {
        try await APIClient.shared.request(.voMoi(.chamThe(id: id, muc: muc.rawValue)))
    }

    static func cauLoi(_ e: Error) -> String {
        if let u = e as? URLError, u.code == .timedOut {
            return T("Chờ quá lâu mà AI chưa xong. Thử lại sau ít phút.")
        }
        if case APIError.serverError(let m) = e, m.contains("404") || m.lowercased().contains("not found") {
            return T("Máy chủ chưa có tính năng này — sắp có.")
        }
        return (e as? LocalizedError)?.errorDescription ?? e.localizedDescription
    }
}

/// Bốn mức nhớ — khớp `muc` của `POST /vo/on-the/:id/cham`.
enum MucNhoThe: String, CaseIterable, Identifiable {
    case lai, kho, tot, de
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .lai: return T("Quên")
        case .kho: return T("Khó")
        case .tot: return T("Nhớ")
        case .de: return T("Dễ")
        }
    }
    var mau: Color {
        switch self {
        case .lai: return AppColors.error
        case .kho: return AppColors.warning
        case .tot: return AppColors.success
        case .de: return AppColors.primary
        }
    }
    var q: Int {
        switch self { case .lai: return 1; case .kho: return 3; case .tot: return 4; case .de: return 5 }
    }

    /// Ước khoảng ôn kế tiếp — CÙNG công thức SM-2 với máy chủ
    /// (`src/services/srs/sm2.ts`), chỉ để hiện nhãn "1 ngày / 6 ngày".
    func khoangToi(_ t: TheOn) -> Int {
        let rep = t.repetitions ?? 0, iv = t.intervalDays ?? 0
        if q < 3 { return 1 }
        if rep == 0 { return 1 }
        if rep == 1 { return 6 }
        // ease không trả về; 2,5 là mặc định — đủ cho một nhãn ước lượng.
        return max(1, Int((Double(iv) * 2.5).rounded()))
    }
}

// MARK: - Cửa sổ "Rút thẻ ôn từ trang"

struct RutTheView: View {
    let trang: TrangVo
    let tenMon: String
    let tenCuon: String
    var xong: (Int) -> Void = { _ in }

    @Environment(\.dismiss) private var dong
    @State private var buoc: Buoc = .dangDoc
    @State private var yChinh: [BanNhapY] = []
    @State private var the: [BanNhapThe] = []
    @State private var dangLuu = false
    @State private var loiLuu: String?
    @State private var daCo = 0

    enum Buoc: Equatable { case dangDoc, loi(String), duyet }

    private var soLuu: Int { the.filter { $0.chon && !$0.truoc.trimmingCharacters(in: .whitespaces).isEmpty }.count }

    var body: some View {
        NavigationStack {
            Group {
                switch buoc {
                case .dangDoc: dangDoc
                case .loi(let m): manLoi(m)
                case .duyet: duyet
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Rút thẻ ôn"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                if buoc == .duyet {
                    ToolbarItem(placement: .confirmationAction) {
                        if dangLuu { ProgressView() } else {
                            Button(String(format: T("Lưu %d thẻ"), soLuu)) { Task { await luu() } }
                                .fontWeight(.semibold)
                                .disabled(soLuu == 0 && yChinh.allSatisfy { !$0.chon })
                        }
                    }
                }
            }
        }
        .task { if buoc == .dangDoc && the.isEmpty { await chay() } }
    }

    // MARK: Các bước

    private var dangDoc: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle().fill(AppColors.primary.opacity(0.1)).frame(width: 96, height: 96)
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                    .symbolEffect(.pulse)
            }
            Text(T("AI đang đọc trang và soạn thẻ…"))
                .font(Font.titleSmall).foregroundStyle(AppColors.textPrimary)
            Text(T("Chỉ dựa vào chữ trên trang này — 15–60 giây. Bạn sẽ được sửa hoặc bỏ từng thẻ trước khi lưu."))
                .font(Font.bodyMedium).foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            ProgressView().padding(.top, Spacing.sm)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func manLoi(_ m: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(AppColors.warning)
            Text(m).font(Font.bodyMedium).foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            HStack(spacing: Spacing.md) {
                Button(T("Thử lại")) { buoc = .dangDoc; Task { await chay() } }.primaryButtonStyle()
                Button(T("Tự soạn thẻ")) { the = [BanNhapThe(truoc: "", sau: "", loai: "THE")]; buoc = .duyet }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: 360)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var duyet: some View {
        List {
            Section {
                HStack(spacing: Spacing.md) {
                    if let a = KhoVo.anhNho(trang.id) {
                        Image(uiImage: a).resizable().scaledToFit()
                            .frame(width: 54, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(AppColors.border))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trang.tieuDe ?? tenCuon).font(.system(size: 15, weight: .semibold))
                        Text("\(tenMon) · \(tenCuon)").font(.system(size: 12)).foregroundStyle(AppColors.textTertiary)
                        Text(T("AI có thể đọc nhầm chữ viết tay — sửa hoặc bỏ thẻ sai trước khi lưu."))
                            .font(.system(size: 12)).foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if !yChinh.isEmpty {
                Section {
                    ForEach($yChinh) { $y in
                        HStack(alignment: .top, spacing: 10) {
                            nutChon($y.chon)
                            TextField(T("Ý chính"), text: $y.noiDung, axis: .vertical)
                                .font(.system(size: 15))
                                .opacity(y.chon ? 1 : 0.45)
                        }
                    }
                    .onDelete { yChinh.remove(atOffsets: $0) }
                } header: {
                    Label(T("Ý chính của trang"), systemImage: "lightbulb")
                } footer: {
                    Text(T("Hiện trong phần thẻ của trang (cả trên web) — không đưa vào lịch ôn."))
                }
            }

            nhomThe(T("Câu hỏi tự kiểm"), "questionmark.bubble", loai: "CAU_HOI",
                    truoc: T("Câu hỏi"), sau: T("Gợi ý trả lời"))
            nhomThe(T("Thẻ ôn hai mặt"), "rectangle.on.rectangle.angled", loai: "THE",
                    truoc: T("Mặt trước"), sau: T("Mặt sau"))

            if let loiLuu {
                Section { Text(loiLuu).font(.system(size: 13)).foregroundStyle(AppColors.error) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func nhomThe(_ ten: String, _ bieuTuong: String, loai: String, truoc: String, sau: String) -> some View {
        Section {
            ForEach($the) { $t in
                if t.loai == loai {
                    HStack(alignment: .top, spacing: 10) {
                        nutChon($t.chon)
                        VStack(alignment: .leading, spacing: 6) {
                            TextField(truoc, text: $t.truoc, axis: .vertical)
                                .font(.system(size: 15, weight: .semibold))
                            Divider()
                            TextField(sau, text: $t.sau, axis: .vertical)
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .opacity(t.chon ? 1 : 0.45)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { idx in
                let ids = the.filter { $0.loai == loai }.enumerated().filter { idx.contains($0.offset) }.map(\.element.id)
                the.removeAll { ids.contains($0.id) }
            }
            Button {
                the.append(BanNhapThe(truoc: "", sau: "", loai: loai))
            } label: {
                Label(loai == "THE" ? T("Thêm thẻ") : T("Thêm câu hỏi"), systemImage: "plus.circle")
            }
        } header: {
            Label("\(ten) · \(the.filter { $0.loai == loai && $0.chon }.count)", systemImage: bieuTuong)
        }
    }

    private func nutChon(_ b: Binding<Bool>) -> some View {
        Button { b.wrappedValue.toggle(); Haptics.cham() } label: {
            Image(systemName: b.wrappedValue ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 21))
                .foregroundStyle(b.wrappedValue ? AppColors.primary : AppColors.textTertiary)
        }
        .buttonStyle(.plain)
        .padding(.top, 1)
    }

    // MARK: Việc

    private func chay() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CT_RUTTHE"] == "mau" { nhan(Self.ketQuaMau); return }
        #endif
        do {
            nhan(try await TheOnVo.rut(trang, tenMon: tenMon, tenCuon: tenCuon))
        } catch {
            buoc = .loi(TheOnVo.cauLoi(error))
        }
    }

    private func nhan(_ kq: KetQuaRutThe) {
        yChinh = (kq.yChinh ?? []).map { BanNhapY(noiDung: $0) }
        the = (kq.cauHoi ?? []).map { BanNhapThe(truoc: $0.hoi, sau: $0.dap, loai: "CAU_HOI") }
            + (kq.the ?? []).map { BanNhapThe(truoc: $0.truoc, sau: $0.sau, loai: "THE") }
        if yChinh.isEmpty && the.isEmpty {
            buoc = .loi(T("AI không rút được ý nào từ trang này — trang có thể chỉ có hình vẽ."))
        } else {
            buoc = .duyet
        }
    }

    private func luu() async {
        dangLuu = true; loiLuu = nil
        defer { dangLuu = false }
        let ds = the.filter { $0.chon }
            .map { BanNhapThe(id: $0.id, truoc: $0.truoc.trimmingCharacters(in: .whitespacesAndNewlines),
                              sau: $0.sau.trimmingCharacters(in: .whitespacesAndNewlines), loai: $0.loai) }
            .filter { !$0.truoc.isEmpty }
        let y = yChinh.filter(\.chon).map { $0.noiDung.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        do {
            _ = try await TheOnVo.luu(trang, yChinh: y, the: ds)
            Haptics.xong()
            xong(ds.count)
            dong()
        } catch {
            loiLuu = TheOnVo.cauLoi(error)
        }
    }

    #if DEBUG
    static let ketQuaMau = KetQuaRutThe(
        xong: true,
        yChinh: ["Kiểm thử hộp đen dựa vào ĐẶC TẢ, không nhìn mã nguồn.",
                 "Phân vùng tương đương: chia miền đầu vào thành các lớp xử lý giống nhau, mỗi lớp lấy 1 giá trị.",
                 "Phân tích giá trị biên: lỗi hay nằm ở mép — thử min, min+1, max−1, max."],
        cauHoi: [.init(hoi: "Vì sao chỉ cần 1 giá trị cho mỗi phân vùng tương đương?",
                       dap: "Mọi giá trị trong cùng lớp được hệ thống xử lý như nhau ⇒ một giá trị đại diện là đủ."),
                 .init(hoi: "So sánh hộp đen và hộp trắng?", dap: "Hộp đen: theo đặc tả. Hộp trắng: theo cấu trúc mã (nhánh, đường đi).")],
        the: [.init(truoc: "Equivalence Partitioning", sau: "Chia đầu vào thành các lớp tương đương; thử một giá trị mỗi lớp."),
              .init(truoc: "Boundary Value Analysis", sau: "Thử giá trị ở biên: min, min+1, max−1, max."),
              .init(truoc: "Tuổi hợp lệ 18–60: các giá trị biên?", sau: "17, 18, 19 · 59, 60, 61")],
        model: "mau")
    #endif
}

// MARK: - Màn "Ôn thẻ hôm nay"

struct OnTheHomNayView: View {
    @Environment(\.modelContext) private var kho
    @State private var ds: [TheOn] = []
    @State private var tong = 0
    @State private var daOn = 0
    @State private var conLai = 0
    @State private var dangTai = true
    @State private var loi: String?
    @State private var lat = false
    @State private var dangCham = false
    @State private var moTrang: MoTrangVo?
    var khiDoiSo: (Int) -> Void = { _ in }

    private var the: TheOn? { ds.first }

    /// Màn đọc/viết tập trung ⇒ chủ đề mùa đứng yên khi màn này hiện (Shared/ChuDe).
    var body: some View { thanManYen.nenMuaYen() }

    @ViewBuilder private var thanManYen: some View {
        Group {
            if dangTai && ds.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loi, ds.isEmpty {
                trong(icon: "wifi.exclamationmark", tieuDe: T("Chưa tải được thẻ"), cau: loi, thuLai: true)
            } else if let the {
                manOn(the)
            } else if tong == 0 {
                trong(icon: "rectangle.stack.badge.plus", tieuDe: T("Chưa có thẻ ôn nào"),
                      cau: T("Mở một trang vở → menu ⋯ → “Rút thẻ ôn từ trang này”. AI soạn ý chính, câu hỏi tự kiểm và thẻ hai mặt; bạn duyệt rồi lưu — thẻ tự vào lịch ôn mỗi ngày."),
                      thuLai: false)
            } else {
                trong(icon: "checkmark.seal.fill", tieuDe: T("Xong thẻ hôm nay 🎉"),
                      cau: String(format: T("Đã ôn %d thẻ. %d thẻ còn lại sẽ quay lại đúng ngày cần nhớ."), daOn, max(0, tong - daOn)),
                      thuLai: false)
            }
        }
        .background(AppColors.backgroundPrimary)
        .task { await nap() }
        .refreshable { await nap() }
        .fullScreenCover(item: $moTrang) { m in ManVietView(cuon: m.cuon, moTrang: m.trangId) }
    }

    private func manOn(_ t: TheOn) -> some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                Label(String(format: T("Còn %d thẻ"), conLai), systemImage: "rectangle.stack")
                Spacer()
                Label(String(format: T("Đã ôn hôm nay: %d"), daOn), systemImage: "checkmark.circle")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: 680)

            ProgressView(value: Double(daOn), total: Double(max(1, daOn + conLai)))
                .tint(AppColors.secondary)
                .frame(maxWidth: 680)

            matThe(t)
                .frame(maxWidth: 680)
                .onTapGesture { withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { lat.toggle() } }

            if lat {
                HStack(spacing: Spacing.sm) {
                    ForEach(MucNhoThe.allCases) { m in
                        Button { Task { await cham(t, m) } } label: {
                            VStack(spacing: 3) {
                                Text(m.ten).font(.system(size: 16, weight: .bold))
                                Text(nhanKhoang(m.khoangToi(t))).font(.system(size: 11.5).monospacedDigit()).opacity(0.85)
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .foregroundStyle(.white)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(m.mau))
                        }
                        .buttonStyle(.plain)
                        .disabled(dangCham)
                    }
                }
                .frame(maxWidth: 680)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button { withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { lat = true } } label: {
                    Label(T("Lật thẻ"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: 320, minHeight: 50)
                }
                .primaryButtonStyle()
                .frame(maxWidth: 320)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func matThe(_ t: TheOn) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 8) {
                Text(t.laCauHoi ? T("CÂU HỎI TỰ KIỂM") : T("THẺ ÔN"))
                    .font(.system(size: 10.5, weight: .heavy)).kerning(0.8)
                    .foregroundStyle(t.laCauHoi ? AppColors.secondary : AppColors.primary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill((t.laCauHoi ? AppColors.secondary : AppColors.primary).opacity(0.12)))
                Spacer()
                if let tr = t.trang {
                    Button { mo(tr) } label: {
                        Label(nguon(tr), systemImage: "book.pages")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.textTertiary)
                }
            }
            Spacer(minLength: Spacing.md)
            Text(t.truoc)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            if lat {
                Divider().padding(.vertical, Spacing.sm)
                Text(t.sau)
                    .font(.system(size: 19))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            } else {
                Text(T("Chạm để lật"))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: Spacing.md)
        }
        .padding(Spacing.xl)
        .frame(minHeight: 340)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(AppColors.border.opacity(0.7)))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .contentShape(Rectangle())
    }

    private func trong(icon: String, tieuDe: String, cau: String, thuLai: Bool) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon).font(.system(size: 50)).foregroundStyle(AppColors.textTertiary)
            Text(tieuDe).font(Font.titleMedium).foregroundStyle(AppColors.textPrimary)
            Text(cau).font(Font.bodyMedium).foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center).frame(maxWidth: 460)
            if thuLai { Button(T("Thử lại")) { Task { await nap() } }.primaryButtonStyle().frame(maxWidth: 220) }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func nguon(_ tr: TrangCuaThe) -> String {
        [tr.monTen, tr.tieuDe].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func nhanKhoang(_ n: Int) -> String {
        n <= 1 ? T("1 ngày") : String(format: T("%d ngày"), n)
    }

    private func mo(_ tr: TrangCuaThe) {
        guard let s = tr.clientId, let id = UUID(uuidString: s),
              let t = ((try? kho.fetch(FetchDescriptor<TrangVo>(predicate: #Predicate { $0.id == id }))) ?? []).first,
              let c = t.cuon else { return }
        moTrang = MoTrangVo(cuon: c, trangId: t.id)
    }

    private func nap() async {
        dangTai = true
        defer { dangTai = false }
        #if DEBUG
        if ProcessInfo.processInfo.environment["CT_ONTHE"] == "mau" {
            ds = Self.mau; tong = 12; daOn = 3; conLai = ds.count; khiDoiSo(conLai)
            lat = ProcessInfo.processInfo.environment["CT_ONTHE_LAT"] == "1"
            return
        }
        #endif
        do {
            let g = try await TheOnVo.homNay()
            ds = g.the ?? []
            tong = g.tong ?? 0
            daOn = g.daOnHomNay ?? 0
            conLai = g.conLai ?? ds.count
            loi = nil
            lat = false
            khiDoiSo(conLai)
        } catch {
            loi = TheOnVo.cauLoi(error)
        }
    }

    private func cham(_ t: TheOn, _ m: MucNhoThe) async {
        dangCham = true
        defer { dangCham = false }
        #if DEBUG
        let thu = ProcessInfo.processInfo.environment["CT_ONTHE"] == "mau"
        #else
        let thu = false
        #endif
        if !thu {
            do { _ = try await TheOnVo.cham(t.id, m) } catch { loi = TheOnVo.cauLoi(error); return }
        }
        Haptics.cham()
        withAnimation(.easeInOut(duration: 0.25)) {
            lat = false
            ds.removeFirst()
            daOn += 1
            conLai = max(0, conLai - 1)
            // "Quên" ⇒ thẻ quay lại cuối lượt hôm nay (Leitner: về hộp 1).
            if m == .lai { ds.append(t); conLai += 1 }
        }
        khiDoiSo(conLai)
        if ds.isEmpty && !thu { await nap() }
    }

    #if DEBUG
    static let mau: [TheOn] = [
        TheOn(id: 1, truoc: "Boundary Value Analysis", sau: "Thử giá trị ở biên: min, min+1, max−1, max — lỗi hay nằm ở mép miền đầu vào.",
              loai: "THE", repetitions: 1, trang: TrangCuaThe(tieuDe: "Slot 7 · 21/10 · Black-box", monTen: "SWT301 · Software Testing")),
        TheOn(id: 2, truoc: "Vì sao chỉ cần một giá trị cho mỗi phân vùng tương đương?", sau: "Mọi giá trị trong cùng lớp được xử lý như nhau.",
              loai: "CAU_HOI", trang: TrangCuaThe(tieuDe: "Slot 7 · 21/10", monTen: "SWT301 · Software Testing")),
    ]
    #endif
}

/// Mở một trang cụ thể bằng `fullScreenCover(item:)`.
struct MoTrangVo: Identifiable {
    let cuon: CuonVo
    let trangId: UUID
    var id: UUID { trangId }
}

// MARK: - Link chỉ xem một trang

struct ChiaSeLinkTrangView: View {
    let trang: TrangVo
    @Environment(\.dismiss) private var dong
    @State private var duongDan: URL?
    @State private var dangLam = false
    @State private var loi: String?
    @State private var daThuHoi = false

    private struct Linh: Decodable { var token: String?; var duongDan: String? }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Image(systemName: daThuHoi ? "link.badge.plus" : "link")
                    .font(.system(size: 42)).foregroundStyle(AppColors.primary)
                    .padding(.top, Spacing.lg)
                Text(daThuHoi ? T("Đã thu hồi link") : T("Link chỉ xem trang này"))
                    .font(Font.titleSmall)
                Text(T("Ai có link đều xem được ẢNH trang (không sửa được, không thấy các trang khác). Thu hồi bất cứ lúc nào — link cũ hết tác dụng ngay."))
                    .font(Font.bodyMedium).foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 420)
                if let duongDan, !daThuHoi {
                    Text(duongDan.absoluteString)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: 460)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundSecondary))
                    HStack(spacing: Spacing.md) {
                        ShareLink(item: duongDan) { Label(T("Chia sẻ"), systemImage: "square.and.arrow.up") }
                            .buttonStyle(.borderedProminent)
                        Button { UIPasteboard.general.url = duongDan; Haptics.xong() } label: {
                            Label(T("Sao chép"), systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        Button(role: .destructive) { Task { await thuHoi() } } label: {
                            Label(T("Thu hồi"), systemImage: "link.badge.minus")
                        }
                        .buttonStyle(.bordered)
                    }
                } else if dangLam {
                    ProgressView()
                } else {
                    Button(T("Tạo link")) { Task { await tao() } }.primaryButtonStyle().frame(maxWidth: 240)
                }
                if let loi { Text(loi).font(.system(size: 13)).foregroundStyle(AppColors.error) }
                Spacer()
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
            .navigationTitle(T("Chia sẻ trang"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(T("Xong")) { dong() } } }
            .task { await tao() }
        }
    }

    private func tao() async {
        dangLam = true; loi = nil; daThuHoi = false
        defer { dangLam = false }
        if trang.idMayChu == nil { await DongBoVo.shared.dongBo() }
        guard let id = trang.idMayChu else { loi = T("Trang chưa lên máy chủ — kiểm tra mạng rồi thử lại."); return }
        do {
            let l: Linh = try await APIClient.shared.request(.voMoi(.taoLinh(noteId: id)))
            if let d = l.duongDan { duongDan = URL(string: APIClient.diaChiGoc + d) }
        } catch { loi = TheOnVo.cauLoi(error) }
    }

    private func thuHoi() async {
        guard let id = trang.idMayChu else { return }
        dangLam = true
        defer { dangLam = false }
        do {
            _ = try await APIClient.shared.send(.voMoi(.thuHoiLinh(noteId: id)))
            daThuHoi = true; duongDan = nil
            Haptics.xong()
        } catch { loi = TheOnVo.cauLoi(error) }
    }
}
#endif

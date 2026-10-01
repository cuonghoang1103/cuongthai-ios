#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// VẼ GIÚP — hai mục mới (29/09/2026): CHỮ HÁN và LUỒNG / SƠ ĐỒ KHỐI
//
// Chữ Hán: gõ 学 / "học" / "gaku" / "nhật bản ngữ" → máy chủ TRA chữ
// (`POST /vo/han/tra`, kèm On/Kun/Hán Việt/nghĩa) → app tải NÉT CHUẨN
// (`/my-language/hanzi-stroke/:char`) → `VeChuHan` dựng ô 田 + nét đúng thứ
// tự + số thứ tự. AI KHÔNG vẽ nét chữ Hán.
//
// Luồng / sơ đồ khối: mô tả → máy chủ trả ĐỒ THỊ (`/vo/so-do/viec`, chạy nền)
// → `SoDoKhoi` tự dàn bố cục và viết chữ bằng phông nét đơn (`PhongNetDon`).
// ════════════════════════════════════════════════════════════════

/// Thông tin một chữ Hán (On/Kun/Hán Việt/nghĩa). `var` + optional — C4.
struct ThongTinHan: Codable, Hashable {
    var chu: String?
    var hanViet: String?
    var on: String?
    var kun: String?
    var nghia: String?
    var soNet: Int?
}

/// Một ứng viên khi tra: một chữ hoặc cả từ (日本語).
struct UngVienHan: Codable, Hashable, Identifiable {
    var chu: String?
    var hanViet: String?
    var nghia: String?
    var doc: String?
    var chiTiet: [ThongTinHan]?
    var id: String { chu ?? "" }
}

enum TraHan {
    private struct KetQua: Decodable {
        var ungVien: [UngVienHan]?
        var model: String?
    }

    static func tra(_ q: String) async throws -> [UngVienHan] {
        let kq: KetQua = try await APIClient.shared.request(.voHanTra(q: q))
        return (kq.ungVien ?? []).filter { !($0.chu ?? "").isEmpty }
    }

    /// Chuỗi gõ vào chỉ gồm chữ Hán / kana (bỏ dấu cách) ⇒ vẽ ngay, khỏi tra.
    static func laChuVeDuoc(_ s: String) -> Bool {
        let g = s.filter { !$0.isWhitespace }
        guard !g.isEmpty else { return false }
        return g.unicodeScalars.allSatisfy { u in
            (0x4E00...0x9FFF).contains(u.value) || (0x3400...0x4DBF).contains(u.value)
                || (0x3040...0x30FF).contains(u.value) || (0xF900...0xFAFF).contains(u.value)
                || u.value == 0x3005 || (0x20000...0x2FFFF).contains(u.value)
        }
    }

    static func laKana(_ c: Character) -> Bool {
        c.unicodeScalars.allSatisfy { (0x3040...0x30FF).contains($0.value) }
    }
}

enum TaiSoDo {
    private struct Viec: Decodable { var viec: String? }

    static func dung(_ de: String) async throws -> (HinhVeAI, DoThiKhoi) {
        let g: DoThiKhoi = try await ViecNen.cho(han: 150, gui: {
            let v: Viec = try await APIClient.shared.request(.voSoDoViec(de: de))
            guard let id = v.viec else {
                throw APIError.coMa(ma: "SO_DO_RONG", thongDiep: T("Máy chủ chưa nhận lượt dựng — thử lại."))
            }
            return id
        }, xem: { id in
            let k: DoThiKhoi = try await APIClient.shared.request(.voSoDoXem(viec: id))
            return k.xong == true ? k : nil
        })
        guard let b = SoDoKhoi.dung(g) else {
            throw APIError.coMa(ma: "SO_DO_RONG", thongDiep: T("AI chưa dựng được sơ đồ này — thử mô tả rõ các khối và luồng đi."))
        }
        return (HinhVeAI(b), g)
    }
}

/// Vẽ giúp → ⚡ Mạch điện: gửi mô tả nối dây, hỏi lại tới khi xong, dựng hình.
enum TaiMach {
    private struct Viec: Decodable { var viec: String? }

    static func dung(_ de: String) async throws -> (HinhVeAI, MachDien) {
        let m: MachDien = try await ViecNen.cho(han: 180, gui: {
            let v: Viec = try await APIClient.shared.request(.voMachViec(de: de))
            guard let id = v.viec else {
                throw APIError.coMa(ma: "MACH_RONG", thongDiep: T("Máy chủ chưa nhận lượt dựng — thử lại."))
            }
            return id
        }, xem: { id in
            let k: MachDien = try await APIClient.shared.request(.voMachXem(viec: id))
            return k.xong == true ? k : nil
        })
        guard let b = SoDoMach.dung(m) else {
            throw APIError.coMa(ma: "MACH_RONG", thongDiep: T("AI chưa tách được sơ đồ này — kể rõ các module và từng chân nối vào đâu."))
        }
        return (HinhVeAI(b), m)
    }
}

// MARK: - Thẻ chọn ứng viên

struct DanhSachUngVienHan: View {
    let ds: [UngVienHan]
    let chon: (UngVienHan) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(T("Bạn muốn vẽ chữ nào?"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Text(T("Có nhiều chữ khớp — chữ thông dụng nhất đứng đầu."))
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
        }
        ForEach(ds) { u in
            Button { chon(u) } label: {
                HStack(spacing: 14) {
                    Text(u.chu ?? "")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(minWidth: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if let hv = u.hanViet {
                                Text(hv).font(.subheadline.weight(.bold)).foregroundStyle(AppColors.primary)
                            }
                            if let d = u.doc { Text(d).font(.footnote).foregroundStyle(AppColors.textSecondary) }
                        }
                        if let n = u.nghia {
                            Text(n).font(.footnote).foregroundStyle(AppColors.textPrimary).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.backgroundCard.opacity(0.85)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Thẻ thông tin chữ

struct TheThongTinHan: View {
    let u: UngVienHan
    /// Số nét đếm từ dữ liệu nét (đúng hơn số AI nói).
    let soNet: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if (u.chu ?? "").count > 1, u.nghia != nil || u.doc != nil {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(u.chu ?? "").font(.title3.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
                    if let d = u.doc { Text(d).font(.subheadline).foregroundStyle(AppColors.textSecondary) }
                    if let hv = u.hanViet { Text(hv).font(.caption.weight(.bold)).foregroundStyle(AppColors.primary) }
                }
                if let n = u.nghia { Text(n).font(.footnote).foregroundStyle(AppColors.textPrimary) }
                Divider()
            }
            ForEach(Array((u.chiTiet ?? []).enumerated()), id: \.offset) { _, c in
                HStack(alignment: .top, spacing: 12) {
                    Text(c.chu ?? "")
                        .font(.system(size: 36))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.primary.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            if let hv = c.hanViet {
                                Text(hv).font(.subheadline.weight(.bold)).foregroundStyle(AppColors.primary)
                            }
                            if let n = (c.chu.flatMap { soNet[$0] }) ?? c.soNet {
                                Text("\(n) \(T("nét"))")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .background(Capsule().fill(AppColors.textPrimary.opacity(0.07)))
                            }
                        }
                        dong("On", c.on)
                        dong("Kun", c.kun)
                        if let n = c.nghia {
                            Text(n).font(.footnote).foregroundStyle(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColors.backgroundCard.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppColors.border, lineWidth: 1))
    }

    @ViewBuilder
    private func dong(_ nhan: String, _ gt: String?) -> some View {
        if let gt, !gt.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(nhan)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(width: 26, alignment: .leading)
                Text(gt).font(.footnote).foregroundStyle(AppColors.textPrimary)
            }
        }
    }
}

// MARK: - Tuỳ chọn vẽ chữ Hán

struct TuyChonVeHan: View {
    @ObservedObject var may: MayVe

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(T("Cỡ chữ"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Picker(T("Cỡ chữ"), selection: $may.coHan) {
                    Text(T("Nhỏ")).tag(VeChuHan.Co.nho)
                    Text(T("Vừa")).tag(VeChuHan.Co.vua)
                    Text(T("Lớn")).tag(VeChuHan.Co.lon)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            Toggle(isOn: $may.soThuTuNet) {
                Label(T("Số thứ tự nét"), systemImage: "list.number")
                    .font(.subheadline).foregroundStyle(AppColors.textPrimary)
            }
            Toggle(isOn: $may.oDien) {
                Label(T("Ô 田 tập viết (mờ)"), systemImage: "squareshape.split.2x2.dotted")
                    .font(.subheadline).foregroundStyle(AppColors.textPrimary)
            }
        }
        .tint(AppColors.primary)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColors.textPrimary.opacity(0.04)))
    }
}

// MARK: - Dữ liệu mẫu (DEBUG, bàn thử không cần mạng)

#if DEBUG
enum MauVeMoi {
    /// Đường tim thật (hanzi-writer-data qua `data/hanzi-graphics-ja.txt.gz`).
    static let medians: [String: [[[Double]]]] = {
        let json = #"{"学":[[[295,727],[366,662],[384,615]],[[445,786],[523,675]],[[681,819],[716,767],[590,641]],[[210,576],[220,527],[162,381]],[[244,541],[791,593],[849,526],[732,471]],[[328,431],[385,418],[551,470],[599,465],[626,430],[516,327]],[[490,326],[538,211],[526,49],[487,11],[398,69]],[[163,252],[227,233],[814,297],[906,273]]],"日":[[[279,689],[319,651],[329,603],[305,66]],[[348,652],[634,703],[695,665],[693,24]],[[347,407],[586,431]],[[329,115],[647,139]]],"本":[[[205,576],[275,563],[698,630],[798,623]],[[439,827],[509,768],[486,-63]],[[472,581],[457,514],[345,351],[216,220],[74,115]],[[526,536],[791,240],[995,199]],[[311,180],[655,199]]],"語":[[[277,832],[363,775],[382,720]],[[59,579],[134,571],[446,622]],[[191,474],[373,501]],[[202,386],[372,399]],[[133,269],[170,238],[210,40]],[[184,261],[321,293],[353,277],[367,255],[334,154]],[[213,125],[376,143]],[[508,708],[849,754]],[[605,684],[643,645],[563,380]],[[493,526],[716,568],[764,558],[787,533],[715,401]],[[400,360],[902,405],[991,393]],[[483,262],[521,228],[565,11]],[[538,247],[750,277],[797,263],[824,225],[757,107]],[[565,71],[765,97],[821,83]]]}"#
        return (try? JSONDecoder().decode([String: [[[Double]]]].self, from: Data(json.utf8))) ?? [:]
    }()

    static func netChu(_ c: String) -> NetChu? {
        guard let m = medians[c] else { return nil }
        return NetChu(character: c, strokes: Array(repeating: "M0,0Z", count: m.count), medians: m)
    }

    static let hoc = UngVienHan(chu: "学", hanViet: "HỌC", nghia: "học, việc học", doc: nil,
                                chiTiet: [ThongTinHan(chu: "学", hanViet: "HỌC", on: "ガク", kun: "まな.ぶ", nghia: "học, việc học")])
    static let nhatBanNgu = UngVienHan(chu: "日本語", hanViet: "NHẬT BẢN NGỮ", nghia: "tiếng Nhật", doc: "にほんご", chiTiet: [
        ThongTinHan(chu: "日", hanViet: "NHẬT", on: "ニチ、ジツ", kun: "ひ、か", nghia: "mặt trời, ngày"),
        ThongTinHan(chu: "本", hanViet: "BẢN", on: "ホン", kun: "もと", nghia: "gốc, sách"),
        ThongTinHan(chu: "語", hanViet: "NGỮ", on: "ゴ", kun: "かた.る", nghia: "ngôn ngữ, lời nói"),
    ])
    static let gaku: [UngVienHan] = [
        hoc,
        UngVienHan(chu: "楽", hanViet: "LẠC, NHẠC", nghia: "âm nhạc; vui vẻ", doc: nil, chiTiet: nil),
        UngVienHan(chu: "額", hanViet: "NGẠCH", nghia: "số tiền; trán; khung tranh", doc: nil, chiTiet: nil),
        UngVienHan(chu: "岳", hanViet: "NHẠC", nghia: "núi cao", doc: nil, chiTiet: nil),
    ]

    /// Sơ đồ MVC có nhiều chữ tiếng Việt nhiều dấu.
    /// Kết quả THẬT của máy chủ (gpt-6-sol, 01/10/2026) cho đề nối mic + ampli
    /// + loa của robot Odin — đúng ca làm lộ lỗi của chế độ "Sơ đồ học tập".
    /// `##"…"##` chứ không `#"…"#`: mã màu `"#C99A06"` chứa đúng chuỗi đóng `"#`.
    static let machMicLoa: MachDien = {
        let json = ##"{"tieuDe":"Nối INMP441 và MAX98357A với ESP32-S3","chinh":"esp","khoi":[{"id":"esp","ten":"ESP32-S3","phu":"trên shield MKE-B01","loai":"mcu","chan":["GPIO 4","GPIO 5","GPIO 6","GPIO 7","GPIO 15","GPIO 16","5V","3V3","GND"]},{"id":"mic","ten":"INMP441","phu":"micro","loai":"cam_bien","chan":["SCK","WS","L/R","SD","VDD","GND"]},{"id":"amp","ten":"MAX98357A","phu":"ampli","loai":"module","chan":["LRC","BCLK","DIN","GAIN","SD","GND","Vin","+","-"]},{"id":"loa","ten":"Loa","phu":"loa tròn","loai":"loa","chan":["+","-"]}],"day":[{"tu":{"khoi":"mic","chan":"SCK"},"toi":{"khoi":"esp","chan":"GPIO 4"},"mau":"#C99A06","tenMau":"vàng"},{"tu":{"khoi":"mic","chan":"WS"},"toi":{"khoi":"esp","chan":"GPIO 5"},"mau":"#16A34A","tenMau":"lục"},{"tu":{"khoi":"mic","chan":"SD"},"toi":{"khoi":"esp","chan":"GPIO 6"},"mau":"#2563EB","tenMau":"lam"},{"tu":{"khoi":"mic","chan":"VDD"},"toi":{"khoi":"esp","chan":"3V3"},"mau":"#DC2626","tenMau":"đỏ"},{"tu":{"khoi":"mic","chan":"GND"},"toi":{"khoi":"esp","chan":"GND"},"mau":"#111827","tenMau":"đen"},{"tu":{"khoi":"mic","chan":"L/R"},"toi":{"khoi":"mic","chan":"GND"},"mau":"#111827","tenMau":"đen","nhan":"BẮT BUỘC, dây ngắn"},{"tu":{"khoi":"amp","chan":"DIN"},"toi":{"khoi":"esp","chan":"GPIO 7"},"mau":"#7C3AED","tenMau":"tím"},{"tu":{"khoi":"amp","chan":"BCLK"},"toi":{"khoi":"esp","chan":"GPIO 15"},"mau":"#6B7280","tenMau":"xám"},{"tu":{"khoi":"amp","chan":"LRC"},"toi":{"khoi":"esp","chan":"GPIO 16"},"mau":"#92400E","tenMau":"nâu"},{"tu":{"khoi":"amp","chan":"Vin"},"toi":{"khoi":"esp","chan":"5V"},"mau":"#EA580C","tenMau":"cam"},{"tu":{"khoi":"amp","chan":"GND"},"toi":{"khoi":"esp","chan":"GND"},"mau":"#111827","tenMau":"đen"},{"tu":{"khoi":"amp","chan":"+"},"toi":{"khoi":"loa","chan":"+"},"mau":"#DB2777","tenMau":"hồng"},{"tu":{"khoi":"amp","chan":"-"},"toi":{"khoi":"loa","chan":"-"},"mau":"#0D9488","tenMau":"xanh ngọc","nhan":"KHÔNG nối GND"}],"deHo":[{"khoi":"amp","chan":"GAIN","nhan":"để hở"},{"khoi":"amp","chan":"SD","nhan":"để hở"}],"linhKien":[{"loai":"tu_hoa","a":{"khoi":"amp","chan":"Vin"},"b":{"khoi":"amp","chan":"GND"},"giaTri":"1000uF","nhan":"nên có"}],"ghiChuChan":[{"khoi":"esp","chan":"3V3","nhan":"khối chân đỏ góc trên bên phải"},{"khoi":"esp","chan":"5V","nhan":"hàng chân màu cam"}],"canhBao":["Micro chỉ dùng 3.3V. Cấp 5V là chết micro.","Chỉ ampli dùng 5V.","Dây - của loa đi thẳng vào loa, không bao giờ nối GND.","Ba dây ampli NGƯỢC thứ tự in trên bo: DIN->7, BCLK->15, LRC->16."]}"##
        return (try? JSONDecoder().decode(MachDien.self, from: Data(json.utf8))) ?? MachDien()
    }()

    static let mvc: DoThiKhoi = {
        typealias N = DoThiKhoi.Nut
        typealias C = DoThiKhoi.Canh
        return DoThiKhoi(tieuDe: "Mô hình MVC", dang: "luong", huong: "TB", nut: [
            N(id: "u", nhan: "Người dùng", loai: "nguoi"),
            N(id: "v", nhan: "Giao diện (View)", loai: "hop", nhom: "app"),
            N(id: "c", nhan: "Bộ điều khiển", loai: "hop", nhom: "app"),
            N(id: "m", nhan: "Mô hình dữ liệu", loai: "hop", nhom: "app"),
            N(id: "db", nhan: "Cơ sở dữ liệu", loai: "csdl"),
        ], nhom: [DoThiKhoi.Nhom(id: "app", nhan: "Ứng dụng web")], canh: [
            C(tu: "u", toi: "v", nhan: "thao tác"),
            C(tu: "v", toi: "c", nhan: "gửi yêu cầu"),
            C(tu: "c", toi: "m", nhan: "xử lý nghiệp vụ"),
            C(tu: "m", toi: "db", nhan: "truy vấn"),
            C(tu: "db", toi: "m", nhan: "kết quả"),
            C(tu: "m", toi: "c", nhan: "trả dữ liệu"),
            C(tu: "c", toi: "v", nhan: "cập nhật"),
            C(tu: "v", toi: "u", nhan: "hiển thị"),
        ])
    }()

    static let jwt: DoThiKhoi = {
        typealias N = DoThiKhoi.Nut
        typealias C = DoThiKhoi.Canh
        return DoThiKhoi(tieuDe: "Đăng nhập JWT", dang: "tuan_tu", huong: "LR", nut: [
            N(id: "cl", nhan: "Trình duyệt", loai: "nguoi"), N(id: "api", nhan: "API", loai: "hop"),
            N(id: "db", nhan: "Cơ sở dữ liệu", loai: "csdl"), N(id: "rd", nhan: "Redis", loai: "csdl"),
        ], canh: [
            C(tu: "cl", toi: "api", nhan: "gửi email + mật khẩu"),
            C(tu: "api", toi: "db", nhan: "tìm người dùng"),
            C(tu: "db", toi: "api", nhan: "băm mật khẩu"),
            C(tu: "api", toi: "api", nhan: "ký JWT"),
            C(tu: "api", toi: "rd", nhan: "lưu refresh token"),
            C(tu: "api", toi: "cl", nhan: "trả JWT"),
        ])
    }()
}
#endif
#endif

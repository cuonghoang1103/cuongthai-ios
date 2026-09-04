import SwiftUI

// ════════════════════════════════════════════════════════════════
// PHÂN LOẠI ĐỀ THI — LOẠI ĐỀ + KỲ THI
//
// Đo thật production 05/09/2026: **800 đề · 23 môn · 5 kỳ học**. Danh sách
// phẳng 800 dòng thì không tìm nổi cái mình cần, nên màn Phòng thi xếp
// Kỳ học → Môn → (Kỳ thi, mới nhất trước), đúng lối Academy đang dùng.
//
// ⚠️ Máy chủ KHÔNG có trường "loại đề" lẫn trường "kỳ thi". Cả hai phải suy
// từ `kind` / `peType` / `code` / `title`. Đã đối chiếu bộ luật dưới đây với
// cả 800 đề trước khi viết ra Swift:
//   FE 573 · PE 112 · PT 43 · ME 41 · Đọc 17 · Nghe 8 · Nói 5 · Quiz 1
// và 0 đề `kind == "PE"` bị rơi nhầm sang loại khác.
// ════════════════════════════════════════════════════════════════

// MARK: - Loại đề

enum LoaiDe: String, CaseIterable, Identifiable {
    case cuoiKy, thucHanh, tienDo, giuaKy, doc, nghe, noi, quiz

    var id: String { rawValue }

    /// Nhãn ngắn trên huy hiệu — giữ đúng tiếng người học quen gọi ở trường
    /// ("FE", "PE", "PT"), chỉ dịch những cái không có tên tắt phổ biến.
    var ma: String {
        switch self {
        case .cuoiKy:   return "FE"
        case .thucHanh: return "PE"
        case .tienDo:   return "PT"
        case .giuaKy:   return "ME"
        case .doc:      return "Đọc"
        case .nghe:     return "Nghe"
        case .noi:      return "Nói"
        case .quiz:     return "Quiz"
        }
    }

    var ten: String {
        switch self {
        case .cuoiKy:   return "Cuối kỳ"
        case .thucHanh: return "Thực hành"
        case .tienDo:   return "Tiến độ"
        case .giuaKy:   return "Giữa kỳ"
        case .doc:      return "Đọc hiểu"
        case .nghe:     return "Nghe"
        case .noi:      return "Nói"
        case .quiz:     return "Quiz"
        }
    }

    var bieuTuong: String {
        switch self {
        case .cuoiKy:   return "graduationcap.fill"
        case .thucHanh: return "hammer.fill"
        case .tienDo:   return "chart.line.uptrend.xyaxis"
        case .giuaKy:   return "flag.fill"
        case .doc:      return "book.fill"
        case .nghe:     return "headphones"
        case .noi:      return "mic.fill"
        case .quiz:     return "bolt.fill"
        }
    }

    /// Mỗi loại một màu riêng, đủ khác nhau để nhận ra bằng ĐUÔI MẮT khi lướt.
    ///
    /// ⚠️ Bản sáng KHÔNG dùng lại đúng mã màu của bản tối: mấy màu neon
    /// (hổ phách, ngọc lam) trên nền trắng thì chữ trắng đọc không nổi. Mỗi
    /// bên một sắc độ riêng, cùng tông.
    var mau: Color {
        switch self {
        case .cuoiKy:   return .theoCheDo(sang: Color(hex: 0x4F46E5), toi: Color(hex: 0x818CF8)) // chàm
        case .thucHanh: return .theoCheDo(sang: Color(hex: 0xB45309), toi: Color(hex: 0xFBBF24)) // hổ phách
        case .tienDo:   return .theoCheDo(sang: Color(hex: 0x047857), toi: Color(hex: 0x34D399)) // ngọc lục
        case .giuaKy:   return .theoCheDo(sang: Color(hex: 0xBE185D), toi: Color(hex: 0xF472B6)) // hồng sen
        case .doc:      return .theoCheDo(sang: Color(hex: 0x0369A1), toi: Color(hex: 0x38BDF8)) // xanh trời
        case .nghe:     return .theoCheDo(sang: Color(hex: 0x0F766E), toi: Color(hex: 0x2DD4BF)) // xanh mòng két
        case .noi:      return .theoCheDo(sang: Color(hex: 0xBE123C), toi: Color(hex: 0xFB7185)) // đỏ hồng
        case .quiz:     return .theoCheDo(sang: Color(hex: 0x475569), toi: Color(hex: 0x94A3B8)) // xám đá
        }
    }

    /// Thứ tự hiện trên thanh lọc: loại đông đề đứng trước.
    var thuTu: Int {
        switch self {
        case .cuoiKy: return 0; case .thucHanh: return 1; case .tienDo: return 2
        case .giuaKy: return 3; case .doc: return 4;      case .nghe: return 5
        case .noi:    return 6; case .quiz: return 7
        }
    }
}

// MARK: - Kỳ thi (Spring 2026, Fall 2023…)

/// Học kỳ mà đề thuộc về — thứ người học dùng để biết đề nào MỚI.
///
/// ⚠️ Đừng nhầm với `DeThi.semester` (Kỳ 1…Kỳ 5): cái đó là kỳ trong CHƯƠNG
/// TRÌNH HỌC (môn nằm ở kỳ mấy), còn cái này là kỳ THI THẬT ngoài đời. Một
/// môn ở "Kỳ 1" vẫn có đề của Spring 2026 lẫn Fall 2022.
struct KyThi: Hashable, Comparable {
    enum Mua: Int, Hashable { case xuan = 1, he = 2, thu = 3, dong = 4

        var ten: String {
            switch self {
            case .xuan: return "Spring"; case .he: return "Summer"
            case .thu:  return "Fall";   case .dong: return "Winter"
            }
        }
    }

    let mua: Mua
    let nam: Int

    var ten: String { "\(mua.ten) \(nam)" }
    /// Mốc so sánh: Fall 2025 mới hơn Summer 2025 mới hơn Spring 2025.
    var moc: Int { nam * 10 + mua.rawValue }

    static func < (a: KyThi, b: KyThi) -> Bool { a.moc < b.moc }

    // ⚠️ Chuỗi thô `#"…"#`: biểu thức đầy dấu chéo, viết kiểu chuỗi thường
    // thì mỗi dấu phải nhân đôi và sai một cái là "invalid escape sequence".
    //
    // `(?!\d)` chặn nuốt nửa số: không có nó thì "SU2024" khớp thành
    // ("SU","20") ⇒ năm 2020, sai hẳn ba năm.
    private static let bieuThuc = try? NSRegularExpression(
        pattern: #"(SPRING|SUMMER|FALL|AUTUMN|WINTER|SP|SU|FA|WI)\s*[-_]?\s*(20\d{2}|\d{2})(?!\d)"#,
        options: .caseInsensitive)

    private static let banDoMua: [String: Mua] = [
        "SPRING": .xuan, "SP": .xuan, "SUMMER": .he, "SU": .he,
        "FALL": .thu, "AUTUMN": .thu, "FA": .thu, "WINTER": .dong, "WI": .dong,
    ]

    /// Rút kỳ thi từ một chuỗi ("… SP26 Retake Exam", "PE7-FALL25-Bl3w").
    /// Không thấy → `nil`, và màn hình xếp những đề đó xuống cuối dưới nhãn
    /// "Không rõ kỳ" chứ KHÔNG đoán bừa một năm.
    static func doc(_ chuoi: String) -> KyThi? {
        guard let re = bieuThuc, !chuoi.isEmpty else { return nil }
        let ns = chuoi as NSString
        for m in re.matches(in: chuoi, range: NSRange(location: 0, length: ns.length)) {
            guard m.numberOfRanges >= 3,
                  let mua = banDoMua[ns.substring(with: m.range(at: 1)).uppercased()]
            else { continue }
            let so = ns.substring(with: m.range(at: 2))
            let nam = so.count == 4 ? (Int(so) ?? 0) : 2000 + (Int(so) ?? 0)
            // Chặn số rác: "FA99" hay một mã sản phẩm ngẫu nhiên không phải kỳ.
            if (2015...2035).contains(nam) { return KyThi(mua: mua, nam: nam) }
        }
        return nil
    }
}

// MARK: - Gắn vào DeThi

extension DeThi {
    /// Loại đề, suy theo THỨ TỰ ƯU TIÊN dưới đây — thứ tự có ý nghĩa:
    /// "Đề 21 — Final Exam Listening" mang cả "final" lẫn "listening", và
    /// nó là bài NGHE chứ không phải một đề cuối kỳ thường.
    var loai: LoaiDe {
        let t = title.lowercased()
        let ma = (code ?? "").uppercased()

        if peType?.uppercased() == "SPEAK" || t.contains("speaking") || ma.hasPrefix("SPEAK") { return .noi }
        if t.contains("listening") { return .nghe }
        if t.contains("reading") || ma.hasPrefix("READ") { return .doc }
        if t.contains("progress test") || ma.hasPrefix("PT") { return .tienDo }
        if t.contains("midterm") || ma.hasPrefix("ME") { return .giuaKy }
        if (kind ?? "").uppercased() == "PE" || t.contains("practical") { return .thucHanh }
        if t.contains("quiz") || ma.hasPrefix("QUIZ") { return .quiz }
        return .cuoiKy
    }

    /// Kỳ thi — tìm trong tên đề trước, không có thì tìm trong mã đề
    /// (`PE7-FALL25-Bl3w` chỉ ghi kỳ ở mã).
    var kyThi: KyThi? { KyThi.doc(title) ?? KyThi.doc(code ?? "") }

    /// Khoá xếp: kỳ mới trước, đề không rõ kỳ xuống CUỐI (moc = -1).
    var mocKy: Int { kyThi?.moc ?? -1 }

    /// Số thứ tự trong mã đề, để xếp theo SỐ chứ không theo chuỗi.
    ///
    /// ⚠️ So chuỗi thì "FE-D11" đứng TRƯỚC "FE-D9" (ký tự '1' < '9'), nên
    /// trong cùng một kỳ thi danh sách hiện Đề 11, Đề 9 — nhìn như xếp bừa.
    /// Lấy CỤM SỐ CUỐI của mã: "FE-D11" → 11, "PE7-FALL25-Bl3w" → 3 (không
    /// hoàn hảo nhưng ổn định), không có số → Int.max để rơi xuống cuối.
    var soDe: Int {
        var cuoi: Int?
        var dang = ""
        for c in (code ?? "") {
            if c.isNumber { dang.append(c) }
            else if !dang.isEmpty { cuoi = Int(dang); dang = "" }
        }
        if !dang.isEmpty { cuoi = Int(dang) }
        return cuoi ?? Int.max
    }

    var maMon: String { course?.courseCode ?? "—" }
    var soKyHoc: Int { semester?.ordinal ?? 99 }
    var tenKyHoc: String { semester?.name ?? "Chưa xếp kỳ" }
}

// MARK: - Mảnh dùng chung cho mọi danh sách đề

/// Một dòng đề — dùng ở CẢ màn Phòng thi lẫn màn Đã lưu.
///
/// ⚠️ Tách ra đây chứ không chép sang hai chỗ: hai bản chép rồi sẽ trôi khỏi
/// nhau, và cái giá là người dùng thấy đề cùng loại mang hai màu khác nhau ở
/// hai màn — đúng thứ "lộn xộn" vừa phải đi sửa.
struct HangDeThi: View {
    let de: DeThi
    let ngonNgu: NgonNguDe
    /// Dòng phụ dưới tên đề. Mặc định là "N câu · M phút".
    var phu: String?

    var body: some View {
        let l = de.loai
        return HStack(spacing: Spacing.sm) {
            // Vạch màu theo loại: lướt nhanh vẫn phân biệt được bằng đuôi mắt.
            RoundedRectangle(cornerRadius: 2).fill(l.mau).frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Label(l.ma, systemImage: l.bieuTuong)
                        .font(.system(size: 10, weight: .bold))
                        .labelStyle(.titleAndIcon)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(l.mau))
                    if let c = de.code {
                        Text(c)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                Text(de.ten(ngonNgu))
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text(phu ?? "\(de.soCau) câu · \(de.phut) phút")
                    .font(.system(size: 11.5)).foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, 10)
        .background(AppColors.backgroundCard)
        .contentShape(Rectangle())
    }
}

/// Dòng ngăn giữa hai kỳ thi ("Spring 2026 ─────").
struct VachKyThi: View {
    let ky: KyThi?
    var nen: Color = AppColors.backgroundPrimary

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(ky?.ten ?? "Không rõ kỳ")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ky == nil ? AppColors.textTertiary : AppColors.textSecondary)
            Rectangle().fill(AppColors.divider).frame(height: 1)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm + 2).padding(.bottom, 2)
        .background(nen)
    }
}

/// Huy hiệu loại + kỳ thi, hàng ngang — dùng ở đầu màn chi tiết và trên thẻ
/// câu đã lưu.
struct NhanLoaiVaKy: View {
    let de: DeThi
    var coChu: CGFloat = 11

    var body: some View {
        HStack(spacing: 5) {
            Label(de.loai.ma, systemImage: de.loai.bieuTuong)
                .font(.system(size: coChu, weight: .bold))
                .labelStyle(.titleAndIcon)
                .foregroundColor(.white)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(de.loai.mau))
            if let c = de.code {
                Text(c)
                    .font(.system(size: coChu - 1, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.textTertiary)
            }
            if let k = de.kyThi {
                Text(k.ten)
                    .font(.system(size: coChu - 1, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

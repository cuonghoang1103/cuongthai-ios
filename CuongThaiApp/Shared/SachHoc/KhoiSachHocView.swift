import SwiftUI
import Charts

// ════════════════════════════════════════════════════════════════
// DỰNG KHỐI — bản native của Blocks.tsx / Blocks2.tsx (web).
// Khối HIỂN THỊ ở tệp này; khối TƯƠNG TÁC (mcq, quiz, build, dictation,
// readkanji) ở KhoiTuongTacSH.swift; chia/hanlop ở ChiaHanSH.swift.
// Mỗi khối là một view nhỏ riêng — để trình biên dịch khỏi nghẹn và để
// SwiftUI chỉ vẽ lại đúng khối đổi.
// ════════════════════════════════════════════════════════════════

/// Màu theo loại bài (kindHue của web), sáng/tối.
func mauLoaiSH(_ khoa: KhoaSH?, _ kind: String) -> Color {
    MauChuSH.mau(hexSH(khoa?.mauLoai[kind])).color
}

/// Khung thẻ dùng chung của các khối.
struct TheKhoiSH: ViewModifier {
    var vien: Color = AppColors.border
    var nen: Color = AppColors.backgroundCard
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(nen))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(vien, lineWidth: 1))
    }
}
extension View {
    func theKhoiSH(vien: Color = AppColors.border, nen: Color = AppColors.backgroundCard) -> some View {
        modifier(TheKhoiSH(vien: vien, nen: nen))
    }
}

// MARK: - Nút loa

struct NutLoaSH: View {
    let text: String
    var giong: String?
    var co: CGFloat = 34
    @ObservedObject private var giongDoc = GiongSachHoc.chung

    private var khoa: String { "loa|\(giong ?? "")|\(text)" }

    var body: some View {
        let dang = giongDoc.dangPhat == khoa
        Button {
            giongDoc.phat(ClipSH(text: text, giong: giong), khoa: khoa)
        } label: {
            ZStack {
                Circle().fill(dang ? AppColors.primary : AppColors.primary.opacity(0.12))
                if dang && giongDoc.dangCho {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: dang ? "stop.fill" : "speaker.wave.2.fill")
                        .font(.system(size: co * 0.42, weight: .semibold))
                        .foregroundColor(dang ? .white : AppColors.primary)
                }
            }
            .frame(width: co, height: co)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dang ? "Dừng" : "Nghe")
    }
}

/// Dòng romaji / pinyin — ẩn theo công tắc "romaji" của người học.
struct DongRoSH: View {
    let ro: String?
    var co: CGFloat = 14
    @AppStorage(CaiDatDocSH.romaji) private var roma = true
    var body: some View {
        if roma, let ro, !ro.isEmpty {
            ChuSH(text: ro, co: co, mau: .mo, nghieng: true)
        }
    }
}

// MARK: - Bộ chia khối

struct KhoiSHView: View {
    let khoi: KhoiSH
    @EnvironmentObject private var vm: SachHocVM

    var body: some View {
        switch khoi {
        case .h(let t): TieuDeSH(text: t)
        case .p(let t): ChuSH(text: t, co: 17).frame(maxWidth: .infinity, alignment: .leading)
        case .note(let title, let items): GhiChuSH(title: title, items: items)
        case .recap(let title, let items): TomTatSH(title: title, items: items)
        case .rule(let f, let vi): CongThucSH(formula: f, vi: vi)
        case .table(let head, let rows, let caption): BangSH(head: head, rows: rows, caption: caption)
        case .examples(let ds): ViDuSH(items: ds)
        case .patterns(let rows): MauCauSH(rows: rows)
        case .vocab(let ds): TuVungSH(items: ds)
        case .dialogue(let title, let lines): HoiThoaiSH(title: title, lines: lines)
        case .listen(let id, let title, let note, let lines, _): BaiNgheSH(id: id, title: title, note: note, lines: lines)
        case .passage(let title, let intro, let paras): BaiDocSH(title: title, intro: intro, paras: paras)
        case .chart(let kieu, let title, let unit, let labels, let series): BieuDoSH(kieu: kieu, title: title, unit: unit, labels: labels, series: series)
        case .alphabet(let groups): BangChuCaiSH(groups: groups)
        default: KhoiTuongTacSHView(khoi: khoi)
        }
    }
}

// MARK: - h, note, recap, rule

struct TieuDeSH: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(AppColors.primary).frame(width: 4).padding(.vertical, 3)
            ChuSH(text: text, co: 20, dam: true)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }
}

struct GhiChuSH: View {
    let title: String
    let items: [String]

    private enum Tone { case warn, tip, info }
    private var tone: Tone {
        let t = title.lowercased()
        if ["sai", "nhầm", "cẩn thận", "lỗi"].contains(where: t.contains) { return .warn }
        if ["mẹo", "cách học", "tip"].contains(where: t.contains) { return .tip }
        return .info
    }
    private var mau: Color {
        switch tone { case .warn: MauChuSH.mau(0xB45309).color; case .tip: MauChuSH.mau(0x047857).color; case .info: MauChuSH.mau(0x1D4ED8).color }
    }
    private var bieuTuong: String {
        switch tone { case .warn: "exclamationmark.triangle.fill"; case .tip: "lightbulb.fill"; case .info: "pin.fill" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                ChuSH(text: title, co: 16, dam: true, mau: .chinh)
            } icon: {
                Image(systemName: bieuTuong).foregroundColor(mau).font(.system(size: 15, weight: .semibold))
            }
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(mau).frame(width: 6, height: 6).offset(y: -3)
                    ChuSH(text: it, co: 16, mau: .chinh)
                }
            }
        }
        .theKhoiSH(vien: mau.opacity(0.4), nen: mau.opacity(0.08))
    }
}

struct TomTatSH: View {
    let title: String?
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🎯 " + (title ?? "Tóm tắt nhanh")).font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.textPrimary)
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(i + 1).").font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundColor(AppColors.primary)
                    ChuSH(text: it, co: 16)
                }
            }
        }
        .theKhoiSH(vien: AppColors.primary.opacity(0.45), nen: AppColors.primary.opacity(0.07))
    }
}

struct CongThucSH: View {
    let formula: String
    let vi: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CÔNG THỨC 1 DÒNG").font(.system(size: 11, weight: .heavy)).kerning(0.6).foregroundColor(AppColors.accent)
            ChuSH(text: formula, co: 18, dam: true)
            if let vi, !vi.isEmpty { ChuSH(text: vi, co: 15, mau: .phu) }
        }
        .theKhoiSH(vien: AppColors.accent.opacity(0.45), nen: AppColors.accent.opacity(0.07))
    }
}

// MARK: - Bảng

struct BangSH: View {
    let head: [String]
    let rows: [[String]]
    let caption: String?

    /// Như web: bảng ≥ 3 cột chữ dài ⇒ mỗi hàng một thẻ (nhãn cột ở đầu ô); bảng ô ngắn ⇒ lưới cuộn ngang.
    private var xepThe: Bool {
        let o = rows.flatMap { $0 }
        let tb = o.reduce(0) { $0 + PhanTichChuSH.tron($1).count } / max(1, o.count)
        return head.count >= 3 && tb > 22
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let caption, !caption.isEmpty { ChuSH(text: caption, co: 14, dam: true, mau: .phu) }
            if xepThe { the } else { luoi }
        }
    }

    private var the: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                VStack(alignment: .leading, spacing: 6) {
                    if let dau = r.first { ChuSH(text: dau, co: 17, dam: true) }
                    ForEach(Array(r.dropFirst().enumerated()), id: \.offset) { j, o in
                        VStack(alignment: .leading, spacing: 1) {
                            if head.indices.contains(j + 1) {
                                Text(PhanTichChuSH.tron(head[j + 1]).uppercased()).font(.system(size: 10.5, weight: .bold)).kerning(0.4).foregroundColor(AppColors.textTertiary)
                            }
                            ChuSH(text: o, co: 16)
                        }
                    }
                }
                .theKhoiSH()
            }
        }
    }

    private var luoi: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                if !head.isEmpty {
                    GridRow {
                        ForEach(Array(head.enumerated()), id: \.offset) { _, h in
                            ChuSH(text: h, co: 14, dam: true, mau: .phu)
                                .frame(minWidth: 70, maxWidth: 300, alignment: .leading)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                        }
                    }
                    .background(AppColors.backgroundTertiary)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    GridRow {
                        ForEach(Array(r.enumerated()), id: \.offset) { j, o in
                            ChuSH(text: o, co: 16, dam: j == 0)
                                .frame(minWidth: 70, maxWidth: 300, alignment: .leading)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                        }
                    }
                    .background(i % 2 == 1 ? AppColors.backgroundTertiary.opacity(0.45) : Color.clear)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .background(AppColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppColors.border, lineWidth: 1))
        }
    }
}

// MARK: - Ví dụ, mẫu câu

struct DongCauSH: View {
    let cau: CauSH
    var co: CGFloat = 20
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            NutLoaSH(text: cau.en).padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                ChuSH(text: cau.en, co: co)
                DongRoSH(ro: cau.ro)
                if !cau.vi.isEmpty { ChuSH(text: cau.vi, co: 15, mau: .phu) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ViDuSH: View {
    let items: [CauSH]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, c in DongCauSH(cau: c) }
        }
        .theKhoiSH()
    }
}

struct MauCauSH: View {
    let rows: [DongMauSH]
    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        ChuSH(text: r.formula, co: 18, dam: true, mau: .nhan)
                        if !r.vi.isEmpty { ChuSH(text: r.vi, co: 14.5, mau: .phu) }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.primary.opacity(0.08)))
                    ForEach(Array(r.examples.enumerated()), id: \.offset) { _, e in DongCauSH(cau: e, co: 19) }
                }
                .theKhoiSH()
            }
        }
    }
}

// MARK: - Từ vựng (có chế độ tự kiểm tra)

struct TuVungSH: View {
    let items: [TuSH]
    @EnvironmentObject private var vm: SachHocVM
    @State private var cheDo = 0          // 0 xem đủ · 1 che nghĩa · 2 che từ
    @State private var daLat: Set<Int> = []

    private var tenTieng: String {
        switch vm.khoa?.ngonNgu { case "ja": "Nhật"; case "zh": "Trung"; default: "Anh" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if items.count >= 4 {
                Picker("Tự kiểm tra", selection: $cheDo) {
                    Text("Xem đủ").tag(0)
                    Text("Che nghĩa").tag(1)
                    Text("Che từ").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: cheDo) { _, _ in daLat = [] }
                if cheDo != 0 {
                    Text(cheDo == 1 ? "Nhìn từ tiếng \(tenTieng), nói to nghĩa rồi chạm ô mờ để kiểm tra · đã lật \(daLat.count)/\(items.count)"
                                    : "Nhìn nghĩa, nói to (hoặc viết ra giấy) từ tiếng \(tenTieng) rồi chạm để kiểm tra · đã lật \(daLat.count)/\(items.count)")
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { k, v in
                    TuMotSH(tu: v, cheNghia: cheDo == 1 && !daLat.contains(k), cheTu: cheDo == 2 && !daLat.contains(k)) {
                        daLat.insert(k)
                    }
                    if k < items.count - 1 { Divider().padding(.leading, 48) }
                }
            }
            .theKhoiSH()
        }
    }
}

private struct TuMotSH: View {
    let tu: TuSH
    let cheNghia: Bool
    let cheTu: Bool
    let lat: () -> Void
    @AppStorage(CaiDatDocSH.romaji) private var roma = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if cheTu { Color.clear.frame(width: 34, height: 34) } else { NutLoaSH(text: tu.w).padding(.top, 2) }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    che(cheTu) { ChuSH(text: tu.w, co: 22, dam: true) }
                    if !tu.pos.isEmpty {
                        Text(tu.pos).font(.system(size: 11.5, weight: .semibold)).foregroundColor(AppColors.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.secondary.opacity(0.12)))
                    }
                }
                if !cheTu, roma, !tu.ipa.isEmpty { Text(tu.ipa).font(.system(size: 14).italic()).foregroundColor(AppColors.textTertiary) }
                che(cheNghia) { ChuSH(text: tu.vi, co: 17, dam: true, mau: .nhan) }
                if !cheTu, !tu.ex.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        NutLoaSH(text: tu.ex, co: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            ChuSH(text: tu.ex, co: 17)
                            DongRoSH(ro: tu.exRo, co: 13)
                            if !cheNghia, !tu.exVi.isEmpty { ChuSH(text: tu.exVi, co: 14.5, mau: .phu) }
                        }
                    }
                    .padding(.top, 2)
                }
                if !cheTu, !cheNghia, let more = tu.more, !more.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("＋").font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.accent)
                        ChuSH(text: more, co: 14.5, mau: .phu)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func che<C: View>(_ on: Bool, @ViewBuilder _ c: () -> C) -> some View {
        if on {
            Button(action: lat) {
                c().opacity(0)
                    .overlay(RoundedRectangle(cornerRadius: 8).fill(AppColors.backgroundTertiary))
                    .overlay(Text("chạm để xem").font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.textTertiary))
            }
            .buttonStyle(.plain)
        } else {
            c()
        }
    }
}

// MARK: - Hội thoại

/// Giọng của một vai — như `useVoiceFor` (Blocks2.tsx): khoá Nhật/Trung ⇒ nam/nữ theo vai, "Cô…" luôn nữ.
func giongVaiSH(_ ngonNgu: String?, role: String, who: String?) -> String {
    let nn = ngonNgu == "ja" ? "ja" : ngonNgu == "zh" ? "zh" : nil
    guard let nn else {
        switch role { case "examiner": return "uk-nam"; case "candidate": return "uk-nu"; case "a": return "us-nu"; case "b": return "us-nam"; default: return "uk-nu" }
    }
    if let who, who.hasPrefix("Cô") || who.hasPrefix("cô") || who.hasPrefix("李老师") { return "\(nn)-nu" }
    return role == "examiner" || role == "b" ? "\(nn)-nam" : "\(nn)-nu"
}

struct HoiThoaiSH: View {
    let title: String?
    let lines: [LoiThoaiSH]
    @EnvironmentObject private var vm: SachHocVM
    @ObservedObject private var giongDoc = GiongSachHoc.chung

    private var khoaCaDoan: String { "hoithoai|" + lines.map(\.text).joined() }

    var body: some View {
        let dangCaDoan = giongDoc.dangPhat == khoaCaDoan
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(PhanTichChuSH.tron(title ?? "Hội thoại mẫu"), systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 8)
                Button {
                    giongDoc.phat(lines.map { ClipSH(text: $0.text, giong: giongVaiSH(vm.khoa?.ngonNgu, role: $0.role, who: $0.who)) }, khoa: khoaCaDoan)
                } label: {
                    Label(dangCaDoan ? "Dừng" : "Nghe cả đoạn", systemImage: dangCaDoan ? "stop.fill" : "play.fill")
                        .font(.system(size: 13.5, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { i, l in
                BongThoaiSH(line: l, sang: dangCaDoan && giongDoc.cauDangDoc == i, giong: giongVaiSH(vm.khoa?.ngonNgu, role: l.role, who: l.who))
            }
        }
        .theKhoiSH()
    }
}

private struct BongThoaiSH: View {
    let line: LoiThoaiSH
    let sang: Bool
    let giong: String
    @ObservedObject private var giongDoc = GiongSachHoc.chung

    private var phai: Bool { line.role == "candidate" || line.role == "b" }
    private var mauVai: Color {
        switch line.role {
        case "examiner": MauChuSH.mau(0x1E3A8A).color
        case "candidate": MauChuSH.mau(0xDB2777).color
        case "a": MauChuSH.mau(0x059669).color
        case "b": MauChuSH.mau(0xEA580C).color
        default: MauChuSH.mau(0x7C3AED).color
        }
    }

    var body: some View {
        let khoa = "cau|\(giong)|\(line.text)"
        let dang = sang || giongDoc.dangPhat == khoa
        HStack(alignment: .top, spacing: 8) {
            if phai { Spacer(minLength: 28) } else { anhDaiDien }
            VStack(alignment: .leading, spacing: 3) {
                ChuSH(text: line.who, co: 12.5, dam: true, mau: .mo)
                Button { giongDoc.phat(ClipSH(text: line.text, giong: giong), khoa: khoa) } label: {
                    ChuSH(text: line.text, co: 19).frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                DongRoSH(ro: line.ro, co: 13)
                if let vi = line.vi, !vi.isEmpty { ChuSH(text: vi, co: 14.5, mau: .phu) }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(dang ? mauVai.opacity(0.16) : AppColors.backgroundTertiary))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(dang ? mauVai : Color.clear, lineWidth: 1.5))
            if phai { anhDaiDien } else { Spacer(minLength: 28) }
        }
    }

    private var anhDaiDien: some View {
        let chu = PhanTichChuSH.tron(line.who).first.map(String.init) ?? "?"
        return Text(chu)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 34, height: 34)
            .background(Circle().fill(mauVai))
    }
}

// MARK: - Bài nghe

struct BaiNgheSH: View {
    let id: String
    let title: String
    let note: String?
    let lines: [LoiNgheSH]
    @EnvironmentObject private var vm: SachHocVM
    @ObservedObject private var giongDoc = GiongSachHoc.chung
    @State private var hienLoi = false
    @State private var soLan = 0

    private var khoa: String { "nghe|\(id)" }

    var body: some View {
        let dang = giongDoc.dangPhat == khoa
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    if !dang { soLan += 1 }
                    giongDoc.phat(lines.map { ClipSH(text: $0.text, giong: $0.voice) }, khoa: khoa)
                } label: {
                    Image(systemName: dang ? "stop.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(AppColors.secondary))
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text("🎧 BÀI NGHE").font(.system(size: 11, weight: .heavy)).kerning(0.6).foregroundColor(AppColors.secondary)
                    ChuSH(text: title, co: 16.5, dam: true)
                    Text((note.map(PhanTichChuSH.tron) ?? "Nghe trước, làm bài bên dưới, rồi mới mở lời thoại để kiểm tra.") + (soLan > 0 ? " · Đã nghe \(soLan) lần" : ""))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            Button { withAnimation(.easeOut(duration: 0.2)) { hienLoi.toggle() } } label: {
                Label(hienLoi ? "Ẩn lời thoại" : "Hiện lời thoại (transcript)", systemImage: hienLoi ? "eye.slash" : "eye")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.primary)
            }
            .buttonStyle(.plain)
            if hienLoi {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, l in
                        HStack(alignment: .top, spacing: 8) {
                            NutLoaSH(text: l.text, giong: l.voice, co: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                if let who = l.who, !who.isEmpty { ChuSH(text: who, co: 12.5, dam: true, mau: .mo) }
                                ChuSH(text: l.text, co: 18)
                                DongRoSH(ro: l.ro, co: 13)
                                if let vi = l.vi, !vi.isEmpty { ChuSH(text: vi, co: 14.5, mau: .phu) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(dang && giongDoc.cauDangDoc == i ? AppColors.secondary.opacity(0.14) : Color.clear))
                    }
                }
            }
        }
        .theKhoiSH(vien: AppColors.secondary.opacity(0.4), nen: AppColors.secondary.opacity(0.06))
    }
}

// MARK: - Bài đọc

struct BaiDocSH: View {
    let title: String
    let intro: String?
    let paras: [DoanSH]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📖 BÀI ĐỌC").font(.system(size: 11, weight: .heavy)).kerning(0.6).foregroundColor(AppColors.accent)
            ChuSH(text: title, co: 19, dam: true)
            if let intro, !intro.isEmpty { ChuSH(text: intro, co: 15, mau: .phu, nghieng: true) }
            ForEach(Array(paras.enumerated()), id: \.offset) { _, p in
                HStack(alignment: .top, spacing: 8) {
                    if let lb = p.label, !lb.isEmpty {
                        Text(lb).font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                            .frame(minWidth: 24, minHeight: 24).padding(.horizontal, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.accent))
                    }
                    ChuSH(text: p.text, co: 18)
                }
            }
        }
        .theKhoiSH()
    }
}

// MARK: - Biểu đồ

struct BieuDoSH: View {
    let kieu: String
    let title: String
    let unit: String?
    let labels: [String]
    let series: [ChuoiSH]

    private struct Diem: Identifiable { let id = UUID(); let nhan: String; let chuoi: String; let gt: Double }
    private var diem: [Diem] {
        series.flatMap { s in s.values.enumerated().compactMap { i, v in labels.indices.contains(i) ? Diem(nhan: labels[i], chuoi: s.name, gt: v) : nil } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChuSH(text: title, co: 16, dam: true)
            if let unit { Text(unit).font(.system(size: 12)).foregroundColor(AppColors.textTertiary) }
            Chart(diem) { d in
                if kieu == "line" {
                    LineMark(x: .value("Mốc", d.nhan), y: .value("Giá trị", d.gt))
                        .foregroundStyle(by: .value("Chuỗi", d.chuoi))
                    PointMark(x: .value("Mốc", d.nhan), y: .value("Giá trị", d.gt))
                        .foregroundStyle(by: .value("Chuỗi", d.chuoi))
                } else {
                    BarMark(x: .value("Mốc", d.nhan), y: .value("Giá trị", d.gt))
                        .foregroundStyle(by: .value("Chuỗi", d.chuoi))
                        .position(by: .value("Chuỗi", d.chuoi))
                }
            }
            .chartXScale(domain: labels)
            .frame(height: 240)
        }
        .theKhoiSH()
    }
}

// MARK: - Bảng chữ cái (kana…)

struct BangChuCaiSH: View {
    let groups: [NhomChuSH]
    @ObservedObject private var giongDoc = GiongSachHoc.chung
    private let cot = [GridItem(.adaptive(minimum: 62, maximum: 90), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                VStack(alignment: .leading, spacing: 6) {
                    Text(g.sound).font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.textSecondary)
                    LazyVGrid(columns: cot, alignment: .leading, spacing: 8) {
                        ForEach(Array(g.letters.enumerated()), id: \.offset) { _, x in o(x) }
                    }
                }
            }
        }
        .theKhoiSH()
    }

    private func o(_ x: ChuCaiSH) -> some View {
        let doc = x.doc ?? x.l
        let khoa = "chu|\(doc)"
        let dang = giongDoc.dangPhat == khoa
        return Button { giongDoc.phat(ClipSH(text: doc), khoa: khoa) } label: {
            VStack(spacing: 2) {
                Text(x.l).font(.system(size: 30, weight: .medium)).foregroundColor(AppColors.textPrimary).minimumScaleFactor(0.5).lineLimit(1)
                Text(x.ipa).font(.system(size: 12.5, weight: .semibold)).foregroundColor(AppColors.textTertiary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(dang ? AppColors.primary.opacity(0.18) : AppColors.primary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(dang ? AppColors.primary : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Nghe chữ \(x.l)")
    }
}

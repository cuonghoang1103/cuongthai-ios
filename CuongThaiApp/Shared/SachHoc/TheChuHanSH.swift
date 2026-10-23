import SwiftUI

// ════════════════════════════════════════════════════════════════
// THẺ CHỮ HÁN — bật lên khi chạm MỘT chữ Hán bất kỳ trong bài (bản native của
// KanjiSheet.tsx): thứ tự nét (KanjiVG — phát, từng nét, số thứ tự), Hán Việt /
// On / Kun / nghĩa / cách nhớ, "Từ đi chung" (từ cô chép + từ vựng mọi bài có
// chữ này, ghi Bài N; chip chữ Hán khác — xanh = đã học), câu ví dụ, ô tập viết.
// Chạm chip chữ khác ⇒ mở thẻ chữ đó, "‹ chữ trước" để quay lại (ngăn xếp ≤ 20).
// Dữ liệu: chu-han.json (han + phần sinh tự động tu/vd/bang/lop) + net.json.
// ════════════════════════════════════════════════════════════════

/// Mở thẻ chữ Hán từ bất cứ đâu trong màn bài. `nil` ⇒ chữ không chạm được (vd. chữ nằm trong một nút).
private struct MoChuHanKey: EnvironmentKey { static let defaultValue: ((String) -> Void)? = nil }
extension EnvironmentValues {
    var moChuHanSH: ((String) -> Void)? {
        get { self[MoChuHanKey.self] }
        set { self[MoChuHanKey.self] = newValue }
    }
}

enum ChuHanTienIchSH {
    /// Ký tự là chữ Hán (CJK + mở rộng A) — `IS_KANJI` của web.
    static func laHan(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) }
    }
    static func cacChu(_ t: String) -> [String] {
        var seen = Set<String>()
        return PhanTichChuSH.tron(t).filter(laHan).map(String.init).filter { seen.insert($0).inserted }
    }
    /// Chữ đọc được của một từ (bỏ chữ Hán giữ cách đọc, bỏ ［…］ và số nhóm) — để phát âm.
    static func kana(_ t: String) -> String {
        var s = PhanTichChuSH.tach(t).map { $0.ruby ?? $0.text }.joined()
        if let re = try? NSRegularExpression(pattern: #"［.*?］|\d$"#) {
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        return s
    }
    static func tronGon(_ t: String) -> String {
        var s = PhanTichChuSH.tron(t)
        if let re = try? NSRegularExpression(pattern: #"［.*?］|\d$"#) {
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        return s
    }
}

/// Sheet chứa ngăn xếp thẻ chữ.
struct NganChuHanSH: View {
    @Binding var nganXep: [String]
    let baiDangHoc: Int?
    @ObservedObject var vm: SachHocVM
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            Group {
                if let ch = nganXep.last {
                    if let d = vm.chuHan {
                        ScrollViewReader { cuon in
                            ScrollView {
                                ThanChuHanSH(ch: ch, d: d, baiDangHoc: baiDangHoc, net: vm.net?[ch]) { c in
                                    if nganXep.last != c { nganXep = Array((nganXep + [c]).suffix(20)) }
                                }
                                .id(ch)
                                .padding(16)
                                .frame(maxWidth: 720)
                                .frame(maxWidth: .infinity)
                            }
                            .onChange(of: ch) { _, c in cuon.scrollTo(c, anchor: .top) }
                        }
                    } else {
                        VStack(spacing: 10) { ProgressView(); Text("Đang tải dữ liệu chữ Hán…").foregroundColor(AppColors.textSecondary) }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(nganXep.last.map { "Chữ Hán \($0)" } ?? "")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if nganXep.count > 1 {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { nganXep.removeLast() } label: { Label(nganXep[nganXep.count - 2], systemImage: "chevron.left") }
                            .accessibilityLabel("Quay lại chữ \(nganXep[nganXep.count - 2])")
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Xong") { dong() } }
            }
        }
        .environmentObject(vm)
        .task { await vm.napChuHan(); await vm.napNet() }
        .presentationDetents([.large])
    }
}

struct ThanChuHanSH: View {
    let ch: String
    let d: ChuHanSH
    let baiDangHoc: Int?
    let net: [String]?
    let mo: (String) -> Void
    @State private var vietTap = false
    @State private var hienSau = false

    private struct Dong: Hashable { let w: String; let ro: String; let vi: String; let n: Int?; let bang: Bool }

    var body: some View {
        let han = d.han[ch]
        let bang = d.bang[ch]
        let daHoc = d.baiCuaChu
        let lop = daHoc[ch]
        let tat = d.tu[ch] ?? []
        let baiCuaTu = Dictionary(tat.map { (ChuHanTienIchSH.tronGon($0.w), $0.n) }, uniquingKeysWith: { a, _ in a })
        let tuTay: [Dong] = (han?.tu ?? []).map { Dong(w: $0.w, ro: $0.ro ?? "", vi: $0.vi ?? "", n: baiCuaTu[PhanTichChuSH.tron($0.w)], bang: $0.bang ?? false) }
        let tapTay = Set(tuTay.map { PhanTichChuSH.tron($0.w) })
        let con = tat.filter { !tapTay.contains(ChuHanTienIchSH.tronGon($0.w)) }.map { Dong(w: $0.w, ro: $0.ro, vi: $0.vi, n: $0.n, bang: false) }
        let now = baiDangHoc
        let trongBai = now == nil ? [] : con.filter { $0.n == now }
        let truoc = con.filter { now == nil || ($0.n ?? 0) < now! }
        let sau = now == nil ? [] : con.filter { ($0.n ?? 0) > now! }
        let on = han.map { $0.on } ?? (bang?.on.map { $0.split(whereSeparator: { "・、, ".contains($0) }).map(String.init) } ?? [])
        let kun = han.map { $0.kun } ?? (bang?.kun.map { $0.split(whereSeparator: { "・、, ".contains($0) }).map(String.init) } ?? [])
        let hv = han?.hv.nilNeuRong ?? bang?.hv
        let nghia = han?.nghia.nilNeuRong ?? bang?.nghia
        let tieuBieu = tuTay.first ?? con.first

        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) { TrinhPhatNetSH(chu: ch, paths: net).id("\(ch)|\(net?.count ?? 0)"); thongTin(hv: hv, nghia: nghia, on: on, kun: kun, han: han, bang: bang, lop: lop, soTu: tat.count, tieuBieu: tieuBieu) }
                VStack(alignment: .leading, spacing: 14) {
                    TrinhPhatNetSH(chu: ch, paths: net).id("\(ch)|\(net?.count ?? 0)").frame(maxWidth: .infinity)
                    thongTin(hv: hv, nghia: nghia, on: on, kun: kun, han: han, bang: bang, lop: lop, soTu: tat.count, tieuBieu: tieuBieu)
                }
            }
            if !tuTay.isEmpty {
                muc("Từ đi chung", phu: "từ tiêu biểu" + (tuTay.contains { $0.bang } ? " — nền xanh là từ cô chép trên bảng" : "")) {
                    ForEach(tuTay, id: \.self) { hangTu($0, daHoc: daHoc) }
                }
            }
            if !con.isEmpty {
                muc("Chữ \(ch) trong từ vựng của khoá", phu: "chip xanh = chữ Hán đã học") {
                    if !trongBai.isEmpty { nhan("Bài đang học (Bài \(now ?? 0))"); ForEach(trongBai, id: \.self) { hangTu($0, daHoc: daHoc) } }
                    if !truoc.isEmpty { nhan(now == nil ? "Các bài" : "Đã gặp ở bài trước — ghép với chữ đã học"); ForEach(truoc, id: \.self) { hangTu($0, daHoc: daHoc) } }
                    if !sau.isEmpty {
                        if hienSau { nhan("Sẽ gặp ở bài sau"); ForEach(sau, id: \.self) { hangTu($0, daHoc: daHoc) } }
                        else { NutSH(ten: "Xem \(sau.count) từ ở các bài sau", phu: true) { hienSau = true } }
                    }
                }
            }
            let vds = cauViDu(now)
            if !vds.isEmpty {
                muc("Câu ví dụ", phu: nil) {
                    ForEach(vds, id: \.self) { e in
                        HStack(alignment: .top, spacing: 8) {
                            NutLoaSH(text: e.text, co: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    ChuSH(text: e.text, co: 17)
                                    the("Bài \(e.n)", bat: e.n == now)
                                }
                                Text(e.ro).font(.system(size: 12.5).italic()).foregroundColor(AppColors.textTertiary)
                                ChuSH(text: e.vi, co: 14, mau: .phu)
                            }
                        }
                    }
                }
            }
            #if os(iOS)
            if vietTap {
                VietTaySH(id: "kj-\(ch)", title: "Tập viết chữ \(ch)", chars: [ch],
                          note: "Xem hoạt hình ở trên cho thuộc thứ tự nét, rồi tô theo chữ mờ ở ô đầu và tự viết ở hai ô sau.")
            } else {
                NutSH(ten: "Tập viết chữ \(ch)", bieuTuong: "pencil.and.scribble") { vietTap = true }
            }
            #endif
        }
    }

    private func cauViDu(_ now: Int?) -> [ChuHanSH.CauVD] {
        let ds = d.vd[ch] ?? []
        guard let now else { return Array(ds.prefix(4)) }
        func kc(_ n: Int) -> Int { n <= now ? now - n : 100 + n - now }
        return Array(ds.sorted { kc($0.n) < kc($1.n) }.prefix(4))
    }

    @ViewBuilder
    private func thongTin(hv: String?, nghia: String?, on: [String], kun: [String], han: ChuHanSH.Han?, bang: ChuHanSH.Bang?, lop: Int?, soTu: Int, tieuBieu: Dong?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(ch).font(.system(size: 54, design: .serif)).foregroundColor(AppColors.textPrimary)
                if let hv { Text(hv).font(.system(size: 22, weight: .heavy)).foregroundColor(MauChuSH.mau(0xB45309).color) }
                Spacer(minLength: 0)
                if let t = tieuBieu {
                    Button { GiongSachHoc.chung.phat(ClipSH(text: ChuHanTienIchSH.kana(t.w)), khoa: "kj|\(t.w)") } label: {
                        Label(PhanTichChuSH.tron(t.w), systemImage: "speaker.wave.2.fill").font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(AppColors.primary.opacity(0.12))).foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Nghe từ tiêu biểu")
                }
            }
            if let nghia { ChuSH(text: nghia, co: 17, dam: true) }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    Text("On 音").font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.textSecondary)
                    Text(on.isEmpty ? "—" : on.joined(separator: "・")).font(.system(size: 18, weight: .medium))
                }
                GridRow {
                    Text("Kun 訓").font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.textSecondary)
                    Text(kun.isEmpty ? "—" : kun.joined(separator: "、")).font(.system(size: 18, weight: .medium))
                }
            }
            HangCuonSH(cach: 6) {
                if let n = net?.count { the("\(n) nét", bat: false) }
                if let lop {
                    the("Chữ của lớp · Bài \(lop)" + (d.lop[String(lop)]?.nguon == "slide" ? " (slide của cô)" : " (dự kiến)"), bat: true)
                } else if let b = bang {
                    the("Gặp ở bảng chữ Hán Bài \(b.n)", bat: false)
                }
                if soTu > 0 { the("\(soTu) từ trong khoá", bat: false) }
            }
            if let nho = han?.nho, !nho.isEmpty {
                ChuSH(text: "**Cách nhớ:** " + nho, co: 15)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.accent.opacity(0.08)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func muc<C: View>(_ t: String, phu: String?, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(t).font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.textPrimary)
                if let phu { Text(phu).font(.system(size: 12)).foregroundColor(AppColors.textTertiary) }
            }
            c()
        }
    }

    private func nhan(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 11, weight: .heavy)).kerning(0.4).foregroundColor(AppColors.textTertiary).padding(.top, 4)
    }

    private func the(_ t: String, bat: Bool) -> some View {
        Text(t).font(.system(size: 11.5, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(bat ? AppColors.primary.opacity(0.15) : AppColors.backgroundTertiary))
            .foregroundColor(bat ? AppColors.primary : AppColors.textSecondary)
    }

    private func hangTu(_ r: Dong, daHoc: [String: Int]) -> some View {
        let khac = ChuHanTienIchSH.cacChu(r.w).filter { $0 != ch }
        return HStack(alignment: .top, spacing: 10) {
            NutLoaSH(text: ChuHanTienIchSH.kana(r.w), co: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ChuSH(text: r.w, co: 18, dam: true)
                    if r.bang { the("cô chép", bat: true) }
                    if let n = r.n { the("Bài \(n)", bat: n == baiDangHoc) }
                }
                if !r.ro.isEmpty { Text(r.ro).font(.system(size: 12.5).italic()).foregroundColor(AppColors.textTertiary) }
                ChuSH(text: r.vi, co: 14.5, mau: .phu)
                if !khac.isEmpty {
                    HangCuonSH(cach: 6) {
                        ForEach(khac, id: \.self) { c in
                            let at = daHoc[c]
                            let xong = at != nil && (baiDangHoc == nil || at! <= baiDangHoc!)
                            let hv = d.han[c]?.hv ?? d.bang[c]?.hv.map { String($0.split(whereSeparator: { $0 == " " || $0 == "(" }).first ?? "") } ?? ""
                            Button { mo(c) } label: {
                                Text("\(c) \(hv)" + (xong ? " · B\(at!) ✓" : at.map { " · B\($0)" } ?? ""))
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(xong ? AppColors.success.opacity(0.15) : at != nil ? AppColors.warning.opacity(0.12) : AppColors.backgroundTertiary))
                                    .foregroundColor(xong ? AppColors.success : AppColors.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(r.bang ? AppColors.info.opacity(0.07) : Color.clear))
    }
}

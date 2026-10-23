import SwiftUI

// ════════════════════════════════════════════════════════════════
// KHỐI `vocabAll` + ô "Tra từ" trong màn bài — bản native của TraTuVung.tsx:
// tra TOÀN BỘ từ vựng của khoá (tu-vung.json, lấy từ mục lục các buổi như web):
// tìm (gõ không dấu cũng được, cả cách đọc furigana), lọc theo buổi, che nghĩa /
// che từ để tự kiểm tra, và thẻ nhớ (lật, trộn) hai chiều.
// ════════════════════════════════════════════════════════════════

/// Gấp chữ để so lỏng: bỏ dấu tiếng Việt, đ→d, thường hoá; `{漢字|かな}` ⇒ "漢字 かな" (tìm được cả hai).
func gapChuSH(_ x: String) -> String {
    var s = x
    if let re = try? NSRegularExpression(pattern: #"\{([^|}]+)\|([^}]+)\}"#) {
        s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1 $2")
    }
    s = s.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
    return s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
}

struct TraTuVungSH: View {
    @EnvironmentObject private var vm: SachHocVM
    @State private var tim = ""
    @State private var buoi = 0
    @State private var che = 0           // 0 xem đủ · 1 che nghĩa · 2 che từ
    @State private var daMo: Set<String> = []
    @State private var the: (bo: [TuKhoaSH], i: Int, lat: Bool, viTruoc: Bool)?
    /// Số dòng đang hiện (kho IELTS ~160 từ, Dekiru ~1.300 từ — hiện dần cho nhẹ).
    @State private var soHien = 80

    private var tenTieng: String { vm.khoa?.ngonNgu == "ja" ? "Nhật" : vm.khoa?.ngonNgu == "zh" ? "Trung" : "Anh" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let tat = vm.tuVung {
                if let t = the { theNho(t) } else { danhSach(tat) }
            } else if vm.khoa?.tuVung == nil {
                Text("Khoá này chưa có danh sách từ vựng.").foregroundColor(AppColors.textSecondary)
            } else if let l = vm.loiNap {
                KhungLoiSH(loi: l) { Task { await vm.napTuVung() } }
            } else {
                HStack(spacing: 8) { ProgressView(); Text("Đang tải từ vựng cả khoá…").foregroundColor(AppColors.textSecondary) }
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .task { await vm.napTuVung() }
    }

    private func loc(_ tat: [TuKhoaSH]) -> [TuKhoaSH] {
        let q = gapChuSH(tim.trimmingCharacters(in: .whitespaces))
        return tat.filter { (buoi == 0 || $0.n == buoi) && (q.isEmpty || gapChuSH($0.w).contains(q) || gapChuSH($0.vi).contains(q) || gapChuSH($0.ipa).contains(q)) }
    }

    private func tenBuoi(_ n: Int) -> String { vm.buoi(n)?.ten ?? "\(vm.khoa?.donVi ?? "Buổi") \(n)" }

    @ViewBuilder
    private func danhSach(_ tat: [TuKhoaSH]) -> some View {
        let ds = loc(tat)
        let cacBuoi = Array(Set(tat.map(\.n))).sorted()
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
            TextField("Tìm từ tiếng \(tenTieng) hoặc nghĩa tiếng Việt (gõ không dấu cũng được)…", text: $tim)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .onChange(of: tim) { _, _ in soHien = 80 }
            if !tim.isEmpty { Button { tim = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary) }.buttonStyle(.plain) }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("Tất cả (\(tat.count))", buoi == 0) { buoi = 0; soHien = 80 }
                ForEach(cacBuoi, id: \.self) { n in
                    chip("\(tenBuoi(n)) (\(tat.filter { $0.n == n }.count))", buoi == n) { buoi = n; soHien = 80 }
                }
            }
        }
        Picker("Tự kiểm tra", selection: $che) {
            Text("Xem đủ").tag(0)
            Text("Che nghĩa").tag(1)
            Text("Che từ").tag(2)
        }
        .pickerStyle(.segmented)
        .onChange(of: che) { _, _ in daMo = [] }
        HStack(spacing: 8) {
            NutSH(ten: "Thẻ nhớ \(tenTieng) → Việt", bieuTuong: "shuffle", phu: true) { the = (ds.shuffled(), 0, false, false) }
                .disabled(ds.isEmpty)
            NutSH(ten: "Việt → \(tenTieng)", bieuTuong: "shuffle", phu: true) { the = (ds.shuffled(), 0, false, true) }
                .disabled(ds.isEmpty)
        }
        Text("\(ds.count) từ\(tim.isEmpty ? "" : " khớp “\(tim)”"). Bấm 🔊 để nghe. Muốn xem câu ví dụ, mở bài của buổi đó.")
            .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
        LazyVStack(spacing: 0) {
            ForEach(ds.prefix(soHien)) { v in
                hang(v)
                Divider()
            }
            if ds.count > soHien {
                Button("Hiện thêm \(min(200, ds.count - soHien)) từ…") { soHien += 200 }
                    .font(.system(size: 14, weight: .semibold)).padding(.vertical, 12)
            }
            if ds.isEmpty {
                Text("Không có từ nào khớp. Thử gõ ngắn hơn, hoặc chọn “Tất cả”.").font(.system(size: 14)).foregroundColor(AppColors.textSecondary).padding(16)
            }
        }
        .theKhoiSH()
    }

    private func hang(_ v: TuKhoaSH) -> some View {
        let cheW = che == 2 && !daMo.contains(v.id)
        let cheVi = che == 1 && !daMo.contains(v.id)
        return HStack(alignment: .top, spacing: 10) {
            if cheW { Color.clear.frame(width: 30, height: 30) } else { NutLoaSH(text: v.w, co: 30) }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    oChe(cheW, v.id) { ChuSH(text: v.w, co: 19, dam: true) }
                    if !v.pos.isEmpty {
                        Text(v.pos).font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(AppColors.secondary.opacity(0.12)))
                    }
                }
                if !cheW, !v.ipa.isEmpty { Text(v.ipa).font(.system(size: 13).italic()).foregroundColor(AppColors.textTertiary) }
                oChe(cheVi, v.id) { ChuSH(text: v.vi, co: 15.5, mau: .nhan) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(tenBuoi(v.n)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func oChe<C: View>(_ on: Bool, _ id: String, @ViewBuilder _ c: () -> C) -> some View {
        if on {
            Button { daMo.insert(id) } label: {
                c().opacity(0)
                    .overlay(RoundedRectangle(cornerRadius: 8).fill(AppColors.backgroundTertiary))
                    .overlay(Text("chạm để xem").font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.textTertiary))
            }
            .buttonStyle(.plain)
        } else {
            c()
        }
    }

    private func chip(_ t: String, _ bat: Bool, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Text(t).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(bat ? AppColors.primary : AppColors.backgroundTertiary))
                .foregroundColor(bat ? .white : AppColors.textPrimary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Thẻ nhớ

    @ViewBuilder
    private func theNho(_ t: (bo: [TuKhoaSH], i: Int, lat: Bool, viTruoc: Bool)) -> some View {
        let it = t.bo[t.i]
        HStack {
            Text("Thẻ \(t.i + 1)/\(t.bo.count) · \(tenBuoi(it.n))").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            Spacer()
            NutSH(ten: "Về danh sách", phu: true) { the = nil }
        }
        Button {
            if !t.lat && !t.viTruoc { GiongSachHoc.chung.phat(ClipSH(text: it.w), khoa: "the|\(it.w)") }
            the?.lat.toggle()
        } label: {
            VStack(spacing: 12) {
                if t.viTruoc { ChuSH(text: it.vi, co: 24, dam: true, giua: true) }
                else {
                    ChuSH(text: it.w, co: 30, dam: true, giua: true)
                    if !it.ipa.isEmpty { Text(it.ipa).font(.system(size: 15).italic()).foregroundColor(AppColors.textTertiary) }
                }
                Divider().opacity(t.lat ? 1 : 0)
                if t.lat {
                    if t.viTruoc {
                        ChuSH(text: it.w, co: 26, dam: true, giua: true)
                        if !it.ipa.isEmpty { Text(it.ipa).font(.system(size: 14).italic()).foregroundColor(AppColors.textTertiary) }
                    } else {
                        ChuSH(text: it.vi, co: 20, mau: .nhan, giua: true)
                    }
                    if !it.pos.isEmpty { Text(it.pos).font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.secondary) }
                } else {
                    Text(t.viTruoc ? "Nói to từ tiếng \(tenTieng) — rồi chạm để lật" : "Nói to nghĩa tiếng Việt — rồi chạm để lật")
                        .font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(RoundedRectangle(cornerRadius: 18).fill(AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AppColors.primary.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .environment(\.moChuHanSH, nil)
        HStack(spacing: 8) {
            NutSH(ten: "Trước", bieuTuong: "arrow.left", phu: true) { the?.i -= 1; the?.lat = false }
                .disabled(t.i == 0).opacity(t.i == 0 ? 0.4 : 1)
            NutSH(ten: "Nghe", bieuTuong: "speaker.wave.2.fill", phu: true) { GiongSachHoc.chung.phat(ClipSH(text: it.w), khoa: "the|\(it.w)") }
            Spacer()
            if t.i < t.bo.count - 1 {
                NutSH(ten: "Tiếp", bieuTuong: "arrow.right") { the?.i += 1; the?.lat = false }
            } else {
                NutSH(ten: "Trộn lại từ đầu", bieuTuong: "arrow.counterclockwise") { the = (t.bo.shuffled(), 0, false, t.viTruoc) }
            }
        }
    }
}

#if os(iOS)
import SwiftUI
import PencilKit

// ════════════════════════════════════════════════════════════════
// KHỐI `essay` — viết bài + AI chấm 4 tiêu chí (Blocks2.tsx › Essay + HandEssay.tsx).
//   ⌨️ Gõ phím: bài tự lưu trên máy (khoá `ielts-v2:essay:<id>` như web) ⇒
//      `POST /ielts/ai/cham-viet {bai, de, task}` (cần ≥ 20 từ; máy chủ đòi ≥ 50 ký tự).
//   ✍️ Viết tay (iPad + Apple Pencil): giấy kẻ dòng chia TRANG (1–4) — trang cố
//      định thì bút chỉ việc viết, không tranh chấp với cuộn bài. Chấm: mỗi trang
//      xuất JPEG nền trắng 1600px ⇒ `POST /ielts/ai/cham-viet-tay` ⇒ AI chép NGUYÊN
//      VĂN (giữ cả lỗi) rồi chấm theo đúng bộ tiêu chí của bài gõ.
// Lựa chọn gõ/viết tay nhớ trên máy (iPad hay viết tay).
// ════════════════════════════════════════════════════════════════

struct VietBaiSH: View {
    let id: String
    let task: String
    let prompt: String
    let minWords: Int
    let tips: [String]
    @AppStorage private var tay: Bool

    init(id: String, task: String, prompt: String, minWords: Int, tips: [String]) {
        self.id = id; self.task = task; self.prompt = prompt; self.minWords = minWords; self.tips = tips
        _tay = AppStorage(wrappedValue: false, "ielts-v2:essay:\(id):tay")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("✍️ WRITING \(task.uppercased())").font(.system(size: 11, weight: .heavy)).kerning(0.6).foregroundColor(AppColors.accent)
            ChuSH(text: prompt, co: 17)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent.opacity(0.07)))
            if !tips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { _, t in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(AppColors.accent).frame(width: 5, height: 5).offset(y: -3)
                            ChuSH(text: t, co: 15, mau: .phu)
                        }
                    }
                }
            }
            Picker("Cách viết bài", selection: $tay) {
                Text("⌨️ Gõ phím").tag(false)
                Text("✍️ Viết tay").tag(true)
            }
            .pickerStyle(.segmented)
            if tay {
                VietTayBaiSH(id: id, de: PhanTichChuSH.tron(prompt), task: task)
            } else {
                GoBaiSH(id: id, de: PhanTichChuSH.tron(prompt), task: task, minWords: minWords)
            }
        }
        .theKhoiSH(vien: AppColors.accent.opacity(0.4))
    }
}

/// Lỗi AI từ máy chủ ⇒ câu tiếng Việt cho người học.
private func loiChamSH(_ e: Error, viec: String) -> String {
    if case APIError.unauthorized = e { return "Đăng nhập để AI \(viec)." }
    return e.localizedDescription
}

// MARK: - Gõ phím

private struct GoBaiSH: View {
    let id: String
    let de: String
    let task: String
    let minWords: Int
    @AppStorage private var bai: String
    @State private var dangCham = false
    @State private var ketQua: String?
    @State private var loi: String?
    @FocusState private var dangGo: Bool

    init(id: String, de: String, task: String, minWords: Int) {
        self.id = id; self.de = de; self.task = task; self.minWords = minWords
        _bai = AppStorage(wrappedValue: "", "ielts-v2:essay:\(id)")
    }

    private var soTu: Int { bai.split(whereSeparator: \.isWhitespace).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $bai)
                    .font(.system(size: 17))
                    .focused($dangGo)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 260)
                    .padding(8)
                if bai.isEmpty {
                    Text("Viết bài của bạn ở đây… (bài tự lưu trên máy này)").font(.system(size: 16)).foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 13).padding(.vertical, 16).allowsHitTesting(false)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(dangGo ? AppColors.primary : AppColors.border, lineWidth: 1.2))
            HStack {
                Text("\(soTu) / \(minWords) từ").font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundColor(soTu >= minWords ? AppColors.success : AppColors.textSecondary)
                Spacer()
                NutSH(ten: dangCham ? "AI đang chấm…" : "Nhờ AI chấm theo 4 tiêu chí", bieuTuong: "sparkles") { Task { await cham() } }
                    .disabled(dangCham || soTu < 20).opacity(dangCham || soTu < 20 ? 0.5 : 1)
            }
            if let loi { PhanHoiSH(dung: false, chu: loi) }
            if let ketQua {
                NoiDungMarkdown(noiDung: ketQua)
                    .theKhoiSH(vien: AppColors.primary.opacity(0.3), nen: AppColors.primary.opacity(0.05))
            }
        }
    }

    private func cham() async {
        dangGo = false
        dangCham = true; loi = nil; ketQua = nil
        defer { dangCham = false }
        struct Kq: Decodable { let ketQua: String?; let lyDo: String? }
        do {
            let kq: Kq = try await APIClient.shared.request(.ieltsChamViet(["bai": bai, "de": de, "task": task]))
            if let k = kq.ketQua, !k.isEmpty { ketQua = k }
            else { loi = kq.lyDo == "ai_unavailable" ? "AI chấm bài đang tạm tắt." : "Chưa chấm được, thử lại nhé." }
        } catch {
            loi = loiChamSH(error, viec: "chấm bài")
        }
    }
}

// MARK: - Viết tay (giấy kẻ dòng)

/// Giấy: dòng cách nhau rộng/20, lề đỏ bên trái như giấy thi — `paper` của HandEssay.tsx.
private struct GiayKeSH: View {
    var xuat = false
    var body: some View {
        Canvas { ctx, size in
            let gap = size.width / 20
            var dong = Path()
            var y = gap * 1.6
            while y < size.height - gap * 0.4 { dong.move(to: CGPoint(x: 0, y: y)); dong.addLine(to: CGPoint(x: size.width, y: y)); y += gap }
            ctx.stroke(dong, with: .color(xuat ? Color(hex: 0xD5DBE5) : AppColors.info.opacity(0.22)), lineWidth: 1)
            var le = Path()
            let x = size.width * 0.075
            le.move(to: CGPoint(x: x, y: 0)); le.addLine(to: CGPoint(x: x, y: size.height))
            ctx.stroke(le, with: .color(Color(hex: 0xDC2626).opacity(0.35)), lineWidth: 1)
        }
    }
}

private struct VietTayBaiSH: View {
    let id: String
    let de: String
    let task: String
    @EnvironmentObject private var vm: SachHocVM

    @State private var trang: [PKDrawing] = [PKDrawing()]
    @State private var dang = 0
    @State private var phienBan = 0
    @State private var but = ButVietSH()
    @State private var daNap = false
    @State private var dangCham = false
    @State private var chep: String?
    @State private var ketQua: String?
    @State private var loi: String?
    @State private var hoiXoa = false

    private static let TI_LE: CGFloat = 1.36
    private static let TOI_DA = 4
    /// Hệ thiết kế: tờ giấy rộng 800 (như web).
    private static let RONG: CGFloat = 800
    private var khoaLuu: String { "\(vm.khoaId):ink:\(id)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                congCu("pencil.tip", "Bút", !but.tay) { but.tay = false }
                congCu("eraser", "Tẩy", but.tay) { but.tay = true }
                congCu("arrow.uturn.backward", "Hoàn tác", false) {
                    guard !trang[dang].strokes.isEmpty else { return }
                    trang[dang].strokes.removeLast(); phienBan += 1; luu()
                }
                congCu("trash", "Xoá trang", false) { if !trang[dang].strokes.isEmpty { hoiXoa = true } }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(trang.indices, id: \.self) { i in
                        Button { dang = i } label: {
                            Text("Trang \(i + 1)\(trang[i].strokes.isEmpty ? " (trống)" : "")").font(.system(size: 13.5, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(i == dang ? AppColors.primary : AppColors.backgroundTertiary))
                                .foregroundColor(i == dang ? .white : AppColors.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    if trang.count < Self.TOI_DA {
                        Button { trang.append(PKDrawing()); dang = trang.count - 1; luu() } label: {
                            Label("Thêm trang", systemImage: "plus").font(.system(size: 13.5, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().strokeBorder(AppColors.primary, lineWidth: 1)).foregroundColor(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    if trang.count > 1, trang[dang].strokes.isEmpty {
                        Button("Bỏ trang trống này") { trang.remove(at: dang); dang = max(0, dang - 1); phienBan += 1; luu() }
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            Color.clear
                .aspectRatio(1 / Self.TI_LE, contentMode: .fit)
                .overlay(
                    GeometryReader { g in
                        ZStack {
                            GiayKeSH()
                            OVietPK(ve: trang[dang], phienBan: phienBan * 10 + dang, rongThietKe: Self.RONG, rong: g.size.width, but: but, doDay: 2.6,
                                    doi: { d in trang[dang] = d; luu() })
                        }
                    }
                )
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.theoCheDo(sang: Color(hex: 0xFFFEFB), toi: Color(hex: 0x1A1C20))))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                .accessibilityLabel("Giấy viết tay, trang \(dang + 1)")
            HStack {
                Text("Trang \(dang + 1)/\(trang.count) · tối đa \(Self.TOI_DA) trang · bài tự lưu trên máy này")
                    .font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
                Spacer()
                let coNet = trang.contains { !$0.strokes.isEmpty }
                NutSH(ten: dangCham ? "AI đang đọc và chấm…" : "Chấm bài viết tay", bieuTuong: "sparkles") { Task { await cham() } }
                    .disabled(dangCham || !coNet).opacity(dangCham || !coNet ? 0.5 : 1)
            }
            if let loi { PhanHoiSH(dung: false, chu: loi) }
            if let chep, !chep.isEmpty {
                DisclosureGroup("AI đọc được bài của bạn thế này") {
                    Text(chep).font(.system(size: 14, design: .serif)).foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                }
                .font(.system(size: 14, weight: .semibold))
            }
            if let ketQua {
                NoiDungMarkdown(noiDung: ketQua)
                    .theKhoiSH(vien: AppColors.primary.opacity(0.3), nen: AppColors.primary.opacity(0.05))
            }
        }
        .task {
            guard !daNap else { return }
            daNap = true
            let m = KhoNetVietSH.doc(khoaLuu)
            let ds = (0..<Self.TOI_DA).compactMap { m["trang-\($0)"] }
            if !ds.isEmpty { trang = ds; phienBan += 1 }
        }
        .confirmationDialog("Xoá hết trang \(dang + 1)?", isPresented: $hoiXoa, titleVisibility: .visible) {
            Button("Xoá trang", role: .destructive) { trang[dang] = PKDrawing(); phienBan += 1; luu() }
        }
    }

    private func congCu(_ bt: String, _ ten: String, _ bat: Bool, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Label(ten, systemImage: bt).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Capsule().fill(bat ? AppColors.primary.opacity(0.16) : AppColors.backgroundTertiary))
                .foregroundColor(bat ? AppColors.primary : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func luu() {
        // Chỉ trang CÓ nét được lưu (trang trống mở lại sẽ mất — như "Bỏ trang trống").
        var m: [String: PKDrawing] = [:]
        for (i, d) in trang.filter({ !$0.strokes.isEmpty }).enumerated() { m["trang-\(i)"] = d }
        KhoNetVietSH.ghi(khoaLuu, m)
    }

    /// Một trang ⇒ JPEG nền trắng 1600px, mực đậm (bản sáng dù máy đang tối).
    private func anhTrang(_ d: PKDrawing) -> String? {
        let w: CGFloat = 1600, h = (w * Self.TI_LE).rounded()
        let fm = UIGraphicsImageRendererFormat(); fm.scale = 1
        let anh = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fm).image { r in
            let ctx = r.cgContext
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let gap = w / 20
            ctx.setStrokeColor(UIColor(hex: 0xD5DBE5).cgColor); ctx.setLineWidth(1)
            var y = gap * 1.6
            while y < h - gap * 0.4 { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: w, y: y)); y += gap }
            ctx.strokePath()
            var net = UIImage()
            UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                net = d.image(from: CGRect(x: 0, y: 0, width: Self.RONG, height: Self.RONG * Self.TI_LE), scale: w / Self.RONG)
            }
            net.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return anh.jpegData(compressionQuality: 0.85)?.base64EncodedString()
    }

    private func cham() async {
        let anh = trang.filter { !$0.strokes.isEmpty }.compactMap(anhTrang)
        guard !anh.isEmpty else { return }
        dangCham = true; loi = nil; chep = nil; ketQua = nil
        defer { dangCham = false }
        struct Kq: Decodable { let chep: String?; let ketQua: String?; let lyDo: String? }
        do {
            let kq: Kq = try await APIClient.shared.request(.sachHocChamVietTay(["pages": anh, "de": de, "task": task]))
            chep = kq.chep
            if let k = kq.ketQua, !k.isEmpty { ketQua = k }
            else {
                loi = kq.lyDo == "ai_unavailable" ? "AI chấm bài đang tạm tắt."
                    : kq.lyDo == "qua_ngan" ? "AI đọc được quá ít chữ để chấm (cần ≥ 20 từ). Xem bản chép bên dưới."
                    : "Chưa chấm được, thử lại nhé."
            }
        } catch {
            loi = loiChamSH(error, viec: "chấm bài")
        }
    }
}
#endif

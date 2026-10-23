import SwiftUI

// ════════════════════════════════════════════════════════════════
// LUYỆN VIẾT — lối vào riêng cho các khối `write` của khoá (23/10/2026).
// Người học trên iPad báo "không tìm thấy chỗ luyện viết": khối viết nằm ở
// CUỐI bài dài (Bài 0: hiragana/katakana; Bài 1–15: chữ Hán của lớp, toàn bộ
// chữ Hán bài, luyện thêm). Mục lục có thẻ "✍ Luyện viết" ⇒ màn liệt kê theo
// Bài ⇒ chạm một mục là mở THẲNG khối viết đó trong màn riêng (chỉ một khối,
// nhẹ — không dựng cả bài 20 khối như khi mở bài rồi cuộn xuống).
//
// Danh sách tính TỪ DỮ LIỆU: index.json (trường `viet` của từng bài, từ
// 23/10) — index cũ chưa có thì app tự quét khối `write` trong nội dung bài
// (tải các buổi về, có thanh tiến độ). Nét đã viết dùng CHUNG kho với trong
// bài (`<khoá>:ink:<id khối>`) ⇒ viết ở đâu cũng thấy ở kia.
// ════════════════════════════════════════════════════════════════

/// Một khối viết của khoá — một mục của màn Luyện viết.
struct MucVietSH: Identifiable, Hashable {
    let buoi: Int
    let baiId: String
    let baiTitle: String
    let nhom: String?
    let khoi: KhoiVietMetaSH
    var id: String { baiId + "/" + khoi.id }
}

extension SachHocVM {
    /// Index mới (có trường `viet`) ⇒ bài không có `viet` nghĩa là KHÔNG có khối viết.
    var indexCoViet: Bool { khoa?.buoi.contains { $0.bai.contains { $0.viet != nil } } ?? false }

    /// Khoá có thể có khối viết — để hiện thẻ "Luyện viết" ở mục lục.
    var coLuyenViet: Bool {
        if indexCoViet { return true }
        if noiDung.values.contains(where: { $0.contains { !Self.vietTu($0).isEmpty } }) { return true }
        // Index cũ (web chưa deploy bản xuất mới): khoá chữ Nhật/Trung luôn có khối viết.
        return khoa?.ngonNgu == "ja" || khoa?.ngonNgu == "zh"
    }

    /// Khối viết của một bài: index, hoặc nội dung đã nạp; nil = chưa biết.
    func khoiViet(buoi n: Int, bai l: BaiMetaSH) -> [KhoiVietMetaSH]? {
        if let v = l.viet { return v }
        if let ds = noiDung[n], let b = ds.first(where: { $0.id == l.id }) { return Self.vietTu(b) }
        return indexCoViet ? [] : nil
    }

    static func vietTu(_ b: BaiSH) -> [KhoiVietMetaSH] {
        b.blocks.compactMap { k in
            guard case .write(let id, let title, let chars, _, _) = k else { return nil }
            var seen = Set<String>()
            let ds = chars.filter { seen.insert($0).inserted }
            return KhoiVietMetaSH(id: id, title: title, so: ds.count, mau: Array(ds.prefix(8)))
        }
    }

    /// Mọi khối viết đã biết của một buổi, theo thứ tự bài.
    func mucViet(_ b: BuoiSH) -> [MucVietSH] {
        b.bai.filter(\.ready).flatMap { l in
            (khoiViet(buoi: b.n, bai: l) ?? []).map { MucVietSH(buoi: b.n, baiId: l.id, baiTitle: l.title, nhom: l.nhom, khoi: $0) }
        }
    }

    /// Buổi còn chưa biết có khối viết hay không (index cũ + chưa nạp nội dung).
    var buoiChuaQuetViet: [BuoiSH] {
        guard !indexCoViet, let khoa else { return [] }
        return khoa.buoi.filter { b in b.tep != nil && noiDung[b.n] == nil }
    }

    /// Thứ tự cả khoá — nút "khối trước / khối sau" của màn viết riêng.
    var dsViet: [MucVietSH] { (khoa?.buoi ?? []).flatMap { mucViet($0) } }
}

// MARK: - Màn liệt kê

struct LuyenVietSHView: View {
    @ObservedObject var vm: SachHocVM
    /// Mở từ một Bài trong mục lục ⇒ cuộn tới Bài đó.
    var toiBuoi: Int? = nil

    @State private var dangQuet: (xong: Int, tong: Int)?
    @State private var loiQuet: String?

    private let cot = [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)]

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    dau
                    if let q = dangQuet {
                        HStack(spacing: 10) {
                            ProgressView(value: Double(q.xong), total: Double(max(1, q.tong))).frame(maxWidth: 220)
                            Text("Đang tìm khối viết trong các bài… \(q.xong)/\(q.tong)").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    if let loiQuet { PhanHoiSH(dung: false, chu: loiQuet) }
                    ForEach(vm.khoa?.buoi ?? []) { b in
                        let ds = vm.mucViet(b)
                        if !ds.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(b.ten.uppercased()).font(.system(size: 12, weight: .heavy)).kerning(0.6).foregroundColor(AppColors.primary)
                                    Text("\(ds.count) khối · \(ds.reduce(0) { $0 + $1.khoi.so }) mục").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                                }
                                LazyVGrid(columns: cot, alignment: .leading, spacing: 12) {
                                    ForEach(ds) { m in
                                        NavigationLink { KhoiVietRiengView(vm: vm, muc: m) } label: { TheVietSH(muc: m, khoaId: vm.khoaId, mauNhom: mauNhomSH(m.nhom)) }
                                            .buttonStyle(.plain)
                                    }
                                }
                            }
                            .id("buoi-\(b.n)")
                        }
                    }
                    if dangQuet == nil, vm.dsViet.isEmpty, vm.buoiChuaQuetViet.isEmpty {
                        Text("Khoá này chưa có phần tập viết.").font(.system(size: 15)).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .task {
                await quet()
                if let n = toiBuoi {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    withAnimation { cuon.scrollTo("buoi-\(n)", anchor: .top) }
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Luyện viết")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var dau: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "pencil.and.scribble").font(.system(size: 26, weight: .semibold)).foregroundColor(.white)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.primary))
            VStack(alignment: .leading, spacing: 4) {
                Text("Luyện viết tay").font(.system(size: 20, weight: .bold)).foregroundColor(AppColors.textPrimary)
                Text("Mỗi khối mở riêng: xem thứ tự nét, tô theo chữ mờ rồi tự viết bằng Apple Pencil hoặc ngón tay. Chữ đã viết lưu trên máy — chung với khối viết trong bài.")
                    .font(.system(size: 14)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .theKhoiSH(vien: AppColors.primary.opacity(0.35), nen: AppColors.primary.opacity(0.05))
    }

    /// Index cũ chưa có `viet` ⇒ tải các buổi (lưu trên máy, lần sau tức thì) và quét khối `write`.
    private func quet() async {
        let ds = vm.buoiChuaQuetViet
        guard !ds.isEmpty, dangQuet == nil else { return }
        dangQuet = (0, ds.count)
        var loi = 0
        for (i, b) in ds.enumerated() {
            do { _ = try await vm.noiDungBuoi(b.n) } catch { loi += 1 }
            dangQuet = (i + 1, ds.count)
        }
        dangQuet = nil
        if loi > 0 { loiQuet = "Không tải được \(loi) buổi — kiểm tra mạng rồi mở lại màn này." }
    }
}

/// Màu nhãn nhóm bài (khớp mục lục).
func mauNhomSH(_ t: String?) -> Color {
    switch t {
    case "Theo slide lớp": return AppColors.info
    case "Luyện thêm": return AppColors.success
    case "Theo sách": return AppColors.textSecondary
    default: return AppColors.primary
    }
}

/// Thẻ một khối viết: vài chữ đầu trong ô 田, tên khối, số mục, bài chứa nó, số chữ đã viết.
private struct TheVietSH: View {
    let muc: MucVietSH
    let khoaId: String
    let mauNhom: Color
    @State private var daViet: Int?

    private var tach: (chinh: String, phu: String?) {
        let t = PhanTichChuSH.tron(muc.khoi.title)
        if let r = t.range(of: " — ") { return (String(t[..<r.lowerBound]), String(t[r.upperBound...])) }
        return (t, nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(muc.khoi.mau.prefix(6).enumerated()), id: \.offset) { _, c in
                    Text(c).font(.system(size: c.count > 2 ? 15 : 24, design: .serif)).lineLimit(1).minimumScaleFactor(0.5)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 40, minHeight: 40).padding(.horizontal, c.count > 1 ? 4 : 0)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.backgroundTertiary))
                        .overlay(OTiengSH().stroke(AppColors.border, style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])).padding(2))
                }
                if muc.khoi.so > 6 {
                    Text("+\(muc.khoi.so - 6)").font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(tach.chinh).font(.system(size: 15.5, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                if let p = tach.phu {
                    Text(p).font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
            }
            HStack(spacing: 6) {
                if let n = muc.nhom {
                    Text(n).font(.system(size: 11, weight: .bold)).foregroundColor(mauNhom)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(Capsule().fill(mauNhom.opacity(0.12)))
                }
                Text(PhanTichChuSH.tron(muc.baiTitle)).font(.system(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                Spacer(minLength: 4)
                if let d = daViet, d > 0 {
                    Label("\(d)/\(muc.khoi.so)", systemImage: "pencil").font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundColor(d >= muc.khoi.so ? AppColors.success : AppColors.primary)
                } else {
                    Text("\(muc.khoi.so) mục").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AppColors.border, lineWidth: 1))
        .contentShape(Rectangle())
        #if os(iOS)
        .task(id: muc.id) { daViet = KhoNetVietSH.soDaViet("\(khoaId):ink:\(muc.khoi.id)") }
        #endif
        .accessibilityElement(children: .combine)
    }
}

/// Đường kẻ chữ thập của ô 田 (trang trí ô chữ mẫu).
private struct OTiengSH: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

// MARK: - Màn một khối viết

/// Chỉ MỘT khối viết (dựng theo lát như trong bài) + lối sang khối trước/sau và "Mở cả bài".
struct KhoiVietRiengView: View {
    @ObservedObject var vm: SachHocVM
    @State var muc: MucVietSH

    @State private var khoi: KhoiSH?
    @State private var loi: String?
    @State private var chuHan: [String] = []
    @State private var rong: CGFloat = 0

    var body: some View {
        let ds = vm.dsViet
        let i = ds.firstIndex(of: muc)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text((vm.buoi(muc.buoi)?.ten ?? "").uppercased()).font(.system(size: 12, weight: .heavy)).kerning(0.6).foregroundColor(AppColors.primary)
                    ChuSH(text: muc.baiTitle, co: 15, mau: .phu)
                    NavigationLink { BaiSachHocView(vm: vm, muc: .bai(buoi: muc.buoi, id: muc.baiId)) } label: {
                        Label("Mở cả bài", systemImage: "book").font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 14)
                if let khoi {
                    KhoiSHView(khoi: khoi).environment(\.latKhoiSH, true).id(muc.id)
                } else if let loi {
                    KhungLoiSH(loi: loi) { Task { await nap() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                }
                HStack(spacing: 10) {
                    if let i, i > 0 { nutChuyen(ds[i - 1], sau: false) }
                    if let i, i + 1 < ds.count { nutChuyen(ds[i + 1], sau: true) }
                }
                .padding(.top, 18)
            }
            .environment(\.rongNoiDungSH, max(0, min(720, rong) - 32))
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 60)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .id(muc.id)
        .background(GeometryReader { g in
            Color.clear.onAppear { rong = g.size.width }.onChange(of: g.size.width) { _, w in rong = w }
        })
        .environment(\.baiDangDocSH, muc.baiId)
        .environment(\.moChuHanSH, vm.khoa?.ngonNgu == "ja" && vm.khoa?.chuHan != nil ? { c in
            if chuHan.last != c { chuHan = Array((chuHan + [c]).suffix(20)) }
        } : nil)
        .environmentObject(vm)
        .sheet(isPresented: Binding(get: { !chuHan.isEmpty }, set: { if !$0 { chuHan = [] } })) {
            NganChuHanSH(nganXep: $chuHan, baiDangHoc: SachHocVM.soBai(muc.baiId), vm: vm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Luyện viết · \(vm.buoi(muc.buoi)?.ten ?? "")")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: muc.id) { await nap() }
    }

    private func nap() async {
        khoi = nil; loi = nil
        #if os(iOS)
        KhoiDongPencilSH.mot()
        #endif
        Task { await vm.napNet() }
        do {
            let b = try await vm.noiDungMuc(.bai(buoi: muc.buoi, id: muc.baiId))
            khoi = b?.blocks.first { if case .write(let id, _, _, _, _) = $0 { return id == muc.khoi.id }; return false }
            if khoi == nil { loi = "Không thấy khối viết này trong bài — có thể bài vừa được cập nhật." }
        } catch {
            loi = error.localizedDescription
        }
    }

    private func nutChuyen(_ m: MucVietSH, sau: Bool) -> some View {
        Button { muc = m } label: {
            VStack(alignment: sau ? .trailing : .leading, spacing: 3) {
                Text(sau ? "Khối viết sau →" : "← Khối viết trước").font(.system(size: 12, weight: .bold)).foregroundColor(AppColors.primary)
                Text(PhanTichChuSH.tron(m.khoi.title)).font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(sau ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: sau ? .trailing : .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI
import AVKit

// ════════════════════════════════════════════════════════════════
// MÀN ĐỌC MỘT BÀI của khoá kiểu sách.
// "Bài tiếp/Bài trước" đổi bài TẠI CHỖ (không đẩy thêm màn) — và ScrollView mang
// `.id(bài)` nên bài mới luôn mở từ ĐẦU trang (bài học 23/08: ScrollView giữ vị
// trí cuộn khi nội dung đổi ⇒ bài mới mở ra ở cuối trang).
// ════════════════════════════════════════════════════════════════

struct BaiSachHocView: View {
    @ObservedObject var vm: SachHocVM
    @State var muc: MucDocSH
    #if DEBUG
    /// Màn soi: cuộn tới khối thứ n lúc mở (`CT_SACHHOC_CUON`).
    var cuonToi: Int? = nil
    #endif

    @State private var bai: BaiSH?
    @State private var loi: String?
    @State private var banCu = false
    /// Ngăn xếp thẻ chữ Hán đang mở (chạm chữ Hán trong bài; chip chữ khác ⇒ chồng thêm).
    @State private var chuHan: [String] = []
    @State private var moTraTu = false
    /// Bề ngang vùng cuộn — để bảng chia cột đúng ngay lượt dựng đầu (khỏi đo lại từng bảng).
    @State private var rongDoc: CGFloat = 0
    /// Nút ✍ trên thanh công cụ ⇒ chỉ số NHÓM của khối viết cần cuộn tới.
    @State private var nhayViet: Int?
    @Environment(\.openURL) private var moURL
    @AppStorage(CaiDatDocSH.furigana) private var furi = true
    @AppStorage(CaiDatDocSH.romaji) private var roma = true
    @AppStorage(CaiDatDocSH.coChu) private var tiLe = 1.0
    @AppStorage(CaiDatDocSH.tocDo) private var tocDo = 1.0
    #if os(iOS)
    /// "Viết lên bài" (GhiKhiHoc/VietDeBai). `@State`, KHÔNG `@StateObject`: đổi bút không được dựng lại cả bài.
    @State private var vietDe = PhienVietDe()
    #endif

    /// Màn đọc/viết tập trung ⇒ chủ đề mùa đứng yên khi màn này hiện (Shared/ChuDe).
    var body: some View {
        #if os(iOS)
        thanManYen.ghiKhiHoc(nguCanhGhi, vietDe: vietDe).nenMuaYen()
        #else
        thanManYen.nenMuaYen()
        #endif
    }

    #if os(iOS)
    /// Bài đang mở ⇒ trang Vở "Ghi khi học" của nó (Dekiru ⇒ JPD113/JPD123 theo số bài).
    private var nguCanhGhi: NguCanhGhi {
        NguCanhGhi.sachHoc(khoa: vm.khoaId, tenKhoa: vm.khoa?.tieuDe, baiId: muc.id, soBai: SachHocVM.soBai(muc.id),
                           tieuDe: PhanTichChuSH.tron(bai?.title ?? vm.meta(muc)?.title ?? ""))
    }
    #endif

    @ViewBuilder private var thanManYen: some View {
        #if DEBUG && os(iOS)
        let _ = DemBodySH.tang("BaiSachHocView")
        #endif
        ScrollViewReader { cuon in
            ScrollView {
                // LazyVStack: bài dài (Bài 0 có 10 khối viết tay × 10 ô PencilKit) chỉ dựng phần gần màn hình.
                // spacing 0 + phần tử đệm: khối lớn (bảng, khối viết, trắc nghiệm) trả về NHIỀU phần tử — mỗi
                // hàng một phần tử (`LatSH`) — để LazyVStack dựng dần theo hàng thay vì cả khối trong một khung
                // hình. Đo 23/10 (DoCuonSH, iPad Pro 11" ảo, cuộn đều 2500 pt/s lần đầu): khối viết 67 chữ
                // ~400 ms dựng một lượt, bảng 26 hàng ~75 ms, trắc nghiệm 33 câu ~300 ms ⇒ hitch ~480 ms/giây.
                LazyVStack(alignment: .leading, spacing: 0) {
                    dau.vietDe("dau")
                    if let bai {
                        let vd = NeoVideoSH.chia(bai)
                        if !vd.dauBai.isEmpty || !(bai.videos ?? []).isEmpty {
                            Color.clear.frame(height: 16)
                            khoiVideo(bai, dauBai: vd.dauBai)
                        }
                        #if DEBUG
                        if ProcessInfo.processInfo.environment["CT_SACHHOC_CHI"].map({ !$0.isEmpty }) == true { Color.clear.frame(height: 1500) }
                        #endif
                        ForEach(Array(nhom(bai).enumerated()), id: \.offset) { i, n in
                            // Phần tử đệm mang id "nhom-i" — neo cho ScrollViewReader (cuộn tới nhóm i). Id CHUỖI,
                            // không dùng số trần: phần tử lát của khối lớn cũng nằm thẳng trong LazyVStack này.
                            Color.clear.frame(height: 16).id("nhom-\(i)")
                            nhomView(n, video: vd.theoKhoi)
                        }
                        Color.clear.frame(height: 16)
                        cuoi
                    } else if let loi {
                        KhungLoiSH(loi: loi) { Task { await nap() } }
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .environment(\.rongNoiDungSH, max(0, min(720, rongDoc) - 32))
                #if os(iOS)
                // Chữ của khoá kiểu sách theo "Cỡ chữ" của màn (tiLe), KHÔNG theo Dynamic Type (ChuSH cỡ cố định).
                .environment(\.vietDe, NguCanhVietDe(phien: vietDe, coChu: CGFloat(tiLe)))
                #endif
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 60)
                #if DEBUG && os(iOS)
                // Màn soi: `CT_SACHHOC_DO=<pt/giây>` ⇒ tự cuộn đều cả bài và đo hitch (DoCuonSH.swift).
                .background {
                    if bai != nil, let v = ProcessInfo.processInfo.environment["CT_SACHHOC_DO"].flatMap(Double.init) {
                        MocDoCuonSH(ten: muc.id, tocDo: CGFloat(v)).frame(width: 1, height: 1)
                    }
                }
                #endif
                // Bề rộng đọc ~720pt căn giữa — iPad (dọc lẫn ngang) không thành dòng chữ dài cả màn.
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .id(muc)
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { rongDoc = g.size.width }
                    .onChange(of: g.size.width) { _, w in rongDoc = w }
            })
            .sheet(isPresented: Binding(get: { !chuHan.isEmpty }, set: { if !$0 { chuHan = [] } })) {
                NganChuHanSH(nganXep: $chuHan, baiDangHoc: SachHocVM.soBai(muc.id), vm: vm)
            }
            .onChange(of: nhayViet) { _, n in
                guard let n else { return }
                // LazyVStack chỉ ƯỚC LƯỢNG chiều cao phần chưa dựng ⇒ cuộn lại vài lượt cho tới đúng chỗ.
                withAnimation(.easeInOut(duration: 0.3)) { cuon.scrollTo("nhom-\(n)", anchor: .top) }
                for t in [0.4, 0.9] { DispatchQueue.main.asyncAfter(deadline: .now() + t) { cuon.scrollTo("nhom-\(n)", anchor: .top) } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { nhayViet = nil }
            }
            #if DEBUG
            .onChange(of: bai?.id) { _, _ in
                if let n = cuonToi, bai != nil {
                    // LazyVStack chỉ ước lượng chiều cao phần chưa dựng ⇒ cuộn vài lượt cho tới đúng chỗ.
                    for t in [0.6, 1.4, 2.4] { DispatchQueue.main.asyncAfter(deadline: .now() + t) { cuon.scrollTo("nhom-\(n)", anchor: .top) } }
                }
            }
            #endif
        }
        .environment(\.baiDangDocSH, muc.id)
        .environment(\.moChuHanSH, vm.khoa?.ngonNgu == "ja" && vm.khoa?.chuHan != nil ? { c in
            if chuHan.last != c { chuHan = Array((chuHan + [c]).suffix(20)) }
        } : nil)
        .environmentObject(vm)
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.meta(muc)?.nhan ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let bai, !khoiViet(bai).isEmpty {
                ToolbarItem(placement: .primaryAction) { nutViet(khoiViet(bai)) }
            }
            if vm.khoa?.tuVung != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button { moTraTu = true } label: { Image(systemName: "character.book.closed") }
                        .accessibilityLabel("Tra từ vựng cả khoá")
                }
            }
            ToolbarItem(placement: .primaryAction) { menuDoc }
        }
        .task(id: muc) { await nap() }
        .onDisappear {
            GiongSachHoc.chung.dung()
            #if os(iOS)
            MayThuSH.chung.huy()
            #endif
        }
        .sheet(isPresented: $moTraTu) {
            NavigationStack {
                ScrollView { TraTuVungSH().padding(16).frame(maxWidth: 720).frame(maxWidth: .infinity) }
                    .background(AppColors.backgroundPrimary)
                    .navigationTitle("Tra từ vựng")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { moTraTu = false } } }
            }
            .environmentObject(vm)
        }
        #if DEBUG
        .task {
            // Màn soi: `CT_SACHHOC_HAN=学` mở sẵn thẻ chữ Hán · `CT_SACHHOC_TRATU=1` mở sẵn ô tra từ.
            let env = ProcessInfo.processInfo.environment
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if let c = env["CT_SACHHOC_HAN"], !c.isEmpty { chuHan = [c] }
            if env["CT_SACHHOC_TRATU"] == "1" { moTraTu = true }
        }
        #endif
    }

    private func nap() async {
        bai = nil; loi = nil
        GiongSachHoc.chung.dung()
        do {
            let b = try await vm.noiDungMuc(muc)
            // Nạp SẴN thứ tự nét / thẻ chữ Hán (~650 KB mỗi tệp, giải mã ngoài luồng chính) ngay khi mở bài:
            // để khối viết tự nạp khi cuộn tới thì vm publish GIỮA lúc cuộn ⇒ mọi khối đang dựng vẽ lại
            // (đo 23/10: thêm ~100–200 ms hitch ở lượt cuộn đầu).
            if let b {
                if b.blocks.contains(where: { $0.loai == "write" }) {
                    Task { await vm.napNet() }
                    #if os(iOS)
                    KhoiDongPencilSH.mot()
                    #endif
                }
                if b.blocks.contains(where: { $0.loai == "hanlop" }) { Task { await vm.napChuHan() } }
            }
            bai = b
            if bai == nil { loi = "Không tìm thấy bài này trong khoá." }
        } catch {
            loi = error.localizedDescription
        }
    }

    // MARK: Đầu bài

    private var dau: some View {
        let m = vm.meta(muc)
        let kind = bai?.kind ?? m?.kind ?? "intro"
        let mau = mauLoaiSH(vm.khoa, kind)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(vm.khoa?.nhan(kind) ?? kind)
                    .font(.system(size: 12, weight: .bold)).foregroundColor(mau)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(mau.opacity(0.13)))
                if let phu = vm.khoa?.nhanLoaiPhu[kind], phu != vm.khoa?.nhan(kind) {
                    Text(phu).font(.system(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
                Spacer()
                if let bai, bai.minutes > 0 {
                    Label("~\(bai.minutes) phút", systemImage: "clock").font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
                }
            }
            ChuSH(text: bai?.title ?? m?.title ?? "", co: 25, dam: true)
            if let goal = bai?.goal, !goal.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "target").foregroundColor(mau).font(.system(size: 15, weight: .semibold)).padding(.top, 2)
                    ChuSH(text: goal, co: 16, mau: .phu)
                }
            }
            if banCu || vm.banLuu {
                Label("Đang xem bản đã lưu trên máy — không tới được máy chủ.", systemImage: "wifi.slash")
                    .font(.system(size: 12.5)).foregroundColor(AppColors.warning)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: Video gắn bài

    /// Đầu bài: video `dau-bai` + neo không khớp mục nào + YouTube tuyển chọn — phát tại chỗ.
    private func khoiVideo(_ b: BaiSH, dauBai: [VideoMucSH]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎬 VIDEO CỦA BÀI").font(.system(size: 11, weight: .heavy)).kerning(0.5).foregroundColor(AppColors.brandPink)
            ForEach(Array(dauBai.enumerated()), id: \.offset) { _, v in VideoNoiSH(v: v) }
            ForEach(Array((b.videos ?? []).enumerated()), id: \.offset) { _, v in
                if let src = v.src {
                    VideoNoiSH(v: VideoMucSH(src: src, tieuDe: v.note ?? v.credit ?? "Video", poster: v.poster, id: v.id, ghiChu: v.dur))
                } else {
                    VideoYouTubeSH(v: v)
                }
            }
        }
        .theKhoiSH(vien: AppColors.brandPink.opacity(0.35), nen: AppColors.brandPink.opacity(0.05))
    }

    // MARK: Khối, đóng khung ngữ pháp

    /// Kèm CHỈ SỐ khối gốc — để gắn video theo neo ngay dưới đúng tiêu đề `h`.
    private enum NhomKhoi { case le(Int, KhoiSH); case khung(Int, String, [KhoiSH]) }

    /// Bài ngữ pháp: mỗi mục (từ khối `h`) đóng KHUNG cùng công thức + ví dụ của nó; bài tập đứng ngoài
    /// khung — như `Blocks framed` của web.
    private func nhom(_ b: BaiSH) -> [NhomKhoi] {
        #if DEBUG
        // Màn soi đo: `CT_SACHHOC_CHI=table,write` ⇒ chỉ giữ các loại khối này (quy hitch về từng loại).
        if let chi = ProcessInfo.processInfo.environment["CT_SACHHOC_CHI"], !chi.isEmpty {
            let ds = Set(chi.split(separator: ",").map(String.init))
            return b.blocks.enumerated().filter { ds.contains($0.element.loai) }.map { NhomKhoi.le($0.offset, $0.element) }
        }
        #endif
        guard b.kind == "grammar" else { return b.blocks.enumerated().map { NhomKhoi.le($0.offset, $0.element) } }
        var out: [NhomKhoi] = []
        var dang: (Int, String, [KhoiSH])?
        func dong() { if let d = dang { out.append(.khung(d.0, d.1, d.2)); dang = nil } }
        for (i, k) in b.blocks.enumerated() {
            if case .h(let t) = k { dong(); dang = (i, t, []) }
            else if k.laBaiTap { dong(); out.append(.le(i, k)) }
            else if dang != nil { dang!.2.append(k) }
            else { out.append(.le(i, k)) }
        }
        dong()
        return out
    }

    @ViewBuilder
    private func videoMuc(_ i: Int, _ theo: [Int: [VideoMucSH]]) -> some View {
        if let vs = theo[i], !vs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(vs.enumerated()), id: \.offset) { _, v in VideoNoiSH(v: v) }
            }
        }
    }

    @ViewBuilder
    private func nhomView(_ n: NhomKhoi, video: [Int: [VideoMucSH]]) -> some View {
        switch n {
        case .le(let i, let k):
            // KHÔNG bọc VStack: khối "lát" (bảng, viết, trắc nghiệm) trả nhiều phần tử cho LazyVStack ngoài.
            khoiLe(i, k)
            if let vs = video[i], !vs.isEmpty {
                Color.clear.frame(height: 12)
                videoMuc(i, video)
            }
        case .khung(let i, let t, let ks) where ks.isEmpty:
            VStack(alignment: .leading, spacing: 12) {
                TieuDeSH(text: t)
                videoMuc(i, video)
            }
            .vietDe("n\(i)")
        case .khung(let i, let t, let ks):
            VStack(alignment: .leading, spacing: 14) {
                ChuSH(text: t, co: 19, dam: true, mau: .nhan)
                    .padding(.bottom, 2)
                videoMuc(i, video)
                ForEach(Array(ks.enumerated()), id: \.offset) { _, k in KhoiSHView(khoi: k) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppColors.primary.opacity(0.045)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1.2))
            .vietDe("n\(i)")
        }
    }

    /// Một khối đứng riêng ở mức cao nhất. Lớp "viết lên bài": khối lát (bảng, trắc nghiệm) gắn lớp theo TỪNG LÁT
    /// (tiền tố "n<i>"); khối có ô nhập/ô viết riêng (viết tay, điền, chép chính tả, bài luận) KHÔNG phủ lớp —
    /// Pencil ở đó là để viết vào ô; còn lại một lớp cho cả khối.
    @ViewBuilder
    private func khoiLe(_ i: Int, _ k: KhoiSH) -> some View {
        switch k {
        case .table, .mcq:
            KhoiSHView(khoi: k).environment(\.latKhoiSH, true).environment(\.phanNhomVietDe, "n\(i)")
        case .write, .quiz, .dictation, .essay:
            KhoiSHView(khoi: k).environment(\.latKhoiSH, true)
        default:
            KhoiSHView(khoi: k).environment(\.latKhoiSH, true).vietDe("n\(i)")
        }
    }

    // MARK: Cuối bài

    private var cuoi: some View {
        let xong = vm.daXong.contains(muc.id)
        let truoc = vm.ke(muc, buoc: -1)
        let sau = vm.ke(muc, buoc: 1)
        return VStack(spacing: 12) {
            if case .phu = muc {} else {
                Button {
                    vm.danhDau(muc.id, xong: !xong)
                } label: {
                    Label(xong ? "Đã học xong bài này" : "Đánh dấu đã học", systemImage: xong ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .foregroundColor(xong ? AppColors.success : .white)
                        .background(RoundedRectangle(cornerRadius: 14).fill(xong ? AppColors.success.opacity(0.14) : AppColors.success))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                if let truoc { nutChuyen(truoc, sau: false) }
                if let sau { nutChuyen(sau, sau: true) }
            }
        }
        .padding(.top, 16)
    }

    private func nutChuyen(_ m: MucDocSH, sau: Bool) -> some View {
        Button {
            if sau, !vm.daXong.contains(muc.id), muc != .gioiThieu { if case .phu = muc {} else { vm.danhDau(muc.id, xong: true) } }
            muc = m
        } label: {
            VStack(alignment: sau ? .trailing : .leading, spacing: 3) {
                Text(sau ? "Bài tiếp →" : "← Bài trước").font(.system(size: 12, weight: .bold)).foregroundColor(AppColors.primary)
                Text(vm.meta(m)?.title ?? "").font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(sau ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: sau ? .trailing : .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Lối tắt tới khối viết

    /// (chỉ số nhóm, tên khối) của các khối `write` — cùng chỉ số với id "nhom-i" của phần tử đệm.
    private func khoiViet(_ b: BaiSH) -> [(Int, String)] {
        nhom(b).enumerated().compactMap { i, n in
            if case .le(_, let k) = n, case .write(_, let title, _, _, _) = k { return (i, PhanTichChuSH.tron(title)) }
            return nil
        }
    }

    /// Khối viết nằm ở CUỐI bài dài — người học trên iPad báo không tìm thấy (23/10/2026).
    @ViewBuilder
    private func nutViet(_ ds: [(Int, String)]) -> some View {
        if ds.count == 1 {
            Button { nhayViet = ds[0].0 } label: { Image(systemName: "pencil.and.scribble") }
                .accessibilityLabel("Tới phần luyện viết")
        } else {
            Menu {
                ForEach(ds, id: \.0) { i, t in Button(t) { nhayViet = i } }
            } label: { Image(systemName: "pencil.and.scribble") }
                .accessibilityLabel("Tới phần luyện viết")
        }
    }

    // MARK: Cài đặt đọc

    private var menuDoc: some View {
        Menu {
            Section("Hiển thị") {
                Toggle(vm.khoa?.ngonNgu == "zh" ? "Pinyin trên chữ" : "Furigana (chữ nhỏ trên chữ Hán)", isOn: $furi)
                Toggle(vm.khoa?.ngonNgu == "zh" ? "Dòng pinyin" : "Romaji", isOn: $roma)
            }
            Section("Cỡ chữ") {
                Picker("Cỡ chữ", selection: $tiLe) {
                    Text("Nhỏ").tag(0.9)
                    Text("Vừa").tag(1.0)
                    Text("Lớn").tag(1.15)
                    Text("Rất lớn").tag(1.3)
                }
            }
            Section("Tốc độ nghe") {
                Picker("Tốc độ nghe", selection: $tocDo) {
                    Text("Chậm 0,75×").tag(0.75)
                    Text("Thường 1×").tag(1.0)
                    Text("Nhanh 1,25×").tag(1.25)
                }
            }
        } label: {
            Image(systemName: "textformat.size")
        }
        .accessibilityLabel("Cài đặt đọc")
    }
}

// MARK: - Phụ

struct KhungLoiSH: View {
    let loi: String
    let thuLai: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 34)).foregroundColor(AppColors.textTertiary)
            Text(loi).font(.system(size: 15)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
            NutSH(ten: "Thử lại", bieuTuong: "arrow.clockwise", hanhDong: thuLai)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

import SwiftUI
import Charts
import PhotosUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// ════════════════════════════════════════════════════════════════
// PHÒNG TƯ VẤN CHỌN NGÀNH HẸP — bản iOS của `app/academy/tu-van-nganh/page.tsx`
//
// Ba phần, tách thành ba thẻ vì màn điện thoại không đặt cạnh nhau được như web:
//  · CuongMini — chat AI, neo vào dữ liệu ngành thật ở backend (không bịa số),
//    kèm câu hỏi gợi ý + "Câu hỏi thường gặp" gộp từ câu người dùng đã hỏi.
//  · So sánh — ngành hẹp theo 2 thị trường 🇻🇳 / 🌏, biểu đồ + thẻ chi tiết.
//  · Thảo luận — bình luận có ảnh, thích, trả lời, báo cáo, xoá.
//
// Dữ liệu so sánh HIỆN CHỈ CÓ cho khối CNTT (SE) và Kinh doanh (BBA) — đo thật
// 23/09/2026: 12 thẻ, 6 + 6. Khối khác vẫn chat được, và màn nói thẳng điều đó.
// ════════════════════════════════════════════════════════════════

// MARK: - Mô hình (đối chiếu với GET /academy/advisor/catalog thật)

struct LienKetTuVan: Decodable, Hashable { let label: String; let url: String }

struct ThiTruong: Decodable {
    let demand: Int
    let salary: Int
    let salaryRange: String
    let note: String
    let sources: [LienKetTuVan]
}

struct NganhHepTuVan: Decodable, Identifiable {
    struct MauCode: Decodable { let language: String; let label: String; let code: String }
    let key: String
    let facultyId: String
    let majorId: String
    let comboId: String?
    let nameVi: String
    let icon: String
    let languages: [String]
    let builds: [String]
    let products: [String]
    let pros: [String]
    let cons: [String]
    let difficulty: Int
    let academyCourses: [String]
    /// 6/12 thẻ không có (khối Kinh doanh) — phải là Optional.
    let codeSample: MauCode?
    let vietnam: ThiTruong
    let global: ThiTruong
    let hiring: [LienKetTuVan]
    var id: String { key }
}

struct NhomCauHoi: Decodable, Hashable { let group: String; let icon: String; let questions: [String] }

struct DanhMucTuVan: Decodable {
    let specs: [NganhHepTuVan]
    let questions: [NhomCauHoi]
}

struct CauHoiThuongGap: Decodable, Hashable { let text: String; let askCount: Int }

struct BinhLuanTuVan: Decodable, Identifiable {
    struct NguoiViet: Decodable {
        let id: Int
        let username: String
        let fullName: String?
        let displayName: String?
        let avatarUrl: String?
        var ten: String { displayName ?? fullName ?? username }
    }
    let id: Int
    let content: String
    let imageUrl: String?
    var likesCount: Int
    let isEdited: Bool
    let createdAt: String
    let parentId: Int?
    let user: NguoiViet
    var replies: [BinhLuanTuVan]?
}

struct TinTuVan: Identifiable, Equatable {
    let id = UUID()
    let vaiTro: String   // "user" | "assistant"
    let noiDung: String
}

// MARK: - ViewModel

@MainActor
final class TuVanNganhVM: ObservableObject {
    let khoiId: String
    let nganhId: String?

    @Published var danhMuc: DanhMucTuVan?
    @Published var loiDanhMuc: String?
    @Published var faq: [CauHoiThuongGap] = []
    @Published var tin: [TinTuVan] = []
    @Published var dangHoi = false
    @Published var loiHoi: String?
    @Published var kyDangHoc = 0
    @Published var daBaoCaoTin: Set<UUID> = []

    @Published var binhLuan: [BinhLuanTuVan] = []
    @Published var dangTaiBL = true
    @Published var daThich: Set<Int> = []
    @Published var thongBao: String?

    init(khoiId: String, nganhId: String?) {
        self.khoiId = khoiId
        self.nganhId = nganhId
    }

    var theNganh: [NganhHepTuVan] { (danhMuc?.specs ?? []).filter { $0.facultyId == khoiId } }

    /// Môn đã học tới hết kỳ đang học — theo khung NỀN của ngành. Khối ngoài
    /// CNTT không có khung nền nên rỗng (web cũng vậy).
    var monDaHoc: [String] {
        guard kyDangHoc > 0 else { return [] }
        var kq: [String] = []
        for k in DanhMucNganh.shared.khung(khoiId, nganhId, nil) where k.ky <= kyDangHoc {
            for m in k.ma where !kq.contains(m) { kq.append(m) }
        }
        return kq
    }

    func taiDanhMuc() async {
        guard danhMuc == nil else { return }
        do {
            danhMuc = try await APIClient.shared.request(.tuVanDanhMuc)
        } catch {
            loiDanhMuc = error.localizedDescription
        }
    }

    func taiFaq() async {
        faq = (try? await APIClient.shared.request(.tuVanFaq(khoi: khoiId, nganh: nganhId))) ?? faq
    }

    func hoi(_ cauHoi: String) async {
        let q = cauHoi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !dangHoi else { return }
        let lichSu = tin.suffix(8).map { ["role": $0.vaiTro, "content": $0.noiDung] }
        tin.append(TinTuVan(vaiTro: "user", noiDung: q))
        dangHoi = true
        loiHoi = nil
        defer { dangHoi = false }
        let dm = DanhMucNganh.shared
        var than: [String: Any] = [
            "question": q, "facultyId": khoiId, "semester": kyDangHoc,
            "completedCourses": monDaHoc, "history": Array(lichSu),
        ]
        if let nganhId { than["majorId"] = nganhId }
        if let k = dm.khoi(khoiId) { than["facultyName"] = k.nameVi }
        if let n = dm.nganh(khoiId, nganhId) { than["majorName"] = n.nameVi }
        struct TraLoi: Decodable { let answer: String }
        do {
            let r: TraLoi = try await APIClient.shared.request(.tuVanHoi(than: than))
            tin.append(TinTuVan(vaiTro: "assistant", noiDung: r.answer))
            Haptics.xong()
            // Câu vừa hỏi có thể vừa lên "Câu hỏi thường gặp".
            try? await Task.sleep(for: .milliseconds(800))
            await taiFaq()
        } catch {
            // Bỏ câu hỏi hỏng ra khỏi khung — để nó lại là hỏi lại sẽ gửi trùng lịch sử.
            if tin.last?.vaiTro == "user" { tin.removeLast() }
            loiHoi = error.localizedDescription
            Haptics.hong()
        }
    }

    // MARK: Thảo luận

    func taiBinhLuan() async {
        dangTaiBL = true
        defer { dangTaiBL = false }
        if let ds: [BinhLuanTuVan] = try? await APIClient.shared.request(.tuVanBinhLuan(khoi: khoiId, nganh: nganhId)) {
            binhLuan = ds
        }
    }

    var tongBinhLuan: Int { binhLuan.reduce(0) { $0 + 1 + ($1.replies?.count ?? 0) } }

    func dang(noiDung: String, anh: Data?, traLoi: Int?) async -> Bool {
        do {
            var url: String?
            if let anh {
                url = try await APIClient.shared.upload(data: anh, fileName: "binh-luan.jpg", mimeType: "image/jpeg").url
            }
            var than: [String: Any] = ["facultyId": khoiId, "content": noiDung]
            if let nganhId { than["majorId"] = nganhId }
            if let url { than["imageUrl"] = url }
            if let traLoi { than["parentId"] = traLoi }
            try await APIClient.shared.send(.tuVanDangBinhLuan(than: than))
            await taiBinhLuan()
            Haptics.xong()
            return true
        } catch {
            thongBao = "Không đăng được: \(error.localizedDescription)"
            Haptics.hong()
            return false
        }
    }

    func thich(_ id: Int) async {
        struct KQ: Decodable { let liked: Bool; let likesCount: Int }
        do {
            let r: KQ = try await APIClient.shared.request(.tuVanThichBinhLuan(id: id))
            if r.liked { daThich.insert(id) } else { daThich.remove(id) }
            capNhat(id) { $0.likesCount = r.likesCount }
            Haptics.cham()
        } catch {
            thongBao = error.localizedDescription
        }
    }

    /// Báo cáo một câu trả lời của CuongMini (Apple 4.7). Gửi kèm câu hỏi đứng
    /// ngay trước để admin đọc được ngữ cảnh.
    func baoCaoTraLoi(_ t: TinTuVan) async {
        let i = tin.firstIndex(of: t) ?? 0
        let hoi = tin[..<i].last { $0.vaiTro == "user" }?.noiDung ?? ""
        do {
            try await APIClient.shared.send(.tuVanBaoCaoTraLoi(than: [
                "answer": t.noiDung, "question": hoi, "facultyId": khoiId,
            ]))
            daBaoCaoTin.insert(t.id)
            thongBao = "Đã gửi báo cáo. Cảm ơn bạn — admin sẽ xem lại câu trả lời này."
        } catch {
            thongBao = "Không gửi được báo cáo: \(error.localizedDescription)"
        }
    }

    // MARK: Ẩn bình luận (bộ lọc nội dung phía người xem — Apple 1.2)

    private static let khoaAn = "tu-van-binh-luan-da-an"
    @Published var daAn: Set<Int> = Set(UserDefaults.standard.array(forKey: TuVanNganhVM.khoaAn) as? [Int] ?? [])

    func an(_ id: Int) {
        daAn.insert(id)
        UserDefaults.standard.set(Array(daAn), forKey: Self.khoaAn)
    }

    func baoCao(_ id: Int) async {
        do {
            try await APIClient.shared.send(.tuVanBaoCaoBinhLuan(id: id))
            thongBao = "Đã gửi báo cáo. Cảm ơn bạn!"
        } catch {
            thongBao = error.localizedDescription
        }
    }

    func xoa(_ id: Int) async {
        do {
            try await APIClient.shared.send(.tuVanXoaBinhLuan(id: id))
            binhLuan = binhLuan.filter { $0.id != id }.map {
                var c = $0; c.replies = c.replies?.filter { $0.id != id }; return c
            }
        } catch {
            thongBao = "Không xoá được: \(error.localizedDescription)"
        }
    }

    private func capNhat(_ id: Int, _ sua: (inout BinhLuanTuVan) -> Void) {
        for i in binhLuan.indices {
            if binhLuan[i].id == id { sua(&binhLuan[i]); return }
            if let j = binhLuan[i].replies?.firstIndex(where: { $0.id == id }) {
                sua(&binhLuan[i].replies![j]); return
            }
        }
    }
}

// MARK: - Màn chính

struct TuVanNganhView: View {
    let khoiId: String
    let nganhId: String?
    /// "Quay lại chọn ngành hẹp".
    var khiChonNganhHep: () -> Void = {}

    @StateObject private var vm: TuVanNganhVM
    @ObservedObject private var appState = AppState.shared
    @State private var the: The = .tuVan
    @State private var thiTruong: ThiTruongChon = .vietnam

    enum The: String, CaseIterable { case tuVan = "CuongMini", soSanh = "So sánh", thaoLuan = "Thảo luận" }
    enum ThiTruongChon { case vietnam, global }

    init(khoiId: String, nganhId: String?, theBanDau: The = .tuVan, khiChonNganhHep: @escaping () -> Void = {}) {
        _the = State(initialValue: theBanDau)
        self.khoiId = khoiId
        self.nganhId = nganhId
        self.khiChonNganhHep = khiChonNganhHep
        _vm = StateObject(wrappedValue: TuVanNganhVM(khoiId: khoiId, nganhId: nganhId))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $the) {
                ForEach(The.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            switch the {
            case .tuVan: TheChatTuVan(vm: vm, daDangNhap: appState.isAuthenticated)
            case .soSanh: theSoSanh
            case .thaoLuan: TheThaoLuan(vm: vm, toi: appState.currentUser)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Tư vấn ngành hẹp")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Chọn ngành hẹp") { khiChonNganhHep() }
            }
        }
        .task {
            async let a: () = vm.taiDanhMuc()
            async let b: () = vm.taiFaq()
            async let c: () = vm.taiBinhLuan()
            _ = await (a, b, c)
        }
        .alert("Thông báo", isPresented: Binding(get: { vm.thongBao != nil }, set: { if !$0 { vm.thongBao = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.thongBao ?? "") }
    }

    // MARK: So sánh

    private var theSoSanh: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if vm.danhMuc == nil && vm.loiDanhMuc == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if let loi = vm.loiDanhMuc {
                    ErrorStateView(message: loi) { Task { await vm.taiDanhMuc() } }
                } else if vm.theNganh.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dữ liệu chi tiết đang được bổ sung cho khối này 🛠️")
                            .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                        Text("Phần so sánh (lương, nhu cầu, sản phẩm, cú pháp code) hiện có cho khối Công nghệ thông tin và Kinh doanh. Bạn vẫn hỏi CuongMini ở thẻ đầu để được tư vấn tổng quát cho khối \(DanhMucNganh.shared.khoi(khoiId)?.nameVi ?? "của bạn").")
                            .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(Spacing.md)
                    .background(AppColors.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                } else {
                    Picker("Thị trường", selection: $thiTruong) {
                        Text("🇻🇳 Việt Nam").tag(ThiTruongChon.vietnam)
                        Text("🌏 Toàn cầu").tag(ThiTruongChon.global)
                    }
                    .pickerStyle(.segmented)
                    Text("Thang định tính 1–5. Số & lương chính xác xem nguồn thống kê trong mỗi thẻ.")
                        .font(.caption).foregroundColor(AppColors.textTertiary)
                    bieuDo
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: Spacing.md, alignment: .top)],
                              spacing: Spacing.md) {
                        ForEach(vm.theNganh) { TheNganhHepTuVan(s: $0, tt: thiTruong == .vietnam ? $0.vietnam : $0.global,
                                                                 laVN: thiTruong == .vietnam) }
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
    }

    private var bieuDo: some View {
        struct Cot: Identifiable { let id = UUID(); let ten: String; let loai: String; let gt: Int }
        let cot = vm.theNganh.flatMap { s -> [Cot] in
            let t = thiTruong == .vietnam ? s.vietnam : s.global
            let ten = String((s.nameVi.components(separatedBy: "(").first ?? s.nameVi)
                .trimmingCharacters(in: .whitespaces).prefix(14))
            return [Cot(ten: ten, loai: "Nhu cầu", gt: t.demand), Cot(ten: ten, loai: "Lương", gt: t.salary)]
        }
        return Chart(cot) { c in
            BarMark(x: .value("Ngành", c.ten), y: .value("Điểm", c.gt))
                .foregroundStyle(by: .value("Chỉ số", c.loai))
                .position(by: .value("Chỉ số", c.loai))
                .annotation(position: .top) {
                    Text("\(c.gt)").font(.system(size: 9)).foregroundColor(AppColors.textTertiary)
                }
        }
        .chartForegroundStyleScale(["Nhu cầu": Color(hex: 0x22D3EE), "Lương": Color(hex: 0xA3E635)])
        .chartYScale(domain: 0...5.5)
        .chartYAxis { AxisMarks(values: [0, 1, 2, 3, 4, 5]) }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(orientation: .verticalReversed).font(.system(size: 9))
            }
        }
        .frame(height: 280)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}

// MARK: - Thẻ chat CuongMini

private struct TheChatTuVan: View {
    @ObservedObject var vm: TuVanNganhVM
    let daDangNhap: Bool
    @State private var nhap = ""
    @State private var tinCanBaoCao: TinTuVan?
    @FocusState private var dangGo: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { cuon in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.md) {
                        chonKy
                        if vm.tin.isEmpty { loiChao }
                        ForEach(vm.tin) { t in bongBong(t).id(t.id) }
                        if vm.dangHoi {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("CuongMini đang suy nghĩ…").font(.bodySmall).foregroundColor(AppColors.textTertiary)
                            }
                            .id("dangHoi")
                        }
                        if let loi = vm.loiHoi {
                            Label(loi, systemImage: "exclamationmark.triangle.fill")
                                .font(.bodySmall).foregroundColor(AppColors.error)
                        }
                        if !vm.faq.isEmpty && !vm.tin.isEmpty { cauHoiThuongGap }
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.tin) { _, t in
                    if let cuoi = t.last { withAnimation { cuon.scrollTo(cuoi.id, anchor: .top) } }
                }
                .onChange(of: vm.dangHoi) { _, dang in
                    if dang { withAnimation { cuon.scrollTo("dangHoi", anchor: .bottom) } }
                }
            }
            oNhap
        }
        .alert("Báo cáo câu trả lời", isPresented: Binding(get: { tinCanBaoCao != nil },
                                                          set: { if !$0 { tinCanBaoCao = nil } })) {
            Button("Gửi báo cáo", role: .destructive) {
                if let t = tinCanBaoCao { Task { await vm.baoCaoTraLoi(t) } }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Câu trả lời này sai, gây hiểu lầm, hoặc không phù hợp? Báo cho chúng tôi để xem lại.")
        }
    }

    private var chonKy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Bạn đang học kỳ mấy?", systemImage: "graduationcap")
                .font(.bodySmall).foregroundColor(AppColors.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...9, id: \.self) { k in
                        Button {
                            Haptics.cham()
                            vm.kyDangHoc = vm.kyDangHoc == k ? 0 : k
                        } label: {
                            Text("Kỳ \(k)")
                                .font(.buttonSmall)
                                .foregroundColor(vm.kyDangHoc == k ? .white : AppColors.textSecondary)
                                .padding(.horizontal, 12).frame(minHeight: 36)
                                .background(vm.kyDangHoc == k ? AppColors.primary : AppColors.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if vm.kyDangHoc > 0 && !vm.monDaHoc.isEmpty {
                Text("→ đã học \(vm.monDaHoc.count) môn, CuongMini sẽ nối kiến thức này cho bạn.")
                    .font(.caption).foregroundColor(AppColors.textTertiary)
            }
        }
    }

    private var loiChao: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: 10) {
                Text("🤖").font(.system(size: 28))
                Text("Chào bạn 👋 Mình là **CuongMini**, giúp bạn chọn ngành hẹp hợp với thế mạnh, thị trường và các môn bạn đã học. Chạm một câu gợi ý hoặc tự nhập nhé:")
                    .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(vm.danhMuc?.questions ?? [], id: \.self) { g in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(g.icon) \(g.group.uppercased())").font(.captionBold).foregroundColor(AppColors.textTertiary)
                    ForEach(g.questions, id: \.self) { q in nutCauHoi(q, phu: nil) }
                }
            }
            if !vm.faq.isEmpty { cauHoiThuongGap }
        }
    }

    private var cauHoiThuongGap: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("CÂU HỎI THƯỜNG GẶP", systemImage: "questionmark.circle")
                .font(.captionBold).foregroundColor(AppColors.secondary)
            Text("Gộp từ câu các bạn đã hỏi CuongMini. Chạm để hỏi lại ngay.")
                .font(.caption).foregroundColor(AppColors.textTertiary)
            ForEach(vm.faq, id: \.self) { f in
                nutCauHoi(f.text, phu: f.askCount > 1 ? "\(f.askCount) lượt hỏi" : nil)
            }
        }
    }

    private func nutCauHoi(_ q: String, phu: String?) -> some View {
        Button { gui(q) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(q).font(.bodyMedium).foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                if let phu { Text(phu).font(.caption).foregroundColor(AppColors.textTertiary) }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.backgroundCard)
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).stroke(AppColors.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .disabled(vm.dangHoi)
    }

    @ViewBuilder private func bongBong(_ t: TinTuVan) -> some View {
        if t.vaiTro == "user" {
            HStack {
                Spacer(minLength: 48)
                Text(t.noiDung)
                    .font(.bodyLarge).foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(AppColors.primary.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .textSelection(.enabled)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                NoiDungMarkdown(noiDung: t.noiDung)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .textSelection(.enabled)
                // Apple 4.7: chỗ nào AI trả lời thì phải báo cáo được câu trả lời đó.
                if vm.daBaoCaoTin.contains(t.id) {
                    Label("Đã báo cáo", systemImage: "checkmark")
                        .font(.caption).foregroundColor(AppColors.textTertiary)
                } else {
                    Button { tinCanBaoCao = t } label: {
                        Label("Báo cáo câu trả lời", systemImage: "flag")
                            .font(.caption).foregroundColor(AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var oNhap: some View {
        VStack(spacing: 0) {
            Divider()
            if daDangNhap {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Hỏi CuongMini… (vd: mình giỏi toán, hợp ngành hẹp nào?)", text: $nhap, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($dangGo)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(AppColors.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Button { gui(nhap) } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                            .foregroundColor(nhap.trimmingCharacters(in: .whitespaces).isEmpty || vm.dangHoi
                                             ? AppColors.textTertiary : AppColors.primary)
                    }
                    .disabled(nhap.trimmingCharacters(in: .whitespaces).isEmpty || vm.dangHoi)
                    .accessibilityLabel("Gửi")
                }
                .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
            } else {
                Text("Đăng nhập để chat với CuongMini.")
                    .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity).padding(Spacing.md)
            }
        }
        .background(AppColors.backgroundSecondary)
    }

    private func gui(_ q: String) {
        guard daDangNhap else { vm.loiHoi = "Đăng nhập để chat với CuongMini nhé."; return }
        nhap = ""
        Task { await vm.hoi(q) }
    }
}

// MARK: - Thẻ so sánh một ngành hẹp

private struct TheNganhHepTuVan: View {
    let s: NganhHepTuVan
    let tt: ThiTruong
    let laVN: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 10) {
                Text(s.icon).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.nameVi).font(.titleSmall).foregroundColor(AppColors.textPrimary)
                    LuoiChip(khoangCach: 4) {
                        ForEach(s.languages, id: \.self) { l in
                            Text(l).font(.system(size: 10, weight: .medium)).foregroundColor(AppColors.primary)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(AppColors.primary.opacity(0.12)).clipShape(Capsule())
                        }
                    }
                }
            }

            VStack(spacing: 6) {
                thuoc("Nhu cầu tuyển", tt.demand, Color(hex: 0x22D3EE))
                thuoc("Mặt bằng lương", tt.salary, Color(hex: 0xA3E635))
                thuoc("Độ khó", s.difficulty, Color(hex: 0xF0ABFC))
            }
            Text("💰 **\(tt.salaryRange)**").font(.bodyMedium).foregroundColor(AppColors.textSecondary)
            Text("“\(tt.note)”").font(.caption).italic().foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            muc("LÀM RA ĐƯỢC") {
                LuoiChip(khoangCach: 5) {
                    ForEach(s.builds, id: \.self) { b in
                        Text(b).font(.caption).foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(AppColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
            muc("SẢN PHẨM NỔI TIẾNG DÙNG HƯỚNG NÀY") {
                Text(s.products.joined(separator: " · ")).font(.bodySmall).foregroundColor(AppColors.textSecondary)
            }
            HStack(alignment: .top, spacing: Spacing.md) {
                danhSach("Ưu điểm", s.pros, AppColors.success)
                danhSach("Nhược điểm", s.cons, AppColors.brandPink)
            }
            if let m = s.codeSample {
                muc("CÚ PHÁP — \(m.label.uppercased())") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(m.code)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(hex: 0xD4D4D4))
                            .padding(12)
                    }
                    .background(Color(hex: 0x0B1020))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            muc("MÔN ACADEMY TIÊU BIỂU") {
                LuoiChip(khoangCach: 5) {
                    ForEach(s.academyCourses, id: \.self) { c in
                        Text(c).font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(AppColors.secondary.opacity(0.12)).clipShape(Capsule())
                    }
                }
            }
            muc("NƠI THƯỜNG TUYỂN") { lienKet(s.hiring) }
            Divider()
            muc("📊 NGUỒN THỐNG KÊ (\(laVN ? "VIỆT NAM" : "TOÀN CẦU"))") { lienKet(tt.sources) }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    private func thuoc(_ nhan: String, _ gt: Int, _ mau: Color) -> some View {
        HStack {
            Text(nhan).font(.caption).foregroundColor(AppColors.textTertiary)
            Spacer()
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { i in
                    Capsule().fill(i <= gt ? mau : AppColors.border).frame(width: 18, height: 5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(nhan) \(gt) trên 5")
    }

    private func muc<C: View>(_ tieuDe: String, @ViewBuilder _ noiDung: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(tieuDe).font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            noiDung()
        }
    }

    private func danhSach(_ tieuDe: String, _ ds: [String], _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tieuDe).font(.captionBold).foregroundColor(mau)
            ForEach(ds, id: \.self) { d in
                Text("• \(d)").font(.caption).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lienKet(_ ds: [LienKetTuVan]) -> some View {
        LuoiChip(khoangCach: 5) {
            ForEach(ds, id: \.self) { l in
                if let u = URL(string: l.url) {
                    Link(destination: u) {
                        HStack(spacing: 3) {
                            Text(l.label)
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppColors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
        }
    }
}

// MARK: - Thẻ thảo luận

private struct TheThaoLuan: View {
    @ObservedObject var vm: TuVanNganhVM
    let toi: User?

    @State private var nhap = ""
    @State private var anhChon: PhotosPickerItem?
    @State private var anh: Data?
    @State private var traLoi: BinhLuanTuVan?
    @State private var dangGui = false
    @State private var canXoa: Int?
    @State private var canChan: BinhLuanTuVan.NguoiViet?
    @ObservedObject private var kiemDuyet = ModerationStore.shared

    /// Bỏ bình luận của người đã chặn và bình luận đã ẩn — cả ở tầng trả lời.
    private var dsHien: [BinhLuanTuVan] {
        vm.binhLuan
            .filter { !kiemDuyet.blockedUserIds.contains($0.user.id) && !vm.daAn.contains($0.id) }
            .map { c in
                var c = c
                c.replies = c.replies?.filter { !kiemDuyet.blockedUserIds.contains($0.user.id) && !vm.daAn.contains($0.id) }
                return c
            }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("💬 Thảo luận & đánh giá (\(vm.tongBinhLuan))")
                        .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                    Text("Chia sẻ trải nghiệm, góp ý, đặt câu hỏi cho cộng đồng. Lịch sự & đúng chủ đề nhé.")
                        .font(.caption).foregroundColor(AppColors.textTertiary)
                }
                soan
                if vm.dangTaiBL && vm.binhLuan.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                } else if dsHien.isEmpty {
                    Text("Chưa có bình luận nào. Hãy là người đầu tiên chia sẻ! ✨")
                        .font(.bodyMedium).foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.lg)
                } else {
                    ForEach(dsHien) { c in
                        motBinhLuan(c, laTraLoi: false)
                        ForEach(c.replies ?? []) { r in motBinhLuan(r, laTraLoi: true) }
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await vm.taiBinhLuan() }
        .onChange(of: anhChon) { _, muc in
            Task {
                guard let muc, let d = try? await muc.loadTransferable(type: Data.self) else { return }
                anh = nenAnh(d)
            }
        }
        .confirmationDialog("Chặn \(canChan?.ten ?? "")?", isPresented: Binding(get: { canChan != nil }, set: { if !$0 { canChan = nil } }),
                            titleVisibility: .visible) {
            Button("Chặn", role: .destructive) {
                if let u = canChan {
                    Task {
                        do { try await kiemDuyet.block(userId: u.id); Haptics.xong() }
                        catch { vm.thongBao = "Không chặn được: \(error.localizedDescription)" }
                    }
                }
            }
        } message: {
            Text("Bạn sẽ không thấy bình luận của người này nữa. Bỏ chặn trong Cài đặt → Danh sách chặn.")
        }
        .confirmationDialog("Xoá bình luận này?", isPresented: Binding(get: { canXoa != nil }, set: { if !$0 { canXoa = nil } }),
                            titleVisibility: .visible) {
            Button("Xoá", role: .destructive) { if let id = canXoa { Task { await vm.xoa(id) } } }
        }
    }

    @ViewBuilder private var soan: some View {
        if toi == nil {
            Text("Đăng nhập để tham gia thảo luận.")
                .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity).padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let traLoi {
                    HStack(spacing: 6) {
                        Text("Đang trả lời **\(traLoi.user.ten)**").font(.caption).foregroundColor(AppColors.textSecondary)
                        Button { self.traLoi = nil } label: { Image(systemName: "xmark.circle.fill") }
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                TextField("Viết bình luận, đánh giá hoặc góp ý…", text: $nhap, axis: .vertical)
                    .lineLimit(2...6)
                    .padding(10)
                    .background(AppColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                #if os(iOS)
                if let anh, let img = UIImage(data: anh) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button { self.anh = nil; anhChon = nil } label: {
                            Image(systemName: "xmark.circle.fill").font(.title3)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .padding(4)
                    }
                }
                #endif
                HStack {
                    PhotosPicker(selection: $anhChon, matching: .images) {
                        Label("Ảnh", systemImage: "photo.badge.plus").font(.buttonSmall)
                    }
                    Spacer()
                    Button {
                        Task {
                            dangGui = true
                            let ok = await vm.dang(noiDung: nhap.trimmingCharacters(in: .whitespacesAndNewlines),
                                                   anh: anh, traLoi: traLoi?.id)
                            dangGui = false
                            if ok { nhap = ""; anh = nil; anhChon = nil; traLoi = nil }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if dangGui { ProgressView().tint(.white) } else { Image(systemName: "paperplane.fill") }
                            Text("Gửi")
                        }
                        .font(.buttonSmall).foregroundColor(.white)
                        .padding(.horizontal, 16).frame(minHeight: 38)
                        .background(AppColors.brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(dangGui || (nhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && anh == nil))
                    .opacity(dangGui || (nhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && anh == nil) ? 0.45 : 1)
                }
            }
            .padding(Spacing.md)
            .background(AppColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }

    private func motBinhLuan(_ c: BinhLuanTuVan, laTraLoi: Bool) -> some View {
        let cuaToi = toi?.id == c.user.id
        let thich = vm.daThich.contains(c.id)
        return HStack(alignment: .top, spacing: 10) {
            UserAvatarView(url: c.user.avatarUrl, size: laTraLoi ? 30 : 38)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(c.user.ten).font(.captionBold).foregroundColor(AppColors.textPrimary)
                        Text(TimeFormatter.formatTimeAgo(c.createdAt)).font(.caption).foregroundColor(AppColors.textTertiary)
                        if c.isEdited { Text("(đã sửa)").font(.system(size: 10)).foregroundColor(AppColors.textTertiary) }
                    }
                    if !c.content.isEmpty {
                        Text(c.content).font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    if let u = c.imageUrl, let url = URL(string: u) {
                        #if canImport(Kingfisher)
                        KFImage(url).resizable().scaledToFit().frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        #else
                        AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
                            .frame(maxHeight: 260)
                        #endif
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(AppColors.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 16) {
                    Button { Task { await vm.thich(c.id) } } label: {
                        Label(c.likesCount > 0 ? "\(c.likesCount)" : "Thích", systemImage: thich ? "heart.fill" : "heart")
                            .foregroundColor(thich ? AppColors.love : AppColors.textTertiary)
                    }
                    if !laTraLoi {
                        Button { traLoi = c } label: { Label("Trả lời", systemImage: "bubble.left") }
                    }
                    Menu {
                        Button { Task { await vm.baoCao(c.id) } } label: { Label("Báo cáo", systemImage: "flag") }
                        Button { vm.an(c.id) } label: { Label("Ẩn bình luận này", systemImage: "eye.slash") }
                        if !cuaToi {
                            Button(role: .destructive) { canChan = c.user } label: {
                                Label("Chặn \(c.user.ten)", systemImage: "hand.raised")
                            }
                        }
                        if cuaToi {
                            Button(role: .destructive) { canXoa = c.id } label: { Label("Xoá", systemImage: "trash") }
                        }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 30, height: 24)
                    }
                    .accessibilityLabel("Tuỳ chọn khác")
                }
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
                .buttonStyle(.plain)
                .disabled(toi == nil)
            }
        }
        .padding(.leading, laTraLoi ? 40 : 0)
    }

    /// Ảnh chụp từ máy dễ tới 5–10 MB (backend trần 8 MB). Thu về 1600px, JPEG 0.8.
    private func nenAnh(_ d: Data) -> Data {
        #if os(iOS)
        guard let img = UIImage(data: d) else { return d }
        let canh = max(img.size.width, img.size.height)
        let tiLe = min(1, 1600 / max(canh, 1))
        let co = CGSize(width: img.size.width * tiLe, height: img.size.height * tiLe)
        let moi = UIGraphicsImageRenderer(size: co).image { _ in img.draw(in: CGRect(origin: .zero, size: co)) }
        return moi.jpegData(compressionQuality: 0.8) ?? d
        #else
        return d
        #endif
    }
}

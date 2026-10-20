import SwiftUI

// MARK: - Trợ lý AI của dự án (mentor) — màn hội thoại
//
// App Store:
//   · 5.1.2(i) — câu hỏi + dữ liệu dự án liên quan được GỬI cho nhà cung cấp mô hình AI bên thứ ba ⇒ trước câu hỏi
//     ĐẦU TIÊN hiện `DongYAICTW` (nói rõ gửi gì, cho ai, để làm gì) và chỉ hỏi khi người dùng bấm đồng ý. Rút lại được
//     ở Account › Privacy.
//   · 4.7 / 1.2 — mọi câu trả lời gắn nhãn "AI-generated", có nút Report (ẩn ngay cho người báo cáo) + Copy; câu hỏi
//     của đồng đội trong hội thoại chung: nhấn giữ ⇒ Report / Block.
//   · 3.1.1 — hết hạn mức: KHÔNG hiện câu "Upgrade to Pro" của máy chủ; link trong câu trả lời trỏ tới trang mua bị chặn.
// Link trong câu trả lời: `/work/<ws>/<KEY>/issue/<n>` ⇒ đẩy thẻ ngay trong ngăn xếp này; `/work/...` khác ⇒
// `DinhTuyenCTW` (đúng mô-đun); trang khác của cuongthai.com ⇒ trình duyệt trong app có chốt 3.1.1; link ngoài ⇒ Safari.

@MainActor
final class TroLyAIVM: ObservableObject {
    let pid: Int
    @Published var dsHoiThoai: [CTWAIHoiThoai] = []
    @Published var hoiThoai: CTWAIHoiThoai?
    @Published var dangCho: String?
    @Published var cauDangHoi: String?
    @Published var loi: String?
    /// Lỗi 502/503/mạng của lượt vừa rồi — hiện dải lỗi có nút "Ask again".
    @Published var loiLuot: String?
    @Published var taiDs = true
    @Published var hanMuc: CTWAIHanMuc?
    @Published var dangApDung: Set<String> = []
    private var viec: Task<Void, Never>?

    init(pid: Int) { self.pid = pid }

    var tinNhan: [CTWAITinNhan] { hoiThoai?.messages ?? [] }
    /// Câu hỏi gần nhất chưa được trả lời (máy chủ đã lưu kèm `error`).
    var cauHong: CTWAITinNhan? { tinNhan.last { $0.role == "user" && $0.error != nil } }

    func taiDanhSach() async {
        defer { taiDs = false }
        if let ds: [CTWAIHoiThoai] = try? await APIClient.shared.request(CTWAPI.aiDsHoiThoai(pid: pid)) { dsHoiThoai = ds }
        if hanMuc == nil { hanMuc = try? await APIClient.shared.request(CTWAPI.aiHanMuc()) }
    }

    func mo(_ id: Int) async {
        do {
            let t: CTWAIHoiThoai = try await APIClient.shared.request(CTWAPI.aiHoiThoai(pid: pid, id: id))
            hoiThoai = t
            loiLuot = nil
        } catch {
            loi = TroLyAICTW.loi(error)
        }
    }

    func moi() {
        viec?.cancel()
        hoiThoai = nil
        loiLuot = nil
        cauDangHoi = nil
        dangCho = nil
    }

    func hoi(_ chu: String, rieng: Bool) async -> Bool {
        let cau = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cau.isEmpty, dangCho == nil else { return true }
        loiLuot = nil
        cauDangHoi = cau
        dangCho = String(localized: "Reading the project…")
        defer { dangCho = nil; cauDangHoi = nil; tienDo = nil; xoaNhap() }
        var tid = hoiThoai?.id
        do {
            if tid == nil {
                let t: CTWAIHoiThoai = try await APIClient.shared.request(CTWAPI.aiTaoHoiThoai(pid: pid, tieuDe: cau, rieng: rieng))
                hoiThoai = t
                tid = t.id
            }
            guard let tid else { return false }
            // Bản stream trước; máy chủ chưa có tuyến ⇒ lặng lẽ về `/ai/chat` (và nhớ trong phiên).
            if !LuongAICTW.khongCoLuong {
                do {
                    try await chayLuong(LuongAICTW.than(cauHoi: cau, threadId: tid), tid: tid)
                    CTWRung.thanhCong()
                    return true
                } catch LoiLuongAI.khongHoTro {
                    xoaNhap()
                }
            }
            let kq: CTWAIKetQua = try await APIClient.shared.request(CTWAPI.aiHoi(pid: pid, cauHoi: cau, threadId: tid))
            if let q = kq.quota { hanMuc = q }
            await mo(tid)
            CTWRung.thanhCong()
            return true
        } catch is CancellationError {
            // Người dùng bấm Dừng / rời màn: máy chủ đánh dấu câu hỏi lỗi ⇒ nạp lại để thấy nút "Ask again".
            if let tid { await moLang(tid) }
            return true
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                if let tid { await moLang(tid) }
                return true
            }
            CTWRung.loi()
            // Máy chủ LƯU câu hỏi trước khi gọi AI ⇒ có trong hội thoại (kèm nút Ask again). Không có ⇒ trả lại ô soạn.
            // ⚠️ Nạp lại TRƯỚC rồi mới đặt `loiLuot` — `mo()` xoá `loiLuot` (đã dính: nút Ask again biến mất ngay).
            if let tid { await mo(tid) }
            loiLuot = TroLyAICTW.loi(error)
            let daLuu = tinNhan.suffix(3).contains { $0.role == "user" && $0.content == cau }
            return daLuu
        }
    }

    func hoiLai(_ m: CTWAITinNhan) async {
        guard dangCho == nil, let tid = hoiThoai?.id else { return }
        loiLuot = nil
        dangCho = String(localized: "Asking again…")
        defer { dangCho = nil; tienDo = nil; xoaNhap() }
        var loiMoi: String?
        do {
            var xong = false
            if !LuongAICTW.khongCoLuong {
                do {
                    try await chayLuong(LuongAICTW.than(cauHoi: m.content.isEmpty ? "retry" : m.content, threadId: tid, hoiLai: m.id), tid: tid)
                    xong = true
                } catch LoiLuongAI.khongHoTro {
                    xoaNhap()
                }
            }
            if !xong {
                let kq: CTWAIKetQua = try await APIClient.shared.request(CTWAPI.aiHoiLai(pid: pid, mid: m.id))
                if let q = kq.quota { hanMuc = q }
            }
            CTWRung.thanhCong()
        } catch is CancellationError {
        } catch {
            if !(Task.isCancelled || (error as? URLError)?.code == .cancelled) {
                CTWRung.loi()
                loiMoi = TroLyAICTW.loi(error)
            }
        }
        await moLang(tid)
        loiLuot = loiMoi
    }

    // MARK: Luồng (SSE)

    /// Tiến độ đang hiện ("Đang đọc LFD-75, Docs #3…", "Đang nghĩ…") — nil khi chưa có sự kiện nào.
    @Published var tienDo: SuKienAICTW?
    /// Bản nháp Markdown đang chạy — cập nhật tối đa ~12 lần/giây (dựng lại markdown mỗi mẩu thì giật).
    @Published private(set) var banNhap = ""
    /// Mục đang đọc của sự kiện `reading` gần nhất (chip dưới dòng trạng thái).
    var docMuc: [String] {
        if case .doc(_, let m)? = tienDo { return Array(m.prefix(6)) }
        return []
    }
    private var nhapTho = ""
    private var henDay: Task<Void, Never>?
    private var lanDayCuoi = Date.distantPast
    /// Lượt hỏi đang chạy — `dung()` huỷ nó (đóng kết nối ⇒ máy chủ thôi gọi model).
    var luot: Task<Void, Never>?

    func dung() {
        luot?.cancel()
    }

    #if DEBUG
    /// Đặt trạng thái lượt hỏi đứng yên (chụp màn) — không gọi mạng.
    func datThu(cau: String, tienDo: SuKienAICTW?, nhap: String) {
        cauDangHoi = cau
        self.tienDo = tienDo
        dangCho = tienDo.flatMap(LuongAICTW.nhan) ?? String(localized: "Writing the answer…")
        nhapTho = nhap
        banNhap = nhap
    }
    #endif

    private func xoaNhap() {
        henDay?.cancel(); henDay = nil
        nhapTho = ""
        if !banNhap.isEmpty { banNhap = "" }
    }

    private func dayNhap(ngay: Bool = false) {
        let bayGio = Date()
        if ngay || bayGio.timeIntervalSince(lanDayCuoi) >= 0.08 {
            henDay?.cancel(); henDay = nil
            lanDayCuoi = bayGio
            banNhap = nhapTho
            return
        }
        guard henDay == nil else { return }
        henDay = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self, !Task.isCancelled else { return }
            self.henDay = nil
            self.lanDayCuoi = Date()
            self.banNhap = self.nhapTho
        }
    }

    /// Chạy một lượt stream tới `done` (ghép câu hỏi + câu trả lời vào hội thoại tại chỗ, không nạp lại) hoặc ném lỗi.
    private func chayLuong(_ than: [String: Any], tid: Int) async throws {
        for try await s in LuongAICTW.mo(pid: pid, than: than) {
            switch s {
            case .chuanBi, .doc, .nghi, .kiemTra:
                tienDo = s
                if let n = LuongAICTW.nhan(s) { dangCho = n }
            case .manh(let t):
                if tienDo != nil { tienDo = nil; dangCho = String(localized: "Writing the answer…") }
                nhapTho += t
                dayNhap()
            case .xoaNhap:
                nhapTho = ""
                dayNhap(ngay: true)
            case .xong(let d):
                let kq = try JSONDecoder().decode(CTWAIKetQua.self, from: d)
                if let q = kq.quota { hanMuc = q }
                if let r = kq.reply { nhapTho = r; dayNhap(ngay: true) }
                ghep(kq, tid: tid)
                return
            case .loi(let ma, let m, _):
                throw APIError.coMa(ma: ma, thongDiep: m)
            }
        }
        throw LoiLuongAI.dutGiuaChung
    }

    /// Ghép `question` + `answer` của `done` vào hội thoại đang mở (đúng dữ liệu máy chủ đã lưu) — khỏi nạp lại cả hội thoại.
    private func ghep(_ kq: CTWAIKetQua, tid: Int) {
        guard var t = hoiThoai, t.id == tid else { return }
        var ms = t.messages ?? []
        for m in [kq.question, kq.answer].compactMap({ $0 }) {
            if let i = ms.firstIndex(where: { $0.id == m.id }) { ms[i] = m } else { ms.append(m) }
        }
        t.messages = ms
        t.messageCount = ms.count
        hoiThoai = t
        if kq.answer == nil { Task { await mo(tid) } }
    }

    /// Nạp lại hội thoại mà không đè lỗi đang hiện bằng thông báo lỗi tải.
    private func moLang(_ tid: Int) async {
        if let t: CTWAIHoiThoai = try? await APIClient.shared.request(CTWAPI.aiHoiThoai(pid: pid, id: tid)) { hoiThoai = t }
    }

    func apDung(_ m: CTWAITinNhan, _ d: CTWAIDeXuat) async {
        let k = "\(m.id)-\(d.index)"
        dangApDung.insert(k)
        defer { dangApDung.remove(k) }
        do {
            let _: CTWAIDeXuat = try await APIClient.shared.request(CTWAPI.aiApDung(pid: pid, mid: m.id, idx: d.index))
            CTWRung.thanhCong()
        } catch {
            loi = TroLyAICTW.loi(error)
        }
        if let tid = hoiThoai?.id { await mo(tid) }
    }

    func boQua(_ m: CTWAITinNhan, _ d: CTWAIDeXuat) async {
        do {
            let _: CTWAIDeXuat = try await APIClient.shared.request(CTWAPI.aiBoQua(pid: pid, mid: m.id, idx: d.index))
        } catch { loi = TroLyAICTW.loi(error) }
        if let tid = hoiThoai?.id { await mo(tid) }
    }

    func xoa(_ t: CTWAIHoiThoai) async {
        do {
            try await APIClient.shared.send(CTWAPI.aiXoaHoiThoai(pid: pid, id: t.id))
            if hoiThoai?.id == t.id { moi() }
            await taiDanhSach()
        } catch { loi = TroLyAICTW.loi(error) }
    }
}

struct TroLyAICTW: View {
    let pid: Int
    @StateObject private var vm: TroLyAIVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @AppStorage("com.cuongthai.ctwork.ai.dongY") private var daDongY = false
    @State private var soan = ""
    @State private var rieng = false
    @State private var tamPhu: TamPhuAI?
    @FocusState private var dangGo: Bool
    @State private var demLucHien = 0

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: TroLyAIVM(pid: pid))
    }

    /// Câu lỗi cho người dùng — KHÔNG để lọt câu mời mua của máy chủ (3.1.1).
    static func loi(_ e: Error) -> String {
        if case APIError.coMa(let ma, let m) = e {
            switch ma {
            case "WORK_AI_BAD_OUTPUT": return String(localized: "The AI returned an answer that couldn't be read. Tap Ask again.")
            case "WORK_AI_UNAVAILABLE": return String(localized: "The AI assistant is temporarily unavailable. Please try again in a few minutes.")
            case "WORK_AI_QUOTA_EXCEEDED", "WORK_AI_TOKEN_CAP": return String(localized: "You've reached today's AI limit. It resets tomorrow.")
            case "WORK_AI_NOTHING_TO_RETRY": return String(localized: "This question already has an answer.")
            case "WORK_AI_CANCELLED": return String(localized: "The answer was stopped before it was ready. Tap Ask again.")
            case "CLIENT_PORTAL_ONLY", "WORK_FORBIDDEN": return String(localized: "The AI assistant is only available to the project team.")
            default: return CTW.coLoiMoiMua(m) ? String(localized: "This action isn't available right now.") : m
            }
        }
        if let l = e as? LoiLuongAI, l == .dutGiuaChung {
            return String(localized: "The connection closed before the answer was ready. Tap Ask again.")
        }
        return CTW.loi(e)
    }

    private var ma: String { app.luaChon?.maDuAn ?? "" }
    private var mau: [String] {
        [String(localized: "What should I work on next, and what do I need to read first?"),
         String(localized: "Summarize where the current sprint stands and what's at risk."),
         ma.isEmpty ? String(localized: "Explain the newest issue assigned to me step by step.") : String(localized: "Explain my most urgent \(ma) issue step by step.")]
    }

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    CongBoAICTW(daDongY: daDongY)
                    if vm.hoiThoai == nil && vm.cauDangHoi == nil {
                        manTrong
                    } else {
                        if let t = vm.hoiThoai {
                            HStack(spacing: 6) {
                                Image(systemName: t.rieng ? "lock.fill" : "person.2.fill").font(.ctw(size: 11))
                                Text(t.rieng ? "Private conversation — only you can see it" : "Shared with the project team")
                                    .font(.ctw(size: 12))
                            }
                            .foregroundColor(AppColors.textSecondary)
                        }
                        ForEach(vm.tinNhan) { m in
                            if m.laAI {
                                TraLoiAICTW(m: m, ma: ma, dangApDung: vm.dangApDung,
                                            apDung: { d in Task { await vm.apDung(m, d) } },
                                            boQua: { d in Task { await vm.boQua(m, d) } })
                                    .id(m.id)
                            } else {
                                CauHoiAICTW(m: m, cuaToi: m.author?.id == app.currentUser?.id, dangCho: vm.dangCho != nil) {
                                    vm.luot = Task { await vm.hoiLai(m) }
                                }
                                .id(m.id)
                            }
                        }
                        if let c = vm.cauDangHoi, !vm.tinNhan.contains(where: { $0.role == "user" && $0.content == c }) {
                            CauHoiAICTW(m: CTWAITinNhan(id: -1, role: "user", content: c, author: app.currentUser.map {
                                CTWUser(id: $0.id, username: $0.username, fullName: $0.fullName, displayName: nil, avatarUrl: $0.avatarUrl, role: nil, kind: nil)
                            }), cuaToi: true, dangCho: true) {}
                        }
                        if !vm.banNhap.isEmpty {
                            // Câu trả lời đang chạy: dựng Markdown dần; thay bằng `done.reply` khi xong (đề xuất chỉ có ở `done`).
                            TraLoiDangVietAICTW(chu: vm.banNhap, trangThai: vm.tienDo.flatMap(LuongAICTW.nhan)).id("nhap")
                        } else if let c = vm.dangCho {
                            DangNghiAICTW(chu: c, muc: vm.docMuc).id("cho")
                        }
                        if let l = vm.loiLuot {
                            VStack(alignment: .leading, spacing: 8) {
                                CTWErrorBanner(text: l) { vm.loiLuot = nil }
                                if let h = vm.cauHong {
                                    Button { vm.luot = Task { await vm.hoiLai(h) } } label: {
                                        Label("Ask again", systemImage: "arrow.clockwise").font(.ctw(size: 15, weight: .semibold))
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(vm.dangCho != nil)
                                    .accessibilityIdentifier("ai.askAgain")
                                }
                            }
                            .id("loi")
                        }
                    }
                    Color.clear.frame(height: 4).id("cuoi")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, 8)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.tinNhan.count) { _, _ in withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) } }
            .onChange(of: vm.dangCho) { _, _ in withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) } }
            // Nháp chạy ⇒ bám đáy (không hoạt ảnh — ~12 lần/giây).
            .onChange(of: vm.banNhap.count / 120) { _, _ in cuon.scrollTo("cuoi", anchor: .bottom) }
        }
        .safeAreaInset(edge: .bottom) { oSoan }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.hoiThoai?.title ?? String(localized: "AI assistant"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { menuHoiThoai } }
        .environment(\.openURL, OpenURLAction { u in moLink(u) })
        .task { await vm.taiDanhSach() }
        .onAppear { demLucHien = nganXep.duong.count }
        // Rời màn (quay lại) ⇒ đóng luồng — máy chủ thôi gọi model. Đẩy một thẻ từ link trong câu trả lời (ngăn xếp DÀI ra)
        // hoặc đổi tab (giữ nguyên) thì để câu trả lời chạy tiếp.
        .onDisappear { if nganXep.duong.count < demLucHien { vm.dung() } }
        // MỘT `.sheet(item:)` cho cả hai tấm phủ (CLAUDE.md C5: hai `.sheet` trên một view ⇒ chỉ cái cuối chạy).
        .sheet(item: $tamPhu) { t in
            switch t {
            case .dongY(let cau):
                DongYAICTW {
                    daDongY = true
                    tamPhu = nil
                    guiDi(cau)
                } huy: { tamPhu = nil }
                .presentationDetents([.large])
            case .web(let u): SafariCTW(url: u)
            }
        }
        .alert(vm.loi ?? "", isPresented: Binding(get: { vm.loi != nil }, set: { if !$0 { vm.loi = nil } })) {
            Button("OK", role: .cancel) {}
        }
        #if DEBUG
        .task {
            if XemThuCTW.conCua("ai") != nil { await vm.taiDanhSach() }
            switch XemThuCTW.conCua("ai") {
            case "thread"?: if let t = vm.dsHoiThoai.first { await vm.mo(t.id) }
            case "loi"?:
                if let t = vm.dsHoiThoai.first(where: { $0.title.contains("velocity") }) { await vm.mo(t.id) }
                vm.loiLuot = TroLyAICTW.loi(APIError.coMa(ma: "WORK_AI_BAD_OUTPUT", thongDiep: ""))
            case "dongy"?: daDongY = false; tamPhu = .dongY(mau[0])
            // Bản stream qua máy chủ giả (XemThuCTW+LuongAI): hỏi thật một câu ⇒ chụp lúc đọc / đang viết / xong.
            case "stream"?:
                daDongY = true
                guiDi(String(localized: "How is Sprint 6 going, and what should I do first?"))
            // Trạng thái đứng yên để chụp: đang đọc thẻ/Docs · câu trả lời đang chạy giữa chừng.
            case "doc"?:
                daDongY = true
                vm.datThu(cau: String(localized: "How is Sprint 6 going, and what should I do first?"),
                          tienDo: .doc(vong: 1, muc: ["NW-12", "NW-17", "Docs #3 — Notification payloads", "Sprint 6"]), nhap: "")
            case "viet"?:
                daDongY = true
                let t = AIGia.traLoiBang
                vm.datThu(cau: String(localized: "How is Sprint 6 going, and what should I do first?"), tienDo: nil,
                          nhap: String(t.prefix(t.count * 55 / 100)))
            default: break
            }
        }
        #endif
    }

    // MARK: Màn trống: 3 câu mẫu + hội thoại gần đây

    private var manTrong: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ask about this project").font(.ctw(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                Text("The assistant reads the project's issues, docs and files before it answers, and links every issue it mentions.")
                    .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(mau.enumerated()), id: \.offset) { i, c in
                Button { thuHoi(c) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: ["checklist", "chart.line.uptrend.xyaxis", "list.number"][i])
                            .font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.primary).frame(width: 22)
                            .accessibilityHidden(true)
                        Text(c).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.circle.fill").font(.ctw(size: 20)).foregroundColor(AppColors.primary)
                            .accessibilityHidden(true)
                    }
                    .padding(14)
                    .ctwThe(14)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ai.sample.\(i)")
                .accessibilityHint("Sends this question to the AI assistant")
            }
            if !vm.dsHoiThoai.isEmpty {
                CTWSectionHeader("clock.arrow.circlepath", String(localized: "Recent conversations")).padding(.top, 8)
                VStack(spacing: 0) {
                    ForEach(vm.dsHoiThoai.prefix(6)) { t in
                        Button { Task { await vm.mo(t.id) } } label: { hangHoiThoai(t) }
                            .buttonStyle(.plain)
                        if t.id != vm.dsHoiThoai.prefix(6).last?.id { Divider().padding(.leading, 44) }
                    }
                }
                .ctwThe(14)
            } else if vm.taiDs {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
        }
    }

    private func hangHoiThoai(_ t: CTWAIHoiThoai) -> some View {
        HStack(spacing: 10) {
            CTWAvatar(user: t.createdBy, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 4) {
                    if t.rieng { Image(systemName: "lock.fill").font(.ctw(size: 10)) }
                    Text(dongPhu(t))
                }
                .font(.ctw(size: 11.5)).foregroundColor(AppColors.textTertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func dongPhu(_ t: CTWAIHoiThoai) -> String {
        let ai = t.createdBy?.ten ?? String(localized: "Someone")
        let n = t.messageCount ?? 0, luc = CTW.thoiDiem(t.lastMessageAt)
        return n == 1 ? String(localized: "\(ai) · 1 message · \(luc)") : String(localized: "\(ai) · \(n) messages · \(luc)")
    }

    // MARK: Menu hội thoại

    private var menuHoiThoai: some View {
        Menu {
            Button { vm.moi(); rieng = false } label: { Label("New conversation", systemImage: "square.and.pencil") }
            Button { vm.moi(); rieng = true } label: { Label("New private conversation", systemImage: "lock") }
            if let t = vm.hoiThoai, t.canManage == true {
                Button(role: .destructive) { Task { await vm.xoa(t) } } label: { Label("Delete conversation", systemImage: "trash") }
            }
            if !vm.dsHoiThoai.isEmpty {
                Section("Conversations") {
                    ForEach(vm.dsHoiThoai.prefix(20)) { t in
                        Button { Task { await vm.mo(t.id) } } label: {
                            Label(t.title, systemImage: t.rieng ? "lock" : (t.id == vm.hoiThoai?.id ? "checkmark" : "bubble.left.and.text.bubble.right"))
                        }
                    }
                }
            }
        } label: { Image(systemName: "text.bubble") }
        .accessibilityLabel("Conversations")
    }

    // MARK: Ô soạn

    private var oSoan: some View {
        VStack(spacing: 6) {
            if rieng && vm.hoiThoai == nil {
                Label("New private conversation — only you will see it", systemImage: "lock.fill")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about issues, docs, the sprint…", text: $soan, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.ctw(size: 15))
                    .focused($dangGo)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppColors.backgroundCard))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppColors.border))
                    .accessibilityIdentifier("ai.input")
                if vm.dangCho != nil {
                    // Đang trả lời ⇒ nút Dừng (đóng luồng; câu hỏi giữ lại với nút "Ask again").
                    Button { vm.dung() } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.ctw(size: 32))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Stop the answer")
                    .accessibilityIdentifier("ai.stop")
                } else {
                    Button { thuHoi(soan) } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.ctw(size: 32))
                            .foregroundColor(soan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.textTertiary : AppColors.primary)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(soan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Send question to AI")
                    .accessibilityIdentifier("ai.send")
                }
            }
            Text("AI answers can be wrong — check important facts. Don't share passwords or keys.")
                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.md).padding(.top, 8).padding(.bottom, 6)
        .background(.bar)
    }

    private func thuHoi(_ c: String) {
        let cau = c.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cau.isEmpty, vm.dangCho == nil else { return }
        // 5.1.2(i): đồng ý TRƯỚC khi gửi lần đầu.
        guard daDongY else { tamPhu = .dongY(cau); return }
        guiDi(cau)
    }

    private func guiDi(_ cau: String) {
        soan = ""
        dangGo = false
        vm.luot = Task {
            let ok = await vm.hoi(cau, rieng: rieng)
            if !ok && soan.isEmpty { soan = cau }
            await vm.taiDanhSach()
        }
    }

    // MARK: Link trong câu trả lời

    private func moLink(_ u: URL) -> OpenURLAction.Result {
        let laCT = u.host == nil || TrinhDuyetCuongThaiCTW.laCuaCuongThai(u)
        if laCT {
            if TrinhDuyetCuongThaiCTW.laDuongMua(u) { return .handled }  // 3.1.1: không mở trang mua
            let duong = u.path + (u.query.map { "?" + $0 } ?? "")
            if duong == "/work" || duong.hasPrefix("/work/"), let d = DuongDanCTW.tach(duong) {
                if d.doan == "issue", let m = d.maDuAn, let so = d.phanCon.first.flatMap(Int.init) {
                    if let l = app.luaChon, l.slug == d.slug, l.maDuAn.caseInsensitiveCompare(m) == .orderedSame {
                        nganXep.duong.append(CTWRoute.the(pid: l.pid, so: so))
                    } else {
                        nganXep.duong.append(CTWRoute.theTheoMa(slug: d.slug, ma: m, so: so))
                    }
                } else {
                    DinhTuyenCTW.mo(duongDan: duong)
                }
                return .handled
            }
            if let full = u.host == nil ? URL(string: APIClient.diaChiGoc + duong) : u { tamPhu = .web(full) }
            return .handled
        }
        guard let s = u.scheme?.lowercased(), s == "https" || s == "http" || s == "mailto" else { return .handled }
        return .systemAction
    }
}

enum TamPhuAI: Identifiable {
    case dongY(String), web(URL)
    var id: String {
        switch self {
        case .dongY(let c): return "dy-\(c)"
        case .web(let u): return u.absoluteString
        }
    }
}

// MARK: - Dải công bố (luôn ở đầu khung AI — 4.7 / 5.1.2)

struct CongBoAICTW: View {
    let daDongY: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles").font(.ctw(size: 15, weight: .bold)).foregroundColor(AppColors.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppColors.primary.opacity(0.12)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("CT Work AI").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    CTWNhanAI(chu: "AI")
                }
                Text("Answers are generated by AI. Your question and the project content it needs are sent to our AI model provider to create the answer.")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .ctwThe(14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hộp đồng ý trước câu hỏi đầu tiên (5.1.2(i))

enum CongBoAI {
    static var tieuDe: String { String(localized: "Questions are answered by AI") }
    static var noiDung: String { String(localized: """
    When you ask the CT Work AI assistant, CT Work sends your question and the project content needed to answer it — issues, comments, Docs pages, attached files and links in this project that you can already see — to a third-party AI model provider (large language models such as Anthropic Claude and OpenAI GPT, reached through our AI gateway). The answer is saved in this project's conversation history.
    """) }
    static var gach: [(String, String)] { [
        ("eye.slash", String(localized: "Only content you already have access to in this project is used.")),
        ("person.2", String(localized: "Shared conversations are visible to your project team; private ones only to you.")),
        ("hand.raised", String(localized: "The provider uses it only to create the answer. No advertising, no tracking.")),
        ("exclamationmark.bubble", String(localized: "AI can be wrong. Nothing changes in the project until someone taps Apply.")),
    ] }
}

struct DongYAICTW: View {
    let dongY: () -> Void
    let huy: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "sparkles").font(.ctw(size: 28, weight: .bold)).foregroundColor(AppColors.primary)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(AppColors.primary.opacity(0.12)))
                        .accessibilityHidden(true)
                    Text(CongBoAI.tieuDe).font(.ctw(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    Text(CongBoAI.noiDung).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(CongBoAI.gach, id: \.1) { g in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: g.0).foregroundColor(AppColors.primary).frame(width: 22).accessibilityHidden(true)
                                Text(g.1).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Text("You can turn this off later in Account › Privacy.").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    Button(action: dongY) {
                        Text("Allow and ask").font(.ctw(size: 17, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("ai.consent.allow")
                    Button("Not now", action: huy).frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(Spacing.lg)
            }
            .background(AppColors.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: huy) } }
        }
    }
}

// MARK: - Câu hỏi (của mình / của đồng đội)

struct CauHoiAICTW: View {
    let m: CTWAITinNhan
    let cuaToi: Bool
    let dangCho: Bool
    let hoiLai: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if !cuaToi, let a = m.author {
                HStack(spacing: 6) {
                    CTWAvatar(user: a, size: 18)
                    Text(a.ten).font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                }
            }
            Text(m.content).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppColors.primary.opacity(0.13)))
                .ctwMenuBaoCaoChan(khoa: "ai-q-\(m.id)", noiDung: m.content, nguCanh: "CT Work AI question", tacGia: m.author, laCuaToi: cuaToi)
            if m.error != nil {
                HStack(spacing: 8) {
                    Label("No answer yet", systemImage: "exclamationmark.triangle.fill")
                        .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.error)
                    if cuaToi {
                        Button("Ask again", action: hoiLai)
                            .font(.ctw(size: 13, weight: .semibold))
                            .buttonStyle(.bordered)
                            .disabled(dangCho)
                            .accessibilityIdentifier("ai.retry.\(m.id)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 40)
    }
}

// MARK: - Câu trả lời của AI

struct TraLoiAICTW: View {
    let m: CTWAITinNhan
    let ma: String
    let dangApDung: Set<String>
    let apDung: (CTWAIDeXuat) -> Void
    let boQua: (CTWAIDeXuat) -> Void
    @ObservedObject private var an = AnNoiDungChungCTW.shared
    @State private var hoiBaoCao = false
    @State private var thongBao: String?

    private var khoa: String { "ai-msg-\(m.id)" }

    var body: some View {
        if an.biAn(khoa) {
            Label("You reported this answer. It's hidden for you.", systemImage: "flag.fill")
                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.ctw(size: 12, weight: .bold)).foregroundColor(AppColors.onPrimary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppColors.primary))
                        .accessibilityHidden(true)
                    Text(m.title ?? "CT Work AI").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    CTWNhanAI(chu: String(localized: "AI-generated"))
                    Spacer(minLength: 0)
                    Text(CTW.thoiDiem(m.createdAt)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                CTWMarkdownView(markdown: m.content, coChu: 15)
                ForEach(m.actions ?? [], id: \.index) { d in deXuat(d) }
                HStack(spacing: 4) {
                    Button { CTW.chepVaoBoNho(m.content); CTWRung.chon() } label: {
                        Label("Copy", systemImage: "doc.on.doc").font(.ctw(size: 12, weight: .medium)).frame(minHeight: 32)
                    }
                    Button { hoiBaoCao = true } label: {
                        Label("Report", systemImage: "flag").font(.ctw(size: 12, weight: .medium)).frame(minHeight: 32)
                    }
                    .accessibilityHint("Report this AI answer to the moderators")
                    .accessibilityIdentifier("ai.report.\(m.id)")
                }
                .buttonStyle(.borderless)
                .foregroundColor(AppColors.textSecondary)
            }
            .padding(14)
            .ctwThe(16)
            .confirmationDialog("Report this AI answer", isPresented: $hoiBaoCao, titleVisibility: .visible) {
                ForEach(CTWBaoCao.lyDo, id: \.ma) { l in
                    Button(l.nhan, role: .destructive) {
                        Task {
                            do {
                                try await CTWBaoCaoChung.guiDi(khoa: khoa, noiDung: m.content, nguCanh: "CT Work AI answer", tacGia: nil, lyDoMa: l.ma)
                                CTWRung.thanhCong()
                            } catch { thongBao = CTW.loi(error) }
                        }
                    }
                }
            } message: { Text("Reports go to the CT Work moderation team and are reviewed within 24 hours.") }
            .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func nhanDaApDung(_ d: CTWAIDeXuat) -> String {
        let dau = d.byName.map { String(localized: "Applied by @\($0)") } ?? String(localized: "Applied")
        return dau + (d.summary.map { " — \($0)" } ?? "")
    }

    @ViewBuilder
    private func deXuat(_ d: CTWAIDeXuat) -> some View {
        let dang = dangApDung.contains("\(m.id)-\(d.index)")
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "wand.and.stars").foregroundColor(AppColors.primary).font(.ctw(size: 13, weight: .semibold))
                    .accessibilityHidden(true)
                Text(d.moTa(ma: ma)).font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch d.status {
            case "done":
                Label(nhanDaApDung(d), systemImage: "checkmark.circle.fill")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.success)
            case "dismissed":
                Text("Dismissed").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
            default:
                if let e = d.error { Text(e).font(.ctw(size: 12)).foregroundColor(AppColors.error) }
                HStack(spacing: 8) {
                    Button { apDung(d) } label: {
                        if dang { ProgressView() } else { Text(d.status == "error" ? "Try again" : "Apply").font(.ctw(size: 13, weight: .semibold)) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(dang || d.status == "applying")
                    Button("Dismiss") { boQua(d) }.font(.ctw(size: 13)).buttonStyle(.bordered).disabled(dang)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundTertiary))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested change: \(d.moTa(ma: ma))")
    }
}

/// "AI đang đọc dự án…" — chấm nhảy, tôn trọng Giảm chuyển động.
struct DangNghiAICTW: View {
    let chu: String
    /// Mục đang đọc (sự kiện `reading` của luồng) — hiện thành chip mã thẻ/trang Docs.
    var muc: [String] = []
    @State private var giay = 0
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ProgressView().padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(chu).font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if !muc.isEmpty {
                    CTWDongChip(ds: muc)
                }
                Text(giay < 20 ? "The assistant reads the issues and docs it needs first." : "Still working — long answers can take up to a minute.")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .ctwThe(14)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                giay += 1
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Câu trả lời ĐANG chạy (SSE)

/// Bong bóng trợ lý khi chữ đang về: Markdown dựng dần (VM đã giới hạn ~12 lần/giây), nhãn "AI-generated" ngay từ chữ đầu
/// (4.7). Chưa có Copy/Report/đề xuất — những thứ đó thuộc câu trả lời CHUẨN (`done`), thay ngay khi xong.
struct TraLoiDangVietAICTW: View {
    let chu: String
    var trangThai: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.ctw(size: 12, weight: .bold)).foregroundColor(AppColors.onPrimary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(AppColors.primary))
                    .accessibilityHidden(true)
                Text(verbatim: "CT Work AI").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                CTWNhanAI(chu: String(localized: "AI-generated"))
                Spacer(minLength: 0)
                ProgressView().controlSize(.small)
            }
            CTWMarkdownView(markdown: chu, coChu: 15)
            if let t = trangThai {
                Text(t).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Writing the answer…").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(14)
        .ctwThe(16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai.streaming")
    }
}

/// Hàng chip bọc dòng (mã thẻ, trang Docs đang đọc).
struct CTWDongChip: View {
    let ds: [String]
    var body: some View {
        BoCucBocDongCTW(khoang: 5) {
            ForEach(Array(ds.enumerated()), id: \.offset) { _, t in
                Text(verbatim: t.count > 40 ? String(t.prefix(38)) + "…" : t)
                    .font(.ctw(size: 11.5, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(AppColors.backgroundTertiary))
            }
        }
    }
}

import SwiftUI

// MARK: - CTWUI — nội dung người dùng ở các mô-đun quản trị dự án (App Store 1.2 / 4.7)
//
// Bình luận của Change request, RAID, phê duyệt, yêu cầu, ticket service desk…
// đều là nội dung người dùng ⇒ phải đủ BỐN thứ của 1.2 như bình luận thẻ:
//   1. lọc   — ẩn ngay thứ mình báo cáo (`AnNoiDungChungCTW`, khoá chuỗi
//              "<loai>-<id>" để id của các bảng khác nhau không đụng nhau)
//              + ẩn mọi nội dung của người đã chặn (`ModerationStore`)
//   2. báo cáo — `POST /work/report {kind, id, reason, detail?}` (18/10/2026,
//              `contentReport.service.ts`): hàng chờ BAO_CAO của quản trị + audit
//              `content.report` + báo ADMIN dự án; chống trùng theo người. Nơi gọi
//              truyền `dich: CTWDichBaoCao(kind:id:)`; KHÔNG có `dich` (loại máy chủ
//              chưa nhận, vd ticket/bài nộp) ⇒ lùi về đường chung `ModerationStore.baoCaoNoiDung`.
//   3. chặn  — `ModerationStore.block`
//   4. liên hệ — Account → Help & contact (có sẵn)
// Nội dung của AI agent luôn gắn nhãn (`CTWNhanAI`, ✦ trên avatar).

/// Ẩn nội dung đã báo cáo — chung cho mọi loại không có kho ẩn riêng.
@MainActor
final class AnNoiDungChungCTW: ObservableObject {
    static let shared = AnNoiDungChungCTW()
    @Published private(set) var daAn: Set<String> = []
    private let d = UserDefaults.standard
    private let k = "com.cuongthai.ctwork.anChung"

    private init() { daAn = Set(d.stringArray(forKey: k) ?? []) }

    func an(_ khoa: String) { daAn.insert(khoa); d.set(Array(daAn), forKey: k) }
    func biAn(_ khoa: String) -> Bool { daAn.contains(khoa) }
    func xoaHet() { daAn = []; d.removeObject(forKey: k) }
}

/// Đích báo cáo ở máy chủ. `kind` ∈ `REPORT_KINDS` của `contentReport.service.ts`:
/// chat_message · issue_comment · page_comment · meeting_note (id = id cuộc họp) · retro_card ·
/// change_request · raid_item · review_item · approval_step (id bước) · intake_message ·
/// form_answer · class_post · class_comment · diagram_comment. `id` = id NỘI BỘ của dòng.
struct CTWDichBaoCao: Hashable {
    var kind: String
    var id: Int
    static let cacLoai: Set<String> = [
        "chat_message", "issue_comment", "page_comment", "meeting_note", "retro_card", "change_request", "raid_item",
        "review_item", "approval_step", "intake_message", "form_answer", "class_post", "class_comment", "diagram_comment",
    ]
    init(_ kind: String, _ id: Int) {
        assert(Self.cacLoai.contains(kind), "kind báo cáo lạ: \(kind)")
        self.kind = kind; self.id = id
    }
}

/// `POST /report` ⇒ `{reported, duplicate}`.
struct CTWKetQuaBaoCao: Codable { var reported: Bool?; var duplicate: Bool? }

extension CTWAPI {
    /// Báo cáo nội dung (1.2) — một cửa cho mọi loại. Tự báo ⇒ 400 `WORK_REPORT_SELF`; không thấy ⇒ 404.
    static func baoCaoNoiDung(_ d: CTWDichBaoCao, lyDo: String, chiTiet: String? = nil) -> APIEndpoint {
        var t: [String: Any] = ["kind": d.kind, "id": d.id, "reason": lyDo]
        if let chiTiet, !chiTiet.isEmpty { t["detail"] = String(chiTiet.prefix(1000)) }
        return goi("/report", "POST", t)
    }
}

enum CTWBaoCaoChung {
    /// Báo cáo một nội dung rồi ẩn ngay cho người báo cáo.
    /// - khoa: "cr-comment-12", "ticket-reply-5"… (khoá ẩn tại chỗ + nhãn ở đường lùi)
    /// - dich: đích ở máy chủ (`POST /work/report`). `nil` ⇒ đường chung cũ.
    @MainActor
    static func guiDi(khoa: String, noiDung: String, nguCanh: String, tacGia: CTWUser?, lyDoMa: String,
                      dich: CTWDichBaoCao? = nil) async throws {
        let l = CTWBaoCao.lyDo.first { $0.ma == lyDoMa } ?? CTWBaoCao.lyDo[CTWBaoCao.lyDo.count - 1]
        if let dich {
            let _: CTWKetQuaBaoCao = try await APIClient.shared.request(CTWAPI.baoCaoNoiDung(dich, lyDo: l.ma))
        } else {
            let ai = tacGia.map { "user #\($0.id)\($0.laAgent ? " (AI agent)" : "")" } ?? "unknown"
            try await ModerationStore.shared.baoCaoNoiDung(
                nhan: "CT WORK \(khoa.uppercased()) · \(ai)",
                noiDung: noiDung, ngucanh: nguCanh, lyDo: l.chung, chiTiet: l.nhan)
        }
        AnNoiDungChungCTW.shared.an(khoa)
    }
}

// MARK: - Menu Báo cáo / Chặn gắn vào MỘT hàng nội dung

private struct MenuBaoCaoChan: ViewModifier {
    let khoa: String
    let noiDung: String
    let nguCanh: String
    let tacGia: CTWUser?
    let laCuaToi: Bool
    var themMuc: AnyView?
    var dich: CTWDichBaoCao?

    @State private var hoiBaoCao = false
    @State private var hoiChan = false
    @State private var thongBao: String?

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button { CTW.chepVaoBoNho(noiDung) } label: { Label("Copy text", systemImage: "doc.on.doc") }
                if let themMuc { themMuc }
                if !laCuaToi {
                    Button(role: .destructive) { hoiBaoCao = true } label: { Label("Report", systemImage: "flag") }
                    if let a = tacGia {
                        Button(role: .destructive) { hoiChan = true } label: { Label("Block \(a.ten)", systemImage: "hand.raised") }
                    }
                }
            }
            .confirmationDialog("Report this content", isPresented: $hoiBaoCao, titleVisibility: .visible) {
                ForEach(CTWBaoCao.lyDo, id: \.ma) { l in
                    Button(l.nhan, role: .destructive) {
                        Task {
                            do {
                                try await CTWBaoCaoChung.guiDi(khoa: khoa, noiDung: noiDung, nguCanh: nguCanh, tacGia: tacGia, lyDoMa: l.ma, dich: dich)
                                CTWRung.thanhCong()
                                thongBao = String(localized: "Thanks — our moderators will review it within 24 hours. It's hidden for you now.")
                            } catch { thongBao = CTW.loi(error) }
                        }
                    }
                }
            } message: { Text("Reports go to the CT Work moderation team.") }
            .confirmationDialog("Block \(tacGia?.ten ?? "this user")?", isPresented: $hoiChan, titleVisibility: .visible) {
                Button("Block", role: .destructive) {
                    guard let u = tacGia else { return }
                    Task {
                        do { try await ModerationStore.shared.block(userId: u.id); CTWRung.thanhCong() }
                        catch { thongBao = CTW.loi(error) }
                    }
                }
            } message: { Text("You won't see their comments, replies or messages anywhere in CT Work.") }
            .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
                Button("OK", role: .cancel) {}
            }
    }
}

extension View {
    /// Nhấn giữ ⇒ Copy · Report · Block. `themMuc` = mục riêng của mô-đun (Edit, Delete…).
    /// `dich` = đích báo cáo ở máy chủ (`POST /work/report`); bỏ trống ⇒ đường chung cũ.
    func ctwMenuBaoCaoChan(khoa: String, noiDung: String, nguCanh: String, tacGia: CTWUser?,
                           laCuaToi: Bool, themMuc: AnyView? = nil, dich: CTWDichBaoCao? = nil) -> some View {
        modifier(MenuBaoCaoChan(khoa: khoa, noiDung: noiDung, nguCanh: nguCanh, tacGia: tacGia,
                                laCuaToi: laCuaToi, themMuc: themMuc, dich: dich))
    }
}

// MARK: - Một bình luận (hàng chung)

/// Hàng bình luận chung: avatar, tên (+ nhãn AI), giờ, nội dung markdown.
/// Tự ẩn khi đã báo cáo hoặc tác giả bị chặn; nhấn giữ ⇒ báo cáo/chặn.
struct CTWBinhLuanDong: View {
    let khoa: String
    let tacGia: CTWUser?
    /// Chữ trơn (cũng là thứ gửi đi khi báo cáo). Dựng bằng markdown nếu không có `doc`.
    let noiDung: String
    var doc: CTWNode? = nil
    let thoiDiem: String?
    var nhanPhu: String?
    let nguCanh: String
    var laAI = false
    /// Mục riêng trong menu nhấn giữ (Delete…).
    var themMuc: AnyView? = nil
    /// Đích báo cáo ở máy chủ (`POST /work/report`).
    var dich: CTWDichBaoCao? = nil

    @EnvironmentObject private var appState: AppState
    @ObservedObject private var an = AnNoiDungChungCTW.shared
    @ObservedObject private var kiemDuyet = ModerationStore.shared

    var body: some View {
        if an.biAn(khoa) || (tacGia.map { kiemDuyet.blockedUserIds.contains($0.id) } ?? false) {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: 10) {
                CTWAvatar(user: tacGia, size: 30)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(tacGia?.ten ?? String(localized: "Someone")).font(.ctw(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary).lineLimit(1)
                        if tacGia?.laAgent == true { CTWNhanAI() } else if laAI { CTWNhanAI(chu: String(localized: "AI-drafted")) }
                        if let nhanPhu {
                            Text(nhanPhu).font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.backgroundTertiary))
                        }
                        Spacer(minLength: 0)
                        Text(CTW.thoiDiem(thoiDiem)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                    if let doc { CTWTipTapView(doc: doc, coChu: 14) } else { CTWMarkdownView(markdown: noiDung, coChu: 14) }
                }
            }
            .padding(12)
            .ctwThe(12)
            .ctwMenuBaoCaoChan(khoa: khoa, noiDung: noiDung, nguCanh: nguCanh, tacGia: tacGia,
                               laCuaToi: tacGia?.id != nil && tacGia?.id == appState.currentUser?.id, themMuc: themMuc, dich: dich)
        }
    }
}

// MARK: - Ô soạn bình luận chung

struct CTWHopSoan: View {
    var goiY = String(localized: "Add a comment…")
    var nutGui = String(localized: "Send")
    let gui: (String) async -> Bool
    @State private var chu = ""
    @State private var dangGui = false
    @FocusState private var dangGo: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(goiY, text: $chu, axis: .vertical)
                .lineLimit(1...6)
                .font(.ctw(size: 15))
                .focused($dangGo)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .ctwThe(18)
            Button {
                let t = chu.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                dangGui = true
                Task {
                    if await gui(t) { chu = ""; dangGo = false; CTWRung.thanhCong() } else { CTWRung.loi() }
                    dangGui = false
                }
            } label: {
                Group {
                    if dangGui { ProgressView().tint(AppColors.onPrimary) }
                    else { Image(systemName: "arrow.up").font(.ctw(size: 15, weight: .bold)) }
                }
                .foregroundColor(AppColors.onPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(chu.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textTertiary : AppColors.primary))
            }
            .buttonStyle(.plain)
            .disabled(dangGui || chu.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel(nutGui)
        }
    }
}

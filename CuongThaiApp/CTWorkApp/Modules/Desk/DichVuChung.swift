import SwiftUI

// MARK: - Mảng "dịch vụ" (Desk · Intake · Forms · Portal · Classes · Submit) — mảnh dùng chung
//
// Chỉ dùng trong các mô-đun của mảng này (cùng target CTWorkApp). Thứ gì đáng
// dùng toàn app thì đã nằm ở `Shared/CTWork/CTWUI`.

/// Giá trị JSON tự do (câu trả lời form, trường ticket) — giải mã KHOAN DUNG:
/// chuỗi, số, bool, mảng, null đều nhận, không làm hỏng cả lượt giải mã (C4).
enum CTWGiaTri: Codable, Hashable {
    case chu(String), so(Double), dung(Bool), mang([CTWGiaTri]), rong

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .rong }
        else if let b = try? c.decode(Bool.self) { self = .dung(b) }
        else if let d = try? c.decode(Double.self) { self = .so(d) }
        else if let s = try? c.decode(String.self) { self = .chu(s) }
        else if let a = try? c.decode([CTWGiaTri].self) { self = .mang(a) }
        else { self = .rong }   // object lạ (vd tệp) ⇒ coi như trống, không ném
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .chu(let s): try c.encode(s)
        case .so(let d): try c.encode(d)
        case .dung(let b): try c.encode(b)
        case .mang(let a): try c.encode(a)
        case .rong: try c.encodeNil()
        }
    }

    /// Chữ hiển thị.
    var hienThi: String {
        switch self {
        case .chu(let s): return s
        case .so(let d): return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(format: "%.2f", d)
        case .dung(let b): return b ? String(localized: "Yes") : String(localized: "No")
        case .mang(let a): return a.map(\.hienThi).filter { !$0.isEmpty }.joined(separator: ", ")
        case .rong: return ""
        }
    }
}

enum DichVuLoi {
    /// Câu lỗi riêng cho các mã "không được vào" của mảng này — nói rõ VÌ SAO,
    /// thay vì câu máy chủ chung chung.
    static func cau(_ e: Error) -> String {
        if case APIError.coMa(let ma, _) = e {
            switch ma {
            case "WORK_INTERNAL_ONLY": return String(localized: "This area is only for the project team.")
            case "CLIENT_PORTAL_ONLY": return String(localized: "Your client account can only use the client portal of this project.")
            case "MODULE_DISABLED": return String(localized: "This module is turned off for the project. A project admin can turn it on in settings.")
            case "WORK_EDIT_LOCKED", "EDIT_LOCKED": return String(localized: "Editing is locked for this project on your account. Unlock it on the project page to make changes.")
            case "WORK_TEACHING_ONLY": return String(localized: "The teaching overview is for teachers of at least one group.")
            case "WORK_AGENT_FORBIDDEN": return String(localized: "AI agents can't do this.")
            default: break
            }
        }
        return CTW.loi(e)
    }

    static func biChan(_ e: Error) -> Bool {
        if case APIError.coMa(let ma, _) = e {
            return ["WORK_INTERNAL_ONLY", "CLIENT_PORTAL_ONLY", "MODULE_DISABLED", "WORK_TEACHING_ONLY"].contains(ma)
        }
        return false
    }

    /// "2026-10-20T16:59:00.000Z" → "Oct 20, 23:59" (giờ máy).
    static func luc(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        let t = CTW.thoiDiem(s)
        return t.isEmpty ? nil : t
    }

    /// Thời điểm đã qua chưa (so với bây giờ).
    static func daQua(_ s: String?) -> Bool {
        guard let s else { return false }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: s) ?? { f.formatOptions = [.withInternetDateTime]; return f.date(from: s) }()
        return (d ?? .distantFuture) < Date()
    }
}

// MARK: - Bình luận của THẺ (ticket, yêu cầu cổng khách) — báo cáo qua route THẬT
//
// Bình luận thẻ có route báo cáo riêng ở máy chủ (`POST …/comments/:cid/report`:
// ghi audit + báo admin dự án) ⇒ dùng nó thay đường chung. Ẩn ngay bằng
// `AnNoiDungCTW.anBinhLuan` (cùng kho với màn chi tiết thẻ ⇒ ẩn ở mọi nơi).

struct DongBinhLuanTheCTW: View {
    let pid: Int
    let so: Int
    let c: CTWComment
    var nhanPhu: String?
    var noiBo = false

    @EnvironmentObject private var app: AppState
    @ObservedObject private var an = AnNoiDungCTW.shared
    @ObservedObject private var kiemDuyet = ModerationStore.shared
    @State private var hoiBaoCao = false
    @State private var hoiChan = false
    @State private var thongBao: String?

    private var laCuaToi: Bool { c.author?.id != nil && c.author?.id == app.currentUser?.id }

    var body: some View {
        if an.binhLuanAn.contains(c.id) || (c.author.map { kiemDuyet.blockedUserIds.contains($0.id) } ?? false) {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: 10) {
                CTWAvatar(user: c.author, size: 30)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(c.author?.ten ?? String(localized: "Someone")).font(.ctw(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary).lineLimit(1)
                        if c.author?.laAgent == true { CTWNhanAI() } else if c.isAi == true { CTWNhanAI(chu: String(localized: "AI-drafted")) }
                        if let nhanPhu {
                            CTWNhanNho(chu: nhanPhu, bieuTuong: noiBo ? "lock.fill" : "globe",
                                       mau: noiBo ? AppColors.warning : AppColors.success)
                        }
                        Spacer(minLength: 0)
                        Text(CTW.thoiDiem(c.createdAt)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                    CTWTipTapView(doc: c.bodyJson, coChu: 14)
                    ForEach(c.attachments ?? []) { a in
                        Label(a.fileName ?? String(localized: "File"), systemImage: a.bieuTuong)
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(noiBo ? AppColors.warning.opacity(0.07) : AppColors.backgroundCard)
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(noiBo ? AppColors.warning.opacity(0.25) : AppColors.border, lineWidth: 0.5))
            .contextMenu {
                Button { CTW.chepVaoBoNho(c.bodyJson?.chuTron ?? "") } label: { Label("Copy text", systemImage: "doc.on.doc") }
                if !laCuaToi {
                    Button(role: .destructive) { hoiBaoCao = true } label: { Label("Report comment", systemImage: "flag") }
                    if let a = c.author {
                        Button(role: .destructive) { hoiChan = true } label: { Label("Block \(a.ten)", systemImage: "hand.raised") }
                    }
                }
            }
            .confirmationDialog("Report this comment", isPresented: $hoiBaoCao, titleVisibility: .visible) {
                ForEach(ctwLyDoBaoCao, id: \.ma) { l in
                    Button(l.nhan, role: .destructive) {
                        Task {
                            do {
                                // Khách (cổng khách) KHÔNG được gọi route báo cáo của thẻ (ngoài danh
                                // sách cho phép ⇒ 403) ⇒ đi đường kiểm duyệt chung của CT Work.
                                if app.cauHinhDuAn?.role == "CLIENT" {
                                    try await CTWBaoCaoChung.guiDi(khoa: "issue-comment-\(c.id)", noiDung: c.bodyJson?.chuTron ?? "",
                                                                  nguCanh: "Project #\(pid) issue #\(so)", tacGia: c.author, lyDoMa: l.ma)
                                    an.anBinhLuan(c.id)
                                    CTWRung.thanhCong()
                                    thongBao = String(localized: "Thanks — our moderators will review it within 24 hours. It's hidden for you now.")
                                    return
                                }
                                let r: CTWBaoCaoKetQua = try await APIClient.shared.request(
                                    .workBaoCaoBinhLuan(pid: pid, so: so, cid: c.id, lyDo: l.ma))
                                an.anBinhLuan(c.id)
                                CTWRung.thanhCong()
                                thongBao = r.duplicate == true
                                    ? String(localized: "You already reported this comment.")
                                    : String(localized: "Thanks — project admins have been notified. The comment is hidden for you.")
                            } catch { thongBao = DichVuLoi.cau(error) }
                        }
                    }
                }
            } message: { Text("Project admins will review it and remove it if it breaks the rules.") }
            .confirmationDialog("Block \(c.author?.ten ?? String(localized: "this user"))?", isPresented: $hoiChan, titleVisibility: .visible) {
                Button("Block", role: .destructive) {
                    guard let u = c.author else { return }
                    Task {
                        do { try await kiemDuyet.block(userId: u.id); CTWRung.thanhCong() } catch { thongBao = DichVuLoi.cau(error) }
                    }
                }
            } message: { Text("You won't see their comments or messages anywhere in the app.") }
            .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

/// Khung nội dung có bề rộng dễ đọc trên iPad.
extension View {
    func dvBeRong(_ w: CGFloat = 760) -> some View {
        self.frame(maxWidth: w).frame(maxWidth: .infinity)
    }
}

/// Dải "xem như khách — chỉ đọc".
struct DaiXemThuKhach: View {
    var chu = String(localized: "Preview as client — read-only")
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
            Text(chu).font(.ctw(size: 13, weight: .semibold))
            Spacer(minLength: 0)
        }
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(AppColors.primary.opacity(0.10))
    }
}

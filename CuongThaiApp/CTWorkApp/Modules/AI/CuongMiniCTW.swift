import SwiftUI

// MARK: - CuongMini — lối vào trợ lý AI của dự án (21/10/2026)
//
// Phản hồi chủ app: "không tìm thấy chỗ chat AI". Trước đây trợ lý chỉ là MỘT dòng "AI assistant" giữa ~40 dòng của
// trang dự án. Giờ trợ lý mang tên CuongMini (như web/desktop) và có bốn cửa:
//   1. Trang dự án (iPhone): nút ✦ cạnh công tắc Board · Backlog · List · More (thấy ở cả bốn) — và thẻ nổi bật
//      "Hỏi CuongMini" ở ĐẦU trang More. iPad: nút ✦ trên màn Board/Backlog (`ManMoDunCTW`) + mục thanh bên.
//   2. Chi tiết thẻ: nút "CuongMini" cạnh trạng thái ⇒ bảng việc một chạm theo LOẠI thẻ (port `AiIssueMenu.tsx`) +
//      câu hỏi gợi ý về thẻ. Việc một chạm ⇒ `POST /ai/quick`; câu hỏi ⇒ chat có `issueNumber`.
//   3. My Work: thẻ "Hôm nay tôi nên làm gì?" ⇒ mở CuongMini của dự án đang chọn và hỏi ngay (chat — KHÔNG dùng
//      `/ai/daily-brief`: tuyến đó viết bản tin stand-up cho CẢ NHÓM và GHI ĐÈ `settings.dailyBrief` của dự án).
//   4. Mô-đun "CuongMini" (id `ai`, giữ id để ghim đồng bộ web).
// Mọi cửa đẩy `RouteCuongMiniCTW` vào ngăn xếp đang đứng (đích đăng ký ở `MoDunAI`). Đồng ý 5.1.2(i), nhãn AI (4.7),
// nút Report vẫn ở `TroLyAICTW` — câu hỏi/việc mở sẵn cũng phải qua hộp đồng ý trước lần gửi đầu.

/// Thẻ đang bàn với CuongMini.
struct TheCuongMini: Hashable {
    var so: Int
    /// Khoá loại thẻ (EPIC/STORY/TASK/BUG/REQUIREMENT…) — chọn việc một chạm.
    var loai: String?
    var tieuDe: String?
}

/// Việc một chạm của `/ai/quick` dùng trên một thẻ (web `AiIssueMenu.tsx`).
enum ViecNhanhCuongMini: String, Hashable, CaseIterable {
    case summarize, split, generate_tests, improve_bug, review_story
}

/// Một mục trong bảng việc một chạm (cùng `split` nhưng Epic gọi là "Chia thành story").
struct MucNhanhCuongMini: Hashable, Identifiable {
    let viec: ViecNhanhCuongMini
    var laEpic = false
    var id: String { viec.rawValue + (laEpic ? "-epic" : "") }

    /// Nhãn theo ngôn ngữ app (tính mỗi lần đọc — đổi ngôn ngữ trong app không đóng băng).
    /// Cũng là `label` gửi máy chủ ⇒ tiêu đề câu trả lời trong hội thoại cùng ngôn ngữ người dùng (như web gửi `wt(...)`).
    var nhan: String {
        switch viec {
        case .summarize: return String(localized: "Summarize")
        case .split: return laEpic ? String(localized: "Break into stories") : String(localized: "Split into sub-tasks")
        case .generate_tests: return String(localized: "Generate test cases")
        case .improve_bug: return String(localized: "Improve bug report")
        case .review_story: return String(localized: "Review story quality")
        }
    }

    var bieuTuong: String {
        switch viec {
        case .summarize: return "text.alignleft"
        case .split: return "square.split.2x1"
        case .generate_tests: return "flask"
        case .improve_bug: return "ladybug"
        case .review_story: return "checklist.checked"
        }
    }
}

/// Việc mở sẵn khi vào CuongMini.
enum KhoiDauCuongMini: Hashable {
    /// Hỏi ngay câu này (vd "Hôm nay tôi nên làm gì?").
    case hoi(String)
    /// Chạy việc một chạm trên thẻ đang bàn.
    case nhanh(MucNhanhCuongMini)
}

/// Đích điều hướng: mở CuongMini của dự án `pid` (đăng ký trong `MoDunAI.dichDen`).
struct RouteCuongMiniCTW: Hashable {
    var pid: Int
    /// Mã dự án — thẻ mở từ My Work có thể thuộc dự án KHÁC dự án đang chọn.
    var maDuAn: String?
    var the: TheCuongMini?
    var khoiDau: KhoiDauCuongMini?
}

enum CuongMini {
    /// Cùng cổng với mô-đun: được dùng AI trong dự án và không phải khách cổng.
    static func coTheDung(_ cfg: CTWProjectConfig?) -> Bool {
        cfg?.permissions?.useAi == true && cfg?.role != "CLIENT"
    }

    /// Việc một chạm theo loại thẻ — đúng thứ tự `itemsFor` của web.
    static func mucNhanh(loai: String?) -> [MucNhanhCuongMini] {
        let t = (loai ?? "").uppercased()
        var ds = [MucNhanhCuongMini(viec: .summarize)]
        if t == "EPIC" { ds.append(MucNhanhCuongMini(viec: .split, laEpic: true)) }
        if ["STORY", "TASK", "BUG"].contains(t) { ds.append(MucNhanhCuongMini(viec: .split)) }
        if t == "STORY" || t == "REQUIREMENT" { ds.append(MucNhanhCuongMini(viec: .generate_tests)) }
        if t == "BUG" { ds.append(MucNhanhCuongMini(viec: .improve_bug)) }
        if t == "STORY" || t == "REQUIREMENT" { ds.append(MucNhanhCuongMini(viec: .review_story)) }
        return ds
    }

    /// Thân `POST /ai/quick` (zod của `work.routes.ts`: task, issueNumber, threadId, label ≤ 120).
    static func thanViecNhanh(viec: ViecNhanhCuongMini, so: Int, threadId: Int, nhan: String) -> [String: Any] {
        ["task": viec.rawValue, "issueNumber": so, "threadId": threadId, "label": String(nhan.prefix(120))]
    }

    /// Câu hỏi gợi ý về một thẻ (máy chủ nhận `issueNumber` ⇒ câu không cần nhắc mã thẻ).
    static var goiYThe: [String] {
        [String(localized: "Explain this issue and how to do it step by step"),
         String(localized: "What do I need to read first?"),
         String(localized: "When is this issue done?")]
    }

    static var cauHomNay: String { String(localized: "What should I work on today?") }
}

// MARK: - Nút ✦ trên thanh điều hướng (trang dự án / Board / Backlog)

struct NutCuongMiniCTW: View {
    let pid: Int
    var maDuAn: String?
    @EnvironmentObject private var nganXep: NganXepCTW

    var body: some View {
        Button {
            CTWRung.chon()
            nganXep.duong.append(RouteCuongMiniCTW(pid: pid, maDuAn: maDuAn))
        } label: {
            Image(systemName: "sparkles")
                .font(.ctw(size: 15, weight: .semibold))
                .foregroundColor(AppColors.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(AppColors.primary.opacity(0.13)))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask CuongMini")
        .accessibilityHint("Opens the project's AI assistant")
        .accessibilityIdentifier("cuongmini.toolbar")
    }
}

// MARK: - Thẻ nổi bật "Hỏi CuongMini" (đầu trang More; My Work = "Hôm nay tôi nên làm gì?")

struct TheCuongMiniCTW: View {
    let pid: Int
    var maDuAn: String?
    var tenDuAn: String?
    /// My Work: hỏi ngay câu "hôm nay" khi bấm.
    var homNay = false
    @EnvironmentObject private var nganXep: NganXepCTW

    var body: some View {
        Button {
            CTWRung.chon()
            nganXep.duong.append(RouteCuongMiniCTW(pid: pid, maDuAn: maDuAn, khoiDau: homNay ? .hoi(CuongMini.cauHomNay) : nil))
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: homNay ? "sun.max.fill" : "sparkles")
                    .font(.ctw(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(LinearGradient(colors: [AppColors.primary, AppColors.primary.opacity(0.72)],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(homNay ? CuongMini.cauHomNay : String(localized: "Ask CuongMini"))
                            .font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        CTWNhanAI(chu: "AI")
                    }
                    Text(dongPhu).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.primary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AppColors.primary.opacity(0.35), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(homNay ? "cuongmini.today" : "cuongmini.card")
    }

    private var dongPhu: String {
        if homNay, let t = tenDuAn { return String(localized: "CuongMini plans your day in \(t)") }
        return String(localized: "Your project's AI assistant — ask about issues, docs and the sprint")
    }
}

// MARK: - Chi tiết thẻ: nút "CuongMini" + bảng việc một chạm / câu hỏi gợi ý

struct NutCuongMiniTheCTW: View {
    let cfg: CTWProjectConfig
    let the: TheCuongMini
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var mo = false
    /// Lựa chọn trong bảng — đẩy SAU khi bảng đóng (đẩy lúc tấm phủ còn đang đóng thì có lúc bị nuốt).
    @State private var chon: RouteCuongMiniCTW?

    var body: some View {
        Button { mo = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles").font(.ctw(size: 12, weight: .bold))
                Text(verbatim: "CuongMini").font(.ctw(size: 13, weight: .semibold))
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 11).frame(minHeight: 32)
            .background(Capsule().fill(AppColors.primary.opacity(0.12)))
            .overlay(Capsule().strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 0.5))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Ask CuongMini about \(cfg.key)-\(the.so)"))
        .accessibilityIdentifier("cuongmini.issue")
        .sheet(isPresented: $mo, onDismiss: {
            if let r = chon { chon = nil; nganXep.duong.append(r) }
        }) {
            // Cao hết cỡ: ở nửa màn, phần "Hỏi về thẻ này" nằm dưới mép — chính phần chủ app cần nhất.
            BangCuongMiniTheCTW(cfg: cfg, the: the) { r in chon = r; mo = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #if DEBUG
        .task {
            guard XemThuCTW.man?.lowercased() == "the:cuongmini" else { return }
            try? await Task.sleep(nanoseconds: 900_000_000)
            mo = true
        }
        #endif
    }
}

struct BangCuongMiniTheCTW: View {
    let cfg: CTWProjectConfig
    let the: TheCuongMini
    let chon: (RouteCuongMiniCTW) -> Void
    @Environment(\.dismiss) private var dong

    private func route(_ k: KhoiDauCuongMini?) -> RouteCuongMiniCTW {
        RouteCuongMiniCTW(pid: cfg.id, maDuAn: cfg.key, the: the, khoiDau: k)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles").font(.ctw(size: 16, weight: .bold)).foregroundColor(AppColors.onPrimary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(AppColors.primary))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(verbatim: "CuongMini").font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                                CTWNhanAI(chu: "AI")
                            }
                            Text(verbatim: "\(cfg.key)-\(the.so)" + (the.tieuDe.map { " · \($0)" } ?? ""))
                                .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
                Section {
                    ForEach(CuongMini.mucNhanh(loai: the.loai)) { m in
                        hang(m.nhan, m.bieuTuong, id: "cuongmini.quick.\(m.id)") { chon(route(.nhanh(m))) }
                    }
                } header: {
                    Text("Quick tasks")
                } footer: {
                    Text("CuongMini reads this issue, its comments and linked docs first. Nothing changes until you tap Apply.")
                }
                Section("Ask about this issue") {
                    ForEach(Array(CuongMini.goiYThe.enumerated()), id: \.offset) { i, c in
                        hang(c, "bubble.left.and.text.bubble.right", id: "cuongmini.ask.\(i)") { chon(route(.hoi(c))) }
                    }
                    hang(String(localized: "Ask something else…"), "square.and.pencil", id: "cuongmini.ask.other") { chon(route(nil)) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Ask CuongMini")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
        }
    }

    private func hang(_ chu: String, _ icon: String, id: String, _ bam: @escaping () -> Void) -> some View {
        Button(action: bam) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                    .frame(width: 24).accessibilityHidden(true)
                Text(chu).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

// MARK: - Móc vào chi tiết thẻ (Shared) — chỉ hiện khi được dùng AI trong dự án của thẻ

extension CTWIssueMoRong {
    @MainActor
    static func nutCuongMini(cfg: CTWProjectConfig, the: TheCuongMini) -> AnyView {
        CuongMini.coTheDung(cfg) ? AnyView(NutCuongMiniTheCTW(cfg: cfg, the: the)) : AnyView(EmptyView())
    }
}

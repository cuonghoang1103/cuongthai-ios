import SwiftUI

// MARK: - Thông báo Bảng tin theo từng không gian / dự án (`PUT /feed/follow`)
//
// ALL (mặc định): chuông cho mọi bài mới + @nhắc · MENTIONS: chỉ @nhắc · OFF: không gì từ phạm vi này (kể cả @nhắc).
// Hoạt động trên bài CỦA MÌNH (bình luận, trả lời, cảm xúc) luôn báo — nói rõ ở chân mục.
// Mở từ Cài đặt thông báo (Inbox/Account) — công tắc đẩy chung `push.feed` nằm ở đó.

struct CaiDatBangTinCTW: View {
    @ObservedObject private var kho = KhoBangTinCTW.shared
    @State private var loi: String?
    @State private var dangLuu: String?

    var body: some View {
        Form {
            if let loi { Section { CTWErrorBanner(text: loi) { self.loi = nil } }.listRowBackground(Color.clear) }
            ForEach(kho.phamVi?.scopes ?? []) { s in
                Section {
                    hang(ten: String(localized: "Workspace posts"), icon: "building.2", ws: s.workspace.id, pid: nil, muc: s.follow)
                    ForEach(s.projects ?? []) { p in
                        hang(ten: p.name ?? p.key ?? "", icon: "folder", ws: s.workspace.id, pid: p.id, muc: p.follow, ma: p.key)
                    }
                } header: {
                    Text(verbatim: s.workspace.name ?? "").textCase(nil)
                }
            }
            Section {
            } footer: {
                Text("Comments, replies and reactions on your own posts always notify you. Mentions follow these settings — Off silences mentions too.")
            }
        }
        .navigationTitle("Feed notifications")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if kho.phamVi == nil { ProgressView() } }
        .task { await kho.taiPhamVi() }
    }

    private func hang(ten: String, icon: String, ws: Int, pid: Int?, muc: String?, ma: String? = nil) -> some View {
        let khoa = "\(ws)-\(pid ?? 0)"
        return Picker(selection: Binding(get: { MucTheoDoiBangTin(rawValue: muc ?? "ALL") ?? .all },
                                         set: { m in Task { await luu(ws: ws, pid: pid, m, khoa: khoa) } })) {
            ForEach(MucTheoDoiBangTin.allCases) { m in Text(m.ten).tag(m) }
        } label: {
            HStack(spacing: 10) {
                if let ma { CTWProjectMark(ma: ma, co: 24) } else {
                    Image(systemName: icon).foregroundColor(AppColors.primary).frame(width: 24)
                }
                Text(verbatim: ten).lineLimit(1)
                if dangLuu == khoa { ProgressView().controlSize(.small) }
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("feed.follow.\(khoa)")
    }

    private func luu(ws: Int, pid: Int?, _ m: MucTheoDoiBangTin, khoa: String) async {
        dangLuu = khoa
        defer { dangLuu = nil }
        do {
            let r: CTWFeedTheoDoi = try await APIClient.shared.request(CTWAPI.bangTinTheoDoi(ws: ws, pid: pid, muc: m.rawValue))
            kho.datTheoDoi(ws: ws, pid: pid, muc: r.level ?? m.rawValue)
            CTWRung.chon()
        } catch { loi = BangTinLoi.chu(error) }
    }
}

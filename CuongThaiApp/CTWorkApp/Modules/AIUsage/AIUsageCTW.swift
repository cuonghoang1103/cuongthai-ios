import SwiftUI

// MARK: - "AI usage" (chỉ đọc) — dự án + không gian (web `aiUsage/AiUsageView.tsx`, `settings/ProjectAiUsage.tsx`)
//
// Ai đang dùng AI nối CT Work (CuongMini qua MCP, AI khác, trợ lý AI web, agent), lần gần nhất, số thao tác, token,
// chi phí theo nguồn (nhãn "ước lượng"/"tự khai" y như web), model và nhật ký thay đổi AI đã làm. Lọc khoảng ngày,
// thành viên (người xem được tất cả), dự án (cấp không gian).

extension CTWModule {
    static let aiUsage = CTWModule(
        id: "ai-usage", ten: "AI usage", bieuTuong: "chart.bar.doc.horizontal", nhom: .quanTri,
        moTa: "Who uses AI with CT Work, how much, and what it changed", thuTu: 60, doanWeb: nil,
        // Khách cổng ⇒ 403 ở máy chủ; ẩn luôn.
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(AIUsageCTW(nguCanh: c)) })
}

struct AIUsageCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @State private var pham: Pham = .duAn
    @State private var ws: Int?
    @State private var dl: TaiCTW<CTWAIUBaoCao> = .dangTai
    @State private var soNgay = 30
    @State private var tu = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
    @State private var den = Date()
    @State private var nguoi: Int?
    @State private var duAn: Int?
    @State private var moLich = false

    enum Pham: Hashable { case duAn, khongGian }

    private var laKhach: Bool { app.cauHinhDuAn?.workspaceRole == "GUEST" }
    private var khoa: String { "\(pham)-\(CTW.chuoiNgay(tu))-\(CTW.chuoiNgay(den))-\(nguoi ?? 0)-\(duAn ?? 0)" }

    var body: some View {
        VStack(spacing: 0) {
            if !laKhach {
                Picker("Scope", selection: $pham) {
                    Text("This project").tag(Pham.duAn)
                    Text("Workspace").tag(Pham.khongGian)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md).padding(.vertical, 8)
                .onChange(of: pham) { _, _ in nguoi = nil; duAn = nil }
            }
            KhungTaiCTW(trangThai: dl, thuLai: { Task { await tai() } }) { r in noiDung(r) }
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(Text("AI usage"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: khoa) { await tai() }
        .sheet(isPresented: $moLich) { chonNgay }
        #if DEBUG
        .onAppear { if XemThuCTW.conCua("ai-usage") == "ws" { pham = .khongGian } }
        #endif
    }

    private func tai() async {
        if case .xong = dl {} else { dl = .dangTai }
        do {
            let a = CTW.chuoiNgay(tu), b = CTW.chuoiNgay(den)
            let r: CTWAIUBaoCao
            if pham == .khongGian {
                if ws == nil { ws = await app.idKhongGian() }
                guard let ws else { dl = .loi(String(localized: "Couldn't find this workspace.")); return }
                r = try await APIClient.shared.request(CTWAPI.aiUsageKhongGian(ws: ws, tu: a, den: b, nguoi: nguoi, duAn: duAn))
            } else {
                r = try await APIClient.shared.request(CTWAPI.aiUsageDuAn(pid: nguCanh.pid, tu: a, den: b, nguoi: nguoi))
            }
            dl = .xong(r)
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "WORK_FORBIDDEN" || ma == "FORBIDDEN" || ma == "WORK_AGENT_FORBIDDEN" {
                dl = .loi(String(localized: "You can't see AI usage here."))
            } else {
                dl = .loi(CTW.loi(error))
            }
        }
    }

    // MARK: Nội dung

    private func noiDung(_ r: CTWAIUBaoCao) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Who uses AI connected to CT Work — CuongMini over MCP, other AI tools, the web AI assistant and agents — how many turns and tokens, the cost by source, and every change AI made.")
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                if r.canSeeAll != true {
                    Label("You only see your own usage. Project admins see everyone's.", systemImage: "person.crop.circle")
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                }
                boLoc(r)
                tongQuan(r.totals)
                if r.notes?.cuongMiniEstimated == true || r.notes?.agentSelfReported == true {
                    VStack(alignment: .leading, spacing: 6) {
                        if r.notes?.cuongMiniEstimated == true {
                            Text("CuongMini cost is an ESTIMATE: a CuongMini turn is counted for this project when it called this project's CT Work tools during that turn (team-quota turns are exact).")
                        }
                        if r.notes?.agentSelfReported == true {
                            Text("Agent cost marked “self-reported” is the number the agent reported to CT Work, not a measurement.")
                        }
                    }
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundTertiary))
                }
                CTWSectionHeader("person.2", String(localized: "AI users"), count: "\((r.people ?? []).count)")
                if (r.people ?? []).isEmpty {
                    Text("No AI usage in this period.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                }
                ForEach(r.people ?? []) { p in nguoiThe(p) }
                if let ms = r.models, !ms.isEmpty {
                    CTWSectionHeader("cpu", String(localized: "Models"))
                    VStack(spacing: 0) {
                        ForEach(Array(ms.enumerated()), id: \.offset) { i, m in
                            hangModel(m)
                            if i < ms.count - 1 { Divider().padding(.leading, 12) }
                        }
                    }
                    .ctwThe(14)
                }
                CTWSectionHeader("clock.arrow.circlepath", String(localized: "Changes made by AI (log)"))
                if (r.writes ?? []).isEmpty {
                    Text("AI changed nothing in this period.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                } else {
                    VStack(spacing: 0) {
                        let ws = Array((r.writes ?? []).prefix(60))
                        ForEach(Array(ws.enumerated()), id: \.element.id) { i, w in
                            hangThayDoi(w, r: r)
                            if i < ws.count - 1 { Divider().padding(.leading, 12) }
                        }
                    }
                    .ctwThe(14)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await tai() }
    }

    private func boLoc(_ r: CTWAIUBaoCao) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach([7, 30, 90], id: \.self) { n in
                        Button(String(localized: "Last \(n) days")) { datKhoang(n) }
                    }
                    Button("Custom range…") { moLich = true }
                } label: {
                    chip("calendar", soNgay > 0 ? String(localized: "Last \(soNgay) days")
                         : "\(CTW.ngayNgan(CTW.chuoiNgay(tu)) ?? "") – \(CTW.ngayNgan(CTW.chuoiNgay(den)) ?? "")")
                }
                if r.canSeeAll == true, let ms = r.members, !ms.isEmpty {
                    Menu {
                        Button("Everyone") { nguoi = nil }
                        ForEach(ms) { m in Button { nguoi = m.id } label: { Text(verbatim: m.ten) } }
                    } label: { chip("person", nguoi.flatMap { id in ms.first { $0.id == id }?.ten } ?? String(localized: "Everyone")) }
                }
                if pham == .khongGian, let ps = r.projects, !ps.isEmpty {
                    Menu {
                        Button("All projects") { duAn = nil }
                        ForEach(ps, id: \.self) { p in Button { duAn = p.id } label: { Text(verbatim: "\(p.key ?? "") · \(p.name ?? "")") } }
                    } label: { chip("folder", duAn.flatMap { id in ps.first { $0.id == id }?.key } ?? String(localized: "All projects")) }
                }
            }
        }
    }

    private func chip(_ bieuTuong: String, _ chu: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: bieuTuong).font(.ctw(size: 11, weight: .semibold))
            Text(verbatim: chu).font(.ctw(size: 13, weight: .medium)).fixedSize()
            Image(systemName: "chevron.down").font(.ctw(size: 9, weight: .bold))
        }
        .foregroundColor(AppColors.textPrimary)
        .padding(.horizontal, 12).frame(minHeight: 34)
        .background(Capsule().fill(AppColors.backgroundCard))
        .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 0.5))
    }

    private func datKhoang(_ n: Int) {
        soNgay = n
        den = Date()
        tu = Calendar.current.date(byAdding: .day, value: -(n - 1), to: den) ?? den
    }

    private var chonNgay: some View {
        NavigationStack {
            Form {
                DatePicker("From", selection: $tu, in: ...den, displayedComponents: .date)
                DatePicker("To", selection: $den, in: tu...Date(), displayedComponents: .date)
            }
            .navigationTitle(Text("Custom range"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { soNgay = 0; moLich = false } } }
        }
        .presentationDetents([.medium])
    }

    private func tongQuan(_ t: CTWAIUBaoCao.Tong?) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            o(String(localized: "AI users"), CTWDinhDang.so(t?.people ?? 0))
            o(String(localized: "CT Work actions"), CTWDinhDang.so(t?.toolCalls ?? 0))
            o(String(localized: "Changes by AI"), CTWDinhDang.so(t?.writes ?? 0), nhan: true)
            o(String(localized: "Tokens"), CTWDinhDang.so((t?.inputTokens ?? 0) + (t?.outputTokens ?? 0)))
            o(String(localized: "Official ($)"), NhanAIU.usd(t?.chinhHangUsd))
            o(String(localized: "CuongMini Core ($)"), NhanAIU.usd(t?.modelapiUsd))
            o(String(localized: "Classic (turns, flat plan)"), NhanAIU.so(t?.ramboTurns))
            o(String(localized: "Agents ($, self-reported)"), NhanAIU.usd(t?.agentUsd))
        }
    }

    private func o(_ nhan: String, _ gt: String, nhan dam: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: gt).font(.ctw(size: 20, weight: .semibold)).monospacedDigit()
                .foregroundColor(dam ? AppColors.primary : AppColors.textPrimary)
            Text(nhan).font(.ctw(size: 11.5)).foregroundColor(AppColors.textSecondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .ctwThe(12)
        .accessibilityElement(children: .combine)
    }

    private func nguoiThe(_ p: CTWAIUBaoCao.Nguoi) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CTWAvatar(user: p.user, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: p.user?.ten ?? "#\(p.userId)").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text(verbatim: (p.clients ?? []).map(NhanAIU.qua).joined(separator: ", "))
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                if let l = p.lastUsedAt { Text(verbatim: CTW.thoiDiem(l)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
            }
            HStack(spacing: 14) {
                so(String(localized: "Actions"), CTWDinhDang.so(p.toolCalls ?? 0) + ((p.failed ?? 0) > 0 ? " (\(p.failed ?? 0) ✕)" : ""))
                so(String(localized: "Changes"), CTWDinhDang.so(p.writes ?? 0))
                so(String(localized: "Tokens in / out"), (p.inputTokens ?? 0) + (p.outputTokens ?? 0) > 0
                   ? "\(CTWDinhDang.so(p.inputTokens ?? 0)) / \(CTWDinhDang.so(p.outputTokens ?? 0))" : "—")
            }
            let chiPhi = [
                (p.chinhHangUsd ?? 0) > 0 ? "\(String(localized: "Official")) \(NhanAIU.usd(p.chinhHangUsd))" : nil,
                (p.modelapiUsd ?? 0) > 0 ? "Core \(NhanAIU.usd(p.modelapiUsd))" : nil,
                (p.ramboTurns ?? 0) > 0 ? "Classic \(NhanAIU.luot(p.ramboTurns))" : nil,
            ].compactMap { $0 }
            if !chiPhi.isEmpty || (p.agentUsd ?? 0) > 0 {
                HStack(spacing: 6) {
                    if !chiPhi.isEmpty { Text(verbatim: chiPhi.joined(separator: " · ")) }
                    if (p.agentUsd ?? 0) > 0 {
                        Text(verbatim: "\(String(localized: "Agent")) \(NhanAIU.usd(p.agentUsd))")
                        NhanTuKhaiCTW()
                    }
                }
                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            if let ms = p.models, !ms.isEmpty {
                Text(verbatim: ms.joined(separator: ", ")).font(.ctw(size: 11.5)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(12)
        .ctwThe(14)
    }

    private func so(_ nhan: String, _ gt: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: gt).font(.ctw(size: 14, weight: .semibold)).monospacedDigit().foregroundColor(AppColors.textPrimary)
            Text(nhan).font(.ctw(size: 10.5)).foregroundColor(AppColors.textTertiary)
        }
    }

    private func hangModel(_ m: CTWAIUBaoCao.Model) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: m.name ?? "").font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                Text(verbatim: "\(NhanAIU.qua(m.via)) · \(NhanAIU.nguon(m.source))").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: m.source == "rambo" ? NhanAIU.luot(m.turns) : NhanAIU.usd(m.costUsd))
                    .font(.ctw(size: 13, weight: .semibold)).monospacedDigit()
                Text(verbatim: NhanAIU.luot(m.turns)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func hangThayDoi(_ w: CTWAIUBaoCao.ThayDoi, r: CTWAIUBaoCao) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: w.ok == false ? "xmark.octagon" : "checkmark.circle")
                .foregroundColor(w.ok == false ? AppColors.error : AppColors.success).font(.ctw(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: w.tool ?? "").font(.ctw(size: 13, design: .monospaced)).foregroundColor(AppColors.textPrimary)
                    let dt = [pham == .khongGian ? w.project?.key : nil, w.target].compactMap { $0 }.filter { !$0.isEmpty }
                    if !dt.isEmpty { Text(verbatim: dt.joined(separator: " · ")).font(.ctw(size: 12, design: .monospaced)).foregroundColor(AppColors.textSecondary) }
                }
                Text(verbatim: [w.user?.ten, NhanAIU.qua(w.client), CTW.thoiDiem(w.at)].compactMap { $0 }.joined(separator: " · "))
                    .font(.ctw(size: 11.5)).foregroundColor(AppColors.textTertiary)
                if w.ok == false {
                    Text(w.errorCode.map { String(localized: "Refused · \($0)") } ?? String(localized: "Refused"))
                        .font(.ctw(size: 11.5)).foregroundColor(AppColors.error)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }
}

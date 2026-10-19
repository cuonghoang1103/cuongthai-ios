import SwiftUI
import WebKit

// MARK: - Xem một mẫu báo cáo (Report builder) — CHỈ XEM
//
// `POST /report-builder/preview {ref}` trả báo cáo ĐÃ DỰNG với số liệu sống. Dựng gốc các khối
// heading/text/kpis/issues/risks/ai/error. Khối biểu đồ máy chủ chỉ trả SVG (không có chuỗi số liệu)
// ⇒ hiện SVG bằng WKWebView NHỎ chỉ để vẽ nội dung (không tải trang nào, không chạy JS, không mạng).
// Soạn mẫu, xuất PDF/DOCX, hẹn lịch gửi: làm trên web.

struct XemBaoCaoCTW: View {
    let pid: Int
    let ref: String
    let ten: String
    @State private var tt: TaiCTW<CTWBaoCaoDungDb> = .dangTai

    var body: some View {
        KhungTaiCTW(trangThai: tt, thuLai: { Task { await tai() } }) { bc in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    dau(bc)
                    ForEach(bc.blocks ?? []) { k in khoi(k) }
                    Text("Generated \(CTW.thoiDiem(bc.generatedAt)) from live project data.")
                        .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                .padding(Spacing.md)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(ten)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if tt.giaTri == nil { await tai() } }
    }

    private func tai() async {
        do {
            let r: CTWBaoCaoDungDb = try await APIClient.shared.request(CTWAPI.xemTruocBaoCao(pid: pid, ref: ref))
            tt = .xong(r)
        } catch {
            if tt.giaTri == nil { tt = .loi(CTW.loi(error)) }
        }
    }

    private func dau(_ bc: CTWBaoCaoDungDb) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bc.title ?? ten).font(.ctw(size: 24, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let s = bc.subtitle, !s.isEmpty { Text(s).font(.ctw(size: 15)).foregroundColor(AppColors.textSecondary) }
            if let a = NgayCTW.nganTu(bc.period?.from), let b = NgayCTW.nganTu(bc.period?.to) {
                Label("\(a) – \(b)", systemImage: "calendar").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            Rectangle().fill(CTW.mau(bc.accent, macDinh: AppColors.primary)).frame(width: 48, height: 3).padding(.top, 4)
        }
    }

    @ViewBuilder
    private func khoi(_ k: CTWKhoiBaoCaoDb) -> some View {
        switch k.type {
        case "heading":
            Text(k.text ?? "").font(.ctw(size: (k.level ?? 1) == 1 ? 20 : ((k.level ?? 1) == 2 ? 17 : 15), weight: .bold))
                .foregroundColor(AppColors.textPrimary).padding(.top, 6)
        case "text":
            CTWMarkdownView(markdown: k.text ?? "", coChu: 15)
        case "pageBreak":
            Divider().padding(.vertical, 4)
        case "kpis":
            VStack(alignment: .leading, spacing: 8) {
                if let t = k.title, !t.isEmpty { tieuDeKhoi(t) }
                CTWLuoiChiSo {
                    ForEach(Array((k.items ?? []).enumerated()), id: \.offset) { _, m in
                        CTWTheChiSo(nhan: m.label ?? m.key ?? "", giaTri: m.value ?? "—", phu: m.hint)
                    }
                }
            }
        case "chart":
            VStack(alignment: .leading, spacing: 8) {
                if let t = k.title, !t.isEmpty { tieuDeKhoi(t) }
                SvgBaoCaoCTW(svg: k.svg ?? "")
                    .aspectRatio(720.0 / 300.0, contentMode: .fit)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
                    .accessibilityLabel(k.title ?? "Chart")
            }
        case "issues":
            bangThe(k)
        case "risks":
            VStack(alignment: .leading, spacing: 8) {
                tieuDeKhoi(k.title ?? "Risks")
                if (k.items ?? []).isEmpty { Text(k.note ?? "No open risks.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary) }
                ForEach(Array((k.items ?? []).enumerated()), id: \.offset) { _, r in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(r.key ?? "").font(.ctw(size: 11, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                            Text(r.title ?? "").font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                            Spacer()
                            if let l = r.level { Text(l).font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.warning) }
                        }
                        if let m = r.mitigation, !m.isEmpty { Text(m).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading).ctwThe(10)
                }
            }
        case "ai":
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    tieuDeKhoi(k.title ?? "Summary")
                    CTWNhanAI(chu: "AI-drafted")
                }
                CTWMarkdownView(markdown: k.text ?? "", coChu: 14)
                if let n = k.note, !n.isEmpty { Text(n).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
            }
            .padding(12).ctwThe(12)
        case "error":
            CTWErrorBanner(text: k.message ?? "This block couldn't be built.")
        default:
            EmptyView()
        }
    }

    private func khoaCot(_ k: CTWKhoiBaoCaoDb, _ i: Int) -> String? {
        guard let c = k.colKeys, i < c.count else { return nil }
        return c[i]
    }

    private func tieuDeKhoi(_ t: String) -> some View {
        Text(t).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
    }

    private func bangThe(_ k: CTWKhoiBaoCaoDb) -> some View {
        let cot = k.columns ?? []
        let hang = k.rows ?? []
        return VStack(alignment: .leading, spacing: 8) {
            if let t = k.title, !t.isEmpty { tieuDeKhoi(t) }
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    GridRow {
                        ForEach(Array(cot.enumerated()), id: \.offset) { _, c in
                            Text(c).font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary).fixedSize()
                        }
                    }
                    Divider()
                    ForEach(Array(hang.enumerated()), id: \.offset) { _, h in
                        GridRow {
                            ForEach(Array(h.enumerated()), id: \.offset) { i, o in
                                Text(o).font(.ctw(size: 12)).foregroundColor(i == 0 ? AppColors.textSecondary : AppColors.textPrimary)
                                    .lineLimit(2).frame(maxWidth: (khoaCot(k, i) == "title") ? 260 : nil, alignment: .leading)
                                    .fixedSize(horizontal: khoaCot(k, i) != "title", vertical: false)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .ctwThe(12)
            if let t = k.total, t > hang.count {
                Text("Showing \(hang.count) of \(t)").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
            }
        }
    }
}


/// Vẽ SVG của máy chủ (chữ đã là path). Không JS, không tải gì ngoài chuỗi SVG.
struct SvgBaoCaoCTW: UIViewRepresentable {
    let svg: String

    func makeUIView(context: Context) -> WKWebView {
        let c = WKWebViewConfiguration()
        c.defaultWebpagePreferences.allowsContentJavaScript = false
        let v = WKWebView(frame: .zero, configuration: c)
        v.isOpaque = false
        v.backgroundColor = .clear
        v.scrollView.isScrollEnabled = false
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ v: WKWebView, context: Context) {
        // Chỉ nhận SVG: chuỗi phải bắt đầu bằng <svg — không dựng HTML tuỳ ý từ máy chủ.
        let s = svg.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("<svg") else { v.loadHTMLString("", baseURL: nil); return }
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:">
        <style>html,body{margin:0;padding:0;background:transparent}svg{width:100%;height:auto;display:block}</style>
        </head><body>\(s)</body></html>
        """
        v.loadHTMLString(html, baseURL: nil)
    }
}

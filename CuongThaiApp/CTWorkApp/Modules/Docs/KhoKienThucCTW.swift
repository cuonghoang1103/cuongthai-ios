import SwiftUI

// MARK: - Kho kiến thức (KB) — `GET /projects/:pid/kb`
//
// Bài KB là một trang Docs kèm siêu dữ liệu (danh mục, đối tượng, số đọc/hữu ích).
// Đọc/sửa bài = mở trang Docs của nó (cùng màn đọc/sửa ⇒ cùng giao thức lưu an toàn).

struct KhoKienThucCTW: View {
    let pid: Int
    @State private var du: CTWKb?
    @State private var loi: String?
    @State private var danhMuc: Int?
    @State private var tim = ""

    var body: some View {
        List {
            if let loi { CTWErrorBanner(text: loi) { self.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if let du {
                if let t = du.totals {
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                            CTWODem(so: "\(t.articles ?? 0)", nhan: "Articles", bieuTuong: "doc.richtext")
                            CTWODem(so: "\(t.forClients ?? 0)", nhan: "Visible to clients", bieuTuong: "person.2.wave.2", mau: AppColors.secondary)
                            CTWODem(so: "\(t.views ?? 0)", nhan: "Views", bieuTuong: "eye", mau: Color(hex: 0x2563EB))
                            CTWODem(so: "\(t.deflected ?? 0)", nhan: "Questions answered by an article", bieuTuong: "checkmark.bubble", mau: AppColors.success)
                        }
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    }
                }
                let dm = du.categories ?? []
                if !dm.isEmpty {
                    Section {
                        CTWThanhLoc(chip: [CTWChipLoc(id: "all", nhan: "All", bat: danhMuc == nil)] + dm.map {
                            CTWChipLoc(id: "\($0.id)", nhan: "\($0.name) · \($0.articles ?? 0)", bat: danhMuc == $0.id)
                        }) { c in danhMuc = c.id == "all" ? nil : Int(c.id) }
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    }
                }
                let ds = loc(du.articles ?? [])
                Section {
                    if ds.isEmpty {
                        CTWOTrong(bieuTuong: "books.vertical", tieuDe: (du.articles ?? []).isEmpty ? "No articles yet" : "No matches",
                                  moTa: (du.articles ?? []).isEmpty ? "Admins publish Docs pages as help articles on the web." : "")
                            .listRowBackground(Color.clear)
                    }
                    ForEach(ds) { a in
                        NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: a.pageNumber, ten: a.title ?? "Article")) { hang(a) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if du == nil && loi == nil { CTWKhungTai(soHang: 5, coAvatar: false) } }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search articles")
        .navigationTitle("Knowledge base")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if du == nil { await tai() } }
    }

    private func loc(_ ds: [CTWKb.BaiViet]) -> [CTWKb.BaiViet] {
        let q = tim.trimmingCharacters(in: .whitespaces).lowercased()
        return ds.filter { a in
            (danhMuc == nil || a.category?.id == danhMuc)
                && (q.isEmpty || (a.title ?? "").lowercased().contains(q) || (a.excerpt ?? "").lowercased().contains(q))
        }
    }

    private func hang(_ a: CTWKb.BaiViet) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(a.title ?? "Untitled").font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                Spacer(minLength: 4)
                if a.published != true { CTWNhanNho(chu: "Unpublished", mau: AppColors.warning) }
            }
            if let e = a.excerpt, !e.isEmpty {
                Text(e).font(.system(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
            }
            HStack(spacing: 8) {
                if let c = a.category?.name { CTWNhanNho(chu: c, bieuTuong: "folder") }
                CTWNhanNho(chu: a.audience == "CLIENT" ? "Clients" : "Team", bieuTuong: a.audience == "CLIENT" ? "person.2.wave.2" : "person.3",
                           mau: a.audience == "CLIENT" ? AppColors.secondary : AppColors.textSecondary)
                Label("\(a.views ?? 0)", systemImage: "eye").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                if let h = a.helpfulPercent {
                    Label("\(h)%", systemImage: "hand.thumbsup").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func tai() async {
        do { du = try await APIClient.shared.request(CTWAPI.kb(pid: pid)); loi = nil }
        catch {
            if case APIError.coMa(let ma, _) = error, ma == "MODULE_DISABLED" {
                loi = "Docs are turned off for this project, so the knowledge base is unavailable."
            } else { loi = CTW.loi(error) }
        }
    }
}

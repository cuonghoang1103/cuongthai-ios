import SwiftUI
import PhotosUI

// MARK: - Docs — SOẠN một trang (tiêu đề + nội dung markdown)
//
// Giao thức lưu an toàn: xem `SuaTrangLogic.swift`. Màn này KHÔNG BAO GIỜ ghi đè
// trang khi phát hiện người khác vừa sửa — chỉ đưa lựa chọn.

@MainActor
final class SuaTrangVM: ObservableObject {
    enum TrangThai: Equatable { case dangTai, san, khongSua(String), loi(String) }
    struct XungDot: Identifiable, Equatable { let id = UUID(); var nguoi: String?; var banMoi: String }

    let pid: Int
    let so: Int
    @Published var trangThai: TrangThai = .dangTai
    @Published var tieuDe = ""
    @Published var noiDung = ""
    @Published var dangLuu = false
    @Published var dangTaiAnh = false
    @Published var loi: String?
    @Published var khoaSua = false
    @Published var xungDot: XungDot?

    /// Mốc của máy chủ (bước 1 của giao thức).
    private var v0: Int?
    private var md0 = ""
    private var tieuDe0 = ""
    private var noiDung0 = ""

    init(pid: Int, so: Int) { self.pid = pid; self.so = so }

    var daSua: Bool { tieuDe != tieuDe0 || noiDung != noiDung0 }

    func tai() async {
        do {
            let (ct, raw) = try await taiTrang()
            if let ly = CTWSuaTrang.lyDoKhongSuaDuoc(raw) { trangThai = .khongSua(ly); return }
            if ct.status == "ARCHIVED" { trangThai = .khongSua("Archived pages are read-only. Move the page back to Draft to edit it."); return }
            if ct.canEdit == false { trangThai = .khongSua("You can read this page but not edit it."); return }
            let md: CTWPageMarkdown = try await APIClient.shared.request(CTWAPI.trangMarkdown(pid: pid, so: so))
            v0 = ct.version
            md0 = md.markdown ?? ""
            tieuDe = ct.title; tieuDe0 = ct.title
            noiDung = CTWSuaTrang.boTieuDe(md0, tieuDe: ct.title); noiDung0 = noiDung
            if let k: CTWEditLock = try? await APIClient.shared.request(CTWAPI.khoaSua(pid: pid)) { khoaSua = k.locked == true }
            trangThai = .san
        } catch {
            trangThai = .loi(CTW.loi(error))
        }
    }

    /// GET trang dạng THÔ: vừa giải mã model, vừa giữ JSON gốc của `contentJson` để
    /// soát kiểu nút (model `CTWNode` bỏ qua thuộc tính như `colspan`).
    private func taiTrang() async throws -> (CTWPageDetail, Any?) {
        let d = try await APIClient.shared.requestRaw(CTWAPI.trang(pid: pid, so: so))
        let bao = try JSONDecoder().decode(APIResponse<CTWPageDetail>.self, from: d)
        guard let ct = bao.data else { throw APIError.noData }
        let goc = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
        let raw = (goc?["data"] as? [String: Any])?["contentJson"]
        return (ct, raw)
    }

    /// Lưu. `true` = đã ghi xong.
    func luu() async -> Bool {
        guard daSua, !dangLuu else { return !daSua }
        let td = tieuDe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !td.isEmpty else { loi = "Give the page a title."; return false }
        dangLuu = true
        defer { dangLuu = false }
        do {
            // Bước 2: PATCH kèm `baseVersion` — máy chủ tự chốt Yjs rồi so, lệch ⇒ 409.
            let sau: CTWPageDetail = try await APIClient.shared.request(CTWAPI.suaTrang(
                pid: pid, so: so, phienBan: v0,
                tieuDe: td != tieuDe0 ? td : nil,
                markdown: noiDung != noiDung0 ? noiDung : nil))
            // Mốc mới = trạng thái máy chủ SAU khi lưu.
            v0 = sau.version ?? v0.map { $0 + 1 }
            if let m: CTWPageMarkdown = try? await APIClient.shared.request(CTWAPI.trangMarkdown(pid: pid, so: so)) {
                md0 = m.markdown ?? md0
            }
            tieuDe0 = td; tieuDe = td
            noiDung0 = noiDung
            loi = nil
            CTWRung.thanhCong()
            return true
        } catch {
            if CTWSuaTrang.laXungDotTrang(error) {
                // Trang đã đổi trên máy chủ: lấy bản mới + người sửa để hiện "reload / compare".
                let moi: CTWPageDetail? = try? await APIClient.shared.request(CTWAPI.trang(pid: pid, so: so))
                let m: CTWPageMarkdown? = try? await APIClient.shared.request(CTWAPI.trangMarkdown(pid: pid, so: so))
                xungDot = XungDot(nguoi: moi?.lastEditedBy?.ten,
                                  banMoi: CTWSuaTrang.boTieuDe(m?.markdown ?? "", tieuDe: moi?.title ?? tieuDe))
                CTWRung.loi()
                return false
            }
            if case APIError.coMa(let ma, _) = error, ma == "WORK_EDIT_LOCKED" { khoaSua = true }
            loi = CTW.loi(error)
            CTWRung.loi()
            return false
        }
    }

    /// "Tải lại": bỏ bản của mình, nạp bản mới nhất của máy chủ làm mốc mới.
    func taiLaiBanMoi() async {
        xungDot = nil
        await tai()
    }

    func moKhoa() async {
        do {
            let k: CTWEditLock = try await APIClient.shared.request(CTWAPI.moKhoaSua(pid: pid))
            khoaSua = k.locked == true
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error) }
    }

    /// Lối thoát của xung đột: lưu bản của mình thành TRANG CON mới — không mất chữ, không đè ai.
    func luuThanhTrangCon() async -> CTWPageDetail? {
        do {
            let t: CTWPageDetail = try await APIClient.shared.request(CTWAPI.taoTrang(
                pid: pid, tieuDe: "\(tieuDe) (my version)", trangCha: so, markdown: noiDung))
            noiDung0 = noiDung; tieuDe0 = tieuDe
            CTWRung.thanhCong()
            return t
        } catch { loi = CTW.loi(error); return nil }
    }

    func taiAnh(_ du: Data) async -> String? {
        dangTaiAnh = true
        defer { dangTaiAnh = false }
        #if canImport(UIKit)
        guard let jpg = CTWTaiAnhTaiLieu.chuanBi(du) else { loi = "This image format isn't supported."; return nil }
        #else
        let jpg = du
        #endif
        do {
            let a = try await CTWTaiAnhTaiLieu.taiLen(pid: pid, du: jpg, ten: "Photo \(CTW.tenTepTheoGio()).jpg")
            return a.url
        } catch { loi = CTW.loi(error); return nil }
    }
}

struct SuaTrangCTW: View {
    let pid: Int
    let so: Int
    let slug: String
    let maDuAn: String
    var xong: (() -> Void)?

    @StateObject private var vm: SuaTrangVM
    @StateObject private var boSoan = CTWBoSoan()
    @Environment(\.dismiss) private var dong
    @State private var xemTruoc = false
    @State private var tamPhu: TamPhu?
    @State private var chonAnh: PhotosPickerItem?
    @State private var moThuVien = false
    @State private var hoiNguonAnh = false
    @State private var hoiBo = false
    @State private var hoiLienKet = false
    @State private var lkChu = ""
    @State private var lkUrl = "https://"

    private enum TamPhu: Identifiable {
        case mayAnh, chonThe, web, xungDot(SuaTrangVM.XungDot)
        var id: String {
            switch self {
            case .mayAnh: return "cam"
            case .web: return "web"
            case .chonThe: return "the"
            case .xungDot(let x): return "xd-\(x.id)"
            }
        }
    }

    init(pid: Int, so: Int, slug: String, maDuAn: String, xong: (() -> Void)? = nil) {
        self.pid = pid; self.so = so; self.slug = slug; self.maDuAn = maDuAn; self.xong = xong
        _vm = StateObject(wrappedValue: SuaTrangVM(pid: pid, so: so))
    }

    var body: some View {
        NavigationStack {
            noiDung
                .background(AppColors.backgroundPrimary)
                .navigationTitle(vm.daSua ? "Editing •" : "Editing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { if vm.daSua { hoiBo = true } else { dong() } }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        if vm.trangThai == .san {
                            Button { withAnimation { xemTruoc.toggle() } } label: {
                                Image(systemName: xemTruoc ? "pencil" : "eye")
                            }
                            .accessibilityLabel(xemTruoc ? "Edit" : "Preview")
                            Button {
                                Task { if await vm.luu() { xong?(); dong() } }
                            } label: {
                                if vm.dangLuu { ProgressView() } else { Text("Save").bold() }
                            }
                            .disabled(!vm.daSua || vm.dangLuu || vm.khoaSua)
                        }
                    }
                }
        }
        .interactiveDismissDisabled(vm.daSua)
        .task { if vm.trangThai == .dangTai { await vm.tai() } }
        .onChange(of: vm.xungDot) { _, x in if let x { tamPhu = .xungDot(x) } }
        .confirmationDialog("Discard your changes?", isPresented: $hoiBo, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dong() }
            Button("Keep editing", role: .cancel) {}
        }
        .confirmationDialog("Insert image", isPresented: $hoiNguonAnh, titleVisibility: .visible) {
            #if os(iOS)
            if MayAnh.coMayAnh { Button("Take Photo") { tamPhu = .mayAnh } }
            #endif
            Button("Choose from Photos") { moThuVien = true }
        }
        .photosPicker(isPresented: $moThuVien, selection: $chonAnh, matching: .images)
        .onChange(of: chonAnh) { _, muc in
            guard let muc else { return }
            Task {
                if let du = try? await muc.loadTransferable(type: Data.self), let url = await vm.taiAnh(du) {
                    boSoan.chenKhoi("![Image](\(url))")
                }
                chonAnh = nil
            }
        }
        .alert("Insert link", isPresented: $hoiLienKet) {
            TextField("Text", text: $lkChu)
            TextField("https://…", text: $lkUrl).keyboardType(.URL).textInputAutocapitalization(.never)
            Button("Insert") {
                let u = lkUrl.trimmingCharacters(in: .whitespaces)
                guard u.hasPrefix("http") else { return }
                let c = lkChu.trimmingCharacters(in: .whitespaces)
                boSoan.chen("[\(c.isEmpty ? u : c)](\(u))")
                lkChu = ""; lkUrl = "https://"
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .mayAnh:
                #if os(iOS)
                MayAnh { du in
                    Task { if let url = await vm.taiAnh(du) { boSoan.chenKhoi("![Photo](\(url))") } }
                }
                .ignoresSafeArea()
                #else
                EmptyView()
                #endif
            case .web:
                if let u = CTWWeb.url(slug: slug, ma: maDuAn, doan: "docs/\(so)") { SafariCTW(url: u).ignoresSafeArea() }
            case .chonThe:
                ChonTheCTW(pid: pid, tieuDe: "Link an issue") { the in
                    boSoan.chen(CTWSuaTrang.lienKetThe(slug: slug, maDuAn: maDuAn, so: the.number, tieuDe: the.title))
                    Task { _ = try? await APIClient.shared.send(CTWAPI.ganTheVaoTrang(pid: pid, so: so, the: the.number)) }
                }
            case .xungDot(let x):
                XungDotTrangCTW(xungDot: x, banCuaToi: vm.noiDung,
                                luuTrangCon: {
                                    if await vm.luuThanhTrangCon() != nil { xong?(); dong() }
                                },
                                taiLai: { Task { await vm.taiLaiBanMoi() } })
            }
        }
    }

    @ViewBuilder
    private var noiDung: some View {
        switch vm.trangThai {
        case .dangTai:
            CTWKhungTai(soHang: 4, coAvatar: false).frame(maxHeight: .infinity, alignment: .top)
        case .loi(let l):
            CTWOLoi(loi: l) { Task { await vm.tai() } }
        case .khongSua(let l):
            // Không đẩy người dùng "lên web" như lối duy nhất (4.2) — nói rõ lý do, cho lối mở trang đầy đủ.
            CTWOTrong(bieuTuong: "lock.doc", tieuDe: "Can't edit this page here", moTa: l,
                      nut: "Open the full editor", hanhDong: { tamPhu = .web })
        case .san:
            VStack(spacing: 0) {
                if vm.khoaSua {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill").foregroundColor(AppColors.warning)
                        Text("Editing is locked for this project on your account.")
                            .font(.system(size: 13)).foregroundColor(AppColors.textPrimary)
                        Spacer(minLength: 0)
                        Button("Unlock") { Task { await vm.moKhoa() } }.font(.system(size: 13, weight: .semibold))
                    }
                    .padding(12)
                    .background(AppColors.warning.opacity(0.12))
                }
                if let l = vm.loi { CTWErrorBanner(text: l) { vm.loi = nil }.padding(.horizontal, 12).padding(.top, 8) }
                TextField("Untitled", text: $vm.tieuDe, axis: .vertical)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
                    .disabled(xemTruoc)
                    .accessibilityLabel("Page title")
                Divider().padding(.horizontal, 16)
                if xemTruoc {
                    ScrollView {
                        CTWMarkdownView(markdown: vm.noiDung.isEmpty ? "_Nothing to preview_" : vm.noiDung, coChu: 15.5)
                            .padding(16)
                            .frame(maxWidth: 760, alignment: .leading)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    #if os(iOS)
                    CTWOSoanTaiLieu(chu: $vm.noiDung, boSoan: boSoan, coChu: 16)
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                    #else
                    TextEditor(text: $vm.noiDung)
                    #endif
                }
            }
            .overlay {
                if vm.dangTaiAnh {
                    HStack(spacing: 8) { ProgressView(); Text("Uploading image…").font(.system(size: 13, weight: .medium)) }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !xemTruoc {
                    CTWThanhDinhDang(boSoan: boSoan,
                                     chenAnh: { hoiNguonAnh = true },
                                     chenThe: { tamPhu = .chonThe },
                                     chenLienKet: { hoiLienKet = true })
                }
            }
        }
    }
}

// MARK: - So sánh theo dòng (bản của tôi ⇄ bản mới)

struct SoSanhTrangCTW: View {
    let dong: [CTWSuaTrang.DongSoSanh]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Label("Only in yours", systemImage: "minus.square.fill").foregroundColor(AppColors.error)
                Label("Only in latest", systemImage: "plus.square.fill").foregroundColor(AppColors.success)
            }
            .font(.system(size: 12, weight: .semibold))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(dong.enumerated()), id: \.offset) { _, d in hang(d) }
            }
            .padding(10)
            .ctwThe(12)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func hang(_ d: CTWSuaTrang.DongSoSanh) -> some View {
        switch d {
        case .giong(let t): dongChu(" ", t, nen: .clear, mau: AppColors.textSecondary)
        case .chiCuaToi(let t): dongChu("−", t, nen: AppColors.error.opacity(0.12), mau: AppColors.textPrimary)
            .accessibilityLabel("Only in yours: \(t)")
        case .chiBanMoi(let t): dongChu("+", t, nen: AppColors.success.opacity(0.12), mau: AppColors.textPrimary)
            .accessibilityLabel("Only in latest: \(t)")
        }
    }

    private func dongChu(_ dau: String, _ t: String, nen: Color, mau: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(dau).font(.system(size: 13, weight: .bold).monospaced()).foregroundColor(mau).frame(width: 12)
            Text(t.isEmpty ? " " : t).font(.system(size: 13).monospaced()).foregroundColor(mau)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2).padding(.horizontal, 4)
        .background(nen)
    }
}

// MARK: - Xung đột: người khác vừa sửa trang

struct XungDotTrangCTW: View {
    let xungDot: SuaTrangVM.XungDot
    let banCuaToi: String
    let luuTrangCon: () async -> Void
    let taiLai: () -> Void
    @Environment(\.dismiss) private var dong
    @State private var dangLuu = false
    @State private var daChep = false
    /// "Latest" = xem bản mới · "Compare" = so dòng của mình với bản mới.
    @State private var cheDo = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "person.2.badge.gearshape.fill")
                            .font(.system(size: 22)).foregroundColor(AppColors.warning)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(AppColors.warning.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This page changed while you were editing")
                                .font(.system(size: 17, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(xungDot.nguoi.map { "\($0) saved a newer version. " } ?? "Someone saved a newer version. ")Your changes were NOT saved, so nothing of theirs was overwritten. Reload the latest version or compare it with yours.")
                                .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    VStack(spacing: 10) {
                        nut("doc.badge.plus", "Save mine as a subpage", "Keeps both versions — merge them later.", chinh: true) {
                            dangLuu = true
                            Task { await luuTrangCon(); dangLuu = false; dong() }
                        }
                        nut(daChep ? "checkmark" : "doc.on.doc", daChep ? "Copied" : "Copy my text", "Paste it anywhere, then reload.") {
                            CTW.chepVaoBoNho(banCuaToi); daChep = true; CTWRung.thanhCong()
                        }
                        nut("arrow.clockwise", "Reload the latest version", "Discards your changes and starts from theirs.", nguyHiem: true) {
                            dong(); taiLai()
                        }
                    }
                    Picker("View", selection: $cheDo) {
                        Text("Latest version").tag(0)
                        Text("Compare").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 6)
                    if cheDo == 0 {
                        CTWMarkdownView(markdown: xungDot.banMoi.isEmpty ? "_Empty page_" : xungDot.banMoi, coChu: 14)
                            .padding(14).ctwThe(12)
                    } else {
                        SoSanhTrangCTW(dong: CTWSuaTrang.soSanhDong(cuaToi: banCuaToi, banMoi: xungDot.banMoi))
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Edit conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Back to editor") { dong() } } }
            .overlay { if dangLuu { ProgressView().controlSize(.large) } }
        }
    }

    private func nut(_ icon: String, _ ten: String, _ phu: String, chinh: Bool = false, nguyHiem: Bool = false,
                     _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                    .foregroundColor(chinh ? AppColors.onPrimary : (nguyHiem ? AppColors.error : AppColors.primary))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(chinh ? AppColors.primary : (nguyHiem ? AppColors.error : AppColors.primary).opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ten).font(.system(size: 15, weight: .semibold))
                        .foregroundColor(nguyHiem ? AppColors.error : AppColors.textPrimary)
                    Text(phu).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .contentShape(Rectangle())
            .ctwThe(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chọn một thẻ (liên kết vào trang)

struct ChonTheCTW: View {
    let pid: Int
    var tieuDe = "Choose an issue"
    let chon: (CTWIssueCard) -> Void
    @Environment(\.dismiss) private var dong
    @State private var q = ""
    @State private var kq: [CTWIssueCard]?
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            List {
                if let loi { Text(loi).foregroundColor(AppColors.error) }
                if let kq {
                    if kq.isEmpty { Text("No issues match.").foregroundColor(AppColors.textSecondary) }
                    ForEach(kq) { t in
                        Button { chon(t); CTWRung.chon(); dong() } label: {
                            HStack(spacing: 10) {
                                Text("#\(t.number)").font(.system(size: 13, weight: .semibold).monospacedDigit())
                                    .foregroundColor(AppColors.textSecondary)
                                Text(t.title).foregroundColor(AppColors.textPrimary).lineLimit(2)
                            }
                            .frame(minHeight: 36)
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search issues")
            .task(id: q) {
                if !q.isEmpty { try? await Task.sleep(nanoseconds: 300_000_000) }
                guard !Task.isCancelled else { return }
                do {
                    var loc = CTWAPI.BoLoc(); loc.q = q; loc.includeDone = true
                    let r: CTWIssueList = try await APIClient.shared.request(CTWAPI.dsThe(pid: pid, loc: loc, limit: 40))
                    kq = r.items ?? []
                    loi = nil
                } catch { if !Task.isCancelled { loi = CTW.loi(error) } }
            }
            .navigationTitle(tieuDe)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } } }
        }
    }
}

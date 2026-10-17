import SwiftUI

// MARK: - Reviews — rà soát / inspection có checklist (IEEE-1028)
//
// Điểm iOS làm tốt: chấm checklist NGAY trong buổi họp — mỗi mục một chạm OK /
// NG / N/A, ghi chú + mức độ, mục NG tạo lỗi (bug) một chạm. Ghi từng mục
// ngay khi chạm (`PUT items` với một mục) để mất mạng giữa chừng không mất cả loạt.

@MainActor
final class RaSoatVM: ObservableObject {
    let pid: Int
    @Published var ds: [CTWReviewHang]?
    @Published var loi: String?
    @Published var tatMoDun = false
    init(pid: Int) { self.pid = pid }

    func tai() async {
        do { ds = try await APIClient.shared.request(CTWAPI.dsReview(pid: pid)); loi = nil }
        catch {
            if GovLoi.laTatMoDun(error) { tatMoDun = true; return }
            loi = CTW.loi(error)
        }
    }
}

struct RaSoatCTW: View {
    let pid: Int
    @StateObject private var vm: RaSoatVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var chiMo = true

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: RaSoatVM(pid: pid))
    }

    var body: some View {
        List {
            if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if vm.tatMoDun {
                GovTatMoDun(ten: "Reviews").listRowBackground(Color.clear)
            } else if let ds = vm.ds {
                let loc = ds.filter { !chiMo || $0.status != "CLOSED" }
                Section {
                    Picker("Show", selection: $chiMo) {
                        Text("Open (\(ds.filter { $0.status != "CLOSED" }.count))").tag(true)
                        Text("All (\(ds.count))").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                if loc.isEmpty {
                    CTWOTrong(bieuTuong: "text.magnifyingglass", tieuDe: ds.isEmpty ? "No reviews yet" : "No open reviews",
                              moTa: "Formal reviews and inspections of documents and code, with a checklist and defect log. Plan them on the web; run the checklist here.")
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(loc) { r in
                            NavigationLink(value: RouteReviewCTW(pid: pid, so: r.number)) { hang(r) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.ds == nil && vm.loi == nil && !vm.tatMoDun { CTWKhungTai(soHang: 4, coAvatar: false) } }
        .navigationTitle("Reviews")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.tai() }
        .task { if vm.ds == nil { await vm.tai() } }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "reviews" else { return }
            defer { app.dichCho = nil }
            let s = d.duongDan.phanCon.first ?? d.duongDan.tham["review"] ?? ""
            if let so = Int(s.split(separator: "-").last.map(String.init) ?? s) { nganXep.duong.append(RouteReviewCTW(pid: pid, so: so)) }
        }
        #if DEBUG
        .onAppear {
            if XemThuCTW.conCua("reviews") == "detail", nganXep.duong.count <= 1 { nganXep.duong.append(RouteReviewCTW(pid: pid, so: 2)) }
        }
        #endif
    }

    private func hang(_ r: CTWReviewHang) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(r.nhanKhoa).font(.system(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                CTWChipChu(chu: r.status)
                CTWNhanNho(chu: r.kind == "CODE" ? "Code" : "Document", bieuTuong: r.kind == "CODE" ? "chevron.left.forwardslash.chevron.right" : "doc.text")
            }
            Text(r.title).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
            HStack(spacing: 10) {
                Text(CTWMauTrangThai.nhan(r.method))
                if let p = r.progress { Label("\(p)%", systemImage: "checklist") }
                if let d = r.defects { Label("\(d) defect\(d == 1 ? "" : "s")", systemImage: "ladybug") }
                if let n = r.participants { Label("\(n)", systemImage: "person.2") }
                if let m = CTW.ngayNgan(r.meetingAt) { Label(m, systemImage: "calendar") }
            }
            .font(.system(size: 12)).foregroundColor(AppColors.textSecondary).labelStyle(.titleAndIcon)
            if let p = r.progress {
                CTWThanhPhanDoan(doan: [(p, AppColors.primary), (100 - p, AppColors.backgroundTertiary)], cao: 4)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chi tiết + chấm checklist

struct ChiTietRaSoatCTW: View {
    let pid: Int
    let so: Int
    @EnvironmentObject private var app: AppState
    @State private var r: CTWReview?
    @State private var loi: String?
    @State private var khoaSua = false
    @State private var dangGhi: Set<Int> = []
    @State private var suaMuc: CTWReviewMuc?
    @State private var thongBao: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if khoaSua { GovDaiKhoaSua(pid: pid) { khoaSua = false } }
                if let r {
                    dau(r)
                    soDo(r)
                    buocTiep(r)
                    nguoiThamGia(r)
                    checklist(r)
                    tieuChi(r)
                } else if loi == nil {
                    CTWKhungTai(soHang: 5, coAvatar: false).padding(-Spacing.md)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(r?.nhanKhoa ?? "Review")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if r == nil { await tai() } }
        .sheet(item: $suaMuc) { m in
            SuaMucReviewCTW(muc: m) { ghiChu, mucDo, dong in
                await ghi(m, ["note": govNull(ghiChu.isEmpty ? nil : ghiChu), "severity": govNull(mucDo),
                              "line": govNull(dong.isEmpty ? nil : dong)])
            }
        }
        .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func dau(_ r: CTWReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                CTWChipChu(chu: r.status)
                CTWNhanNho(chu: CTWMauTrangThai.nhan(r.method), bieuTuong: "person.3")
                CTWNhanNho(chu: r.kind == "CODE" ? "Code" : "Document", bieuTuong: r.kind == "CODE" ? "chevron.left.forwardslash.chevron.right" : "doc.text")
            }
            Text(r.title).font(.system(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            CTWKhoiTruong {
                if let p = r.page {
                    NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: p.number, ten: p.title ?? "Page")) {
                        CTWHangTruong(nhan: "Work product", bieuTuong: "doc.text") { Text(p.title ?? "Page \(p.number)").lineLimit(1) }
                    }.buttonStyle(.plain)
                    Divider()
                } else if let w = r.workProduct, !w.isEmpty {
                    CTWHangTruong("Work product", w, bieuTuong: "shippingbox"); Divider()
                }
                CTWHangTruong("Checklist", r.checklistName ?? r.checklistKey, bieuTuong: "checklist")
                if let m = r.meetingAt { Divider(); CTWHangTruong("Meeting", CTW.thoiDiem(m), bieuTuong: "calendar") }
                Divider()
                CTWHangTruong(nhan: "Decision", bieuTuong: "checkmark.seal") {
                    if r.suaDuoc && (r.status == "MEETING" || r.status == "FOLLOW_UP" || r.status == "REWORK") {
                        Menu {
                            ForEach(CTWReviewLuat.quyetDinh, id: \.self) { q in
                                Button(CTWReviewLuat.nhanQuyetDinh(q)) { Task { await sua(["decision": q]) } }
                            }
                            if r.decision != nil { Button("Clear decision", role: .destructive) { Task { await sua(["decision": NSNull()]) } } }
                        } label: {
                            HStack(spacing: 4) { Text(CTWReviewLuat.nhanQuyetDinh(r.decision)); Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)) }
                                .frame(minHeight: 32)
                        }
                    } else {
                        Text(CTWReviewLuat.nhanQuyetDinh(r.decision))
                    }
                }
            }
        }
    }

    private func soDo(_ r: CTWReview) -> some View {
        let m = r.metrics
        let tienDo = Int((m?.checklistProgress ?? 0).rounded())
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            CTWODem(so: "\(tienDo)%", nhan: "Checklist answered", bieuTuong: "checklist", mau: AppColors.primary)
            CTWODem(so: "\(m?.defects ?? 0)", nhan: "Defects (\(m?.majorDefects ?? 0) major)", bieuTuong: "ladybug.fill", mau: AppColors.error)
            CTWODem(so: so(m?.effortHours) + "h", nhan: "Total effort", bieuTuong: "clock", mau: Color(hex: 0x2563EB))
            if let d = m?.density {
                CTWODem(so: so(d), nhan: "Defects per \(m?.sizeUnit == "LOC" ? "KLOC" : "page")", bieuTuong: "chart.bar", mau: AppColors.warning)
            }
        }
    }

    private func so(_ d: Double?) -> String {
        guard let d else { return "0" }
        return d.rounded() == d ? String(Int(d)) : String(format: "%.1f", d)
    }

    @ViewBuilder
    private func buocTiep(_ r: CTWReview) -> some View {
        let ke = r.next ?? CTWReviewLuat.ke(tu: r.status)
        if r.suaDuoc && !ke.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if ke.contains("CLOSED"), let b = r.closeBlockers, !b.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Before closing").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        ForEach(b, id: \.self) { x in
                            Label(CTWReviewLuat.lyDoChan(x), systemImage: "exclamationmark.circle").font(.system(size: 13)).foregroundColor(AppColors.warning)
                        }
                    }
                }
                HStack(spacing: 10) {
                    ForEach(ke, id: \.self) { s in
                        let dong = s == "CLOSED"
                        Button { Task { await chuyen(s) } } label: {
                            Text(CTWReviewLuat.nhanBuoc(s)).font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(dong ? AppColors.success : AppColors.primary)
                        .disabled(dong && !(r.closeBlockers ?? []).isEmpty)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func nguoiThamGia(_ r: CTWReview) -> some View {
        let ds = r.participants ?? []
        if !ds.isEmpty {
            CTWSectionHeader("person.2", "Participants", count: "\(ds.count)")
            VStack(spacing: 0) {
                ForEach(ds) { p in
                    HStack(spacing: 10) {
                        CTWAvatar(user: p.user, size: 28)
                        Text(p.user?.ten ?? "Member").font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                        if p.user?.laAgent == true { CTWNhanAI() }
                        Spacer(minLength: 0)
                        if let m = p.prepMinutes, m > 0 { Text("\(m) min prep").font(.system(size: 12)).foregroundColor(AppColors.textTertiary) }
                        CTWNhanNho(chu: CTWMauTrangThai.nhan(p.role))
                    }
                    .frame(minHeight: 44)
                    if p.id != ds.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 14).ctwThe(14)
        }
    }

    @ViewBuilder
    private func checklist(_ r: CTWReview) -> some View {
        ForEach(r.theoPhan, id: \.phan) { nhom in
            let xong = nhom.muc.filter { $0.result != nil }.count
            CTWSectionHeader("checklist", nhom.phan, count: "\(xong)/\(nhom.muc.count)")
            VStack(spacing: 10) {
                ForEach(nhom.muc) { m in mucView(m, r) }
            }
        }
    }

    private func mucView(_ m: CTWReviewMuc, _ r: CTWReview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(m.question ?? "").font(.system(size: 15)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach([("OK", "checkmark", AppColors.success), ("NG", "xmark", AppColors.error), ("NA", "minus", AppColors.textSecondary)], id: \.0) { k in
                    let chon = m.result == k.0
                    Button {
                        CTWRung.chon()
                        Task { await ghi(m, ["result": govNull(chon ? nil : k.0)]) }
                    } label: {
                        Label(k.0 == "NA" ? "N/A" : k.0, systemImage: k.1)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(chon ? .white : k.2)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(chon ? k.2 : k.2.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!r.suaDuoc || dangGhi.contains(m.id))
                    .accessibilityAddTraits(chon ? .isSelected : [])
                }
                if r.suaDuoc {
                    Button { suaMuc = m } label: {
                        Image(systemName: "square.and.pencil").frame(width: 44, height: 40)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.textSecondary)
                    .accessibilityLabel("Note and severity")
                }
            }
            if m.note != nil || m.severity != nil || m.line != nil || m.defect != nil || (m.result == "NG" && r.canEdit == true) {
                HStack(spacing: 6) {
                    if let s = m.severity { CTWChipChu(chu: s) }
                    if let l = m.line?.chu, !l.isEmpty { CTWNhanNho(chu: "Line \(l)", bieuTuong: "text.line.first.and.arrowtriangle.forward") }
                    Spacer(minLength: 0)
                    if let d = m.defect {
                        NavigationLink(value: CTWRoute.the(pid: pid, so: d.number)) {
                            CTWNhanNho(chu: d.key ?? "#\(d.number)", bieuTuong: d.done == true ? "checkmark.circle" : "ladybug", mau: AppColors.error)
                        }
                        .buttonStyle(.plain)
                    } else if m.result == "NG" && r.canEdit == true {
                        Button { Task { await taoLoi(m) } } label: {
                            Label("Create defect", systemImage: "ladybug").font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                if let n = m.note, !n.isEmpty {
                    Text(n).font(.system(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .ctwThe(12)
        .opacity(dangGhi.contains(m.id) ? 0.6 : 1)
    }

    @ViewBuilder
    private func tieuChi(_ r: CTWReview) -> some View {
        ForEach([("Entry criteria", "arrow.right.to.line", r.entryCriteria), ("Exit criteria", "arrow.left.to.line", r.exitCriteria),
                 ("Notes", "note.text", r.notes)], id: \.0) { x in
            if let t = x.2?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                CTWSectionHeader(x.1, x.0)
                CTWMarkdownView(markdown: t, coChu: 14).padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
            }
        }
    }

    // MARK: Mạng

    private func tai() async {
        do { r = try await APIClient.shared.request(CTWAPI.review(pid: pid, so: so)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    private func baoLoi(_ e: Error) {
        CTWRung.loi()
        if GovLoi.laKhoaSua(e) { khoaSua = true } else { loi = CTW.loi(e) }
    }

    @discardableResult
    private func ghi(_ m: CTWReviewMuc, _ truong: [String: Any]) async -> Bool {
        dangGhi.insert(m.id)
        defer { dangGhi.remove(m.id) }
        var x = truong
        x["id"] = m.id
        do {
            r = try await APIClient.shared.request(CTWAPI.ghiMucReview(pid: pid, so: so, muc: [x]))
            return true
        } catch { baoLoi(error); return false }
    }

    private func sua(_ t: [String: Any]) async {
        do { r = try await APIClient.shared.request(CTWAPI.suaReview(pid: pid, so: so, than: t)); CTWRung.thanhCong() }
        catch { baoLoi(error) }
    }

    private func chuyen(_ s: String) async {
        do { r = try await APIClient.shared.request(CTWAPI.chuyenReview(pid: pid, so: so, den: s)); CTWRung.thanhCong() }
        catch { baoLoi(error); await tai() }
    }

    private func taoLoi(_ m: CTWReviewMuc) async {
        dangGhi.insert(m.id)
        defer { dangGhi.remove(m.id) }
        do {
            let k: CTWReviewTaoLoi = try await APIClient.shared.request(CTWAPI.taoLoiTuMuc(pid: pid, so: so, mucId: m.id, mucDo: m.severity))
            CTWRung.thanhCong()
            thongBao = "Created \(k.key ?? "defect")\(k.title.map { " — \($0)" } ?? "")."
            await tai()
        } catch { baoLoi(error) }
    }
}

/// Tấm sửa ghi chú / mức độ / dòng của một mục checklist.
struct SuaMucReviewCTW: View {
    let muc: CTWReviewMuc
    let luu: (_ ghiChu: String, _ mucDo: String?, _ dong: String) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var ghiChu = ""
    @State private var mucDo = ""
    @State private var dongSo = ""
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(muc.question ?? "").font(.system(size: 15)).foregroundColor(AppColors.textPrimary) }
                Section("Finding") {
                    TextField("Note", text: $ghiChu, axis: .vertical).lineLimit(2...8)
                    Picker("Severity", selection: $mucDo) {
                        Text("Not set").tag("")
                        ForEach(CTWReviewLuat.mucDo, id: \.self) { s in Text(CTWMauTrangThai.nhan(s)).tag(s) }
                    }
                    TextField("Line or location (optional)", text: $dongSo)
                }
            }
            .navigationTitle("Checklist item")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button("Save") {
                            dangLuu = true
                            Task {
                                defer { dangLuu = false }
                                if await luu(ghiChu.trimmingCharacters(in: .whitespacesAndNewlines), mucDo.isEmpty ? nil : mucDo,
                                             dongSo.trimmingCharacters(in: .whitespaces)) { CTWRung.thanhCong(); dong() }
                            }
                        }
                        .bold()
                    }
                }
            }
            .onAppear {
                ghiChu = muc.note ?? ""
                mucDo = muc.severity ?? ""
                dongSo = muc.line?.chu ?? ""
            }
        }
        .presentationDetents([.medium, .large])
    }
}

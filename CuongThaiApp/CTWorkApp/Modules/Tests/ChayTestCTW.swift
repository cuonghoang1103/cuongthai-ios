import SwiftUI
import PhotosUI

// MARK: - CHẠY KIỂM THỬ trên điện thoại
//
// Tester cầm máy thật bấm Pass/Fail/Blocked/Skip từng bước, ghi kết quả thực
// tế, chụp ảnh bằng chứng ngay tại chỗ, và tạo lỗi từ bước hỏng — việc mà
// trên laptop phải chuyển qua lại giữa thiết bị thử và trình duyệt.
//
// Trạng thái LƯỢT do MÁY CHỦ tính lại mỗi lần đổi trạng thái bước
// (`deriveRunStatus`). App đổi lạc quan theo cùng luật (`CTWLuatTest`) cho
// nhanh tay, rồi thay bằng đúng thân máy chủ trả về.

@MainActor
final class ChayTestVM: ObservableObject {
    let pid: Int
    let id: Int
    @Published var r: CTWRunDetail?
    @Published var loi: String?
    @Published var dangGui: Set<Int> = []
    @Published var dangTaiLen = false
    /// Người dùng đang bật "khoá chỉnh sửa" cho dự án (423) — chỉ xem.
    @Published var biKhoa = false

    init(pid: Int, id: Int) { self.pid = pid; self.id = id }

    var soTest: Int? { r?.testCase?.issue?.number }

    func tai() async {
        do { r = try await APIClient.shared.request(CTWAPI.luotChay(pid: pid, id: id)); loi = nil }
        catch { baoLoi(error) }
    }

    private func baoLoi(_ e: Error) {
        if case APIError.coMa(let ma, _) = e, ma.contains("EDIT_LOCKED") {
            biKhoa = true
            loi = String(localized: "Editing is locked for this project on your account. Unlock it on the web (or in project settings) to record results.")
            return
        }
        loi = CTW.loi(e)
    }

    /// Bấm lại đúng trạng thái đang chọn ⇒ về TODO (bỏ chọn).
    func danhDau(_ s: CTWRunStep, _ trangThai: String) async {
        guard var moi = r, let i = moi.steps?.firstIndex(where: { $0.id == s.id }) else { return }
        let cu = moi
        let dich = s.status == trangThai ? "TODO" : trangThai
        moi.steps?[i].status = dich
        moi.status = CTWLuatTest.trangThaiLuot((moi.steps ?? []).map { $0.status ?? "TODO" })
        r = moi
        dangGui.insert(s.id)
        defer { dangGui.remove(s.id) }
        do {
            r = try await APIClient.shared.request(CTWAPI.suaBuoc(pid: pid, run: id, buoc: s.id, than: ["status": dich]))
            dich == "FAIL" ? CTWRung.loi() : CTWRung.thanhCong()
        } catch {
            r = cu
            CTWRung.loi()
            baoLoi(error)
        }
    }

    func luuThucTe(_ buocId: Int, _ chu: String) async {
        let t = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let s = r?.steps?.first(where: { $0.id == buocId }), (s.actual ?? "") != t else { return }
        do {
            r = try await APIClient.shared.request(CTWAPI.suaBuoc(
                pid: pid, run: id, buoc: buocId, than: ["actual": t.isEmpty ? NSNull() : String(t.prefix(10_000))]))
        } catch { baoLoi(error) }
    }

    func luuGhiChu(_ chu: String) async -> Bool {
        let t = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            r = try await APIClient.shared.request(CTWAPI.suaLuot(pid: pid, run: id, than: ["comment": t.isEmpty ? NSNull() : t]))
            CTWRung.thanhCong()
            return true
        } catch { baoLoi(error); return false }
    }

    func datLai() async {
        do {
            r = try await APIClient.shared.request(CTWAPI.suaLuot(pid: pid, run: id, than: ["reset": true]))
            CTWRung.thanhCong()
        } catch { baoLoi(error) }
    }

    func taiLen(du: Data, ten: String, kieu: String? = nil) async {
        guard let so = soTest else { return }
        dangTaiLen = true
        defer { dangTaiLen = false }
        do {
            let a = try await CTWTaiBangChung.taiLen(pid: pid, soTest: so, run: id, du: du, ten: ten, kieu: kieu)
            r?.evidence = (r?.evidence ?? []) + [a]
            CTWRung.thanhCong()
        } catch { CTWRung.loi(); baoLoi(error) }
    }

    func moBangChung(_ a: CTWAttachment) async -> URL? {
        do {
            let u: CTWUrl = try await APIClient.shared.request(CTWAPI.urlDinhKem(pid: pid, aid: a.id, xemTrongApp: true))
            guard let url = URL(string: u.url) else { return nil }
            return try await CTWXemTep.taiVe(url: url, ten: a.fileName ?? "evidence", khoa: "run-\(id)-\(a.id)")
        } catch { baoLoi(error); return nil }
    }

    func taoLoi(buoc: Int?, tieuDe: String, uuTien: Int) async -> Int? {
        do {
            let m: CTWSoMoi = try await APIClient.shared.request(
                CTWAPI.taoLoiTuLuot(pid: pid, run: id, buoc: buoc, tieuDe: tieuDe, uuTien: uuTien))
            CTWRung.thanhCong()
            await tai()
            return m.number
        } catch { CTWRung.loi(); baoLoi(error); return nil }
    }
}

/// Tải bằng chứng lên LƯỢT chạy: như đính kèm thẻ (presign → PUT → complete)
/// nhưng thẻ là CA KIỂM THỬ và bước complete kèm `runId`.
/// Không sửa `CTWTaiLen` dùng chung vì đường complete khác thân.
enum CTWTaiBangChung {
    static func taiLen(pid: Int, soTest: Int, run: Int, du: Data, ten: String, kieu: String?) async throws -> CTWAttachment {
        guard du.count <= CTWTaiLen.tranByte else { throw CTWTaiLen.Loi.quaLon }
        let ct = kieu ?? CTWTaiLen.kieu(cho: ten)
        let ps: CTWPresign = try await APIClient.shared.request(
            CTWAPI.xinDuongTaiLen(pid: pid, so: soTest, ten: ten, kieu: ct, coByte: du.count))
        guard let url = URL(string: ps.uploadUrl) else { throw CTWTaiLen.Loi.hong(0) }
        var rq = URLRequest(url: url)
        rq.httpMethod = "PUT"
        let dau = ps.headers ?? ["Content-Type": ct]
        for (k, v) in dau { rq.setValue(v, forHTTPHeaderField: k) }
        if dau["Content-Type"] == nil { rq.setValue(ct, forHTTPHeaderField: "Content-Type") }
        let (_, res) = try await URLSession.shared.upload(for: rq, from: du)
        let ma = (res as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(ma) else { throw CTWTaiLen.Loi.hong(ma) }
        return try await APIClient.shared.request(CTWAPI.xongTaiBangChung(pid: pid, soTest: soTest, key: ps.key, ten: ten, run: run))
    }
}

struct ChayTestCTW: View {
    let pid: Int
    let id: Int
    @StateObject private var vm: ChayTestVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @Environment(\.horizontalSizeClass) private var beRong

    /// MỘT tấm phủ cho cả màn (bẫy C5).
    @State private var tamPhu: TamPhu?
    @State private var nhap: [Int: String] = [:]
    @FocusState private var dangGo: Int?
    @State private var ghiChu = ""
    @State private var hoiDatLai = false
    @State private var loiMoi: Int?
    /// Số lỗi vừa tạo — chờ tấm phủ đóng hẳn mới bật hộp báo (alert trên sheet đang đóng bị nuốt).
    @State private var loiChoBao: Int?
    @State private var xemNhanh: URL?
    @State private var moChonAnh = false
    @State private var chonAnh: [PhotosPickerItem] = []
    @State private var moChonTep = false

    private enum TamPhu: Identifiable {
        case mayAnh
        case taoLoi(CTWRunStep?)
        var id: String {
            switch self {
            case .mayAnh: return "mayanh"
            case .taoLoi(let s): return "loi-\(s?.id ?? 0)"
            }
        }
    }

    init(pid: Int, id: Int) {
        self.pid = pid
        self.id = id
        _vm = StateObject(wrappedValue: ChayTestVM(pid: pid, id: id))
    }

    private var cfg: CTWProjectConfig? { app.cauHinhDuAn }
    private var coTheChay: Bool { cfg?.coTheChuyen == true && !vm.biKhoa }
    private var coTheTaoLoi: Bool { cfg?.coTheTao == true && !vm.biKhoa }
    private var coTheDinhKem: Bool { cfg?.permissions?.attach == true && !vm.biKhoa }
    private var maDuAn: String { cfg?.key ?? app.luaChon?.maDuAn ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil } }
                if let r = vm.r {
                    if beRong == .regular {
                        HStack(alignment: .top, spacing: Spacing.lg) {
                            VStack(alignment: .leading, spacing: Spacing.md) { dau(r); cacBuoc(r) }
                                .frame(maxWidth: 680)
                            VStack(alignment: .leading, spacing: Spacing.md) { benPhai(r) }
                                .frame(width: 340)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        dau(r)
                        cacBuoc(r)
                        benPhai(r)
                    }
                } else if vm.loi == nil {
                    CTWKhungTai(soHang: 5, coAvatar: false)
                }
            }
            .padding(Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.soTest.map { "\(maDuAn)-\($0)" } ?? String(localized: "Test run"))
        .ctwTieuDeNho()
        .toolbar {
            if vm.r != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if coTheTaoLoi {
                            Button { tamPhu = .taoLoi(nil) } label: { Label("Log a bug", systemImage: "ladybug") }
                        }
                        if coTheChay {
                            Button(role: .destructive) { hoiDatLai = true } label: { Label("Reset run", systemImage: "arrow.counterclockwise") }
                        }
                        if let so = vm.soTest {
                            Button { nganXep.duong.append(CTWRoute.the(pid: pid, so: so)) } label: {
                                Label("Open test issue", systemImage: "doc.text")
                            }
                        }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel("More")
                }
                ToolbarItem(placement: .keyboard) {
                    HStack { Spacer(); Button("Done") { dangGo = nil } }
                }
            }
        }
        .refreshable { await vm.tai() }
        .task { if vm.r == nil { await vm.tai(); ghiChu = vm.r?.comment ?? "" } }
        // Rời ô "kết quả thực tế" ⇒ lưu ô vừa rời (không bắt bấm Lưu từng bước).
        .onChange(of: dangGo) { cu, _ in
            if let cu, let chu = nhap[cu] { Task { await vm.luuThucTe(cu, chu) } }
        }
        .confirmationDialog("Reset this run?", isPresented: $hoiDatLai, titleVisibility: .visible) {
            Button("Reset run", role: .destructive) {
                Task { await vm.datLai(); nhap = [:] }
            }
        } message: {
            Text("Every step goes back to To do and actual results are cleared. Linked bugs and evidence stay.")
        }
        .alert("Bug \(maDuAn)-\(loiMoi ?? 0) created",
               isPresented: Binding(get: { loiMoi != nil }, set: { if !$0 { loiMoi = nil } })) {
            Button("Open bug") {
                if let so = loiMoi { nganXep.duong.append(CTWRoute.the(pid: pid, so: so)) }
                loiMoi = nil
            }
            Button("OK", role: .cancel) { loiMoi = nil }
        } message: {
            Text("It's linked to this run, with steps to reproduce, expected and actual results filled in.")
        }
        .sheet(item: $tamPhu, onDismiss: {
            if let so = loiChoBao { loiChoBao = nil; loiMoi = so }
        }) { tp in
            switch tp {
            case .mayAnh:
                MayAnh { du in
                    Task { await vm.taiLen(du: du, ten: "Evidence \(CTW.tenTepTheoGio()).jpg", kieu: "image/jpeg") }
                }
                .ignoresSafeArea()
            case .taoLoi(let s):
                TaoLoiTestView(tieuDeGoiY: tieuDeLoi(s)) { tieuDe, uuTien in
                    if let so = await vm.taoLoi(buoc: s?.id, tieuDe: tieuDe, uuTien: uuTien) {
                        loiChoBao = so
                        return nil
                    }
                    let m = vm.loi ?? String(localized: "Couldn't create the bug. Please try again.")
                    vm.loi = nil
                    return m
                }
            }
        }
        .ctwXemTep($xemNhanh)
    }

    private func tieuDeLoi(_ s: CTWRunStep?) -> String {
        let ten = vm.r?.testCase?.issue?.title ?? String(localized: "Test")
        let buoc = s ?? vm.r?.steps?.first { $0.status == "FAIL" } ?? vm.r?.steps?.first { $0.status == "BLOCKED" }
        guard let b = buoc else { return String(localized: "\(ten) fails") }
        return String(localized: "\(ten) — step \((b.position ?? 0) + 1) fails")
    }

    // MARK: Đầu màn

    private func dau(_ r: CTWRunDetail) -> some View {
        let buoc = r.steps ?? []
        let xong = buoc.filter { ($0.status ?? "TODO") != "TODO" }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let c = r.cycle?.name { CTWNhanNho(chu: c, bieuTuong: "arrow.triangle.2.circlepath") }
                if let e = r.cycle?.environment, !e.isEmpty { CTWNhanNho(chu: e, bieuTuong: "desktopcomputer") }
                if let b = r.cycle?.build, !b.isEmpty { CTWNhanNho(chu: b, bieuTuong: "shippingbox") }
            }
            Text(r.testCase?.issue?.title ?? String(localized: "Test")).font(.ctw(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                Image(systemName: CTWLuatTest.bieuTuong(r.status))
                    .font(.ctw(size: 26)).foregroundColor(CTWLuatTest.mau(r.status))
                VStack(alignment: .leading, spacing: 2) {
                    Text(CTWLuatTest.nhan(r.status)).font(.ctw(size: 17, weight: .bold))
                        .foregroundColor(CTWLuatTest.mau(r.status))
                    Text("\(xong) of \(buoc.count) steps recorded").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
                if let u = r.executedBy {
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 5) {
                            CTWAvatar(user: u, size: 20)
                            Text(u.ten).font(.ctw(size: 12, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        }
                        if u.laAgent { CTWNhanAI() }
                        if let t = r.executedAt { Text(CTW.thoiDiem(t)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
                    }
                }
            }
            CTWThanhPhanDoan(doan: ["PASS", "FAIL", "BLOCKED", "SKIP"].map { k -> (gt: Int, mau: Color) in
                (buoc.filter { $0.status == k }.count, CTWLuatTest.mau(k))
            } + [(gt: buoc.filter { ($0.status ?? "TODO") == "TODO" }.count, mau: Color.clear)], cao: 8)
            .animation(.easeInOut(duration: 0.2), value: r.status)
            if let v = r.testCaseVersion, let hienTai = r.testCase?.version, v < hienTai {
                Label("This run uses version \(v) of the test; the test is now at version \(hienTai). Reset the run to pick up the new steps.",
                      systemImage: "exclamationmark.arrow.circlepath")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !coTheChay && !vm.biKhoa {
                Label("You can view this run but not record results.", systemImage: "eye")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(16)
        .ctwThe(16)
    }

    // MARK: Các bước

    @ViewBuilder private func cacBuoc(_ r: CTWRunDetail) -> some View {
        if let p = r.testCase?.preconditions, !p.isEmpty {
            CTWSectionHeader("flag", String(localized: "Preconditions"))
            Text(p).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12).ctwThe(12)
        }
        if let g = r.gherkin, !g.isEmpty {
            CTWSectionHeader("text.alignleft", String(localized: "Scenario"))
            CTWKhoiView(khoi: [.ma(g)])
        }
        let buoc = (r.steps ?? []).sorted { ($0.position ?? 0) < ($1.position ?? 0) }
        CTWSectionHeader("list.number", String(localized: "Steps"), count: "\(buoc.count)")
        if buoc.isEmpty {
            Text("This test has no steps. Set the overall result from the web, or add steps to the test.")
                .font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
        }
        ForEach(Array(buoc.enumerated()), id: \.element.id) { i, s in
            CTWBuocTestView(so: i + 1, action: s.action, data: s.data, expected: s.expected, trangThai: s.status) {
                duoiBuoc(s)
            }
        }
    }

    @ViewBuilder private func duoiBuoc(_ s: CTWRunStep) -> some View {
        if coTheChay {
            HStack(spacing: 6) {
                ForEach(CTWLuatTest.trangThaiBuoc, id: \.self) { k in nutTrangThai(s, k) }
            }
            .padding(.top, 2)
            .overlay(alignment: .topTrailing) {
                if vm.dangGui.contains(s.id) { ProgressView().scaleEffect(0.7).offset(x: 6, y: -18) }
            }
            TextField("Actual result (optional)", text: Binding(
                get: { nhap[s.id] ?? s.actual ?? "" },
                set: { nhap[s.id] = $0 }), axis: .vertical)
                .lineLimit(1...5)
                .font(.ctw(size: 14))
                .focused($dangGo, equals: s.id)
                .submitLabel(.done)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundTertiary))
        } else {
            HStack(spacing: 6) {
                Image(systemName: CTWLuatTest.bieuTuong(s.status)).foregroundColor(CTWLuatTest.mau(s.status))
                Text(CTWLuatTest.nhan(s.status)).font(.ctw(size: 13, weight: .semibold)).foregroundColor(CTWLuatTest.mau(s.status))
            }
            if let a = s.actual, !a.isEmpty {
                Text("Actual: \(a)").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if (s.status == "FAIL" || s.status == "BLOCKED") && coTheTaoLoi {
            Button { tamPhu = .taoLoi(s) } label: {
                Label("Log a bug for this step", systemImage: "ladybug")
                    .font(.ctw(size: 13, weight: .semibold))
                    .frame(minHeight: 36)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.error)
        }
    }

    private func nutTrangThai(_ s: CTWRunStep, _ k: String) -> some View {
        let chon = s.status == k
        let mau = CTWLuatTest.mau(k)
        let ngan = ["PASS": String(localized: "Pass"), "FAIL": String(localized: "Fail"), "BLOCKED": String(localized: "Blocked"), "SKIP": String(localized: "Skip")][k] ?? k
        return Button {
            Task { await vm.danhDau(s, k) }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: CTWLuatTest.bieuTuong(k)).font(.ctw(size: 15, weight: .semibold))
                Text(ngan).font(.ctw(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundColor(chon ? .white : mau)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(chon ? mau : mau.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(mau.opacity(chon ? 0 : 0.25), lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(vm.dangGui.contains(s.id))
        .accessibilityLabel("Mark step \(ngan)")
        .accessibilityAddTraits(chon ? .isSelected : [])
    }

    // MARK: Bằng chứng · lỗi · ghi chú

    @ViewBuilder private func benPhai(_ r: CTWRunDetail) -> some View {
        bangChung(r)
        loiLienQuan(r)
        ghiChuLuot(r)
    }

    private func bangChung(_ r: CTWRunDetail) -> some View {
        let ds = r.evidence ?? []
        let them: AnyView? = coTheDinhKem ? AnyView(
            Menu {
                if MayAnh.coMayAnh {
                    Button { tamPhu = .mayAnh } label: { Label("Take Photo", systemImage: "camera") }
                }
                Button { moChonAnh = true } label: { Label("Photo Library", systemImage: "photo.on.rectangle") }
                Button { moChonTep = true } label: { Label("Choose File", systemImage: "folder") }
            } label: {
                if vm.dangTaiLen { ProgressView().frame(width: 44, height: 32) }
                else { Image(systemName: "plus.circle.fill").font(.ctw(size: 20)).frame(width: 44, height: 32) }
            }
            .disabled(vm.dangTaiLen)
            .accessibilityLabel("Add evidence")
        ) : nil
        return VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("camera.viewfinder", String(localized: "Evidence"), count: ds.isEmpty ? nil : "\(ds.count)", trailing: them)
                // Bộ chọn tệp gắn ở đây, bộ chọn ảnh gắn ở khối ngoài, sheet ở gốc (C5).
                .fileImporter(isPresented: $moChonTep, allowedContentTypes: [.item], allowsMultipleSelection: false) { kq in
                    guard case .success(let ds) = kq, let u = ds.first else { return }
                    Task {
                        let mo = u.startAccessingSecurityScopedResource()
                        defer { if mo { u.stopAccessingSecurityScopedResource() } }
                        guard let du = try? Data(contentsOf: u) else { vm.loi = String(localized: "Couldn't read that file."); return }
                        await vm.taiLen(du: du, ten: u.lastPathComponent)
                    }
                }
            if ds.isEmpty {
                Text(coTheDinhKem ? "Tap + to take a photo or attach a screenshot of what you saw." : "No evidence yet.")
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(ds) { a in
                        Button {
                            Task { if let u = await vm.moBangChung(a) { xemNhanh = u } }
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: a.bieuTuong)
                                    .font(.ctw(size: 16, weight: .medium)).foregroundColor(AppColors.primary)
                                    .frame(width: 36, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.fileName ?? String(localized: "File")).font(.ctw(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.textPrimary).lineLimit(1)
                                    Text([a.coChu, a.uploader?.ten, CTW.thoiDiem(a.createdAt)]
                                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "eye").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if a.id != ds.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .ctwThe(12)
            }
        }
        .photosPicker(isPresented: $moChonAnh, selection: $chonAnh, maxSelectionCount: 5, matching: .images)
        .onChange(of: chonAnh) { _, ds in
            guard !ds.isEmpty else { return }
            chonAnh = []
            Task {
                for (i, item) in ds.enumerated() {
                    guard let du = try? await item.loadTransferable(type: Data.self) else { continue }
                    let loai = item.supportedContentTypes.first
                    let duoi = loai?.preferredFilenameExtension ?? "jpg"
                    let kieu = loai?.preferredMIMEType ?? "image/jpeg"
                    await vm.taiLen(du: du, ten: "Evidence \(CTW.tenTepTheoGio())\(ds.count > 1 ? "-\(i + 1)" : "").\(duoi)", kieu: kieu)
                }
            }
        }
    }

    @ViewBuilder private func loiLienQuan(_ r: CTWRunDetail) -> some View {
        let ds = (r.defects ?? []).filter { $0.deletedAt == nil }
        if !ds.isEmpty || coTheTaoLoi {
            VStack(alignment: .leading, spacing: 8) {
                CTWSectionHeader("ladybug", String(localized: "Bugs"), count: ds.isEmpty ? nil : "\(ds.count)",
                                 trailing: coTheTaoLoi ? AnyView(
                                    Button { tamPhu = .taoLoi(nil) } label: {
                                        Image(systemName: "plus.circle.fill").font(.ctw(size: 20)).frame(width: 44, height: 32)
                                    }.accessibilityLabel("Log a bug")) : nil)
                if ds.isEmpty {
                    Text("No bugs linked to this run.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(ds) { d in
                            NavigationLink(value: CTWRoute.the(pid: pid, so: d.number)) {
                                HStack(spacing: 9) {
                                    Image(systemName: "ladybug.fill").foregroundColor(AppColors.error).frame(width: 20)
                                    Text("\(maDuAn)-\(d.number)").font(.ctw(size: 12, weight: .medium).monospaced())
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(d.title ?? String(localized: "Bug")).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                    Spacer(minLength: 0)
                                    if let st = d.statusId.flatMap({ cfg?.trangThai($0) }) { CTWStatusChip(status: st) }
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if d.id != ds.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 14)
                    .ctwThe(12)
                }
            }
        }
    }

    @ViewBuilder private func ghiChuLuot(_ r: CTWRunDetail) -> some View {
        if coTheChay || !(r.comment ?? "").isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CTWSectionHeader("text.bubble", String(localized: "Run notes"))
                if coTheChay {
                    TextField("Environment details, data used, anything worth knowing…", text: $ghiChu, axis: .vertical)
                        .lineLimit(2...8)
                        .font(.ctw(size: 14))
                        .padding(12)
                        .ctwThe(12)
                    if ghiChu.trimmingCharacters(in: .whitespacesAndNewlines) != (r.comment ?? "") {
                        HStack {
                            Spacer()
                            Button("Revert") { ghiChu = r.comment ?? "" }.buttonStyle(.bordered)
                            Button("Save notes") { Task { _ = await vm.luuGhiChu(ghiChu) } }.buttonStyle(.borderedProminent)
                        }
                    }
                } else if let c = r.comment {
                    Text(c).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12).ctwThe(12)
                }
            }
        }
    }
}

// MARK: - Tạo lỗi từ lượt chạy

struct TaoLoiTestView: View {
    let tieuDeGoiY: String
    /// Trả `nil` = tạo xong; chuỗi = câu lỗi hiện NGAY trong tấm này (màn dưới bị che).
    let tao: (String, Int) async -> String?
    @Environment(\.dismiss) private var dong
    @State private var loi: String?
    @State private var tieuDe = ""
    @State private var uuTien = 2
    @State private var dangTao = false

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { CTWErrorBanner(text: loi) }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
                Section("Title") {
                    TextField("What went wrong?", text: $tieuDe, axis: .vertical).lineLimit(1...4)
                }
                Section("Priority") {
                    Picker("Priority", selection: $uuTien) {
                        ForEach(CTW.doUuTien, id: \.so) { p in
                            Label(p.ten, systemImage: p.bieuTuong).tag(p.so)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Label("The description is filled in for you: cycle, environment and build, preconditions, steps to reproduce, expected and actual result.",
                          systemImage: "wand.and.stars")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            .navigationTitle("Log a bug")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangTao { ProgressView() } else {
                        Button("Create") {
                            dangTao = true
                            Task {
                                loi = await tao(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines), uuTien)
                                dangTao = false
                                if loi == nil { dong() }
                            }
                        }
                        .disabled(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onAppear { if tieuDe.isEmpty { tieuDe = tieuDeGoiY } }
        }
        .presentationDetents([.medium, .large])
    }
}

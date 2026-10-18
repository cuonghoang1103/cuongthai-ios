import SwiftUI

// MARK: - Intake — đề xuất từ kênh ngoài (email/Discord/Zalo/Slack) chờ duyệt thành thẻ
//
// Nội dung tin là của NGƯỜI NGOÀI ⇒ nội dung người dùng: nhấn giữ để báo cáo/chặn (1.2).

struct RouteDeXuatCTW: Hashable { var pid: Int; var dx: CTWDeXuat }

struct IntakeCTW: View {
    let pid: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var trangThai = "PENDING"
    @State private var du: CTWDsDeXuat?
    @State private var loi: String?
    @State private var biChan: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let b = biChan {
                    CTWOTrong(bieuTuong: "lock.shield", tieuDe: "Intake unavailable", moTa: b)
                } else {
                    CTWThanhLoc(chip: CTWIntake.trangThai.map { t in
                        let n = du?.counts?[t.ma]
                        return CTWChipLoc(id: t.ma, nhan: n.map { "\(t.nhan) \($0)" } ?? t.nhan, bat: trangThai == t.ma)
                    }) { c in trangThai = c.id }
                        .padding(.horizontal, -Spacing.md)
                    if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                    if let ds = du?.proposals {
                        if ds.isEmpty {
                            CTWOTrong(bieuTuong: "tray", tieuDe: trangThai == "PENDING" ? "Inbox zero" : "Nothing here",
                                      moTa: trangThai == "PENDING"
                                        ? "Messages sent to the project's intake channels show up here for triage."
                                        : "No \(trangThai.lowercased()) requests.")
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(ds) { d in
                                    NavigationLink(value: RouteDeXuatCTW(pid: pid, dx: d)) { HangDeXuat(d: d) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    } else if loi == nil {
                        CTWKhungTai(soHang: 4).padding(.horizontal, -Spacing.md)
                    }
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Intake")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task(id: trangThai) { await tai() }
        .onAppear { if du != nil { Task { await tai() } } }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "intake" else { return }
            defer { app.dichCho = nil }
            if let s = d.duongDan.tham["status"]?.uppercased(), CTWIntake.trangThai.contains(where: { $0.ma == s }) { trangThai = s }
        }
    }

    private func tai() async {
        do {
            du = try await APIClient.shared.request(CTWAPI.deXuat(pid: pid, trangThai: trangThai))
            loi = nil
        } catch {
            if Task.isCancelled { return }
            if DichVuLoi.biChan(error) { biChan = DichVuLoi.cau(error) } else { loi = DichVuLoi.cau(error) }
        }
    }
}

private struct HangDeXuat: View {
    let d: CTWDeXuat
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: CTWIntake.bieuTuongNguon(d.source))
                .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(d.title).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                if let b = d.body, !b.isEmpty {
                    Text(b.replacingOccurrences(of: "\n", with: " ")).font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text("\(CTWIntake.tenNguon(d.source)) · \(d.nguoiGui)").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                    if d.simulated == true { CTWNhanNho(chu: "Test") }
                    Spacer(minLength: 0)
                    if let k = d.issue?.key { CTWNhanNho(chu: k, bieuTuong: "checkmark", mau: AppColors.success) }
                    Text(CTW.thoiDiem(d.createdAt)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(14)
        .ctwThe(14)
        .contentShape(Rectangle())
    }
}

// MARK: - Chi tiết một đề xuất

struct DeXuatCTW: View {
    let pid: Int
    @State var dx: CTWDeXuat
    @EnvironmentObject private var app: AppState
    @State private var tamPhu: TamPhu?
    @State private var hoiTuChoi = false
    @State private var ghiChu = ""
    @State private var loi: String?
    @State private var dangLam = false

    private enum TamPhu: String, Identifiable { case nhan; var id: String { rawValue } }

    init(pid: Int, dx: CTWDeXuat) { self.pid = pid; _dx = State(initialValue: dx) }

    private var duocQuyet: Bool { dx.status == "PENDING" && (app.cauHinhDuAn?.coTheTao ?? true) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                HStack(spacing: 6) {
                    CTWNhanNho(chu: CTWIntake.tenNguon(dx.source), bieuTuong: CTWIntake.bieuTuongNguon(dx.source), mau: AppColors.primary)
                    if dx.simulated == true { CTWNhanNho(chu: "Test message") }
                    Spacer(minLength: 0)
                    CTWChipChu(chu: dx.status)
                }
                Text(dx.title).font(.system(size: 21, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                CTWKhoiTruong {
                    CTWHangTruong("From", dx.nguoiGui, bieuTuong: "person")
                    if let h = dx.senderHandle, h != dx.nguoiGui { Divider(); CTWHangTruong("Address", h, bieuTuong: "at") }
                    Divider()
                    CTWHangTruong("Received", DichVuLoi.luc(dx.createdAt), bieuTuong: "clock")
                    if let by = dx.decidedBy {
                        Divider()
                        CTWHangTruong("Decided by", "\(by)\(DichVuLoi.luc(dx.decidedAt).map { " · \($0)" } ?? "")", bieuTuong: "checkmark.circle")
                    }
                    if let n = dx.decisionNote, !n.isEmpty { Divider(); CTWHangTruong("Note", n, bieuTuong: "text.bubble") }
                }
                if let b = dx.body, !b.isEmpty {
                    CTWSectionHeader("text.alignleft", "Message")
                    Text(b).font(.system(size: 15)).foregroundColor(AppColors.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).ctwThe(12)
                        .ctwMenuBaoCaoChan(khoa: "intake-\(dx.id)", noiDung: b, nguCanh: "Intake · \(CTWIntake.tenNguon(dx.source)) · \(dx.nguoiGui)",
                                           tacGia: nil, laCuaToi: false, dich: CTWDichBaoCao("intake_message", dx.id))
                    Text("Touch and hold the message to report it.").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                if let so = dx.issue?.number {
                    NavigationLink(value: CTWRoute.the(pid: pid, so: so)) {
                        Label("Open \(dx.issue?.key ?? "issue")", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                if duocQuyet {
                    HStack(spacing: 10) {
                        Button(role: .destructive) { hoiTuChoi = true } label: {
                            Label("Reject", systemImage: "xmark").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        Button { tamPhu = .nhan } label: {
                            Label("Accept as issue", systemImage: "checkmark").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .disabled(dangLam)
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reject this request?", isPresented: $hoiTuChoi) {
            TextField("Reason (optional)", text: $ghiChu)
            Button("Reject", role: .destructive) { Task { await quyet(nhan: false, ghiChu: ghiChu) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("It won't become an issue. The sender isn't notified.") }
        .sheet(item: $tamPhu) { _ in
            NhanDeXuatSheet(dx: dx, cfg: app.cauHinhDuAn) { tieuDe, loai, nguoi, uuTien, note in
                await quyet(nhan: true, tieuDe: tieuDe, loai: loai, nguoi: nguoi, uuTien: uuTien, ghiChu: note)
            }
        }
    }

    @discardableResult
    private func quyet(nhan: Bool, tieuDe: String? = nil, loai: String? = nil, nguoi: Int? = nil, uuTien: Int? = nil, ghiChu: String?) async -> Bool {
        dangLam = true
        defer { dangLam = false }
        do {
            dx = try await APIClient.shared.request(CTWAPI.quyetDeXuat(pid: pid, id: dx.id, nhan: nhan, tieuDe: tieuDe, loai: loai,
                                                                      nguoi: nguoi, uuTien: uuTien, ghiChu: ghiChu))
            CTWRung.thanhCong()
            return true
        } catch {
            loi = DichVuLoi.cau(error)
            CTWRung.loi()
            return false
        }
    }
}

private struct NhanDeXuatSheet: View {
    let dx: CTWDeXuat
    let cfg: CTWProjectConfig?
    let xong: (String, String?, Int?, Int, String) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var tieuDe = ""
    @State private var loai: String?
    @State private var nguoi: Int = 0
    @State private var uuTien = 3
    @State private var note = ""
    @State private var dangGui = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Issue") {
                    TextField("Title", text: $tieuDe, axis: .vertical)
                    Picker("Type", selection: $loai) {
                        Text("Default").tag(String?.none)
                        ForEach((cfg?.dsLoai ?? []).filter { ($0.level ?? 0) == 0 }) { t in
                            Text(t.name).tag(Optional(t.key ?? ""))
                        }
                    }
                    Picker("Priority", selection: $uuTien) {
                        ForEach(CTW.doUuTien, id: \.so) { p in Label(p.ten, systemImage: p.bieuTuong).tag(p.so) }
                    }
                    Picker("Assignee", selection: $nguoi) {
                        Text("Unassigned").tag(0)
                        ForEach((cfg?.dsThanhVien ?? []).filter(\.giaoDuoc)) { u in
                            Text(u.laAgent ? "\(u.ten) (AI agent)" : u.ten).tag(u.id)
                        }
                    }
                }
                Section("Note") { TextField("Optional note (max 300)", text: $note, axis: .vertical) }
            }
            .navigationTitle("Accept as issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dangGui = true
                        Task {
                            if await xong(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines), loai, nguoi == 0 ? nil : nguoi, uuTien, note) { dong() }
                            dangGui = false
                        }
                    } label: { if dangGui { ProgressView() } else { Text("Create").bold() } }
                    .disabled(dangGui || tieuDe.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if tieuDe.isEmpty { tieuDe = dx.title } }
        }
    }
}

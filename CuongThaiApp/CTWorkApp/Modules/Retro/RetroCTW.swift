import SwiftUI
import Combine

// MARK: - Retrospectives: danh sách + tạo
//
// Thẻ retro là NỘI DUNG NGƯỜI DÙNG (1.2): báo cáo + ẩn ngay cho người báo, chặn người dùng,
// ẩn thẻ của người đã chặn. AI summary chỉ HIỂN THỊ nếu đã được tạo trên web (app không gửi
// dữ liệu cho AI — 5.1.2) và luôn có nhãn AI.

struct RouteRetroCTW: Hashable { var pid: Int; var rid: Int; var ten: String }

/// Thẻ retro người dùng đã báo cáo ⇒ ẩn ngay trên máy này (máy chủ chưa có route báo cáo riêng).
@MainActor
final class RetroAnCTW: ObservableObject {
    static let shared = RetroAnCTW()
    @Published private(set) var an: Set<Int>
    private let k = "com.cuongthai.ctwork.retroAn"
    private init() { an = Set(UserDefaults.standard.array(forKey: k) as? [Int] ?? []) }
    func anThe(_ id: Int) { an.insert(id); UserDefaults.standard.set(Array(an), forKey: k) }
    func boAnHet() { an = []; UserDefaults.standard.removeObject(forKey: k) }
}

struct RetroCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var ds: TaiCTW<CTWRetroDs> = .dangTai
    @State private var moTao = false
    @State private var huyNghe: AnyCancellable?

    var body: some View {
        KhungTaiCTW(trangThai: ds, thuLai: { Task { await tai() } }) { d in
            List {
                let mo = (d.retros ?? []).filter { $0.locked != true }
                let khoa = (d.retros ?? []).filter { $0.locked == true }
                if mo.isEmpty && khoa.isEmpty {
                    Section {
                        CTWOTrong(bieuTuong: "bubble.left.and.text.bubble.right", tieuDe: String(localized: "No retrospectives yet"),
                                  moTa: String(localized: "Collect what went well and what to improve, vote, and turn it into action items."),
                                  nut: d.canCreate == true ? String(localized: "New retro") : nil) { moTao = true }
                    }
                    .listRowBackground(Color.clear)
                }
                if !mo.isEmpty { Section("Open") { ForEach(mo) { hang($0) } } }
                if !khoa.isEmpty { Section("Locked") { ForEach(khoa) { hang($0) } } }
            }
            .listStyle(.insetGrouped)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Retrospectives")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if ds.giaTri?.canCreate == true {
                ToolbarItem(placement: .primaryAction) {
                    Button { moTao = true } label: { Image(systemName: "plus") }.accessibilityLabel("New retrospective")
                }
            }
        }
        .refreshable { await tai() }
        .task { await tai() }
        .onAppear {
            RealtimeKeHoachCTW.shared.nghe(pid: nguCanh.pid)
            huyNghe = RealtimeKeHoachCTW.shared.suKienAgile
                .filter { [pid = nguCanh.pid] in $0.projectId == pid && $0.kind == "retro" }
                .sink { _ in Task { await tai() } }
        }
        .onDisappear { huyNghe = nil; RealtimeKeHoachCTW.shared.boNghe(pid: nguCanh.pid) }
        .sheet(isPresented: $moTao) {
            TaoRetroCTW(pid: nguCanh.pid) { id, ten in
                Task { await tai() }
                nganXep.duong.append(RouteRetroCTW(pid: nguCanh.pid, rid: id, ten: ten))
            }
        }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "retros" else { return }
            defer { app.dichCho = nil }
            if let r = Int(d.duongDan.tham["r"] ?? d.duongDan.phanCon.first ?? "") {
                nganXep.duong.append(RouteRetroCTW(pid: nguCanh.pid, rid: r, ten: String(localized: "Retro")))
            }
        }
        #if DEBUG
        .onAppear {
            if let con = XemThuCTW.conCua("retros"), let r = Int(con), nganXep.duong.isEmpty {
                nganXep.duong.append(RouteRetroCTW(pid: nguCanh.pid, rid: r, ten: "Retro"))
            }
        }
        #endif
    }

    private func hang(_ r: CTWRetroDs.Retro) -> some View {
        NavigationLink(value: RouteRetroCTW(pid: nguCanh.pid, rid: r.id, ten: r.title ?? String(localized: "Retro"))) {
            HStack(spacing: 12) {
                Image(systemName: r.locked == true ? "lock.fill" : "bubble.left.and.text.bubble.right")
                    .font(.ctw(size: 15, weight: .semibold)).foregroundColor(r.locked == true ? AppColors.textSecondary : AppColors.primary)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill((r.locked == true ? AppColors.textSecondary : AppColors.primary).opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(r.title ?? String(localized: "Retro")).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        if r.anonymous == true {
                            Image(systemName: "eye.slash").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                                .accessibilityLabel("Anonymous")
                        }
                    }
                    Text([RetroCot.tenTemplate(r.template), r.sprint?.name, r.cards == 1 ? String(localized: "1 card") : String(localized: "\(r.cards ?? 0) cards"),
                                  r.actions == 1 ? String(localized: "1 action") : String(localized: "\(r.actions ?? 0) actions")]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
            }
            .padding(.vertical, 3)
        }
    }

    private func tai() async {
        do { ds = .xong(try await APIClient.shared.request(CTWAPI.dsRetro(pid: nguCanh.pid))) }
        catch { if ds.giaTri == nil { ds = .loi(CTW.loi(error)) } }
    }
}

// MARK: - Tạo retro

struct TaoRetroCTW: View {
    let pid: Int
    let taoXong: (Int, String) -> Void
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var template = "SSC"
    @State private var sprintId: Int?
    @State private var anDanh = false
    @State private var phieu = 5
    @State private var loi: String?
    @State private var dangLam = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") { TextField("e.g. Sprint 6 retro", text: $ten) }
                Section("Format") {
                    Picker("Format", selection: $template) {
                        Text("Start · Stop · Continue").tag("SSC")
                        Text("Mad · Sad · Glad").tag("MSG")
                        Text("4Ls (Liked, Learned, Lacked, Longed for)").tag("FOUR_L")
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
                Section {
                    Picker("Sprint", selection: $sprintId) {
                        Text("None").tag(Int?.none)
                        ForEach(app.cauHinhDuAn?.sprints ?? []) { s in Text(s.name).tag(Int?.some(s.id)) }
                    }
                    Stepper("Votes per person: \(phieu)", value: $phieu, in: 1...20)
                    Toggle("Anonymous cards", isOn: $anDanh)
                } footer: {
                    Text("Anonymous hides who wrote each card from everyone, including admins. It can't be turned off later.")
                }
                if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
            }
            .navigationTitle("New retrospective")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await tao() } } label: { if dangLam { ProgressView() } else { Text("Create").bold() } }
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty || dangLam)
                }
            }
            .onAppear {
                let s = app.cauHinhDuAn?.sprints?.first { $0.state == "ACTIVE" }
                sprintId = s?.id
                if ten.isEmpty, let s { ten = String(localized: "\(s.name) retro") }
            }
        }
    }

    private func tao() async {
        dangLam = true
        defer { dangLam = false }
        do {
            let t = ten.trimmingCharacters(in: .whitespaces)
            let r: CTWRetroTao = try await APIClient.shared.request(
                CTWAPI.taoRetro(pid: pid, ten: t, template: template, sprintId: sprintId, anDanh: anDanh, phieuMoiNguoi: phieu))
            CTWRung.thanhCong()
            dong()
            if let id = r.id { taoXong(id, t) }
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}

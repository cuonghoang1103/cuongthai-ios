import SwiftUI
import Charts
import Combine

// MARK: - Planning Poker: danh sách phiên + tạo phiên
//
// Ai được làm gì (máy chủ quyết, app chỉ ẩn nút): bỏ phiếu/tạo phiên = người (không phải agent)
// ADMIN/MEMBER; điều phối (bắt đầu, lật, chốt, bỏ qua, hẹn giờ, đóng) = người tạo phiên hoặc ADMIN.
// Realtime: `work:agile {kind:'poker'}` không mang nội dung ⇒ nhận là tải lại REST.

struct RoutePokerCTW: Hashable { var pid: Int; var sid: Int; var ten: String }

/// Phép tính thuần (kiểm thử được).
enum PokerTinh {
    static let fibonacci = ["0", "1", "2", "3", "5", "8", "13", "21", "?", "☕"]
    static let tshirt = ["XS", "S", "M", "L", "XL", "XXL", "?", "☕"]

    /// Bộ bài: máy chủ trả `cards`; bản cũ thiếu thì dựng theo `deck`.
    static func boBai(_ p: CTWPokerPhong) -> [String] {
        if let c = p.cards, !c.isEmpty { return c.map(\.value) }
        return p.deck == "TSHIRT" ? tshirt : fibonacci
    }

    /// Lá có điểm (chốt được) — bỏ `?` và `☕`.
    static func laChotDuoc(_ p: CTWPokerPhong) -> [String] {
        if let c = p.cards, !c.isEmpty { return c.filter { $0.points != nil }.map(\.value) }
        return boBai(p).filter { $0 != "?" && $0 != "☕" }
    }

    /// Giây còn lại của đồng hồ hẹn giờ. Dùng độ lệch `serverNow` − đồng hồ máy lúc tải để không
    /// phụ thuộc giờ máy (giờ máy lệch vài phút là đếm sai cả lượt).
    static func giayConLai(ketThuc: String?, serverNow: String?, taiLuc: Date, bayGio: Date) -> Int? {
        guard let kt = NgayCTW.thoiDiem(ketThuc) else { return nil }
        let lech = (NgayCTW.thoiDiem(serverNow) ?? taiLuc).timeIntervalSince(taiLuc)
        let mayChuBayGio = bayGio.addingTimeInterval(lech)
        return max(Int(kt.timeIntervalSince(mayChuBayGio).rounded(.up)), 0)
    }

    /// "Estimated 4 of 6 · 21 pts".
    static func tomTat(_ p: CTWPokerDs.Phien) -> String {
        let e = p.estimated ?? 0, n = p.items ?? 0
        if let d = p.points, d > 0 { return String(localized: "Estimated \(e) of \(n) · \(CTWSo.gon(d)) pts") }
        return String(localized: "Estimated \(e) of \(n)")
    }
}

struct PokerCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var ds: TaiCTW<CTWPokerDs> = .dangTai
    @State private var moTao = false
    @State private var huyNghe: AnyCancellable?

    var body: some View {
        KhungTaiCTW(trangThai: ds, thuLai: { Task { await tai() } }) { d in
            List {
                let mo = (d.sessions ?? []).filter { $0.status != "CLOSED" }
                let dong = (d.sessions ?? []).filter { $0.status == "CLOSED" }
                if mo.isEmpty && dong.isEmpty {
                    Section {
                        CTWOTrong(bieuTuong: "suit.spade", tieuDe: String(localized: "No poker sessions yet"),
                                  moTa: String(localized: "Estimate stories together: everyone picks a card, then reveal at once."),
                                  nut: d.canCreate == true ? String(localized: "New session") : nil) { moTao = true }
                    }
                    .listRowBackground(Color.clear)
                }
                if !mo.isEmpty { Section("Open") { ForEach(mo) { hang($0) } } }
                if !dong.isEmpty { Section("Closed") { ForEach(dong) { hang($0) } } }
            }
            .listStyle(.insetGrouped)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Planning poker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if ds.giaTri?.canCreate == true {
                ToolbarItem(placement: .primaryAction) {
                    Button { moTao = true } label: { Image(systemName: "plus") }.accessibilityLabel("New poker session")
                }
            }
        }
        .refreshable { await tai() }
        .task { await tai() }
        .onAppear {
            RealtimeKeHoachCTW.shared.nghe(pid: nguCanh.pid)
            huyNghe = RealtimeKeHoachCTW.shared.suKienAgile
                .filter { [pid = nguCanh.pid] in $0.projectId == pid && $0.kind == "poker" }
                .sink { _ in Task { await tai() } }
        }
        .onDisappear { huyNghe = nil; RealtimeKeHoachCTW.shared.boNghe(pid: nguCanh.pid) }
        .sheet(isPresented: $moTao) {
            TaoPokerCTW(pid: nguCanh.pid) { id, ten in
                Task { await tai() }
                nganXep.duong.append(RoutePokerCTW(pid: nguCanh.pid, sid: id, ten: ten))
            }
        }
        // Deep link `/work/<ws>/<KEY>/poker?s=<id>` ⇒ mở phòng. Xoá cờ ở CUỐI.
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "poker" else { return }
            defer { app.dichCho = nil }
            if let s = Int(d.duongDan.tham["s"] ?? d.duongDan.phanCon.first ?? "") {
                nganXep.duong.append(RoutePokerCTW(pid: nguCanh.pid, sid: s, ten: String(localized: "Poker")))
            }
        }
        #if DEBUG
        .onAppear {
            if let con = XemThuCTW.conCua("poker"), let s = Int(con), nganXep.duong.isEmpty {
                nganXep.duong.append(RoutePokerCTW(pid: nguCanh.pid, sid: s, ten: "Poker"))
            }
        }
        #endif
    }

    private func hang(_ p: CTWPokerDs.Phien) -> some View {
        NavigationLink(value: RoutePokerCTW(pid: nguCanh.pid, sid: p.id, ten: p.title ?? String(localized: "Poker"))) {
            HStack(spacing: 12) {
                Image(systemName: p.deck == "TSHIRT" ? "tshirt" : "suit.spade.fill")
                    .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.title ?? String(localized: "Poker")).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text([p.sprint?.name, PokerTinh.tomTat(p)].compactMap { $0 }.joined(separator: " · "))
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                    let tong = max(p.items ?? 0, 1)
                    CTWThanhTienDo(doan: [
                        CTWDoanTienDo(ten: String(localized: "Estimated"), giaTri: Double(p.estimated ?? 0), mau: AppColors.success),
                        CTWDoanTienDo(ten: String(localized: "Remaining"), giaTri: Double(tong - (p.estimated ?? 0)), mau: AppColors.backgroundTertiary),
                    ], cao: 5)
                }
            }
            .padding(.vertical, 3)
        }
    }

    private func tai() async {
        do { ds = .xong(try await APIClient.shared.request(CTWAPI.dsPoker(pid: nguCanh.pid))) }
        catch { if ds.giaTri == nil { ds = .loi(CTW.loi(error)) } }
    }
}

// MARK: - Tạo phiên

struct TaoPokerCTW: View {
    let pid: Int
    let taoXong: (Int, String) -> Void
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var boBai = "FIBONACCI"
    @State private var sprintId: Int?
    @State private var loi: String?
    @State private var dangLam = false

    private var sprints: [CTWSprint] { (app.cauHinhDuAn?.sprints ?? []).filter { $0.state != "CLOSED" } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") { TextField("e.g. Sprint 7 refinement", text: $ten) }
                Section("Deck") {
                    Picker("Deck", selection: $boBai) {
                        Text("Fibonacci (0, 1, 2, 3, 5, 8…)").tag("FIBONACCI")
                        Text("T-shirt (XS, S, M, L…)").tag("TSHIRT")
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
                Section {
                    Picker("Sprint", selection: $sprintId) {
                        Text("None").tag(Int?.none)
                        ForEach(sprints) { s in Text(s.state == "ACTIVE" ? String(localized: "\(s.name) (active)") : s.name).tag(Int?.some(s.id)) }
                    }
                } footer: { Text("Picking a sprint adds its unfinished stories and tasks to the session.") }
                if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
            }
            .navigationTitle("New poker session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await tao() } } label: { if dangLam { ProgressView() } else { Text("Create").bold() } }
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty || dangLam)
                }
            }
            .onAppear { sprintId = sprints.first { $0.state == "ACTIVE" }?.id }
        }
    }

    private func tao() async {
        dangLam = true
        defer { dangLam = false }
        do {
            let t = ten.trimmingCharacters(in: .whitespaces)
            let r: CTWPokerTao = try await APIClient.shared.request(CTWAPI.taoPoker(pid: pid, ten: t, boBai: boBai, sprintId: sprintId))
            CTWRung.thanhCong()
            dong()
            if let id = r.id { taoXong(id, t) }
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}

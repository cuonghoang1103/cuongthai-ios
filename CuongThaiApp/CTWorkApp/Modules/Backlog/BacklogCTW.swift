import SwiftUI

// MARK: - Backlog / List
//
// Hai chế độ (21/10/2026 — đợt B, ngang web):
//   · Sprints — `KeHoachSprintCTW`: lên kế hoạch sprint (kéo thả sprint ⇄ backlog, xếp hạng, chuyển sprint, sửa hàng loạt).
//   · All issues — `DanhSachCTW`: danh sách theo JQL (gợi ý, bộ lọc đã lưu, sắp xếp, trường hiện, đổi trạng thái tại chỗ).
// Trong trang dự án (công tắc Board · Backlog · List) mỗi chế độ hiện riêng (`nhung`); mở như mô-đun ⇒ có công tắc riêng.

struct BacklogCTW: View {
    let pid: Int
    @State private var cheDo: CheDo = .backlog

    enum CheDo: String, CaseIterable, Identifiable {
        case backlog = "Sprints", tatCa = "All issues"
        var id: String { rawValue }
        var ten: String { self == .backlog ? String(localized: "Sprints") : String(localized: "All issues") }
    }

    /// Nhúng trong trang dự án (công tắc Board · Backlog · List ở trên đã chọn chế độ) ⇒ ẩn công tắc Sprints/All riêng.
    private let nhung: Bool

    init(pid: Int, cheDoDau: CheDo = .backlog, nhung: Bool = false) {
        self.pid = pid
        self.nhung = nhung
        _cheDo = State(initialValue: cheDoDau)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !nhung {
                Picker("Mode", selection: $cheDo) {
                    ForEach(CheDo.allCases) { Text($0.ten).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
            }
            switch cheDo {
            case .backlog: KeHoachSprintCTW(pid: pid)
            case .tatCa: DanhSachCTW(pid: pid)
            }
        }
        .background(AppColors.backgroundPrimary)
        .modifier(TieuDeBacklog(bat: !nhung))
        // Màn Tìm mọi thứ gửi một câu JQL cho dự án này ⇒ sang "All issues" (DanhSachCTW nhận câu đó).
        .onReceive(DieuHuongTimCTW.shared.$jqlCho) { j in if let j, j.pid == pid { cheDo = .tatCa } }
        #if DEBUG
        .onAppear { if XemThuCTW.man?.lowercased() == "list" { cheDo = .tatCa } }
        #endif
    }
}

/// Tiêu đề "Backlog" chỉ khi mở như mô-đun — nhúng trong trang dự án thì để trang dự án đặt (tên dự án + menu đổi dự án).
private struct TieuDeBacklog: ViewModifier {
    let bat: Bool
    func body(content: Content) -> some View {
        if bat { content.navigationTitle("Backlog").navigationBarTitleDisplayMode(.inline) } else { content }
    }
}

// MARK: - Bảng lọc

struct BoLocCTW: View {
    let cauHinh: CTWProjectConfig
    @State var loc: CTWAPI.BoLoc
    @State var uuTien: Set<Int>
    let toi: Int?
    let apDung: (CTWAPI.BoLoc, Set<Int>) -> Void
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignee") {
                    if let toi {
                        chon(String(localized: "Me"), loc.assignee.contains(toi)) { doi(&loc.assignee, toi) }
                    }
                    chon(String(localized: "Unassigned"), loc.assignee.contains(0)) { doi(&loc.assignee, 0) }
                    ForEach(cauHinh.dsThanhVien.filter { $0.id != toi }) { u in
                        chon(u.laAgent ? String(localized: "\(u.ten) · AI agent") : u.ten, loc.assignee.contains(u.id)) { doi(&loc.assignee, u.id) }
                    }
                }
                Section("Status") {
                    ForEach(trangThai) { s in
                        chon(CTWTen.trangThai(s.name), loc.status.contains(s.id)) { doi(&loc.status, s.id) }
                    }
                    Toggle("Include done issues", isOn: $loc.includeDone)
                }
                Section("Priority") {
                    ForEach(CTW.doUuTien, id: \.so) { p in
                        Button {
                            if uuTien.contains(p.so) { uuTien.remove(p.so) } else { uuTien.insert(p.so) }
                        } label: {
                            HStack {
                                Label(p.ten, systemImage: p.bieuTuong).foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if uuTien.contains(p.so) { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
                            }
                        }
                    }
                }
                Section("Type") {
                    ForEach(cauHinh.dsLoai) { t in
                        chon(CTWTen.loai(t.name), loc.type.contains(t.id)) { doi(&loc.type, t.id) }
                    }
                }
                if !(cauHinh.labels ?? []).isEmpty {
                    Section("Labels") {
                        ForEach(cauHinh.labels ?? []) { l in
                            chon(l.name, loc.label.contains(l.id)) { doi(&loc.label, l.id) }
                        }
                    }
                }
                if !(cauHinh.sprints ?? []).isEmpty {
                    Section("Sprint") {
                        chon(String(localized: "Any"), loc.sprint == nil) { loc.sprint = nil }
                        chon(String(localized: "Backlog (no sprint)"), loc.sprint == "backlog") { loc.sprint = "backlog" }
                        ForEach(cauHinh.sprints ?? []) { s in
                            chon(s.state == "ACTIVE" ? String(localized: "\(s.name) (active)") : s.name, loc.sprint == String(s.id)) { loc.sprint = String(s.id) }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        let q = loc.q
                        loc = CTWAPI.BoLoc()
                        loc.q = q
                        uuTien = []
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apDung(loc, uuTien); dong() }.bold()
                }
            }
        }
    }

    private var trangThai: [CTWStatus] {
        var thay = Set<Int>()
        return cauHinh.tatCaTrangThai.filter { thay.insert($0.id).inserted }
    }

    private func doi(_ a: inout [Int], _ v: Int) {
        if let i = a.firstIndex(of: v) { a.remove(at: i) } else { a.append(v) }
    }

    private func chon(_ ten: String, _ bat: Bool, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            HStack {
                Text(ten).foregroundColor(AppColors.textPrimary)
                Spacer()
                if bat { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
            }
        }
    }
}

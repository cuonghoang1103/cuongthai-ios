import SwiftUI

// MARK: - Tấm phủ ghi sprint: tạo · sửa · bắt đầu · hoàn tất
//
// Một view cho cả bốn (theo `TamPhuSprintCTW`) để màn danh sách chỉ có MỘT `.sheet(item:)`.
// Lệnh ghi do nơi gọi chạy (`ghi`) — trả true thì đóng tấm phủ.

struct BangSprintCTW: View {
    let tamPhu: TamPhuSprintCTW
    let pid: Int
    /// Mọi sprint của dự án — để chọn sprint PLANNED nhận thẻ chưa xong khi hoàn tất.
    let dsKhac: [CTWSprintDu]
    /// Trả câu lỗi (nil = xong).
    let ghi: (APIEndpoint) async -> String?

    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var mucTieu = ""
    @State private var batDau = Date()
    @State private var ketThuc = Date().addingTimeInterval(14 * 86400)
    @State private var coNgay = false
    @State private var chuyen: DichChuyenSprintCTW = .backlog
    @State private var dangGhi = false
    @State private var daNap = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { CTWErrorBanner(text: loi).listRowInsets(EdgeInsets()).listRowBackground(Color.clear) } }
                noiDung
            }
                .navigationTitle(tieuDe)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                    ToolbarItem(placement: .confirmationAction) {
                        if dangGhi { ProgressView() } else {
                            Button(nutChinh) { Task { await luu() } }.bold().disabled(!hopLe)
                        }
                    }
                }
        }
        .presentationDetents([.large])
        .onAppear(perform: nap)
    }

    private var tieuDe: String {
        switch tamPhu {
        case .tao: return "New sprint"
        case .sua: return "Edit sprint"
        case .batDau: return "Start sprint"
        case .hoanTat: return "Complete sprint"
        }
    }

    private var nutChinh: String {
        switch tamPhu {
        case .tao: return "Create"
        case .sua: return "Save"
        case .batDau: return "Start"
        case .hoanTat: return "Complete"
        }
    }

    private var hopLe: Bool {
        switch tamPhu {
        case .batDau: return ketThuc > batDau
        case .sua: return !ten.trimmingCharacters(in: .whitespaces).isEmpty && (!coNgay || ketThuc > batDau)
        default: return true
        }
    }

    private func nap() {
        guard !daNap else { return }
        daNap = true
        switch tamPhu {
        case .tao: break
        case .sua(let s), .batDau(let s), .hoanTat(let s):
            ten = s.ten
            mucTieu = s.goal ?? ""
            if let a = NgayCTW.thoiDiem(s.startAt) { batDau = a; coNgay = true }
            if let b = NgayCTW.thoiDiem(s.endAt) { ketThuc = b } else { ketThuc = batDau.addingTimeInterval(14 * 86400) }
        }
    }

    @ViewBuilder private var noiDung: some View {
        switch tamPhu {
        case .tao:
            Section {
                TextField("Name (optional — defaults to “Sprint N”)", text: $ten)
                TextField("Sprint goal", text: $mucTieu, axis: .vertical).lineLimit(2...5)
            } footer: { Text("You can set dates when you start the sprint.") }
        case .sua:
            Section("Sprint") {
                TextField("Name", text: $ten)
                TextField("Sprint goal", text: $mucTieu, axis: .vertical).lineLimit(2...5)
            }
            Section {
                Toggle("Set dates", isOn: $coNgay)
                if coNgay { chonNgay }
            }
        case .batDau(let s):
            Section("Sprint") {
                TextField("Name", text: $ten)
                TextField("Sprint goal", text: $mucTieu, axis: .vertical).lineLimit(2...5)
            }
            Section {
                chonNgay
                HStack(spacing: 8) {
                    ForEach([1, 2, 3, 4], id: \.self) { tuan in
                        Button("\(tuan) wk") { ketThuc = NgayCTW.cong(batDau, ngay: tuan * 7) }
                            .buttonStyle(.bordered).font(.ctw(size: 13, weight: .semibold))
                    }
                }
            } header: { Text("Duration") } footer: {
                Text("Starting \(s.ten) commits its current issues. Only one sprint can be active at a time.")
            }
        case .hoanTat(let s):
            Section {
                Picker("Move unfinished issues to", selection: $chuyen) {
                    Text("Backlog").tag(DichChuyenSprintCTW.backlog)
                    Text("A new sprint").tag(DichChuyenSprintCTW.sprintMoi)
                    ForEach(dsKhac.filter { $0.chuaBatDau && $0.id != s.id }) { k in
                        Text(k.ten).tag(DichChuyenSprintCTW.sprint(k.id))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: { Text("Unfinished issues go to") } footer: {
                Text("Done issues stay in \(s.ten). Unfinished issues and their sub-tasks move to the place you pick.")
            }
        }
    }

    private var chonNgay: some View {
        Group {
            DatePicker("Start", selection: $batDau, displayedComponents: .date)
            DatePicker("End", selection: $ketThuc, in: batDau..., displayedComponents: .date)
        }
    }

    private func luu() async {
        dangGhi = true
        defer { dangGhi = false }
        let e: APIEndpoint
        switch tamPhu {
        case .tao:
            e = CTWAPI.taoSprint(pid: pid, ten: ten, mucTieu: mucTieu.isEmpty ? nil : mucTieu)
        case .sua(let s):
            e = CTWAPI.suaSprint(pid: pid, sid: s.id, ten: ten.trimmingCharacters(in: .whitespaces), mucTieu: mucTieu,
                                 batDau: coNgay ? batDau : nil, ketThuc: coNgay ? ketThuc : nil)
        case .batDau(let s):
            e = CTWAPI.batDauSprint(pid: pid, sid: s.id, ten: ten.trimmingCharacters(in: .whitespaces), mucTieu: mucTieu,
                                    batDau: batDau, ketThuc: ketThuc)
        case .hoanTat(let s):
            e = CTWAPI.hoanTatSprint(pid: pid, sid: s.id, chuyenDen: chuyen)
        }
        if let l = await ghi(e) { loi = l } else { dong() }
    }
}

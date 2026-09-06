import SwiftUI

/// Thêm / sửa một buổi học.
///
/// Kiểm ngay tại máy bằng ĐÚNG luật của máy chủ (`classSchedule.routes.ts`):
/// thứ 2..8, giờ HH:mm, kết thúc phải sau bắt đầu, nhắc 0..1440 phút. Để máy
/// chủ bắt thì người dùng gõ xong cả biểu mẫu mới biết mình sai.
struct SuaBuoiHocView: View {
    @ObservedObject var vm: TongQuanVM
    let buoi: BuoiHoc?
    @Environment(\.dismiss) private var dismiss

    @State private var mon = ""
    @State private var maLop = ""
    @State private var giangVien = ""
    @State private var phong = ""
    @State private var thu = 2
    @State private var batDau = Date()
    @State private var ketThuc = Date()
    @State private var nhacTruoc = 30
    @State private var ghiChu = ""
    @State private var coKy = false
    @State private var tuNgay = Date()
    @State private var denNgay = Date()
    @State private var dangLuu = false
    @State private var loi: String?

    /// 0 = không nhắc. Các mốc quen dùng — nhập số tự do thì đa số người chọn
    /// một trong mấy giá trị này, mà bàn phím số lại che mất biểu mẫu.
    private let mocNhac = [0, 10, 15, 30, 45, 60, 90, 120]

    var body: some View {
        Form {
            Section(T("Môn học")) {
                TextField(T("Tên môn"), text: $mon)
                TextField(T("Mã lớp (tuỳ chọn)"), text: $maLop)
                TextField(T("Giảng viên (tuỳ chọn)"), text: $giangVien)
                TextField(T("Phòng (tuỳ chọn)"), text: $phong)
            }

            Section {
                Picker(T("Thứ"), selection: $thu) {
                    ForEach(BuoiHoc.thuNho...BuoiHoc.thuLon, id: \.self) { t in
                        Text(BuoiHoc.tenThu(t)).tag(t)
                    }
                }
                DatePicker(T("Bắt đầu"), selection: $batDau, displayedComponents: .hourAndMinute)
                DatePicker(T("Kết thúc"), selection: $ketThuc, displayedComponents: .hourAndMinute)
                if let e = loiGio { Text(e).font(.system(size: 12)).foregroundColor(AppColors.error) }
            } header: {
                Text(T("Lịch"))
            }

            Section {
                Picker(T("Nhắc trước"), selection: $nhacTruoc) {
                    ForEach(mocNhac, id: \.self) { m in
                        Text(m == 0 ? T("Không nhắc") : String(format: T("%d phút"), m)).tag(m)
                    }
                }
            } header: {
                Text(T("Nhắc đi học"))
            } footer: {
                // Nói thẳng cơ chế: người dùng cần biết vì sao tắt thông báo
                // của app là mất lời nhắc, và vì sao nó vẫn kêu khi mất mạng.
                Text(T("Thông báo do máy đặt sẵn, lặp hằng tuần — không cần mạng. Tắt thông báo của app trong Cài đặt iOS thì sẽ không nhắc."))
            }

            Section {
                Toggle(T("Giới hạn theo kỳ học"), isOn: $coKy.animation())
                if coKy {
                    DatePicker(T("Từ ngày"), selection: $tuNgay, displayedComponents: .date)
                    DatePicker(T("Đến ngày"), selection: $denNgay, displayedComponents: .date)
                    if denNgay < tuNgay {
                        Text(T("Ngày kết thúc phải sau ngày bắt đầu."))
                            .font(.system(size: 12)).foregroundColor(AppColors.error)
                    }
                }
            } footer: {
                Text(T("Có kỳ học thì hết kỳ app tự thôi nhắc, không cần bạn vào xoá."))
            }

            Section(T("Ghi chú")) {
                TextField(T("Ghi chú (tuỳ chọn)"), text: $ghiChu, axis: .vertical).lineLimit(2...5)
            }

            if let loi {
                Section {
                    Label(loi, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error).font(.system(size: 13))
                }
            }

            if buoi != nil {
                Section {
                    Button(role: .destructive) {
                        if let b = buoi { Task { await vm.xoaBuoiHoc(b); dismiss() } }
                    } label: {
                        HStack { Spacer(); Text(T("Xoá buổi học")); Spacer() }
                    }
                }
            }
        }
        .navigationTitle(buoi == nil ? T("Thêm buổi học") : T("Sửa buổi học"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                if dangLuu { ProgressView() }
                else {
                    Button(T("Lưu")) { Task { await luu() } }
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(!hopLe)
                }
            }
        }
        .onAppear(perform: nap)
    }

    // MARK: Kiểm

    private var loiGio: String? {
        gio(ketThuc) <= gio(batDau) ? T("Giờ kết thúc phải sau giờ bắt đầu.") : nil
    }

    private var hopLe: Bool {
        !mon.trimmingCharacters(in: .whitespaces).isEmpty
        && loiGio == nil
        && (!coKy || denNgay >= tuNgay)
    }

    private func gio(_ d: Date) -> Int {
        let c = Calendar.current
        return c.component(.hour, from: d) * 60 + c.component(.minute, from: d)
    }

    private func hhmm(_ d: Date) -> String {
        let c = Calendar.current
        return String(format: "%02d:%02d", c.component(.hour, from: d), c.component(.minute, from: d))
    }

    // MARK: Nạp / lưu

    private func nap() {
        guard let b = buoi else {
            // Mặc định 07:00–09:15: ca sáng phổ biến nhất, và giờ hiện tại thì
            // gần như không bao giờ đúng giờ học.
            batDau = ngay(7, 0); ketThuc = ngay(9, 15)
            return
        }
        mon = b.subject
        maLop = b.classCode ?? ""
        giangVien = b.teacher ?? ""
        phong = b.room ?? ""
        thu = b.weekday
        let p1 = b.startTime.split(separator: ":").compactMap { Int($0) }
        let p2 = b.endTime.split(separator: ":").compactMap { Int($0) }
        batDau = ngay(p1.first ?? 7, p1.count > 1 ? p1[1] : 0)
        ketThuc = ngay(p2.first ?? 9, p2.count > 1 ? p2[1] : 0)
        nhacTruoc = mocNhac.contains(b.remindMinutes) ? b.remindMinutes : 30
        ghiChu = b.note ?? ""
        if let t = b.startDate, let d = PhamViViec.dinhDang.date(from: String(t.prefix(10))) {
            coKy = true; tuNgay = d
        }
        if let t = b.endDate, let d = PhamViViec.dinhDang.date(from: String(t.prefix(10))) {
            coKy = true; denNgay = d
        }
    }

    private func ngay(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    private func luu() async {
        dangLuu = true; loi = nil
        defer { dangLuu = false }

        func chu(_ s: String) -> Any {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? NSNull() : t     // rỗng = XOÁ trường, không phải bỏ qua
        }

        var p: [String: Any] = [
            "subject": mon.trimmingCharacters(in: .whitespaces),
            "classCode": chu(maLop), "teacher": chu(giangVien), "room": chu(phong),
            "note": chu(ghiChu),
            "weekday": thu,
            "startTime": hhmm(batDau), "endTime": hhmm(ketThuc),
            "remindMinutes": nhacTruoc,
        ]
        p["startDate"] = coKy ? PhamViViec.dinhDang.string(from: tuNgay) : NSNull()
        p["endDate"] = coKy ? PhamViViec.dinhDang.string(from: denNgay) : NSNull()

        if await vm.luuBuoiHoc(buoi, p) { dismiss() } else { loi = vm.loi }
    }
}

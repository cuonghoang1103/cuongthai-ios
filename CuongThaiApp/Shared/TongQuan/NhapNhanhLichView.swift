import SwiftUI

/// Nhập cả thời khoá biểu bằng MỘT khối chữ, thay vì mở biểu mẫu 10 lần.
///
/// Vì sao không dán thẳng bảng FAP: khi chép bảng HTML ra chữ thì **cột bị
/// mất**, mà cột chính là THỨ. Không có thứ thì không dựng lại được lịch, và
/// đoán theo thứ tự dòng là kiểu sai âm thầm. Dạng dưới đây bắt ghi rõ thứ,
/// gõ nhanh mà không mơ hồ.
///
///     thứ | slot | mã môn | phòng
///     2 | 2 | SWR302 | BE-210
///
/// Có bản xem trước bắt buộc: lưu hàng loạt là thao tác khó lùi (tuỳ chọn
/// "thay thế" xoá sạch lịch cũ), nên người dùng phải THẤY thứ mình sắp ghi.
struct NhapNhanhLichView: View {
    @ObservedObject var vm: TongQuanVM
    @Environment(\.dismiss) private var dismiss

    @State private var chu = ""
    @State private var nhacTruoc = 60
    @State private var coKy = true
    @State private var tuNgay = Date()
    @State private var soTuan = 10
    @State private var thayThe = false
    @State private var dangLuu = false
    @State private var loi: String?

    private let mocNhac = [0, 15, 30, 45, 60, 90, 120]

    /// Một dòng đã bóc tách. `loi` khác nil = dòng hỏng, không cho lưu.
    private struct Dong: Identifiable {
        let id = UUID()
        var so: Int
        var thu = 0
        var slot = 0
        var mon = ""
        var phong = ""
        var loi: String?
    }

    private var cacDong: [Dong] {
        chu.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { (i, raw) in
                let d = raw.trimmingCharacters(in: .whitespaces)
                if d.isEmpty || d.hasPrefix("#") { return nil }   // cho phép chú thích
                var r = Dong(so: i + 1)
                let phan = d.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                guard phan.count >= 3 else {
                    r.loi = T("cần ít nhất: thứ | slot | môn"); return r
                }
                guard let t = Int(phan[0]), t >= BuoiHoc.thuNho, t <= BuoiHoc.thuLon else {
                    r.loi = T("thứ phải từ 2 đến 8"); return r
                }
                guard let s = Int(phan[1]), SlotFAP.khung[s] != nil else {
                    r.loi = T("slot phải là 1–5"); return r
                }
                r.thu = t; r.slot = s
                r.mon = phan[2]
                r.phong = phan.count > 3 ? phan[3] : ""
                if r.mon.isEmpty { r.loi = T("thiếu tên môn") }
                return r
            }
    }

    private var soHong: Int { cacDong.filter { $0.loi != nil }.count }
    private var hopLe: Bool { !cacDong.isEmpty && soHong == 0 }

    private var denNgay: Date {
        Calendar.current.date(byAdding: .day, value: soTuan * 7 - 1, to: tuNgay) ?? tuNgay
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $chu)
                    .frame(minHeight: 150)
                    .font(.system(size: 14, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    // Bàn phím ASCII: mã môn có W (SWT301) mà Telex biến W → Ư.
                    .keyboardType(.asciiCapable)
            } header: {
                Text(T("Dán lịch"))
            } footer: {
                Text(T("Mỗi dòng một buổi:  thứ | slot | môn | phòng\nVí dụ:  3 | 1 | SWT301 | DE-412\nThứ 2–8 (8 = Chủ nhật) · Slot 1–5 · phòng có thể bỏ trống."))
                    .font(.system(size: 12))
            }

            if !cacDong.isEmpty {
                Section {
                    ForEach(cacDong) { d in
                        HStack(spacing: Spacing.sm) {
                            if let e = d.loi {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12)).foregroundColor(AppColors.error)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(String(format: T("Dòng %d"), d.so))
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(e).font(.system(size: 11)).foregroundColor(AppColors.error)
                                }
                            } else {
                                Text(BuoiHoc.tenThu(d.thu))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 52, alignment: .leading)
                                Text("S\(d.slot)")
                                    .font(.system(size: 11, weight: .heavy).monospacedDigit())
                                    .foregroundColor(AppColors.textTertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(d.mon).font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                    Text([d.phong, SlotFAP.khung[d.slot].map { "\($0.0)–\($0.1)" }]
                                            .compactMap { $0?.isEmpty == false ? $0 : nil }
                                            .joined(separator: " · "))
                                        .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                } header: {
                    Text(soHong == 0
                         ? String(format: T("Xem trước — %d buổi"), cacDong.count)
                         : String(format: T("Xem trước — %d dòng HỎNG"), soHong))
                }
            }

            Section {
                Picker(T("Nhắc trước"), selection: $nhacTruoc) {
                    ForEach(mocNhac, id: \.self) { m in
                        Text(m == 0 ? T("Không nhắc") : String(format: T("%d phút"), m)).tag(m)
                    }
                }
                Toggle(T("Giới hạn theo kỳ"), isOn: $coKy.animation())
                if coKy {
                    DatePicker(T("Tuần 1 bắt đầu"), selection: $tuNgay, displayedComponents: .date)
                    Stepper(String(format: T("Số tuần: %d"), soTuan), value: $soTuan, in: 1...30)
                    Text(String(format: T("Áp dụng tới %@"), ngayChu(denNgay)))
                        .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                }
            } header: {
                Text(T("Áp dụng cho mọi buổi"))
            } footer: {
                Text(T("Hết kỳ là app tự thôi nhắc, không cần bạn vào xoá."))
            }

            Section {
                Toggle(T("Xoá lịch cũ trước khi nhập"), isOn: $thayThe)
                    .tint(AppColors.error)
            } footer: {
                Text(thayThe
                     ? T("⚠️ Toàn bộ buổi học đang có sẽ bị xoá. Điểm danh đã chấm của chúng cũng mất theo.")
                     : T("Lịch mới được THÊM vào, buổi đang có giữ nguyên."))
            }

            if let loi {
                Section { Text(loi).font(.system(size: 13)).foregroundColor(AppColors.error) }
            }
        }
        .navigationTitle(T("Nhập nhanh lịch"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                if dangLuu { ProgressView() }
                else {
                    Button(T("Lưu")) { Task { await luu() } }
                        .font(.system(size: 16, weight: .semibold)).disabled(!hopLe)
                }
            }
        }
        .onAppear {
            // Mặc định tuần 1 = thứ Hai của tuần đang xem.
            tuNgay = vm.tuanDangXem
        }
    }

    private func ngayChu(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"
        return f.string(from: d)
    }

    private func luu() async {
        dangLuu = true; loi = nil
        defer { dangLuu = false }
        let f = PhamViViec.dinhDang
        let items: [[String: Any]] = cacDong.compactMap { d in
            guard d.loi == nil, let k = SlotFAP.khung[d.slot] else { return nil }
            var p: [String: Any] = [
                "subject": d.mon, "weekday": d.thu, "slot": d.slot,
                "startTime": k.0, "endTime": k.1, "remindMinutes": nhacTruoc,
            ]
            if !d.phong.isEmpty { p["room"] = d.phong }
            if coKy {
                p["startDate"] = f.string(from: tuNgay)
                p["endDate"] = f.string(from: denNgay)
            }
            return p
        }
        guard !items.isEmpty else { loi = T("Không có dòng nào hợp lệ."); return }
        do {
            try await APIClient.shared.send(.nhapLichHoc(items: items, thayThe: thayThe))
            await vm.napLich()
            Haptics.xong()
            dismiss()
        } catch { loi = error.localizedDescription }
    }
}

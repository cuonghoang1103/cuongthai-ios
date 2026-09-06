import SwiftUI

/// Thêm / sửa một buổi thi. Khác buổi học ở chỗ nó xảy ra ĐÚNG MỘT LẦN vào
/// một ngày cụ thể, nên chọn NGÀY chứ không chọn thứ.
struct SuaBuoiThiView: View {
    @ObservedObject var vm: TongQuanVM
    let thi: BuoiThi?
    @Environment(\.dismiss) private var dismiss

    @State private var mon = ""
    @State private var maMon = ""
    @State private var loai: LoaiThi = .PE
    @State private var ngay = Date()
    @State private var batDau = Date()
    @State private var ketThuc = Date()
    @State private var phong = ""
    @State private var soBaoDanh = ""
    @State private var ghiChu = ""
    @State private var nhacTruoc = 60
    @State private var dangLuu = false
    @State private var loi: String?

    /// Thi thì mốc nhắc dài hơn buổi học — phòng lạ, phải tới sớm.
    private let mocNhac = [0, 15, 30, 60, 90, 120, 180]

    var body: some View {
        Form {
            Section(T("Môn thi")) {
                TextField(T("Tên môn"), text: $mon)

                    // ⚠️ `.asciiCapable`: bàn phím tiếng Việt kiểu Telex biến
                    // "W" thành "Ư", nên gõ mã môn SWT301 / SWR302 ra SƯT301 —
                    // đo thật khi dùng. Mấy ô này LUÔN là mã ASCII nên ép được;
                    // riêng "Tên môn" thì không, vì tên có thể là tiếng Việt.
                TextField(T("Mã môn (tuỳ chọn)"), text: $maMon)
                    .keyboardType(.asciiCapable).autocorrectionDisabled()
                Picker(T("Loại"), selection: $loai) {
                    ForEach(LoaiThi.allCases) { l in Text(l.ten).tag(l) }
                }
            }

            Section {
                DatePicker(T("Ngày thi"), selection: $ngay, displayedComponents: .date)
                DatePicker(T("Bắt đầu"), selection: $batDau, displayedComponents: .hourAndMinute)
                DatePicker(T("Kết thúc"), selection: $ketThuc, displayedComponents: .hourAndMinute)
                if let e = loiGio { Text(e).font(.system(size: 12)).foregroundColor(AppColors.error) }
            } header: { Text(T("Thời gian")) }

            Section(T("Địa điểm")) {
                TextField(T("Phòng thi"), text: $phong)
                    .keyboardType(.asciiCapable).autocorrectionDisabled()
                TextField(T("Số báo danh / số máy"), text: $soBaoDanh)
                    .keyboardType(.asciiCapable).autocorrectionDisabled()
            }

            Section {
                Picker(T("Nhắc trước"), selection: $nhacTruoc) {
                    ForEach(mocNhac, id: \.self) { m in
                        Text(m == 0 ? T("Không nhắc") : String(format: T("%d phút"), m)).tag(m)
                    }
                }
            } header: { Text(T("Nhắc")) } footer: {
                Text(T("Thông báo đặt sẵn trong máy cho đúng ngày thi, không cần mạng."))
            }

            Section(T("Ghi chú")) {
                TextField(T("Mang theo gì, thi phần nào…"), text: $ghiChu, axis: .vertical).lineLimit(2...5)
            }

            if let loi {
                Section { Text(loi).font(.system(size: 13)).foregroundColor(AppColors.error) }
            }
            if let t = thi {
                Section {
                    Button(role: .destructive) {
                        Task { await vm.xoaBuoiThi(t); dismiss() }
                    } label: { HStack { Spacer(); Text(T("Xoá buổi thi")); Spacer() } }
                }
            }
        }
        .navigationTitle(thi == nil ? T("Thêm buổi thi") : T("Sửa buổi thi"))
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
        .onAppear(perform: nap)
    }

    private func gio(_ d: Date) -> Int {
        let c = Calendar.current
        return c.component(.hour, from: d) * 60 + c.component(.minute, from: d)
    }
    private func hhmm(_ d: Date) -> String {
        let c = Calendar.current
        return String(format: "%02d:%02d", c.component(.hour, from: d), c.component(.minute, from: d))
    }
    private var loiGio: String? {
        gio(ketThuc) <= gio(batDau) ? T("Giờ kết thúc phải sau giờ bắt đầu.") : nil
    }
    private var hopLe: Bool {
        !mon.trimmingCharacters(in: .whitespaces).isEmpty && loiGio == nil
    }

    private func nap() {
        guard let t = thi else {
            batDau = moc(7, 30); ketThuc = moc(9, 0)
            return
        }
        mon = t.monHoc; maMon = t.maMon ?? ""
        loai = t.kieu
        ngay = PhamViViec.dinhDang.date(from: t.ngayGon) ?? Date()
        let p1 = t.batDau.split(separator: ":").compactMap { Int($0) }
        let p2 = t.ketThuc.split(separator: ":").compactMap { Int($0) }
        batDau = moc(p1.first ?? 7, p1.count > 1 ? p1[1] : 30)
        ketThuc = moc(p2.first ?? 9, p2.count > 1 ? p2[1] : 0)
        phong = t.phong ?? ""; soBaoDanh = t.soBaoDanh ?? ""; ghiChu = t.ghiChu ?? ""
        nhacTruoc = mocNhac.contains(t.nhacTruoc) ? t.nhacTruoc : 60
    }

    private func moc(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    private func luu() async {
        dangLuu = true; loi = nil
        defer { dangLuu = false }
        func chu(_ s: String) -> Any {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? NSNull() : t
        }
        var p: [String: Any] = [
            "monHoc": mon.trimmingCharacters(in: .whitespaces),
            "maMon": chu(maMon), "loai": loai.rawValue,
            "ngay": PhamViViec.dinhDang.string(from: ngay),
            "batDau": hhmm(batDau), "ketThuc": hhmm(ketThuc),
            "phong": chu(phong), "soBaoDanh": chu(soBaoDanh), "ghiChu": chu(ghiChu),
            "nhacTruoc": nhacTruoc,
        ]
        // Gắn vào kỳ đang học nếu có — để sau lọc lịch thi theo kỳ được.
        if let k = vm.kyDangHoc { p["hocKyId"] = k.id }
        if await vm.luuBuoiThi(thi, p) { dismiss() } else { loi = vm.loi }
    }
}

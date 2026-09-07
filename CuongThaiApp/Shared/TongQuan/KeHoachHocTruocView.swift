import SwiftUI

/// "Học trước" — chia toàn bộ giáo trình Academy của một môn thành các buổi tự
/// học, rải đều trong N tuần, rồi đặt thành việc có ngày cụ thể.
///
/// Vì sao cần: trên lớp môn đó dạy 2 buổi/tuần suốt 10 tuần. Muốn ĐI TRƯỚC
/// chương trình thì phải học xong cùng lượng kiến thức trong 5 tuần — tức
/// khoảng gấp đôi nhịp. "Học trước" nói ra CHÍNH XÁC mỗi buổi phải học bài
/// nào, thay vì để người dùng tự chia và bỏ dở ở tuần thứ hai.
struct KeHoachHocTruocView: View {
    let mon: String
    let khoa: Course?
    let bai: [CourseLesson]
    @ObservedObject var vm: TongQuanVM
    @Environment(\.dismiss) private var dismiss

    @State private var soTuan = 5
    @State private var buoiMoiTuan = 4
    @State private var phutMoiBuoi = 45
    @State private var batDau = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var themKiemTra = true
    @State private var dangLuu = false
    @State private var loi: String?

    private var soBuoi: Int { max(1, soTuan * buoiMoiTuan) }
    /// Chia bài cho các buổi. Dư thì buổi đầu gánh thêm — học lúc còn hăng
    /// dễ hơn dồn vào tuần cuối, lúc đã sát lịch thi.
    private var chiaBai: [[CourseLesson]] {
        guard !bai.isEmpty else { return [] }
        let n = bai.count, b = min(soBuoi, n)
        var ra: [[CourseLesson]] = []
        var i = 0
        for k in 0..<b {
            let con = n - i, buoiCon = b - k
            let lay = Int(ceil(Double(con) / Double(buoiCon)))
            ra.append(Array(bai[i..<(i + lay)]))
            i += lay
        }
        return ra
    }

    /// Ngày của buổi thứ `k`, rải ĐỀU trong tuần thay vì dồn liền nhau.
    /// 4 buổi/tuần → lệch 0, 2, 4, 5 ngày; học cách quãng nhớ tốt hơn học dồn.
    private func ngayBuoi(_ k: Int) -> Date {
        let tuan = k / buoiMoiTuan, trongTuan = k % buoiMoiTuan
        let lech = Int((Double(trongTuan) * 7.0 / Double(buoiMoiTuan)).rounded())
        return Calendar.current.date(byAdding: .day, value: tuan * 7 + lech, to: batDau) ?? batDau
    }

    private var soViec: Int { chiaBai.count + (themKiemTra ? soTuan : 0) }
    private var phutMoiTuan: Int { buoiMoiTuan * phutMoiBuoi }

    var body: some View {
        Form {
            if bai.isEmpty {
                Section {
                    Text(String(format: T("Môn %@ chưa có bài học nào trong Academy nên chưa lập kế hoạch được."), mon))
                        .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                }
            } else {
                Section {
                    HStack {
                        Text(T("Giáo trình"))
                        Spacer()
                        Text(String(format: T("%d bài"), bai.count))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Stepper(String(format: T("Học xong trong: %d tuần"), soTuan), value: $soTuan, in: 1...15)
                    Stepper(String(format: T("Số buổi mỗi tuần: %d"), buoiMoiTuan), value: $buoiMoiTuan, in: 1...7)
                    Stepper(String(format: T("Mỗi buổi: %d phút"), phutMoiBuoi), value: $phutMoiBuoi, in: 15...120, step: 15)
                    DatePicker(T("Bắt đầu"), selection: $batDau, displayedComponents: .date)
                } header: {
                    Text(T("Nhịp học"))
                } footer: {
                    Text(String(format: T("≈ %d phút mỗi tuần, %d buổi. Buổi đầu gánh nhiều bài hơn — học lúc còn hăng dễ hơn dồn vào tuần cuối, lúc đã sát lịch thi."),
                                phutMoiTuan, chiaBai.count))
                }

                Section {
                    Toggle(T("Cuối mỗi tuần thêm việc làm đề"), isOn: $themKiemTra)
                } footer: {
                    Text(T("Làm một đề là cách kiểm nhanh nhất xem học trước có vào đầu không. Đọc lại thì lúc nào cũng thấy quen."))
                }

                Section {
                    ForEach(Array(chiaBai.enumerated()), id: \.offset) { i, nhom in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(String(format: T("Buổi %d"), i + 1))
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(AppColors.primary)
                                Text(ngayChu(ngayBuoi(i)))
                                    .font(.system(size: 11.5).monospacedDigit())
                                    .foregroundColor(AppColors.textTertiary)
                                Spacer(minLength: 0)
                                Text(String(format: T("%d bài"), nhom.count))
                                    .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                            }
                            // ⚠️ Tên bài cũng là chuỗi SONG NGỮ ghép "|||",
                            // giống tiêu đề đề thi. Hiện thẳng thì mỗi bài đọc
                            // ra hai lần bằng hai thứ tiếng.
                            Text(nhom.map { $0.title.tachSongNgu(.viet) }.joined(separator: " · "))
                                .font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
                                .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                    }
                } header: {
                    Text(String(format: T("XEM TRƯỚC — %d việc sẽ tạo"), soViec))
                }

                if let loi {
                    Section { Text(loi).font(.system(size: 13)).foregroundColor(AppColors.error) }
                }
            }
        }
        .navigationTitle(String(format: T("Học trước %@"), mon))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                if dangLuu { ProgressView() }
                else {
                    Button(T("Tạo")) { Task { await tao() } }
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(bai.isEmpty)
                }
            }
        }
    }

    private func ngayChu(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "EEE d/M"
        return f.string(from: d)
    }

    private func tao() async {
        dangLuu = true; loi = nil
        defer { dangLuu = false }
        let f = PhamViViec.dinhDang
        var soTao = 0

        for (i, nhom) in chiaBai.enumerated() {
            let ngay = f.string(from: ngayBuoi(i))
            var p: [String: Any] = [
                "scope": "today", "date": ngay,
                "title": String(format: T("Học trước %@ — buổi %d/%d (%d phút)"),
                                mon, i + 1, chiaBai.count, phutMoiBuoi),
                "exp": 25,
            ]
            // Ghi chú = danh sách bài của đúng buổi đó. Không có nó thì tới
            // hôm ấy người dùng chỉ thấy "buổi 7/20" và không biết học gì.
            p["note"] = nhom.map { "• \($0.title.tachSongNgu(.viet))" }.joined(separator: "\n")
            do {
                try await APIClient.shared.send(.themViec(p))
                soTao += 1
            } catch { loi = error.localizedDescription; return }
        }

        if themKiemTra {
            for t in 0..<soTuan {
                // Cuối tuần = buổi cuối của tuần đó, lùi lại 0 ngày.
                let k = min((t + 1) * buoiMoiTuan - 1, max(0, chiaBai.count - 1))
                let ngay = f.string(from: ngayBuoi(k))
                try? await APIClient.shared.send(.themViec([
                    "scope": "today", "date": ngay,
                    "title": String(format: T("Kiểm tra tuần %d: làm 1 đề %@"), t + 1, mon),
                    "exp": 25,
                ]))
                soTao += 1
            }
        }

        await vm.nap()
        Haptics.xong()
        dismiss()
    }
}

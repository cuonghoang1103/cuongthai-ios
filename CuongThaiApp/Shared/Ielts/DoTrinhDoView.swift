import SwiftUI

// ════════════════════════════════════════════════════════════════
// ĐO TRÌNH ĐỘ ĐẦU VÀO
//
// Mặc định app xếp mọi người vào Chặng 1 (Band 0→4.0). Người đã có nền
// vào đó sẽ thấy nhàm ngay bài thứ hai rồi bỏ — mà "nhàm" và "khó quá"
// đều dẫn tới cùng một kết cục.
//
// Lấy câu hỏi từ chính BÀI TẬP đã có của 4 chặng (200 câu mỗi chặng), mỗi
// chặng 4 câu. Không viết nội dung mới, không cần backend mới.
// ════════════════════════════════════════════════════════════════

struct CauDo: Identifiable, Hashable {
    let id = UUID()
    let chang: Int
    let q: String
    let options: [String]
    let answer: String
    let why: String?
}

struct DoTrinhDoView: View {
    @ObservedObject var vm: IeltsVM
    @Environment(\.dismiss) private var dong

    @State private var cau: [CauDo] = []
    @State private var i = 0
    @State private var chon: String?
    @State private var dungTheoChang: [Int: Int] = [:]
    @State private var tongTheoChang: [Int: Int] = [:]
    @State private var dangTai = true
    @State private var xong = false

    private let soCauMoiChang = 4

    var body: some View {
        NavigationStack {
            Group {
                if dangTai { ProgressView(T("Đang soạn đề…")) }
                else if xong { ketQua }
                else if i < cau.count { manCauHoi }
                else { ProgressView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Đo trình độ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
            }
            .task { await soanDe() }
        }
    }

    // MARK: Câu hỏi

    private var manCauHoi: some View {
        let c = cau[i]
        return VStack(alignment: .leading, spacing: Spacing.lg) {
            ProgressView(value: Double(i), total: Double(cau.count)).tint(AppColors.primary)
            Text("\(T("Câu")) \(i + 1)/\(cau.count)")
                .font(.caption).foregroundStyle(AppColors.textTertiary)

            Text(c.q).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Spacing.sm) {
                ForEach(c.options, id: \.self) { o in
                    Button { chon = o } label: {
                        HStack {
                            Text(o).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            if chon == o {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppColors.primary)
                            }
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(chon == o ? AppColors.primary.opacity(0.10) : AppColors.backgroundCard)
                        .cornerRadius(CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
            // KHÔNG hiện đúng/sai từng câu. Đây là bài ĐO, không phải bài
            // học: báo sai giữa chừng làm người ta đoán theo phản hồi và
            // con số cuối cùng mất ý nghĩa.
            Button(i == cau.count - 1 ? T("Xem kết quả") : T("Câu tiếp")) { traLoi() }
                .buttonStyle(.borderedProminent)
                .disabled(chon == nil)
                .frame(maxWidth: .infinity)
        }
        .padding(Spacing.md)
    }

    // MARK: Kết quả

    private var ketQua: some View {
        let de = changDeXuat
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("🎯").font(.system(size: 54)).frame(maxWidth: .infinity)
                Text(String(format: T("Bạn nên bắt đầu từ Chặng %d"), de))
                    .font(.titleMedium).foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)

                VStack(spacing: Spacing.sm) {
                    ForEach(1...4, id: \.self) { s in
                        let t = tongTheoChang[s] ?? 0
                        let d = dungTheoChang[s] ?? 0
                        HStack {
                            Text("\(T("Chặng")) \(s)").font(.bodySmall)
                            Spacer()
                            Text("\(d)/\(t)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(t > 0 && Double(d) / Double(t) >= 0.7
                                                 ? AppColors.success : AppColors.textTertiary)
                        }
                        .padding(.horizontal, Spacing.md).padding(.vertical, 6)
                        .background(AppColors.backgroundCard).cornerRadius(CornerRadius.medium)
                    }
                }

                Text(T("Đây là ước lượng nhanh từ 16 câu, không phải điểm thi. Bạn đổi chặng bất cứ lúc nào."))
                    .font(.caption).foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(String(format: T("Bắt đầu từ Chặng %d"), de)) {
                    vm.changDangXem = "stage\(de)"
                    dong()
                }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }
            .padding(Spacing.md)
        }
    }

    /// Chặng đầu tiên làm ĐÚNG dưới 70% — đó là chỗ còn thứ để học.
    ///
    /// Không lấy "chặng cao nhất vượt qua": vượt chặng 3 mà rớt chặng 2 là
    /// chuyện thường với 4 câu mỗi chặng, và đẩy người ta lên chặng 4 vì
    /// một lần đoán may là hỏng cả lộ trình.
    private var changDeXuat: Int {
        for s in 1...4 {
            let t = tongTheoChang[s] ?? 0
            let d = dungTheoChang[s] ?? 0
            if t > 0 && Double(d) / Double(t) < 0.7 { return s }
        }
        return 4
    }

    // MARK: Việc

    private func traLoi() {
        let c = cau[i]
        tongTheoChang[c.chang, default: 0] += 1
        if chon == c.answer { dungTheoChang[c.chang, default: 0] += 1 }
        chon = nil
        if i == cau.count - 1 { xong = true } else { i += 1 }
    }

    private func soanDe() async {
        guard cau.isEmpty else { return }
        dangTai = true
        defer { dangTai = false }
        var ds: [CauDo] = []
        for s in 1...4 {
            let bt = await IeltsAPI.baiTapThoTheoChang("stage\(s)")
            // Lấy NGẪU NHIÊN, không lấy 4 câu đầu: lấy đầu thì làm lại lần
            // thứ hai gặp y hệt, và con số đo được chỉ là trí nhớ.
            // Chỉ lấy câu TRẮC NGHIỆM có đủ lựa chọn, và đáp án phải nằm
            // trong đó — dữ liệu 200 câu/chặng do nhiều đợt soạn, không cái
            // nào bảo đảm điều đó, mà một câu không bấm đúng được sẽ làm
            // lệch kết quả đo theo hướng không ai phát hiện ra.
            let dungDuoc = bt.filter { c in
                guard let o = c.options, o.count >= 2 else { return false }
                return o.contains(c.answer)
            }
            for c in dungDuoc.shuffled().prefix(soCauMoiChang) {
                ds.append(CauDo(chang: s, q: c.q, options: c.options ?? [],
                                answer: c.answer, why: c.why))
            }
        }
        cau = ds
    }
}

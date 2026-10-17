import SwiftUI
import Charts

// MARK: - Biểu đồ burndown / burnup (Swift Charts)
//
// Dùng ở chi tiết sprint, tab Burndown của Reports và widget `burndown` của Dashboards.
// Một trục y (đơn vị ước lượng), đường 2pt, lý tưởng nét đứt xám, vạch "Today".

struct BieuDoBurndownCTW: View {
    let diem: [DiemSprintCTW]
    let unit: String?
    var cao: CGFloat = 220

    private var mauCon: Color { CTWMauChuoi.mau(0) }
    private var mauLyTuong: Color { AppColors.textTertiary }

    var body: some View {
        CTWKhungBieuDo(
            tieuDe: "Burndown",
            phu: "Remaining \(DonViSprintCTW.tenDai(unit)) per day",
            chuGiai: [CTWMucChuGiai(ten: "Remaining", mau: mauCon),
                      CTWMucChuGiai(ten: "Ideal", mau: mauLyTuong, netDut: true)],
            cot: ["Day", "Remaining", "Ideal"],
            hang: diem.map { CTWHangBang(nhan: NgayCTW.ngan($0.ngay),
                                         giaTri: [$0.conLai.map(CTWSo.gon) ?? "—", $0.lyTuong.map(CTWSo.gon) ?? "—"]) },
            cao: cao
        ) {
            Chart {
                ForEach(diem) { d in
                    if let l = d.lyTuong {
                        LineMark(x: .value("Day", d.ngay, unit: .day), y: .value("Ideal", l), series: .value("Series", "Ideal"))
                            .foregroundStyle(mauLyTuong)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                }
                ForEach(diem) { d in
                    if let c = d.conLai {
                        LineMark(x: .value("Day", d.ngay, unit: .day), y: .value("Remaining", c), series: .value("Series", "Remaining"))
                            .foregroundStyle(mauCon)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)
                        AreaMark(x: .value("Day", d.ngay, unit: .day), y: .value("Remaining", c), series: .value("Series", "RemainingArea"))
                            .foregroundStyle(LinearGradient(colors: [mauCon.opacity(0.18), mauCon.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                    }
                }
                if let h = homNay {
                    RuleMark(x: .value("Today", h, unit: .day))
                        .foregroundStyle(AppColors.primary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Today").font(.system(size: 9, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        }
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(AppColors.divider)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: false)
            } }
            .chartYAxis { AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppColors.divider)
                AxisValueLabel()
            } }
            .accessibilityLabel("Burndown chart")
        }
    }

    private var homNay: Date? {
        let h = NgayCTW.ngay(NgayCTW.ymd(Date()))
        guard let h, let a = diem.first?.ngay, let b = diem.last?.ngay, h >= a, h <= b else { return nil }
        return h
    }
}

struct BieuDoBurnupCTW: View {
    let diem: [DiemSprintCTW]
    let unit: String?
    var cao: CGFloat = 200

    var body: some View {
        let ds = diem.filter { $0.tong != nil }
        CTWKhungBieuDo(
            tieuDe: "Burnup",
            phu: "Scope vs completed \(DonViSprintCTW.tenDai(unit)) — scope changes show as steps",
            chuGiai: [CTWMucChuGiai(ten: "Scope", mau: CTWMauChuoi.mau(1)),
                      CTWMucChuGiai(ten: "Completed", mau: AppColors.success)],
            cot: ["Day", "Scope", "Completed"],
            hang: ds.map { CTWHangBang(nhan: NgayCTW.ngan($0.ngay), giaTri: [$0.tong.map(CTWSo.gon) ?? "—", $0.xong.map(CTWSo.gon) ?? "—"]) },
            cao: cao
        ) {
            Chart {
                ForEach(ds) { d in
                    LineMark(x: .value("Day", d.ngay, unit: .day), y: .value("Scope", d.tong ?? 0), series: .value("Series", "Scope"))
                        .foregroundStyle(CTWMauChuoi.mau(1))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.stepEnd)
                }
                ForEach(ds) { d in
                    AreaMark(x: .value("Day", d.ngay, unit: .day), y: .value("Completed", d.xong ?? 0), series: .value("Series", "Completed"))
                        .foregroundStyle(AppColors.success.opacity(0.22))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Day", d.ngay, unit: .day), y: .value("Completed", d.xong ?? 0), series: .value("Series", "CompletedLine"))
                        .foregroundStyle(AppColors.success)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(AppColors.divider)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: false)
            } }
            .chartYAxis { AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppColors.divider)
                AxisValueLabel()
            } }
            .accessibilityLabel("Burnup chart")
        }
    }
}

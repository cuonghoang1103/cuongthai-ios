import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

// MARK: - Widget + Live Activity của app CT Work (mảng D, 18/10/2026)
//
// Widget KHÔNG gọi mạng, KHÔNG cầm token: chỉ đọc ảnh chụp JSON app ghi vào App Group
// (`CTWorkShared/NhomCTW.swift`). App ghi lại mỗi lần ra tiền cảnh / tải My Work / đổi đồng hồ,
// rồi `WidgetCenter.reloadTimelines`. Ảnh chụp quá cũ (> 12 giờ) ⇒ ghi rõ "Open CT Work to refresh".
// ⚠️ Không kéo `Shared/` vào target này (giới hạn bộ nhớ extension) — chỉ `CTWorkShared/`.

private enum MauW {
    static let chinh = Color(red: 0.478, green: 0.271, blue: 0.910)
    static let hop = Color(red: 0.13, green: 0.55, blue: 0.85)
    static let han = Color(red: 0.95, green: 0.55, blue: 0.10)
    static let tre = Color(red: 0.88, green: 0.24, blue: 0.24)
    static let ke = Color(red: 0.20, green: 0.66, blue: 0.45)
}

@main
struct GoiWidgetCTW: WidgetBundle {
    var body: some Widget {
        ViecHomNayWidget()
        DongHoWidget()
        DongHoLiveActivityWidget()
    }
}

// MARK: - 1. My work today

struct MocViec: TimelineEntry {
    let date: Date
    let anh: AnhViecHomNayCTW?
}

struct NguonViec: TimelineProvider {
    func placeholder(in context: Context) -> MocViec { MocViec(date: Date(), anh: Self.mau) }
    func getSnapshot(in context: Context, completion: @escaping (MocViec) -> Void) {
        completion(MocViec(date: Date(), anh: context.isPreview ? (AnhViecHomNayCTW.doc() ?? Self.mau) : AnhViecHomNayCTW.doc()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MocViec>) -> Void) {
        // Vẽ lại sau nửa đêm (giờ VN) để "hôm nay" không trôi sang hôm qua; app vẫn đẩy lại khi có dữ liệu mới.
        var c = Calendar(identifier: .gregorian)
        c.timeZone = NgayNhomCTW.mui
        let mai = c.startOfDay(for: c.date(byAdding: .day, value: 1, to: Date()) ?? Date()).addingTimeInterval(60)
        let tiep = min(mai, Date().addingTimeInterval(30 * 60))
        completion(Timeline(entries: [MocViec(date: Date(), anh: AnhViecHomNayCTW.doc())], policy: .after(tiep)))
    }

    static let mau = AnhViecHomNayCTW(ngay: NgayNhomCTW.ymd(), capNhat: Date(), viec: [
        .init(loai: "meeting", id: "m", tieuDe: "Daily stand-up", ma: "M-4", duAn: "NW", gio: Date().addingTimeInterval(3600), quaHan: false, duongDan: nil),
        .init(loai: "overdue", id: "o", tieuDe: "Fix login crash", ma: "NW-9", duAn: "NW", gio: nil, quaHan: true, duongDan: nil),
        .init(loai: "due", id: "d", tieuDe: "Push notifications open the right issue", ma: "NW-12", duAn: "NW", gio: nil, quaHan: false, duongDan: nil),
    ], daDangNhap: true)
}

struct ViecHomNayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTWViecHomNayWidget", provider: NguonViec()) { m in
            ViecHomNayView(moc: m).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("My work today")
        .description("Today's meetings, issues due and overdue work.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

struct ViecHomNayView: View {
    let moc: MocViec
    @Environment(\.widgetFamily) private var co

    private var viec: [AnhViecHomNayCTW.Viec] {
        guard let a = moc.anh, a.daDangNhap, a.ngay == NgayNhomCTW.ymd(moc.date) else { return [] }
        return a.viec
    }
    private var cu: Bool { (moc.anh.map { moc.date.timeIntervalSince($0.capNhat) } ?? .infinity) > 12 * 3600 }

    var body: some View {
        switch co {
        case .accessoryInline:
            Text(viec.isEmpty ? "CT Work: all clear" : "CT Work: \(viec.count) today")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Today").font(.headline).widgetAccentable()
                if let a = moc.anh, !a.daDangNhap { Text("Sign in to CT Work").font(.caption) }
                else if viec.isEmpty { Text("Nothing due").font(.caption) }
                ForEach(viec.prefix(2)) { v in Text("\(v.ma ?? "•") \(v.tieuDe)").font(.caption).lineLimit(1) }
            }
        default:
            noiDung
        }
    }

    private var soDong: Int { co == .systemLarge ? 8 : (co == .systemMedium ? 4 : 3) }

    @ViewBuilder private var noiDung: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checklist").font(.caption.weight(.bold)).foregroundStyle(MauW.chinh)
                Text(co == .systemSmall ? "Today" : "My work today").font(.caption.weight(.bold))
                Spacer(minLength: 0)
                if !viec.isEmpty { Text("\(viec.count)").font(.caption.weight(.bold)).foregroundStyle(.secondary) }
            }
            if let a = moc.anh, !a.daDangNhap {
                Spacer(); Text("Sign in to CT Work to see your day.").font(.caption).foregroundStyle(.secondary); Spacer()
            } else if moc.anh == nil {
                Spacer(); Text("Open CT Work once to set up this widget.").font(.caption).foregroundStyle(.secondary); Spacer()
            } else if viec.isEmpty {
                Spacer()
                Label("All clear today", systemImage: "checkmark.circle").font(.subheadline.weight(.semibold)).foregroundStyle(MauW.ke)
                Spacer()
            } else {
                ForEach(viec.prefix(soDong)) { v in dong(v) }
                Spacer(minLength: 0)
                if viec.count > soDong { Text("+\(viec.count - soDong) more").font(.caption2).foregroundStyle(.secondary) }
            }
            if cu && moc.anh?.daDangNhap == true {
                Text("Open CT Work to refresh").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "ctwork://mywork"))
    }

    private func dong(_ v: AnhViecHomNayCTW.Viec) -> some View {
        let mau: Color = v.loai == "meeting" ? MauW.hop : (v.quaHan ? MauW.tre : (v.loai == "due" ? MauW.han : MauW.ke))
        let link = v.duongDan.flatMap { URL(string: $0.hasPrefix("/") ? "ctwork:/\($0)" : $0) }
        return Link(destination: link ?? URL(string: "ctwork://mywork")!) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(mau).frame(width: 3, height: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(v.tieuDe).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(phu(v)).font(.caption2).foregroundStyle(v.quaHan ? MauW.tre : .secondary).lineLimit(1)
                }
            }
        }
    }

    private func phu(_ v: AnhViecHomNayCTW.Viec) -> String {
        var p: [String] = []
        if let g = v.gio { p.append(g.formatted(date: .omitted, time: .shortened)) }
        if v.quaHan { p.append("Overdue") }
        if let m = v.ma { p.append(m) } else if let d = v.duAn { p.append(d) }
        return p.joined(separator: " · ")
    }
}

// MARK: - 2. Timer

struct MocDongHo: TimelineEntry {
    let date: Date
    let anh: AnhDongHoCTW?
}

struct NguonDongHo: TimelineProvider {
    func placeholder(in context: Context) -> MocDongHo {
        MocDongHo(date: Date(), anh: AnhDongHoCTW(issueKey: "NW-12", issueTitle: "Push notifications", projectKey: "NW", running: true,
                                                  runningSince: Date().addingTimeInterval(-4980), elapsedSec: 0, duongDan: nil, capNhat: Date()))
    }
    func getSnapshot(in context: Context, completion: @escaping (MocDongHo) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : MocDongHo(date: Date(), anh: AnhDongHoCTW.doc()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MocDongHo>) -> Void) {
        // `Text(timerInterval:)` tự đếm — không cần mốc mỗi giây. App đẩy lại khi đồng hồ đổi.
        completion(Timeline(entries: [MocDongHo(date: Date(), anh: AnhDongHoCTW.doc())], policy: .never))
    }
}

struct DongHoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTWDongHoWidget", provider: NguonDongHo()) { m in
            DongHoWidgetView(moc: m).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Timer")
        .description("Your running CT Work timer.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}

struct DongHoWidgetView: View {
    let moc: MocDongHo
    @Environment(\.widgetFamily) private var co

    var body: some View {
        if let d = moc.anh {
            switch co {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: d.running ? "timer" : "pause.fill").font(.caption)
                    DemGioW(anh: d).font(.caption2.monospacedDigit()).minimumScaleFactor(0.6)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text(d.issueKey).font(.headline).widgetAccentable()
                    DemGioW(anh: d).font(.body.monospacedDigit())
                    Text(d.running ? d.issueTitle : "Paused").font(.caption).lineLimit(1)
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Label(d.running ? "Running" : "Paused", systemImage: d.running ? "timer" : "pause.circle.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(d.running ? MauW.chinh : .secondary)
                    DemGioW(anh: d).font(.title2.weight(.semibold).monospacedDigit()).minimumScaleFactor(0.7)
                    Text(d.issueKey).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(d.issueTitle).font(.caption).lineLimit(2)
                    Spacer(minLength: 0)
                }
                .widgetURL(d.duongDan.flatMap { URL(string: "ctwork:/\($0)") } ?? URL(string: "ctwork://mywork"))
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "timer").font(.title3).foregroundStyle(MauW.chinh)
                Text(co == .systemSmall ? "No timer running" : "No timer").font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .widgetURL(URL(string: "ctwork://mywork"))
        }
    }
}

/// Đếm giờ: đang chạy ⇒ hệ thống tự đếm; tạm dừng ⇒ số tĩnh.
struct DemGioW: View {
    let anh: AnhDongHoCTW
    var body: some View {
        if anh.running, let tu = anh.runningSince {
            Text(timerInterval: tu...Date.distantFuture, countsDown: false)
        } else {
            Text(DemGioW.chu(anh.elapsedSec))
        }
    }
    static func chu(_ giay: Int) -> String {
        let g = max(giay, 0)
        return String(format: "%d:%02d:%02d", g / 3600, (g % 3600) / 60, g % 60)
    }
}

// MARK: - 3. Live Activity (Lock Screen + Dynamic Island)

struct DongHoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CTWDongHoAttributes.self) { ctx in
            ManKhoaDongHo(s: ctx.state)
                .padding(14)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.9))
                .widgetURL(URL(string: "ctwork://work/\(ctx.attributes.workspaceSlug)/\(ctx.state.projectKey)/issue/\(ctx.attributes.issueNumber)"))
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(ctx.state.issueKey, systemImage: ctx.state.running ? "timer" : "pause.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(MauW.chinh)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DemLA(s: ctx.state).font(.title3.weight(.semibold).monospacedDigit()).frame(maxWidth: 110)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ctx.state.issueTitle).font(.subheadline).lineLimit(1)
                        NutLA(s: ctx.state)
                    }
                }
            } compactLeading: {
                Image(systemName: ctx.state.running ? "timer" : "pause.fill").foregroundStyle(MauW.chinh)
            } compactTrailing: {
                DemLA(s: ctx.state).monospacedDigit().frame(maxWidth: 56)
            } minimal: {
                Image(systemName: ctx.state.running ? "timer" : "pause.fill").foregroundStyle(MauW.chinh)
            }
            .widgetURL(URL(string: "ctwork://work/\(ctx.attributes.workspaceSlug)/\(ctx.state.projectKey)/issue/\(ctx.attributes.issueNumber)"))
        }
    }
}

struct DemLA: View {
    let s: CTWDongHoAttributes.ContentState
    var body: some View {
        if s.running, let tu = s.runningSince {
            Text(timerInterval: tu...Date.distantFuture, countsDown: false)
        } else {
            Text(DemGioW.chu(s.elapsedSec))
        }
    }
}

struct ManKhoaDongHo: View {
    let s: CTWDongHoAttributes.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(s.running ? "CT Work timer" : "Timer paused", systemImage: s.running ? "timer" : "pause.circle.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(MauW.chinh)
                    Text("\(s.issueKey) · \(s.issueTitle)").font(.subheadline.weight(.semibold)).lineLimit(1)
                    if let a = s.activity { Text(a).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                DemLA(s: s).font(.title.weight(.semibold).monospacedDigit()).frame(maxWidth: 140, alignment: .trailing)
            }
            NutLA(s: s)
        }
    }
}

/// Nút trên Live Activity — `NutDongHoLiveIntent` chạy trong tiến trình app.
struct NutLA: View {
    let s: CTWDongHoAttributes.ContentState
    var body: some View {
        HStack(spacing: 10) {
            if s.running {
                Button(intent: NutDongHoLiveIntent("pause")) { Label("Pause", systemImage: "pause.fill") }
            } else {
                Button(intent: NutDongHoLiveIntent("resume")) { Label("Resume", systemImage: "play.fill") }
            }
            Button(intent: NutDongHoLiveIntent("stop")) { Label("Stop & log", systemImage: "stop.fill") }
                .tint(MauW.tre)
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
    }
}

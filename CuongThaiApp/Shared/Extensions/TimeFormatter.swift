import Foundation

// MARK: - Time Formatter
struct TimeFormatter {
    static func formatTimeAgo(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }
        if date == nil {
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            date = customFormatter.date(from: dateString)
        }
        if date == nil {
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            date = customFormatter.date(from: dateString)
        }

        guard let parsedDate = date else { return "" }

        let now = Date()
        let interval = now.timeIntervalSince(parsedDate)

        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7
        let months = days / 30
        let years = days / 365

        if seconds < 60 { return "Vừa xong" }
        if minutes < 60 { return "\(minutes)p trước" }
        if hours < 24 { return "\(hours)h trước" }
        if days < 7 { return "\(days)ngày trước" }
        if weeks < 4 { return "\(weeks)tuần trước" }
        if months < 12 { return "\(months)tháng trước" }
        return "\(years)năm trước"
    }
}

// MARK: - Đọc chuỗi thời gian ISO của backend

extension Date {
    /// Backend trả ISO-8601 lúc CÓ lúc KHÔNG có phần giây lẻ (`.123`), tuỳ chỗ
    /// serialize. `ISO8601DateFormatter` chỉ nhận đúng một dạng theo cờ đang
    /// đặt, nên thử lần lượt — thiếu bước này thì so mốc đọc luôn thất bại và
    /// "Đã xem" không bao giờ hiện.
    static func tuChuoiISO(_ chuoi: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: chuoi) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: chuoi)
    }
}

import SwiftUI

// ════════════════════════════════════════════════════════════════
// BỘ SÁCH CuongThai — 25 tập
//
// ⚠️ Danh sách này CHÉP TỪ `frontend/src/app/books/booksData.ts` của web
// (sinh bằng script 25/08/2026), KHÔNG tải động. Lý do: web không có
// manifest — thử `GET /books/index.json` và `/books/books.json` đều trả
// **200 nhưng là trang HTML của Next**, không phải JSON. Tin mã 200 mà không
// xem `content-type` là trúng bẫy đó.
//
// ⚠️ Hệ quả: thêm tập thứ 26 trên web thì PHẢI cập nhật file này. Muốn hết
// phải thì thêm một `books.json` thật vào `frontend/public/books/`.
//
// Nội dung sách thì tải thật từ `https://cuongthai.com/books/<file>` (HTML tự
// chứa) và bản dịch từ `/books/i18n/<slug>.vi.json`. Đo 25/08/2026: cả ba
// loại tệp đều tải được, và bản dịch phủ **100%** số khối.

struct Sach: Identifiable, Hashable {
    let vol: String
    let file: String
    let mauHex: String
    let tua: String
    let soChuong: String
    let soBaiTap: String
    let soTu: String

    var id: String { vol }
    /// Bỏ đuôi `.html` — dùng để tra file dịch.
    var slug: String { String(file.dropLast(5)) }
    var duongSach: URL? { URL(string: "https://cuongthai.com/books/\(file)") }
    var duongDich: URL? { URL(string: "https://cuongthai.com/books/i18n/\(slug).vi.json") }
    var mau: Color { Color(hex: UInt32(mauHex.dropFirst(), radix: 16) ?? 0x64748B) }
}

struct NhomSach: Identifiable, Hashable {
    let tua: String
    let moTa: String
    let sach: [Sach]
    var id: String { tua }
}

enum KhoSach {
    /// Số liệu cả bộ, lấy từ `SERIES_STATS` của web.
    static let thongKe: [(String, String)] = [
        ("25", "tập"),
        ("412", "chương"),
        ("3,607", "bài tập"),
        ("2,479", "đoạn mã"),
        ("745", "bảng"),
        ("809,780", "từ"),
    ]

    static let nhom: [NhomSach] = [
        NhomSach(tua: "Foundations", moTa: "The ground everything else stands on.", sach: [
            Sach(vol: "24", file: "24-the-terminal-from-zero-to-fluent.html", mauHex: "#256B4F",
                 tua: "The Terminal from Zero to Fluent", soChuong: "24",
                 soBaiTap: "179", soTu: "77,095"),
            Sach(vol: "17", file: "17-linux-and-bash-from-zero-to-production.html", mauHex: "#8A5A14",
                 tua: "Linux and Bash from Zero to Production", soChuong: "16",
                 soBaiTap: "175", soTu: "34,408"),
            Sach(vol: "25", file: "25-networking-from-zero-to-production.html", mauHex: "#1F5D7A",
                 tua: "Networking from Zero to Production", soChuong: "24",
                 soBaiTap: "182", soTu: "129,015"),
            Sach(vol: "09", file: "09-git-from-zero-to-confident.html", mauHex: "#8E3B2A",
                 tua: "Git from Zero to Confident", soChuong: "17",
                 soBaiTap: "160", soTu: "20,889"),
        ]),
        NhomSach(tua: "Languages", moTa: "The three languages the rest of the series is written in.", sach: [
            Sach(vol: "03", file: "03-javascript-from-zero-to-production.html", mauHex: "#8A5A14",
                 tua: "JavaScript from Zero to Production", soChuong: "17",
                 soBaiTap: "160", soTu: "17,605"),
            Sach(vol: "04", file: "04-typescript-from-zero-to-type-safe.html", mauHex: "#3B3E8C",
                 tua: "TypeScript from Zero to Type-Safe", soChuong: "20",
                 soBaiTap: "160", soTu: "29,747"),
            Sach(vol: "02", file: "02-java-from-zero-to-lab211.html", mauHex: "#256B4F",
                 tua: "Java from Zero to LAB211", soChuong: "22",
                 soBaiTap: "91", soTu: "26,124"),
        ]),
        NhomSach(tua: "The front end", moTa: "What the user actually touches.", sach: [
            Sach(vol: "01", file: "01-react-from-zero-to-production.html", mauHex: "#2B4C86",
                 tua: "React from Zero to Production", soChuong: "25",
                 soBaiTap: "160", soTu: "55,186"),
            Sach(vol: "05", file: "05-nextjs-from-zero-to-production.html", mauHex: "#3D5567",
                 tua: "Next.js from Zero to Production", soChuong: "20",
                 soBaiTap: "160", soTu: "26,506"),
            Sach(vol: "10", file: "10-tailwind-css-from-zero-to-production.html", mauHex: "#0E6E6B",
                 tua: "Tailwind CSS from Zero to Production", soChuong: "16",
                 soBaiTap: "160", soTu: "16,385"),
        ]),
        NhomSach(tua: "The back end", moTa: "Serving requests, and knowing who is asking.", sach: [
            Sach(vol: "07", file: "07-nodejs-and-express-from-zero-to-production.html", mauHex: "#256B4F",
                 tua: "Node.js and Express from Zero to Production", soChuong: "19",
                 soBaiTap: "160", soTu: "27,297"),
            Sach(vol: "13", file: "13-socketio-from-zero-to-production.html", mauHex: "#3B3E8C",
                 tua: "Socket.IO from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "21,383"),
            Sach(vol: "14", file: "14-authentication-from-zero-to-production.html", mauHex: "#8A5A14",
                 tua: "Authentication from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "24,992"),
        ]),
        NhomSach(tua: "Data", moTa: "Where the state lives, and how it is reached.", sach: [
            Sach(vol: "06", file: "06-postgresql-from-zero-to-production.html", mauHex: "#0E6E6B",
                 tua: "PostgreSQL from Zero to Production", soChuong: "25",
                 soBaiTap: "210", soTu: "36,792"),
            Sach(vol: "11", file: "11-prisma-from-zero-to-production.html", mauHex: "#6B3A6E",
                 tua: "Prisma from Zero to Production", soChuong: "16",
                 soBaiTap: "160", soTu: "21,104"),
            Sach(vol: "12", file: "12-redis-from-zero-to-production.html", mauHex: "#8E3B2A",
                 tua: "Redis from Zero to Production", soChuong: "16",
                 soBaiTap: "160", soTu: "23,241"),
            Sach(vol: "19", file: "19-object-storage-from-zero-to-production.html", mauHex: "#6B3A6E",
                 tua: "Object Storage from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "27,752"),
        ]),
        NhomSach(tua: "Infrastructure", moTa: "Getting it onto a machine that strangers can reach.", sach: [
            Sach(vol: "08", file: "08-docker-from-zero-to-production.html", mauHex: "#2B4C86",
                 tua: "Docker from Zero to Production", soChuong: "18",
                 soBaiTap: "160", soTu: "22,437"),
            Sach(vol: "15", file: "15-nginx-from-zero-to-production.html", mauHex: "#256B4F",
                 tua: "Nginx from Zero to Production", soChuong: "14",
                 soBaiTap: "140", soTu: "26,565"),
            Sach(vol: "16", file: "16-deploying-to-a-vps-from-zero-to-production.html", mauHex: "#3D5567",
                 tua: "Deploying to a VPS from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "21,973"),
            Sach(vol: "18", file: "18-github-actions-from-zero-to-production.html", mauHex: "#0E6E6B",
                 tua: "GitHub Actions from Zero to Production", soChuong: "13",
                 soBaiTap: "130", soTu: "33,139"),
            Sach(vol: "20", file: "20-domains-dns-and-tls-from-zero-to-production.html", mauHex: "#2B4C86",
                 tua: "Domains, DNS and TLS from Zero to Production", soChuong: "10",
                 soBaiTap: "100", soTu: "23,834"),
        ]),
        NhomSach(tua: "Running a product", moTa: "The parts that only matter once people rely on it.", sach: [
            Sach(vol: "21", file: "21-media-processing-from-zero-to-production.html", mauHex: "#8E3B2A",
                 tua: "Media Processing from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "26,459"),
            Sach(vol: "22", file: "22-observability-and-monitoring-from-zero-to-production.html", mauHex: "#3D5567",
                 tua: "Observability and Monitoring from Zero to Production", soChuong: "10",
                 soBaiTap: "100", soTu: "20,352"),
            Sach(vol: "23", file: "23-payment-integration-from-zero-to-production.html", mauHex: "#3B3E8C",
                 tua: "Payment Integration from Zero to Production", soChuong: "10",
                 soBaiTap: "100", soTu: "19,500"),
        ]),
    ]

    static var tatCa: [Sach] { nhom.flatMap(\.sach) }
}

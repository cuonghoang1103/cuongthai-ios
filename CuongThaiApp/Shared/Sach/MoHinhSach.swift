import SwiftUI

// ════════════════════════════════════════════════════════════════
// BỘ SÁCH CuongThai
//
// ⚠️ FILE NÀY SINH TỰ ĐỘNG — đừng sửa tay, chạy lại:
//
//     python3 scripts/sinh-mo-hinh-sach.py
//
// ⚠️ Danh sách CHÉP TỪ `frontend/src/app/books/booksData.ts`, KHÔNG tải động.
// Lý do: web không có manifest — `GET /books/index.json` và `/books/books.json`
// đều trả **200 nhưng là trang HTML của Next**, không phải JSON. Tin mã 200 mà
// không xem `content-type` là trúng đúng cái bẫy đó.
//
// ⚠️ Hệ quả: web thêm tập mới thì app KHÔNG tự thấy — phải chạy lại script.
// Đã xảy ra thật: web lên 41 tập, app còn nằm ở 25.
//
// Nội dung sách tải thật từ `https://cuongthai.com/books/<file>` (HTML tự
// chứa), bản dịch từ `/books/i18n/<slug>.vi.json`. Script chỉ giữ tập có file
// THẬT trên đĩa web, nên không sinh ra lối vào dẫn tới 404.

struct Sach: Identifiable, Hashable {
    let vol: String
    let file: String
    let mauHex: String
    let tua: String
    let soChuong: String
    let soBaiTap: String
    let soTu: String
    /// Tập tiếng Việt gốc không có (và không cần) bản dịch — bộ đọc ẩn luôn
    /// nút EN/VI cho chúng thay vì bày ra một nút bấm không làm gì.
    let coSongNgu: Bool

    var id: String { vol }
    /// Bỏ đuôi `.html` — dùng để tra file dịch và tên bản lưu trên máy.
    var slug: String { String(file.dropLast(5)) }
    var duongSach: URL? { URL(string: "https://cuongthai.com/books/\(file)") }
    var duongDich: URL? {
        coSongNgu ? URL(string: "https://cuongthai.com/books/i18n/\(slug).vi.json") : nil
    }
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
        ("41", "tập"),
        ("649", "chương"),
        ("5,503", "bài tập"),
        ("2,425", "đoạn mã"),
        ("1,468", "bảng"),
        ("1,469,374", "từ"),
    ]

    static let nhom: [NhomSach] = [
        NhomSach(tua: "Foundations", moTa: "The ground everything else stands on.", sach: [
            Sach(vol: "24", file: "24-the-terminal-from-zero-to-fluent.html", mauHex: "#256B4F",
                 tua: "The Terminal from Zero to Fluent", soChuong: "24",
                 soBaiTap: "179", soTu: "77,095", coSongNgu: true),
            Sach(vol: "17", file: "17-linux-and-bash-from-zero-to-production.html", mauHex: "#8A5A14",
                 tua: "Linux and Bash from Zero to Production", soChuong: "16",
                 soBaiTap: "175", soTu: "34,408", coSongNgu: true),
            Sach(vol: "25", file: "25-networking-from-zero-to-production.html", mauHex: "#1F5D7A",
                 tua: "Networking from Zero to Production", soChuong: "24",
                 soBaiTap: "182", soTu: "129,015", coSongNgu: true),
            Sach(vol: "09", file: "09-git-from-zero-to-confident.html", mauHex: "#8E3B2A",
                 tua: "Git from Zero to Confident", soChuong: "17",
                 soBaiTap: "160", soTu: "20,889", coSongNgu: true),
        ]),
        NhomSach(tua: "Languages", moTa: "The three languages the rest of the series is written in.", sach: [
            Sach(vol: "03", file: "03-javascript-from-zero-to-production.html", mauHex: "#8A5A14",
                 tua: "JavaScript from Zero to Production", soChuong: "17",
                 soBaiTap: "160", soTu: "17,605", coSongNgu: true),
            Sach(vol: "04", file: "04-typescript-from-zero-to-type-safe.html", mauHex: "#3B3E8C",
                 tua: "TypeScript from Zero to Type-Safe", soChuong: "20",
                 soBaiTap: "160", soTu: "29,747", coSongNgu: true),
            Sach(vol: "02", file: "02-java-from-zero-to-lab211.html", mauHex: "#256B4F",
                 tua: "Java from Zero to LAB211", soChuong: "22",
                 soBaiTap: "91", soTu: "26,124", coSongNgu: true),
        ]),
        NhomSach(tua: "The front end", moTa: "What the user actually touches.", sach: [
            Sach(vol: "01", file: "01-react-from-zero-to-production.html", mauHex: "#2B4C86",
                 tua: "React from Zero to Production", soChuong: "25",
                 soBaiTap: "160", soTu: "55,186", coSongNgu: true),
            Sach(vol: "05", file: "05-nextjs-from-zero-to-production.html", mauHex: "#3D5567",
                 tua: "Next.js from Zero to Production", soChuong: "20",
                 soBaiTap: "160", soTu: "26,506", coSongNgu: true),
            Sach(vol: "10", file: "10-tailwind-css-from-zero-to-production.html", mauHex: "#0E6E6B",
                 tua: "Tailwind CSS from Zero to Production", soChuong: "16",
                 soBaiTap: "160", soTu: "16,385", coSongNgu: true),
        ]),
        NhomSach(tua: "The back end", moTa: "Serving requests, and knowing who is asking.", sach: [
            Sach(vol: "07", file: "07-nodejs-and-express-from-zero-to-production.html", mauHex: "#256B4F",
                 tua: "Node.js and Express from Zero to Production", soChuong: "19",
                 soBaiTap: "160", soTu: "27,297", coSongNgu: true),
            Sach(vol: "13", file: "13-socketio-from-zero-to-production.html", mauHex: "#3B3E8C",
                 tua: "Socket.IO from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "21,383", coSongNgu: true),
            Sach(vol: "14", file: "14-authentication-from-zero-to-production.html", mauHex: "#8A5A14",
                 tua: "Authentication from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "24,992", coSongNgu: true),
        ]),
        NhomSach(tua: "Data", moTa: "Where the state lives, and how it is reached.", sach: [
            Sach(vol: "06", file: "06-postgresql-from-zero-to-production.html", mauHex: "#0E6E6B",
                 tua: "PostgreSQL from Zero to Production", soChuong: "25",
                 soBaiTap: "210", soTu: "36,792", coSongNgu: true),
            Sach(vol: "11", file: "11-prisma-from-zero-to-production.html", mauHex: "#6B3A6E",
                 tua: "Prisma from Zero to Production", soChuong: "16",
                 soBaiTap: "160", soTu: "21,104", coSongNgu: true),
            Sach(vol: "12", file: "12-redis-from-zero-to-production.html", mauHex: "#8E3B2A",
                 tua: "Redis from Zero to Production", soChuong: "16",
                 soBaiTap: "160", soTu: "23,241", coSongNgu: true),
            Sach(vol: "19", file: "19-object-storage-from-zero-to-production.html", mauHex: "#6B3A6E",
                 tua: "Object Storage from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "27,752", coSongNgu: true),
        ]),
        NhomSach(tua: "Infrastructure", moTa: "Getting it onto a machine that strangers can reach.", sach: [
            Sach(vol: "08", file: "08-docker-from-zero-to-production.html", mauHex: "#2B4C86",
                 tua: "Docker from Zero to Production", soChuong: "18",
                 soBaiTap: "160", soTu: "22,437", coSongNgu: true),
            Sach(vol: "15", file: "15-nginx-from-zero-to-production.html", mauHex: "#256B4F",
                 tua: "Nginx from Zero to Production", soChuong: "14",
                 soBaiTap: "140", soTu: "26,565", coSongNgu: true),
            Sach(vol: "16", file: "16-deploying-to-a-vps-from-zero-to-production.html", mauHex: "#3D5567",
                 tua: "Deploying to a VPS from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "21,973", coSongNgu: true),
            Sach(vol: "18", file: "18-github-actions-from-zero-to-production.html", mauHex: "#0E6E6B",
                 tua: "GitHub Actions from Zero to Production", soChuong: "13",
                 soBaiTap: "130", soTu: "33,139", coSongNgu: true),
            Sach(vol: "20", file: "20-domains-dns-and-tls-from-zero-to-production.html", mauHex: "#2B4C86",
                 tua: "Domains, DNS and TLS from Zero to Production", soChuong: "10",
                 soBaiTap: "100", soTu: "23,834", coSongNgu: true),
        ]),
        NhomSach(tua: "Running a product", moTa: "The parts that only matter once people rely on it.", sach: [
            Sach(vol: "21", file: "21-media-processing-from-zero-to-production.html", mauHex: "#8E3B2A",
                 tua: "Media Processing from Zero to Production", soChuong: "12",
                 soBaiTap: "120", soTu: "26,459", coSongNgu: true),
            Sach(vol: "22", file: "22-observability-and-monitoring-from-zero-to-production.html", mauHex: "#3D5567",
                 tua: "Observability and Monitoring from Zero to Production", soChuong: "10",
                 soBaiTap: "100", soTu: "20,352", coSongNgu: true),
            Sach(vol: "23", file: "23-payment-integration-from-zero-to-production.html", mauHex: "#3B3E8C",
                 tua: "Payment Integration from Zero to Production", soChuong: "10",
                 soBaiTap: "100", soTu: "19,500", coSongNgu: true),
        ]),
        NhomSach(tua: "Kỹ năng toàn diện", moTa: "Từ làm chủ bản thân đến hệ thống thực hành tổng hợp.", sach: [
            Sach(vol: "26", file: "26-lam-chu-ban-than.html", mauHex: "#6B3A6E",
                 tua: "Làm chủ bản thân", soChuong: "14",
                 soBaiTap: "112", soTu: "35,826", coSongNgu: false),
            Sach(vol: "27", file: "27-tu-duy-phan-bien-va-giai-quyet-van-de.html", mauHex: "#8E3B2A",
                 tua: "Tư duy phản biện và giải quyết vấn đề", soChuong: "17",
                 soBaiTap: "136", soTu: "44,022", coSongNgu: false),
            Sach(vol: "28", file: "28-hoc-cach-hoc-va-quan-ly-tri-thuc.html", mauHex: "#256B4F",
                 tua: "Học cách học và quản lý tri thức", soChuong: "13",
                 soBaiTap: "104", soTu: "26,774", coSongNgu: false),
            Sach(vol: "29", file: "29-quan-ly-thoi-gian-va-hieu-suat.html", mauHex: "#2B4C86",
                 tua: "Quản lý thời gian và hiệu suất", soChuong: "13",
                 soBaiTap: "104", soTu: "37,363", coSongNgu: false),
            Sach(vol: "30", file: "30-giao-tiep-chuyen-nghiep.html", mauHex: "#0E6E6B",
                 tua: "Giao tiếp chuyên nghiệp", soChuong: "15",
                 soBaiTap: "120", soTu: "42,561", coSongNgu: false),
            Sach(vol: "31", file: "31-lam-viec-nhom-va-xu-ly-mau-thuan.html", mauHex: "#8A5A14",
                 tua: "Làm việc nhóm và xử lý mâu thuẫn", soChuong: "12",
                 soBaiTap: "96", soTu: "30,480", coSongNgu: false),
            Sach(vol: "32", file: "32-lap-ke-hoach-va-quan-ly-du-an.html", mauHex: "#3B3E8C",
                 tua: "Lập kế hoạch và quản lý dự án", soChuong: "15",
                 soBaiTap: "120", soTu: "40,292", coSongNgu: false),
            Sach(vol: "33", file: "33-lanh-dao-va-quan-ly-con-nguoi.html", mauHex: "#6B3A6E",
                 tua: "Lãnh đạo và quản lý con người", soChuong: "17",
                 soBaiTap: "136", soTu: "49,163", coSongNgu: false),
            Sach(vol: "34", file: "34-lap-trinh-va-nang-luc-cong-nghe.html", mauHex: "#3D5567",
                 tua: "Lập trình và năng lực công nghệ", soChuong: "20",
                 soBaiTap: "160", soTu: "61,592", coSongNgu: false),
            Sach(vol: "35", file: "35-xay-dung-san-pham.html", mauHex: "#256B4F",
                 tua: "Xây dựng sản phẩm", soChuong: "14",
                 soBaiTap: "112", soTu: "38,917", coSongNgu: false),
            Sach(vol: "36", file: "36-marketing-ban-hang-va-go-to-market.html", mauHex: "#8E3B2A",
                 tua: "Marketing, bán hàng và đưa sản phẩm ra thị trường", soChuong: "22",
                 soBaiTap: "176", soTu: "65,821", coSongNgu: false),
            Sach(vol: "37", file: "37-su-nghiep-phong-van-va-freelance.html", mauHex: "#2B4C86",
                 tua: "Sự nghiệp, phỏng vấn và freelance", soChuong: "20",
                 soBaiTap: "160", soTu: "64,614", coSongNgu: false),
            Sach(vol: "38", file: "38-khoi-nghiep-va-van-hanh-doanh-nghiep.html", mauHex: "#8A5A14",
                 tua: "Khởi nghiệp và vận hành doanh nghiệp", soChuong: "16",
                 soBaiTap: "128", soTu: "53,929", coSongNgu: false),
            Sach(vol: "39", file: "39-ai-du-lieu-va-nang-luc-so.html", mauHex: "#3B3E8C",
                 tua: "AI, dữ liệu và năng lực số", soChuong: "10",
                 soBaiTap: "80", soTu: "26,326", coSongNgu: false),
            Sach(vol: "40", file: "40-tai-chinh-ca-nhan-va-ky-nang-doi-song.html", mauHex: "#0E6E6B",
                 tua: "Tài chính cá nhân và kỹ năng đời sống", soChuong: "12",
                 soBaiTap: "96", soTu: "38,530", coSongNgu: false),
            Sach(vol: "41", file: "41-he-thong-thuc-hanh-tong-hop.html", mauHex: "#3D5567",
                 tua: "Hệ thống thực hành tổng hợp", soChuong: "7",
                 soBaiTap: "56", soTu: "23,038", coSongNgu: false),
        ]),
    ]
}

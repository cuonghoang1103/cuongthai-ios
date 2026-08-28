import SwiftUI

// ════════════════════════════════════════════════════════════════
// MÀU VÀ TÊN NGẮN CỦA NGÔN NGỮ
//
// Chép từ `frontend/src/components/exp-hub/LanguageIcon.tsx` để app và web
// gọi cùng một thứ bằng cùng một màu. Đây là cái neo thị giác của cả danh
// sách: 51 mẩu mà tấm thẻ nào cũng chữ trắng trên nền xám thì không quét mắt
// được, còn một ô màu bên trái thì nhìn phát ra ngay đâu là `bash`, đâu là
// `java`.
// ════════════════════════════════════════════════════════════════

enum NgonNguMa {
    /// Vài mã ngôn ngữ khác với tên chuẩn — gộp về một mối trước khi tra.
    private static let doiTen: [String: String] = [
        "js": "javascript", "ts": "typescript", "py": "python", "golang": "go",
        "c++": "cpp", "node": "nodejs", "nodejs": "javascript", "reactjs": "react",
        "sh": "bash", "zsh": "bash", "shell": "bash", "console": "bash",
        "yml": "yaml", "md": "markdown", "docker": "dockerfile", "text": "text",
    ]

    private static let bangMau: [String: UInt32] = [
        "javascript": 0xF7DF1E, "typescript": 0x3178C6, "python": 0x3776AB,
        "java": 0xED8B00, "go": 0x00ADD8, "rust": 0xCE422B, "c": 0xA8B9CC,
        "cpp": 0x00599C, "csharp": 0x239120, "php": 0x777BB4, "ruby": 0xCC342D,
        "swift": 0xFA7343, "kotlin": 0x7F52FF, "scala": 0xDC322F, "sql": 0xE38C00,
        "bash": 0x4EAA25, "html": 0xE34F26, "css": 0x1572B6, "scss": 0xCC6699,
        "json": 0x8B8B8B, "yaml": 0xCB171E, "xml": 0xF16529, "markdown": 0x5B7FD4,
        "dockerfile": 0x2496ED, "vue": 0x4FC08D, "svelte": 0xFF3E00,
        "react": 0x61DAFB, "graphql": 0xE10098, "r": 0x276DC3, "dart": 0x0175C2,
        "lua": 0x4A63C8, "powershell": 0x4C7BD6, "terraform": 0x7B42BC,
        "text": 0x8A8A94,
    ]

    private static let tenNgan: [String: String] = [
        "javascript": "JS", "typescript": "TS", "python": "PY", "java": "JV",
        "go": "GO", "rust": "RS", "c": "C", "cpp": "C++", "csharp": "C#",
        "php": "PHP", "ruby": "RB", "swift": "SW", "kotlin": "KT", "scala": "SC",
        "sql": "SQL", "bash": "SH", "html": "HTML", "css": "CSS", "scss": "SCSS",
        "json": "JSON", "yaml": "YAML", "xml": "XML", "markdown": "MD",
        "dockerfile": "DOCK", "vue": "VUE", "svelte": "SVT", "react": "RCT",
        "graphql": "GQL", "r": "R", "dart": "DART", "lua": "LUA",
        "powershell": "PS", "terraform": "TF", "text": "TXT",
    ]

    private static func chuan(_ s: String?) -> String {
        let k = (s ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        return doiTen[k] ?? k
    }

    /// Màu thương hiệu của ngôn ngữ. Không biết thì trả màu trung tính chứ
    /// KHÔNG trả màu nhấn của app — để `bash` và một ngôn ngữ lạ nhìn giống
    /// nhau là mất luôn tác dụng của việc tô màu.
    static func mau(_ s: String?) -> Color {
        Color(hex: bangMau[chuan(s)] ?? 0x8A8A94)
    }

    /// Tên ngắn để nhét vừa ô 40pt. Ngôn ngữ lạ thì lấy 4 chữ cái đầu.
    static func nhan(_ s: String?) -> String {
        let k = chuan(s)
        if let t = tenNgan[k] { return t }
        // Không biết ngôn ngữ thì dùng ký hiệu mã, KHÔNG dùng "?" — dấu hỏi
        // trông như app lỗi chứ không như "mẩu này không khai ngôn ngữ".
        return k.isEmpty ? "{ }" : String(k.prefix(4)).uppercased()
    }
}

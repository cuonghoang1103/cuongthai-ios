#!/usr/bin/env python3
"""Sinh `MoHinhSach.swift` từ `booksData.ts` của web.

Web KHÔNG có manifest (`/books/index.json` trả 200 nhưng là trang HTML của
Next), nên danh sách sách phải chép cứng vào app. Script này thay cho việc
chép tay — chạy lại mỗi khi web thêm/sửa tập.

    python3 scripts/sinh-mo-hinh-sach.py [đường-dẫn-api-backend]
"""
import json, re, sys, pathlib

GOC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/Users/admin/Downloads/api-backend')
NGUON = GOC / 'frontend/src/app/books/booksData.ts'
DICH = pathlib.Path(__file__).resolve().parent.parent / 'CuongThaiApp/Shared/Sach/MoHinhSach.swift'
THUMUC_HTML = GOC / 'frontend/public/books'

s = NGUON.read_text()

def mang_sau(ten):
    """Cắt đúng mảng `export const <ten> ... = [ … ];` bằng cách đếm ngoặc."""
    i = s.find(f'export const {ten}')
    # ⚠️ KHÔNG dùng `s.index('[', i)`: nó vớ phải cặp `[]` trong khai kiểu
    # (`BookGroup[] = [`) rồi trả về một mảng RỖNG mà không báo lỗi gì.
    a = s.index('[', s.index('=', i))
    sau, trong_chuoi, dau = 0, None, False
    for k in range(a, len(s)):
        c = s[k]
        if trong_chuoi:
            if dau: dau = False
            elif c == '\\': dau = True
            elif c == trong_chuoi: trong_chuoi = None
            continue
        if c in '"\'': trong_chuoi = c
        elif c == '[': sau += 1
        elif c == ']':
            sau -= 1
            if sau == 0: return s[a:k+1]
    raise ValueError(ten)

# BOOK_GROUPS là JSON hợp lệ (khoá nháy kép) → đọc thẳng.
nhom = json.loads(mang_sau('BOOK_GROUPS'))

# SKILL_BOOKS viết kiểu TS (nháy đơn) → bóc bằng regex từng trường.
truong = lambda k, t: (re.search(rf"\b{k}:\s*'((?:[^'\\]|\\.)*)'", t) or [None, ''])[1]
ky_nang = []
for khoi in re.split(r'\n  \{', mang_sau('SKILL_BOOKS'))[1:]:
    v = truong('vol', khoi)
    if v:
        ky_nang.append({k: truong(k, khoi) for k in
                        ('vol', 'file', 'color', 'title', 'chapters', 'practice', 'words')})
if ky_nang:
    nhom.append({'title': 'Kỹ năng toàn diện',
                 'desc': 'Từ làm chủ bản thân đến hệ thống thực hành tổng hợp.',
                 'books': ky_nang})

thong_ke = json.loads(re.search(r'SERIES_STATS = (\{.*?\}) as const', s, re.S).group(1))

# Chỉ giữ tập nào THẬT SỰ có file — tránh dựng lối vào dẫn tới 404.
co_that = {p.name for p in THUMUC_HTML.glob('*.html')} if THUMUC_HTML.is_dir() else None
co_dich = {p.name for p in (THUMUC_HTML / 'i18n').glob('*.vi.json')} if THUMUC_HTML.is_dir() else set()
thieu = []
if co_that is not None:
    for g in nhom:
        giu = []
        for b in g['books']:
            (giu if b['file'] in co_that else thieu).append(b)
        g['books'] = giu
    nhom = [g for g in nhom if g['books']]

thoat = lambda t: t.replace('\\', '\\\\').replace('"', '\\"')
NHAN = [('volumes', 'tập'), ('chapters', 'chương'), ('practice', 'bài tập'),
        ('listings', 'đoạn mã'), ('tables', 'bảng'), ('words', 'từ')]

ra = ['''import SwiftUI

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
    var duongSach: URL? { URL(string: "https://cuongthai.com/books/\\(file)") }
    var duongDich: URL? {
        coSongNgu ? URL(string: "https://cuongthai.com/books/i18n/\\(slug).vi.json") : nil
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
    static let thongKe: [(String, String)] = [''']
for k, nhan in NHAN:
    if k in thong_ke:
        ra.append(f'        ("{thong_ke[k]}", "{nhan}"),')
ra.append('    ]\n')
ra.append('    static let nhom: [NhomSach] = [')
tong = 0
for g in nhom:
    ra.append(f'        NhomSach(tua: "{thoat(g["title"])}", moTa: "{thoat(g["desc"])}", sach: [')
    for b in g['books']:
        tong += 1
        sn = 'true' if f'{b["file"][:-5]}.vi.json' in co_dich else 'false'
        ra.append(f'            Sach(vol: "{b["vol"]}", file: "{b["file"]}", mauHex: "{b["color"]}",')
        ra.append(f'                 tua: "{thoat(b["title"])}", soChuong: "{b["chapters"]}",')
        ra.append(f'                 soBaiTap: "{b["practice"]}", soTu: "{b["words"]}", coSongNgu: {sn}),')
    ra.append('        ]),')
ra.append('    ]\n}')

DICH.write_text('\n'.join(ra) + '\n')
print(f"✔ {DICH.name}: {len(nhom)} nhóm · {tong} tập · {sum(1 for g in nhom for b in g['books'] if f'{b['file'][:-5]}.vi.json' in co_dich)} tập có bản dịch")
if thieu:
    print(f"⚠️ BỎ QUA {len(thieu)} tập khai trong booksData.ts mà KHÔNG có file html:")
    for b in thieu: print(f"     {b['vol']} · {b['file']}")

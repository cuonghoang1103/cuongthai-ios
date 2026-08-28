#!/usr/bin/env python3
"""Sinh `KhoThuatToan.swift` từ `catalog.ts` của web (80 thuật toán).

    python3 scripts/sinh-thuat-toan.py

⚠️ Mỗi thuật toán là một đoạn mã JS chạy được. Chép bằng máy để không sai một
ký tự nào — sai một dấu là thuật toán ra kết quả khác web mà không báo lỗi.
"""
import re, pathlib, sys, json

GOC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/Users/admin/Downloads/api-backend')
NGUON = GOC / 'frontend/src/components/algorithms/catalog.ts'
DICH = pathlib.Path(__file__).resolve().parent.parent / 'CuongThaiApp/Shared/ThuatToan/KhoThuatToan.swift'

s = NGUON.read_text()

# ── Mọi `const <tên> = \`…\`;` là một đoạn mã ──
ma = {}
for m in re.finditer(r'^const (\w+) = `(.*?)`;\s*$', s, re.S | re.M):
    ma[m.group(1)] = m.group(2).replace('\\`', '`').replace('\\$', '$').replace('\\\\', '\\')

# ⚠️ 8/82 đoạn dùng NỘI SUY TEMPLATE (`${GRAPH_SETUP}`, `${MAZE_SETUP}`).
# TypeScript thay giá trị lúc nạp module; chép nguyên chữ `${GRAPH_SETUP}` sang
# app thì JS ném "Unexpected token '{'" — và chỉ ở 8 thuật toán đó, nên chạy
# thử Bubble Sort thấy ổn là tưởng xong. Phải thay bằng tay ở đây.
def noi_suy(t, sau=0):
    if sau > 5: raise RuntimeError('nội suy lồng quá sâu — có vòng lặp?')
    def thay(m):
        ten = m.group(1)
        if ten not in ma: raise RuntimeError(f'không có `{ten}` để nội suy')
        return noi_suy(ma[ten], sau + 1)
    return re.sub(r'\$\{(\w+)\}', thay, t)

ma = {k: noi_suy(v) for k, v in ma.items()}

# ── Danh sách CATALOG ──
i = s.index('export const CATALOG')
arr = s[s.index('[', i):]
arr = arr[:arr.index('\n];') + 3]
# ⚠️ Trường dùng CẢ nháy đơn LẪN nháy kép: 6/80 mục có dấu lược trong tên
# ("Dijkstra's Shortest Path") nên TS phải đổi sang nháy kép. Regex chỉ nhận
# nháy đơn thì bỏ sót đúng 6 mục đó — và bỏ sót IM LẶNG nếu không có chốt đếm
# ở dưới.
CHUOI = r"""(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")"""
MAU = (r"\{\s*id:\s*" + CHUOI + r",\s*name:\s*" + CHUOI +
       r",\s*category:\s*" + CHUOI + r",\s*description:\s*" + CHUOI +
       r",\s*code:\s*(\w+)\s*\}")

def lay(m, n):
    """Nhóm thứ n (1-based) chiếm hai ô bắt: nháy đơn hoặc nháy kép."""
    return m.group(n * 2 - 1) if m.group(n * 2 - 1) is not None else m.group(n * 2)

muc = []
for m in re.finditer(MAU, arr):
    ten_ma = m.group(9)
    ma_id = lay(m, 1)
    if ten_ma not in ma:
        print(f"  ⚠️ BỎ QUA {ma_id}: không tìm thấy mã `{ten_ma}`")
        continue
    muc.append({
        'id': ma_id, 'name': lay(m, 2), 'category': lay(m, 3),
        'description': (lay(m, 4) or '').replace("\\'", "'").replace('\\"', '"'),
        'code': ma[ten_ma],
    })

# Chốt: không đoạn nào còn nội suy chưa thay.
for x in muc:
    con = re.findall(r'\$\{(\w+)\}', x['code'])
    assert not con, f"{x['id']} còn nội suy chưa thay: {con}"

khai = len(re.findall(r"\{\s*id:\s*['\"]", arr))
assert len(muc) == khai, f"khai {khai} mục nhưng chỉ bóc được {len(muc)} — regex hụt"

def thoat(t):
    return t.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t')

nhom = []
for x in muc:
    if x['category'] not in nhom: nhom.append(x['category'])

ra = ['''import Foundation

// ════════════════════════════════════════════════════════════════
// KHO THUẬT TOÁN
//
// ⚠️ FILE NÀY SINH TỰ ĐỘNG từ `frontend/src/components/algorithms/catalog.ts`.
// Đừng sửa tay, chạy lại:
//
//     python3 scripts/sinh-thuat-toan.py
//
// Mỗi mục mang theo ĐOẠN MÃ JS chạy được — người dùng sửa rồi chạy lại được,
// đúng như trên web. Vì thế phải chép bằng máy: sai một ký tự là thuật toán
// cho kết quả khác web mà không có lỗi nào để thấy.
// ════════════════════════════════════════════════════════════════

struct ThuatToan: Identifiable, Hashable {
    let id: String
    let ten: String
    let nhom: String
    let moTa: String
    let ma: String
}

enum KhoThuatToan {
    static let nhom: [String] = [''']
for n in nhom:
    ra.append(f'        "{thoat(n)}",')
ra.append('    ]\n')
ra.append('    static let tatCa: [ThuatToan] = [')
for x in muc:
    ra.append(f'        ThuatToan(id: "{thoat(x["id"])}", ten: "{thoat(x["name"])}",')
    ra.append(f'                  nhom: "{thoat(x["category"])}",')
    ra.append(f'                  moTa: "{thoat(x["description"])}",')
    ra.append(f'                  ma: "{thoat(x["code"])}"),')
ra.append('    ]')
ra.append('}')

DICH.write_text('\n'.join(ra) + '\n')
print(f"✔ {DICH.name}: {len(muc)} thuật toán · {len(nhom)} nhóm · {DICH.stat().st_size // 1024} KB")

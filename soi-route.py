"""Đối chiếu MỌI endpoint app iOS gọi với route có thật trong backend.

    python3 soi-route.py [đường-dẫn-kho-backend]      # mặc định ../api-backend

Vì sao cần: gõ sai một chữ trong đường dẫn, hay khai nhầm phương thức HTTP,
thì `swiftc` mù hoàn toàn — chạy lên chỉ là một màn hình im lặng. Ngày
22/08/2026 phép rà này tìm ra `reactPost` gửi PATCH trong khi backend khai
POST, tức bộ chọn cảm xúc CHƯA TỪNG hoạt động.

⚠️ Nó TỰ KIỂM trước: 8 route đã đo sống phải được nhận ra, thiếu là DỪNG chứ
không báo cáo. Bản đầu báo 90 endpoint "thiếu" mà sai cả 90.
"""
import re, pathlib, sys, os

BE = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                  else pathlib.Path(__file__).resolve().parent.parent / 'api-backend')
IOS = pathlib.Path(__file__).resolve().parent / 'CuongThaiApp/Shared/Network/APIEndpoint.swift'
if not (BE / 'src/index.ts').exists():
    sys.exit(f"Không thấy {BE}/src/index.ts — truyền đường dẫn kho backend làm tham số.")
idx = (BE / 'src/index.ts').read_text()
var2file, mod2file = {}, {}
for m in re.finditer(r"const (\w+)\s*=\s*\(await import\(path\.join\(__dirname,\s*'routes',\s*'([\w.]+)\.js'\)\)\)\.\w+", idx):
    var2file[m.group(1)] = f"src/routes/{m.group(2)}.ts"
for m in re.finditer(r"const (\w+)\s*=\s*\(?await import\(path\.join\(__dirname,\s*'routes',\s*'([\w.]+)\.js'\)\)\)?\s*;", idx):
    mod2file[m.group(1)] = f"src/routes/{m.group(2)}.ts"
for m in re.finditer(r"const (\w+)\s*=\s*(\w+)\.(\w+)\s*;", idx):
    if m.group(2) in mod2file: var2file[m.group(1)] = mod2file[m.group(2)]
# destructuring, CÓ HOẶC KHÔNG bọc ngoặc, có hoặc không đổi tên
for m in re.finditer(r"const \{([^}]*)\}\s*=\s*\(?await import\(path\.join\(__dirname,\s*'routes',\s*'([\w.]+)\.js'\)\)", idx):
    for part in m.group(1).split(','):
        nm = part.split(':')[-1].strip()
        if nm: var2file[nm] = f"src/routes/{m.group(2)}.ts"

mounts = set()
for m in re.finditer(r"app\.use\('(/api/v1[^']*)'\s*,([^;]*)\);", idx):
    for v in re.findall(r'\b([A-Za-z_]\w*)\b', m.group(2)):
        if v in var2file: mounts.add((m.group(1), v))

RX = re.compile(r"(\w*[Rr]outer)\.(get|post|put|patch|delete)\(\s*'([^']*)'", re.S)
full = set()
for prefix, var in mounts:
    try: src = pathlib.Path(BE / var2file[var]).read_text()
    except Exception: continue
    for m in RX.finditer(src):
        p = (prefix.rstrip('/') + '/' + m.group(3).lstrip('/')).replace('//','/').rstrip('/') or prefix
        full.add((m.group(2).upper(), p))

def norm(p): return tuple('*' if s.startswith(':') else s for s in p.strip('/').split('/'))
be = {}
for m, p in full: be.setdefault(m, set()).add(norm(p))
def khop(meth, p):
    s = norm(p)
    return any(len(c)==len(s) and all(a=='*' or b=='*' or a==b for a,b in zip(c,s)) for c in be.get(meth,()))

# TỰ KIỂM: 8 route đã ĐO SỐNG hoặc chắc chắn đang chạy
tu_kiem = [('GET','/api/v1/my-language/notebook/x'), ('POST','/api/v1/my-language/notebook/entries'),
           ('GET','/api/v1/exams/attempts/1'), ('POST','/api/v1/social/posts'),
           ('POST','/api/v1/exams/questions/1/bookmark'), ('GET','/api/v1/exams/attempts/mine'),
           ('GET','/api/v1/messages/threads'), ('POST','/api/v1/auth/login')]
xau = [x for x in tu_kiem if not khop(*x)]
print(f"TỰ KIỂM bộ kiểm: {len(tu_kiem)-len(xau)}/{len(tu_kiem)}")
for m,p in xau: print(f"  ✖ {m} {p}")
if xau: sys.exit("→ bộ kiểm chưa đáng tin, KHÔNG kết luận")

src = IOS.read_text()
meth_of, cur = {}, []
for line in re.search(r'var method: String \{(.*?)\n    \}', src, re.S).group(1).splitlines():
    cur += re.findall(r'\.(\w+)', line.split('return')[0])
    r = re.search(r'return "(\w+)"', line)
    if r:
        for n in cur: meth_of[n] = r.group(1)
        cur = []
thieu, tong = [], 0
for m in re.finditer(r'case \.(\w+)[^:]*: return "(/api/v1/[^"]*)"', src):
    name, p = m.group(1), re.sub(r'\\\([^)]*\)', '*', m.group(2))
    tong += 1
    if not khop(meth_of.get(name,'GET'), p): thieu.append((meth_of.get(name,'GET'), p, name))
print(f"\n{len(full)} route backend · {tong} endpoint iOS")
if thieu:
    print(f"✖ {len(thieu)} endpoint KHÔNG khớp route nào:")
    for m,p,n in thieu: print(f"   {m:6} {p:48} (.{n})")
else:
    print("✔ TẤT CẢ endpoint iOS đều khớp một route backend có thật")

#!/usr/bin/env python3
"""Sinh `DongCoMoPhong.swift` — gói 62 kịch bản /simulation của web vào app.

    python3 scripts/sinh-mo-phong.py

⚠️ Vì sao gói JS thay vì viết lại bằng Swift: mỗi kịch bản là một hàm `build()`
THUẦN sinh ra danh sách bước từ tuỳ chọn người dùng (method, status, hit/miss…).
27.576 dòng logic giảng dạy nằm trong 62 hàm đó. Viết lại bằng Swift là dịch
tay 27k dòng, và mỗi kịch bản mới trên web lại phải dịch lần hai. Giao diện —
sân khấu, gói tin chạy, thanh tua, bảng thông tin — vẫn SwiftUI gốc.

Cách gói: `tsc --module amd --outFile` (có sẵn trong `frontend/node_modules`,
không cài thêm gì) + một bộ nạp AMD ~20 dòng. `lucide-react` được thay bằng
module giả trả về TÊN biểu tượng — iOS không cần React, chỉ cần tên để bắc
sang SF Symbols.
"""
import json, pathlib, shutil, subprocess, sys, tempfile

GOC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/Users/admin/Downloads/api-backend')
NGUON = GOC / 'frontend/src/components/simulation'
TSC = GOC / 'frontend/node_modules/.bin/tsc'
DICH = pathlib.Path(__file__).resolve().parent.parent / 'CuongThaiApp/Shared/MoPhong/DongCoMoPhong.swift'
DICH.parent.mkdir(parents=True, exist_ok=True)

assert TSC.exists(), f"không thấy tsc ở {TSC} — chạy `npm i` trong frontend"

tam = pathlib.Path(tempfile.mkdtemp(prefix='mophong-'))
try:
    shutil.copytree(NGUON, tam / 'src')
    (tam / 'shim/lucide-react').mkdir(parents=True)
    (tam / 'shim/lucide-react/index.d.ts').write_text(
        "export type LucideIcon = string;\ndeclare const _p: any;\nexport = _p;\n")
    (tam / 'tsconfig.json').write_text(json.dumps({
        "compilerOptions": {
            "target": "ES2017", "module": "amd", "outFile": "goi.js",
            "moduleResolution": "classic", "strict": False, "skipLibCheck": True,
            "noEmitOnError": False, "jsx": "preserve", "removeComments": True,
        },
        "files": ["src/scenarios/index.ts"],
    }))
    # tsc báo lỗi kiểu (thiếu React, lucide…) nhưng VẪN sinh mã — đó là chủ ý:
    # ta chỉ cần phần logic chạy được, không cần cây kiểu đầy đủ.
    subprocess.run([str(TSC), '-p', '.'], cwd=tam, capture_output=True, text=True)
    goi = (tam / 'goi.js')
    assert goi.exists(), "tsc không sinh ra goi.js"
    js_goi = goi.read_text()
finally:
    shutil.rmtree(tam, ignore_errors=True)

so_mod = js_goi.count('\ndefine("') + js_goi.count('define("', 0, 20)
assert 'exports.SCENARIOS' in js_goi, "gói thiếu SCENARIOS"

LOADER = r'''
// ── Bộ nạp AMD tí hon ───────────────────────────────────────────
// `tsc --module amd --outFile` sinh ra `define(tên, [phụ thuộc], factory)`.
// Trình duyệt cần RequireJS; ở đây chừng này là đủ.
var __mods = {}, __defs = {};
function define(name, deps, factory) { __defs[name] = { deps: deps, factory: factory }; }
define.amd = true;
function __require(name) {
  // `lucide-react` chỉ dùng để lấy BIỂU TƯỢNG. iOS không có React và cũng
  // không cần — chỉ cần TÊN để bắc sang SF Symbols.
  if (name === 'lucide-react') {
    return new Proxy({}, { get: function (_, k) { return String(k); } });
  }
  if (__mods[name]) return __mods[name];
  var d = __defs[name];
  if (!d) throw new Error('Thiếu module: ' + name);
  var ex = {};
  __mods[name] = ex;                    // đặt TRƯỚC để chịu được vòng tham chiếu
  var args = d.deps.map(function (n) {
    if (n === 'exports') return ex;
    if (n === 'require') return __require;
    return __require(n);
  });
  d.factory.apply(null, args);
  return ex;
}
'''

CUA = r'''
// ── Cửa Swift gọi vào ───────────────────────────────────────────
var __M = null;
function __nap() { if (!__M) __M = __require('scenarios/index'); return __M; }

/** Danh sách nhóm + kịch bản (không kèm `build`, vì hàm không qua JSON được). */
function ctsDsKichBan() {
  var M = __nap();
  var ks = (M.SCENARIOS || []).map(function (s) {
    return {
      id: s.id, name: s.name, tagline: s.tagline, icon: s.icon, accent: s.accent,
      group: s.group, lesson: s.lesson, nodes: s.nodes, edges: s.edges,
      options: s.options || [],
    };
  });
  return JSON.stringify({ groups: M.SCENARIO_GROUPS || [], scenarios: ks });
}

/** Dựng bước + panel cho một kịch bản với bộ tuỳ chọn đã chọn.
 *
 * ⚠️ `panels` có thể là MẢNG hoặc HÀM `(opts) => PanelSpec[]` — 42/62 kịch bản
 * dùng panel thay cho sơ đồ mạng, và nhiều cái đổi panel theo tuỳ chọn. Coi nó
 * luôn là mảng thì `for...of` ném "function is not iterable". */
function ctsDungBuoc(id, opts) {
  var M = __nap();
  var s = (M.SCENARIOS || []).filter(function (x) { return x.id === id; })[0];
  if (!s) return JSON.stringify({ ok: false, error: 'Không có kịch bản ' + id });
  var o = opts || {};
  try {
    var b = s.build(o) || [];
    var pn = typeof s.panels === 'function' ? (s.panels(o) || []) : (s.panels || []);
    return JSON.stringify({ ok: true, steps: b, panels: pn });
  } catch (e) {
    return JSON.stringify({ ok: false, error: (e && e.message) || String(e) });
  }
}
'''

js = LOADER + "\n" + js_goi + "\n" + CUA
assert '"""#' not in js, "JS chứa dấu đóng chuỗi thô — phải tăng số dấu #"

DAU = '#' + '"' * 3
CUOI = '"' * 3 + '#'
DICH.write_text(f'''import Foundation

// ════════════════════════════════════════════════════════════════
// ĐỘNG CƠ MÔ PHỎNG — gói nguyên 62 kịch bản của web
//
// ⚠️ FILE NÀY SINH TỰ ĐỘNG. Đừng sửa tay, chạy lại:
//
//     python3 scripts/sinh-mo-phong.py
//
// Mỗi kịch bản là một hàm `build()` THUẦN sinh ra danh sách bước từ tuỳ chọn
// người dùng. 27.576 dòng logic giảng dạy nằm trong 62 hàm đó — dịch tay sang
// Swift là làm lại từ đầu, và mỗi kịch bản mới trên web lại phải dịch lần hai.
// Giao diện (sân khấu, gói tin chạy, thanh tua, bảng thông tin) vẫn SwiftUI gốc.
// ════════════════════════════════════════════════════════════════

enum DongCoMoPhong {{
    static let nguon = {DAU}
{js}
{CUOI}
}}
''')
print(f"✔ {DICH.name}: {len(js) // 1024} KB JS · {so_mod} module")

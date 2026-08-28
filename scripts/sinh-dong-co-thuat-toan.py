#!/usr/bin/env python3
"""Sinh `DongCoJS.swift` từ `engine.ts` của web.

⚠️ TRÍCH bằng máy, KHÔNG chép tay. `WORKER_SRC` dài ~130 dòng đặc ký tự thoát;
chép tay là chắc chắn sai một dấu, mà sai một dấu thì thuật toán chạy ra kết
quả khác web chứ không báo lỗi.

`buildFrames` thì phải chuyển từ TypeScript sang JS — chỉ là gỡ chú thích kiểu,
không đổi một dòng logic nào.

    python3 scripts/sinh-dong-co-thuat-toan.py
"""
import re, pathlib, sys

GOC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/Users/admin/Downloads/api-backend')
NGUON = GOC / 'frontend/src/components/algorithms/engine.ts'
DICH = pathlib.Path(__file__).resolve().parent.parent / 'CuongThaiApp/Shared/ThuatToan/DongCoJS.swift'

s = NGUON.read_text()

# ── 1. WORKER_SRC ────────────────────────────────────────────────
i = s.index('const WORKER_SRC = `')
j = s.index('`;', i)
worker = s[i + len('const WORKER_SRC = `'):j]
# Trong TS nó là template literal: `\\d` nghĩa là `\d`, `\\n` nghĩa là `\n`.
worker = worker.replace('\\\\', '\\').replace('\\`', '`').replace('\\$', '$')

# Bỏ lớp Worker: đổi `self.onmessage = function (e) {...}` thành một hàm thường.
worker = worker.replace('self.onmessage = function (e) {', 'function ctsChay(e) {', 1)
worker = worker.replace(
    "self.postMessage({ ok: true, commands: commands });",
    "return { ok: true, commands: commands };")
worker = worker.replace(
    "} catch (err) { self.postMessage({ ok: false, error: (err && err.message) ? err.message : String(err) }); }",
    "} catch (err) { return { ok: false, error: (err && err.message) ? err.message : String(err), commands: [] }; }")
assert 'self.postMessage' not in worker, "còn sót postMessage"
assert 'ctsChay' in worker, "không thay được vỏ worker"

# ── 2. buildFrames: TS → JS ──────────────────────────────────────
i = s.index('export function buildFrames(')
build = s[i:]
build = build[:build.index('\n}\n') + 3]
build = build.replace('export function buildFrames(commands: Cmd[]): { metas: TracerMeta[]; frames: Frame[]; lines: number[] } {',
                      'function ctsDungKhung(commands) {')
# Gỡ chú thích kiểu — chỉ ở khai báo biến và tham số, không đụng logic.
for a, b in [
    ('const metas: TracerMeta[] = []', 'const metas = []'),
    ('const live: Record<number, TracerState> = {}', 'const live = {}'),
    ('const frames: Frame[] = []', 'const frames = []'),
    ('const lines: number[] = []', 'const lines = []'),
    ('const snapshot = (): Frame => { const f: Frame = {};', 'const snapshot = () => { const f = {};'),
    ('(arr: number[], from: number, to: number)', '(arr, from, to)'),
    ('(g: GraphState, id: string)', '(g, id)'),
    ('(g: GraphState, s: string, t: string)', '(g, s, t)'),
    ('(n) => n.id === id', '(n) => n.id === id'),
]:
    build = build.replace(a, b)
build = re.sub(r'\(([a-z]) \) =>', r'(\1) =>', build)
assert ': TracerMeta' not in build and ': Frame[]' not in build, "còn chú thích kiểu"

# `cloneState` là hàm phụ, phải mang theo.
k = s.index('function cloneState(')
clone = s[k:]
clone = clone[:clone.index('\n}\n') + 3]
clone = clone.replace('function cloneState(s: TracerState): TracerState {', 'function cloneState(s) {')
clone = re.sub(r'as [A-Za-z0-9_<>\[\]]+', '', clone)

js = worker + "\n" + clone + "\n" + build + """
// Cửa duy nhất Swift gọi vào. Trả về SỐ khung, còn khung thì lấy từng cái một
// qua `ctsKhung(i)` — dựng cả mảng khung thành JSON là hàng chục MB với thuật
// toán nhiều bước, mà mỗi lúc chỉ vẽ đúng một khung.
var CTS = null;
function ctsNap(code) {
  var r = ctsChay({ data: { code: code } });
  if (!r.ok) return JSON.stringify({ ok: false, error: r.error });
  var b = ctsDungKhung(r.commands);
  CTS = b;
  return JSON.stringify({ ok: true, soKhung: b.frames.length, metas: b.metas, lines: b.lines });
}
function ctsKhung(i) {
  if (!CTS || i < 0 || i >= CTS.frames.length) return '{}';
  return JSON.stringify(CTS.frames[i]);
}
"""

# ⚠️ Dùng chuỗi THÔ NHIỀU DÒNG của Swift (#""" … """#): JS có xuống dòng, dấu
# nháy kép và rất nhiều dấu chéo ngược (regex `\\d`). Nhét vào chuỗi một dòng
# thì phải thoát cả ba, và bản đầu tôi QUÊN thoát xuống dòng ⇒ "unterminated
# string literal", 12 lỗi biên dịch liền. Chuỗi thô không cần thoát gì.
assert '"""#' not in js, "JS chứa dấu đóng chuỗi thô — phải tăng số dấu #"

DAU = '#' + '"' * 3
CUOI = '"' * 3 + '#'

ra = f"""import Foundation

// ════════════════════════════════════════════════════════════════
// ĐỘNG CƠ THUẬT TOÁN — chạy nguyên mã JS của web
//
// ⚠️ FILE NÀY SINH TỰ ĐỘNG từ `frontend/src/components/algorithms/engine.ts`.
// Đừng sửa tay, chạy lại:
//
//     python3 scripts/sinh-dong-co-thuat-toan.py
//
// Vì sao chạy JS thay vì viết lại bằng Swift: 80 thuật toán trong `catalog.ts`
// là 80 đoạn mã JS, và người dùng SỬA ĐƯỢC chúng rồi chạy lại. Viết lại bằng
// Swift là mất luôn tính năng đó, và mỗi thuật toán mới trên web lại phải
// dịch tay lần hai. JavaScriptCore có sẵn trên iOS, không thêm phụ thuộc nào.
//
// Ngữ nghĩa tracer và `buildFrames` lấy NGUYÊN từ web (trích bằng máy, không
// chép tay), nên từng khung khớp đúng với trình duyệt.
// ════════════════════════════════════════════════════════════════

enum DongCoJS {{
    static let nguon = {DAU}
{js}
{CUOI}
}}
"""
DICH.write_text(ra)
print(f"✔ {DICH.name}: {len(js)} ký tự JS")

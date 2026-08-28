import Foundation
import JavaScriptCore

// ════════════════════════════════════════════════════════════════
// MÁY MÔ PHỎNG
//
// Chạy `build(opts)` và `panels(opts)` của kịch bản trong `JSContext`, rồi
// PHÁT LẠI danh sách `ops` để suy ra trạng thái panel tại từng bước.
//
// ⚠️ Trạng thái tại bước `i` phải suy ra bằng cách phát lại ops 0..i, KHÔNG
// được sửa dần theo chiều tiến. Người dùng kéo thanh tua lùi lại là chuyện
// thường; sửa dần thì lùi xong trạng thái sai mà không có gì báo.
// ════════════════════════════════════════════════════════════════

/// Trạng thái một panel sau khi phát lại tới bước hiện tại.
struct TrangThaiPanel {
    /// Làn → danh sách mục. Panel một danh sách dùng làn `"_"` (MAIN_LANE).
    var lan: [String: [MucPanel]] = [:]
    /// Làn/hàng đang được chiếu sáng.
    var dangSang: String?
    /// Dòng mã đang chạy.
    var dong: [Int] = []
    /// Đồng hồ / cột biểu đồ: khoá → (giá trị, nhãn, sắc thái).
    var giaTri: [String: (Double, String?, String?)] = [:]
    /// Biểu đồ đường: khoá → danh sách điểm.
    var diem: [String: [(Double, Double)]] = [:]
}

@MainActor
final class MayMoPhong: ObservableObject {
    @Published private(set) var nhom: [NhomMoPhong] = []
    @Published private(set) var kichBan: [KichBan] = []
    @Published private(set) var buoc: [BuocMP] = []
    @Published private(set) var panel: [PanelMP] = []
    @Published private(set) var loi: String?
    @Published private(set) var dangTai = true

    private let ctx: JSContext = {
        let c = JSContext()!
        c.exceptionHandler = { _, e in NhatKy.sach.error("JS mô phỏng: \(e?.toString() ?? "?")") }
        c.evaluateScript(DongCoMoPhong.nguon)
        return c
    }()

    /// Nạp danh mục. Gọi một lần cho cả vòng đời màn hình.
    func napDanhMuc() {
        guard kichBan.isEmpty else { dangTai = false; return }
        dangTai = true; defer { dangTai = false }
        guard let r = ctx.objectForKeyedSubscript("ctsDsKichBan")?.call(withArguments: []),
              let chu = r.toString(), let d = chu.data(using: .utf8) else {
            loi = T("Không nạp được danh sách kịch bản."); return
        }
        struct Goi: Decodable { let groups: [NhomMoPhong]?; let scenarios: [KichBan]? }
        guard let g = try? JSONDecoder().decode(Goi.self, from: d) else {
            loi = T("Danh sách kịch bản không đọc được."); return
        }
        nhom = g.groups ?? []
        kichBan = g.scenarios ?? []
        loi = kichBan.isEmpty ? T("Chưa có kịch bản nào.") : nil
    }

    /// Dựng bước + panel cho một kịch bản với bộ tuỳ chọn đã chọn.
    func dung(_ id: String, tuyChon: [String: String]) {
        buoc = []; panel = []; loi = nil
        guard let r = ctx.objectForKeyedSubscript("ctsDungBuoc")?
                .call(withArguments: [id, tuyChon]),
              let chu = r.toString(), let d = chu.data(using: .utf8) else {
            loi = T("Không dựng được kịch bản."); return
        }
        struct Goi: Decodable {
            let ok: Bool; let error: String?
            let steps: [BuocMP]?; let panels: [PanelMP]?
        }
        guard let g = try? JSONDecoder().decode(Goi.self, from: d) else {
            loi = T("Kết quả dựng không đọc được."); return
        }
        guard g.ok else { loi = g.error ?? T("Kịch bản lỗi."); return }
        buoc = g.steps ?? []
        panel = g.panels ?? []
    }

    /// Trạng thái mọi panel sau khi phát lại ops từ bước 0 tới `toi`.
    func trangThai(toi: Int) -> [String: TrangThaiPanel] {
        var ra: [String: TrangThaiPanel] = [:]
        for p in panel { ra[p.id] = TrangThaiPanel() }
        // ⚠️ `0...min(toi, buoc.count - 1)` VỠ khi chưa có bước nào:
        // `min(0, -1)` = -1 ⇒ `0...(-1)` là khoảng không hợp lệ và Swift huỷ
        // tiến trình ngay. Và trạng thái này CÓ thật: giao diện dựng lần đầu
        // TRƯỚC khi `.task` kịp gọi `dung()`. Dùng `..<` với cận trên đã kẹp.
        let het = min(toi + 1, buoc.count)
        guard het > 0 else { return ra }
        for i in 0..<het {
            for o in buoc[i].cacOps {
                var t = ra[o.p] ?? TrangThaiPanel()
                let lan = o.lane ?? "_"
                switch o.op {
                case "push":
                    t.lan[lan, default: []].append(contentsOf: o.item ?? [])
                case "pop":
                    // Bỏ khỏi CUỐI làn — ngăn xếp trả về.
                    let k = max(0, (t.lan[lan]?.count ?? 0) - (o.n ?? 1))
                    t.lan[lan] = Array((t.lan[lan] ?? []).prefix(k))
                case "shift":
                    // Bỏ khỏi ĐẦU làn — hàng đợi được phục vụ (FIFO).
                    t.lan[lan] = Array((t.lan[lan] ?? []).dropFirst(o.n ?? 1))
                case "clear":
                    if o.lane == nil { t.lan.removeAll() } else { t.lan[lan] = [] }
                case "tone":
                    // Đổi sắc thái/nhãn phụ của một mục ĐANG CÓ, theo `key`.
                    for (l, ds) in t.lan {
                        t.lan[l] = ds.map { m in
                            guard m.idOn == o.key else { return m }
                            return MucPanel(id: m.id, label: m.label,
                                            sub: o.sub ?? m.sub, badge: o.badge ?? m.badge,
                                            tone: o.tone ?? m.tone, cells: m.cells, depth: m.depth)
                        }
                    }
                case "active":
                    t.dangSang = o.valueChu
                case "lines":
                    t.dong = o.valueMang ?? []
                case "value":
                    if let k = o.key { t.giaTri[k] = (o.valueSo ?? 0, o.label, o.tone) }
                case "point":
                    if let k = o.key { t.diem[k, default: []].append((o.x ?? 0, o.y ?? 0)) }
                default: break
                }
                ra[o.p] = t
            }
        }
        return ra
    }
}

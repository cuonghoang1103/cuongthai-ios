// ════════════════════════════════════════════════════════════════
// LÕI TOÁN CỦA PHÉP BOOLEAN — cây BSP cắt lưới tam giác
//
// Tách khỏi phần SceneKit CÓ CHỦ ĐÍCH: lõi này chỉ cần `simd`, nên chạy và
// KIỂM ĐƯỢC ngoài app bằng một chương trình dòng lệnh. CSG là loại mã rất
// dễ ra kết quả "gần đúng" (mặt thủng, tam giác lật ngược) mà chỉ lộ ra khi
// nhìn từ một góc nhất định — không kiểm được bằng máy thì không nên tin.
// ════════════════════════════════════════════════════════════════

import Foundation
import simd

enum PhepBooleanBa: String, CaseIterable {
    case gop, khoet, giao
}

// MARK: - Nguyên liệu

struct DinhBa {
    var vt: SIMD3<Double>
    var phap: SIMD3<Double>

    func lat() -> DinhBa { DinhBa(vt: vt, phap: -phap) }
    static func pha(_ a: DinhBa, _ b: DinhBa, _ t: Double) -> DinhBa {
        DinhBa(vt: a.vt + (b.vt - a.vt) * t, phap: a.phap + (b.phap - a.phap) * t)
    }
}

/// Sai số so mặt phẳng. Quá nhỏ thì một đỉnh nằm đúng trên mặt bị xếp nhầm
/// sang một bên và lưới thủng một tam giác; quá lớn thì mặt mỏng biến mất.
private let EPS = 1e-5

struct MatPhangBa {
    var phap: SIMD3<Double>
    var w: Double

    init?(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>) {
        let n = simd_cross(b - a, c - a)
        let d = simd_length(n)
        guard d > 1e-12 else { return nil }   // tam giác suy biến
        phap = n / d
        w = simd_dot(phap, a)
    }

    /// Cắt một đa giác theo mặt phẳng này thành bốn rổ.
    ///
    /// ⚠️ TRẢ VỀ chứ không nhận `inout`: hai chỗ gọi đều cần dồn hai rổ vào
    /// CÙNG một mảng, mà Swift cấm truyền cùng một biến vào hai tham số
    /// `inout` ("inout arguments are not allowed to alias each other").
    /// Bản đầu viết kiểu `inout` và chỉ lộ ra khi biên dịch — may mà có
    /// phép kiểm chạy ngoài app, chứ bản dựng iOS lúc đó chưa chạm tệp này.
    func cat(_ dg: DaGiacBa)
        -> (truocCungMat: [DaGiacBa], sauCungMat: [DaGiacBa],
            truoc: [DaGiacBa], sau: [DaGiacBa]) {
        var truocCungMat: [DaGiacBa] = [], sauCungMat: [DaGiacBa] = []
        var truoc: [DaGiacBa] = [], sau: [DaGiacBa] = []
        let TRUNG = 0, TRUOC = 1, SAU = 2, CA_HAI = 3

        var loaiDaGiac = 0
        var loaiDinh: [Int] = []
        loaiDinh.reserveCapacity(dg.dinh.count)
        for d in dg.dinh {
            let t = simd_dot(phap, d.vt) - w
            let l = t < -EPS ? SAU : (t > EPS ? TRUOC : TRUNG)
            loaiDaGiac |= l
            loaiDinh.append(l)
        }

        switch loaiDaGiac {
        case TRUNG:
            if simd_dot(phap, dg.mat.phap) > 0 { truocCungMat.append(dg) }
            else { sauCungMat.append(dg) }
        case TRUOC:
            truoc.append(dg)
        case SAU:
            sau.append(dg)
        default:
            var t: [DinhBa] = [], s: [DinhBa] = []
            for i in dg.dinh.indices {
                let j = (i + 1) % dg.dinh.count
                let li = loaiDinh[i], lj = loaiDinh[j]
                let vi = dg.dinh[i], vj = dg.dinh[j]
                if li != SAU { t.append(vi) }
                if li != TRUOC { s.append(vi) }
                if (li | lj) == CA_HAI {
                    let k = (w - simd_dot(phap, vi.vt)) /
                            simd_dot(phap, vj.vt - vi.vt)
                    let v = DinhBa.pha(vi, vj, k)
                    t.append(v); s.append(v)
                }
            }
            if t.count >= 3, let p = DaGiacBa(t) { truoc.append(p) }
            if s.count >= 3, let p = DaGiacBa(s) { sau.append(p) }
        }
        return (truocCungMat, sauCungMat, truoc, sau)
    }
}

struct DaGiacBa {
    var dinh: [DinhBa]
    var mat: MatPhangBa

    init?(_ d: [DinhBa]) {
        guard d.count >= 3, let m = MatPhangBa(d[0].vt, d[1].vt, d[2].vt) else { return nil }
        dinh = d
        mat = m
    }

    func lat() -> DaGiacBa {
        var m = self
        m.dinh = dinh.reversed().map { $0.lat() }
        m.mat.phap = -mat.phap
        m.mat.w = -mat.w
        return m
    }
}

// MARK: - Cây BSP

final class CayBSP {
    private var mat: MatPhangBa?
    private var truoc: CayBSP?
    private var sau: CayBSP?
    private var cua: [DaGiacBa] = []

    init(_ ds: [DaGiacBa] = []) { if !ds.isEmpty { them(ds) } }

    func lat() {
        cua = cua.map { $0.lat() }
        if var m = mat { m.phap = -m.phap; m.w = -m.w; mat = m }
        truoc?.lat(); sau?.lat()
        swap(&truoc, &sau)
    }

    /// Bỏ những phần của `ds` nằm TRONG cây này.
    func xenBot(_ ds: [DaGiacBa]) -> [DaGiacBa] {
        guard let m = mat else { return ds }
        var t: [DaGiacBa] = [], s: [DaGiacBa] = []
        for dg in ds {
            let r = m.cat(dg)
            t += r.truocCungMat + r.truoc
            s += r.sauCungMat + r.sau
        }
        let a = truoc?.xenBot(t) ?? t
        // Không có nhánh SAU nghĩa là vùng đó nằm gọn bên trong ⇒ bỏ hết.
        let b = sau.map { $0.xenBot(s) } ?? []
        return a + b
    }

    func xenTheo(_ cay: CayBSP) {
        cua = cay.xenBot(cua)
        truoc?.xenTheo(cay)
        sau?.xenTheo(cay)
    }

    func tatCa() -> [DaGiacBa] {
        cua + (truoc?.tatCa() ?? []) + (sau?.tatCa() ?? [])
    }

    func them(_ ds: [DaGiacBa]) {
        guard !ds.isEmpty else { return }
        if mat == nil { mat = ds[0].mat }
        guard let m = mat else { return }
        var t: [DaGiacBa] = [], s: [DaGiacBa] = []
        for dg in ds {
            let r = m.cat(dg)
            cua += r.truocCungMat + r.sauCungMat
            t += r.truoc
            s += r.sau
        }
        if !t.isEmpty { (truoc ?? { let n = CayBSP(); truoc = n; return n }()).them(t) }
        if !s.isEmpty { (sau ?? { let n = CayBSP(); sau = n; return n }()).them(s) }
    }
}


enum LoiBoolean {
    /// Ba phép, viết theo đúng cách kinh điển của thuật toán BSP-CSG.
    static func lam(_ phep: PhepBooleanBa, _ a: [DaGiacBa], _ b: [DaGiacBa]) -> [DaGiacBa] {
        let A = CayBSP(a), B = CayBSP(b)
        switch phep {
        case .gop:
            A.xenTheo(B); B.xenTheo(A)
            B.lat(); B.xenTheo(A); B.lat()
            A.them(B.tatCa())
            return A.tatCa()
        case .khoet:
            A.lat()
            A.xenTheo(B); B.xenTheo(A)
            B.lat(); B.xenTheo(A); B.lat()
            A.them(B.tatCa())
            A.lat()
            return A.tatCa()
        case .giao:
            A.lat()
            B.xenTheo(A); B.lat()
            A.xenTheo(B); B.xenTheo(A)
            A.them(B.tatCa())
            A.lat()
            return A.tatCa()
        }
    }
}

#if os(iOS)
import SceneKit
import SwiftUI
import simd

// ════════════════════════════════════════════════════════════════
// PHÉP BOOLEAN (CSG) — gộp · khoét · giao
//
// SceneKit KHÔNG có sẵn phép này và Apple cũng không cung cấp ở đâu khác,
// nên phải tự cắt lưới tam giác. Dùng cây BSP: cách kinh điển, đúng với
// mọi lưới KÍN, và không cần thư viện ngoài.
//
// Ý tưởng: mỗi lưới thành một cây phân chia không gian theo mặt phẳng của
// từng đa giác. Có cây rồi thì "đa giác này nằm trong hay ngoài khối kia"
// trả lời được, và ba phép gộp/khoét/giao chỉ là ba cách ghép các mảnh
// trong/ngoài lại.
//
// ⚠️ Chỉ đúng với lưới KÍN (không thủng). Mặt phẳng `.phang` dày bằng 0 nên
// không phải khối kín — chặn từ đầu thay vì trả về hình rác.
// ════════════════════════════════════════════════════════════════

enum PhepBa: String, CaseIterable, Identifiable {
    case gop, khoet, giao
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .gop:   return T("Gộp (A + B)")
        case .khoet: return T("Khoét (A − B)")
        case .giao:  return T("Giao (A ∩ B)")
        }
    }
    var bieuTuong: String {
        switch self {
        case .gop:   return "plus.circle"
        case .khoet: return "minus.circle"
        case .giao:  return "circle.circle"
        }
    }
}

// MARK: - Cửa vào

enum Boolean3D {

    /// Rút tam giác của một nút (kèm mọi nút con) về TOẠ ĐỘ THẾ GIỚI.
    ///
    /// Phải đưa cả hai khối về chung một hệ toạ độ trước khi cắt — nếu
    /// không thì phép trừ lấy nhầm vị trí và kết quả trông như khoét trượt.
    static func daGiac(_ nut: SCNNode, vl: Int = 0) -> [DaGiacBa] {
        var ra: [DaGiacBa] = []
        nut.enumerateHierarchy { n, _ in
            guard let g = n.geometry else { return }
            let m = n.simdWorldTransform
            guard let vt = docVec(g, .vertex) else { return }
            let ph = docVec(g, .normal)

            for pt in g.elements where pt.primitiveType == .triangles {
                guard let chiSo = docIdx(pt) else { continue }
                var i = 0
                while i + 2 < chiSo.count {
                    var bo: [DinhBa] = []
                    for k in 0..<3 {
                        let idx = chiSo[i + k]
                        guard idx < vt.count else { bo = []; break }
                        let p4 = m * SIMD4<Float>(vt[idx], 1)
                        let n3: SIMD3<Float>
                        if let ph, idx < ph.count {
                            let n4 = m * SIMD4<Float>(ph[idx], 0)
                            n3 = SIMD3(n4.x, n4.y, n4.z)
                        } else { n3 = SIMD3(0, 1, 0) }
                        bo.append(DinhBa(vt: SIMD3(Double(p4.x), Double(p4.y), Double(p4.z)),
                                         phap: SIMD3(Double(n3.x), Double(n3.y), Double(n3.z))))
                    }
                    if bo.count == 3, let dg = DaGiacBa(bo, vl: vl) { ra.append(dg) }
                    i += 3
                }
            }
        }
        return ra
    }

    static func docVec(_ g: SCNGeometry, _ loai: SCNGeometrySource.Semantic) -> [SIMD3<Float>]? {
        guard let s = g.sources(for: loai).first, s.componentsPerVector >= 3 else { return nil }
        var ra: [SIMD3<Float>] = []
        ra.reserveCapacity(s.vectorCount)
        s.data.withUnsafeBytes { (b: UnsafeRawBufferPointer) in
            for i in 0..<s.vectorCount {
                let o = s.dataOffset + i * s.dataStride
                if s.bytesPerComponent == 4 {
                    let x = b.loadUnaligned(fromByteOffset: o, as: Float.self)
                    let y = b.loadUnaligned(fromByteOffset: o + 4, as: Float.self)
                    let z = b.loadUnaligned(fromByteOffset: o + 8, as: Float.self)
                    ra.append(SIMD3(x, y, z))
                } else if s.bytesPerComponent == 8 {
                    let x = b.loadUnaligned(fromByteOffset: o, as: Double.self)
                    let y = b.loadUnaligned(fromByteOffset: o + 8, as: Double.self)
                    let z = b.loadUnaligned(fromByteOffset: o + 16, as: Double.self)
                    ra.append(SIMD3(Float(x), Float(y), Float(z)))
                }
            }
        }
        return ra.isEmpty ? nil : ra
    }

    static func docIdx(_ e: SCNGeometryElement) -> [Int]? {
        var ra: [Int] = []
        ra.reserveCapacity(e.primitiveCount * 3)
        e.data.withUnsafeBytes { (b: UnsafeRawBufferPointer) in
            let n = e.primitiveCount * 3
            for i in 0..<n {
                switch e.bytesPerIndex {
                case 2: ra.append(Int(b.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self)))
                case 4: ra.append(Int(b.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self)))
                default: return
                }
            }
        }
        return ra.isEmpty ? nil : ra
    }

    /// Gọi lõi toán chung — lõi đó kiểm được ngoài app, xem `LoiBoolean.swift`.
    static func lam(_ phep: PhepBa, _ a: [DaGiacBa], _ b: [DaGiacBa]) -> [DaGiacBa] {
        LoiBoolean.lam(PhepBooleanBa(rawValue: phep.rawValue) ?? .gop, a, b)
    }

    /// Dựng `SCNGeometry` từ kết quả, đồng thời dời về gốc toạ độ và trả
    /// lại TÂM để người gọi đặt vị trí khối mới cho khớp chỗ cũ.
    /// Dựng hình GIỮ RIÊNG từng nhãn vật liệu: mỗi nhãn một phần tử hình
    /// học, nên khối gộp ra vẫn có hai màu như hai khối gốc.
    static func dungHinhNhieuMau(_ ds: [DaGiacBa], mau: [Int: SCNMaterial])
        -> (SCNGeometry, SIMD3<Double>)? {
        guard !ds.isEmpty else { return nil }
        var lo = SIMD3<Double>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Double>(repeating: -.greatestFiniteMagnitude)
        for dg in ds { for d in dg.dinh { lo = simd_min(lo, d.vt); hi = simd_max(hi, d.vt) } }
        let tam = (lo + hi) / 2

        var vt: [SCNVector3] = [], ph: [SCNVector3] = []
        var theoVl: [Int: [UInt32]] = [:]
        for dg in ds {
            let goc = UInt32(vt.count)
            for d in dg.dinh {
                let p = d.vt - tam
                vt.append(SCNVector3(Float(p.x), Float(p.y), Float(p.z)))
                ph.append(SCNVector3(Float(d.phap.x), Float(d.phap.y), Float(d.phap.z)))
            }
            for i in 1..<(dg.dinh.count - 1) {
                theoVl[dg.vl, default: []] += [goc, goc + UInt32(i), goc + UInt32(i + 1)]
            }
        }
        let nhan = theoVl.keys.sorted()
        guard !nhan.isEmpty else { return nil }

        let pt = nhan.map { SCNGeometryElement(indices: theoVl[$0]!, primitiveType: .triangles) }
        let g = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vt), SCNGeometrySource(normals: ph)],
            elements: pt)
        // Thứ tự vật liệu phải KHỚP thứ tự phần tử hình học.
        g.materials = nhan.map { mau[$0] ?? SCNMaterial() }
        return (g, tam)
    }

    static func dungHinh(_ ds: [DaGiacBa]) -> (SCNGeometry, SIMD3<Double>)? {
        guard !ds.isEmpty else { return nil }
        var lo = SIMD3<Double>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Double>(repeating: -.greatestFiniteMagnitude)
        for dg in ds { for d in dg.dinh { lo = simd_min(lo, d.vt); hi = simd_max(hi, d.vt) } }
        let tam = (lo + hi) / 2

        var vt: [SCNVector3] = [], ph: [SCNVector3] = [], ci: [UInt32] = []
        for dg in ds {
            // Quạt tam giác quanh đỉnh đầu — đa giác do BSP sinh ra luôn lồi.
            let goc = UInt32(vt.count)
            for d in dg.dinh {
                let p = d.vt - tam
                vt.append(SCNVector3(Float(p.x), Float(p.y), Float(p.z)))
                ph.append(SCNVector3(Float(d.phap.x), Float(d.phap.y), Float(d.phap.z)))
            }
            for i in 1..<(dg.dinh.count - 1) {
                ci.append(goc); ci.append(goc + UInt32(i)); ci.append(goc + UInt32(i + 1))
            }
        }
        guard ci.count >= 3 else { return nil }

        let g = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vt), SCNGeometrySource(normals: ph)],
            elements: [SCNGeometryElement(indices: ci, primitiveType: .triangles)])
        return (g, tam)
    }
}
#endif

#if os(iOS)
// ════════════════════════════════════════════════════════════════
// SceneKit → MẢNH LƯỚI để xuất .glb / .obj
// ════════════════════════════════════════════════════════════════

extension Boolean3D {

    /// Rút lưới của một khối về toạ độ THẾ GIỚI, tách theo từng vật liệu.
    ///
    /// Tách theo vật liệu chứ không gộp cả khối: gộp thì con robot ra máy
    /// tính chỉ còn MỘT màu, mất hết thân/khớp/đèn/kính — đúng thứ người
    /// dùng cần giữ khi làm skin.
    static func manhLuoi(_ k: KhoiBa, nut: SCNNode) -> [MienhLuoi] {
        var ra: [MienhLuoi] = []
        nut.enumerateHierarchy { n, _ in
            guard let g = n.geometry else { return }
            let bd = n.simdWorldTransform
            guard let vt = docVec(g, .vertex) else { return }
            let ph = docVec(g, .normal)

            for (iPt, pt) in g.elements.enumerated() where pt.primitiveType == .triangles {
                guard let ci = docIdx(pt) else { continue }
                var m = MienhLuoi()
                m.ten = k.tenHien

                // Vật liệu: của chính mảnh nếu tệp nhập mang theo, còn lại
                // lấy của khối. `toDe` nghĩa là người dùng cố ý tô đè.
                let vl = iPt < g.materials.count ? g.materials[iPt] : g.materials.first
                if k.loai == .nhap && !k.toDe, let c = (vl?.diffuse.contents as? UIColor) {
                    m.mau = rgba(c)
                } else {
                    m.mau = rgba(UIColor(Color(maHex: k.mau)))
                }
                m.kimLoai = Float(k.kimLoai)
                m.nham = Float(k.nham)

                // Chép đỉnh theo THỨ TỰ CHỈ SỐ rồi đánh số lại: lưới gốc có
                // thể dùng chung đỉnh giữa nhiều phần tử, mà mỗi mảnh xuất
                // ra phải tự chứa đủ đỉnh của nó.
                var banDo: [Int: UInt32] = [:]
                for idx in ci {
                    guard idx < vt.count else { continue }
                    if banDo[idx] == nil {
                        let p4 = bd * SIMD4<Float>(vt[idx], 1)
                        m.vt.append(SIMD3(p4.x, p4.y, p4.z))
                        if let ph, idx < ph.count {
                            let n4 = bd * SIMD4<Float>(ph[idx], 0)
                            m.ph.append(SIMD3(n4.x, n4.y, n4.z))
                        } else {
                            m.ph.append(SIMD3(0, 1, 0))
                        }
                        banDo[idx] = UInt32(m.vt.count - 1)
                    }
                    m.ci.append(banDo[idx]!)
                }
                if m.vt.count >= 3 && m.ci.count >= 3 { ra.append(m) }
            }
        }
        return ra
    }

    private static func rgba(_ c: UIColor) -> SIMD4<Float> {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4(Float(r), Float(g), Float(b), Float(a))
    }

    /// Cả cảnh → danh sách mảnh, bỏ khối đã ẩn hoặc không đọc được lưới.
    static func manhCuaCanh(_ canh: CanhBa, thuMucTep: URL) -> [MienhLuoi] {
        var ra: [MienhLuoi] = []
        for k in canh.khoi {
            let n = DungCanh.dungNut(k, dangChon: false, thuMucTep: thuMucTep)
            ra += manhLuoi(k, nut: n)
        }
        return ra
    }
}
#endif

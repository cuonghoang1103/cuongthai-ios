#if os(iOS)
import SceneKit
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
    static func daGiac(_ nut: SCNNode) -> [DaGiacBa] {
        var ra: [DaGiacBa] = []
        nut.enumerateHierarchy { n, _ in
            guard let g = n.geometry else { return }
            let m = n.simdWorldTransform
            guard let vt = doc(g, .vertex) else { return }
            let ph = doc(g, .normal)

            for pt in g.elements where pt.primitiveType == .triangles {
                guard let chiSo = docChiSo(pt) else { continue }
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
                    if bo.count == 3, let dg = DaGiacBa(bo) { ra.append(dg) }
                    i += 3
                }
            }
        }
        return ra
    }

    private static func doc(_ g: SCNGeometry, _ loai: SCNGeometrySource.Semantic) -> [SIMD3<Float>]? {
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

    private static func docChiSo(_ e: SCNGeometryElement) -> [Int]? {
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

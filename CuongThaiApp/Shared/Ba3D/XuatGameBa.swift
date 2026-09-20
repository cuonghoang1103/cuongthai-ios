// ════════════════════════════════════════════════════════════════
// XUẤT SANG MÁY TÍNH — .glb (glTF nhị phân) và .obj
//
// Vì sao phải TỰ viết: đo trên máy 20/09/2026, ModelIO xuất được
// obj/ply/stl/usd nhưng **KHÔNG xuất được glb, gltf, fbx, dae**; còn
// SceneKit chỉ ghi được .scn và .usdz. Mà .glb mới là thứ three.js và
// Babylon.js nạp thẳng cho web 3D game, và Unity/Godot/Blender đều đọc.
// Không có nó thì mọi thứ dựng ra kẹt lại trong iPad.
//
// glTF 2.0 nhị phân = 12 byte đầu + khối JSON + khối nhị phân. Không khó,
// chỉ cần đúng từng byte — nên phần dựng byte tách riêng khỏi SceneKit để
// chạy kiểm được bằng chương trình dòng lệnh.
// ════════════════════════════════════════════════════════════════

import Foundation
import simd

/// Một mảnh lưới cùng vật liệu — đơn vị nhỏ nhất khi xuất.
///
/// Tách theo VẬT LIỆU chứ không gộp cả mô hình vào một mảnh: gộp thì con
/// robot ra máy tính chỉ còn MỘT màu, mất hết thân/khớp/đèn/kính.
struct MienhLuoi {
    var vt: [SIMD3<Float>] = []
    var ph: [SIMD3<Float>] = []
    var ci: [UInt32] = []
    /// RGBA 0…1
    var mau: SIMD4<Float> = [1, 1, 1, 1]
    var kimLoai: Float = 0.1
    var nham: Float = 0.45
    var ten: String = "phan"
}

enum DungGLB {

    // MARK: .glb

    static func glb(_ ms: [MienhLuoi], tenMoHinh: String) -> Data? {
        let hop = ms.filter { $0.vt.count >= 3 && $0.ci.count >= 3 }
        guard !hop.isEmpty else { return nil }

        var bin = Data()
        var bufferViews: [[String: Any]] = []
        var accessors: [[String: Any]] = []
        var meshes: [[String: Any]] = []
        var materials: [[String: Any]] = []
        var nodes: [[String: Any]] = []

        /// Ghi một mảng vào khối nhị phân, trả chỉ số bufferView.
        func ghi(_ d: Data, target: Int) -> Int {
            // glTF bắt buộc mỗi bufferView bắt đầu ở bội của 4.
            while bin.count % 4 != 0 { bin.append(0) }
            let off = bin.count
            bin.append(d)
            bufferViews.append(["buffer": 0, "byteOffset": off,
                                "byteLength": d.count, "target": target])
            return bufferViews.count - 1
        }

        for (i, m) in hop.enumerated() {
            // ── vị trí ──
            var dVt = Data()
            var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            for v in m.vt {
                lo = simd_min(lo, v); hi = simd_max(hi, v)
                for k in 0..<3 { withUnsafeBytes(of: v[k]) { dVt.append(contentsOf: $0) } }
            }
            let bvVt = ghi(dVt, target: 34962)
            accessors.append([
                "bufferView": bvVt, "componentType": 5126, "count": m.vt.count,
                "type": "VEC3",
                // min/max của POSITION là BẮT BUỘC trong glTF — thiếu thì
                // three.js vẫn nạp nhưng khung bao sai, và vật bị cắt khi
                // camera nhìn nghiêng (frustum culling dùng đúng hai số này).
                "min": [lo.x, lo.y, lo.z], "max": [hi.x, hi.y, hi.z],
            ])
            let aVt = accessors.count - 1

            // ── pháp tuyến ──
            var dPh = Data()
            for v in m.ph {
                let n = simd_length(v) > 1e-6 ? simd_normalize(v) : SIMD3<Float>(0, 1, 0)
                for k in 0..<3 { withUnsafeBytes(of: n[k]) { dPh.append(contentsOf: $0) } }
            }
            let bvPh = ghi(dPh, target: 34962)
            accessors.append(["bufferView": bvPh, "componentType": 5126,
                              "count": m.ph.count, "type": "VEC3"])
            let aPh = accessors.count - 1

            // ── chỉ số ──
            var dCi = Data()
            for c in m.ci { withUnsafeBytes(of: c) { dCi.append(contentsOf: $0) } }
            let bvCi = ghi(dCi, target: 34963)
            accessors.append(["bufferView": bvCi, "componentType": 5125,
                              "count": m.ci.count, "type": "SCALAR"])
            let aCi = accessors.count - 1

            materials.append([
                "name": m.ten,
                "pbrMetallicRoughness": [
                    "baseColorFactor": [m.mau.x, m.mau.y, m.mau.z, m.mau.w],
                    "metallicFactor": m.kimLoai,
                    "roughnessFactor": m.nham,
                ],
                "doubleSided": true,
            ])
            meshes.append([
                "name": m.ten,
                "primitives": [[
                    "attributes": ["POSITION": aVt, "NORMAL": aPh],
                    "indices": aCi, "material": i, "mode": 4,
                ]],
            ])
            nodes.append(["mesh": i, "name": m.ten])
        }

        let json: [String: Any] = [
            "asset": ["version": "2.0", "generator": "CuongThai Xưởng 3D"],
            "scene": 0,
            "scenes": [["name": tenMoHinh, "nodes": Array(0..<nodes.count)]],
            "nodes": nodes,
            "meshes": meshes,
            "materials": materials,
            "accessors": accessors,
            "bufferViews": bufferViews,
            "buffers": [["byteLength": bin.count]],
        ]
        guard var dJson = try? JSONSerialization.data(withJSONObject: json) else { return nil }

        // Cả hai khối phải dài bội của 4. Khối JSON đệm bằng DẤU CÁCH, khối
        // nhị phân đệm bằng 0 — đệm sai ký tự thì bộ đọc báo tệp hỏng.
        while dJson.count % 4 != 0 { dJson.append(0x20) }
        var dBin = bin
        while dBin.count % 4 != 0 { dBin.append(0) }

        var ra = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { ra.append(contentsOf: $0) } }
        let tong = 12 + 8 + dJson.count + 8 + dBin.count
        u32(0x46546C67)            // "glTF"
        u32(2)
        u32(UInt32(tong))
        u32(UInt32(dJson.count)); u32(0x4E4F534A)   // "JSON"
        ra.append(dJson)
        u32(UInt32(dBin.count)); u32(0x004E4942)    // "BIN"
        ra.append(dBin)
        return ra
    }

    // MARK: .obj + .mtl

    /// `.obj` kèm `.mtl`. Không có texture nên `.mtl` chỉ mang màu — đủ để
    /// Blender/Unity nhận đúng từng mảng màu thay vì một cục trắng.
    static func obj(_ ms: [MienhLuoi], tenMoHinh: String) -> (obj: String, mtl: String) {
        var o = "# CuongThai Xưởng 3D\nmtllib \(tenMoHinh).mtl\n"
        var mtl = "# CuongThai Xưởng 3D\n"
        var goc = 1     // .obj đánh số đỉnh TỪ 1, không phải 0

        for (i, m) in ms.enumerated() where m.vt.count >= 3 && m.ci.count >= 3 {
            let ten = "vl_\(i)_\(m.ten.replacingOccurrences(of: " ", with: "_"))"
            mtl += """

            newmtl \(ten)
            Kd \(m.mau.x) \(m.mau.y) \(m.mau.z)
            Ks \(m.kimLoai) \(m.kimLoai) \(m.kimLoai)
            Ns \((1 - m.nham) * 900)
            d \(m.mau.w)

            """
            o += "\ng \(m.ten.replacingOccurrences(of: " ", with: "_"))_\(i)\nusemtl \(ten)\n"
            for v in m.vt { o += "v \(v.x) \(v.y) \(v.z)\n" }
            for n in m.ph { o += "vn \(n.x) \(n.y) \(n.z)\n" }
            var k = 0
            while k + 2 < m.ci.count {
                let a = Int(m.ci[k]) + goc, b = Int(m.ci[k+1]) + goc, c = Int(m.ci[k+2]) + goc
                o += "f \(a)//\(a) \(b)//\(b) \(c)//\(c)\n"
                k += 3
            }
            goc += m.vt.count
        }
        return (o, mtl)
    }
}

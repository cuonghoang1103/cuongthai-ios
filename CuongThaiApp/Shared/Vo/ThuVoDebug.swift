#if DEBUG && os(iOS)
import PencilKit
import SwiftData
import SwiftUI

// MARK: - Bàn thử Vở (CHỈ bản DEBUG, mở qua CT_XEM_MAN)
//
// Máy mô phỏng không có công cụ rê/kéo tự động, nên phép thử sắp xếp · đổi
// tên · nhân bản · chuyển cuốn · xoá + hoàn tác chạy THẲNG trên các hàm của
// `ThaoTacTrang` — đúng những hàm giao diện gọi — trong một kho SwiftData
// BỘ NHỚ riêng, không đụng vở thật. Kết quả in ra màn + nhật ký
// (`[THU-VO]`), đọc bằng `xcrun simctl spawn <udid> log show`.
//
//   CT_XEM_MAN=vo-thu        chạy bộ thử logic
//   CT_XEM_MAN=vo-kiem       tóm tắt KHO THẬT (đếm môn/cuốn/trang, tên, thứ tự)
//   CT_XEM_MAN=vo-viet       (gieo vở mẫu nếu kho trống) mở màn viết
//   CT_XEM_MAN=vo-tongquan   … mở thẳng màn "Các trang" (lưới)
//   CT_XEM_MAN=vo-sapxep     … mở thẳng màn "Các trang" (danh sách tay nắm)
//   CT_XEM_MAN=vo-lamgon-thu bộ đo "Làm gọn chữ" trên nét giả (ThuLamGon)
//   CT_XEM_MAN=vo-lamgon     gieo một trang viết XẤU rồi mở màn viết; thêm
//                              CT_LAMGON=mo            tự mở cửa sổ Làm gọn
//                              CT_LAMGON=ap            … và tự bấm Áp dụng
//                              CT_LAMGON_HOANTAC=1     … rồi ↶ / ↷ và đối chiếu (log)
//                              CT_LAMGON_XEM=goc       cửa sổ mở ở bản "Trước"

@MainActor
enum ThuVo {
    static func log(_ s: String) { NSLog("[THU-VO] %@", s) }

    /// Chạy mọi phép thử, trả về từng dòng "✅/❌ …".
    static func chayHet() -> [String] {
        var kq: [String] = []
        func kiem(_ ten: String, _ dung: Bool, _ chiTiet: String = "") {
            let d = (dung ? "✅ " : "❌ ") + ten + (chiTiet.isEmpty ? "" : " — " + chiTiet)
            kq.append(d); log(d)
        }
        let schema = Schema([MonVo.self, CuonVo.self, TrangVo.self, ViecXoaCho.self,
                             TienDoChu.self, TheHoiAI.self])
        guard let c = try? ModelContainer(for: schema, configurations: [
            ModelConfiguration("ThuVo", schema: schema, isStoredInMemoryOnly: true)]) else {
            kiem("dựng kho thử", false); return kq
        }
        let kho = ModelContext(c)
        let mon = MonVo(ten: "Thử"); kho.insert(mon)
        let cuon = CuonVo(ten: "Cuốn A", mon: mon); kho.insert(cuon)
        let cuonB = CuonVo(ten: "Cuốn B", mon: mon, thuTu: 1); kho.insert(cuonB)
        var ids: [UUID] = []
        for i in 0..<5 {
            let t = TrangVo(cuon: cuon, thuTu: i, giay: .keNgang, huong: .doc)
            kho.insert(t); ids.append(t.id)
        }
        let tB = TrangVo(cuon: cuonB, thuTu: 0, giay: .oLy, huong: .doc); kho.insert(tB)
        try? kho.save()
        cuon.canDayCay = false
        let ten = { cuon.trangsTheoThuTu.map { t in "\(ids.firstIndex(of: t.id).map { $0 + 1 } ?? 0)" }.joined(separator: ",") }
        let soLienMach = { cuon.trangsTheoThuTu.map(\.thuTu) == Array(0..<cuon.trangsTheoThuTu.count) }

        // 1. Kéo trang 4 lên cạnh trang 1 (đúng ca người dùng báo).
        let t4 = cuon.trangsTheoThuTu[3], t2 = cuon.trangsTheoThuTu[1]
        ThaoTacTrang.datVaoCho(t4, choCua: t2, trongCuon: cuon, kho: kho)
        kiem("kéo trang 4 vào chỗ trang 2", ten() == "1,4,2,3,5", ten())
        kiem("thuTu liền mạch sau kéo", soLienMach())
        kiem("đánh dấu cây bẩn sau kéo", cuon.canDayCay)

        // 2. onMove (danh sách tay nắm): đưa trang cuối lên đầu.
        ThaoTacTrang.diChuyen(trongCuon: cuon, tu: IndexSet(integer: 4), toi: 0, kho: kho)
        kiem("onMove: cuối lên đầu", ten() == "5,1,4,2,3", ten())
        // Kéo XUỐNG: trang đầu xuống sau trang 3 (vị trí 4).
        let dau = cuon.trangsTheoThuTu[0], thu4 = cuon.trangsTheoThuTu[3]
        ThaoTacTrang.datVaoCho(dau, choCua: thu4, trongCuon: cuon, kho: kho)
        kiem("kéo xuống: 5 xuống sau 2", ten() == "1,4,2,5,3", ten())

        // 3. Đọc lại từ một context MỚI — thứ tự thật sự đã lưu.
        let kho2 = ModelContext(c)
        let docLai = (try? kho2.fetch(FetchDescriptor<CuonVo>()))?.first { $0.id == cuon.id }
        let tt2 = docLai?.trangsTheoThuTu.map { t in "\(ids.firstIndex(of: t.id).map { $0 + 1 } ?? 0)" }.joined(separator: ",")
        kiem("thứ tự bền qua context mới", tt2 == "1,4,2,5,3", tt2 ?? "nil")

        // 4. Đổi tên + tên mặc định.
        let p1 = cuon.trangsTheoThuTu[0]
        ThaoTacTrang.doiTen(p1, thanh: "  Bài 3 — Katakana ", kho: kho)
        kiem("đổi tên (cắt khoảng trắng)", p1.tieuDe == "Bài 3 — Katakana", p1.tieuDe ?? "nil")
        kiem("tên hiển thị có tên", p1.tenHienThi(so: 1) == "Bài 3 — Katakana")
        let p2 = cuon.trangsTheoThuTu[1]
        kiem("tên hiển thị mặc định", p2.tenHienThi(so: 2) == T("Trang") + " 2", p2.tenHienThi(so: 2))
        ThaoTacTrang.doiTen(p1, thanh: "   ", kho: kho)
        kiem("xoá tên = về Trang N", p1.tieuDe == nil)
        ThaoTacTrang.doiTen(p1, thanh: "Bài 3", kho: kho)

        // 5. Nhân bản: ngay sau gốc, mang nền + nét.
        p1.nenPdfTen = "gia.pdf"; p1.nenPdfTrang = 2
        var net = PKDrawing()
        let diem = [PKStrokePoint(location: CGPoint(x: 10, y: 10), timeOffset: 0, size: CGSize(width: 4, height: 4),
                                  opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2),
                    PKStrokePoint(location: CGPoint(x: 200, y: 200), timeOffset: 0.1, size: CGSize(width: 4, height: 4),
                                  opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)]
        net.strokes.append(PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: diem, creationDate: Date())))
        KhoVo.ghi(net, cho: p1.id)
        let ban = ThaoTacTrang.nhanBan(p1, kho: kho)
        kiem("nhân bản nằm ngay sau gốc", cuon.trangsTheoThuTu[1].id == ban?.id)
        kiem("nhân bản mang nền PDF", ban?.nenPdfTen == "gia.pdf" && ban?.nenPdfTrang == 2)
        kiem("nhân bản mang nét", ban.map { KhoVo.nap($0.id).strokes.count } == 1)
        kiem("nhân bản có tên (bản sao)", ban?.tieuDe?.hasPrefix("Bài 3") == true, ban?.tieuDe ?? "nil")
        kiem("6 trang, liền mạch", cuon.trangsTheoThuTu.count == 6 && soLienMach())

        // 6. Chèn trước/sau.
        let moiDau = ThaoTacTrang.chenTrangTrang(vao: cuon, viTri: 0, giay: .bonDong, huong: .doc, kho: kho)
        kiem("chèn trước trang 1", cuon.trangsTheoThuTu.first?.id == moiDau.id && moiDau.giay == .bonDong)

        // 7. Chuyển sang cuốn B: vào cuối cuốn B.
        let canChuyen = cuon.trangsTheoThuTu[2]
        let okChuyen = ThaoTacTrang.chuyen([canChuyen], sang: cuonB, kho: kho)
        kiem("chuyển sang cuốn B", okChuyen && cuonB.trangsTheoThuTu.last?.id == canChuyen.id
             && canChuyen.cuon?.id == cuonB.id)
        kiem("cả hai cuốn liền mạch", soLienMach()
             && cuonB.trangsTheoThuTu.map(\.thuTu) == Array(0..<cuonB.trangsTheoThuTu.count))
        let khongDuoc = ThaoTacTrang.chuyen(cuonB.trangsTheoThuTu, sang: cuon, kho: kho)
        kiem("chặn chuyển làm rỗng cuốn", !khongDuoc && cuonB.soTrang == 2)

        // 8. Xoá + hoàn tác.
        let truocXoa = cuon.trangsTheoThuTu.count
        let xoaNay = cuon.trangsTheoThuTu[1]           // trang "Bài 3" có nét
        let tieuDeXoa = xoaNay.tieuDe
        let chup = ThaoTacTrang.xoa([xoaNay], kho: kho)
        kiem("xoá 1 trang", chup?.count == 1 && cuon.trangsTheoThuTu.count == truocXoa - 1)
        let hangDoi = (try? kho.fetch(FetchDescriptor<ViecXoaCho>())) ?? []
        kiem("lệnh xoá vào hàng đợi bền", hangDoi.contains { $0.maDoiTuong == chup?.first?.idCu.uuidString })
        if let chup {
            let lai = ThaoTacTrang.hoanTacXoa(chup, vao: cuon, kho: kho)
            kiem("hoàn tác: về đúng vị trí 2", cuon.trangsTheoThuTu[1].id == lai.first?.id)
            kiem("hoàn tác: id MỚI (không đụng hàng đã xoá trên máy chủ)", lai.first?.id != chup.first?.idCu)
            kiem("hoàn tác: giữ tên + nét", lai.first?.tieuDe == tieuDeXoa
                 && lai.first.map { KhoVo.nap($0.id).strokes.count } == 1)
            kiem("hoàn tác: sẽ được đẩy lên", lai.first?.canDay == true && lai.first?.idMayChu == nil)
        }
        kiem("chặn xoá hết trang", ThaoTacTrang.xoa(cuon.trangsTheoThuTu, kho: kho) == nil)

        // 9. Đổi giấy nhiều trang.
        ThaoTacTrang.doiGiay(Array(cuon.trangsTheoThuTu.prefix(2)), thanh: .luoiCode, kho: kho)
        kiem("đổi giấy 2 trang sang lưới code", cuon.trangsTheoThuTu.prefix(2).allSatisfy { $0.giay == .luoiCode })

        // 10. Payload kéo về: máy chủ cũ trả "Trang N" làm tenChuong.
        let cu = try? JSONDecoder().decode(TrangTaiVe.self, from: Data(#"{"clientId":"x","id":1,"thuTu":0,"tenChuong":"Trang 3","inkVersion":0,"inkStrokeCount":0}"#.utf8))
        kiem("máy chủ cũ: 'Trang 3' không thành chương", cu?.mayChuMoi == false && cu?.tenChuongThat == nil)
        let moi = try? JSONDecoder().decode(TrangTaiVe.self, from: Data(#"{"clientId":"x","id":1,"thuTu":0,"tenChuong":null,"tieuDe":"Bài 1","inkVersion":0,"inkStrokeCount":0}"#.utf8))
        kiem("máy chủ mới: đọc tieuDe", moi?.mayChuMoi == true && moi?.tieuDe == "Bài 1")

        // 11. Xuất PDF cả cuốn: đủ số trang.
        if let url = XuatPdfVo.taoPdf(trangs: cuon.trangsTheoThuTu, tenTep: "thu-xuat"),
           let doc = CGPDFDocument(url as CFURL) {
            kiem("xuất PDF đủ trang", doc.numberOfPages == cuon.soTrang, "\(doc.numberOfPages) trang")
        } else { kiem("xuất PDF", false) }

        // 12. Vẽ hai giấy mới ra PNG để nhìn (Documents/giay-*.png).
        let goc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for g in [LoaiGiay.bonDong, .luoiCode] {
            let kt = HuongGiay.doc.khoA4
            let v = GiayNenView(frame: CGRect(origin: .zero, size: kt))
            v.giay = g; v.khoTrang = kt; v.tyLe = 1
            let anh = UIGraphicsImageRenderer(size: kt).image { _ in v.draw(CGRect(origin: .zero, size: kt)) }
            try? anh.pngData()?.write(to: goc.appendingPathComponent("giay-\(g.rawValue).png"))
        }

        // Dọn tệp nét vừa ghi ra Documents/Vo.
        for t in (try? kho.fetch(FetchDescriptor<TrangVo>())) ?? [] { KhoVo.xoa(t.id) }
        let hong = kq.filter { $0.hasPrefix("❌") }.count
        log("KẾT QUẢ: \(kq.count - hong)/\(kq.count) đạt")
        kq.append("KẾT QUẢ: \(kq.count - hong)/\(kq.count) đạt")
        return kq
    }

    /// Tóm tắt KHO THẬT — để đối chiếu trước/sau khi cài đè bản mới.
    static func tomTatKhoThat(_ kho: ModelContext) -> [String] {
        let mons = (try? kho.fetch(FetchDescriptor<MonVo>(sortBy: [SortDescriptor(\.thuTu)]))) ?? []
        var ds = ["loiMoKho=\(KhoSwiftData.loiMoKho ?? "không")", "môn=\(mons.count)"]
        for m in mons {
            for c in m.cuonsTheoThuTu {
                let ts = c.trangsTheoThuTu.enumerated().map { i, t in
                    "\(i + 1):\(t.tenHienThi(so: i + 1))|chuong=\(t.tenChuong ?? "-")|giay=\(t.loaiGiay)|net=\(KhoVo.nap(t.id).strokes.count)"
                }
                ds.append("\(m.ten)/\(c.ten) [\(c.soTrang) trang] " + ts.joined(separator: " ; "))
            }
        }
        for d in ds { log("KHO: " + d) }
        return ds
    }

    /// Gieo một cuốn vở mẫu vào KHO THẬT nếu còn trống (chỉ máy mô phỏng).
    static func gieoNeuTrong(_ kho: ModelContext) -> CuonVo? {
        if let c = (try? kho.fetch(FetchDescriptor<CuonVo>()))?.first(where: { $0.soTrang > 0 }) { return c }
        let mon = MonVo(ten: "Tiếng Anh", emoji: "🇬🇧"); kho.insert(mon)
        let cuon = CuonVo(ten: "Vở mẫu sắp xếp", mon: mon); kho.insert(cuon)
        let giays: [LoaiGiay] = [.keNgang, .bonDong, .luoiCode, .genkou, .cornell, .oLy]
        for i in 0..<6 {
            let t = TrangVo(cuon: cuon, thuTu: i, giay: giays[i], huong: .doc)
            if i == 1 { t.tieuDe = "Bài 3 — Present Perfect" }
            if i == 3 { t.tenChuong = "Chương 2 — Kanji" }
            kho.insert(t)
            // Vẽ SỐ TRANG thật to bằng nét để nhìn ảnh nhỏ là biết trang nào.
            let d = veSo(i + 1)
            KhoVo.ghi(d, cho: t.id)
            KhoVo.dungAnhNho(d, kho: t.khoTrang, cho: t.id)
        }
        try? kho.save()
        return cuon
    }

    /// Một cuốn "Thử làm gọn" với MỘT trang kẻ ngang viết xấu (chữ nghiêng,
    /// nhảy, run tay, bảng lệch, hình méo). Mỗi lần mở ghi đè lại trang xấu,
    /// trừ khi đặt `CT_LAMGON_GIU=1` (để xem bản đã áp dụng còn nguyên không).
    static func gieoTrangXau(_ kho: ModelContext) -> CuonVo? {
        let ten = "Thử làm gọn"
        var cuon = (try? kho.fetch(FetchDescriptor<CuonVo>()))?.first { $0.ten == ten }
        if cuon == nil {
            let mon = MonVo(ten: "Thử", emoji: "✨"); kho.insert(mon)
            let c = CuonVo(ten: ten, mon: mon); kho.insert(c)
            let t = TrangVo(cuon: c, thuTu: 0, giay: .keNgang, huong: .doc)
            kho.insert(t)
            cuon = c
        }
        guard let cuon, let trang = cuon.trangsTheoThuTu.first else { return nil }
        if ProcessInfo.processInfo.environment["CT_LAMGON_GIU"] != "1" || !trang.coNet {
            let d = ThuLamGon.trangMau().k.drawing
            KhoVo.ghi(d, cho: trang.id)
            KhoVo.dungAnhNho(d, kho: trang.khoTrang, cho: trang.id)
            trang.coNet = true
        }
        cuon.trangDangDoc = 0
        try? kho.save()
        return cuon
    }

    /// Chữ số 1–9 vẽ bằng nét theo lưới 7 đoạn — đủ để nhận ra trên ảnh nhỏ.
    private static func veSo(_ n: Int) -> PKDrawing {
        let doan: [Int: [(CGPoint, CGPoint)]] = {
            let a = CGPoint(x: 200, y: 200), b = CGPoint(x: 400, y: 200)
            let c = CGPoint(x: 200, y: 420), d = CGPoint(x: 400, y: 420)
            let e = CGPoint(x: 200, y: 640), f = CGPoint(x: 400, y: 640)
            return [1: [(b, d), (d, f)],
                    2: [(a, b), (b, d), (d, c), (c, e), (e, f)],
                    3: [(a, b), (b, d), (c, d), (d, f), (e, f)],
                    4: [(a, c), (c, d), (b, d), (d, f)],
                    5: [(b, a), (a, c), (c, d), (d, f), (f, e)],
                    6: [(b, a), (a, e), (e, f), (f, d), (d, c)],
                    7: [(a, b), (b, f)],
                    8: [(a, b), (b, f), (f, e), (e, a), (c, d)],
                    9: [(d, c), (c, a), (a, b), (b, f)]]
        }()
        var d = PKDrawing()
        for (p, q) in doan[n] ?? [] {
            let pts = [p, q].map { PKStrokePoint(location: $0, timeOffset: 0, size: CGSize(width: 14, height: 14),
                                                 opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2) }
            d.strokes.append(PKStroke(ink: PKInk(.marker, color: .systemBlue),
                                      path: PKStrokePath(controlPoints: pts, creationDate: Date())))
        }
        return d
    }
}

struct ThuVoView: View {
    let cheDo: String
    @Environment(\.modelContext) private var kho
    @State private var dong: [String] = []
    @State private var cuon: CuonVo?

    var body: some View {
        // ZStack + Color.clear: một `Group` đang RỖNG (cuon còn nil) không bao
        // giờ "xuất hiện", nên `onAppear` gắn trên nó không bao giờ chạy.
        ZStack {
            Color.clear
            switch cheDo {
            case "vo-viet", "vo-lamgon":
                if let cuon { ManVietView(cuon: cuon) }
            case "vo-tongquan", "vo-sapxep":
                if let cuon {
                    TongQuanTrangView(cuon: cuon, idDangMo: cuon.trangsTheoThuTu.first?.id,
                                      lanLuu: 0) { _ in }
                }
            default:
                List(dong, id: \.self) { Text($0).font(.system(size: 13, design: .monospaced)) }
            }
        }
        .onAppear {
            switch cheDo {
            case "vo-thu": dong = ThuVo.chayHet()
            case "vo-kiem": dong = ThuVo.tomTatKhoThat(kho)
            case "vo-lamgon-thu":
                dong = ThuLamGon.chayHet()
                for d in dong { NSLog("[THU-LAMGON] %@", d) }
            case "vo-lamgon": cuon = ThuVo.gieoTrangXau(kho)
            default:
                UserDefaults.standard.set(cheDo == "vo-sapxep" ? "danhSach" : "luoi",
                                          forKey: "vo.tongquan.chedo")
                cuon = ThuVo.gieoNeuTrong(kho)
                _ = ThuVo.tomTatKhoThat(kho)
            }
        }
    }
}
#endif

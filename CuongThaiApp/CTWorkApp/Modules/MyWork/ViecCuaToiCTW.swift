import SwiftUI

// MARK: - Tab Việc của tôi (+ tìm kiếm toàn cục)

struct ViecCuaToiCTW: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tim = ""
    /// Ô tìm đang mở ⇒ hiện tìm gần đây + bộ lọc (đợt B, như trang Search của web).
    @State private var timMo = false
    @State private var locTim = BoLocTimCTW()
    /// 0 = Issues (My Work của lõi) · 1 = Agenda (`/me/agenda`, xuyên dự án) · 2 = Bảng tin (gộp mọi không gian/dự án —
    /// Modules/BangTin; chỉ khi máy chủ có bảng tin và người dùng đọc được ít nhất một phạm vi).
    @AppStorage("ctw.myWork.che") private var che = 0
    @ObservedObject private var kho = KhoBangTinCTW.shared

    var body: some View {
        Group {
            if timMo || locTim.coLoc || tim.trimmingCharacters(in: .whitespaces).count >= 2 {
                TimKiemNangCaoCTW(q: tim, loc: $locTim) { tim = $0 }
            } else {
                // Công tắc nằm TRONG danh sách (hàng đầu) ⇒ cùng lề với ô tìm và các thẻ — trước 20/10 nó đệm 16 pt
                // riêng nên rộng hơn ô tìm và lệch với ô đếm (ảnh chủ app trên iPhone Pro Max, lề hệ thống 20 pt).
                if che == 2 && kho.hien {
                    BangTinCTW(cheDo: .gop, loc: .gop, dau: AnyView(congTac))
                } else if che == 1 {
                    AgendaCuaToiCTW(dau: AnyView(congTac))
                } else {
                    DanhSachViecCTW(dau: AnyView(congTac))
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("My Work")
        .searchable(text: $tim, isPresented: $timMo, prompt: "Search issues in all projects")
        .onSubmit(of: .search) { TimGanDayCTW.shared.them(tim) }
        // "Tìm mọi thẻ khớp …" từ màn Tìm mọi thứ ⇒ mở ô tìm này với chữ sẵn.
        .onReceive(DieuHuongTimCTW.shared.$chuMyWork) { c in
            guard let c else { return }
            DieuHuongTimCTW.shared.chuMyWork = nil
            nganXep.veDau()
            tim = c
            timMo = true
        }
        #if DEBUG
        .onAppear { if XemThuCTW.man?.lowercased() == "timkiem" { timMo = true; locTim.nhom = ["TODO", "IN_PROGRESS"]; locTim.capNhat = 7; tim = "push" } }
        #endif
        // Đích từ thông báo/đường dẫn. `.task(id:)` vì cờ có thể được đặt
        // TRƯỚC khi màn tồn tại (mở nguội từ thông báo).
        // Bảng tin: bài cần mở (thông báo đẩy, đường dẫn sâu) / bảng tin không gian (bảng chọn dự án). Xoá cờ ở CUỐI.
        .task(id: kho.canMo) {
            guard let r = kho.canMo else { return }
            defer { kho.canMo = nil }
            tim = ""
            timMo = false
            var p = NavigationPath()
            p.append(r)
            nganXep.duong = p
        }
        // Máy chủ cũ (không có bảng tin) / mất quyền ⇒ phân đoạn Bảng tin biến mất, về Issues.
        .onChange(of: kho.hien) { _, co in if !co && che == 2 { che = 0 } }
        .task(id: app.ctWorkDich) {
            guard let d = app.ctWorkDich else { return }
            app.ctWorkDich = nil
            tim = ""
            var p = NavigationPath()
            if let ma = d.maDuAn, let so = d.so {
                p.append(CTWRoute.theTheoMa(slug: d.slug, ma: ma, so: so))
            } else if let ma = d.maDuAn {
                p.append(CTWRoute.bangTheoMa(slug: d.slug, ma: ma))
            } else {
                p.append(CTWRoute.khongGian(slug: d.slug, ten: d.slug))
            }
            nganXep.duong = p
        }
    }
}

extension ViecCuaToiCTW {
    fileprivate var congTac: some View {
        VStack(spacing: 10) {
            Picker("View", selection: $che) {
                Text("Issues").tag(0)
                Text("Agenda").tag(1)
                if kho.hien { Text("Feed").tag(2) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("mywork.views")
            // "Hôm nay tôi nên làm gì?" (21/10/2026): mở CuongMini của dự án đang chọn và hỏi ngay. Không ở Bảng tin.
            if che != 2, let l = app.luaChon, CuongMini.coTheDung(app.cauHinhDuAn) {
                TheCuongMiniCTW(pid: l.pid, maDuAn: l.maDuAn, tenDuAn: l.tenDuAn, homNay: true)
            }
        }
        .padding(.bottom, 4)
    }
}

// Kết quả tìm toàn cục + bộ lọc + tìm gần đây: `TimKiemNangCaoCTW.swift` (đợt B, 21/10/2026).

import SwiftUI

// MARK: - Tab Việc của tôi (+ tìm kiếm toàn cục)

struct ViecCuaToiCTW: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tim = ""
    /// Ô tìm đang mở ⇒ hiện tìm gần đây + bộ lọc (đợt B, như trang Search của web).
    @State private var timMo = false
    @State private var locTim = BoLocTimCTW()
    /// 0 = Issues (My Work của lõi) · 1 = Agenda (`/me/agenda`, xuyên dự án).
    @AppStorage("ctw.myWork.che") private var che = 0

    var body: some View {
        Group {
            if timMo || locTim.coLoc || tim.trimmingCharacters(in: .whitespaces).count >= 2 {
                TimKiemNangCaoCTW(q: tim, loc: $locTim) { tim = $0 }
            } else {
                // Công tắc nằm TRONG danh sách (hàng đầu) ⇒ cùng lề với ô tìm và các thẻ — trước 20/10 nó đệm 16 pt
                // riêng nên rộng hơn ô tìm và lệch với ô đếm (ảnh chủ app trên iPhone Pro Max, lề hệ thống 20 pt).
                if che == 1 { AgendaCuaToiCTW(dau: AnyView(congTac)) } else { DanhSachViecCTW(dau: AnyView(congTac)) }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("My Work")
        .searchable(text: $tim, isPresented: $timMo, prompt: "Search issues in all projects")
        .onSubmit(of: .search) { TimGanDayCTW.shared.them(tim) }
        #if DEBUG
        .onAppear { if XemThuCTW.man?.lowercased() == "timkiem" { timMo = true; locTim.nhom = ["TODO", "IN_PROGRESS"]; locTim.capNhat = 7; tim = "push" } }
        #endif
        // Đích từ thông báo/đường dẫn. `.task(id:)` vì cờ có thể được đặt
        // TRƯỚC khi màn tồn tại (mở nguội từ thông báo).
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
        Picker("View", selection: $che) {
            Text("Issues").tag(0)
            Text("Agenda").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 4)
    }
}

// Kết quả tìm toàn cục + bộ lọc + tìm gần đây: `TimKiemNangCaoCTW.swift` (đợt B, 21/10/2026).

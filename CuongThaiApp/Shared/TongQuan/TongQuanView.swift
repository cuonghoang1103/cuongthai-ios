import SwiftUI

/// Trang chủ mới: bảng điều khiển việc + lịch học, thay cho bảng tin.
///
/// Bảng tin KHÔNG bị bỏ — nó chuyển vào nút trên thanh tiêu đề và một thẻ
/// trong "Đi nhanh". Xoá hẳn thì mọi màn liên quan (chi tiết bài, bình luận,
/// thả cảm xúc) thành mã chết mà vẫn phải biên dịch.
struct TongQuanView: View {
    @StateObject private var vm = TongQuanVM()
    @EnvironmentObject private var appState: AppState
    @State private var oViecMoi = ""
    @State private var moLich = false
    @State private var moFeed = false
    @State private var moCon: Set<Int> = []
    @State private var monDangMo: String?
    @FocusState private var dangGo: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    dauTrang
                    theSo
                    if vm.buoiKeTiep != nil || !vm.hocHomNay.isEmpty { khoiHocHomNay }
                    khoiViec
                    if !vm.viecSapToi.isEmpty { khoiSapToi }
                    khoiDiNhanh
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }
            .background(AppColors.backgroundPrimary)
            .refreshable { await vm.nap(); await vm.napLich() }
            .navigationTitle(T("Tổng quan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Spacing.md) {
                        Button { moLich = true } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel(T("Thời khoá biểu"))

                        // Bảng tin vẫn ở đây — không mất, chỉ đổi chỗ.
                        Button { moFeed = true } label: {
                            Image(systemName: "square.stack")
                        }
                        .accessibilityLabel(T("Bảng tin"))
                    }
                    .foregroundColor(AppColors.textPrimary)
                }
            }
            .navigationDestination(isPresented: $moLich) { LichTuanView(vm: vm) }
            .navigationDestination(isPresented: $moFeed) { HomeView() }
            .sheet(item: Binding(
                get: { monDangMo.map(MonMo.init) },
                set: { monDangMo = $0?.ma })) { m in
                HocGiChoMonView(dsMon: m.ma.components(separatedBy: ","), vm: vm)
            }
            .alert(T("Đã kết thúc ngày"), isPresented: Binding(
                get: { vm.vuaCong != nil }, set: { if !$0 { vm.vuaCong = nil } })) {
                Button("OK") { vm.vuaCong = nil }
            } message: {
                Text(String(format: T("Bạn nhận được %d EXP."), vm.vuaCong ?? 0))
            }
            .task {
                await vm.nap()
                await vm.napLich()
            }
        }
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loiChao)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(ngayGio)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            vongCapDo
        }
    }

    /// Lời chào theo GIỜ MÁY. Bản desktop chào "Khuya rồi" lúc 3 giờ sáng —
    /// giữ đúng giọng đó.
    private var loiChao: String {
        let h = Calendar.current.component(.hour, from: Date())
        let ten = appState.currentUser?.displayName
            ?? appState.currentUser?.username ?? ""
        let c: String
        switch h {
        case 0..<5:   c = T("Khuya rồi")
        case 5..<11:  c = T("Chào buổi sáng")
        case 11..<13: c = T("Buổi trưa")
        case 13..<18: c = T("Chào buổi chiều")
        default:      c = T("Chào buổi tối")
        }
        return ten.isEmpty ? c : "\(c), \(ten)"
    }

    private var ngayGio: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: QuanLyNgonNguApp.shared.ngonNgu == .anh ? "en_US" : "vi_VN")
        f.setLocalizedDateFormatFromTemplate("EEEE d/M/yyyy")
        let g = DateFormatter(); g.dateFormat = "HH:mm"
        return "\(f.string(from: Date())) · \(g.string(from: Date()))"
    }

    private var vongCapDo: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle().stroke(AppColors.backgroundTertiary, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: vm.trangThai.phanTram)
                    .stroke(LinearGradient(colors: [AppColors.primary, AppColors.primaryLight],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: vm.trangThai.phanTram)
                VStack(spacing: -2) {
                    Text("\(vm.trangThai.level)")
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .foregroundColor(AppColors.textPrimary)
                    Text(T("cấp")).font(.system(size: 9)).foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(vm.trangThai.exp)")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundColor(AppColors.textPrimary)
                Text("/\(TrangThaiTongQuan.expMoiCap) EXP")
                    .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                Text(String(format: T("tới cấp %d"), vm.trangThai.level + 1))
                    .font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
            }
        }
    }

    // MARK: Bốn thẻ số

    private var theSo: some View {
        // Lưới 2×2 thay vì một hàng 4 cột: trên máy hẹp bốn thẻ ngang thì chữ
        // "tin nhắn chưa đọc" bị bóp còn hai dòng rưỡi.
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm),
                            GridItem(.flexible(), spacing: Spacing.sm)], spacing: Spacing.sm) {
            the("\(vm.soXong)/\(vm.soTong)", T("việc hôm nay"), "checklist", AppColors.primary)
            the("\(appState.unreadMessages)", T("tin nhắn chưa đọc"), "message", AppColors.secondary)
            the("\(appState.unreadNotifications)", T("thông báo mới"), "bell", AppColors.warning)
            // Chuỗi ngày THAY thẻ "tổng EXP": EXP và cấp đã nằm trong vòng
            // tròn ở đầu trang, để lại một thẻ nữa là nói cùng một chuyện hai
            // lần. Chuỗi là con số duy nhất nói về THÓI QUEN chứ không về
            // điểm — đúng thứ người dùng đang thiếu.
            the(vm.chuoiNgay > 0 ? "\(vm.chuoiNgay)" : "—",
                vm.chuoiNgay > 0 ? T("ngày liên tiếp") : T("chưa có chuỗi"),
                "flame", vm.chuoiNgay > 0 ? AppColors.error : AppColors.textTertiary)
        }
    }

    private func the(_ so: String, _ nhan: String, _ bt: String, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: bt).font(.system(size: 14)).foregroundColor(mau)
            Text(so)
                .font(.system(size: 26, weight: .bold).monospacedDigit())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(nhan)
                .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(mau.opacity(0.22), lineWidth: 1))
        )
    }

    // MARK: Học hôm nay

    private var khoiHocHomNay: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(T("HỌC HÔM NAY"))
                    .font(.system(size: 11, weight: .heavy)).tracking(1)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                Button(T("Cả tuần")) { moLich = true }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.primary)
            }

            if vm.hocHomNay.isEmpty {
                Text(T("Hôm nay không có buổi học nào."))
                    .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
            } else {
                ForEach(vm.hocHomNay) { b in
                    HangBuoiHoc(buoi: b, keTiep: b.id == vm.buoiKeTiep?.id)
                }
            }
        }
    }

    // MARK: Việc

    private var khoiViec: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Thanh phạm vi cuộn ngang: 5 mục tiếng Việt không vừa màn hẹp.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PhamViViec.allCases) { p in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { vm.pham = p }
                            Haptics.cham()
                        } label: {
                            Text(p.ten)
                                .font(.system(size: 13.5, weight: vm.pham == p ? .semibold : .regular))
                                .foregroundColor(vm.pham == p ? AppColors.onPrimary : AppColors.textSecondary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(
                                    Capsule().fill(vm.pham == p ? AppColors.primary : AppColors.backgroundTertiary)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            if vm.soTong > 0 {
                HStack(spacing: Spacing.sm) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.backgroundTertiary)
                            Capsule().fill(LinearGradient(colors: [AppColors.primary, AppColors.primaryLight],
                                                          startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * CGFloat(vm.soXong) / CGFloat(max(1, vm.soTong)))
                                .animation(.easeOut(duration: 0.3), value: vm.soXong)
                        }
                    }
                    .frame(height: 6)
                    Text("\(vm.soXong)/\(vm.soTong)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            HStack(spacing: Spacing.sm) {
                TextField(String(format: T("Thêm việc cho %@…"), vm.pham.ten.lowercased()), text: $oViecMoi)
                    .font(.system(size: 15))
                    .focused($dangGo)
                    .submitLabel(.done)
                    .onSubmit { them() }
                    .padding(.horizontal, Spacing.md).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))

                Button(action: them) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.onPrimary)
                        .frame(width: 44, height: 42)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(oViecMoi.trimmingCharacters(in: .whitespaces).isEmpty
                                  ? AppColors.primary.opacity(0.4) : AppColors.primary))
                }
                .disabled(oViecMoi.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if vm.dangTai && vm.viec.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, Spacing.lg)
            } else if vm.viecHienTai.isEmpty {
                Text(vm.pham.loiMoi)
                    .font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.lg)
            } else {
                ForEach(vm.viecHienTai) { v in
                    HangViec(viec: v, con: vm.viecCon(v.id), moCon: moCon.contains(v.id),
                             batCon: { if moCon.contains(v.id) { moCon.remove(v.id) } else { moCon.insert(v.id) } },
                             moMon: { monDangMo = $0 },
                             vm: vm)
                }
            }

            // Kết thúc ngày — CHỖ DUY NHẤT cộng EXP.
            //
            // Máy chủ không cộng EXP lúc tích việc; nó cộng ở `POST /celebrate`,
            // một lần mỗi ngày, gộp EXP của mọi việc đã xong. Không có nút này
            // thì vòng cấp độ trên đầu trang đứng yên vĩnh viễn và chỉ để trang
            // trí — đo thật: tích xong một việc mà "tổng EXP" vẫn là 0.
            if vm.pham == .today && vm.coTheKetThucNgay {
                Button { Task { await vm.ketThucNgay() } } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "moon.stars.fill").font(.system(size: 13))
                        Text(T("Kết thúc ngày · nhận EXP")).font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                .padding(.top, 4)
            } else if vm.pham == .today && vm.daKetThucNgay {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 12))
                    Text(T("Đã kết thúc ngày hôm nay")).font(.system(size: 12.5))
                }
                .foregroundColor(AppColors.success)
                .frame(maxWidth: .infinity).padding(.top, 4)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func them() {
        let t = oViecMoi
        oViecMoi = ""
        dangGo = false
        Task { await vm.themViec(t) }
    }

    // MARK: Sắp tới

    /// Việc đã đặt cho những ngày tới — chủ yếu là việc ôn lặp.
    private var khoiSapToi: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Text(T("SẮP TỚI"))
                    .font(.system(size: 11, weight: .heavy)).tracking(1)
                    .foregroundColor(AppColors.textTertiary)
                Text(T("giữ để xoá"))
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary.opacity(0.7))
            }
            VStack(spacing: 0) {
                ForEach(Array(vm.viecSapToi.enumerated()), id: \.offset) { _, nhom in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(spacing: 1) {
                            Text(ngayNgan(nhom.ngay))
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundColor(AppColors.primary)
                            Text(thuNgan(nhom.ngay))
                                .font(.system(size: 9.5))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .frame(width: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(nhom.viec) { v in
                                // Giữ để XOÁ. Không có nó thì việc đặt cho
                                // ngày tương lai KHÔNG xoá được từ bất cứ đâu:
                                // danh sách "Hôm nay" lọc theo đúng ngày hôm
                                // nay, nên phải đợi tới đúng hôm đó mới đụng
                                // được vào. Đo thật khi tự dùng.
                                Text(v.title)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(1)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { await vm.xoaViec(v) }
                                        } label: {
                                            Label(T("Xoá việc"), systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)
                    if nhom.ngay != vm.viecSapToi.last?.ngay { Divider().opacity(0.3) }
                }
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }

    private func ngayNgan(_ iso: String) -> String {
        guard let d = PhamViViec.dinhDang.date(from: iso) else { return iso }
        let f = DateFormatter(); f.dateFormat = "dd/MM"
        return f.string(from: d)
    }

    private func thuNgan(_ iso: String) -> String {
        guard let d = PhamViViec.dinhDang.date(from: iso) else { return "" }
        return BuoiHoc.tenThu(BuoiHoc.thuViet(tuLich: Calendar.current.component(.weekday, from: d)))
    }

    // MARK: Đi nhanh

    private var khoiDiNhanh: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("ĐI NHANH"))
                .font(.system(size: 11, weight: .heavy)).tracking(1)
                .foregroundColor(AppColors.textTertiary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm),
                                GridItem(.flexible(), spacing: Spacing.sm)], spacing: Spacing.sm) {
                NavigationLink { LichTuanView(vm: vm) } label: {
                    theNhanh(T("Thời khoá biểu"), T("Lịch tuần · nhắc đi học"), "calendar", AppColors.primary)
                }
                NavigationLink { HomeView() } label: {
                    theNhanh(T("Bảng tin"), T("Bài viết, bình luận"), "square.stack", AppColors.secondary)
                }
            }
        }
    }

    private func theNhanh(_ ten: String, _ phu: String, _ bt: String, _ mau: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: bt).font(.system(size: 16)).foregroundColor(mau).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(ten).font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Text(phu).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}

/// Bọc danh sách mã môn (nối bằng dấu phẩy) để dùng được với `.sheet(item:)`.
private struct MonMo: Identifiable { let ma: String; var id: String { ma } }

// MARK: - Một hàng việc

private struct HangViec: View {
    let viec: ViecTongQuan
    let con: [ViecTongQuan]
    let moCon: Bool
    let batCon: () -> Void
    let moMon: (String) -> Void
    @ObservedObject var vm: TongQuanVM

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Button { Task { await vm.doiXong(viec) } } label: {
                    Image(systemName: viec.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21))
                        .foregroundColor(viec.done ? AppColors.success : AppColors.textTertiary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    // Bấm tiêu đề → "Học gì cho môn này". Chỉ mở khi tiêu đề
                    // CÓ mã môn: bấm vào "2 bài Lab" mà hiện màn tra cứu môn
                    // rỗng thì tệ hơn là không làm gì.
                    let dsMa = HocGiChoMonView.maMon(tu: viec.title)
                    if !dsMa.isEmpty {
                        Button { moMon(dsMa.joined(separator: ",")) } label: {
                            HStack(spacing: 5) {
                                Text(viec.title)
                                    .font(.system(size: 15))
                                    .foregroundColor(viec.done ? AppColors.textTertiary : AppColors.textPrimary)
                                    .strikethrough(viec.done, color: AppColors.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.primary.opacity(viec.done ? 0.35 : 0.8))
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(viec.title)
                            .font(.system(size: 15))
                            .foregroundColor(viec.done ? AppColors.textTertiary : AppColors.textPrimary)
                            .strikethrough(viec.done, color: AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 6) {
                        if let u = viec.nhanUuTien {
                            nhan(u, mau: viec.priority == 3 ? AppColors.error
                                 : viec.priority == 2 ? AppColors.warning : AppColors.textTertiary)
                        }
                        if viec.repeatMode != "none" { nhan(T("Lặp"), mau: AppColors.secondary) }
                        if !con.isEmpty {
                            Button(action: batCon) {
                                HStack(spacing: 3) {
                                    Image(systemName: moCon ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("\(con.filter(\.done).count)/\(con.count)")
                                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                }
                                .foregroundColor(AppColors.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let n = viec.note, !n.isEmpty {
                        Text(n).font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if viec.done {
                    Button { Task { await vm.xoaViec(viec) } } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(T("Xoá việc"))
                } else {
                    Text("+\(viec.exp)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.vertical, 9)

            if moCon {
                ForEach(con) { c in
                    HStack(spacing: Spacing.sm) {
                        Button { Task { await vm.doiXong(c) } } label: {
                            Image(systemName: c.done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundColor(c.done ? AppColors.success : AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        Text(c.title)
                            .font(.system(size: 13.5))
                            .foregroundColor(c.done ? AppColors.textTertiary : AppColors.textSecondary)
                            .strikethrough(c.done, color: AppColors.textTertiary)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 30).padding(.vertical, 5)
                }
            }
        }
        .contentShape(Rectangle())
        // ⚠️ KHÔNG dùng `.swipeActions` ở đây. Nó CHỈ chạy bên trong `List`;
        // gắn vào một hàng trong `VStack` thì trình biên dịch nhận, chạy
        // không lỗi, và vuốt KHÔNG làm gì cả — đo thật trên máy ảo. Danh sách
        // việc nằm trong một thẻ có nền riêng nên không thể là `List` (lồng
        // cuộn trong cuộn). Giữ `.contextMenu` (giữ để mở) và thêm nút xoá
        // hiện rõ khi việc ĐÃ XONG — lúc đó dòng không còn gì để bấm nhầm.
        .contextMenu {
            Button { Task { await vm.doiViec(viec, ["priority": viec.priority == 3 ? 0 : 3]) } } label: {
                Label(viec.priority == 3 ? T("Bỏ ưu tiên cao") : T("Ưu tiên cao"), systemImage: "flag")
            }
            Button(role: .destructive) { Task { await vm.xoaViec(viec) } } label: {
                Label(T("Xoá việc"), systemImage: "trash")
            }
        }
        Divider().opacity(0.35)
    }

    private func nhan(_ t: String, mau: Color) -> some View {
        Text(t)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(mau)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(mau.opacity(0.14)))
    }
}

// MARK: - Một hàng buổi học

struct HangBuoiHoc: View {
    let buoi: BuoiHoc
    var keTiep = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(mau).frame(width: 3.5, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(buoi.subject)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text([buoi.room, buoi.teacher].compactMap { $0?.isEmpty == false ? $0 : nil }
                        .joined(separator: " · "))
                    .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(buoi.startTime)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textPrimary)
                Text(buoi.endTime)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(AppColors.textTertiary)
            }
            if keTiep {
                Text(T("Kế tiếp"))
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(AppColors.primary))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(keTiep ? AppColors.primary.opacity(0.5) : .clear, lineWidth: 1.5))
        )
    }

    private var mau: Color {
        // Không có màu người dùng chọn thì suy từ TÊN MÔN — cùng môn luôn ra
        // cùng màu ở mọi màn, mà không phải lưu thêm gì.
        if let h = buoi.color, let c = Color(hexChuoi: h) { return c }
        let bang: [Color] = [AppColors.primary, AppColors.secondary, AppColors.accent,
                             AppColors.success, AppColors.warning, AppColors.error]
        return bang[abs(buoi.subject.hashValue) % bang.count]
    }
}

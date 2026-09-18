import SwiftUI

/// Trang chủ mới: bảng điều khiển việc + lịch học, thay cho bảng tin.
///
/// Bảng tin KHÔNG bị bỏ — nó chuyển vào nút trên thanh tiêu đề và một thẻ
/// trong "Đi nhanh". Xoá hẳn thì mọi màn liên quan (chi tiết bài, bình luận,
/// thả cảm xúc) thành mã chết mà vẫn phải biên dịch.
struct TongQuanView: View {
    @StateObject private var vm: TongQuanVM
    /// Bản thử dùng dữ liệu giả nên KHÔNG được gọi mạng: `nap()` sẽ hỏng vì
    /// chưa đăng nhập rồi xoá sạch dữ liệu vừa nhồi vào, và bàn thử thành
    /// trang trắng. Xem `ThuTongQuan` trong `ManXemThu`.
    private let banThu: Bool
    @EnvironmentObject private var appState: AppState

    init() {
        _vm = StateObject(wrappedValue: TongQuanVM())
        banThu = false
    }

    #if DEBUG
    /// Chỉ dành cho cửa xem màn hình. Không có đường nào tới đây từ bản
    /// Release — cả `init` này lẫn nơi gọi đều nằm trong `#if DEBUG`.
    init(banThu vm: TongQuanVM) {
        _vm = StateObject(wrappedValue: vm)
        banThu = true
    }
    #endif
    @State private var oViecMoi = ""
    @State private var moVo = false
    @State private var moLich = false
    @State private var moFeed = false
    @State private var moCon: Set<Int> = []
    @State private var monDangMo: String?
    /// `.sheet(item:)` chứ không `isPresented` + biến rời: hai state đổi
    /// trong cùng một hành động thì sheet có thể dựng nội dung bằng giá trị
    /// CŨ. Gói câu hỏi vào chính item là hết cửa lệch.
    @State private var moChat: MoChatAI?
    /// Buổi học đang mở chi tiết, mở từ thẻ điểm nhấn.
    @State private var buoiDangSua: BuoiHoc?
    @State private var moThongBao = false
    /// Ngày đang mở hết việc trong khối "Sắp tới".
    @State private var ngayMoRong: Set<String> = []
    @FocusState private var dangGo: Bool
    /// Cỡ lời chào. `@ScaledMetric` để nó lớn lên theo cỡ chữ hệ thống —
    /// `.font(.system(size:))` trần thì Dynamic Type không đụng tới được.
    @ScaledMetric(relativeTo: .title) private var coLoiChao: CGFloat = 27
    @ScaledMetric(relativeTo: .title3) private var coTieuDeMuc: CGFloat = 19
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

    var body: some View {
        NavigationStack {
            ScrollView {
                // Thứ tự này trả lời lần lượt bốn câu hỏi của một ngày đi
                // học: sắp tới học gì → hôm nay phải làm gì → nhờ được ai →
                // mấy hôm tới có gì. Bản cũ để lời chào, robot, ô chat và bốn
                // thẻ số lên trước, nên buổi học kế tiếp nằm dưới màn hình.
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    dauTrang
                    theKeTiep
                    // Thẻ trên đã nói buổi gần nhất rồi — in lại nguyên dòng
                    // đó ngay dưới là nói hai lần trong một màn hình.
                    if !hocHomNayConLai.isEmpty { khoiHocHomNay }
                    khoiViec
                    theCuongMini
                    if !vm.viecSapToi.isEmpty { khoiSapToi }
                    thanhTienDo
                    khoiDiNhanh
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
                // ⚠️ Bản cũ chèn `Color.clear.frame(height: 90)` để chừa chỗ
                // cho thanh tab. Thừa: `TabView` gốc đã cộng sẵn vùng an toàn
                // của thanh tab vào `ScrollView`, nên 90pt đó là một khoảng
                // trống chết cuối trang, cuộn mãi mới hết.
                .padding(.bottom, Spacing.lg)
            }
            .background(AppColors.backgroundPrimary)
            .refreshable {
                guard !banThu else { return }
                await vm.nap(); await vm.napLich()
            }
            .navigationTitle(T("Tổng quan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Spacing.md) {
                        // Vở viết tay. Trên iPad nó đã có mục riêng ở thanh
                        // bên; nút này là lối vào cho iPhone và cho iPad đang
                        // ở cửa sổ hẹp.
                        Button { moVo = true } label: {
                            Image(systemName: "book.closed")
                        }
                        .accessibilityLabel(T("Vở"))

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
            .navigationDestination(isPresented: $moVo) { NoiDungVoView() }
            .navigationDestination(isPresented: $moLich) { LichTuanView(vm: vm) }
            .navigationDestination(isPresented: $moFeed) { HomeView() }
            // Sheet chứ không đẩy màn: `NotificationsView` tự mang nút "Đóng"
            // (nó vốn được `HomeView` mở dạng sheet), nên đẩy vào stack thì
            // trên cùng có HAI đường quay lại — mũi tên và "Đóng".
            .sheet(isPresented: $moThongBao) { NotificationsView() }
            .sheet(item: $buoiDangSua) { b in
                NavigationStack { SuaBuoiHocView(vm: vm, buoi: b) }
            }
            .sheet(item: $moChat) { m in
                AIChatView(cauMoDau: m.cau, bacBanDau: .pro)
            }
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
                guard !banThu else { return }
                await vm.nap()
                await vm.napLich()
            }
        }
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(loiChao)
                    .font(.system(size: coLoiChao, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                // ⚠️ Đồng hồ trong nội dung đã BỎ. Giờ hiện tại luôn nằm sẵn
                // trên thanh trạng thái của iOS, cách đây 8pt — in lại nó là
                // chiếm chỗ để nói một thứ người dùng đang nhìn thấy. Cái
                // ĐÁNG nói là còn bao lâu nữa vào học, và nó nằm ở thẻ dưới.
                Text(ngayNgan)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            nutThongBao
        }
    }

    /// Chuông + số chưa đọc. Đây là chỗ con số "thông báo mới" chuyển về sau
    /// khi bỏ lưới bốn thẻ số — một huy hiệu trên đúng cái nút mở nó, thay vì
    /// một thẻ to bằng nắm tay nằm cách nút đó nửa màn hình.
    private var nutThongBao: some View {
        Button { moThongBao = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppColors.backgroundCard))
                    .overlay(Circle().strokeBorder(AppColors.border, lineWidth: 1))

                if appState.unreadNotifications > 0 {
                    Text(appState.unreadNotifications > 99 ? "99+"
                         : "\(appState.unreadNotifications)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundColor(AppColors.onPrimary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.error))
                        .offset(x: 3, y: -1)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.unreadNotifications > 0
            ? String(format: T("Thông báo · %d chưa đọc"), appState.unreadNotifications)
            : T("Thông báo"))
    }

    /// Lời chào theo GIỜ MÁY. Bản desktop chào "Khuya rồi" lúc 3 giờ sáng —
    /// giữ đúng giọng đó. Tên lấy từ hồ sơ đang đăng nhập, không gõ cứng.
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

    /// "Thứ Tư, 9/9/2026".
    private var ngayNgan: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: QuanLyNgonNguApp.shared.ngonNgu == .anh ? "en_US" : "vi_VN")
        f.setLocalizedDateFormatFromTemplate("EEEE d/M/yyyy")
        return f.string(from: Date())
    }

    // MARK: Buổi học kế tiếp — thẻ điểm nhấn

    /// Nhịp 20 giây: đủ để con số phút không lệch quá lâu, mà không dựng lại
    /// view mỗi giây (tốn pin cho thứ chỉ đổi mỗi phút).
    private var theKeTiep: some View {
        TimelineView(.periodic(from: .now, by: 20)) { moc in
            let phut = TrangThaiBuoi.phutTrongNgay(moc.date)
            let thu = BuoiHoc.thuViet(
                tuLich: Calendar.current.component(.weekday, from: moc.date))
            TheBuoiKeTiep(
                ketQua: TimBuoiKeTiep.tim(vm.buoiHoc, thuHomNay: thu, phutBayGio: phut),
                coLich: !vm.buoiHoc.isEmpty,
                hetGioHomNay: !vm.hocHomNay.isEmpty
                    && vm.hocHomNay.allSatisfy { $0.phutKetThuc <= phut },
                phutBayGio: phut,
                moChiTiet: { buoiDangSua = $0 },
                moBaiHoc: { monDangMo = $0.joined(separator: ",") },
                moLich: { moLich = true })
        }
    }

    /// Buổi đang nằm trên thẻ điểm nhấn, nếu nó thuộc HÔM NAY.
    ///
    /// Tính lại bằng `Date()` chứ không dùng mốc của `TimelineView`: lệch
    /// nhau nhiều nhất là một nhịp 20 giây, và cái giá của việc luồn mốc đó
    /// ra ngoài là phải bọc cả trang trong `TimelineView`.
    private var buoiTrenThe: BuoiHoc? {
        let phut = TrangThaiBuoi.phutTrongNgay(Date())
        let thu = BuoiHoc.thuViet(tuLich: Calendar.current.component(.weekday, from: Date()))
        guard let kq = TimBuoiKeTiep.tim(vm.buoiHoc, thuHomNay: thu, phutBayGio: phut),
              kq.soNgayNua == 0 else { return nil }
        return kq.buoi
    }

    /// Buổi học hôm nay TRỪ buổi đã nằm trên thẻ điểm nhấn.
    private var hocHomNayConLai: [BuoiHoc] {
        vm.hocHomNay.filter { $0.id != buoiTrenThe?.id }
    }

    // MARK: Tiến độ — cấp độ, EXP, chuỗi ngày

    private var thanhTienDo: some View {
        DaiCapDo(capDo: vm.trangThai.level,
                    exp: vm.trangThai.exp,
                    expMoiCap: TrangThaiTongQuan.expMoiCap,
                    phanTram: vm.trangThai.phanTram,
                    chuoiNgay: vm.chuoiNgay)
    }

    /// Robot "biết" đang là lúc nào trong ngày để đổi biểu cảm.
    ///
    /// Thứ tự ưu tiên có chủ đích: ĐANG HỌC đè lên mọi thứ khác — lúc đang
    /// ngồi trong lớp thì việc vặt đã xong hay chưa không còn là tin đáng
    /// nhìn nhất trên màn hình.
    private var tamTrangRobot: TamTrangRobot {
        let bayGio = TrangThaiBuoi.phutTrongNgay(Date())
        var somNhat: Int?
        for b in vm.hocHomNay {
            switch TrangThaiBuoi.tinh(batDau: b.startTime, ketThuc: b.endTime, bayGio: bayGio) {
            case .dangHoc:
                return .dangHoc
            case .chuaToi(let p):
                if p <= 60 { somNhat = min(somNhat ?? p, p) }
            case .daXong:
                break
            }
        }
        if let p = somNhat { return .sapVaoHoc(phut: p) }
        // Chỉ ăn mừng khi THẬT SỰ có việc và làm xong hết. `0/0` là ngày
        // chưa ghi việc nào, không phải thành tích.
        if vm.soTong > 0 && vm.soXong >= vm.soTong { return .xongViec }
        return .binhThuong
    }

    // MARK: CuongMini

    /// Vì sao trợ lý ở trang chủ chứ không bắt sang tab AI: câu hỏi hay đến
    /// đúng lúc đang nhìn lịch học ("mai thi gì?", "giảng lại chỗ này"), và
    /// bắt nhớ câu đó qua hai lần chạm là mất luôn câu hỏi.
    private var theCuongMini: some View {
        TheCuongMini(goiY: goiYCuongMini,
                     cauMoi: cauMoiCuongMini,
                     tamTrang: tamTrangRobot,
                     moChat: { moChat = MoChatAI(cau: $0) })
    }

    /// Một câu gợi ý suy TỪ DỮ LIỆU ĐÃ CÓ trên màn này — không gọi LLM nào.
    ///
    /// ⚠️ Chỗ này rất dễ trượt thành "để AI tự nghĩ một câu chào cho thân
    /// thiện". Đừng: mỗi lần mở trang chủ là một lượt gọi model có tính tiền,
    /// người dùng không hỏi gì, và câu trả về thì không kiểm được. Suy được
    /// thì nói, không suy được thì mời chung chung.
    private var goiYCuongMini: String {
        let conLai = vm.viecHienTai.filter { !$0.done }.count
        if let ma = maMonKeTiep {
            return String(format: T("Sắp học %@ — hỏi trước cho chắc."), ma)
        }
        if conLai > 0 {
            return String(format: T("Còn %d việc chưa xong. Hỏi nên làm gì trước?"), conLai)
        }
        return T("Hỏi bài, xin dàn ý ôn tập, hay nhờ sắp lịch học.")
    }

    /// Mã môn của buổi kế tiếp, nếu rút được. Dùng cho cả gợi ý lẫn câu mồi.
    private var maMonKeTiep: String? {
        let phut = TrangThaiBuoi.phutTrongNgay(Date())
        let thu = BuoiHoc.thuViet(tuLich: Calendar.current.component(.weekday, from: Date()))
        // Cố ý KHÔNG dùng `buoiTrenThe`: gợi ý vẫn có nghĩa khi buổi kế tiếp
        // rơi sang ngày mai ("Sắp học SWT301 — hỏi trước cho chắc").
        guard let kq = TimBuoiKeTiep.tim(vm.buoiHoc, thuHomNay: thu, phutBayGio: phut)
        else { return nil }
        return HocGiChoMonView.maMon(tu: "\(kq.buoi.subject) \(kq.buoi.classCode ?? "")").first
    }

    /// Câu mồi. Câu đầu gọi ĐÚNG TÊN môn sắp học khi rút được mã — câu chung
    /// chung thì ai cũng bấm một lần rồi thôi.
    private var cauMoiCuongMini: [String] {
        guard let ma = maMonKeTiep else { return CAU_MOI }
        return [String(format: T("Ôn nhanh %@"), ma)] + CAU_MOI
    }

    // MARK: Học hôm nay

    private var khoiHocHomNay: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(T("Lịch hôm nay"))
                    .font(.system(size: coTieuDeMuc, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(hocHomNayConLai.count)")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
                Spacer(minLength: 0)
                Button(T("Cả tuần")) { moLich = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .frame(minHeight: 44)
            }

            // Khối này chỉ dựng khi còn buổi nào KHÁC buổi trên thẻ, nên
            // không còn nhánh "hôm nay không có buổi nào" — câu đó đã do thẻ
            // điểm nhấn nói, và nói kỹ hơn (buổi kế tiếp rơi vào hôm nào).
            ForEach(hocHomNayConLai) { b in
                HangBuoiHoc(buoi: b, keTiep: b.id == vm.buoiKeTiep?.id)
            }
        }
    }

    // MARK: Việc

    private var khoiViec: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Tiêu đề + tiến độ trên CÙNG một hàng. Con số "0/2" trước đây là
            // một trong bốn thẻ số to đùng ở trên; nó chỉ có nghĩa khi đứng
            // ngay cạnh danh sách mà nó đang đếm.
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(tieuDeViec)
                    .font(.system(size: coTieuDeMuc, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if vm.soTong > 0 {
                    Text("\(vm.soXong)/\(vm.soTong)")
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .foregroundColor(vm.soXong >= vm.soTong
                                         ? AppColors.success : AppColors.textSecondary)
                }
                Spacer(minLength: 0)
            }

            if vm.soTong > 0 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.backgroundTertiary)
                        Capsule().fill(LinearGradient(colors: [AppColors.primary, AppColors.primaryLight],
                                                      startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * CGFloat(vm.soXong) / CGFloat(max(1, vm.soTong)))
                            .animation(giamChuyenDong ? nil : .easeOut(duration: 0.3), value: vm.soXong)
                    }
                }
                .frame(height: 5)
                .accessibilityHidden(true)
            }

            // Thanh phạm vi cuộn ngang: 5 mục tiếng Việt không vừa màn hẹp.
            // "Hôm nay" và "Tuần này" đứng đầu vì đó là hai phạm vi dùng hằng
            // ngày; tháng/quý/năm vẫn ở đây, chỉ là phải kéo thêm một đoạn.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PhamViViec.allCases) { p in
                        Button {
                            withAnimation(giamChuyenDong ? nil : .easeInOut(duration: 0.15)) {
                                vm.pham = p
                            }
                            Haptics.cham()
                        } label: {
                            Text(p.ten)
                                .font(.system(size: 13.5, weight: vm.pham == p ? .semibold : .regular))
                                .foregroundColor(vm.pham == p ? AppColors.onPrimary : AppColors.textSecondary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 34)
                                .background(
                                    Capsule().fill(vm.pham == p ? AppColors.primary : AppColors.backgroundTertiary)
                                )
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(vm.pham == p ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 2)
            }

            // Ô thêm việc gọn lại: một khung duy nhất, nút "+" nằm TRONG khung
            // thay vì một khối vuông tím rời 44×42 bên cạnh. Vẫn thêm được
            // bằng đúng một lần chạm — giấu ô nhập sau một nút thì mỗi việc
            // ghi thêm mất hai lần chạm, đắt cho thứ dùng hằng ngày.
            HStack(spacing: 4) {
                TextField(String(format: T("Thêm việc cho %@…"), vm.pham.ten.lowercased()),
                          text: $oViecMoi)
                    .font(.system(size: 15))
                    .textFieldStyle(.plain)
                    .focused($dangGo)
                    .submitLabel(.done)
                    .onSubmit { them() }
                Button(action: them) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(oViecMoi.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? AppColors.textTertiary : AppColors.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(oViecMoi.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel(T("Thêm việc"))
            }
            .padding(.leading, 12)
            .padding(.trailing, 2)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(AppColors.backgroundTertiary))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1))

            if vm.dangTai && vm.viec.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, Spacing.lg)
            } else if let loi = vm.loi, vm.viec.isEmpty {
                // Lỗi nạp trước đây KHÔNG hiện ở đâu cả: danh sách rỗng trông
                // y hệt "chưa có việc nào", nên mất mạng nhìn như ngày rảnh.
                khoiLoi(loi)
            } else if vm.viecHienTai.isEmpty {
                Text(vm.pham.loiMoi)
                    .font(.system(size: 14)).foregroundColor(AppColors.textTertiary)
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
                        Text(T("Kết thúc ngày · nhận EXP")).font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                .padding(.top, 4)
            } else if vm.pham == .today && vm.daKetThucNgay {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 12))
                    Text(T("Đã kết thúc ngày hôm nay")).font(.system(size: 13))
                }
                .foregroundColor(AppColors.success)
                .frame(maxWidth: .infinity).padding(.top, 4)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppColors.backgroundCard))
    }

    /// Tiêu đề khối việc — đổi theo phạm vi đang chọn, để đổi tab xong không
    /// tưởng là danh sách bị mất việc.
    private var tieuDeViec: String {
        vm.pham == .today ? T("Việc hôm nay")
                          : String(format: T("Việc · %@"), vm.pham.ten.lowercased())
    }

    private func khoiLoi(_ loi: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 22)).foregroundColor(AppColors.warning)
            Text(T("Chưa nạp được danh sách việc"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(loi)
                .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Button(T("Thử lại")) { Task { await vm.nap() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.primary)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
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
            HStack(alignment: .firstTextBaseline) {
                Text(T("Sắp tới"))
                    .font(.system(size: coTieuDeMuc, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
                // Xem đủ việc của những ngày tới = đổi phạm vi sang "Tháng
                // này". Đó là màn CÓ THẬT trong app, không phải một nút dẫn
                // tới thứ chưa làm.
                Button(T("Xem tất cả")) {
                    withAnimation(giamChuyenDong ? nil : .easeInOut(duration: 0.15)) {
                        vm.pham = .month
                    }
                    Haptics.cham()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.primary)
                .frame(minHeight: 44)
            }
            // ⚠️ Dòng "giữ để xoá" treo vĩnh viễn cạnh tiêu đề đã BỎ. Nó là
            // một lời mách nước phải đọc mỗi lần mở app, cho một thao tác
            // dùng vài tháng một lần. Thao tác thì GIỮ NGUYÊN: giữ vào một
            // việc vẫn ra menu Xoá — đó cũng là cử chỉ chuẩn của iOS, và là
            // đường DUY NHẤT xoá được việc đặt cho ngày mai (danh sách chính
            // lọc theo đúng ngày hôm nay).
            VStack(spacing: 0) {
                ForEach(Array(vm.viecSapToi.enumerated()), id: \.offset) { _, nhom in
                    hangNgaySapToi(nhom)
                    if nhom.ngay != vm.viecSapToi.last?.ngay { Divider().opacity(0.3) }
                }
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.backgroundCard))
        }
    }

    /// Một ngày trong khối "Sắp tới". Mặc định chỉ hiện HAI việc — ngày ôn
    /// tập dày có thể có bảy tám việc, và bảy tám dòng xám nhạt xếp chồng thì
    /// không ai đọc, chỉ làm trang chủ dài thêm.
    @ViewBuilder
    private func hangNgaySapToi(_ nhom: (ngay: String, viec: [ViecTongQuan])) -> some View {
        let moRong = ngayMoRong.contains(nhom.ngay)
        let hien = moRong ? nhom.viec : Array(nhom.viec.prefix(2))
        let con = nhom.viec.count - hien.count

        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(spacing: 1) {
                Text(ngayNgan(nhom.ngay))
                    .font(.system(size: 12.5, weight: .bold).monospacedDigit())
                    .foregroundColor(AppColors.primary)
                Text(thuNgan(nhom.ngay))
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
            }
            .frame(width: 46)
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(hien) { v in
                    Text(v.title)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await vm.xoaViec(v) }
                            } label: {
                                Label(T("Xoá việc"), systemImage: "trash")
                            }
                        }
                }
                if con > 0 || moRong {
                    Button {
                        withAnimation(giamChuyenDong ? nil : .easeInOut(duration: 0.18)) {
                            if moRong { ngayMoRong.remove(nhom.ngay) }
                            else { ngayMoRong.insert(nhom.ngay) }
                        }
                    } label: {
                        Text(moRong ? T("Thu gọn")
                                    : String(format: T("Xem thêm %d việc"), con))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                            .frame(minHeight: 34, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
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
            Text(T("Đi nhanh"))
                .font(.system(size: coTieuDeMuc, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm),
                                GridItem(.flexible(), spacing: Spacing.sm)], spacing: Spacing.sm) {
                NavigationLink { LichTuanView(vm: vm) } label: {
                    theNhanh(T("Thời khoá biểu"), T("Lịch tuần"), "calendar", AppColors.primary)
                }
                NavigationLink { HomeView() } label: {
                    theNhanh(T("Bảng tin"), T("Bài viết, bình luận"), "square.stack", AppColors.secondary)
                }
                NavigationLink { TienView() } label: {
                    theNhanh(T("Tiền nong"), T("Chi tiêu, nợ, mục tiêu"), "creditcard", AppColors.accent)
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
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1))
        )
        .contentShape(Rectangle())
    }
}

/// Bọc danh sách mã môn (nối bằng dấu phẩy) để dùng được với `.sheet(item:)`.
private struct MonMo: Identifiable { let ma: String; var id: String { ma } }

/// Bọc câu hỏi cho `.sheet(item:)`. `id` mới mỗi lần bấm nên bấm lại đúng một
/// con chip vẫn mở lại được.
private struct MoChatAI: Identifiable {
    let id = UUID()
    let cau: String?
}

/// Ba câu mồi cho thẻ chat nhanh. Chọn theo thứ hay hỏi lúc đang nhìn trang
/// chủ, chứ không phải câu "hay" nói chung.
private let CAU_MOI: [String] = [
    "Hôm nay tôi nên học gì trước?",
    "Giảng lại phần khó nhất của môn tôi đang học",
    "Cho tôi 5 câu ôn nhanh",
]

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
                        // Giờ đã đặt cho việc. Chỉ hiện khi máy chủ THẬT SỰ
                        // trả về mốc — không có thì bỏ hẳn, không in "—".
                        if let g = gioDat {
                            nhan(g, mau: AppColors.secondary)
                        }
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
                    // ⚠️ Trước đây chỉ có "+15", không đơn vị. Người mới cài
                    // app không có cách nào biết 15 đó là EXP hay phút.
                    Text(String(format: T("+%d EXP"), viec.exp))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.primary)
                        .lineLimit(1)
                        .fixedSize()
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

    /// "19:00" của `remindAt`, hoặc `dueAt` nếu không có. `nil` khi không đọc
    /// được — dùng đúng bộ đọc ISO mà `NhacViec` dùng, vì tự cắt chuỗi là mời
    /// một lỗi lệch 7 tiếng vào chỗ khó thấy nhất.
    private var gioDat: String? {
        guard let s = viec.remindAt ?? viec.dueAt, let d = NhacViec.moc(s) else { return nil }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
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

// MARK: - Trạng thái một buổi học theo đồng hồ

/// Buổi học đang ở đâu so với BÂY GIỜ.
///
/// Tách riêng khỏi View để tính được bằng phép kiểm — giờ giấc là thứ dễ sai
/// lệch-một (phút thứ 0, phút cuối, qua nửa đêm) mà nhìn mắt thường không ra.
enum TrangThaiBuoi: Equatable {
    /// Chưa tới giờ. `phut` = còn bao nhiêu phút nữa thì vào học.
    case chuaToi(phut: Int)
    /// Đang trong giờ. `conLai` = còn bao nhiêu phút thì hết;
    /// `tiLe` = đã trôi qua bao nhiêu phần (0…1) để vẽ thanh tiến độ.
    case dangHoc(conLai: Int, tiLe: Double)
    case daXong

    /// - Parameter bayGio: số phút tính từ 00:00 của hôm nay.
    static func tinh(batDau: String, ketThuc: String, bayGio: Int) -> TrangThaiBuoi {
        guard let bd = TrangThaiBuoi.phut(batDau), let kt = TrangThaiBuoi.phut(ketThuc),
              kt > bd else { return .daXong }
        if bayGio < bd { return .chuaToi(phut: bd - bayGio) }
        if bayGio >= kt { return .daXong }
        // `bayGio == bd` là phút ĐẦU của giờ học, phải tính là ĐANG HỌC —
        // để nó rơi vào `chuaToi(0)` thì thẻ hiện "còn 0 phút" suốt một phút.
        return .dangHoc(conLai: kt - bayGio,
                        tiLe: Double(bayGio - bd) / Double(kt - bd))
    }

    /// Số phút từ 00:00 của MỘT thời điểm, theo lịch/múi giờ của máy.
    static func phutTrongNgay(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// "HH:mm" → số phút từ 00:00. Trả `nil` nếu chuỗi không đúng dạng.
    static func phut(_ hhmm: String) -> Int? {
        let p = hhmm.split(separator: ":")
        guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }

    /// "45 phút" · "1 giờ 05" — bỏ phần giờ khi dưới 60 để đỡ rườm.
    static func doDai(_ phut: Int) -> String {
        if phut < 60 { return String(format: T("%d phút"), phut) }
        let g = phut / 60, p = phut % 60
        return p == 0 ? String(format: T("%d giờ"), g)
                      : String(format: T("%d giờ %02d"), g, p)
    }
}

struct HangBuoiHoc: View {
    let buoi: BuoiHoc
    var keTiep = false

    var body: some View {
        // Đồng hồ nhịp 20 giây: đủ để con số phút không bao giờ lệch quá lâu,
        // mà không dựng lại view mỗi giây (tốn pin cho thứ chỉ đổi mỗi phút).
        TimelineView(.periodic(from: .now, by: 20)) { moc in
            than(TrangThaiBuoi.tinh(batDau: buoi.startTime, ketThuc: buoi.endTime,
                                    bayGio: TrangThaiBuoi.phutTrongNgay(moc.date)))
        }
    }

    @ViewBuilder
    private func than(_ tt: TrangThaiBuoi) -> some View {
        let dangHoc: Bool = { if case .dangHoc = tt { return true }; return false }()
        let daXong: Bool  = { if case .daXong  = tt { return true }; return false }()

        VStack(spacing: 8) {
            HStack(spacing: Spacing.md) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(mau).frame(width: dangHoc ? 5 : 3.5, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(buoi.subject)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        if dangHoc { chamDangHoc }
                    }
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
                if keTiep && !dangHoc && !daXong {
                    Text(T("Kế tiếp"))
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(AppColors.onPrimary)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.primary))
                }
            }

            dongDem(tt)
        }
        .padding(Spacing.md)
        .background(nen(dangHoc: dangHoc))
        // Buổi đã qua thì mờ đi — mắt không phải lọc thủ công xem cái nào
        // còn phải đi học.
        .opacity(daXong ? 0.5 : 1)
    }

    /// Chấm xanh nhấp nháy — dấu hiệu "đang diễn ra" quen thuộc.
    private var chamDangHoc: some View {
        TimelineView(.periodic(from: .now, by: 1)) { m in
            let sang = Int(m.date.timeIntervalSince1970) % 2 == 0
            Circle()
                .fill(AppColors.success)
                .frame(width: 7, height: 7)
                .shadow(color: AppColors.success.opacity(sang ? 0.9 : 0.2),
                        radius: sang ? 5 : 1)
                .opacity(sang ? 1 : 0.55)
                .animation(.easeInOut(duration: 0.9), value: sang)
        }
    }

    /// Hàng dưới: đếm ngược tới giờ vào, hoặc đếm ngược tới giờ tan + tiến độ.
    @ViewBuilder
    private func dongDem(_ tt: TrangThaiBuoi) -> some View {
        switch tt {
        case .chuaToi(let phut):
            // ⚠️ Bản đầu giấu đếm ngược khi còn hơn 3 tiếng, vì tôi cho rằng
            // "còn 5 giờ 49" là thừa. Sai: người dùng xem lịch lúc 1–2 giờ
            // sáng để biết mai mấy giờ phải dậy, và đó CHÍNH LÀ lúc con số
            // xa nhất lại có ích nhất. Nay luôn hiện.
            HStack(spacing: 5) {
                Image(systemName: phut <= 15 ? "figure.walk" : "hourglass")
                    .font(.system(size: 10, weight: .semibold))
                Text(String(format: T("Vào học sau %@"), TrangThaiBuoi.doDai(phut)))
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
            }
            // Dưới 15 phút thì đổi sang màu cảnh báo: đây là lúc phải
            // đứng dậy đi, không phải lúc đọc cho biết.
            .foregroundColor(phut <= 15 ? AppColors.warning : AppColors.primary)

        case .dangHoc(let conLai, let tiLe):
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(T("ĐANG HỌC"))
                        .font(.system(size: 10, weight: .heavy)).tracking(0.5)
                    Spacer(minLength: 0)
                    Text(String(format: T("còn %@"), TrangThaiBuoi.doDai(conLai)))
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                }
                .foregroundColor(AppColors.success)

                // Thanh tiến độ: nhìn một cái biết đang ở đầu hay cuối buổi.
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.success.opacity(0.18))
                        Capsule().fill(AppColors.success)
                            .frame(width: max(3, g.size.width * tiLe))
                    }
                }
                .frame(height: 4)
            }

        case .daXong:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                Text(T("Đã tan"))
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundColor(AppColors.textTertiary)
        }
    }

    /// Khung riêng khi đang học: nền pha màu thành công + viền dày hơn, để
    /// liếc một cái là biết "giờ này mình đang trong lớp".
    @ViewBuilder
    private func nen(dangHoc: Bool) -> some View {
        RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(dangHoc
                  ? AnyShapeStyle(LinearGradient(
                        colors: [AppColors.success.opacity(0.16),
                                 AppColors.backgroundCard],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                  : AnyShapeStyle(AppColors.backgroundCard))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(dangHoc ? AppColors.success.opacity(0.75)
                            : (keTiep ? AppColors.primary.opacity(0.5) : .clear),
                            lineWidth: dangHoc ? 2 : 1.5)
            )
            .shadow(color: dangHoc ? AppColors.success.opacity(0.22) : .clear,
                    radius: 10, y: 3)
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

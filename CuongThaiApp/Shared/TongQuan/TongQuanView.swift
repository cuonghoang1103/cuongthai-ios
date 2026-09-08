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
    /// `.sheet(item:)` chứ không `isPresented` + biến rời: hai state đổi
    /// trong cùng một hành động thì sheet có thể dựng nội dung bằng giá trị
    /// CŨ. Gói câu hỏi vào chính item là hết cửa lệch.
    @State private var moChat: MoChatAI?
    @State private var oChat = ""
    @FocusState private var dangGo: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    dauTrang
                    // Robot chào mừng — bản iOS của con robot trên web, vẽ
                    // thẳng bằng SwiftUI Shape nên không cần tài nguyên ảnh.
                    RobotChaoMung(ten: appState.currentUser?.displayName
                                  ?? appState.currentUser?.username,
                                  tamTrang: tamTrangRobot)
                    khoiChatNhanh
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
                // Ngày + giờ là thứ người dùng liếc nhanh nhất ở màn này —
                // trước đây nó xám 13pt, chìm nghỉm dưới lời chào 24pt đậm.
                // Nay tách làm hai viên: NGÀY màu nhấn, GIỜ màu nhấn phụ, để
                // mắt bắt được ngay cả khi chỉ liếc qua.
                HStack(spacing: 6) {
                    Label(ngayNgan, systemImage: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.primary.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(AppColors.primary.opacity(0.30), lineWidth: 1))

                    Label(gioNgan, systemImage: "clock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.secondary)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.secondary.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(AppColors.secondary.opacity(0.30), lineWidth: 1))
                }
                .labelStyle(.titleAndIcon)
                .padding(.top, 2)
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

    /// Chỉ NGÀY: "Thứ Tư, 9/9/2026".
    private var ngayNgan: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: QuanLyNgonNguApp.shared.ngonNgu == .anh ? "en_US" : "vi_VN")
        f.setLocalizedDateFormatFromTemplate("EEEE d/M/yyyy")
        return f.string(from: Date())
    }

    /// Chỉ GIỜ: "01:28".
    private var gioNgan: String {
        let g = DateFormatter(); g.dateFormat = "HH:mm"
        return g.string(from: Date())
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

    // MARK: Chat nhanh với CuongMini Pro

    /// Vì sao ở trang chủ chứ không để người dùng tự sang tab AI: câu hỏi
    /// hay đến lúc đang nhìn lịch học ("mai thi gì?", "giảng lại chỗ này"),
    /// và bắt họ nhớ câu đó qua hai lần chạm là mất luôn câu hỏi.
    private var khoiChatNhanh: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // ⚠️ Vùng bấm chỉ đặt ở HÀNG TIÊU ĐỀ. Bản đầu đặt
            // `.onTapGesture` lên cả thẻ, và nó GIÀNH mất cú bấm của các con
            // chip bên dưới: chat vẫn mở, nhưng mở rỗng — nhìn như câu mồi
            // hỏng, trong khi thật ra chip chưa bao giờ được bấm.
            Button { moChat = MoChatAI(cau: nil) } label: {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.secondary)
                    Text(T("Chat nhanh với CuongMini Pro"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Ba câu mồi. Đủ ngắn để đọc hết trong một nhịp, và đều là thứ
            // hỏi được NGAY mà không phải gõ gì thêm.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(CAU_MOI, id: \.self) { c in
                        Button { moChat = MoChatAI(cau: c) } label: {
                            Text(c)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                                .padding(.horizontal, 11).padding(.vertical, 7)
                                .background(Capsule().fill(AppColors.backgroundTertiary))
                                .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 1))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }

            HStack(spacing: Spacing.sm) {
                TextField(T("Hỏi CuongMini Pro bất cứ điều gì…"), text: $oChat)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit { guiChat() }
                Button(action: guiChat) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(oChat.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? AppColors.textTertiary : AppColors.secondary)
                }
                .buttonStyle(.plain)
                .disabled(oChat.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.backgroundTertiary))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1))
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(AppColors.secondary.opacity(0.22), lineWidth: 1))
        .sheet(item: $moChat) { m in
            AIChatView(cauMoDau: m.cau, bacBanDau: .pro)
        }
    }

    private func guiChat() {
        let c = oChat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        oChat = ""
        dangGo = false
        moChat = MoChatAI(cau: c)
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
            // Quá xa thì không hiện — "còn 9 giờ 40" chẳng giúp gì, chỉ chật chỗ.
            if phut <= 180 {
                HStack(spacing: 5) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 10, weight: .semibold))
                    Text(String(format: T("Vào học sau %@"), TrangThaiBuoi.doDai(phut)))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 0)
                }
                // Dưới 15 phút thì đổi sang màu cảnh báo: đây là lúc phải
                // đứng dậy đi, không phải lúc đọc cho biết.
                .foregroundColor(phut <= 15 ? AppColors.warning : AppColors.primary)
            }

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

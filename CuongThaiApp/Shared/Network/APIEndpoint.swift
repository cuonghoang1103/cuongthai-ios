import Foundation

// MARK: - API Endpoint
enum APIEndpoint {
    /// Đường dẫn ghép tay — app **Admin** dùng.
    ///
    /// Khu quản trị có hơn 50 endpoint, nằm rải ở `admin.routes`,
    /// `shop.routes`, `commerceAdmin.routes`… và chúng đổi theo backend. Khai
    /// một `case` cho từng cái nghĩa là chép lại backend lần thứ hai rồi phải
    /// nhớ đồng bộ tay mãi mãi. App admin chỉ mình chủ dùng nên đổi đường dẫn
    /// một dòng rẻ hơn nhiều so với giữ hai bản khai.
    ///
    /// ⚠️ App CHÍNH đừng dùng case này: ở đó đường dẫn có `case` riêng là cố
    /// ý — sai chính tả bị `tsc` của Swift bắt lúc dịch, còn chuỗi thì phải
    /// chạy mới biết.
    case tuyChinh(duong: String, phuongThuc: String, than: [String: Any]?)

    // ─── Vở viết tay (iPad · PencilKit) ───
    // Khai `case` riêng chứ KHÔNG dùng `.tuyChinh`: đây là app chính, và sai
    // một ký tự trong đường dẫn thì phải chạy mới biết.
    case voLayCay
    case voDongBoCay(mons: [[String: Any]])
    case voXinDuongDay(trangId: Int, coAnhXemTruoc: Bool)
    case voXinDuongNen(sha256: String, duoi: String, soByte: Int)
    case voXacNhanNet(trangId: Int, than: [String: Any])
    case voXoaTrang(clientIds: [String])
    case voXoaCuon(clientId: String)

    // Auth
    case login(username: String, password: String, captchaToken: String?)
    case register(username: String, email: String, password: String, fullName: String?, captchaToken: String?)
    /// Sign in with Apple / OAuth exchange — see AppleSignIn.swift.
    case oauthToken([String: Any])
    case changePassword(current: String, new: String)
    case refreshToken(String)

    // Profile
    case getProfile

    // ── Tổng quan (việc) + Thời khoá biểu ──────────────────────────────
    /// `homNay` là ngày theo GIỜ MÁY. Máy chủ cần nó để sinh việc lặp đúng
    /// kỳ — thiếu thì nó lùi về ngày UTC và ở UTC+7 sẽ lệch mất 7 tiếng đầu
    /// ngày. Xem `PhamViViec.moc`.
    case tongQuan(homNay: String)
    case themViec([String: Any])
    case suaViec(id: Int, [String: Any])
    case xoaViec(id: Int)
    /// Kết thúc ngày: máy chủ cộng EXP của mọi việc ĐÃ XONG hôm nay, một lần
    /// mỗi ngày. Không gọi nó thì EXP và cấp độ đứng yên vĩnh viễn.
    case ketThucNgay(homNay: String)
    /// Tải toàn bộ dữ liệu cá nhân (quyền chủ thể dữ liệu, Nghị định 13/2023).
    /// Máy chủ đã có từ lâu; app chưa bao giờ gọi.
    case taiDuLieuCuaToi
    case lichHoc(ngay: String?)
    case themBuoiHoc([String: Any])
    case suaBuoiHoc(id: Int, [String: Any])
    case xoaBuoiHoc(id: Int)
    case nhapLichHoc(items: [[String: Any]], thayThe: Bool)
    /// Điểm danh — API do phiên khác dựng (`ClassAttendance`), iOS dùng lại.
    case diemDanhTrongKhoang(tu: String, den: String)
    case chamDiemDanh(id: Int, [String: Any])
    // Kỳ học + lịch thi
    case dsHocKy
    case themHocKy([String: Any])
    case suaHocKy(id: Int, [String: Any])
    case xoaHocKy(id: Int)
    case dsLichThi(tu: String?, den: String?)
    case themBuoiThi([String: Any])
    case suaBuoiThi(id: Int, [String: Any])
    case xoaBuoiThi(id: Int)
    case updateProfile([String: Any])
    case getDeletionRequest
    case requestDeletion(reason: String?)
    case cancelDeletionRequest

    // Feed
    /// Bảng tin. `hashtag` lọc theo một thẻ (dùng cho từng loạt bài),
    /// `excludeSeries` thì ngược lại — bỏ hẳn bài của MỌI loạt, để bảng tin
    /// chung không bị 135 bài học dìm mất bài thường.
    /// (Swift không cho enum case có tham số mặc định, nên phải truyền đủ.)
    case getFeed(cursor: Int?, limit: Int, type: String?, videoCategoryId: Int?,
                 hashtag: String?, excludeSeries: Bool)
    /// Số bài mỗi tab. `excludeSeries` phải truyền GIỐNG hệt lúc gọi `getFeed`,
    /// không thì con số trên tab đếm cả bài của các loạt mà danh sách bên dưới
    /// lại không hiện chúng.
    case getPostCounts(excludeSeries: Bool)
    /// Mục lục một loạt bài nhiều kỳ: [{ day, postId, title }]. Công khai.
    case getSeries(slug: String)
    case createPost([String: Any])
    case deletePost(id: Int)
    case likePost(id: Int)
    case unlikePost(id: Int)
    /// ⚠️⚠️ **POST, không phải PATCH.** Backend khai
    /// `router.post('/posts/:id/react')`. App gửi PATCH suốt từ đầu ⇒ mọi lượt
    /// thả cảm xúc đều nhận `404 "Route PATCH … not found"`, tức **cả bộ chọn
    /// cảm xúc chưa từng hoạt động** — mà 404 thì giao diện lặng thinh, không
    /// khác gì mạng chậm. Phát hiện 22/08/2026 bằng cách đối chiếu TOÀN BỘ 173
    /// endpoint của app với 1.685 route backend; đây là cái duy nhất lệch.
    case reactPost(id: Int, type: String)
    case getComments(postId: Int, cursor: Int?, limit: Int)
    case createComment(postId: Int, content: String, parentId: Int?, mediaUrl: String? = nil, mediaKind: String? = nil)
    /// Thích bình luận — máy chủ TỰ ĐẢO trạng thái, một đường cho cả hai chiều.
    case likeComment(id: Int)
    case savePost(id: Int, folder: String?)
    case unsavePost(id: Int)

    // Users
    case getUserProfile(id: Int)
    case getUserPosts(id: Int, cursor: Int?, limit: Int)
    case followUser(id: Int)
    case unfollowUser(id: Int)
    case searchUsers(q: String)

    /// Tìm kiếm HỢP NHẤT — một lượt gọi trả về cả người, bài viết, khoá học,
    /// nhạc. Thay cho việc gọi bốn nơi rồi tự ghép.
    ///
    /// ⚠️ ĐỪNG quay lại dùng `.searchUsers` cho màn Tìm kiếm: đó là API cho
    /// `@mention` — trần cứng 8 kết quả, LOẠI chính mình, và trả về MẢNG
    /// PHẲNG chứ không phải `{users: […]}`. App từng giải mã sai hình dạng đó
    /// nên màn Tìm kiếm chưa từng chạy, mà không báo lỗi gì.
    case timKiem(q: String, loai: String)

    // Messaging
    case getThreads(cursor: Int?, limit: Int)
    case getMessages(threadId: Int, cursor: Int?, limit: Int)
    case sendMessage(threadId: Int, content: String, type: String, parentMessageId: Int?)
    /// Gửi tin có file đính kèm. Máy chủ nhận `fileIds: [Int]` (id hàng
    /// `FileAttachment` do `POST /messages/upload` tạo ra), KHÔNG nhận URL.
    case sendMessageWithFiles(threadId: Int, content: String, fileIds: [Int])
    /// Mốc đọc của từng người trong hội thoại — để vẽ "Đã xem".
    case getThreadReads(threadId: Int)
    /// Gửi GIF / nhãn dán. Máy chủ nhận `media: {url, kind}` với kind là
    /// `gif` hoặc `sticker` — KHÔNG phải file đính kèm.
    case sendMessageMedia(threadId: Int, url: String, kind: String)
    /// Bật/tắt một cảm xúc trên tin nhắn (gọi lại cùng emoji là gỡ).
    case toggleMessageReaction(messageId: Int, emoji: String)
    case recallMessage(messageId: Int)
    case deleteMessage(messageId: Int)
    /// Tìm GIF qua proxy GIPHY của backend. `q` rỗng = đang thịnh hành.
    case searchGifs(q: String)
    /// Đổi MỘT ô tuỳ chọn của hội thoại. `slot` là một trong
    /// `pinnedAt` / `mutedUntil` / `archivedAt` / `markedUnreadAt`;
    /// `value` là mốc ISO, hoặc `nil` để xoá ô đó.
    case datTuyChonHoiThoai(threadId: Int, slot: String, value: String?)
    case boLuuTruHoiThoai(threadId: Int)
    case danhDauChuaDoc(threadId: Int)
    /// Đặt/xoá biệt danh cho người kia trong hội thoại. `alias` rỗng = xoá.
    case datBietDanh(threadId: Int, targetId: Int, alias: String)
    /// Một hội thoại. ⚠️ Đường này gọi serializer KHÔNG kèm bản đồ biệt danh,
    /// nên `peer.displayName` luôn là TÊN THẬT — dùng nó để lấy lại tên thật
    /// sau khi xoá biệt danh, đừng dùng để làm mới sau khi ĐẶT biệt danh.
    case layHoiThoai(threadId: Int)
    /// Hàng tin: MỘT tin mới nhất cho mỗi người.
    case dangKyThietBi(token: String, sandbox: Bool)
    case goThietBi(token: String)
    case layHangTin
    /// Đủ tin của một người, để lật qua từng tin.
    case layTinCuaNguoi(userId: Int)
    case danhDauDaXemTin(storyId: Int)
    case taoTin(mediaUrl: String, mediaType: String, caption: String?)
    case xoaTin(storyId: Int)
    case markRead(threadId: Int)
    /// Mở (hoặc tạo nếu chưa có) hội thoại 1-1 với một người.
    case openThread(peerId: Int)
    /// Tắt thông báo hội thoại. `durationMinutes`: 0 = bật lại, 15/60/480/1440,
    /// nil = tắt vô thời hạn. Backend CHỈ chấp nhận đúng những giá trị đó.
    case muteThread(id: Int, durationMinutes: Int?)

    // Moderation (App Store Guideline 1.2)
    case reportPost(id: Int, reason: String, details: String?)
    case reportThread(id: Int, reason: String)
    case listBlocks
    case blockUser(id: Int, reason: String?)
    case unblockUser(id: Int)

    // Notes
    case getNotesTree
    case getNotesBySubject(id: Int)
    case createNote(subjectId: Int, chapterId: Int?, title: String?)
    case updateNote(id: Int, [String: Any])
    case deleteNote(id: Int)
    case layGhiChu(id: Int)
    /// Tìm ghi chú. `q` rỗng + `tag` rỗng = trả tất cả (máy chủ tự lo).
    case timGhiChu(q: String, subjectId: Int?, tag: String?)
    case layThe
    case taoChuong(subjectId: Int, title: String)
    case taoMon(name: String, color: String?, emoji: String?)
    case suaMon(id: Int, [String: Any])
    case xoaMon(id: Int)
    case suaChuong(id: Int, title: String)
    case xoaChuong(id: Int)
    case nhanBanGhiChu(id: Int)
    case locGhiChu(f: String)
    case khoiPhucGhiChu(id: Int)
    case xoaVinhVien(id: Int)
    case layLienKetNguoc(id: Int)

    // ─── Từ vựng & thẻ ghi nhớ ───────────────────────────────
    // ─── Bài viết của chính mình ─────────────────────────────
    /// Báo cáo một câu trả lời AI. Máy chủ đòi `rating` 1-5; báo cáo là mức
    /// thấp nhất (1) kèm loại.
    case baoCaoTraLoiAI(messageId: Int?)
    // ─── Phiên chat AI ───────────────────────────────────────
    /// `archived=1` là màn LƯU TRỮ; không truyền là danh sách thường.
    /// Hai bộ lọc LOẠI TRỪ nhau — backend cố ý không có nhánh "xem tất cả".
    case dsPhienChat(luuTru: Bool, thuMucId: String?)
    case lichSuPhienChat(id: String)
    case taoPhienChat(title: String?)
    /// Đổi tên / ghim / lưu trữ — cùng một đường PATCH.
    case suaPhienChat(id: String, [String: Any])
    case xoaPhienChat(id: String)
    case dsThuMucChat
    case taoThuMucChat(ten: String, mau: String?)
    case xoaThuMucChat(id: String)
    case chuyenThuMuc(id: String, thuMucId: String?)
    /// Tách nhánh từ một lượt: giữ các tin TRƯỚC `denChiSo`, tạo phiên mới.
    case tachNhanhPhien(id: String, denChiSo: Int)
    /// Cắt bỏ từ một lượt trở đi — dùng khi sửa câu hỏi rồi hỏi lại.
    case catPhien(id: String, tuChiSo: Int)
    /// Đặt việc đọc — trả `{ jobId }`, KHÔNG trả tiếng ngay. Xem `MayDoc`.
    case datViecDoc(text: String, voice: String? = nil)
    /// Danh sách giọng máy chủ — cho bộ chọn giọng của trợ lý.
    case dsGiongMayChu
    /// Xoá hội thoại CHO RIÊNG MÌNH — máy chủ đặt `deletedAt` theo người xem,
    /// người kia vẫn thấy nguyên. Khôi phục ở tab "Đã xoá".
    case xoaHoiThoai(threadId: Int)
    case xoaBaiViet(id: Int)
    /// Đổi nội dung và/hoặc quyền riêng tư. Máy chủ nhận `content`,
    /// `visibility` (PUBLIC | FRIENDS | PRIVATE).
    case suaBaiViet(id: Int, [String: Any])
    /// Ghim/bỏ ghim — máy chủ TỰ ĐẢO, một đường cho cả hai chiều.
    /// ⚠️ Mỗi người chỉ ghim được MỘT bài: nó lưu ở `userProfile.pinnedPostId`,
    /// ghim bài mới là bài cũ tự bỏ ghim.
    case ghimBaiViet(id: Int)

    case layTuVung(noteId: Int)
    case themTuVung(noteId: Int, term: String, reading: String?, meaning: String?, example: String?)
    case suaTuVung(id: Int, [String: Any])
    case xoaTuVung(id: Int)
    case layBoThe(noteId: Int)
    /// `known: true` = nhớ được. Máy chủ tự cộng chuỗi đúng và số lần ôn.
    case chamThe(vocabId: Int, known: Bool)
    case datLaiThe(vocabId: Int)
    case layPhienBan(noteId: Int)
    case layMotPhienBan(noteId: Int, version: Int)
    case luuMocPhienBan(noteId: Int)
    case khoiPhucPhienBan(noteId: Int, version: Int)
    case layViecAI
    case chayViecAI(action: String, selection: String)
    case hoiTroLyGhiChu(question: String)
    case laySoDoGhiChu
    case layBangTheoMon(subjectId: Int)
    case layBang(databaseId: Int)
    case taoDongBang(databaseId: Int)
    case suaDongBang(rowId: Int, values: [String: Any])
    case xoaDongBang(rowId: Int)

    // Learning
    case getCourses(page: Int, size: Int, keyword: String?)
    /// Khoá của **Academy FPT** (môn theo học kỳ).
    ///
    /// ⚠️ PHẢI là endpoint riêng, không dùng `getCourses`. Máy chủ đặt
    /// `where.semesterId = academy ? { not: null } : null` — tức KHÔNG truyền
    /// cờ `academy` thì nó trả về ĐÚNG những khoá KHÔNG thuộc Academy. Tìm
    /// "SWR302" bằng `getCourses` thì vĩnh viễn không ra gì, dù môn đó có đủ
    /// bài trên web.
    case getCoursesAcademy(page: Int, size: Int, keyword: String?)
    case getCourseDetail(slug: String)
    case enrollCourse(id: Int)
    /// Mục lục khoá — trả MẢNG chương ở tầng gốc, đi qua `requestList`.
    case getCurriculum(courseId: Int)
    /// 9 học kỳ của chương trình FPT.
    /// Bài đã lưu. `{ data: [...], pagination }` — đi qua `requestList`.
    case getSavedPosts(cursor: Int?, limit: Int)
    /// Khoá đã ghi danh — trả bản ghi ghi danh kèm tiến độ, không phải Course.
    case getMyCourses
    case getSemesters
    /// Các môn của một học kỳ — 50 môn `academyType: "FPT"` chỉ lấy được ở đây,
    /// `/courses` KHÔNG trả chúng.
    case getCoursesBySemester(semesterId: Int)
    /// Nội dung đầy đủ một bài (có kiểm quyền truy cập).
    case getLesson(courseId: Int, lessonId: Int)
    case getCourseProgress(courseId: Int)
    /// Lưu tiến độ. `lastPositionSeconds` cho phép mở lại đúng chỗ đang dở.
    case saveLessonProgress(courseId: Int, lessonId: Int, isCompleted: Bool?, watchTimeSeconds: Int?, lastPositionSeconds: Int?)

    /// Gia sư AI cho MỘT bài học Academy — bản KHÔNG stream, đường lùi khi SSE
    /// hỏng. Đường chính là `LuongGiaSuBai` (SSE).
    ///
    /// ⚠️ CHỈ Pro. Ngữ cảnh bài học do MÁY CHỦ tự ghép từ `lessonId`, client
    /// không gửi nội dung bài — gửi kèm chỉ tốn token mà máy chủ vẫn tự đọc lại.
    case hoiGiaSuBai(lessonId: Int, than: [String: Any])

    /// "Câu hỏi thường gặp" của một bài — mọi người đã hỏi gì, AI trả lời sao.
    ///
    /// CHUNG cho mọi người học, không riêng tư. Đó là toàn bộ giá trị: người
    /// thứ hai gặp đúng chỗ khó ấy đọc lại được NGUYÊN VĂN câu trả lời cũ,
    /// tức thì và KHÔNG tốn thêm một lượt gọi model nào. Máy chủ trả tối đa
    /// 40 lượt, mới nhất trước.
    case cauHoiThuongGap(lessonId: Int)
    /// Xoá một lượt trong mục trên. Máy chủ chỉ cho người hỏi hoặc admin.
    case xoaCauHoiThuongGap(lessonId: Int, askId: Int)

    // Notifications
    case getUnreadNotificationCount
    case getNotifications(cursor: Int?, limit: Int)
    case getUnreadMessageCount
    /// Danh sách STUN/TURN kèm khoá tạm 10 phút cho một cuộc gọi.
    case mayChuIce

    // ── My Language ─────────────────────────────────────────────
    case dsNgonNgu
    case chuDeTu(code: String)
    case tuVung(code: String, categoryId: Int?, page: Int, limit: Int)
    case hangDoiOnTap(code: String)
    /// `quality` 0-5 theo thang SM-2. `nil` = chỉ đổi trạng thái, không chấm.
    case ghiTienDo(itemId: Int, quality: Int?)
    case ghiKetQuaQuiz(languageId: Int, categoryId: Int?, score: Int, total: Int)
    case thongKeNgonNgu(code: String)
    case dsYeuThich(code: String)
    case idYeuThich(code: String)
    case doiYeuThich(wordId: Int)
    case bangChu(code: String)
    case nguPhap(code: String, level: String?, page: Int, limit: Int)
    case hoiThoai(code: String, page: Int, limit: Int)
    case baiDoc(code: String, page: Int, limit: Int)
    case baiNghe(code: String, page: Int, limit: Int)
    case timTuVung(code: String, q: String)
    case aiChamBaiViet(code: String, chu: String, deBai: String?)
    case hoiDap(code: String, page: Int, limit: Int)
    /// Lộ trình học. `optionalAuth` — gọi KHÔNG token vẫn ra đủ nút, chỉ là
    /// `doneNodeIds` về rỗng, nên đừng suy ra "chưa học gì" từ mảng rỗng.
    case loTrinh(code: String)
    /// Bật/tắt trạng thái đã học của một nút. Máy chủ trả về trạng thái MỚI.
    case doiNutLoTrinh(nodeId: Int)
    /// Toàn bộ trạng thái chơi + danh sách bài. ĐÒI đăng nhập.
    case luyenTap(code: String)
    case bangXepHang(code: String)
    case thanhTich(code: String)
    /// Nộp kết quả một bài. `lessonKey` phải đúng dạng `vocab:<mã chủ đề>`,
    /// máy chủ từ chối dạng khác. `wrongIds`/`rightIds` được đẩy vào hàng đợi
    /// ôn tập SM-2 nên gửi kèm là bài học tự nối vào phần Ôn tập.
    case nopBaiLuyen(code: String, lessonKey: String, dung: Int, tong: Int,
                     sai: Int, idSai: [Int], idDung: [Int])
    // ── Sổ tay ngôn ngữ (tất cả ĐÒI đăng nhập) ──
    /// TOÀN BỘ kho từ của một ngôn ngữ trong một lượt (en 2,2MB). Công khai,
    /// không cần đăng nhập. Máy chủ KHÔNG lọc — `?q=` vô tác dụng.
    case tuDien(code: String)
    case caySoTay(code: String)
    case mucSoTay(id: Int)
    case taoThuMucSoTay(code: String, ten: String, icon: String?, chaId: Int?)
    case doiTenThuMucSoTay(id: Int, ten: String, icon: String?)
    case xoaThuMucSoTay(id: Int)
    case taoMucSoTay(code: String, thuMucId: Int?, loai: String, tieuDe: String,
                     than: String, cachDoc: String?, nghia: String?)
    case suaMucSoTay(id: Int, tieuDe: String, than: String, cachDoc: String?,
                     nghia: String?, loai: String)
    case chuyenMucSoTay(id: Int, thuMucId: Int?)
    case onMucSoTay(id: Int, chatLuong: Int)
    case xoaMucSoTay(id: Int)
    /// `sangTiengNuocNgoai` = true nghĩa là Việt → ngôn ngữ đó.
    case aiDich(code: String, chu: String, sangTiengNuocNgoai: Bool)
    case aiKiemNguPhap(code: String, chu: String)
    /// Một lượt hội thoại. Máy chủ KHÔNG nhớ hộ — lịch sử phải gửi kèm mỗi
    /// lần, đúng khuôn của AI Chat.
    case aiNoiChuyen(code: String, canhHuong: String, lichSu: [[String: String]], chu: String)

    // ── Phòng thi ───────────────────────────────────────────────
    /// ⚠️ SỐ NHIỀU: `/api/v1/exams`. `/exam` trả 404.
    case dsDeThi
    /// Câu trắc nghiệm luyện tập của MỘT chương, gộp từ đề thi thật đã gán.
    case luyenChuong(sectionId: Int, ngauNhien: Bool, gioiHan: Int)
    /// Câu thực hành (PE) của chương đó.
    case luyenChuongThucHanh(sectionId: Int)
    /// Số câu luyện của TỪNG chương trong một khoá — `{sectionId: số câu}`.
    /// Công khai (không cần đăng nhập), máy chủ có cache 120s.
    case soCauLuyenTheoChuong(courseId: Int)
    case deDangLam(examId: Int)
    /// `coAI = true` → "Bắt đầu thi với CuongMini": máy chủ tạo lượt
    /// `aiAssisted`, **không tính giờ** (`expiresAt = null`) và tách hẳn khỏi
    /// lượt thi thật (`startAttempt` lọc `where: { …, aiAssisted }`, nên một
    /// cú bấm CuongMini KHÔNG bao giờ nối nhầm vào lượt đang chạy đồng hồ).
    case batDauLuotThi(examId: Int, coAI: Bool)
    case nopBaiTracNghiem(attemptId: Int, dapAn: [String: [Int]], giay: Int)
    case luotThiCuaToi
    /// Bản xem lại một lượt đã nộp — đáp án đúng + lời giải từng câu.
    case xemLaiLuotThi(attemptId: Int)
    /// Cả hai đều LẬT trạng thái (toggle) và trả `{bookmarked: Bool}`.
    case danhDauDeThi(examId: Int)
    case danhDauCauHoi(questionId: Int)

    // ── CuongMini — AI đồng hành khi thi ─────────────────────────
    /// "Hiện đáp án" — KHÔNG gọi AI, tra thẳng đáp án đã có trên câu hỏi.
    /// Mở cho MỌI tài khoản (chỉ `/ai/ask*` mới cần Pro).
    case hienDapAn(attemptId: Int, questionId: Int)
    /// "Câu này học ở bài nào" — tra `ExamQuestion.sectionId`, không gọi AI.
    /// ⚠️ Trả `data: null` khi câu chưa được gán chương. `APIClient.request`
    /// coi `data == nil` là LỖI, nên nơi gọi phải bắt lỗi rồi coi như "không
    /// có bài liên quan" — đúng cách web làm (`.catch(() => …null)`).
    case baiHocLienQuan(attemptId: Int, questionId: Int)
    /// Hỏi CuongMini — bản KHÔNG stream, chỉ dùng làm đường lùi khi SSE hỏng.
    /// Đường chính là `LuongCuongMini` (SSE), giống hệt web.
    case hoiCuongMini(attemptId: Int, than: [String: Any])
    /// Bình luận theo câu hỏi — mở cho mọi tài khoản, không cần Pro.
    case dsBinhLuanCauHoi(questionId: Int)
    case themBinhLuanCauHoi(questionId: Int, noiDung: String, traLoiId: Int?)
    case suaBinhLuanCauHoi(id: Int, noiDung: String)
    case xoaBinhLuanCauHoi(id: Int)
    // ── Code Lab ──
    /// 12.549 bài tập. Bộ lọc ĐÃ ĐO là có tác dụng thật (EASY→2.381,
    /// HARD→2.605, `q=zzzqqqxxx`→0), không như `?level=`/`?q=` của My Language.
    case dsBaiTapCode(nhom: Int?, loTrinh: Int?, doKho: String?, ngonNgu: String?, tim: String,
                      sap: String?, trang: Int)
    case nhomCodeLab
    case thongKeCodeLab
    /// Trọn chương trình học của một lộ trình: chương + bài tập theo đúng thứ tự.
    case loTrinhChiTiet(slug: String)
    /// Bài học của một chương — 5 loại khối, CÓ bản tiếng Việt.
    case baiHocChuong(chuongId: Int)
    /// Bài tập đầy đủ (đề bài, ví dụ, gợi ý, lời giải) theo slug.
    case baiTapTheoSlug(slug: String)
    /// Tiến độ của chính mình trong một lộ trình. ĐÒI đăng nhập.
    case tienDoCodeLab(loTrinhId: Int)
    /// `trangThai`: `SOLVED` hoặc `IN_PROGRESS`.
    case ghiTienDoBaiTap(baiId: Int, trangThai: String)
    /// Lưu mã người học đang viết. Máy chủ nhận MẢNG khối `{name, language, code}`.
    case luuMaBaiTap(baiId: Int, ma: String, ngonNgu: String)
    /// AI đối chiếu mã với từng yêu cầu của đề. **Chỉ Pro**, tốn AI — phải để
    /// người dùng tự bấm.
    case chamMaBaiTap(baiId: Int, ma: String)
    // ── Mẩu mã ──
    /// ⚠️ Tham số tìm là `search`, KHÔNG phải `q` — gõ `q` thì máy chủ trả
    /// về TOÀN BỘ danh sách mà không báo gì. Đã đo.
    case dsSnippet(danhMuc: Int?, ngonNgu: String?, tim: String, trang: Int)
    case dsDanhMucSnippet

    // ── Lộ trình (Roadmap) ────────────────────────────────────
    /// Danh sách lộ trình, trả về `{ role: [...], skill: [...] }`.
    case dsLoTrinh
    /// Chi tiết một lộ trình: các chặng + nút + `doneNodeIds` của người đang
    /// đăng nhập (`optionalAuth`, nên chưa đăng nhập vẫn xem được nội dung).
    ///
    /// ⚠️ TÊN PHẢI KHÁC `loTrinh(code:)` của Ngoại ngữ. Đặt trùng tên thì
    /// `switch` KHÔNG phân biệt được: mẫu `case .loTrinh(let c)` viết trước
    /// khớp CẢ HAI (cùng một tham số), nên lời gọi ở đây âm thầm đi sang
    /// `/my-language/<slug>/roadmap` và trả về "Không tìm thấy ngôn ngữ".
    /// Trình biên dịch không kêu ca gì — nhãn tham số khác nhau là hợp lệ.
    case loTrinhNghe(slug: String)
    /// Bật/tắt đánh dấu đã học một nút. CẦN đăng nhập.
    ///
    /// ⚠️ ĐỪNG lẫn với `doiNutLoTrinh` — cái đó là lộ trình học NGOẠI NGỮ
    /// (`/my-language/roadmap/:id/done`), một hệ hoàn toàn khác. Hai cái tên
    /// gần giống nhau là chỗ dễ gọi nhầm nhất trong tệp này.
    case danhDauNutLoTrinhNghe(nodeId: Int)

    // ── Dự án (Projects) ──────────────────────────────────────
    // ── Phỏng vấn (Interview) ─────────────────────────────────
    //
    // ⚠️ TOÀN BỘ nhóm này CẦN đăng nhập (`router.use(authenticate)` ở đầu
    // `interview.routes.ts`) — kể cả `/tracks` vốn nhìn như dữ liệu chung.
    // Chưa đăng nhập là 401 chứ không phải danh sách rỗng.
    case pvTaxonomy
    case pvTaoPhien(than: [String: Any])
    case pvTrangThai(id: Int)
    case pvTraLoi(id: Int, thuTu: Int, than: [String: Any])
    case pvTuCham(id: Int, thuTu: Int, than: [String: Any])
    case pvKetThuc(id: Int)
    case pvBaoCao(id: Int)
    case pvLichSu
    case pvBaoLoiCau(id: Int, thuTu: Int, lyDo: String)
    case pvTaoCauPhu(id: Int, thuTu: Int)
    case pvTraLoiCauPhu(id: Int, thuTu: Int, than: [String: Any])
    case pvOnTap
    case pvChamOnTap(cardId: Int, than: [String: Any])
    case pvThanhThao

    // ── CV Builder ────────────────────────────────────────────
    //
    // ⚠️ CẦN đăng nhập. Đường gốc là `/api/v1/cv`.
    // ⚠️ `GET /profile` TỰ TẠO hồ sơ nếu chưa có (upsert) — nên nó không bao
    // giờ 404, và cũng không được gọi từ chỗ chỉ muốn ĐỌC.
    case cvHoSo
    case cvLuuHoSo(than: [String: Any])
    case cvDoDay
    /// Mục kinh nghiệm / dự án / học vấn…
    case cvThemMuc(than: [String: Any])
    case cvSuaMuc(id: Int, than: [String: Any])
    case cvXoaMuc(id: Int)
    case cvThemGach(mucId: Int, than: [String: Any])
    case cvSuaGach(id: Int, than: [String: Any])
    case cvXoaGach(id: Int)
    case cvVietLaiGach(id: Int, than: [String: Any])
    case cvTrangThaiVietLai
    case cvThemKyNang(than: [String: Any])
    case cvXoaKyNang(id: Int)
    case cvThemChungChi(than: [String: Any])
    case cvXoaChungChi(id: Int)
    case cvThemNgonNgu(than: [String: Any])
    case cvXoaNgonNgu(id: Int)
    case cvSoiLoi
    case cvMauCV
    case cvDsTaiLieu
    case cvTaoTaiLieu(than: [String: Any])
    case cvTaiLieu(id: Int)
    case cvXoaTaiLieu(id: Int)
    case cvSoiLoiTaiLieu(id: Int)
    case cvDsViecLam
    case cvThemViecLam(than: [String: Any])
    case cvXoaViecLam(id: Int)
    case cvDoPhu(id: Int)
    case cvGoiYTheoViec(id: Int)
    case cvThuXinViec(id: Int, than: [String: Any])
    case cvTrangThaiThu
    case cvChamCV(than: [String: Any])
    case cvTrangThaiCham

    /// Gửi giao dịch App Store lên máy chủ xác minh và cấp Pro.
    /// `jws` là `Transaction.jsonRepresentation` của StoreKit 2.
    case guiGiaoDichApple(jws: String)

    /// Báo "tôi đang dùng app" để máy chủ làm mới `lastActiveAt`.
    /// Không có lời gọi này thì với mọi người khác mình LUÔN ngoại tuyến.
    case baoHoatDong

    case dsDuAn(danhMuc: String?, tim: String, trang: Int)
    case duAn(slug: String)
    /// Ghi nhận một lượt chép. Không cần đăng nhập (máy chủ đếm theo IP).
    case ghiNhanChep(id: Int)
    case dsDeDaLuu
    case dsCauHoiDaLuu
    /// Ghi chú riêng cho câu đã lưu. Gửi chuỗi RỖNG là xoá ghi chú.
    case ghiChuCauHoi(questionId: Int, ghiChu: String)
    /// PATCH — `nil` = đánh dấu đã đọc TẤT CẢ, hoặc truyền danh sách id.
    case markNotificationsRead(ids: [Int]?)
    /// Lấy một bài viết theo id, để bấm thông báo là mở đúng bài.
    case getPost(id: Int)

    var path: String {
        switch self {
        case .tuyChinh(let duong, _, _): return duong
        case .voLayCay: return "/api/v1/vo"
        case .voDongBoCay: return "/api/v1/vo/sync"
        case .voXinDuongNen: return "/api/v1/vo/nen/duong-day"
        case .voXinDuongDay(let id, _): return "/api/v1/vo/trang/\(id)/duong-day"
        case .voXacNhanNet(let id, _): return "/api/v1/vo/trang/\(id)/xac-nhan"
        case .voXoaTrang: return "/api/v1/vo/trang/xoa"
        case .voXoaCuon: return "/api/v1/vo/cuon/xoa"
        case .login: return "/api/v1/auth/login"
        case .register: return "/api/v1/auth/register"
        case .oauthToken: return "/api/v1/auth/oauth/token"
        case .changePassword: return "/api/v1/auth/change-password"
        case .refreshToken: return "/api/v1/auth/refresh"

        case .getProfile: return "/api/v1/profile"

        case .tongQuan(let hn): return "/api/v1/dashboard?homNay=\(hn)"
        case .themViec: return "/api/v1/dashboard/tasks"
        case .suaViec(let id, _): return "/api/v1/dashboard/tasks/\(id)"
        case .xoaViec(let id): return "/api/v1/dashboard/tasks/\(id)"
        case .ketThucNgay: return "/api/v1/dashboard/celebrate"
        case .taiDuLieuCuaToi: return "/api/v1/profile/export-data"
        case .lichHoc(let ngay):
            return ngay.map { "/api/v1/class-schedule?ngay=\($0)" } ?? "/api/v1/class-schedule"
        case .themBuoiHoc: return "/api/v1/class-schedule"
        case .suaBuoiHoc(let id, _): return "/api/v1/class-schedule/\(id)"
        case .xoaBuoiHoc(let id): return "/api/v1/class-schedule/\(id)"
        case .nhapLichHoc: return "/api/v1/class-schedule/bulk"
        case .diemDanhTrongKhoang(let tu, let den): return "/api/v1/class-schedule/attendance?tu=\(tu)&den=\(den)"
        case .chamDiemDanh(let id, _): return "/api/v1/class-schedule/\(id)/attendance"
        case .dsHocKy, .themHocKy: return "/api/v1/hoc-ky"
        case .suaHocKy(let id, _): return "/api/v1/hoc-ky/\(id)"
        case .xoaHocKy(let id): return "/api/v1/hoc-ky/\(id)"
        case .dsLichThi(let tu, let den):
            if let tu, let den { return "/api/v1/hoc-ky/lich-thi?tu=\(tu)&den=\(den)" }
            return "/api/v1/hoc-ky/lich-thi"
        case .themBuoiThi: return "/api/v1/hoc-ky/lich-thi"
        case .suaBuoiThi(let id, _): return "/api/v1/hoc-ky/lich-thi/\(id)"
        case .xoaBuoiThi(let id): return "/api/v1/hoc-ky/lich-thi/\(id)"
        case .updateProfile: return "/api/v1/profile"
        case .getDeletionRequest: return "/api/v1/profile/deletion-request"
        case .requestDeletion: return "/api/v1/profile/deletion-request"
        case .cancelDeletionRequest: return "/api/v1/profile/deletion-request"

        case .getFeed: return "/api/v1/social/posts"
        case .getPostCounts: return "/api/v1/social/posts/counts"
        case .getSeries(let slug): return "/api/v1/social/series/\(slug)"
        case .createPost: return "/api/v1/social/posts"
        case .deletePost(let id): return "/api/v1/social/posts/\(id)"
        case .likePost(let id): return "/api/v1/social/posts/\(id)/like"
        case .unlikePost(let id): return "/api/v1/social/posts/\(id)/like"
        case .reactPost(let id, _): return "/api/v1/social/posts/\(id)/react"
        case .getComments(let postId, _, _): return "/api/v1/social/posts/\(postId)/comments"
        // ⚠️ TẠO bình luận là `POST /social/comments` với `postId` trong THÂN.
        // Bản cũ gọi `/social/posts/{id}/comments` — đường đó chỉ có GET, nên
        // POST trả 404, bình luận vừa chèn tạm bị gỡ đi, và nhìn từ ngoài
        // đúng là "ấn gửi mà không thấy gì".
        case .createComment: return "/api/v1/social/comments"
        case .likeComment(let id): return "/api/v1/social/comments/\(id)/like"
        case .savePost(let id, _): return "/api/v1/social/posts/\(id)/save"
        case .unsavePost(let id): return "/api/v1/social/posts/\(id)/save"

        case .getUserProfile(let id): return "/api/v1/users/\(id)"
        case .getUserPosts(let id, _, _): return "/api/v1/users/\(id)/posts"
        case .followUser: return "/api/v1/users/follow"
        case .unfollowUser: return "/api/v1/users/follow"
        case .searchUsers: return "/api/v1/users/search"
        case .timKiem: return "/api/v1/tim-kiem"

        case .getThreads: return "/api/v1/messages/threads"
        case .getMessages(let threadId, _, _): return "/api/v1/messages/threads/\(threadId)/messages"
        case .sendMessage(let threadId, _, _, _): return "/api/v1/messages/threads/\(threadId)/messages"
        case .sendMessageWithFiles(let threadId, _, _): return "/api/v1/messages/threads/\(threadId)/messages"
        case .getThreadReads(let threadId): return "/api/v1/messages/threads/\(threadId)/reads"
        case .sendMessageMedia(let threadId, _, _): return "/api/v1/messages/threads/\(threadId)/messages"
        case .toggleMessageReaction(let id, _): return "/api/v1/messages/messages/\(id)/reactions"
        case .recallMessage(let id): return "/api/v1/messages/messages/\(id)/recall"
        case .deleteMessage(let id): return "/api/v1/messages/messages/\(id)"
        case .searchGifs: return "/api/v1/gifs"
        case .datTuyChonHoiThoai(let id, _, _): return "/api/v1/messages/threads/\(id)/preference"
        case .boLuuTruHoiThoai(let id): return "/api/v1/messages/threads/\(id)/unarchive"
        case .danhDauChuaDoc(let id): return "/api/v1/messages/threads/\(id)/mark-unread"
        case .datBietDanh(let id, _, _): return "/api/v1/messages/threads/\(id)/nickname"
        case .layHoiThoai(let id): return "/api/v1/messages/threads/\(id)"
        case .dangKyThietBi: return "/api/v1/devices"
        case .goThietBi(let t): return "/api/v1/devices/\(t)"
        case .layHangTin: return "/api/v1/stories/feed"
        case .layTinCuaNguoi(let id): return "/api/v1/stories/user/\(id)"
        case .danhDauDaXemTin(let id): return "/api/v1/stories/\(id)/view"
        case .taoTin: return "/api/v1/stories"
        case .xoaTin(let id): return "/api/v1/stories/\(id)"
        case .markRead(let threadId): return "/api/v1/messages/threads/\(threadId)/read"
        case .openThread(let peerId): return "/api/v1/messages/threads/user/\(peerId)"
        case .muteThread(let id, _): return "/api/v1/messages/threads/\(id)/mute-for"

        case .reportPost(let id, _, _): return "/api/v1/social/posts/\(id)/report"
        case .reportThread(let id, _): return "/api/v1/messages/threads/\(id)/report"
        case .listBlocks: return "/api/v1/messages/blocks"
        case .blockUser(let id, _): return "/api/v1/messages/blocks/\(id)"
        case .unblockUser(let id): return "/api/v1/messages/blocks/\(id)"

        case .getNotesTree: return "/api/v1/notes/tree"
        case .getNotesBySubject(let id): return "/api/v1/notes/subjects/\(id)"
        case .createNote: return "/api/v1/notes/notes"
        case .updateNote(let id, _): return "/api/v1/notes/notes/\(id)"
        case .deleteNote(let id): return "/api/v1/notes/notes/\(id)"
        case .layGhiChu(let id): return "/api/v1/notes/notes/\(id)"
        case .timGhiChu: return "/api/v1/notes/search"
        case .layThe: return "/api/v1/notes/tags"
        case .taoChuong: return "/api/v1/notes/chapters"
        case .taoMon: return "/api/v1/notes/subjects"
        case .suaMon(let id, _): return "/api/v1/notes/subjects/\(id)"
        case .xoaMon(let id): return "/api/v1/notes/subjects/\(id)"
        case .suaChuong(let id, _): return "/api/v1/notes/chapters/\(id)"
        case .xoaChuong(let id): return "/api/v1/notes/chapters/\(id)"
        case .nhanBanGhiChu(let id): return "/api/v1/notes/notes/\(id)/duplicate"
        case .locGhiChu: return "/api/v1/notes/notes/filter"
        case .khoiPhucGhiChu(let id): return "/api/v1/notes/notes/\(id)/restore"
        case .xoaVinhVien(let id): return "/api/v1/notes/notes/\(id)/permanent"
        case .layLienKetNguoc(let id): return "/api/v1/notes/notes/\(id)/backlinks"
        case .baoCaoTraLoiAI: return "/api/v1/ai/feedback"
        case .dsPhienChat: return "/api/v1/ai/chat/sessions"
        case .lichSuPhienChat(let id): return "/api/v1/ai/chat/history/\(id)"
        case .taoPhienChat: return "/api/v1/ai/chat/sessions"
        case .suaPhienChat(let id, _): return "/api/v1/ai/chat/sessions/\(id)"
        case .xoaPhienChat(let id): return "/api/v1/ai/chat/sessions/\(id)"
        case .dsThuMucChat, .taoThuMucChat: return "/api/v1/ai/chat/folders"
        case .xoaThuMucChat(let id): return "/api/v1/ai/chat/folders/\(id)"
        case .chuyenThuMuc(let id, _): return "/api/v1/ai/chat/sessions/\(id)/folder"
        case .tachNhanhPhien(let id, _): return "/api/v1/ai/chat/sessions/\(id)/fork"
        case .catPhien(let id, _): return "/api/v1/ai/chat/sessions/\(id)/cat"
        case .datViecDoc: return "/api/v1/voice-mini/tts"
        case .dsGiongMayChu: return "/api/v1/voice-mini/voices"
        case .xoaHoiThoai(let id): return "/api/v1/messages/threads/\(id)"
        case .xoaBaiViet(let id): return "/api/v1/social/posts/\(id)"
        case .suaBaiViet(let id, _): return "/api/v1/social/posts/\(id)"
        case .ghimBaiViet(let id): return "/api/v1/social/posts/\(id)/pin"
        case .layTuVung: return "/api/v1/notes/vocab"
        case .themTuVung: return "/api/v1/notes/vocab"
        case .suaTuVung(let id, _): return "/api/v1/notes/vocab/\(id)"
        case .xoaTuVung(let id): return "/api/v1/notes/vocab/\(id)"
        case .layBoThe: return "/api/v1/notes/flashcards"
        case .chamThe: return "/api/v1/notes/flashcards/grade"
        case .datLaiThe: return "/api/v1/notes/flashcards/reset"
        case .layPhienBan(let id): return "/api/v1/notes/notes/\(id)/versions"
        case .layMotPhienBan(let id, let v): return "/api/v1/notes/notes/\(id)/versions/\(v)"
        case .luuMocPhienBan(let id): return "/api/v1/notes/notes/\(id)/versions"
        case .khoiPhucPhienBan(let id, let v): return "/api/v1/notes/notes/\(id)/versions/\(v)/restore"
        case .layViecAI: return "/api/v1/notes/ai/actions"
        case .chayViecAI: return "/api/v1/notes/ai/assist"
        case .hoiTroLyGhiChu: return "/api/v1/notes/ai/hoi"
        case .laySoDoGhiChu: return "/api/v1/notes/graph"
        case .layBangTheoMon(let id): return "/api/v1/notes-databases/subject/\(id)"
        case .layBang(let id): return "/api/v1/notes-databases/\(id)"
        case .taoDongBang(let id): return "/api/v1/notes-databases/\(id)/rows"
        case .suaDongBang(let id, _): return "/api/v1/notes-databases/rows/\(id)"
        case .xoaDongBang(let id): return "/api/v1/notes-databases/rows/\(id)"

        case .getCourses, .getCoursesAcademy: return "/api/v1/courses"
        case .getCourseDetail(let slug): return "/api/v1/courses/\(slug)"
        case .enrollCourse(let id): return "/api/v1/courses/\(id)/enroll"
        case .getCurriculum(let id): return "/api/v1/courses/\(id)/curriculum"
        case .getSavedPosts: return "/api/v1/social/saves"
        case .getMyCourses: return "/api/v1/courses/my"
        case .getSemesters: return "/api/v1/academy/semesters"
        // `gon=1` — màn Học viện chỉ hiện tên/mã/ảnh/mô tả ngắn/số bài, KHÔNG
        // đọc `sections`. Không có tham số này thì mỗi lần mở một kỳ là kéo về
        // cả cây chương→bài của mọi môn trong kỳ: đo thật 09/09/2026 là
        // 136-391 KB mỗi kỳ và ~2 giây chờ, trong đó 93% là `sections`.
        case .getCoursesBySemester(let id): return "/api/v1/courses/semester/\(id)?gon=1"
        case .getLesson(let c, let l): return "/api/v1/courses/\(c)/lessons/\(l)"
        case .hoiGiaSuBai(let l, _): return "/api/v1/courses/lessons/\(l)/ai/ask"
        case .cauHoiThuongGap(let l): return "/api/v1/courses/lessons/\(l)/ai/asks"
        case .xoaCauHoiThuongGap(let l, let a): return "/api/v1/courses/lessons/\(l)/ai/asks/\(a)"
        case .getCourseProgress(let id): return "/api/v1/courses/\(id)/progress"
        case .saveLessonProgress(let id, _, _, _, _): return "/api/v1/courses/\(id)/progress"

        case .getUnreadNotificationCount: return "/api/v1/social/notifications/unread-count"
        case .getNotifications: return "/api/v1/social/notifications"
        case .getUnreadMessageCount: return "/api/v1/messages/unread-count"
        case .mayChuIce: return "/api/v1/messages/ice-servers"

        case .dsNgonNgu: return "/api/v1/my-language/"
        case .chuDeTu(let c): return "/api/v1/my-language/\(c)/vocab/categories"
        case .tuVung(let c, _, _, _): return "/api/v1/my-language/\(c)/vocab"
        case .hangDoiOnTap: return "/api/v1/my-language/review-queue"
        case .ghiTienDo: return "/api/v1/my-language/progress"
        case .ghiKetQuaQuiz: return "/api/v1/my-language/quiz-result"
        case .thongKeNgonNgu: return "/api/v1/my-language/stats"
        case .dsYeuThich(let c): return "/api/v1/my-language/favorites/\(c)"
        case .idYeuThich(let c): return "/api/v1/my-language/favorites/\(c)/ids"
        case .doiYeuThich: return "/api/v1/my-language/favorites/toggle"
        case .bangChu(let c): return "/api/v1/my-language/\(c)/alphabet"
        case .nguPhap(let c, _, _, _): return "/api/v1/my-language/\(c)/grammar"
        case .hoiThoai(let c, _, _): return "/api/v1/my-language/\(c)/conversation"
        case .baiDoc(let c, _, _): return "/api/v1/my-language/\(c)/reading"
        case .baiNghe(let c, _, _): return "/api/v1/my-language/\(c)/listening"
        case .timTuVung(let c, _): return "/api/v1/my-language/\(c)/vocab/search"
        case .aiChamBaiViet: return "/api/v1/my-language/ai/writing"
        case .hoiDap(let c, _, _): return "/api/v1/my-language/\(c)/qna"
        case .loTrinh(let c): return "/api/v1/my-language/\(c)/roadmap"
        case .doiNutLoTrinh(let id): return "/api/v1/my-language/roadmap/\(id)/done"
        case .luyenTap(let c): return "/api/v1/my-language/\(c)/practice"
        case .bangXepHang(let c): return "/api/v1/my-language/\(c)/practice/leaderboard"
        case .thanhTich(let c): return "/api/v1/my-language/\(c)/practice/achievements"
        case .nopBaiLuyen: return "/api/v1/my-language/practice/complete"
        case .tuDien(let c): return "/api/v1/my-language/\(c)/dictionary"
        case .caySoTay(let c): return "/api/v1/my-language/notebook/\(c)"
        case .mucSoTay(let id): return "/api/v1/my-language/notebook/entry/\(id)"
        case .taoThuMucSoTay: return "/api/v1/my-language/notebook/folders"
        case .doiTenThuMucSoTay(let id, _, _): return "/api/v1/my-language/notebook/folders/\(id)"
        case .xoaThuMucSoTay(let id): return "/api/v1/my-language/notebook/folders/\(id)"
        case .taoMucSoTay: return "/api/v1/my-language/notebook/entries"
        case .suaMucSoTay(let id, _, _, _, _, _): return "/api/v1/my-language/notebook/entries/\(id)"
        case .chuyenMucSoTay(let id, _): return "/api/v1/my-language/notebook/entries/\(id)/move"
        case .onMucSoTay(let id, _): return "/api/v1/my-language/notebook/entries/\(id)/review"
        case .xoaMucSoTay(let id): return "/api/v1/my-language/notebook/entries/\(id)"
        case .aiDich: return "/api/v1/my-language/ai/translate"
        case .aiKiemNguPhap: return "/api/v1/my-language/ai/grammar-check"
        case .aiNoiChuyen: return "/api/v1/my-language/ai/roleplay"
        case .dsDeThi: return "/api/v1/exams"
        case .luyenChuong(let id, _, _): return "/api/v1/exams/practice/by-section/\(id)"
        case .luyenChuongThucHanh(let id): return "/api/v1/exams/practice/by-section/\(id)/practical"
        case .soCauLuyenTheoChuong(let id): return "/api/v1/exams/practice/section-counts/\(id)"
        case .deDangLam(let e): return "/api/v1/exams/\(e)/take"
        case .batDauLuotThi(let e, _): return "/api/v1/exams/\(e)/attempts"
        case .hienDapAn(let a, _): return "/api/v1/exams/attempts/\(a)/ai/reveal"
        case .baiHocLienQuan(let a, _): return "/api/v1/exams/attempts/\(a)/ai/related-lesson"
        case .hoiCuongMini(let a, _): return "/api/v1/exams/attempts/\(a)/ai/ask"
        case .dsBinhLuanCauHoi(let q), .themBinhLuanCauHoi(let q, _, _):
            return "/api/v1/exams/questions/\(q)/comments"
        case .suaBinhLuanCauHoi(let id, _), .xoaBinhLuanCauHoi(let id):
            return "/api/v1/exams/comments/\(id)"
        case .nopBaiTracNghiem(let a, _, _): return "/api/v1/exams/attempts/\(a)/submit-fe"
        case .luotThiCuaToi: return "/api/v1/exams/attempts/mine"
        case .xemLaiLuotThi(let id): return "/api/v1/exams/attempts/\(id)"
        case .danhDauDeThi(let id): return "/api/v1/exams/\(id)/bookmark"
        case .danhDauCauHoi(let id): return "/api/v1/exams/questions/\(id)/bookmark"
        case .dsBaiTapCode: return "/api/v1/code-lab/exercises"
        case .nhomCodeLab: return "/api/v1/code-lab/groups"
        case .thongKeCodeLab: return "/api/v1/code-lab/stats"
        case .loTrinhChiTiet(let s): return "/api/v1/code-lab/tracks/\(s)"
        case .baiHocChuong(let id): return "/api/v1/code-lab/modules/\(id)/lesson"
        case .baiTapTheoSlug(let s): return "/api/v1/code-lab/exercises/\(s)"
        case .tienDoCodeLab: return "/api/v1/code-lab/progress/mine"
        case .ghiTienDoBaiTap(let id, _): return "/api/v1/code-lab/exercises/\(id)/progress"
        case .luuMaBaiTap(let id, _, _): return "/api/v1/code-lab/exercises/\(id)/progress"
        case .chamMaBaiTap(let id, _): return "/api/v1/code-lab/exercises/\(id)/coach/check"
        case .dsSnippet: return "/api/v1/snippets"
        case .dsDanhMucSnippet: return "/api/v1/snippets/categories"
        case .dsLoTrinh: return "/api/v1/roadmaps"
        case .loTrinhNghe(let slug): return "/api/v1/roadmaps/\(slug)"
        case .danhDauNutLoTrinhNghe(let id): return "/api/v1/roadmaps/nodes/\(id)/done"
        case .pvTaxonomy: return "/api/v1/interview/tracks"
        case .pvTaoPhien: return "/api/v1/interview/sessions"
        case .pvTrangThai(let id): return "/api/v1/interview/sessions/\(id)"
        case .pvTraLoi(let id, let t, _): return "/api/v1/interview/sessions/\(id)/turns/\(t)/answer"
        case .pvTuCham(let id, let t, _): return "/api/v1/interview/sessions/\(id)/turns/\(t)/self-assess"
        case .pvKetThuc(let id): return "/api/v1/interview/sessions/\(id)/finish"
        case .pvBaoCao(let id): return "/api/v1/interview/sessions/\(id)/report"
        case .pvLichSu: return "/api/v1/interview/history"
        case .pvBaoLoiCau(let id, let t, _): return "/api/v1/interview/sessions/\(id)/turns/\(t)/flag"
        case .pvTaoCauPhu(let id, let t): return "/api/v1/interview/sessions/\(id)/turns/\(t)/followup"
        case .pvTraLoiCauPhu(let id, let t, _): return "/api/v1/interview/sessions/\(id)/turns/\(t)/followup/answer"
        case .pvOnTap: return "/api/v1/interview/drill"
        case .pvChamOnTap(let c, _): return "/api/v1/interview/drill/\(c)/grade"
        case .pvThanhThao: return "/api/v1/interview/mastery"
        case .cvHoSo, .cvLuuHoSo: return "/api/v1/cv/profile"
        case .cvDoDay: return "/api/v1/cv/profile/completeness"
        case .cvThemMuc: return "/api/v1/cv/items"
        case .cvSuaMuc(let id, _), .cvXoaMuc(let id): return "/api/v1/cv/items/\(id)"
        case .cvThemGach(let id, _): return "/api/v1/cv/items/\(id)/bullets"
        case .cvSuaGach(let id, _), .cvXoaGach(let id): return "/api/v1/cv/bullets/\(id)"
        case .cvVietLaiGach(let id, _): return "/api/v1/cv/bullets/\(id)/rewrite"
        case .cvTrangThaiVietLai: return "/api/v1/cv/rewrite/status"
        case .cvThemKyNang: return "/api/v1/cv/skills"
        case .cvXoaKyNang(let id): return "/api/v1/cv/skills/\(id)"
        case .cvThemChungChi: return "/api/v1/cv/certifications"
        case .cvXoaChungChi(let id): return "/api/v1/cv/certifications/\(id)"
        case .cvThemNgonNgu: return "/api/v1/cv/languages"
        case .cvXoaNgonNgu(let id): return "/api/v1/cv/languages/\(id)"
        case .cvSoiLoi: return "/api/v1/cv/lint"
        case .cvMauCV: return "/api/v1/cv/templates"
        case .cvDsTaiLieu, .cvTaoTaiLieu: return "/api/v1/cv/documents"
        case .cvTaiLieu(let id), .cvXoaTaiLieu(let id): return "/api/v1/cv/documents/\(id)"
        case .cvSoiLoiTaiLieu(let id): return "/api/v1/cv/documents/\(id)/lint"
        case .cvDsViecLam, .cvThemViecLam: return "/api/v1/cv/jobs"
        case .cvXoaViecLam(let id): return "/api/v1/cv/jobs/\(id)"
        case .cvDoPhu(let id): return "/api/v1/cv/jobs/\(id)/coverage"
        case .cvGoiYTheoViec(let id): return "/api/v1/cv/jobs/\(id)/tailor"
        case .cvThuXinViec(let id, _): return "/api/v1/cv/jobs/\(id)/cover-letter"
        case .cvTrangThaiThu: return "/api/v1/cv/cover-letter/status"
        case .cvChamCV: return "/api/v1/cv/critique"
        case .cvTrangThaiCham: return "/api/v1/cv/critique/status"
        case .guiGiaoDichApple: return "/api/v1/pro/apple/transactions"
        case .baoHoatDong: return "/api/v1/users/status"
        case .dsDuAn: return "/api/v1/projects"
        case .duAn(let slug): return "/api/v1/projects/\(slug)"
        case .ghiNhanChep(let id): return "/api/v1/snippets/\(id)/copy"
        case .dsDeDaLuu: return "/api/v1/exams/bookmarks/exams"
        case .dsCauHoiDaLuu: return "/api/v1/exams/bookmarks/questions"
        case .ghiChuCauHoi(let id, _): return "/api/v1/exams/questions/\(id)/bookmark-note"
        case .markNotificationsRead: return "/api/v1/social/notifications"
        case .getPost(let id): return "/api/v1/social/posts/\(id)"
        }
    }

    var method: String {
        switch self {
        case .tuyChinh(_, let pt, _): return pt
        case .voLayCay: return "GET"
        case .voDongBoCay, .voXinDuongDay, .voXacNhanNet, .voXoaTrang, .voXoaCuon,
             .voXinDuongNen: return "POST"
        case .ghiTienDo, .ghiKetQuaQuiz, .doiYeuThich, .aiDich, .aiKiemNguPhap, .aiNoiChuyen,
             .aiChamBaiViet, .batDauLuotThi, .nopBaiTracNghiem,
             .hienDapAn, .baiHocLienQuan, .hoiCuongMini, .themBinhLuanCauHoi, .hoiGiaSuBai,
             .doiNutLoTrinh, .danhDauNutLoTrinhNghe, .nopBaiLuyen,
             .pvTaoPhien, .pvTraLoi, .pvTuCham, .pvKetThuc, .pvBaoLoiCau,
             .pvTaoCauPhu, .pvTraLoiCauPhu, .pvChamOnTap,
             .cvThemMuc, .cvThemGach, .cvVietLaiGach, .cvThemKyNang,
             .cvThemChungChi, .cvThemNgonNgu, .cvSoiLoi, .cvTaoTaiLieu,
             .cvSoiLoiTaiLieu, .cvThemViecLam, .cvThuXinViec, .cvChamCV, .taoThuMucSoTay, .taoMucSoTay, .ghiNhanChep,
             .ghiTienDoBaiTap, .luuMaBaiTap, .chamMaBaiTap,
             .reactPost,   // ⚠️ backend khai POST, KHÔNG phải PATCH — xem ghi chú ở `case reactPost`
             .danhDauDeThi, .danhDauCauHoi,
             .login, .register, .oauthToken, .changePassword, .refreshToken,
             .createPost, .likePost, .followUser, .unfollowUser,
             .createComment, .likeComment, .savePost, .sendMessage, .sendMessageWithFiles, .enrollCourse,
             .sendMessageMedia, .toggleMessageReaction, .recallMessage,
             .boLuuTruHoiThoai, .danhDauChuaDoc, .danhDauDaXemTin, .taoTin, .taoChuong,
             .luuMocPhienBan, .khoiPhucPhienBan, .chayViecAI, .hoiTroLyGhiChu, .taoDongBang,
             .taoMon, .nhanBanGhiChu, .khoiPhucGhiChu, .dangKyThietBi,
             .themTuVung, .chamThe, .datLaiThe, .ghimBaiViet, .baoCaoTraLoiAI,
             .createNote, .reportPost, .reportThread, .blockUser, .requestDeletion,
             .openThread, .muteThread, .saveLessonProgress,
             .taoPhienChat, .taoThuMucChat, .tachNhanhPhien, .catPhien, .datViecDoc:
            return "POST"
        case .chamDiemDanh:
            return "PUT"
        case .updateProfile, .datBietDanh, .doiTenThuMucSoTay, .suaMucSoTay, .ghiChuCauHoi,
             .suaBinhLuanCauHoi,
             .cvLuuHoSo, .cvSuaMuc, .cvSuaGach:
            return "PUT"
        case .guiGiaoDichApple, .baoHoatDong:
            return "POST"
        case .themViec, .themBuoiHoc, .nhapLichHoc, .ketThucNgay, .themHocKy, .themBuoiThi:
            return "POST"
        case .suaViec, .suaBuoiHoc, .suaHocKy, .suaBuoiThi:
            return "PATCH"
        case .xoaViec, .xoaBuoiHoc, .xoaHocKy, .xoaBuoiThi:
            return "DELETE"
        case .updateNote, .markRead, .markNotificationsRead, .datTuyChonHoiThoai,
             .suaDongBang, .suaMon, .suaChuong, .suaTuVung, .suaBaiViet,
             .suaPhienChat, .chuyenThuMuc, .chuyenMucSoTay, .onMucSoTay:
            return "PATCH"
        case .deletePost, .unlikePost, .unsavePost, .deleteNote, .xoaBinhLuanCauHoi,
             .unblockUser, .cancelDeletionRequest, .deleteMessage, .xoaTin, .xoaDongBang,
             .xoaMon, .xoaChuong, .xoaVinhVien, .goThietBi, .xoaTuVung, .xoaBaiViet,
             .xoaPhienChat, .xoaThuMucChat, .xoaHoiThoai, .xoaThuMucSoTay, .xoaMucSoTay,
             .cvXoaMuc, .cvXoaGach, .cvXoaKyNang, .cvXoaChungChi,
             .cvXoaNgonNgu, .cvXoaTaiLieu, .cvXoaViecLam,
             .xoaCauHoiThuongGap:
            return "DELETE"
        default:
            return "GET"
        }
    }

    var body: [String: Any]? {
        switch self {
        case .tuyChinh(_, _, let than): return than
        case .voLayCay: return nil
        case .voDongBoCay(let mons): return ["mons": mons]
        case .voXinDuongNen(let sha, let duoi, let soByte):
            return ["sha256": sha, "duoi": duoi, "soByte": soByte]
        case .voXinDuongDay(_, let coAnh): return ["coAnhXemTruoc": coAnh]
        case .voXacNhanNet(_, let than): return than
        case .voXoaTrang(let ids): return ["clientIds": ids]
        case .voXoaCuon(let id): return ["clientId": id]
        case .cvLuuHoSo(let m), .cvThemMuc(let m), .cvThemGach(_, let m),
             .cvSuaMuc(_, let m), .cvSuaGach(_, let m), .cvVietLaiGach(_, let m),
             .cvThemKyNang(let m), .cvThemChungChi(let m), .cvThemNgonNgu(let m),
             .cvTaoTaiLieu(let m), .cvThemViecLam(let m), .cvThuXinViec(_, let m),
             .cvChamCV(let m):
            return m
        case .pvTaoPhien(let m): return m
        case .pvTraLoi(_, _, let m): return m
        case .pvTuCham(_, _, let m): return m
        case .pvTraLoiCauPhu(_, _, let m): return m
        case .pvChamOnTap(_, let m): return m
        case .pvBaoLoiCau(_, _, let l): return ["reason": l]
        case .login(let u, let p, let c):
            var m: [String: Any] = ["username": u, "password": p]
            if let t = c { m["cf-turnstile-response"] = t }
            return m
        case .ghiTienDo(let id, let q):
            var m: [String: Any] = ["itemType": "VOCAB", "itemId": id]
            // Không chấm điểm thì máy chủ đi nhánh "đổi trạng thái" và
            // KHÔNG đụng vào lịch ôn — dùng cho việc chỉ đánh dấu đã xem.
            if let q { m["quality"] = q } else { m["status"] = "LEARNING" }
            return m
        case .ghiKetQuaQuiz(let lid, let cid, let s, let t):
            var m: [String: Any] = ["languageId": lid, "score": s, "total": t]
            if let cid { m["categoryId"] = cid }
            return m
        case .aiDich(let c, let chu, let sang):
            return ["languageCode": c, "text": chu, "direction": sang ? "to" : "from"]
        case .aiKiemNguPhap(let c, let chu):
            return ["languageCode": c, "text": chu]
        case .aiChamBaiViet(let c, let chu, let de):
            var m: [String: Any] = ["languageCode": c, "text": chu]
            // `prompt` là ĐỀ BÀI, không bắt buộc. Gửi chuỗi rỗng thì máy chủ
            // vẫn nhét "ĐỀ BÀI: " vào lời nhắc — bỏ hẳn trường mới đúng.
            if let de, !de.isEmpty { m["prompt"] = de }
            return m
        case .aiNoiChuyen(let c, let ch, let ls, let chu):
            return ["languageCode": c, "scenario": ch, "history": ls, "message": chu]
        case .nopBaiTracNghiem(_, let da, let g):
            return ["answers": da, "timeSpentSeconds": g]
        case .batDauLuotThi(_, let coAI):
            // ⚠️ Không gửi `{aiAssisted:false}` cho lượt thường: máy chủ đọc
            // `req.body?.aiAssisted === true` nên gửi false cũng đúng, nhưng
            // web gửi `undefined` — giữ y hệt để không có đường nào khác nhau.
            return coAI ? ["aiAssisted": true] : nil
        case .hienDapAn(_, let q), .baiHocLienQuan(_, let q):
            return ["questionId": q]
        case .hoiCuongMini(_, let m), .hoiGiaSuBai(_, let m):
            return m
        case .themBinhLuanCauHoi(_, let chu, let cha):
            var m: [String: Any] = ["content": chu]
            if let cha { m["parentId"] = cha }
            return m
        case .suaBinhLuanCauHoi(_, let chu):
            return ["content": chu]
        case .doiYeuThich(let w):
            return ["wordId": w]
        case .taoThuMucSoTay(let c, let ten, let icon, let cha):
            var m: [String: Any] = ["code": c, "name": ten]
            if let icon { m["icon"] = icon }
            if let cha { m["parentId"] = cha }
            return m
        case .doiTenThuMucSoTay(_, let ten, let icon):
            var m: [String: Any] = ["name": ten]
            if let icon { m["icon"] = icon }
            return m
        case .taoMucSoTay(let c, let tm, let loai, let td, let than, let cd, let ng):
            var m: [String: Any] = ["code": c, "kind": loai, "title": td, "body": than]
            // `folderId` KHÔNG gửi khi ở gốc: backend đọc `!= null` để phân
            // biệt "thư mục gốc" với "không đổi".
            if let tm { m["folderId"] = tm }
            if let cd, !cd.isEmpty { m["reading"] = cd }
            if let ng, !ng.isEmpty { m["meaning"] = ng }
            return m
        case .suaMucSoTay(_, let td, let than, let cd, let ng, let loai):
            return ["title": td, "body": than, "kind": loai,
                    "reading": cd ?? "", "meaning": ng ?? ""]
        case .chuyenMucSoTay(_, let tm):
            var m: [String: Any] = [:]
            if let tm { m["folderId"] = tm }
            return m
        case .onMucSoTay(_, let cl):
            return ["quality": cl]
        case .ghiTienDoBaiTap(_, let tt):
            return ["status": tt]
        case .luuMaBaiTap(_, let ma, let ng):
            return ["savedCode": [["name": "main", "language": ng, "code": ma]]]
        case .chamMaBaiTap(_, let ma):
            return ["code": ma]
        case .ghiChuCauHoi(_, let g):
            return ["note": g]
        case .nopBaiLuyen(let c, let key, let dung, let tong, let sai, let idSai, let idDung):
            return ["languageCode": c, "lessonKey": key, "correct": dung,
                    "total": tong, "mistakes": sai,
                    "wrongIds": idSai, "rightIds": idDung]
        case .register(let u, let e, let p, let f, let c):
            var m: [String: Any] = ["username": u, "email": e, "password": p]
            if let name = f { m["fullName"] = name }
            if let t = c { m["cf-turnstile-response"] = t }
            return m
        case .oauthToken(let payload):
            return payload
        case .changePassword(let current, let new):
            // The backend validates confirmPassword === newPassword.
            return ["currentPassword": current, "newPassword": new, "confirmPassword": new]
        case .createPost(let d): return d
        case .updateProfile(let d): return d
        case .themViec(let d): return d
        case .guiGiaoDichApple(let jws): return ["jws": jws]
        case .ketThucNgay(let hn): return ["homNay": hn]
        case .suaViec(_, let d): return d
        case .themBuoiHoc(let d): return d
        case .suaBuoiHoc(_, let d): return d
        case .nhapLichHoc(let items, let thayThe): return ["items": items, "thayThe": thayThe]
        case .chamDiemDanh(_, let d): return d
        case .themHocKy(let d): return d
        case .suaHocKy(_, let d): return d
        case .themBuoiThi(let d): return d
        case .suaBuoiThi(_, let d): return d
        case .updateNote(_, let d): return d
        case .reactPost(_, let t): return ["type": t]
        // Backend `POST /users/follow` is a toggle keyed by `targetId`.
        case .followUser(let id): return ["targetId": id]
        case .unfollowUser(let id): return ["targetId": id]
        case .createComment(let postId, let c, let p, let mUrl, let mKind):
            var m: [String: Any] = ["postId": postId, "content": c]
            if let p { m["parentId"] = p }
            // Máy chủ chỉ nhận media khi CÓ ĐỦ cặp url + kind, và kind phải là
            // gif | sticker | image.
            if let mUrl, let mKind, !mUrl.isEmpty { m["mediaUrl"] = mUrl; m["mediaKind"] = mKind }
            return m
        case .savePost(_, let f):
            return f != nil ? ["folder": f!] : nil
        case .sendMessageMedia(_, let u, let k):
            return ["media": ["url": u, "kind": k]]
        case .toggleMessageReaction(_, let e):
            return ["emoji": e]
        case .suaDongBang(_, let v):
            // Máy chủ nhận NGUYÊN bản đồ `values`, không nhận từng ô lẻ.
            return ["values": v]
        case .chayViecAI(let a, let sel):
            return ["action": a, "selection": sel]
        case .hoiTroLyGhiChu(let q):
            return ["question": q]
        case .taoPhienChat(let t):
            return t.map { ["title": $0] } ?? [:]
        case .suaPhienChat(_, let d): return d
        case .taoThuMucChat(let ten, let mau):
            var d: [String: Any] = ["ten": ten]
            if let mau { d["mau"] = mau }
            return d
        case .chuyenThuMuc(_, let fid):
            // `null` là BỎ khỏi thư mục — khác hẳn không gửi trường.
            return ["folderId": fid as Any]
        case .datViecDoc(let t, let v):
            var m: [String: Any] = ["text": t]
            if let v { m["voice"] = v }
            return m
        case .tachNhanhPhien(_, let i): return ["denChiSo": i]
        case .catPhien(_, let i): return ["tuChiSo": i]
        case .baoCaoTraLoiAI(let mid):
            return ["messageId": mid ?? 0, "rating": 1, "feedbackType": "REPORT",
                    "comment": "Người dùng báo cáo từ app iOS"]
        case .suaBaiViet(_, let d): return d
        case .themTuVung(let nid, let t, let r, let m, let e):
            var d: [String: Any] = ["noteId": nid, "term": t]
            if let r, !r.isEmpty { d["reading"] = r }
            if let m, !m.isEmpty { d["meaning"] = m }
            if let e, !e.isEmpty { d["example"] = e }
            return d
        case .suaTuVung(_, let d): return d
        case .chamThe(let vid, let k): return ["vocabId": vid, "known": k]
        case .datLaiThe(let vid): return ["vocabId": vid]
        case .taoChuong(let sid, let t):
            return ["subjectId": sid, "title": t]
        case .taoMon(let n, let c, let e):
            var m: [String: Any] = ["name": n]
            if let c { m["color"] = c }
            if let e { m["emoji"] = e }
            return m
        case .suaMon(_, let d): return d
        case .suaChuong(_, let t): return ["title": t]
        case .dangKyThietBi(let t, let sb):
            return ["token": t, "platform": "ios", "sandbox": sb]
        case .taoTin(let u, let k, let c):
            var m: [String: Any] = ["mediaUrl": u, "mediaType": k, "visibility": "PUBLIC"]
            if let c, !c.isEmpty { m["caption"] = c }
            return m
        case .datBietDanh(_, let t, let a):
            return ["targetId": t, "alias": a]
        case .datTuyChonHoiThoai(_, let slot, let v):
            // `value: nil` PHẢI gửi thành JSON `null` chứ không được bỏ khoá —
            // máy chủ hiểu `null` là "xoá ô này", còn thiếu khoá cũng ra null
            // nhưng dựa vào đó là dựa vào một sự trùng hợp.
            return ["slot": slot, "value": v as Any]
        case .sendMessageWithFiles(_, let c, let ids):
            // `content` rỗng vẫn phải gửi khoá: tin chỉ có ảnh là hợp lệ.
            return ["content": c, "fileIds": ids]
        case .sendMessage(_, let c, let t, let cha):
            var m: [String: Any] = ["content": c, "type": t]
            if let cha { m["parentMessageId"] = cha }
            return m
        case .createNote(let s, let ch, let t):
            var m: [String: Any] = ["subjectId": s]
            if let chapter = ch { m["chapterId"] = chapter }
            if let title = t { m["title"] = title }
            return m
        case .reportPost(_, let reason, let details):
            var m: [String: Any] = ["reason": reason]
            if let d = details, !d.isEmpty { m["details"] = d }
            return m
        case .reportThread(_, let reason):
            return ["reason": reason]
        case .blockUser(_, let reason):
            return reason != nil ? ["reason": reason!] : nil
        case .requestDeletion(let reason):
            return reason != nil ? ["reason": reason!] : nil
        case .muteThread(_, let phut):
            // Gửi NSNull chứ không bỏ trắng: bỏ trắng thì backend đọc ra
            // `undefined` và cũng hiểu là vô thời hạn, nhưng gửi thẳng cho rõ.
            return ["durationMinutes": phut as Any? ?? NSNull()]
        case .markNotificationsRead(let ids):
            // Thân rỗng cũng được hiểu là "tất cả", nhưng gửi rõ ràng để
            // không phụ thuộc vào hành vi mặc định của backend.
            return ids.map { ["ids": $0] } ?? ["all": true]
        case .saveLessonProgress(_, let lessonId, let xong, let daXem, let viTri):
            var m: [String: Any] = ["lessonId": lessonId]
            if let xong { m["isCompleted"] = xong }
            if let daXem { m["watchTimeSeconds"] = daXem }
            if let viTri { m["lastPositionSeconds"] = viTri }
            return m
        case .refreshToken(let t): return ["refreshToken": t]
        default: return nil
        }
    }

    var queryParams: [String: Any]? {
        switch self {
        // ⚠️ Tham số của GET PHẢI ở ĐÂY, không phải ở `body`. Đặt `httpBody`
        // lên một yêu cầu GET thì URLSession ném
        // `NSURLErrorDataLengthExceedsMaximum` — hiện ra thành câu
        // "resource exceeds maximum size", nghe như ảnh quá nặng nên rất khó
        // lần ra. Ba đường dưới đây từng dính đúng lỗi này: bảng GIF không tải
        // được, và tìm/lọc ghi chú cũng hỏng câm y hệt.
        case .searchGifs(let q):
            return q.isEmpty ? nil : ["q": q]
        case .luyenChuong(_, let ngauNhien, let gioiHan):
            var m: [String: Any] = [:]
            if ngauNhien { m["random"] = 1 }
            if gioiHan > 0 { m["limit"] = gioiHan }
            return m.isEmpty ? nil : m
        case .tienDoCodeLab(let id):
            return ["trackId": id]
        case .dsDuAn(let dm, let tim, let trang):
            var m: [String: Any] = ["page": trang, "limit": 12]
            if let dm, !dm.isEmpty { m["category"] = dm }
            if !tim.isEmpty { m["search"] = tim }
            return m
        case .dsSnippet(let dm, let ng, let tim, let trang):
            var m: [String: Any] = ["page": trang, "limit": 20]
            if let dm { m["categoryId"] = dm }
            if let ng { m["language"] = ng }
            if !tim.isEmpty { m["search"] = tim }   // ⚠️ `search`, không phải `q`
            return m
        case .dsBaiTapCode(let nhom, let lt, let kho, let ng, let tim, let sap, let trang):
            // Trang 12, cố ý NHỎ. Danh sách trả về cả HTML đề bài lẫn mã lời
            // giải, và cỡ bài rất chênh: đo thật 25 bài trung bình ~343KB,
            // nhưng 25 bài **Java là 1.005KB** (~40KB/bài). Để 20 thì gặp
            // đúng lô Java là mỗi lần cuộn tải ~800KB — quá nặng cho 4G.
            var m: [String: Any] = ["page": trang, "limit": 12]
            if let nhom { m["groupId"] = nhom }
            if let lt { m["trackId"] = lt }
            if let kho { m["difficulty"] = kho }
            if let ng { m["language"] = ng }
            if !tim.isEmpty { m["q"] = tim }
            if let sap { m["sort"] = sap }
            return m
        case .dsPhienChat(let luuTru, let fid):
            var d: [String: Any] = [:]
            // Chỉ gửi khi BẬT: backend đọc `archived === '1'`, gửi "0" cũng
            // vô hại nhưng thừa một tham số trong mọi URL.
            if luuTru { d["archived"] = "1" }
            if let fid { d["folderId"] = fid }
            return d.isEmpty ? nil : d
        case .timGhiChu(let q, let sid, let tag):
            var m: [String: Any] = [:]
            if !q.isEmpty { m["q"] = q }
            if let sid { m["subjectId"] = sid }
            if let tag, !tag.isEmpty { m["tag"] = tag }
            return m.isEmpty ? nil : m
        case .locGhiChu(let f):
            return ["f": f]
        // Hai đường này là GET — tham số PHẢI ở đây, không phải `body`.
        // Đặt vào body thì URLSession ném "resource exceeds maximum size".
        case .layTuVung(let nid): return ["noteId": nid]
        case .layBoThe(let nid): return ["noteId": nid]
        case .getFeed(let c, let l, let t, let v, let h, let boLoat):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            if let type = t { m["type"] = type }
            if let vid = v { m["videoCategoryId"] = vid }
            if let tag = h { m["hashtag"] = tag }
            if boLoat { m["excludeSeries"] = "true" }
            return m
        case .getPostCounts(let boLoat):
            return boLoat ? ["excludeSeries": "true"] : [:]
        case .getComments(_, let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .getUserPosts(_, let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .getThreads(let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .getMessages(_, let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .getCourses(let p, let s, let k):
            var m: [String: Any] = ["page": p, "size": s]
            if let keyword = k { m["keyword"] = keyword }
            return m
        case .getCoursesAcademy(let p, let s, let k):
            // `academy=1` là thứ DUY NHẤT phân biệt hai rổ khoá học.
            var m: [String: Any] = ["page": p, "size": s, "academy": 1]
            if let keyword = k { m["keyword"] = keyword }
            return m
        case .getNotifications(let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .getSavedPosts(let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .searchUsers(let q):
            return ["q": q, "limit": 20]
        case .timKiem(let q, let loai):
            return ["q": q, "loai": loai, "gioiHan": 20]
        case .tuVung(_, let cat, let p, let l):
            var m: [String: Any] = ["page": p, "limit": l]
            // ⚠️ KHÔNG có `level` ở đây. Đo thật: `?level=N5` trên /vocab
            // trả về ĐỦ 7.209 từ, tức là nó bị bỏ qua chứ không lọc. Lọc
            // theo cấp phải làm bằng cách chọn chủ đề thuộc cấp đó.
            if let cat { m["categoryId"] = cat }
            return m
        case .hangDoiOnTap(let c), .thongKeNgonNgu(let c):
            return ["languageCode": c]
        case .nguPhap(_, let lv, let p, let l):
            var m: [String: Any] = ["page": p, "limit": l]
            // Khác /vocab: ở đây `?level=` CÓ lọc thật — máy chủ trả kèm
            // `levels` để dựng thanh chọn, đúng khuôn của trang ngữ pháp.
            if let lv { m["level"] = lv }
            return m
        case .timTuVung(_, let q):
            return ["q": q]
        case .hoiThoai(_, let p, let l), .baiDoc(_, let p, let l), .hoiDap(_, let p, let l),
             .baiNghe(_, let p, let l):
            return ["page": p, "limit": l]
        default: return nil
        }
    }
}

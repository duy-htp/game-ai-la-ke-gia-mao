// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get gameTitle => 'AI LÀ KẺ GIẢ MẠO?';

  @override
  String get gameTagline => 'Đọc vị bạn bè. Giữ kín bí mật.';

  @override
  String get createRoom => 'TẠO PHÒNG';

  @override
  String get joinRoom => 'VÀO PHÒNG';

  @override
  String get profile => 'Hồ sơ';

  @override
  String get shop => 'Cửa hàng';

  @override
  String get settings => 'Cài đặt';

  @override
  String get comingSoon => 'Tính năng sẽ có trong cột mốc tiếp theo.';

  @override
  String get developmentEnvironment => 'BẢN PHÁT TRIỂN';

  @override
  String get stagingEnvironment => 'BẢN KIỂM THỬ';

  @override
  String get identityMarkLabel => 'Biểu tượng chiếc mặt nạ bí ẩn';

  @override
  String get authInitializing => 'Đang khôi phục người chơi…';

  @override
  String get retry => 'THỬ LẠI';

  @override
  String get chooseYourName => 'CHỌN TÊN CỦA BẠN';

  @override
  String get displayName => 'Tên hiển thị';

  @override
  String get usernameHint => 'Ví dụ: Dũng';

  @override
  String get chooseAvatar => 'CHỌN NHÂN VẬT';

  @override
  String get startPlaying => 'BẮT ĐẦU CHƠI';

  @override
  String avatarOption(int number) {
    return 'Nhân vật $number';
  }

  @override
  String playerLevel(int level) {
    return 'Cấp $level';
  }

  @override
  String coinBalance(int coins) {
    return 'Số dư $coins xu';
  }

  @override
  String get errorNetworkUnavailable =>
      'Không có kết nối mạng. Vui lòng thử lại.';

  @override
  String get errorSessionExpired =>
      'Phiên đăng nhập đã hết hạn. Vui lòng bắt đầu lại.';

  @override
  String get errorUnexpected => 'Đã xảy ra lỗi. Vui lòng thử lại.';

  @override
  String get errorConfiguration =>
      'Ứng dụng chưa được cấu hình kết nối máy chủ.';

  @override
  String get errorAuthInitialization => 'Không thể khởi tạo phiên người chơi.';

  @override
  String get errorAnonymousSignIn =>
      'Không thể tạo phiên khách. Vui lòng thử lại.';

  @override
  String get errorProfileLoad => 'Không thể tải hồ sơ. Vui lòng thử lại.';

  @override
  String get errorUsernameBlank => 'Vui lòng nhập tên hiển thị.';

  @override
  String get errorUsernameTooShort => 'Tên phải có ít nhất 2 ký tự.';

  @override
  String get errorUsernameTooLong => 'Tên không được dài quá 20 ký tự.';

  @override
  String get errorUsernameInvalidCharacters =>
      'Tên chứa ký tự không được hỗ trợ.';

  @override
  String get errorInvalidAvatar => 'Vui lòng chọn một nhân vật hợp lệ.';

  @override
  String get errorProfileCreation => 'Không thể tạo hồ sơ. Vui lòng thử lại.';

  @override
  String get gameType => 'Trò chơi';

  @override
  String get maximumPlayers => 'Số người tối đa';

  @override
  String get create => 'TẠO PHÒNG';

  @override
  String get join => 'VÀO PHÒNG';

  @override
  String get cancel => 'HỦY';

  @override
  String get enterRoomCode => 'NHẬP MÃ PHÒNG';

  @override
  String get roomCode => 'Mã phòng';

  @override
  String get roomCodeHint => 'Nhập mã gồm 6 ký tự do chủ phòng chia sẻ.';

  @override
  String get waitingRoom => 'PHÒNG CHỜ';

  @override
  String get players => 'Người chơi';

  @override
  String get host => 'Chủ phòng';

  @override
  String get leaveRoom => 'RỜI PHÒNG';

  @override
  String roomCodeValue(String code) {
    return 'Mã phòng $code';
  }

  @override
  String capacity(int current, int maximum) {
    return '$current/$maximum';
  }

  @override
  String get errorInvalidRoomCode => 'Mã phòng phải gồm đúng 6 ký tự hợp lệ.';

  @override
  String get errorRoomNotFound => 'Không tìm thấy phòng.';

  @override
  String get errorRoomClosed => 'Phòng này đã đóng.';

  @override
  String get errorRoomFull => 'Phòng đã đủ người.';

  @override
  String get errorAlreadyInRoom => 'Bạn đang ở trong một phòng khác.';

  @override
  String get errorUnsupportedGameType => 'Trò chơi này chưa được hỗ trợ.';

  @override
  String get errorInvalidMaxPlayers => 'Số người chơi phải từ 3 đến 10.';

  @override
  String get errorProfileRequired =>
      'Bạn cần hoàn tất hồ sơ trước khi vào phòng.';

  @override
  String get errorNotRoomMember => 'Bạn không còn ở trong phòng này.';

  @override
  String get errorRoomOperation => 'Không thể xử lý phòng. Vui lòng thử lại.';

  @override
  String get online => 'TRỰC TUYẾN';

  @override
  String get reconnecting => 'ĐANG KẾT NỐI LẠI...';

  @override
  String get onlineLower => 'Trực tuyến';

  @override
  String get disconnected => 'Mất kết nối';

  @override
  String get ready => 'SẴN SÀNG';

  @override
  String get notReady => 'CHƯA SẴN SÀNG';

  @override
  String get cancelReady => 'HỦY SẴN SÀNG';

  @override
  String get lobbySettings => 'CÀI ĐẶT PHÒNG';

  @override
  String get impostorCount => 'Số kẻ giả mạo';

  @override
  String get category => 'Chủ đề';

  @override
  String get randomCategory => 'Ngẫu nhiên';

  @override
  String get clueTime => 'Thời gian gợi ý';

  @override
  String get discussionTime => 'Thời gian thảo luận';

  @override
  String get saveSettings => 'LƯU CÀI ĐẶT';

  @override
  String get minimumPlayersRequired => 'Cần ít nhất 3 người chơi';

  @override
  String waitingReadyPlayers(int count) {
    return 'Đang chờ $count người sẵn sàng';
  }

  @override
  String get invalidLobbySettings => 'Cài đặt phòng chưa hợp lệ';

  @override
  String get startGame => 'BẮT ĐẦU';

  @override
  String get startAvailableMilestoneFive => 'BẮT ĐẦU · MILESTONE 5';

  @override
  String get categoryFood => 'Đồ ăn';

  @override
  String get categoryAnimals => 'Động vật';

  @override
  String get categoryPlaces => 'Địa điểm';

  @override
  String get categoryObjects => 'Đồ vật';

  @override
  String get categoryJobs => 'Nghề nghiệp';

  @override
  String get categorySports => 'Thể thao';

  @override
  String get categoryEntertainment => 'Giải trí';

  @override
  String get categoryVietnam => 'Việt Nam';

  @override
  String get categoryFriends => 'Bạn bè';

  @override
  String get categoryRelationships => 'Các mối quan hệ';

  @override
  String get holdToReveal => 'NHẤN GIỮ ĐỂ XEM VAI TRÒ';

  @override
  String get youAreNormal => 'BẠN LÀ NGƯỜI THƯỜNG';

  @override
  String get youAreImpostor => 'BẠN LÀ KẺ GIẢ MẠO';

  @override
  String get secretKeyword => 'TỪ KHÓA';

  @override
  String get impostorHint => 'Hãy quan sát manh mối và tìm ra từ khóa.';

  @override
  String get remembered => 'ĐÃ NHỚ';

  @override
  String get secretHidden => 'Vai trò đang được ẩn';

  @override
  String get errorGameOperation => 'Không thể bắt đầu hoặc tải ván chơi.';

  @override
  String get errorSecretUnavailable =>
      'Không thể tải vai trò bí mật. Vui lòng thử lại.';

  @override
  String get clueRound => 'VÒNG MANH MỐI';

  @override
  String get yourClueTurn => 'ĐẾN LƯỢT BẠN';

  @override
  String waitingForClue(String username) {
    return 'Đang chờ $username đưa manh mối...';
  }

  @override
  String get clueHint => 'Nhập manh mối (tối đa 80 ký tự)';

  @override
  String get submitClue => 'GỬI MANH MỐI';

  @override
  String get submittedClues => 'Các manh mối';

  @override
  String get noClueSubmitted => 'Không đưa ra manh mối';

  @override
  String get discussion => 'THẢO LUẬN';

  @override
  String get votingWillFollow =>
      'Bình chọn sẽ được triển khai ở milestone tiếp theo.';

  @override
  String get errorInvalidClue =>
      'Manh mối không hợp lệ. Hãy chọn manh mối khác.';

  @override
  String get errorNotCurrentTurn => 'Chưa đến lượt của bạn.';

  @override
  String get errorTurnExpired => 'Thời gian đưa manh mối đã hết.';

  @override
  String get errorClueAlreadySubmitted => 'Lượt này đã có manh mối.';
}

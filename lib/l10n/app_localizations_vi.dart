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
  String get errorNetworkUnavailable =>
      'Không có kết nối mạng. Vui lòng thử lại.';

  @override
  String get errorSessionExpired =>
      'Phiên đăng nhập đã hết hạn. Vui lòng bắt đầu lại.';

  @override
  String get errorUnexpected => 'Đã xảy ra lỗi. Vui lòng thử lại.';
}

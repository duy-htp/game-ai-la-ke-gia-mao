import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @gameTitle.
  ///
  /// In vi, this message translates to:
  /// **'AI LÀ KẺ GIẢ MẠO?'**
  String get gameTitle;

  /// No description provided for @gameTagline.
  ///
  /// In vi, this message translates to:
  /// **'Đọc vị bạn bè. Giữ kín bí mật.'**
  String get gameTagline;

  /// No description provided for @createRoom.
  ///
  /// In vi, this message translates to:
  /// **'TẠO PHÒNG'**
  String get createRoom;

  /// No description provided for @joinRoom.
  ///
  /// In vi, this message translates to:
  /// **'VÀO PHÒNG'**
  String get joinRoom;

  /// No description provided for @profile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get profile;

  /// No description provided for @shop.
  ///
  /// In vi, this message translates to:
  /// **'Cửa hàng'**
  String get shop;

  /// No description provided for @settings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settings;

  /// No description provided for @comingSoon.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng sẽ có trong cột mốc tiếp theo.'**
  String get comingSoon;

  /// No description provided for @developmentEnvironment.
  ///
  /// In vi, this message translates to:
  /// **'BẢN PHÁT TRIỂN'**
  String get developmentEnvironment;

  /// No description provided for @stagingEnvironment.
  ///
  /// In vi, this message translates to:
  /// **'BẢN KIỂM THỬ'**
  String get stagingEnvironment;

  /// No description provided for @identityMarkLabel.
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng chiếc mặt nạ bí ẩn'**
  String get identityMarkLabel;

  /// No description provided for @authInitializing.
  ///
  /// In vi, this message translates to:
  /// **'Đang khôi phục người chơi…'**
  String get authInitializing;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'THỬ LẠI'**
  String get retry;

  /// No description provided for @chooseYourName.
  ///
  /// In vi, this message translates to:
  /// **'CHỌN TÊN CỦA BẠN'**
  String get chooseYourName;

  /// No description provided for @displayName.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị'**
  String get displayName;

  /// No description provided for @usernameHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Dũng'**
  String get usernameHint;

  /// No description provided for @chooseAvatar.
  ///
  /// In vi, this message translates to:
  /// **'CHỌN NHÂN VẬT'**
  String get chooseAvatar;

  /// No description provided for @startPlaying.
  ///
  /// In vi, this message translates to:
  /// **'BẮT ĐẦU CHƠI'**
  String get startPlaying;

  /// No description provided for @avatarOption.
  ///
  /// In vi, this message translates to:
  /// **'Nhân vật {number}'**
  String avatarOption(int number);

  /// No description provided for @playerLevel.
  ///
  /// In vi, this message translates to:
  /// **'Cấp {level}'**
  String playerLevel(int level);

  /// No description provided for @coinBalance.
  ///
  /// In vi, this message translates to:
  /// **'Số dư {coins} xu'**
  String coinBalance(int coins);

  /// No description provided for @errorNetworkUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết nối mạng. Vui lòng thử lại.'**
  String get errorNetworkUnavailable;

  /// No description provided for @errorSessionExpired.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập đã hết hạn. Vui lòng bắt đầu lại.'**
  String get errorSessionExpired;

  /// No description provided for @errorUnexpected.
  ///
  /// In vi, this message translates to:
  /// **'Đã xảy ra lỗi. Vui lòng thử lại.'**
  String get errorUnexpected;

  /// No description provided for @errorConfiguration.
  ///
  /// In vi, this message translates to:
  /// **'Ứng dụng chưa được cấu hình kết nối máy chủ.'**
  String get errorConfiguration;

  /// No description provided for @errorAuthInitialization.
  ///
  /// In vi, this message translates to:
  /// **'Không thể khởi tạo phiên người chơi.'**
  String get errorAuthInitialization;

  /// No description provided for @errorAnonymousSignIn.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tạo phiên khách. Vui lòng thử lại.'**
  String get errorAnonymousSignIn;

  /// No description provided for @errorProfileLoad.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải hồ sơ. Vui lòng thử lại.'**
  String get errorProfileLoad;

  /// No description provided for @errorUsernameBlank.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên hiển thị.'**
  String get errorUsernameBlank;

  /// No description provided for @errorUsernameTooShort.
  ///
  /// In vi, this message translates to:
  /// **'Tên phải có ít nhất 2 ký tự.'**
  String get errorUsernameTooShort;

  /// No description provided for @errorUsernameTooLong.
  ///
  /// In vi, this message translates to:
  /// **'Tên không được dài quá 20 ký tự.'**
  String get errorUsernameTooLong;

  /// No description provided for @errorUsernameInvalidCharacters.
  ///
  /// In vi, this message translates to:
  /// **'Tên chứa ký tự không được hỗ trợ.'**
  String get errorUsernameInvalidCharacters;

  /// No description provided for @errorInvalidAvatar.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn một nhân vật hợp lệ.'**
  String get errorInvalidAvatar;

  /// No description provided for @errorProfileCreation.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tạo hồ sơ. Vui lòng thử lại.'**
  String get errorProfileCreation;

  /// No description provided for @gameType.
  ///
  /// In vi, this message translates to:
  /// **'Trò chơi'**
  String get gameType;

  /// No description provided for @maximumPlayers.
  ///
  /// In vi, this message translates to:
  /// **'Số người tối đa'**
  String get maximumPlayers;

  /// No description provided for @create.
  ///
  /// In vi, this message translates to:
  /// **'TẠO PHÒNG'**
  String get create;

  /// No description provided for @join.
  ///
  /// In vi, this message translates to:
  /// **'VÀO PHÒNG'**
  String get join;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'HỦY'**
  String get cancel;

  /// No description provided for @enterRoomCode.
  ///
  /// In vi, this message translates to:
  /// **'NHẬP MÃ PHÒNG'**
  String get enterRoomCode;

  /// No description provided for @roomCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã phòng'**
  String get roomCode;

  /// No description provided for @roomCodeHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã gồm 6 ký tự do chủ phòng chia sẻ.'**
  String get roomCodeHint;

  /// No description provided for @waitingRoom.
  ///
  /// In vi, this message translates to:
  /// **'PHÒNG CHỜ'**
  String get waitingRoom;

  /// No description provided for @players.
  ///
  /// In vi, this message translates to:
  /// **'Người chơi'**
  String get players;

  /// No description provided for @host.
  ///
  /// In vi, this message translates to:
  /// **'Chủ phòng'**
  String get host;

  /// No description provided for @leaveRoom.
  ///
  /// In vi, this message translates to:
  /// **'RỜI PHÒNG'**
  String get leaveRoom;

  /// No description provided for @roomCodeValue.
  ///
  /// In vi, this message translates to:
  /// **'Mã phòng {code}'**
  String roomCodeValue(String code);

  /// No description provided for @capacity.
  ///
  /// In vi, this message translates to:
  /// **'{current}/{maximum}'**
  String capacity(int current, int maximum);

  /// No description provided for @errorInvalidRoomCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã phòng phải gồm đúng 6 ký tự hợp lệ.'**
  String get errorInvalidRoomCode;

  /// No description provided for @errorRoomNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy phòng.'**
  String get errorRoomNotFound;

  /// No description provided for @errorRoomClosed.
  ///
  /// In vi, this message translates to:
  /// **'Phòng này đã đóng.'**
  String get errorRoomClosed;

  /// No description provided for @errorRoomFull.
  ///
  /// In vi, this message translates to:
  /// **'Phòng đã đủ người.'**
  String get errorRoomFull;

  /// No description provided for @errorAlreadyInRoom.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang ở trong một phòng khác.'**
  String get errorAlreadyInRoom;

  /// No description provided for @errorUnsupportedGameType.
  ///
  /// In vi, this message translates to:
  /// **'Trò chơi này chưa được hỗ trợ.'**
  String get errorUnsupportedGameType;

  /// No description provided for @errorInvalidMaxPlayers.
  ///
  /// In vi, this message translates to:
  /// **'Số người chơi phải từ 3 đến 10.'**
  String get errorInvalidMaxPlayers;

  /// No description provided for @errorProfileRequired.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần hoàn tất hồ sơ trước khi vào phòng.'**
  String get errorProfileRequired;

  /// No description provided for @errorNotRoomMember.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không còn ở trong phòng này.'**
  String get errorNotRoomMember;

  /// No description provided for @errorRoomOperation.
  ///
  /// In vi, this message translates to:
  /// **'Không thể xử lý phòng. Vui lòng thử lại.'**
  String get errorRoomOperation;

  /// No description provided for @online.
  ///
  /// In vi, this message translates to:
  /// **'TRỰC TUYẾN'**
  String get online;

  /// No description provided for @reconnecting.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG KẾT NỐI LẠI...'**
  String get reconnecting;

  /// No description provided for @onlineLower.
  ///
  /// In vi, this message translates to:
  /// **'Trực tuyến'**
  String get onlineLower;

  /// No description provided for @disconnected.
  ///
  /// In vi, this message translates to:
  /// **'Mất kết nối'**
  String get disconnected;

  /// No description provided for @ready.
  ///
  /// In vi, this message translates to:
  /// **'SẴN SÀNG'**
  String get ready;

  /// No description provided for @notReady.
  ///
  /// In vi, this message translates to:
  /// **'CHƯA SẴN SÀNG'**
  String get notReady;

  /// No description provided for @cancelReady.
  ///
  /// In vi, this message translates to:
  /// **'HỦY SẴN SÀNG'**
  String get cancelReady;

  /// No description provided for @lobbySettings.
  ///
  /// In vi, this message translates to:
  /// **'CÀI ĐẶT PHÒNG'**
  String get lobbySettings;

  /// No description provided for @impostorCount.
  ///
  /// In vi, this message translates to:
  /// **'Số kẻ giả mạo'**
  String get impostorCount;

  /// No description provided for @category.
  ///
  /// In vi, this message translates to:
  /// **'Chủ đề'**
  String get category;

  /// No description provided for @randomCategory.
  ///
  /// In vi, this message translates to:
  /// **'Ngẫu nhiên'**
  String get randomCategory;

  /// No description provided for @clueTime.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian gợi ý'**
  String get clueTime;

  /// No description provided for @discussionTime.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian thảo luận'**
  String get discussionTime;

  /// No description provided for @saveSettings.
  ///
  /// In vi, this message translates to:
  /// **'LƯU CÀI ĐẶT'**
  String get saveSettings;

  /// No description provided for @minimumPlayersRequired.
  ///
  /// In vi, this message translates to:
  /// **'Cần ít nhất 3 người chơi'**
  String get minimumPlayersRequired;

  /// No description provided for @waitingReadyPlayers.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ {count} người sẵn sàng'**
  String waitingReadyPlayers(int count);

  /// No description provided for @invalidLobbySettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt phòng chưa hợp lệ'**
  String get invalidLobbySettings;

  /// No description provided for @startGame.
  ///
  /// In vi, this message translates to:
  /// **'BẮT ĐẦU'**
  String get startGame;

  /// No description provided for @startAvailableMilestoneFive.
  ///
  /// In vi, this message translates to:
  /// **'BẮT ĐẦU · MILESTONE 5'**
  String get startAvailableMilestoneFive;

  /// No description provided for @categoryFood.
  ///
  /// In vi, this message translates to:
  /// **'Đồ ăn'**
  String get categoryFood;

  /// No description provided for @categoryAnimals.
  ///
  /// In vi, this message translates to:
  /// **'Động vật'**
  String get categoryAnimals;

  /// No description provided for @categoryPlaces.
  ///
  /// In vi, this message translates to:
  /// **'Địa điểm'**
  String get categoryPlaces;

  /// No description provided for @categoryObjects.
  ///
  /// In vi, this message translates to:
  /// **'Đồ vật'**
  String get categoryObjects;

  /// No description provided for @categoryJobs.
  ///
  /// In vi, this message translates to:
  /// **'Nghề nghiệp'**
  String get categoryJobs;

  /// No description provided for @categorySports.
  ///
  /// In vi, this message translates to:
  /// **'Thể thao'**
  String get categorySports;

  /// No description provided for @categoryEntertainment.
  ///
  /// In vi, this message translates to:
  /// **'Giải trí'**
  String get categoryEntertainment;

  /// No description provided for @categoryVietnam.
  ///
  /// In vi, this message translates to:
  /// **'Việt Nam'**
  String get categoryVietnam;

  /// No description provided for @categoryFriends.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bè'**
  String get categoryFriends;

  /// No description provided for @categoryRelationships.
  ///
  /// In vi, this message translates to:
  /// **'Các mối quan hệ'**
  String get categoryRelationships;

  /// No description provided for @holdToReveal.
  ///
  /// In vi, this message translates to:
  /// **'NHẤN GIỮ ĐỂ XEM VAI TRÒ'**
  String get holdToReveal;

  /// No description provided for @youAreNormal.
  ///
  /// In vi, this message translates to:
  /// **'BẠN LÀ NGƯỜI THƯỜNG'**
  String get youAreNormal;

  /// No description provided for @youAreImpostor.
  ///
  /// In vi, this message translates to:
  /// **'BẠN LÀ KẺ GIẢ MẠO'**
  String get youAreImpostor;

  /// No description provided for @secretKeyword.
  ///
  /// In vi, this message translates to:
  /// **'TỪ KHÓA'**
  String get secretKeyword;

  /// No description provided for @impostorHint.
  ///
  /// In vi, this message translates to:
  /// **'Hãy quan sát manh mối và tìm ra từ khóa.'**
  String get impostorHint;

  /// No description provided for @remembered.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ NHỚ'**
  String get remembered;

  /// No description provided for @secretHidden.
  ///
  /// In vi, this message translates to:
  /// **'Vai trò đang được ẩn'**
  String get secretHidden;

  /// No description provided for @errorGameOperation.
  ///
  /// In vi, this message translates to:
  /// **'Không thể bắt đầu hoặc tải ván chơi.'**
  String get errorGameOperation;

  /// No description provided for @errorSecretUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải vai trò bí mật. Vui lòng thử lại.'**
  String get errorSecretUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

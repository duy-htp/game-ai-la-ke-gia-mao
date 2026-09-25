# Thiết lập môi trường

## Phiên bản đã xác minh

- macOS 26.6.2 (`darwin-arm64`)
- Flutter 3.47.5 stable, revision `6a19cca564`
- Dart 3.13.4 stable
- DevTools 2.60.0
- Java OpenJDK 23.0.2 (system; Android build chưa được xác minh)

Flutter được cài bằng Homebrew tại `/opt/homebrew/share/flutter`.

## Khởi chạy

```sh
flutter pub get
flutter run --dart-define=APP_ENV=development
```

Giá trị `APP_ENV` hợp lệ: `development`, `staging`, `production`. Nếu không
truyền, ứng dụng dùng `development`. Giá trị khác sẽ dừng bootstrap với lỗi rõ
ràng.

Để dùng file cấu hình:

```sh
cp config/development.example.json config/development.json
flutter run --dart-define-from-file=config/development.json
```

`config/*.json` bị Git bỏ qua; chỉ file `*.example.json` được commit. Không đặt
secret trong repository. Milestone 2 dùng:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (chấp nhận publishable key hiện hành)

Ứng dụng tuyệt đối không nhận service-role key, database password hoặc JWT
secret.

## Supabase local

Supabase CLI 2.117.0 được chạy qua npm vì Homebrew bị chặn bởi Command Line
Tools cũ:

```sh
npx --yes supabase@latest start
npx --yes supabase@latest db reset
npx --yes supabase@latest test db
npx --yes supabase@latest stop
```

Docker daemon phải hoạt động. Local config bật anonymous sign-in và migration
tự động được áp từ `supabase/migrations`.

## Supabase remote development

1. Tạo development project riêng trên Supabase.
2. Áp migration bằng Supabase CLI, không tạo schema thủ công trong Dashboard.
3. Trong Dashboard mở **Authentication → Providers → Anonymous Sign-Ins** và
   bật anonymous sign-in. Đây là Auth service setting, không nằm trong SQL
   migration.
4. Sao chép Project URL và publishable/anon key vào file config local bị ignore.
5. Không dùng staging/production credentials cho development.

Anonymous user không mặc nhiên đáng tin cậy. Trước release cần xem xét account
creation spam, room spam, rate limiting, device abuse và rewarded-ad abuse.

## Application identity

Android application ID và iOS bundle ID là `com.duyhtp.ailakegiamao`. Namespace
này cần được rà soát trước production release.

## Trạng thái native toolchain

`flutter doctor -v` ngày 24-09-2026 xác nhận Flutter, Chrome, network và thiết
bị macOS/web hoạt động. Native mobile chưa sẵn sàng:

- Android: chưa có Android SDK/Android Studio. Cài Android Studio, dùng SDK
  Manager cài Android SDK/Platform Tools, rồi chạy `flutter doctor -v`. Nếu SDK
  ở vị trí tùy chỉnh: `flutter config --android-sdk <đường-dẫn-sdk>`.
- iOS: chỉ có Command Line Tools, thiếu Xcode đầy đủ và CocoaPods. Cài Xcode,
  sau đó chạy `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
  và `sudo xcodebuild -runFirstLaunch`; cài CocoaPods theo hướng dẫn chính thức.

Không cần các IDE/native tool này để chạy analyze và widget/unit tests.

`supabase_flutter` thêm native plugin dependencies; build thiết bị thật vẫn
chưa được xác minh cho tới khi Android SDK/Xcode/CocoaPods sẵn sàng.

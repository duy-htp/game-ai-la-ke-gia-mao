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
secret trong repository. Milestone 1 chưa có cấu hình Supabase.

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

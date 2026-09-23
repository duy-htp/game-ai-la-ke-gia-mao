# AI LÀ KẺ GIẢ MẠO?

Ứng dụng party game social-deduction đa nền tảng dành cho iOS và Android.
Repository hiện hoàn thành **Milestone 1 — Foundation**; gameplay và backend
chưa được triển khai.

## Bắt đầu nhanh

Yêu cầu Flutter 3.47.5 / Dart 3.13.4 hoặc phiên bản stable tương thích.

```sh
flutter pub get
flutter run --dart-define=APP_ENV=development
```

Hoặc tạo file local từ `config/development.example.json` rồi chạy:

```sh
flutter run --dart-define-from-file=config/development.json
```

Xem [hướng dẫn cài đặt](docs/setup.md), [kiến trúc](docs/architecture.md) và
[kiểm thử](docs/testing.md).

## Phạm vi hiện tại

- Riverpod và `go_router` foundation.
- Dark theme, localization tiếng Việt/Anh.
- Compile-time environment, logging có redaction và typed errors.
- Home foundation screen responsive.

Application ID hiện tại là `com.duyhtp.ailakegiamao` và cần được rà soát lại
trước khi phát hành production.

# AI LÀ KẺ GIẢ MẠO?

Ứng dụng party game social-deduction đa nền tảng dành cho iOS và Android.
Repository hiện hoàn thành **Milestone 3 — Private Rooms**. Realtime lobby,
ready state và gameplay chưa được triển khai.

## Bắt đầu nhanh

Yêu cầu Flutter 3.47.5 / Dart 3.13.4 hoặc phiên bản stable tương thích.

```sh
flutter pub get
cp config/development.example.json config/development.json
# Điền development Project URL và publishable key vào file local.
flutter run --dart-define-from-file=config/development.json
```

Hoặc truyền trực tiếp compile-time defines:

```sh
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Xem [hướng dẫn cài đặt](docs/setup.md), [kiến trúc](docs/architecture.md) và
[kiểm thử](docs/testing.md).

## Phạm vi hiện tại

- Riverpod và `go_router` foundation.
- Dark theme, localization tiếng Việt/Anh.
- Compile-time environment, logging có redaction và typed errors.
- Supabase Anonymous Auth và session restoration.
- Profile onboarding bảo mật qua RPC, RLS và PostgreSQL grants.
- Home hiển thị avatar, username, level và coins.
- Tạo/vào/rời private room qua transactional RPC.
- Room code server-generated, capacity-safe và hỗ trợ khôi phục sau restart.

Application ID hiện tại là `com.duyhtp.ailakegiamao` và cần được rà soát lại
trước khi phát hành production.

## Milestone 4 — Realtime lobby

Room hiện đồng bộ bằng Supabase Broadcast channel riêng tư. Broadcast và
Presence chỉ là tín hiệu; `get_current_room()` vẫn là nguồn sự thật sau event,
reconnect hoặc mobile resume. Người chơi dùng ready state idempotent, chủ phòng
lưu category/impostor/timer, và thay đổi settings sẽ reset ready của non-host.
Backend tự tính `can_start`; thao tác tạo game được giữ lại cho Milestone 5.

## Milestone 5 — Secure game engine

Host có thể khởi tạo một ván `role_reveal` bằng transaction server-authoritative.
Backend snapshot participant, chọn category/keyword, phân role và turn order bằng
random bytes phía server. Public game snapshot không chứa role hay keyword;
secret của từng người chỉ được trả bởi RPC không nhận player ID. Role Reveal yêu
cầu giữ một giây, tự ẩn sau năm giây và ẩn ngay khi app background.

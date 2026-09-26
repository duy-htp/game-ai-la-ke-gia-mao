# AI LÀ KẺ GIẢ MẠO?

Ứng dụng party game social-deduction đa nền tảng dành cho iOS và Android.
Repository hiện hoàn thành **Milestone 10 — Profile, Stats & Private History**:
hồ sơ editable, thống kê authoritative và lịch sử riêng tư có phân trang.

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

## Milestone 6 — Clue Round

Role acknowledgement, deadline, thứ tự lượt, clue validation và timeout đều do
database quyết định. `game_turns` lưu lịch sử submitted/timed-out; lượt cuối
chuyển sang Discussion.

## Milestone 7 — Discussion và Secure Voting

Discussion readiness, voting deadlines, private immutable ballots, aggregate
results và tối đa một revote đều do database điều khiển. Tie vòng hai được chọn
ngẫu nhiên bằng PostgreSQL secure randomness. Vote Result không tiết lộ role.

## Milestone 8 — Final Guess, Result và Rewards

Sau 5 giây hiển thị Vote Result, backend tự quyết định đi thẳng tới Result hoặc
cho impostor bị loại 20 giây để chọn một trong bốn đáp án opaque đã persist.
Winner, reward, level và stats đều được giải quyết atomically phía server với
ledger idempotent. Result chỉ tiết lộ role/keyword cho participant; host có thể
đưa chính room đó về Lobby bằng Chơi lại mà vẫn giữ settings và lịch sử.

## Milestone 9 — Multiplayer Reliability

Recovery coordinator cấp ứng dụng thực hiện authoritative refetch khi resume,
Realtime reconnect hoặc outcome mutation chưa chắc chắn. Refresh là single-flight
có một follow-up coalesced; generation loại response cũ, revision không bao giờ
lùi và deadline hội tụ bằng vòng advance giới hạn 16 bước. Presence vẫn chỉ là
UX: mất mạng không xóa membership hay đổi host.

## Milestone 10 — Profile, Stats & Private History

Profile screen đọc profile/stats qua RPC caller-scoped, cho đổi username/avatar
với cùng validation ở client và server, hiển thị XP/level/coins cùng sáu thống
kê. Lịch sử chỉ trả các ván Result mà caller đã tham gia, dùng keyset pagination
ổn định và reward lấy trực tiếp từ ledger. Sau Result hoặc khi recovery, client
refetch profile authoritative; profile/economy tables vẫn không mở direct read.

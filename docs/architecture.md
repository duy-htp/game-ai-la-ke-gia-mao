# Kiến trúc

## Nguyên tắc

Ứng dụng dùng kiến trúc feature-first và chỉ tạo lớp khi có trách nhiệm thực tế:

```text
UI → Controller/Notifier → Repository → Data source/service
```

`lib/core` chứa nền tảng dùng chung; `lib/features` chứa mã theo tính năng.
Milestone 2 có `AuthRepository`, `ProfileRepository` và một typed application
session controller vì các ranh giới này cô lập Supabase khỏi presentation và
cho phép kiểm thử không cần backend thật.

## Composition root

```text
main() → bootstrap() → ProviderScope → App → MaterialApp.router
```

`bootstrap` đọc cấu hình, khởi tạo đúng một `SupabaseClient`, rồi inject hai
repository. Riverpod là cơ chế DI và state management duy nhất.

Application session có các state loại trừ lẫn nhau:

```text
initializing
├─ authenticatedNeedsProfile → Onboarding
├─ authenticatedReady        → Home
├─ recoverableError          → Retry
└─ fatalConfigurationError   → Configuration message
```

`go_router` redirect theo state này. Gọi trực tiếp Home không thể bỏ qua
onboarding. Supabase SDK khôi phục session đã lưu; repository chỉ anonymous
sign-in khi không có session và gộp các request sign-in đồng thời.

Milestone 3 mở rộng ready state bằng một `RoomSnapshot?`. Sau khi profile được
tải, startup luôn gọi `RoomRepository.loadCurrentRoom()`: room hiện hữu chuyển
đến Room; không có room chuyển Home; lỗi truy vấn chuyển recoverable error.
Create/join/leave cập nhật snapshot duy nhất trong application session. Room
controller chỉ giữ trạng thái action tạm thời và idempotency key, không sao chép
authoritative room data.

## Ranh giới

- Widget không chứa luật game hay truy cập database.
- Backend sẽ là nguồn sự thật cho room và gameplay.
- Gameplay screen sau này phải được suy ra từ server game state.
- Secret không được đưa vào public state, Realtime event hoặc production log.
- `auth.uid()` là player identity duy nhất; username không phải định danh/login.
- Profile JSON được parse thành `PlayerProfile` trước khi đi vào UI.
- Room RPC trả `RoomSnapshot` an toàn thay vì raw table rows.
- Direct navigation không thể bỏ qua onboarding hoặc active-room guard.

## Realtime lobby authority

`AppSessionReady.room` là bản snapshot duy nhất trong Flutter.
`RoomRealtimeController` chỉ sở hữu lifecycle channel, trạng thái kết nối và
presence tạm thời. Private Broadcast mang `room_id` và có nghĩa “hãy refetch”.
Invalidation được gom trong 120 ms; generation counter và server revision chặn
response cũ ghi đè state mới. Reconnect và app resume đều refetch bằng RPC.

Presence key là authenticated user ID và luôn được giao với membership trong
snapshot. Mất Presence chỉ đổi chỉ báo online; không xóa membership hay chuyển
host. Chỉ explicit `leave_room()` mới kích hoạt host transfer ở Milestone 4.

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

## Game and secret boundaries

`AppSessionReady.game` chỉ chứa `GameSnapshot` công khai. Keyword/role không đi
vào session chung mà thuộc auto-disposed `RoleSecretController` trong
RoleRevealScreen. Startup khôi phục profile → room → public game rồi router dựa
trên server status. Room-scoped private Broadcast vẫn chỉ báo invalidation;
clients refetch room và game, sau đó tự gọi secret RPC cho chính mình.

## Authoritative clue loop

`GamePhaseController` gửi acknowledge/submit/advance và chỉ áp dụng snapshot
authoritative mới. Realtime vẫn là room-scoped invalidation; client refetch RPC.
Timer cục bộ chỉ hiển thị và gọi `advance_game_if_due()` một lần khi về 0;
`clock_timestamp()` cùng row lock phía database mới quyết định hết hạn.

## Secure voting

Flutter gửi `set_discussion_ready` và `submit_vote`, sau đó chỉ render snapshot.
Realtime tiếp tục là invalidation không chứa voter/target. Snapshot active voting
chỉ có candidate list, `N/total` và cờ caller-specific `currentUserHasVoted`.
Router ánh xạ trực tiếp `discussion`, `voting`, `vote_result`; resume/reconnect
khởi động lại room channel và refetch authoritative game.

## Final Guess, result and economy boundary

`GamePhaseController` chỉ gửi opaque `choice_id`, advance deadline và Play Again;
không tính winner/reward. `FinalGuessSnapshot` chỉ chứa bốn lựa chọn cho đúng
impostor bị loại; client khác nhận danh sách rỗng. `GameResultSnapshot` dùng enum
typed cho winner/reason, role và keyword chỉ xuất hiện khi status là `result`, và
reward summary chỉ thuộc caller hiện tại. Router ánh xạ `final_guess`/`result`
trực tiếp từ snapshot.

Realtime tiếp tục chỉ phát invalidation tối giản. Keyword, đáp án, winner,
reward và economy totals không đi trong Broadcast. Resume/reconnect luôn refetch
RPC; uniqueness trong database ngăn việc refetch hoặc retry cấp reward lần hai.

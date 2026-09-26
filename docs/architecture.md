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

## Recovery coordinator

`RecoveryController` sở hữu pipeline room/game recovery; `App` sở hữu lifecycle
observer, còn `RoomRealtimeController` sở hữu private channel/Presence.
Invalidation được debounce 120 ms rồi yêu cầu recovery, không mutate snapshot.

Recovery load room rồi game, hội tụ deadline tối đa 16 lần và áp dụng cặp
snapshot atomically. Một pass chạy tại một thời điểm; trigger trong lúc chạy vô
hiệu generation cũ và gom thành một follow-up. Cùng game/room ID không nhận
revision thấp hơn; same revision được thay thế vì các field caller-specific như
`currentUserHasVoted` và reward có thể đổi. Event không mang game authority nên
RPC current-state bảo vệ khỏi invalidation của game cũ.

Channel lifecycle là create → subscribe → replace khi room ID đổi → dispose khi
không còn room/app dispose. Presence biến mất không đổi membership, host, turn,
vote hoặc reward eligibility.

## Profile, stats and private history

`AppSessionReady.profile` là nguồn profile duy nhất cho UI. `ProfileController`
validate rồi gọi update RPC; response không chắc chắn được reconcile bằng
`get_my_profile()`. Profile refresh không tái tạo router. Khi game chuyển Result
và trong recovery, controller đọc lại totals authoritative thay vì cộng reward
ở client.

`GameHistoryController` giữ danh sách riêng tư, trạng thái lỗi/loading và cursor
`(finished_at, game_id)`. Pagination merge theo game ID để retry không nhân đôi.
Widget chỉ render typed models; không query Supabase hay tính stats/winner.

## Monetization authority

`MonetizationController` là state owner duy nhất cho entitlement/reward status;
ad load state thuộc `AdsService`, store state thuộc `PurchaseService`. Provider
SDK classes không đi vào Widgets. Supabase `auth.uid()` cũng là provider App User
ID ổn định; username/avatar không tham gia identity.

Result gate bỏ qua result đầu tiên và chỉ thử interstitial mỗi result thứ ba.
Failure luôn fail-open cho gameplay. Last-confirmed Remove Ads `true` được giữ khi
refresh lỗi để tránh hiện ads cho purchaser offline. Reward callback không sửa
coins; client refetch monetization/profile sau khi provider SSV xử lý.

RevenueCat webhook chỉ nhận minimal event, yêu cầu bearer secret, rồi gọi RPC
service-role. Event ID unique và provider timestamp ngăn duplicate/out-of-order
event làm entitlement lùi sai. Không gửi game secret, clue, vote hay keyword cho
provider; receipt/service secrets không nằm trong Flutter.

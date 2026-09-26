# Kiểm thử

Chạy quality gates:

```sh
dart format .
flutter analyze
flutter test
```

Bộ test Milestone 1 bao phủ:

- parse và validation ba environment;
- redaction token, authorization, keyword và role theo ngữ cảnh;
- ánh xạ typed error sang thông báo localized an toàn;
- app shell, initial Home route;
- locale mặc định tiếng Việt và locale tiếng Anh;
- Home trên viewport điện thoại nhỏ, các action và trạng thái chưa khả dụng.

Native integration/device tests sẽ được bổ sung ở milestone có native flow.

## Milestone 2

Flutter tests dùng fake repository và bao phủ session restoration, anonymous
sign-in, chống sign-in trùng, typed state transitions, profile fetch error,
username/avatar validation, onboarding success/failure, router guard, locale và
Home profile summary.

Database tests chạy thật trên Supabase local:

```sh
npx --yes supabase@latest db reset
npx --yes supabase@latest test db
```

File `supabase/tests/database/profiles_rls_test.sql` có 22 pgTAP assertions cho
RLS, grants, `auth.uid()`, economy defaults, validation và idempotency.

## Milestone 3

Flutter tests bao phủ RoomCode, safe snapshot parsing, typed RPC error mapping,
create/join/leave controller, create idempotency key, startup restore, router
guards, ba room screens, localization và viewport nhỏ.

Room pgTAP tests kiểm tra schema constraints, code generation/uniqueness/reuse,
create/join/leave idempotency, capacity, grants, privacy, history và host
transfer. Chạy cùng profile tests bằng:

```sh
npx --yes supabase@latest test db
```

Race test dùng hai PostgreSQL connections thật cùng chờ một room-row lock:

```sh
supabase/tests/concurrency/room_join_race.sh
```

Kỳ vọng: đúng một join thành công, một join nhận `room_full`, member count và
distinct active seats đều bằng capacity.

Milestone 4 thêm pgTAP `realtime_lobby_test.sql` và harness hai client thật:

```sh
dart run tool/realtime_lobby_harness.dart <local-api-url> <local-anon-key>
```

Harness xác minh join invalidation, Presence, authoritative refetch sau khi
subscription bị tháo/reconnect, settings invalidation và ready reset trên local
Supabase Realtime; đây không phải mock test.

Milestone 5 thêm pgTAP secrecy/invariant tests, race hai connection
`supabase/tests/concurrency/game_start_race.sh`, và harness ba client thật:

```sh
dart run tool/game_start_realtime_harness.dart <local-api-url> <publishable-key>
```

Harness kiểm tra tất cả client hội tụ vào cùng `role_reveal`, Broadcast không có
secret, đúng số impostor, impostor không có keyword, normal nhận cùng concept đã
chọn và reconnect khôi phục room/game/secret.

Milestone 6 thêm `clue_round_test.sql` cho acknowledgement, settings snapshot,
turn order, validation VI/EN, timeout history, Discussion entry, RLS và snapshot
secrecy. Concurrency/harness kiểm tra duplicate advancement, submit-timeout race,
Realtime convergence và reconnect giữa active clue turn.

Milestone 7 thêm `secure_voting_test.sql`, `voting_races.sh` và
`voting_realtime_harness.dart`. Coverage gồm ready idempotency/deadline, ballot
immutability/secrecy, abstention, unique result, first tie/revote, second tie
random resolution, concurrent final actions, Realtime payload privacy và
reconnect trước/sau vote.

Milestone 8 thêm `complete_game_test.sql` với reward matrix, Final Guess privacy,
winner/reason persistence, timeout, idempotency, stats, Play Again và round kế
tiếp. Race và complete-game harness chạy bằng:

```sh
bash supabase/tests/concurrency/result_reward_races.sh
dart run tool/complete_game_harness.dart <local-api-url> <publishable-key>
```

Concurrency xác minh hai advance, hai guess/reward resolution và hai Play Again
không tạo bản ghi trùng. Harness ba client đi qua ba scenario: normal bị loại,
impostor đoán sai và impostor đoán đúng; đồng thời kiểm tra reconnect, quyền đọc
option/result/reward, economy mutation và hội tụ về Lobby.

## Milestone 9

Flutter tests kiểm tra 20-event storm, single-flight/follow-up, response đảo thứ
tự, revision monotonic, same-revision refresh, reconnect, subscription reuse và
dispose. Complete-game harness mặc định chạy 10 ván liên tiếp trong cùng room:

```sh
dart run tool/complete_game_harness.dart <local-api-url> <publishable-key>
SOAK_ROUNDS=25 dart run tool/complete_game_harness.dart <local-api-url> <publishable-key>
```

### Action retry classification

| Action | Policy |
|---|---|
| create room, start game | Retry cùng request ID; action mới dùng ID mới |
| ready, acknowledge, discussion ready, same clue/vote/final guess, Play Again | Same-input retry an toàn |
| join | Same-room retry an toàn |
| leave | Retry sau khi reconcile current room |
| settings | Retry cùng payload; không tự retry payload đã đổi |
| different clue/vote/final guess | Manual only; không blind retry |

Khi response mutation bị mất, recovery refetch snapshot thay vì kết luận thất
bại. Automatic recovery được coalesce/bounded; không có connectivity plugin hay
retry vô hạn.

## Milestone 10

`profile_history_test.sql` có 22 assertions cho caller-only profile/history,
validation, cross-stat constraints, ordering/cursor, reward ledger consistency và
direct-access denial. Flutter tests bao phủ model invariants, XP/win rate,
normalization, save/refetch sau network outcome không chắc chắn, pagination
dedupe/error retention và layout 360×640.

Complete-game soak còn kiểm tra mỗi vòng rằng profile totals tăng đúng reward và
history mới nhất khớp game/result. Chạy cùng lệnh Milestone 9; toàn bộ database
suite chạy bằng `npx --yes supabase@latest test db`.

## Milestone 11

`monetization_test.sql` kiểm tra grants/RLS, +50 cố định, duplicate, daily limit,
ledger/profile consistency, entitlement idempotency và out-of-order revoke.
Race harness thực sự chạy hai verified reward event khi quota đã dùng 2/3 và hai
purchase event đồng thời:

```sh
bash supabase/tests/concurrency/monetization_races.sh
```

Flutter dùng fake adapters, không gọi live ads/store. Controller tests kiểm tra
first-game/frequency, Remove Ads suppression, rewarded vẫn optional, duplicate
callback guard, purchase/restore refresh. Provider sandbox/production matrix ở
`docs/monetization-setup.md`.

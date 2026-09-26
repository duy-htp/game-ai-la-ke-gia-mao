# Database

Backend là nguồn sự thật. Flutter gửi action và chỉ quan sát state được phép.

## Profile lifecycle

Supabase Auth tạo anonymous account trước. Không tự động tạo profile. Sau khi
người chơi chọn username/avatar, Flutter gọi `complete_profile`; function lấy ID
từ `auth.uid()` và tạo profile. Retry là idempotent và không ghi đè profile đã
tồn tại. Xóa `auth.users` cascade xóa profile tương ứng.

## `public.profiles`

| Column | Type | Authority |
|---|---|---|
| `id` | UUID PK/FK `auth.users` | `auth.uid()` |
| `username` | TEXT | validated RPC input |
| `avatar_id` | TEXT | predefined catalog |
| `coins` | INTEGER, default 0 | server only |
| `xp` | INTEGER, default 0 | server only |
| `level` | INTEGER, default 1 | server only |
| `created_at` | TIMESTAMPTZ | database clock |
| `updated_at` | TIMESTAMPTZ | database trigger |

Constraints enforce trimmed username, 2–20 characters, no control characters,
12 allowed avatar IDs, nonnegative coins/XP and positive level.

## RLS and grants

- RLS is enabled and forced.
- `authenticated` may SELECT only the row whose ID equals `auth.uid()`.
- `anon` has no table access.
- `authenticated` has column SELECT grants but no INSERT/UPDATE/DELETE grant.
- There is deliberately no client INSERT or UPDATE policy.

## RPC security

`complete_profile(text, text)` is `SECURITY DEFINER` with `search_path = ''`.
Every relation is schema-qualified. It rejects missing `auth.uid()`, validates
both inputs, and writes economy values `0/0/1` itself. EXECUTE is revoked from
`public` and `anon`, and granted explicitly to `authenticated`.

The `set_updated_at` trigger uses database time and a safe empty search path.
Direct execution is revoked from client roles.

## Private rooms

`rooms` lưu UUID, code 6 ký tự, nullable current host, immutable creator,
`game_type`, status, capacity, create request UUID và server timestamps.
`room_players` lưu lịch sử từng lần tham gia bằng identity PK, room/player,
stable seat, `joined_at` và nullable `left_at`.

Lifecycle hiện tại:

```text
waiting → closed
```

Room cuối cùng được đóng thay vì xóa. Active membership là `left_at is null`.
Rời rồi rejoin tạo một history row mới; các partial unique indexes chỉ áp dụng
cho active rows.

### Codes and indexes

Code được tạo trong PostgreSQL từ `extensions.gen_random_bytes` và alphabet
`23456789ABCDEFGHJKMNPQRSTUVWXYZ`, retry tối đa 32 lần. Partial unique index
`rooms_active_code_unique` áp dụng khi status là `waiting`, nên code của room
closed có thể được tái sử dụng.

Các index khác đảm bảo:

- một active membership trên mỗi player trong toàn hệ thống;
- một active membership cho mỗi player/room;
- một active seat cho mỗi room;
- code/status lookup;
- active member ordering phục vụ host transfer.

### RPC locking and idempotency

- `create_room`: advisory transaction lock theo `auth.uid()`, client request
  UUID unique theo immutable `created_by`; retry trả cùng room.
- `join_room`: advisory player lock, sau đó khóa room row `FOR UPDATE` trước khi
  count/seat assignment. Retry cùng room trả snapshot; room khác bị từ chối.
- `leave_room`: advisory player lock và room row lock; retry khi không còn room
  trả thành công an toàn.

Host rời phòng được thay bằng active member sớm nhất theo `joined_at`, `seat`,
`player_id`. Khi không còn member, room đóng và `host_id` thành null.

### Privacy and privileges

RLS được ENABLE/FORCE trên cả hai bảng. `anon` và `authenticated` không có direct
table grants; không có client policies. Chỉ các SECURITY DEFINER RPC với empty
search path được execute bởi `authenticated`.

Snapshot chỉ trả room ID/code/type/status/capacity/host và member fields:
player ID, username, avatar ID, seat, host flag, joined timestamp. Coins, XP,
level, email, auth metadata, creator và idempotency key không được trả.

Không có public code-lookup endpoint; lookup room diễn ra bên trong `join_room`
cho authenticated profile. Rate limiting/code-enumeration mitigation nâng cao
được hoãn sang hardening milestone.

Lobby realtime và game schema vẫn nằm ngoài Milestone 3.

## Milestone 4 lobby extension

Rooms có thêm server-owned `revision`, `impostor_count`, nullable `category_id`
(null nghĩa random), `clue_seconds`, `discussion_seconds`; membership có
`is_ready`. Mười category metadata MVP được seed và chỉ category active được
authenticated đọc. Timer/impostor values được constraint và RPC kiểm tra.

`set_ready(boolean)` lấy player từ `auth.uid()` và chỉ cho non-host active member
trong waiting room. `update_room_settings(...)` chỉ dành cho host; thay đổi thật
sự mới tăng revision và reset ready của non-host. Snapshot tự tính `can_start`
từ active host, tối thiểu ba người, settings hợp lệ và toàn bộ non-host ready.

Rooms/memberships vẫn không cấp SELECT. Trigger gọi `realtime.send` với payload
tối giản. Policy trên `realtime.messages` dùng SECURITY DEFINER predicate để
chỉ active room member được nghe private channel tương ứng.

## Secure game engine

`games` lưu active phase, server timestamps, selected category/keyword, revision
và start idempotency key. Partial unique index bảo đảm mỗi room tối đa một active
game; `(room_id, round_number)` bảo đảm lịch sử vòng. `game_players` là snapshot
cố định với private role và unique turn order. `words` chứa 100 concept VI/EN,
10 mỗi category; không bảng nào cấp direct client access.

`start_game(request_id)` khóa room rồi kiểm tra lại host, trạng thái, actual
member count, ready và impostor settings. Category/word, role và turn order đều
dùng `extensions.gen_random_bytes` ở server. Toàn bộ insert và room transition
`waiting → in_game` chung một transaction. Retry cùng request ID trả cùng game.
`get_current_game()` trả explicit safe JSON; `get_my_game_secret()` không có input
identity và lấy duy nhất `auth.uid()`.

## Clue round

`games` snapshot impostor/clue/discussion settings khi start.
`game_players.role_acknowledged_at` chỉ được public hóa thành boolean.
`game_turns` lưu một player bất biến cho mỗi lượt và trạng thái
`active/submitted/timed_out`; partial unique index bảo đảm tối đa một active turn.
`clues` liên kết duy nhất với turn và không cấp INSERT trực tiếp.

Keyword matching dùng NFC, `unaccent`, lowercase, gom punctuation/whitespace
thành một khoảng trắng, rồi so khớp phrase theo ranh giới token cho cả VI và EN.
Mọi semantic rejection chỉ trả `invalid_clue`; tối đa năm keyword-match failures
mỗi turn hạn chế oracle probing nhưng không tuyên bố loại bỏ hoàn toàn side-channel.

## Voting storage

`discussion_ready_at` là idempotent per-player readiness. `voting_rounds` giới hạn
round number 1–2 và có partial unique active-round index.
`voting_round_candidates` persist candidate eligibility; `votes` có unique
`(round,voter)` và cấm self-vote. Không bảng voting nào cấp direct client grants.

Voting deadline cố định 30 giây; missing rows là abstention. Round 1 tie tạo
`vote_result` 5 giây rồi round 2 chỉ với tied leaders. Tie vòng 2 chọn một tied
candidate bằng `gen_random_bytes`; chỉ aggregate counts và cờ random-resolution
được public, individual ballots không bao giờ được trả.

## Final Guess, result and rewards

`final_guess_options` persist đúng bốn concept: keyword thật và ba concept active
khác, ưu tiên cùng category rồi fallback category khác. Thứ tự được random bằng
crypto bytes; raw `word_id` không có grant. Projection trả UUID lựa chọn opaque
và text VI/EN chỉ cho impostor bị loại. `final_guesses` unique theo game/player;
retry cùng lựa chọn idempotent, lựa chọn khác bị từ chối.

Sau Vote Result 5 giây, normal bị loại cho impostor thắng ngay; impostor bị loại
có 20 giây Final Guess. Đúng thì impostor thắng, sai/timeout thì normal thắng.
Luật này kết thúc ván kể cả cấu hình có hai impostor; chỉ impostor bị loại được
đoán.

`games.winner_team`, `result_reason`, `finished_at` persist kết quả. Private
resolution khóa game row, ghi result, insert `game_rewards` unique
`(game_id, player_id)`, cập nhật profile và stats trong cùng transaction. Reward:
mọi người +10 coin, đội thắng thêm +10; normal +100 khi bắt được impostor, +30
nếu ballot vòng quyết định nhắm bất kỳ impostor nào, +50 khi đội normal thắng;
mỗi impostor +150 khi normal bị loại; chỉ impostor đoán đúng nhận +120. Level là
`floor(total_xp / 500) + 1`. Stats gồm games played/won, normal/impostor wins và
correct votes; client không có quyền sửa economy, ledger hay result.

`play_again()` chỉ host gọi được. Nó khóa room/game, chuyển `in_game → waiting`,
reset ready của non-host và tăng revision nhưng giữ members, settings cùng toàn
bộ history. Retry khi đã waiting trả cùng lobby; lần start kế tiếp dùng round
number lớn nhất + 1.

## Profile RPC và private game history

`get_my_profile()` và `update_my_profile(text,text)` không nhận player ID; identity
luôn là `auth.uid()`. Update chỉ cho username/avatar, normalize whitespace, giới
hạn 2–20 ký tự, chặn control character và kiểm tra avatar allowlist. Các CHECK
constraint giữ `wins <= played`, tổng role wins bằng wins và correct votes không
vượt games played.

`get_my_game_history(limit,before_finished_at,before_game_id)` chỉ join những
`game_players` của caller, chỉ game `result`, và lấy XP/coin từ `game_rewards`.
Kết quả tối giản, sắp xếp `(finished_at,id) DESC`; hai cursor bắt buộc cùng có
hoặc cùng null. Index theo player/game và partial Result history hỗ trợ truy vấn.
Authenticated chỉ có EXECUTE các RPC cần thiết, không có direct SELECT/UPDATE
profiles, game rewards hay stats.

# Game state machine

Gameplay state sẽ do backend sở hữu và điều khiển. Client không được tự chuyển
phase; router/presentation sẽ render theo state server-authoritative. State,
transition và timer cụ thể chưa thuộc phạm vi Milestone 1.
# Game state machine

```text
waiting lobby
  └─ start_game (atomic, host-only)
       └─ role_reveal
```

Deadline và transition đều dựa vào server timestamp; client timer chỉ hiển thị
và gọi RPC advance idempotent.

## Milestone 6

```text
role_reveal -- all acknowledged / deadline --> clue turn 1
clue turn N -- submit / deadline -----------> clue turn N+1
final clue turn -- submit / deadline -------> discussion
```

Mỗi transition khóa game row. Entering clue tạo atomically đúng một turn theo
M5 `turn_order`. Timeout ghi `timed_out` và không tạo clue giả. Discussion dùng
deadline đã snapshot nhưng là terminal state của Milestone 6; chưa có vote.

## Milestone 7

```text
discussion -- all ready / deadline --> voting round 1
voting -- all voted / deadline -----> vote_result
vote_result tie round 1 -- 5s due --> voting round 2
voting round 2 ---------------------> vote_result (unique or random tie-break)
```

Abstention không tạo ballot giả. Mỗi action khóa game/round row; không thể có
active rounds song song hoặc round thứ ba.

## Milestone 8

```text
vote_result -- 5s, normal eliminated ----> result (impostor win)
vote_result -- 5s, impostor eliminated --> final_guess
final_guess -- correct ------------------> result (impostor win)
final_guess -- wrong / 20s timeout ------> result (normal win)
result -- host play_again ---------------> waiting lobby
```

Một ván kết thúc sau đúng một elimination, kể cả có hai impostor. Winner, reason,
ledger, profile totals và stats được ghi atomically. Play Again không xóa ván;
ván kế tiếp tăng `round_number` đơn điệu.

## Recovery semantics

Không có phase offline. Client giữ snapshot an toàn gần nhất, hiện reconnecting
rồi refetch. Nếu `phase_ends_at <= server_now`, client chỉ yêu cầu
`advance_game_if_due`; server vẫn quyết định transition. Recovery giới hạn 16
lần để hội tụ deadline mà không loop vô hạn. Nếu mọi client đóng app, phase có
thể nằm ở deadline đã hết; participant đầu tiên quay lại sẽ hội tụ state.

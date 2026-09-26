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

Milestone 5 dừng tại `role_reveal`. Deadline 15 giây dùng server timestamp nhưng
không tự chuyển phase. Các trạng thái `clue`, `discussion`, `voting`,
`vote_result`, `final_guess`, `result` được dành chỗ trong constraint nhưng
chưa có transition/RPC/UI và **NOT IMPLEMENTED YET**. Milestone 6 sẽ bổ sung
transition authoritative từ `role_reveal` sang `clue`.

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

Unique result và round-2 result là terminal trong M7. Abstention không tạo ballot
giả. Mỗi action khóa game/round row; không thể có active rounds song song hoặc
round thứ ba. Final Guess và role reveal sau elimination chưa được triển khai.

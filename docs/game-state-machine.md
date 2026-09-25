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

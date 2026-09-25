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

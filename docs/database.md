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

Room/game schema remains outside Milestone 2.

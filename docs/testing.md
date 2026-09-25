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

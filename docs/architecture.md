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

## Ranh giới

- Widget không chứa luật game hay truy cập database.
- Backend sẽ là nguồn sự thật cho room và gameplay.
- Gameplay screen sau này phải được suy ra từ server game state.
- Secret không được đưa vào public state, Realtime event hoặc production log.
- `auth.uid()` là player identity duy nhất; username không phải định danh/login.
- Profile JSON được parse thành `PlayerProfile` trước khi đi vào UI.

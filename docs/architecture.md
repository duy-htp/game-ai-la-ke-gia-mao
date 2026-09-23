# Kiến trúc

## Nguyên tắc

Ứng dụng dùng kiến trúc feature-first và chỉ tạo lớp khi có trách nhiệm thực tế:

```text
UI → Controller/Notifier → Repository → Data source/service
```

Milestone 1 chưa có nghiệp vụ cần controller hoặc repository, vì vậy Home chỉ
là presentation. `lib/core` chứa các nền tảng dùng chung; `lib/features` chứa
mã theo tính năng.

## Composition root

```text
main() → bootstrap() → ProviderScope → App → MaterialApp.router
```

`bootstrap` đọc và xác thực cấu hình trước khi render. Riverpod là cơ chế DI và
state management duy nhất. `go_router` sở hữu điều hướng; hiện chỉ đăng ký Home.
Các tên/path tương lai được quy ước nhưng chưa có route hoặc màn hình giả.

## Ranh giới

- Widget không chứa luật game hay truy cập database.
- Backend sẽ là nguồn sự thật cho room và gameplay.
- Gameplay screen sau này phải được suy ra từ server game state.
- Secret không được đưa vào public state, Realtime event hoặc production log.

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

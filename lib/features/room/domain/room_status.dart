import '../../../core/errors/app_error.dart';

enum RoomStatus {
  waiting('waiting'),
  closed('closed');

  const RoomStatus(this.value);

  final String value;

  static RoomStatus parse(String value) {
    return RoomStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw const RoomOperationAppError(),
    );
  }
}

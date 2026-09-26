sealed class AppError implements Exception {
  const AppError(this.code);

  final String code;
}

final class NetworkAppError extends AppError {
  const NetworkAppError() : super('network_unavailable');
}

final class SessionExpiredAppError extends AppError {
  const SessionExpiredAppError() : super('session_expired');
}

final class UnexpectedAppError extends AppError {
  const UnexpectedAppError() : super('unexpected');
}

final class MissingConfigurationAppError extends AppError {
  const MissingConfigurationAppError() : super('configuration_missing');
}

final class InvalidConfigurationAppError extends AppError {
  const InvalidConfigurationAppError() : super('configuration_invalid');
}

final class AuthInitializationAppError extends AppError {
  const AuthInitializationAppError() : super('auth_initialization_failed');
}

final class AnonymousSignInAppError extends AppError {
  const AnonymousSignInAppError() : super('anonymous_sign_in_failed');
}

final class ProfileLoadAppError extends AppError {
  const ProfileLoadAppError() : super('profile_load_failed');
}

final class InvalidUsernameAppError extends AppError {
  const InvalidUsernameAppError(this.reason) : super('invalid_username');

  final UsernameErrorReason reason;
}

enum UsernameErrorReason { blank, tooShort, tooLong, controlCharacter }

final class InvalidAvatarAppError extends AppError {
  const InvalidAvatarAppError() : super('invalid_avatar');
}

final class ProfileCreationAppError extends AppError {
  const ProfileCreationAppError() : super('profile_creation_failed');
}

final class InvalidRoomCodeAppError extends AppError {
  const InvalidRoomCodeAppError() : super('invalid_room_code');
}

final class RoomNotFoundAppError extends AppError {
  const RoomNotFoundAppError() : super('room_not_found');
}

final class RoomClosedAppError extends AppError {
  const RoomClosedAppError() : super('room_closed');
}

final class RoomFullAppError extends AppError {
  const RoomFullAppError() : super('room_full');
}

final class AlreadyInAnotherRoomAppError extends AppError {
  const AlreadyInAnotherRoomAppError() : super('already_in_another_room');
}

final class UnsupportedGameTypeAppError extends AppError {
  const UnsupportedGameTypeAppError() : super('unsupported_game_type');
}

final class InvalidMaxPlayersAppError extends AppError {
  const InvalidMaxPlayersAppError() : super('invalid_max_players');
}

final class ProfileRequiredAppError extends AppError {
  const ProfileRequiredAppError() : super('profile_required');
}

final class NotRoomMemberAppError extends AppError {
  const NotRoomMemberAppError() : super('not_room_member');
}

final class RoomOperationAppError extends AppError {
  const RoomOperationAppError() : super('room_operation_failed');
}

final class GameOperationAppError extends AppError {
  const GameOperationAppError() : super('game_operation_failed');
}

final class SecretUnavailableAppError extends AppError {
  const SecretUnavailableAppError() : super('secret_unavailable');
}

final class InvalidClueAppError extends AppError {
  const InvalidClueAppError() : super('invalid_clue');
}

final class NotCurrentTurnAppError extends AppError {
  const NotCurrentTurnAppError() : super('not_current_turn');
}

final class TurnExpiredAppError extends AppError {
  const TurnExpiredAppError() : super('turn_expired');
}

final class ClueAlreadySubmittedAppError extends AppError {
  const ClueAlreadySubmittedAppError() : super('clue_already_submitted');
}

final class InvalidVoteTargetAppError extends AppError {
  const InvalidVoteTargetAppError() : super('invalid_vote_target');
}

final class SelfVoteAppError extends AppError {
  const SelfVoteAppError() : super('self_vote_not_allowed');
}

final class VoteAlreadySubmittedAppError extends AppError {
  const VoteAlreadySubmittedAppError() : super('vote_already_submitted');
}

final class VoteExpiredAppError extends AppError {
  const VoteExpiredAppError() : super('vote_expired');
}

final class NotGuessingPlayerAppError extends AppError {
  const NotGuessingPlayerAppError() : super('not_guessing_player');
}

final class InvalidGuessChoiceAppError extends AppError {
  const InvalidGuessChoiceAppError() : super('invalid_guess_choice');
}

final class FinalGuessSubmittedAppError extends AppError {
  const FinalGuessSubmittedAppError() : super('final_guess_already_submitted');
}

final class FinalGuessExpiredAppError extends AppError {
  const FinalGuessExpiredAppError() : super('final_guess_expired');
}

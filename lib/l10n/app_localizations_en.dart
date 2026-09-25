// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get gameTitle => 'WHO IS THE IMPOSTOR?';

  @override
  String get gameTagline => 'Read your friends. Keep your secret.';

  @override
  String get createRoom => 'CREATE ROOM';

  @override
  String get joinRoom => 'JOIN ROOM';

  @override
  String get profile => 'Profile';

  @override
  String get shop => 'Shop';

  @override
  String get settings => 'Settings';

  @override
  String get comingSoon => 'This feature is coming in a future milestone.';

  @override
  String get developmentEnvironment => 'DEVELOPMENT BUILD';

  @override
  String get stagingEnvironment => 'STAGING BUILD';

  @override
  String get identityMarkLabel => 'Mysterious mask symbol';

  @override
  String get authInitializing => 'Restoring your player…';

  @override
  String get retry => 'RETRY';

  @override
  String get chooseYourName => 'CHOOSE YOUR NAME';

  @override
  String get displayName => 'Display name';

  @override
  String get usernameHint => 'Example: Alex';

  @override
  String get chooseAvatar => 'CHOOSE YOUR CHARACTER';

  @override
  String get startPlaying => 'START PLAYING';

  @override
  String avatarOption(int number) {
    return 'Character $number';
  }

  @override
  String playerLevel(int level) {
    return 'Lv. $level';
  }

  @override
  String coinBalance(int coins) {
    return 'Balance: $coins coins';
  }

  @override
  String get errorNetworkUnavailable =>
      'No network connection. Please try again.';

  @override
  String get errorSessionExpired => 'Your session expired. Please start again.';

  @override
  String get errorUnexpected => 'Something went wrong. Please try again.';

  @override
  String get errorConfiguration => 'The server connection is not configured.';

  @override
  String get errorAuthInitialization =>
      'The player session could not be initialized.';

  @override
  String get errorAnonymousSignIn =>
      'A guest session could not be created. Please retry.';

  @override
  String get errorProfileLoad =>
      'Your profile could not be loaded. Please retry.';

  @override
  String get errorUsernameBlank => 'Enter a display name.';

  @override
  String get errorUsernameTooShort =>
      'The name must contain at least 2 characters.';

  @override
  String get errorUsernameTooLong => 'The name cannot exceed 20 characters.';

  @override
  String get errorUsernameInvalidCharacters =>
      'The name contains unsupported characters.';

  @override
  String get errorInvalidAvatar => 'Choose a valid character.';

  @override
  String get errorProfileCreation =>
      'Your profile could not be created. Please retry.';

  @override
  String get gameType => 'Game';

  @override
  String get maximumPlayers => 'Maximum players';

  @override
  String get create => 'CREATE ROOM';

  @override
  String get join => 'JOIN ROOM';

  @override
  String get cancel => 'CANCEL';

  @override
  String get enterRoomCode => 'ENTER ROOM CODE';

  @override
  String get roomCode => 'Room code';

  @override
  String get roomCodeHint => 'Enter the 6-character code shared by the host.';

  @override
  String get waitingRoom => 'WAITING ROOM';

  @override
  String get players => 'Players';

  @override
  String get host => 'Host';

  @override
  String get leaveRoom => 'LEAVE ROOM';

  @override
  String roomCodeValue(String code) {
    return 'Room code $code';
  }

  @override
  String capacity(int current, int maximum) {
    return '$current/$maximum';
  }

  @override
  String get errorInvalidRoomCode =>
      'The room code must contain exactly 6 valid characters.';

  @override
  String get errorRoomNotFound => 'Room not found.';

  @override
  String get errorRoomClosed => 'This room is closed.';

  @override
  String get errorRoomFull => 'The room is full.';

  @override
  String get errorAlreadyInRoom => 'You are already in another room.';

  @override
  String get errorUnsupportedGameType => 'This game is not supported.';

  @override
  String get errorInvalidMaxPlayers =>
      'Player capacity must be between 3 and 10.';

  @override
  String get errorProfileRequired =>
      'Complete your profile before joining a room.';

  @override
  String get errorNotRoomMember => 'You are no longer a member of this room.';

  @override
  String get errorRoomOperation =>
      'The room request could not be completed. Please retry.';

  @override
  String get online => 'ONLINE';

  @override
  String get reconnecting => 'RECONNECTING...';

  @override
  String get onlineLower => 'Online';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get ready => 'READY';

  @override
  String get notReady => 'NOT READY';

  @override
  String get cancelReady => 'NOT READY';

  @override
  String get lobbySettings => 'LOBBY SETTINGS';

  @override
  String get impostorCount => 'Impostors';

  @override
  String get category => 'Category';

  @override
  String get randomCategory => 'Random';

  @override
  String get clueTime => 'Clue time';

  @override
  String get discussionTime => 'Discussion time';

  @override
  String get saveSettings => 'SAVE SETTINGS';

  @override
  String get minimumPlayersRequired => 'At least 3 players required';

  @override
  String waitingReadyPlayers(int count) {
    return 'Waiting for $count ready player(s)';
  }

  @override
  String get invalidLobbySettings => 'Lobby settings are invalid';

  @override
  String get startGame => 'START';

  @override
  String get startAvailableMilestoneFive => 'START · MILESTONE 5';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryAnimals => 'Animals';

  @override
  String get categoryPlaces => 'Places';

  @override
  String get categoryObjects => 'Objects';

  @override
  String get categoryJobs => 'Jobs';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryVietnam => 'Vietnam';

  @override
  String get categoryFriends => 'Friends';

  @override
  String get categoryRelationships => 'Relationships';

  @override
  String get holdToReveal => 'PRESS AND HOLD TO REVEAL ROLE';

  @override
  String get youAreNormal => 'YOU ARE A NORMAL PLAYER';

  @override
  String get youAreImpostor => 'YOU ARE THE IMPOSTOR';

  @override
  String get secretKeyword => 'KEYWORD';

  @override
  String get impostorHint => 'Watch the clues and discover the keyword.';

  @override
  String get remembered => 'GOT IT';

  @override
  String get secretHidden => 'Your role is hidden';

  @override
  String get errorGameOperation => 'The game could not be started or loaded.';

  @override
  String get errorSecretUnavailable =>
      'Your secret role could not be loaded. Please retry.';

  @override
  String get clueRound => 'CLUE ROUND';

  @override
  String get yourClueTurn => 'IT\'S YOUR TURN';

  @override
  String waitingForClue(String username) {
    return 'Waiting for $username to give a clue...';
  }

  @override
  String get clueHint => 'Enter a clue (up to 80 characters)';

  @override
  String get submitClue => 'SUBMIT CLUE';

  @override
  String get submittedClues => 'Clues';

  @override
  String get noClueSubmitted => 'No clue given';

  @override
  String get discussion => 'DISCUSSION';

  @override
  String get votingWillFollow => 'Voting will follow in the next milestone.';

  @override
  String get errorInvalidClue => 'That clue is not valid. Choose another clue.';

  @override
  String get errorNotCurrentTurn => 'It is not your turn.';

  @override
  String get errorTurnExpired => 'Your clue time has expired.';

  @override
  String get errorClueAlreadySubmitted =>
      'A clue has already been submitted for this turn.';
}

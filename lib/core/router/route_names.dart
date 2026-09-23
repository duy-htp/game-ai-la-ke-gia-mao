abstract final class RouteNames {
  static const home = 'home';
  static const createRoom = 'create-room';
  static const joinRoom = 'join-room';
  static const room = 'room';
  static const game = 'game';
  static const profile = 'profile';
  static const shop = 'shop';
  static const settings = 'settings';
}

abstract final class RoutePaths {
  static const home = '/';
  static const createRoom = '/create-room';
  static const joinRoom = '/join-room';
  static const room = '/room/:roomCode';
  static const game = '/game/:gameId';
  static const profile = '/profile';
  static const shop = '/shop';
  static const settings = '/settings';
}

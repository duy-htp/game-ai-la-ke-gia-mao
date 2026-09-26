import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RewardedAdOutcome { completed, closedEarly, unavailable, failed }

abstract interface class AdsService {
  Future<void> initialize();
  Future<bool> showInterstitial();
  Future<RewardedAdOutcome> showRewarded();
  Future<void> dispose();
}

class UnavailableAdsService implements AdsService {
  const UnavailableAdsService();
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> showInterstitial() async => false;
  @override
  Future<RewardedAdOutcome> showRewarded() async =>
      RewardedAdOutcome.unavailable;
  @override
  Future<void> dispose() async {}
}

final adsServiceProvider = Provider<AdsService>(
  (ref) => const UnavailableAdsService(),
);

import 'dart:async';

import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_controller.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/monetization/application/monetization_controller.dart';
import 'package:ai_la_ke_gia_mao/features/monetization/domain/ads_service.dart';
import 'package:ai_la_ke_gia_mao/features/monetization/domain/monetization_repository.dart';
import 'package:ai_la_ke_gia_mao/features/monetization/domain/monetization_state.dart';
import 'package:ai_la_ke_gia_mao/features/monetization/domain/purchase_service.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  test(
    'first result suppressed and interstitial appears every third result',
    () async {
      final ads = FakeAds();
      final c = await _container(ads: ads);
      addTearDown(c.dispose);
      final controller = c.read(monetizationControllerProvider.notifier);
      await controller.onResultVisible();
      await controller.onResultVisible();
      expect(ads.interstitialCalls, 0);
      await controller.onResultVisible();
      expect(ads.interstitialCalls, 1);
    },
  );

  test(
    'Remove Ads suppresses interstitials but not optional rewarded ads',
    () async {
      final ads = FakeAds(rewardedOutcome: RewardedAdOutcome.closedEarly);
      final c = await _container(ads: ads, removeAds: true);
      addTearDown(c.dispose);
      final controller = c.read(monetizationControllerProvider.notifier);
      for (var i = 0; i < 3; i++) {
        await controller.onResultVisible();
      }
      expect(ads.interstitialCalls, 0);
      expect(await controller.watchRewarded(), RewardedAdOutcome.closedEarly);
      expect(ads.rewardedCalls, 1);
    },
  );

  test(
    'duplicate rewarded tap is guarded and completion refetches authority',
    () async {
      final ads = FakeAds(
        rewardedOutcome: RewardedAdOutcome.completed,
        holdReward: true,
      );
      final monetization = FakeMonetizationRepository(false);
      final c = await _container(ads: ads, repository: monetization);
      addTearDown(c.dispose);
      final controller = c.read(monetizationControllerProvider.notifier);
      final first = controller.watchRewarded();
      expect(await controller.watchRewarded(), RewardedAdOutcome.unavailable);
      ads.completeReward();
      expect(await first, RewardedAdOutcome.completed);
      expect(ads.rewardedCalls, 1);
      expect(monetization.fetchCalls, 2);
    },
  );

  test('purchase and restore outcomes trigger authoritative refresh only when submitted', () async {
    final purchase = FakePurchase();
    final repository = FakeMonetizationRepository(false);
    final c = await _container(purchase: purchase, repository: repository);
    addTearDown(c.dispose);
    final controller = c.read(monetizationControllerProvider.notifier);
    expect(await controller.purchaseRemoveAds(), PurchaseOutcome.submitted);
    expect(await controller.restorePurchases(), RestoreOutcome.submitted);
    expect(repository.fetchCalls, 3);
    expect(purchase.identifiedAs, sampleProfile.id);
  });
}

Future<ProviderContainer> _container({
  FakeAds? ads,
  FakePurchase? purchase,
  FakeMonetizationRepository? repository,
  bool removeAds = false,
}) async {
  final result = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: 'http://localhost',
          supabaseAnonKey: 'test',
        ),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile: sampleProfile),
      ),
      roomRepositoryProvider.overrideWithValue(FakeRoomRepository()),
      gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      adsServiceProvider.overrideWithValue(ads ?? FakeAds()),
      purchaseServiceProvider.overrideWithValue(purchase ?? FakePurchase()),
      monetizationRepositoryProvider.overrideWithValue(
        repository ?? FakeMonetizationRepository(removeAds),
      ),
    ],
  );
  await result.read(appSessionControllerProvider.notifier).initialize();
  await result.read(monetizationControllerProvider.notifier).initialize();
  return result;
}

class FakeMonetizationRepository implements MonetizationRepository {
  FakeMonetizationRepository(this.removeAds);
  final bool removeAds;
  int fetchCalls = 0;
  @override
  Future<MonetizationState> fetchMyState() async {
    fetchCalls++;
    return MonetizationState(
      removeAds: removeAds,
      rewardedUsedToday: 0,
      rewardedRemainingToday: 3,
      canWatchRewardedAd: true,
      dayResetsAt: DateTime.utc(2026, 9, 29),
    );
  }
}

class FakeAds implements AdsService {
  FakeAds({
    this.rewardedOutcome = RewardedAdOutcome.completed,
    this.holdReward = false,
  });
  final RewardedAdOutcome rewardedOutcome;
  final bool holdReward;
  int interstitialCalls = 0;
  int rewardedCalls = 0;
  final _rewardCompleter = Completer<void>();
  void completeReward() => _rewardCompleter.complete();
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> showInterstitial() async {
    interstitialCalls++;
    return true;
  }

  @override
  Future<RewardedAdOutcome> showRewarded() async {
    rewardedCalls++;
    if (holdReward) await _rewardCompleter.future;
    return rewardedOutcome;
  }

  @override
  Future<void> dispose() async {}
}

class FakePurchase implements PurchaseService {
  String? identifiedAs;
  @override
  Future<void> identify(String authenticatedUserId) async {
    identifiedAs = authenticatedUserId;
  }

  @override
  Future<StoreProduct?> loadRemoveAdsProduct() async => const StoreProduct(
    id: MonetizationProducts.removeAds,
    localizedPrice: r'$1.99',
  );
  @override
  Future<PurchaseOutcome> purchaseRemoveAds() async =>
      PurchaseOutcome.submitted;
  @override
  Future<RestoreOutcome> restorePurchases() async => RestoreOutcome.submitted;
}

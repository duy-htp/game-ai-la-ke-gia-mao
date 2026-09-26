import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../profile/application/profile_controller.dart';
import '../domain/ads_service.dart';
import '../domain/monetization_repository.dart';
import '../domain/monetization_state.dart';
import '../domain/purchase_service.dart';

class MonetizationViewState {
  const MonetizationViewState({
    this.authoritative,
    this.product,
    this.loading = false,
    this.message,
    this.error,
  });
  final MonetizationState? authoritative;
  final StoreProduct? product;
  final bool loading;
  final String? message;
  final AppError? error;
  bool get suppressInterstitial => authoritative?.removeAds ?? false;
}

class MonetizationController extends Notifier<MonetizationViewState> {
  int _completedGamesThisSession = 0;
  bool _rewardInFlight = false;

  @override
  MonetizationViewState build() => const MonetizationViewState();

  Future<void> initialize() async {
    final session = ref.read(appSessionControllerProvider);
    if (session is! AppSessionReady) return;
    try {
      await ref
          .read(adsServiceProvider)
          .initialize()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Monetization initialization is never allowed to block core startup.
    }
    try {
      await ref
          .read(purchaseServiceProvider)
          .identify(session.profile.id)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    await refresh();
    StoreProduct? product;
    try {
      product = await ref
          .read(purchaseServiceProvider)
          .loadRemoveAdsProduct()
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    state = MonetizationViewState(
      authoritative: state.authoritative,
      product: product,
      error: state.error,
    );
  }

  Future<void> refresh() async {
    final repository = ref.read(monetizationRepositoryProvider);
    if (repository == null) return;
    final previous = state;
    try {
      final value = await repository.fetchMyState();
      state = MonetizationViewState(
        authoritative: value,
        product: previous.product,
      );
    } on AppError catch (error) {
      // Keep the last confirmed true entitlement to conservatively suppress ads.
      state = MonetizationViewState(
        authoritative: previous.authoritative,
        product: previous.product,
        error: error,
      );
    }
  }

  Future<void> onResultVisible() async {
    _completedGamesThisSession++;
    if (_completedGamesThisSession == 1 ||
        _completedGamesThisSession % 3 != 0 ||
        state.suppressInterstitial) {
      return;
    }
    await ref.read(adsServiceProvider).showInterstitial();
  }

  Future<RewardedAdOutcome> watchRewarded() async {
    if (_rewardInFlight ||
        !(state.authoritative?.canWatchRewardedAd ?? false)) {
      return RewardedAdOutcome.unavailable;
    }
    _rewardInFlight = true;
    try {
      final outcome = await ref.read(adsServiceProvider).showRewarded();
      if (outcome == RewardedAdOutcome.completed) {
        // Provider SSV/webhook grants the reward. Poll authoritative state only;
        // the SDK callback never mutates coins.
        await Future.wait([
          refresh(),
          ref.read(profileControllerProvider.notifier).refresh(),
        ]);
      }
      return outcome;
    } finally {
      _rewardInFlight = false;
    }
  }

  Future<PurchaseOutcome> purchaseRemoveAds() async {
    final outcome = await ref.read(purchaseServiceProvider).purchaseRemoveAds();
    if (outcome == PurchaseOutcome.submitted) await refresh();
    return outcome;
  }

  Future<RestoreOutcome> restorePurchases() async {
    final outcome = await ref.read(purchaseServiceProvider).restorePurchases();
    if (outcome == RestoreOutcome.submitted) await refresh();
    return outcome;
  }
}

final monetizationControllerProvider =
    NotifierProvider<MonetizationController, MonetizationViewState>(
      MonetizationController.new,
    );

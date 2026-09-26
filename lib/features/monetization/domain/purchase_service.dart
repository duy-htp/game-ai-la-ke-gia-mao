import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'monetization_state.dart';

enum PurchaseOutcome { submitted, cancelled, unavailable, failed }

enum RestoreOutcome { submitted, nothingToRestore, unavailable, failed }

abstract interface class PurchaseService {
  Future<void> identify(String authenticatedUserId);
  Future<StoreProduct?> loadRemoveAdsProduct();
  Future<PurchaseOutcome> purchaseRemoveAds();
  Future<RestoreOutcome> restorePurchases();
}

class UnavailablePurchaseService implements PurchaseService {
  const UnavailablePurchaseService();
  @override
  Future<void> identify(String authenticatedUserId) async {}
  @override
  Future<StoreProduct?> loadRemoveAdsProduct() async => null;
  @override
  Future<PurchaseOutcome> purchaseRemoveAds() async =>
      PurchaseOutcome.unavailable;
  @override
  Future<RestoreOutcome> restorePurchases() async => RestoreOutcome.unavailable;
}

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => const UnavailablePurchaseService(),
);

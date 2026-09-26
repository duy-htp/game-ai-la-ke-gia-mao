class MonetizationState {
  const MonetizationState({
    required this.removeAds,
    required this.rewardedUsedToday,
    required this.rewardedRemainingToday,
    required this.canWatchRewardedAd,
    required this.dayResetsAt,
  });

  factory MonetizationState.fromJson(Map<String, Object?> json) =>
      MonetizationState(
        removeAds: json['remove_ads']! as bool,
        rewardedUsedToday: json['rewarded_used_today']! as int,
        rewardedRemainingToday: json['rewarded_remaining_today']! as int,
        canWatchRewardedAd: json['can_watch_rewarded_ad']! as bool,
        dayResetsAt: DateTime.parse(json['day_resets_at']! as String).toUtc(),
      );

  final bool removeAds;
  final int rewardedUsedToday;
  final int rewardedRemainingToday;
  final bool canWatchRewardedAd;
  final DateTime dayResetsAt;
}

class StoreProduct {
  const StoreProduct({required this.id, required this.localizedPrice});
  final String id;
  final String localizedPrice;
}

abstract final class MonetizationProducts {
  static const removeAds = 'ai_la_ke_gia_mao_remove_ads';
}

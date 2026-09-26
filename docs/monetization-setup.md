# Monetization external setup

M11 implements the authority boundary, UI, adapters and local test path. No live
provider configuration has been claimed or committed. Development defaults to
unavailable adapters, so it cannot display live ads or charge a store account.

## Product and identity

- Non-consumable product ID: `ai_la_ke_gia_mao_remove_ads`.
- RevenueCat entitlement ID: `remove_ads`.
- RevenueCat App User ID must be the authenticated Supabase `auth.uid()`, never
  username/avatar. Future account linking must alias/transfer this stable ID
  before deleting an anonymous identity.
- Remove Ads suppresses interstitial/display ads only. Optional rewarded ads
  remain available by explicit user choice.

## AdMob checklist (pending)

- Create separate Android and iOS AdMob apps.
- Create one interstitial and one rewarded unit per platform.
- Configure provider-approved test IDs/test devices for development/staging.
- Supply `ADMOB_ANDROID_APP_ID`, `ADMOB_IOS_APP_ID`, platform interstitial and
  rewarded IDs through environment configuration.
- Add native app IDs only after receiving real values; do not fabricate them.
- Configure rewarded server-side verification to a trusted endpoint that calls
  `process_verified_ad_reward` with a unique verified event ID.
- Validate load/show/dismiss/reload, background callbacks and non-personalized
  consent behavior on physical devices.

## Store and RevenueCat checklist (pending)

- Create the same non-consumable product in App Store Connect and Google Play.
- Create RevenueCat iOS/Android apps, import products, attach both to the
  `remove_ads` entitlement and configure sandbox accounts.
- Supply only provider-designated public mobile SDK keys through
  `REVENUECAT_PUBLIC_SDK_KEY`; never ship secret/store credentials.
- Deploy `revenuecat-webhook`, set `REVENUECAT_WEBHOOK_AUTH`, and configure the
  RevenueCat Authorization header. Supabase injects service-role credentials
  server-side; they must never enter Flutter.
- Test purchase, cancellation, restore, reinstall/restore, refund/revoke,
  duplicate and out-of-order webhook delivery.

## Privacy and readiness

Only stable game user ID, product/entitlement identifiers and minimal provider
event metadata cross the monetization boundary. Keywords, roles, clues, votes,
receipts and full webhook payloads are not logged. Raw receipts are not stored
in Flutter. Consent/ATT/store compliance and production SSV remain M12 device
and provider-console validation work, not completed compliance claims.

| Path | Development | Provider sandbox | Production |
|---|---|---|---|
| Ads | Fake/unavailable adapter | Test ad units | Pending IDs/consent review |
| Purchase | Deterministic fake/unavailable adapter | Store + RevenueCat sandbox | Pending console approval |
| Entitlement | Local verified-event RPC tests | Signed/authenticated webhook | Pending deployment |
| Reward | Local service-role verifier tests | Provider SSV | Pending endpoint setup |

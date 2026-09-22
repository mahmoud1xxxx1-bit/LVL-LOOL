import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../economy_manager.dart';

class RewardedAdsService {
  RewardedAdsService._();

  static const androidRewardedTestId = 'ca-app-pub-3940256099942544/5224354917';

  static Future<bool> grantLifeFromRewardedAd() async {
    final state = await EconomyManager.checkEconomy();
    final lives = state['lives'] as int? ?? 0;
    final maxLives = state['maxLives'] as int? ?? 10;

    if (lives >= maxLives) return false;

    // VIP is ad-free: the reward is granted immediately.
    if (state['isVip'] == true) {
      return EconomyManager.grantRewardedLife();
    }

    final completer = Completer<bool>();
    await RewardedAd.load(
      adUnitId: androidRewardedTestId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          var earned = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(onUserEarnedReward: (_, __) => earned = true);
        },
        onAdFailedToLoad: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );
    final watched = await completer.future;
    return watched ? EconomyManager.grantRewardedLife() : false;
  }
}

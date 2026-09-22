import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EconomyManager {
  // Owner/test account: this single authenticated Google account bypasses
  // progression locks so the full game can be QA-tested without changing
  // the normal player economy.
  static const String ownerTestEmail = 'love.dotk@hmail.com';

  static bool isOwnerTestAccount() {
    final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    return email == ownerTestEmail;
  }
  // LVL LOOL progression/economy: Season 1 is free. Each later
  // season becomes purchasable only after 70% of the previous season is
  // completed. These prices are the approved values and must not drift.
  static const List<int> seasonUnlockCosts = <int>[0, 1500, 9000, 22500, 42000, 75000];
  static const double nextSeasonCompletionRequired = 0.70;
  static const String _completedStagesKey = 'lvllo_completed_stages';
  static const String _unlockedSeasonsKey = 'lvllo_unlocked_seasons';

  static const int normalMaxLives = 10;
  static const int vipMaxLives = 30;
  static const int rewardedLifeDailyLimit = 10;
  static const String _rewardedDateKey = 'ld_rewarded_life_date';
  static const String _rewardedCountKey = 'ld_rewarded_life_count';

  static bool _isVipActive(SharedPreferences prefs) {
    final vip = prefs.getBool('ld_vip') ?? false;
    final expiry = prefs.getInt('ld_vip_expiry') ?? 0;
    if (!vip) return false;
    if (expiry > 0 && DateTime.now().millisecondsSinceEpoch >= expiry) return false;
    return true;
  }

  // Normal refill cadence: the first life takes 3 minutes, then each
  // following life takes one minute longer, until the normal 10-life cap.
  static int _refillMinutesForNextLife(int lives) =>
      (lives + 3).clamp(3, 12);

  static Future<void> _ensureVipDailyMail(SharedPreferences prefs) async {
    if (!_isVipActive(prefs)) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDailyDate = prefs.getString('ld_vip_last_daily_date') ?? '';
    if (lastDailyDate == today) return;

    final mails = prefs.getStringList('ld_mailbox') ?? [];
    mails.insert(0, jsonEncode({
      'id': 'vip_daily_$today',
      'type': 'vip_daily_economy',
      'title': 'VIP Daily Reward',
      'body': 'Daily VIP reward: 10,000 Gold + 50 Gems.',
      'gold': 10000,
      'gems': 50,
      'claimed': false,
    }));
    mails.insert(0, jsonEncode({
      'id': 'vip_lives_$today',
      'type': 'vip_lives',
      'title': 'VIP 30 Lives',
      'body': '30 Lives are ready when your current lives reach zero.',
      'lives': vipMaxLives,
      'claimed': false,
    }));

    if (mails.length > 100) {
      mails.removeRange(100, mails.length);
    }

    await prefs.setStringList('ld_mailbox', mails);
    await prefs.setString('ld_vip_last_daily_date', today);
  }

  static Future<void> activateWeeklyVip() async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyActive = _isVipActive(prefs);
    if (alreadyActive) return;

    final expiry = DateTime.now()
        .add(const Duration(days: 7))
        .millisecondsSinceEpoch;

    await prefs.setBool('ld_vip', true);
    await prefs.setInt('ld_vip_expiry', expiry);
    await prefs.setInt('ld_lives', vipMaxLives);
    await prefs.remove('ld_zero_timestamp');
    await prefs.remove('ld_refill_started_at');
    await prefs.remove('ld_refill_minutes');

    // The 500-Gem activation bonus is granted once when VIP is activated.
    await prefs.setInt(
      'ld_gems',
      (prefs.getInt('ld_gems') ?? 0) + 500,
    );

    // Daily VIP mailbox rewards begin with the next daily cycle; activation
    // itself is already compensated by the immediate 500-Gem bonus.
    await prefs.setString(
      'ld_vip_last_daily_date',
      DateTime.now().toIso8601String().substring(0, 10),
    );
  }

  static Future<void> deductLife() async {
    final prefs = await SharedPreferences.getInstance();
    final isOwner = isOwnerTestAccount();
    final isVip = isOwner || _isVipActive(prefs);
    final maxLives = isOwner ? 999 : (isVip ? vipMaxLives : normalMaxLives);
    var lives = isOwner ? maxLives : (prefs.getInt('ld_lives') ?? maxLives);

    // Keep the stored value consistent with the currently active cap.
    if (lives > maxLives) {
      lives = maxLives;
      await prefs.setInt('ld_lives', lives);
    }

    if (lives <= 0) return;

    lives--;
    await prefs.setInt('ld_lives', lives);

    if (lives == 0) {
      if (isVip) {
        await prefs.remove('ld_refill_started_at');
        await prefs.remove('ld_refill_minutes');
      } else {
        await prefs.setInt(
          'ld_refill_started_at',
          DateTime.now().millisecondsSinceEpoch,
        );
        await prefs.setInt('ld_refill_minutes', 3);
      }
    }
  }

  static Future<bool> buyLivesWithGems(int quantity) async {
    if (quantity <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final isVip = _isVipActive(prefs);
    final maxLives = isVip ? vipMaxLives : normalMaxLives;
    final lives = (prefs.getInt('ld_lives') ?? maxLives).clamp(0, maxLives);
    final gems = prefs.getInt('ld_gems') ?? 0;
    final actual = quantity.clamp(0, maxLives - lives);
    final cost = actual * 50;
    if (actual <= 0 || gems < cost) return false;
    await prefs.setInt('ld_gems', gems - cost);
    await prefs.setInt('ld_lives', lives + actual);
    return true;
  }

  static Future<bool> exchangeGoldForGems(int quantity) async {
    if (quantity <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final cost = quantity * 1000;
    final gold = prefs.getInt('ld_gold') ?? 0;
    if (gold < cost) return false;
    await prefs.setInt('ld_gold', gold - cost);
    await prefs.setInt('ld_gems', (prefs.getInt('ld_gems') ?? 0) + quantity * 10);
    return true;
  }

  static Future<bool> grantRewardedLife() async {
    final prefs = await SharedPreferences.getInstance();
    final isVip = _isVipActive(prefs);
    final maxLives = isVip ? vipMaxLives : normalMaxLives;
    final lives = (prefs.getInt('ld_lives') ?? maxLives).clamp(0, maxLives);
    if (lives >= maxLives) return false;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    var used = prefs.getInt(_rewardedCountKey) ?? 0;
    if (prefs.getString(_rewardedDateKey) != today) used = 0;
    if (!isVip && used >= rewardedLifeDailyLimit) return false;

    await prefs.setInt('ld_lives', lives + 1);
    await prefs.setString(_rewardedDateKey, today);
    await prefs.setInt(_rewardedCountKey, used + 1);
    if (lives == 0 && !isVip) {
      await prefs.setInt('ld_refill_started_at', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('ld_refill_minutes', 4);
    }
    return true;
  }

  static Future<Map<String, dynamic>> checkEconomy() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureVipDailyMail(prefs);

    final isVip = _isVipActive(prefs);
    final maxLives = isVip ? vipMaxLives : normalMaxLives;
    var lives = prefs.getInt('ld_lives') ?? maxLives;

    // A normal account cannot keep the VIP-only 30-life capacity after VIP
    // has expired. Preserve the normal cap for the active economy state.
    if (!isOwner && !isVip && lives > normalMaxLives) {
      lives = normalMaxLives;
      await prefs.setInt('ld_lives', lives);
    }

    int? targetTime;

    if (!isVip && lives < normalMaxLives) {
      int startedAt = prefs.getInt('ld_refill_started_at') ?? 0;
      int refillMinutes = prefs.getInt('ld_refill_minutes') ?? 0;

      if (startedAt == 0 || refillMinutes == 0) {
        startedAt = DateTime.now().millisecondsSinceEpoch;
        refillMinutes = _refillMinutesForNextLife(lives);
        await prefs.setInt('ld_refill_started_at', startedAt);
        await prefs.setInt('ld_refill_minutes', refillMinutes);
      }

      // Catch up every elapsed refill while the app was closed, rather than
      // granting only one life per check.
      var now = DateTime.now().millisecondsSinceEpoch;
      while (lives < normalMaxLives &&
          now - startedAt >= refillMinutes * 60000) {
        startedAt += refillMinutes * 60000;
        lives++;
        if (lives >= normalMaxLives) break;
        refillMinutes = _refillMinutesForNextLife(lives);
      }

      await prefs.setInt('ld_lives', lives);

      if (lives >= normalMaxLives) {
        await prefs.remove('ld_refill_started_at');
        await prefs.remove('ld_refill_minutes');
      } else {
        await prefs.setInt('ld_refill_started_at', startedAt);
        await prefs.setInt('ld_refill_minutes', refillMinutes);
        targetTime = startedAt + refillMinutes * 60000;
      }
    }

    final mails = prefs.getStringList('ld_mailbox') ?? [];
    final unreadCount = mails.where((raw) {
      try {
        return jsonDecode(raw)['claimed'] != true;
      } catch (_) {
        return true;
      }
    }).length;

    return {
      'lives': lives,
      'maxLives': maxLives,
      'targetTime': targetTime,
      'gold': prefs.getInt('ld_gold') ?? 0,
      'gems': prefs.getInt('ld_gems') ?? 0,
      'unreadMail': unreadCount,
      'isVip': isVip,
      'isOwnerTestAccount': isOwner,
    };
  }

  static Future<bool> claimVipLifeMailById(String mailId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isVipActive(prefs)) return false;

    final mails = prefs.getStringList('ld_mailbox') ?? [];
    final index = mails.indexWhere((raw) {
      try {
        return jsonDecode(raw)['id'] == mailId;
      } catch (_) {
        return false;
      }
    });
    if (index < 0) return false;

    final mail = jsonDecode(mails[index]) as Map<String, dynamic>;
    if (mail['type'] != 'vip_lives' || mail['claimed'] == true) return false;

    final lives = prefs.getInt('ld_lives') ?? vipMaxLives;
    if (lives > 0) return false;

    await prefs.setInt('ld_lives', vipMaxLives);
    await prefs.remove('ld_refill_started_at');
    await prefs.remove('ld_refill_minutes');

    mail['claimed'] = true;
    mails[index] = jsonEncode(mail);
    await prefs.setStringList('ld_mailbox', mails);
    return true;
  }

  // Kept for compatibility with existing callers while the mailbox UI is
  // migrated to ID-based claims.
  static Future<bool> claimVipLifeMail(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final mails = prefs.getStringList('ld_mailbox') ?? [];
    if (index < 0 || index >= mails.length) return false;

    try {
      final id = (jsonDecode(mails[index]) as Map<String, dynamic>)['id'];
      if (id is! String || id.isEmpty) return false;
      return claimVipLifeMailById(id);
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> processStageWin(int stageId) async {
    if (stageId < 1 || stageId > 175) {
      throw ArgumentError.value(stageId, 'stageId');
    }

    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(_completedStagesKey) ?? <String>[];
    final key = stageId.toString();
    final isFirstClear = !completed.contains(key);

    final positionInRewardCycle = (stageId - 1) % 3;
    final gems = positionInRewardCycle == 0
        ? 1
        : positionInRewardCycle == 1
            ? 3
            : 5;
    final replayGold = positionInRewardCycle == 0
        ? 100
        : positionInRewardCycle == 1
            ? 250
            : 500;

    if (isFirstClear) {
      completed.add(key);
      await prefs.setStringList(_completedStagesKey, completed);
      await prefs.setInt('ld_gems', (prefs.getInt('ld_gems') ?? 0) + gems);
    } else {
      await prefs.setInt('ld_gold', (prefs.getInt('ld_gold') ?? 0) + replayGold);
    }

    // Keep the first-clear/replay result explicit for the victory UI.
    return {
      'stageId': stageId,
      'isFirst': isFirstClear,
      'gems': isFirstClear ? gems : 0,
      'gold': isFirstClear ? 0 : replayGold,
    };
  }

  static Future<Map<String, dynamic>> processWin(int round) async {
    // Compatibility for existing callers. New gameplay should pass the
    // global stage ID through processStageWin.
    return processStageWin(round);
  }

  static Future<Set<int>> completedStageIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_completedStagesKey) ?? <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<int> seasonCompletedCount(int season) async {
    if (season < 1 || season > 6) return 0;
    final completed = await completedStageIds();
    final start = season == 6 ? 101 : ((season - 1) * 20) + 1;
    final count = season == 6 ? 75 : 20;
    return completed.where((id) => id >= start && id < start + count).length;
  }

  static Future<bool> isSeasonUnlocked(int season) async {
    if (season < 1 || season > 6) return false;
    if (isOwnerTestAccount()) return true;
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList(_unlockedSeasonsKey) ?? <String>['1'];
    if (!unlocked.contains('1')) {
      unlocked.add('1');
      await prefs.setStringList(_unlockedSeasonsKey, unlocked);
    }
    return unlocked.contains(season.toString());
  }

  static Future<Map<String, dynamic>> seasonUnlockState(int season) async {
    final unlocked = await isSeasonUnlocked(season);
    if (season <= 1) {
      return {'unlocked': true, 'eligible': true, 'cost': 0, 'previousCompletion': 1.0};
    }

    final previousCount = await seasonCompletedCount(season - 1);
    final previousTotal = season - 1 == 6 ? 75 : 20;
    final completion = previousTotal == 0 ? 0.0 : previousCount / previousTotal;
    return {
      'unlocked': unlocked,
      'eligible': completion >= nextSeasonCompletionRequired,
      'cost': seasonUnlockCosts[season - 1],
      'previousCompletion': completion,
    };
  }

  static Future<bool> unlockSeason(int season) async {
    if (season < 2 || season > 6) return season == 1;
    if (isOwnerTestAccount()) return true;
    if (await isSeasonUnlocked(season)) return true;

    final state = await seasonUnlockState(season);
    if (state['eligible'] != true) return false;

    final cost = state['cost'] as int;
    final prefs = await SharedPreferences.getInstance();
    final gems = prefs.getInt('ld_gems') ?? 0;
    if (gems < cost) return false;

    await prefs.setInt('ld_gems', gems - cost);
    final unlocked = prefs.getStringList(_unlockedSeasonsKey) ?? <String>['1'];
    if (!unlocked.contains(season.toString())) unlocked.add(season.toString());
    await prefs.setStringList(_unlockedSeasonsKey, unlocked);
    return true;
  }


}

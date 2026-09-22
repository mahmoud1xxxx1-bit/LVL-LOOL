import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lvllo/economy_manager.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('normal account starts with 10 lives', () async {
    final state = await EconomyManager.checkEconomy();
    expect(state['lives'], 10);
    expect(state['maxLives'], 10);
    expect(state['isVip'], false);
  });

  test('life deduction and gem purchase are consistent', () async {
    await EconomyManager.deductLife();
    var state = await EconomyManager.checkEconomy();
    expect(state['lives'], 9);

    SharedPreferences.setMockInitialValues({'ld_lives': 5, 'ld_gems': 500});
    expect(await EconomyManager.buyLivesWithGems(2), true);
    state = await EconomyManager.checkEconomy();
    expect(state['lives'], 7);
    expect(state['gems'], 400);
  });

  test('first completion pays gems and replay pays gold', () async {
    var reward = await EconomyManager.processWin(1);
    expect(reward['isFirst'], true);
    expect(reward['gems'], 1);
    expect(reward['gold'], 0);

    reward = await EconomyManager.processWin(1);
    expect(reward['isFirst'], false);
    expect(reward['gems'], 0);
    expect(reward['gold'], 100);
  });

  test('rewarded life respects max lives and daily cap', () async {
    SharedPreferences.setMockInitialValues({
      'ld_lives': 0,
      'ld_gems': 0,
    });
    for (var i = 0; i < EconomyManager.rewardedLifeDailyLimit; i++) {
      expect(await EconomyManager.grantRewardedLife(), true);
    }
    expect(await EconomyManager.grantRewardedLife(), false);
    final state = await EconomyManager.checkEconomy();
    expect(state['lives'], 10);
  });
  test('season progression starts at Season 1 and requires 70 percent plus gems', () async {
    expect(await EconomyManager.isSeasonUnlocked(1), true);
    expect(await EconomyManager.isSeasonUnlocked(2), false);

    for (var stage = 1; stage <= 14; stage++) {
      await EconomyManager.processStageWin(stage);
    }

    var state = await EconomyManager.seasonUnlockState(2);
    expect(state['eligible'], true);
    expect(state['cost'], 1500);

    SharedPreferences.setMockInitialValues({
      'lvllo_completed_stages': List<String>.generate(14, (i) => (i + 1).toString()),
      'ld_gems': 1500,
    });
    expect(await EconomyManager.unlockSeason(2), true);
    expect(await EconomyManager.isSeasonUnlocked(2), true);
    final economy = await EconomyManager.checkEconomy();
    expect(economy['gems'], 0);
  });

  test('approved season unlock prices remain fixed', () {
    expect(EconomyManager.seasonUnlockCosts, [0, 1500, 9000, 22500, 42000, 75000]);
  });

  test('global stage reward cycle preserves Season 6 stage 101 values', () async {
    var reward = await EconomyManager.processStageWin(101);
    expect(reward['isFirst'], true);
    expect(reward['gems'], 3);

    reward = await EconomyManager.processStageWin(101);
    expect(reward['gold'], 250);
  });

}

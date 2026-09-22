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
}

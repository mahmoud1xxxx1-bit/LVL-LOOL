
import 'package:flutter/material.dart';

final ValueNotifier<String> globalLanguageNotifier = ValueNotifier<String>('en');

class L10n {
  static String get(String key) {
    final bool isAr = globalLanguageNotifier.value == 'ar';
    final Map<String, Map<String, String>> dict = {
      'you_died': {'en': 'YOU DIED', 'ar': 'YOU DIED'},
      'level_cleared': {'en': 'LEVEL CLEARED', 'ar': 'LEVEL CLEARED'},
      'out_of_lives': {'en': 'OUT OF LIVES', 'ar': '\u0646\u0641\u0630\u062a \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0627\u062a'},
      'main_menu': {'en': 'MAIN MENU', 'ar': '\u0627\u0644\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629'},
      'next_level': {'en': 'Next Level', 'ar': '\u0627\u0644\u0645\u0631\u062d\u0644\u0629 \u0627\u0644\u062a\u0627\u0644\u064a\u0629'},
      'replay': {'en': 'Replay', 'ar': '\u0625\u0639\u0627\u062f\u0629'},
      'retry': {'en': 'RETRY', 'ar': '\u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629'},
      'get_lives': {'en': 'GET LIVES', 'ar': '\u0627\u062d\u0635\u0644 \u0639\u0644\u0649 \u0645\u062d\u0627\u0648\u0644\u0627\u062a'},
      'back_to_menu': {'en': 'Back to Menu', 'ar': '\u0627\u0644\u0639\u0648\u062f\u0629 \u0644\u0644\u0642\u0627\u0626\u0645\u0629'},
      'visit_store': {'en': 'VISIT STORE', 'ar': '\u0632\u064a\u0627\u0631\u0629 \u0627\u0644\u0645\u062a\u062c\u0631'},
      'cancel': {'en': 'CANCEL', 'ar': '\u0625\u0644\u063a\u0627\u0621'},
      'next_life': {'en': 'Next life refills in:', 'ar': '\u062a\u062a\u062c\u062f\u062f \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629 \u0627\u0644\u0642\u0627\u062f\u0645\u0629 \u0628\u0639\u062f:'},
      'under_construction': {'en': 'UNDER CONSTRUCTION', 'ar': '\u0642\u064a\u062f \u0627\u0644\u0625\u0646\u0634\u0627\u0621'},
      'back': {'en': 'BACK', 'ar': '\u0631\u062c\u0648\u0639'},
      'lives_remaining': {'en': 'LIVES REMAINING:', 'ar': '\u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0627\u062a \u0627\u0644\u0645\u062a\u0628\u0642\u064a\u0629:'},
      
      // Store and HUD
      'perk_1': {'en': 'Ad-Free Experience', 'ar': '\u062a\u062c\u0631\u0628\u0629 \u0628\u062f\u0648\u0646 \u0625\u0639\u0644\u0627\u0646\u0627\u062a'},
      'perk_2': {'en': '30 Max Lives Cap', 'ar': '\u062d\u062f \u0623\u0642\u0635\u0649 30 \u0645\u062d\u0627\u0648\u0644\u0629'},
      'perk_3': {'en': 'Daily Mail: 10,000 Gold & 50 Gems', 'ar': '\u0628\u0631\u064a\u062f \u064a\u0648\u0645\u064a: 10000 \u0630\u0647\u0628 \u0648 50 \u062c\u0648\u0647\u0631\u0629'},
      'perk_4': {'en': '+500 Gems Instantly', 'ar': '+500 \u062c\u0648\u0647\u0631\u0629 \u0641\u0648\u0631\u0627\u064b'},
      'exchange_gold': {'en': 'Exchange Gold', 'ar': '\u062a\u0628\u0627\u062f\u0644 \u0627\u0644\u0630\u0647\u0628'},
      'exchange_gold_desc': {'en': 'Trade 1000 Gold for 10 Gems.', 'ar': '\u0628\u0627\u062f\u0644 1000 \u0630\u0647\u0628 \u0645\u0642\u0627\u0628\u0644 10 \u062c\u0648\u0627\u0647\u0631.'},
      'vip_pass': {'en': 'VIP PASS', 'ar': 'VIP PASS'},
      'active': {'en': 'ACTIVE', 'ar': 'ACTIVE'},
      'subscribe_now': {'en': 'SUBSCRIBE NOW', 'ar': '\u0627\u0634\u062a\u0631\u0643 \u0627\u0644\u0622\u0646'},
      'you_are_vip': {'en': 'YOU ARE VIP', 'ar': '\u0623\u0646\u062a VIP'},
      '10_per_week': {'en': '\$10 / Week', 'ar': '\$10 / \u0623\u0633\u0628\u0648\u0639'},
      'store': {'en': 'STORE', 'ar': '\u0627\u0644\u0645\u062a\u062c\u0631'},
      'mailbox': {'en': 'MAILBOX', 'ar': '\u0635\u0646\u062f\u0648\u0642 \u0627\u0644\u0628\u0631\u064a\u062f'},
      'settings': {'en': 'SETTINGS', 'ar': '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a'},
      'sound_effects': {'en': 'Sound Effects', 'ar': '\u0627\u0644\u0645\u0624\u062b\u0631\u0627\u062a \u0627\u0644\u0635\u0648\u062a\u064a\u0629'},
      'music': {'en': 'Music', 'ar': '\u0627\u0644\u0645\u0648\u0633\u064a\u0642\u0649'},
      'close': {'en': 'CLOSE', 'ar': '\u0625\u063a\u0644\u0627\u0642'},
      'choose_nightmare': {'en': 'PREPARE TO RAGE', 'ar': 'PREPARE TO RAGE'},
      'enter_season': {'en': 'ENTER SEASON', 'ar': 'ENTER SEASON'},
      'season': {'en': 'SEASON', 'ar': 'SEASON'},
      'the_awakening': {'en': 'The Awakening', 'ar': 'The Awakening'},
      'levels': {'en': 'LEVELS', 'ar': 'LEVELS'},
      'buy_1_life': {'en': 'Buy 1 Life', 'ar': '\u0634\u0631\u0627\u0621 \u0645\u062d\u0627\u0648\u0644\u0629 \u0648\u0627\u062d\u062f\u0629'},
      'buy_qty_lives': {'en': 'Buy {qty} Lives', 'ar': 'شراء {qty} محاولات'},
      'exchange_qty_gold': {'en': 'Exchange {gold} Gold', 'ar': 'تبادل {gold} ذهب'},
      'exchange_qty_desc': {'en': 'Trade {gold} Gold for {gems} Gems.', 'ar': 'بادل {gold} ذهب مقابل {gems} جواهر.'},
      'buy_btn_text': {'en': 'BUY ({cost} 💎)', 'ar': 'شراء ({cost} 💎)'},
      'refill_life_title': {'en': 'REFILL LIFE', 'ar': 'شراء الأرواح؟'},
      'refill_life_msg': {'en': 'Buy {qty} Life for {cost} Gems', 'ar': 'شراء {qty} أرواح مقابل {cost} جوهرة؟'},
      'need_gems_msg': {'en': 'You need {cost} Gems!', 'ar': 'تحتاج {cost} جوهرة!'},
      'lives_full_title': {'en': 'LIVES FULL', 'ar': 'الأرواح ممتلئة'},
      'lives_full_msg': {'en': 'You already have max lives!', 'ar': 'لديك الحد الأقصى من الأرواح!'},
      'bought_lives_title': {'en': 'BOUGHT LIVES', 'ar': 'تم الشراء'},
      'bought_lives_msg': {'en': 'You successfully bought {qty} lives.', 'ar': 'تم شراء {qty} أرواح بنجاح.'},
      'exchange_gold_title': {'en': 'EXCHANGE GOLD?', 'ar': 'تبادل الذهب؟'},
      'exchange_gold_confirm': {'en': 'EXCHANGE', 'ar': 'تبادل'},
      'exchange_gold_msg': {'en': 'Trade {gold} Gold for {gems} Gems?', 'ar': 'بادل {gold} ذهب مقابل {gems} جوهرة؟'},
      'need_gold_msg': {'en': 'You need {gold} Gold!', 'ar': 'تحتاج {gold} ذهب!'},
      'exchange_success_title': {'en': 'EXCHANGE SUCCESSFUL', 'ar': 'تم التبادل بنجاح'},
      'exchange_success_msg': {'en': 'Traded {gold} Gold for {gems} Gems.', 'ar': 'تم تبادل {gold} ذهب بـ {gems} جوهرة.'},

      'buy_life_desc': {'en': 'Instantly get 1 Life to keep playing.', 'ar': '\u0627\u062d\u0635\u0644 \u0639\u0644\u0649 \u0645\u062d\u0627\u0648\u0644\u0629 \u0641\u0648\u0631\u0627\u064b \u0644\u0645\u0648\u0627\u0635\u0644\u0629 \u0627\u0644\u0644\u0639\u0628.'},
      'buy_1000_gems': {'en': 'Buy 1000 Gems', 'ar': '\u0634\u0631\u0627\u0621 1000 \u062c\u0648\u0647\u0631\u0629'},
      'buy_gems_desc': {'en': 'Use gems to buy lives or unlock seasons.', 'ar': '\u0627\u0633\u062a\u062e\u062f\u0645 \u0627\u0644\u062c\u0648\u0627\u0647\u0631 \u0644\u0634\u0631\u0627\u0621 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0627\u062a \u0623\u0648 \u0641\u062a\u062d \u0627\u0644\u0645\u0648\u0627\u0633\u0645.'},
      'play': {'en': 'PLAY', 'ar': '\u0627\u0644\u0639\u0628'},
      'no_messages': {'en': 'No messages yet!', 'ar': '\u0644\u0627 \u062a\u0648\u062c\u062f \u0631\u0633\u0627\u0626\u0644 \u062d\u062a\u0649 \u0627\u0644\u0622\u0646!'},
      
      // Level specific
      'lvl_easy': {'en': 'LVL \u00B7 EASY', 'ar': 'LVL \u00B7 EASY'},
      'lvl_medium': {'en': 'LVL+ \u00B7 MEDIUM', 'ar': 'LVL+ \u00B7 MEDIUM'},
      'lvl_hard': {'en': 'LVL++ \u00B7 HARD', 'ar': 'LVL++ \u00B7 HARD'},
      'desc_easy': {'en': 'First encounter with each mechanic', 'ar': '\u0627\u0644\u0645\u0648\u0627\u062c\u0647\u0629 \u0627\u0644\u0623\u0648\u0644\u0649 \u0645\u0639 \u0627\u0644\u0641\u062e\u0627\u062e'},
      'desc_medium': {'en': 'Getting trickier now...', 'ar': '\u0627\u0644\u0623\u0645\u0648\u0631 \u062a\u0632\u062f\u0627\u062f \u062e\u0628\u062b\u0627\u064b...'},
      'desc_hard': {'en': 'Pure evil. Good luck.', 'ar': '\u0634\u0631 \u062e\u0627\u0644\u0635. \u062d\u0638\u0627\u064b \u0645\u0648\u0641\u0642\u0627\u064b.'},
    };
    return dict[key]?[isAr ? 'ar' : 'en'] ?? key;
  }
}










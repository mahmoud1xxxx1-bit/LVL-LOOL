import 'package:flutter/material.dart';
import 'l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'global_game_ui.dart';
import 'economy_manager.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int _gold = 0;
  int _gems = 0;
  int _lives = 0;
  int _maxLives = 10;
  bool _isVip = false;
  int _lifeQty = 1;
  int _goldQty = 1;

  @override
  void initState() {
    super.initState();
    _loadEconomy();
  }

  Future<void> _loadEconomy() async {
    final state = await EconomyManager.checkEconomy();
    if (!mounted) return;
    setState(() {
      _gold = state['gold'] as int? ?? 0;
      _gems = state['gems'] as int? ?? 0;
      _lives = state['lives'] as int? ?? 10;
      _isVip = state['isVip'] == true;
      _maxLives = state['maxLives'] as int? ?? 10;
    });
  }

  // --- Purchase Logic ---
  Future<void> _buyVip() async {
    if (_isVip) {
      GamePopups.showSuccess(context, title: 'ALREADY VIP', message: 'You are already a VIP!');
      return;
    }
    
    GamePopups.showConfirm(
      context,
      title: 'BUY VIP PASS?',
      message: 'Unlock Ad-Free, 30 Lives Cap, and Daily Rewards?',
      color: Colors.amber,
      confirmText: 'SUBSCRIBE (\$10)',
      onConfirm: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        await EconomyManager.activateWeeklyVip(); 
        _loadEconomy();
        if (mounted) GamePopups.showSuccess(context, title: 'VIP ACTIVATED!', message: 'Enjoy your exclusive perks.');
      }
    );
  }

  Future<void> _buyGems() async {
    GamePopups.showConfirm(
      context,
      title: 'BUY GEMS?',
      message: 'Get 1,000 Gems for \$5.00?',
      color: Colors.cyanAccent,
      confirmText: 'BUY (\$5)',
      onConfirm: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('ld_gems', _gems + 1000);
        _loadEconomy();
        if (mounted) GamePopups.showSuccess(context, title: 'PURCHASE SUCCESSFUL', message: '1000 Gems added to your account!');
      }
    );
  }

  Future<void> _buyLife() async {
    if (_lives >= _maxLives) {
      GamePopups.showSuccess(context, title: L10n.get('lives_full_title'), message: L10n.get('lives_full_msg'));
      return;
    }
    
    int spaceLeft = _maxLives - _lives;
    int actualQty = _lifeQty > spaceLeft ? spaceLeft : _lifeQty;
    int cost = actualQty * 50;

    GamePopups.showConfirm(
      context,
      title: L10n.get('refill_life_title'),
      message: L10n.get('refill_life_msg').replaceAll('{qty}', actualQty.toString()).replaceAll('{cost}', cost.toString()),
      color: Colors.redAccent,
      confirmText: L10n.get('buy_btn_text').replaceAll('{cost}', cost.toString()),
      onConfirm: () async {
        if (_gems < cost) {
          if (mounted) GamePopups.showError(context, message: L10n.get('need_gems_msg').replaceAll('{cost}', cost.toString()));
          return;
        }
        final ok = await EconomyManager.buyLivesWithGems(actualQty);
        if (!ok) {
          if (mounted) GamePopups.showError(context, message: L10n.get('need_gems_msg').replaceAll('{cost}', cost.toString()));
          return;
        }
        _loadEconomy();
        if (mounted) GamePopups.showSuccess(context, title: L10n.get('bought_lives_title'), message: L10n.get('bought_lives_msg').replaceAll('{qty}', actualQty.toString()));
      }
    );
  }

  Future<void> _exchangeGold() async {
    int goldCost = _goldQty * 1000;
    int gemGain = _goldQty * 10;
    
    GamePopups.showConfirm(
      context,
      title: L10n.get('exchange_gold_title'),
      message: L10n.get('exchange_gold_msg').replaceAll('{gold}', goldCost.toString()).replaceAll('{gems}', gemGain.toString()),
      color: Colors.amber,
      confirmText: L10n.get('exchange_gold_confirm'),
      onConfirm: () async {
        if (_gold < goldCost) {
          if (mounted) GamePopups.showError(context, message: L10n.get('need_gold_msg').replaceAll('{gold}', goldCost.toString()));
          return;
        }
        final ok = await EconomyManager.exchangeGoldForGems(_goldQty);
        if (!ok) {
          if (mounted) GamePopups.showError(context, message: L10n.get('need_gold_msg').replaceAll('{gold}', goldCost.toString()));
          return;
        }
        _loadEconomy();
        if (mounted) GamePopups.showSuccess(context, title: L10n.get('exchange_success_title'), message: L10n.get('exchange_success_msg').replaceAll('{gold}', goldCost.toString()).replaceAll('{gems}', gemGain.toString()));
      }
    );
  }

  Widget _buildCurrencyBadge(IconData icon, Color iconColor, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F111A),
        elevation: 0,
        title: Text(L10n.get('store'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCurrencyBadge(Icons.favorite, Colors.redAccent, '$_lives/$_maxLives'),
                Row(
                  children: [
                    _buildCurrencyBadge(Icons.diamond_rounded, Colors.cyanAccent, '$_gems'),
                    const SizedBox(width: 8),
                    _buildCurrencyBadge(Icons.monetization_on, Colors.amber, '$_gold'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. VIP Subscription Bundle
            _buildVipCard(),
            const SizedBox(height: 24),
            
            // 2. Buy Lives
            _buildStoreItem(
              title: _lifeQty == 1 ? L10n.get('buy_1_life') : L10n.get('buy_qty_lives').replaceAll('{qty}', _lifeQty.toString()),
              description: L10n.get('buy_life_desc'),
              icon: Icons.favorite,
              iconColor: Colors.redAccent,
              priceText: '${50 * _lifeQty}',
              priceIcon: Icons.diamond_rounded,
              priceIconColor: Colors.cyanAccent,
              onTap: _buyLife,
              quantity: _lifeQty,
              onAdd: () {
                int spaceLeft = _maxLives - _lives;
                int limit = spaceLeft > 10 ? 10 : spaceLeft;
                if (limit < 1) limit = 1; // Always allow at least 1 so UI doesn't break, popup will handle LIVES FULL
                if (_lifeQty < limit) setState(() => _lifeQty++);
              },
              onRemove: () {
                if (_lifeQty > 1) setState(() => _lifeQty--);
              },
            ),
            const SizedBox(height: 16),

            // 3. Buy Gems
            _buildStoreItem(
              title: L10n.get('buy_1000_gems'),
              description: L10n.get('buy_gems_desc'),
              icon: Icons.diamond_rounded,
              iconColor: Colors.cyanAccent,
              priceText: '\$5.00',
              onTap: _buyGems,
              isRealMoney: true,
            ),
            const SizedBox(height: 16),

            // 4. Exchange Gold
            _buildStoreItem(
              title: _goldQty == 1 ? L10n.get('exchange_gold') : L10n.get('exchange_qty_gold').replaceAll('{gold}', (_goldQty * 1000).toString()),
              description: L10n.get('exchange_qty_desc').replaceAll('{gold}', (_goldQty * 1000).toString()).replaceAll('{gems}', (_goldQty * 10).toString()),
              icon: Icons.sync,
              iconColor: Colors.amber,
              priceText: '${1000 * _goldQty}',
              priceIcon: Icons.monetization_on,
              priceIconColor: Colors.amber,
              onTap: _exchangeGold,
              quantity: _goldQty,
              onAdd: () {
                if (_goldQty < 10) setState(() => _goldQty++);
              },
              onRemove: () {
                if (_goldQty > 1) setState(() => _goldQty--);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFB400FF).withValues(alpha: 0.3), const Color(0xFF4A00E0).withValues(alpha: 0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB400FF), width: 2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFB400FF).withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(L10n.get('vip_pass'), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
              if (_isVip)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                  child: Text(L10n.get('active'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              else
                const Text('\$10 / Week', style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildVipPerk(Icons.block, L10n.get('perk_1')),
          _buildVipPerk(Icons.favorite, L10n.get('perk_2')),
          _buildVipPerk(Icons.mail_outline_rounded, L10n.get('perk_3')),
          _buildVipPerk(Icons.diamond_rounded, L10n.get('perk_4')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isVip ? null : _buyVip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB400FF),
                disabledBackgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_isVip ? L10n.get('you_are_vip') : L10n.get('subscribe_now'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipPerk(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStoreItem({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String priceText,
    IconData? priceIcon,
    Color? priceIconColor,
    required VoidCallback onTap,
    bool isRealMoney = false,
    int? quantity,
    VoidCallback? onAdd,
    VoidCallback? onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161824),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 32),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(description, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (quantity != null) ...[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.white54,
                onPressed: onRemove,
              ),
              Container(
                alignment: Alignment.center,
                width: 24,
                child: Text(quantity.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.white54,
                onPressed: onAdd,
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRealMoney ? Colors.green : const Color(0xFF2C2F42),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (priceIcon != null) ...[
                    Icon(priceIcon, color: priceIconColor, size: 18),
                    const SizedBox(width: 4),
                  ],
                  Text(priceText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}












import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/cosmic_background.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/lvllo_brand.dart';
import '../../core/theme/game_bottom_nav.dart';
import '../../store_screen.dart';
import 'world_hub_screen.dart';
import 'season7_prototype_screen.dart';
import '../../economy_manager.dart';

class LvlloLobbyScreen extends StatefulWidget {
  const LvlloLobbyScreen({super.key});

  @override
  State<LvlloLobbyScreen> createState() => _LvlloLobbyScreenState();
}

class _LvlloLobbyScreenState extends State<LvlloLobbyScreen> {
  int _tab = 0;
  int _lives = 10;
  int _maxLives = 10;
  int _gems = 0;
  int _gold = 0;
  int _mail = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final state = await EconomyManager.checkEconomy();
    if (!mounted) return;
    setState(() {
      _lives = state['lives'] as int? ?? 10;
      _maxLives = state['maxLives'] as int? ?? 10;
      _gems = state['gems'] as int? ?? 0;
      _gold = state['gold'] as int? ?? 0;
      _mail = state['unreadMail'] as int? ?? 0;
    });
  }

  void _openWorlds() => setState(() => _tab = 1);

  void _selectTab(int index) {
    HapticFeedback.selectionClick();
    setState(() => _tab = index);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: CosmicBackground(
        child: IndexedStack(
          index: _tab,
          children: [
            _homePage(),
            const LvlloPlatformerHubScreen(inline: true),
            const StoreScreen(),
            _mailPage(),
            _settingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: GameBottomNav(
        currentIndex: _tab,
        onSelected: _selectTab,
        items: [
          const GameBottomNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'HOME'),
          const GameBottomNavItem(icon: Icons.public_outlined, activeIcon: Icons.public_rounded, label: 'WORLDS'),
          const GameBottomNavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'STORE'),
          GameBottomNavItem(icon: Icons.mail_outline_rounded, activeIcon: Icons.mail_rounded, label: _mail > 0 ? 'MAIL • ${_mail}' : 'MAILBOX'),
          const GameBottomNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'SETTINGS'),
        ],
      ),
    );
  }

  Widget _homePage() {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 10), sliver: SliverToBoxAdapter(child: _profileHeader())),
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 18), sliver: SliverToBoxAdapter(child: _hero())),
          SliverPadding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 130), sliver: SliverToBoxAdapter(child: _progressCard())),
        ],
      ),
    );
  }

  Widget _profileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: GameColors.cosmicGradient, boxShadow: GameShadows.primaryGlow),
              child: const Center(child: LvlloBrandMark(size: 52)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PLAYER', style: TextStyle(color: GameColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  SizedBox(height: 2),
                  Text('LVL LOOL', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ],
              ),
            ),
            _iconButton(Icons.mail_outline_rounded, _mail > 0, () => _selectTab(3)),
            const SizedBox(width: 7),
            _iconButton(Icons.settings_rounded, false, () => _selectTab(4)),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(child: _resourcePill(Icons.favorite_rounded, GameColors.danger, '${_lives}/${_maxLives}')),
            const SizedBox(width: 7),
            Expanded(child: _resourcePill(Icons.diamond_rounded, GameColors.accentBright, '${_gems}')),
            const SizedBox(width: 7),
            Expanded(child: _resourcePill(Icons.monetization_on_rounded, GameColors.rewardGold, '${_gold}')),
          ],
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, bool badge, VoidCallback onTap) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: GameColors.surfaceGlass,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onTap, borderRadius: BorderRadius.circular(15),
            child: SizedBox(width: 46, height: 46, child: Icon(icon, color: GameColors.textStrong)),
          ),
        ),
        if (badge) const Positioned(right: -1, top: -1, child: CircleAvatar(radius: 5, backgroundColor: GameColors.danger)),
      ],
    );
  }

  Widget _resourcePill(IconData icon, Color color, String value) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 16), const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _hero() {
    return CosmicPanel(
      glow: true,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('THE TROLL PLATFORMER', style: TextStyle(color: GameColors.accentBright, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 10),
        const Text('175 STAGES.\nZERO MERCY.', style: TextStyle(fontSize: 36, height: .96, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
        const SizedBox(height: 10),
        const Text('Learn the trap. Remember the pattern. Beat the stage.', style: TextStyle(color: GameColors.textSoft, fontSize: 13, height: 1.35)),
        const SizedBox(height: 16),
        Container(
          height: 138, width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF111E45), Color(0xFF28104C), Color(0xFF071323)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: GameColors.accent.withOpacity(.24)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                right: -25, top: -35,
                child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, gradient: GameColors.cosmicGradient, boxShadow: GameShadows.primaryGlow)),
              ),
              const Positioned(right: 26, top: 26, child: LvlloBrandMark(size: 82)),
              const Positioned(left: 18, bottom: 14, child: Text('PREPARE TO RAGE', style: TextStyle(color: GameColors.textSoft, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: _primaryButton(icon: Icons.play_arrow_rounded, label: 'PLAY', onTap: _openWorlds)),
      ]),
    );
  }

  Widget _progressCard() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('YOUR JOURNEY', style: TextStyle(color: GameColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      const SizedBox(height: 10),
      _journeyTile(icon: Icons.public_rounded, title: 'WORLDS', subtitle: 'Explore all 175 stages', value: '6 WORLDS', onTap: _openWorlds),
      const SizedBox(height: 9),
      _journeyTile(
        icon: Icons.auto_awesome_rounded,
        title: 'SEASON 7 PROTOTYPE',
        subtitle: 'Level 1 • The Fake Path',
        value: 'TEST',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Season7PrototypeScreen(),
          ),
        ),
      ),
      const SizedBox(height: 9),
      _journeyTile(icon: Icons.storefront_rounded, title: 'STORE', subtitle: 'Lives, gems and rewards', value: 'SHOP', onTap: () => _selectTab(2)),
      const SizedBox(height: 9),
      _journeyTile(icon: Icons.mail_rounded, title: 'MAILBOX', subtitle: _mail > 0 ? 'You have ${_mail} unread reward(s)' : 'No unread rewards', value: _mail > 0 ? 'NEW' : 'OPEN', onTap: () => _selectTab(3)),
    ]);
  }

  Widget _journeyTile({required IconData icon, required String title, required String subtitle, required String value, required VoidCallback onTap}) {
    return Material(
      color: GameColors.surfaceGlass,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), border: Border.all(color: GameColors.surfaceStrong)),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(gradient: GameColors.cosmicGradient, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: GameColors.backgroundDeep)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: GameColors.muted, fontSize: 10)),
            ])),
            Text(value, style: const TextStyle(color: GameColors.accentBright, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: GameColors.muted),
          ]),
        ),
      ),
    );
  }

  Widget _primaryButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: () { HapticFeedback.mediumImpact(); onTap(); },
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(gradient: GameColors.cosmicGradient, borderRadius: BorderRadius.circular(17), boxShadow: GameShadows.primaryGlow),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: GameColors.backgroundDeep), const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: GameColors.backgroundDeep, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: .6)),
          ]),
        ),
      ),
    );
  }

  Widget _mailPage() {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _pageHeader('MAILBOX', Icons.mail_rounded),
          SliverPadding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 130), sliver: SliverToBoxAdapter(child: _MailboxPanel(onChanged: _refresh))),
        ],
      ),
    );
  }

  Widget _settingsPage() => const _SettingsPage();

  SliverAppBar _pageHeader(String title, IconData icon) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: GameColors.background.withOpacity(.94),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(children: [Icon(icon, color: GameColors.accentBright, size: 21), const SizedBox(width: 9), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5))]),
    );
  }
}

class _MailboxPanel extends StatefulWidget {
  const _MailboxPanel({required this.onChanged});
  final VoidCallback onChanged;
  @override State<_MailboxPanel> createState() => _MailboxPanelState();
}

class _MailboxPanelState extends State<_MailboxPanel> {
  List<Map<String, dynamic>> _mails = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('ld_mailbox') ?? [];
    final mails = <Map<String, dynamic>>[];
    for (final value in raw) {
      try { mails.add(Map<String, dynamic>.from(jsonDecode(value) as Map)); } catch (_) {}
    }
    if (mounted) setState(() => _mails = mails);
  }

  Future<void> _claim(int index) async {
    if (_mails[index]['claimed'] == true) return;
    final mail = _mails[index];
    if (mail['type'] == 'vip_lives') {
      final id = mail['id']?.toString() ?? '';
      final ok = id.isNotEmpty
          ? await EconomyManager.claimVipLifeMailById(id)
          : await EconomyManager.claimVipLifeMail(index);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The 30 Lives reward can be claimed when your current lives reach zero.')),
        );
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final gems = (mail['gems'] as num?)?.toInt() ?? 0;
      final gold = (mail['gold'] as num?)?.toInt() ?? 0;
      await prefs.setInt('ld_gems', (prefs.getInt('ld_gems') ?? 0) + gems);
      await prefs.setInt('ld_gold', (prefs.getInt('ld_gold') ?? 0) + gold);
      final raw = prefs.getStringList('ld_mailbox') ?? [];
      if (index < raw.length) {
        final updated = Map<String, dynamic>.from(jsonDecode(raw[index]) as Map);
        updated['claimed'] = true;
        raw[index] = jsonEncode(updated);
        await prefs.setStringList('ld_mailbox', raw);
      }
    }
    HapticFeedback.mediumImpact();
    await _load();
    widget.onChanged();
  }

  @override Widget build(BuildContext context) {
    if (_mails.isEmpty) {
      return CosmicPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 70),
          child: Center(child: Column(children: const [
            Icon(Icons.mark_email_read_outlined, size: 52, color: GameColors.muted),
            SizedBox(height: 12),
            Text('NO NEW MAIL', style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 5),
            Text('Rewards and announcements will appear here.', textAlign: TextAlign.center, style: TextStyle(color: GameColors.muted, fontSize: 11)),
          ])),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _mails.length; i++) ...[
          _mailCard(i),
          if (i != _mails.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _mailCard(int index) {
    final mail = _mails[index];
    final claimed = mail['claimed'] == true;
    final gems = (mail['gems'] as num?)?.toInt() ?? 0;
    final gold = (mail['gold'] as num?)?.toInt() ?? 0;
    return CosmicPanel(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.card_giftcard_rounded, color: GameColors.rewardGold),
          const SizedBox(width: 9),
          Expanded(child: Text('${mail['title'] ?? 'REWARD'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))),
          if (claimed) const Icon(Icons.check_circle_rounded, color: GameColors.success, size: 20),
        ]),
        const SizedBox(height: 8),
        Text('${mail['body'] ?? mail['message'] ?? 'A reward is waiting for you.'}', style: const TextStyle(color: GameColors.textSoft, fontSize: 11, height: 1.35)),
        const SizedBox(height: 12),
        Wrap(spacing: 7, children: [
          if (mail['type'] == 'vip_lives') _rewardChip(Icons.favorite_rounded, '+${mail['lives'] ?? 30} LIVES', GameColors.danger),
          if (gems > 0) _rewardChip(Icons.diamond_rounded, '${gems} GEMS', GameColors.accentBright),
          if (gold > 0) _rewardChip(Icons.monetization_on_rounded, '${gold} GOLD', GameColors.rewardGold),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: claimed ? null : () => _claim(index), child: Text(claimed ? 'CLAIMED' : 'CLAIM REWARD'))),
      ]),
    );
  }

  Widget _rewardChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 14), const SizedBox(width: 5), Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900))]),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();
  @override State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool _haptics = true;
  bool _sound = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _haptics = prefs.getBool('ld_haptics') ?? true;
      _sound = prefs.getBool('ld_sound') ?? true;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (mounted) setState(() {
      if (key == 'ld_haptics') _haptics = value;
      if (key == 'ld_sound') _sound = value;
    });
    if (value && key == 'ld_haptics') HapticFeedback.selectionClick();
  }

  @override Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: GameColors.background.withOpacity(.94),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Row(children: [
              Icon(Icons.settings_rounded, color: GameColors.accentBright, size: 21),
              SizedBox(width: 9),
              Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ]),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 130),
            sliver: SliverToBoxAdapter(
              child: Column(children: [
                CosmicPanel(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    SwitchListTile.adaptive(
                      value: _haptics,
                      onChanged: (value) => _set('ld_haptics', value),
                      title: const Text('Haptic feedback', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Tactile feedback for buttons and gameplay.', style: TextStyle(color: GameColors.muted, fontSize: 10)),
                      secondary: const Icon(Icons.vibration_rounded, color: GameColors.accentBright),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: _sound,
                      onChanged: (value) => _set('ld_sound', value),
                      title: const Text('Sound effects', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Game audio preference.', style: TextStyle(color: GameColors.muted, fontSize: 10)),
                      secondary: const Icon(Icons.volume_up_rounded, color: GameColors.violet),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                CosmicPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('GAMEPLAY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    SizedBox(height: 8),
                    Text('All menus use portrait mode. Selecting a stage switches to fullscreen landscape gameplay and returns to portrait when you exit.', style: TextStyle(color: GameColors.muted, fontSize: 11, height: 1.4)),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
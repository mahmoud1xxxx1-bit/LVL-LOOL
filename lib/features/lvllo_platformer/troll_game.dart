import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../../economy_manager.dart';
import 'troll_engine.dart';
import '../multiplayer_engine/duel_service.dart';
import 'lvllo_season_visual_theme.dart';
import '../../../../core/navigation/game_orientation.dart';

class TrollGame extends StatefulWidget {
  const TrollGame({
    super.key,
    this.onWin,
    this.startRound,
    this.maxRounds = 2,
    this.levelsPerMechanic = 3,
    this.mechanicOffset = 0,
    this.stageSeedOverride,
    this.onFail,
    this.onNextStage,
    this.stageId = 1,
    this.duelMatchId,
    this.duelSeed,
    this.testStage = false,
    this.seasonPlusStage = false,
  });
  final void Function(int score)? onWin;
  final VoidCallback? onFail;
  final VoidCallback? onNextStage;
  final int? startRound;
  final int maxRounds;
  final int levelsPerMechanic;
  final int mechanicOffset;
  final int? stageSeedOverride;
  final int stageId;
  final String? duelMatchId;
  final int? duelSeed;
  final bool testStage;
  final bool seasonPlusStage;

  @override
  State<TrollGame> createState() => _TrollGameState();
}

class _TrollGameState extends State<TrollGame> with SingleTickerProviderStateMixin {
  late TrollEngine _engine;
  late Ticker _ticker;
  late FocusNode _focusNode;
  Duration _lastTime = Duration.zero;
  bool _paused = false;
  bool _deathVisible = false;
  bool _victoryVisible = false;
  bool _rewardProcessed = false;
  int _livesRemaining = 10;
  int _maxLives = 10;
  Map<String, dynamic>? _stageReward;

  double _lastReportedProgress = -1;
  int _lastReportedTime = 0;
  int _duelStartTime = 0;
  bool _duelTimeout = false;
  bool _ownerTestMode = false;
  int _gold = 0;
  int _gems = 0;
  String? _rewardToast;
  int _rewardFlightToken = 0;
  String _rewardFlightKind = 'gold';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _engine = TrollEngine(
      round: widget.startRound ?? widget.stageId,
      maxRounds: widget.maxRounds,
      levelsPerMechanic: widget.levelsPerMechanic,
      mechanicOffset: widget.mechanicOffset,
      stageSeedOverride: widget.duelSeed ?? widget.stageSeedOverride,
      testStageMode: widget.testStage,
      seasonPlusStageMode: widget.seasonPlusStage,
    );
    TrollEngine.godMode = false;
    _syncOwnerTestMode();
    GameOrientation.enterGame();
    _duelStartTime = DateTime.now().millisecondsSinceEpoch;
    _ticker = createTicker(_onTick)..start();
  }


  Future<void> _syncOwnerTestMode() async {
    final enabled = await EconomyManager.isOwnerTestModeEnabled();
    final economy = await EconomyManager.checkEconomy();
    if (!mounted) return;
    _ownerTestMode = enabled;
    TrollEngine.godMode = enabled;
    setState(() {
      _livesRemaining = economy['lives'] as int? ?? (enabled ? 999 : 10);
      _maxLives = economy['maxLives'] as int? ?? (enabled ? 999 : 10);
      _gold = economy['gold'] as int? ?? 0;
      _gems = economy['gems'] as int? ?? 0;
    });
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;

    _engine.update(dt);

    if (widget.seasonPlusStage && _engine.rewardEvents.isNotEmpty) {
      final events = List<StageRewardEvent>.from(_engine.rewardEvents);
      _engine.rewardEvents.clear();
      for (final event in events) {
        if (event.type == 'gold') {
          EconomyManager.addGold(event.amount);
          _gold += event.amount;
          _rewardToast = '+${event.amount} GOLD';
        } else if (event.type == 'gems') {
          EconomyManager.addGems(event.amount);
          _gems += event.amount;
          _rewardToast = '+${event.amount} GEMS';
        } else if (event.type == 'heart') {
          _engine.bonusHitPoints += 1;
          _rewardToast = '+1 HEART HIT';
        }
        _rewardFlightToken++;
      }
    }
    if (_ownerTestMode) TrollEngine.godMode = true;
    
    if (widget.duelMatchId != null && !_duelTimeout) {
      final nowTime = DateTime.now().millisecondsSinceEpoch;
      if (nowTime - _duelStartTime >= 180000) { // 3 mins
        _duelTimeout = true;
        _ticker.stop();
        DuelService.resolveTimeout(widget.duelMatchId!).then((_) {
            if (mounted) Navigator.of(context).pop();
        }).catchError((_) {
            if (mounted) Navigator.of(context).pop();
        });
        return;
      }

      if (nowTime - _lastReportedTime > 1000) {
        _lastReportedTime = nowTime;
        final progress = (_engine.player.rect.left / (_engine.maxMapWidth)).clamp(0.0, 1.0);
        if ((progress - _lastReportedProgress).abs() > 0.05) {
          _lastReportedProgress = progress;
          DuelService.updateProgress(widget.duelMatchId!, progress);
        }
      }
    }

    if (_engine.isDead && !_deathVisible && !_victoryVisible) {
      _handleDeath();
      return;
    }

    if (_engine.allComplete && _engine.completedAsWin && !_victoryVisible) {
      _handleVictory();
      return;
    }

    if (mounted) setState(() {});
  }

  Future<void> _handleDeath() async {
    _engine.movingLeft = false;
    _engine.movingRight = false;
    _engine.jumping = false;
    if (widget.duelMatchId != null) {
      // Unlimited lives in duel!
      setState(() { _deathVisible = true; });
      await Future.delayed(const Duration(milliseconds: 500));
      _engine.player.rect = RectD(15 * 30.0, 30.0, _engine.player.rect.w, _engine.player.rect.h);
      _engine.player.vy = 0;
      _engine.isDead = false;
      if (mounted) setState(() { _deathVisible = false; });
      return;
    }
    _ticker.stop();
    await EconomyManager.deductLife();
    final economy = await EconomyManager.checkEconomy();
    if (!mounted) return;
    setState(() {
      _livesRemaining = economy['lives'] as int? ?? 0;
      _maxLives = economy['maxLives'] as int? ?? 10;
      _deathVisible = true;
      _lastTime = Duration.zero;
    });
    HapticFeedback.heavyImpact();
  }

  Future<void> _retryAfterDeath() async {
    final economy = await EconomyManager.checkEconomy();
    final lives = economy['lives'] as int? ?? 0;
    if (lives <= 0) {
      setState(() {
        _livesRemaining = lives;
        _maxLives = economy['maxLives'] as int? ?? 10;
      });
      return;
    }
    _engine.retryCurrentRound();
    setState(() {
      _deathVisible = false;
      _lastTime = Duration.zero;
    });
    _ticker.start();
    _focusNode.requestFocus();
  }

  Future<void> _handleVictory() async {
    _ticker.stop();
    if (_rewardProcessed) return;
    _rewardProcessed = true;
    
    if (widget.testStage || widget.seasonPlusStage) {
      if (!mounted) return;
      setState(() { _victoryVisible = true; _stageReward = {'gold': 0, 'gems': 0}; });
      HapticFeedback.heavyImpact();
      return;
    }

    if (widget.duelMatchId != null) {
      if (!mounted) return;
      await DuelService.updateProgress(widget.duelMatchId!, 1.0);
      setState(() { _victoryVisible = true; _stageReward = {'gold': 0, 'gems': 0}; });
      HapticFeedback.heavyImpact();
      return;
    }

    final reward = await EconomyManager.processStageWin(widget.stageId);
    int soloGold = 0;
    try {
      soloGold = await DuelService.claimSoloWin(widget.stageId);
    } catch (_) {}
    reward['gold'] = soloGold;

    final economy = await EconomyManager.checkEconomy();
    if (!mounted) return;
    setState(() {
      _stageReward = reward;
      _livesRemaining = economy['lives'] as int? ?? _livesRemaining;
      _maxLives = economy['maxLives'] as int? ?? _maxLives;
      _victoryVisible = true;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    TrollEngine.godMode = false;
    _ticker.dispose();
    _focusNode.dispose();
    GameOrientation.leaveGame();
    super.dispose();
  }

  void _togglePause() {
    if (_engine.allComplete) return;
    setState(() {
      _paused = !_paused;
      _lastTime = Duration.zero;
    });
    if (_paused) {
      _ticker.stop();
      HapticFeedback.mediumImpact();
    } else {
      _ticker.start();
      HapticFeedback.lightImpact();
      _focusNode.requestFocus();
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _engine.movingLeft = true;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) _engine.movingRight = true;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) _engine.setCrouching(true);
      if (event.logicalKey == LogicalKeyboardKey.keyX ||
          event.logicalKey == LogicalKeyboardKey.keyC) {
        _engine.shootFireball();
      }
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _engine.jumping = true;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _engine.movingLeft = false;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) _engine.movingRight = false;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) _engine.setCrouching(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode..requestFocus(),
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF07080A),
        body: Stack(
          children: [
            // Main Game Area
            Column(
              children: [
                Expanded(
                  child: SizedBox.expand(
                    child: ClipRect(
                      child: CustomPaint(
                        painter: _TrollPainter(_engine, widget.stageId),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Mobile-first HUD
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Row(
                    children: [
                      _LifeHud(seasonPlus: widget.seasonPlusStage),
                      if (widget.seasonPlusStage) ...[
                        const SizedBox(width: 6),
                        _hitHud(),
                      ],
                      if (widget.seasonPlusStage) ...[
                        const SizedBox(width: 6),
                        _currencyHud(Icons.monetization_on_rounded, _gold, const Color(0xFFFFD54A)),
                        const SizedBox(width: 6),
                        _currencyHud(Icons.diamond_rounded, _gems, const Color(0xFF5CF5FF)),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: _hudPill(
                            icon: Icons.bolt_rounded,
                            color: const Color(0xFF5CF5FF),
                            text: widget.seasonPlusStage ? 'SEASON + • STAGE 01' : (widget.testStage ? 'TEST STAGE 01' : 'STAGE ${_engine.round > 100 ? _engine.round - 100 : _engine.round}'),
                          ),
                        ),
                      ),
                      _hudButton(
                        icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        onTap: _togglePause,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Season+ controls: jump remains the main right-side action;
            // fire/crouch are compact buttons so the player can use the new
            // combat mechanics without losing the existing movement layout.
            Positioned(
              right: 0,
              bottom: 0,
              width: MediaQuery.sizeOf(context).width * 0.5,
              height: MediaQuery.sizeOf(context).height * 0.46,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  if (_paused || _deathVisible || _victoryVisible) return;
                  HapticFeedback.lightImpact();
                  _engine.jumping = true;
                },
                onPointerUp: (_) => _engine.jumping = false,
                onPointerCancel: (_) => _engine.jumping = false,
                child: const SizedBox.expand(),
              ),
            ),

            if (widget.seasonPlusStage)
              Positioned(
                right: 18,
                bottom: 18,
                child: SafeArea(
                  top: false,
                  left: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: Icons.keyboard_double_arrow_down_rounded,
                        label: 'DOWN',
                        onDown: () => _engine.setCrouching(true),
                        onUp: () => _engine.setCrouching(false),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.local_fire_department_rounded,
                        label: 'FIRE',
                        onDown: () => _engine.shootFireball(),
                        onUp: () {},
                      ),
                    ],
                  ),
                ),
              ),

            Positioned(
              left: 18,
              bottom: 18,
              child: SafeArea(
                top: false,
                right: false,
                child: _buildDirectionalGear(),
              ),
            ),


            if (widget.seasonPlusStage && _rewardToast != null)
              Positioned(
                top: 82,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xDD071226),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x555CF5FF)),
                      ),
                      child: Text(
                        _rewardToast!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (widget.seasonPlusStage && _rewardFlightToken > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_rewardFlightToken),
                    duration: const Duration(milliseconds: 850),
                    tween: Tween(begin: 0, end: 1),
                    onEnd: () {
                      if (!mounted) return;
                      setState(() {
                        _rewardFlightToken = 0;
                        _rewardToast = null;
                      });
                    },
                    builder: (context, t, child) {
                      final align = Alignment.lerp(
                        Alignment.center,
                        const Alignment(0.92, -0.92),
                        t,
                      )!;
                      return Align(
                        alignment: align,
                        child: Transform.scale(
                          scale: 1.0 - t * .35,
                          child: child,
                        ),
                      );
                    },
                    child: _SeasonPlusCurrencyIcon(kind: _rewardFlightKind, size: 30),
                  ),
                ),
              ),

            if (_deathVisible)
              _buildDeathOverlay(),

            if (_victoryVisible)
              _buildVictoryOverlay(),

            if (_paused)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xCC02040A),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(28),
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1530),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0x335CF5FF)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x6619DCE8), blurRadius: 32),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pause_circle_filled_rounded, color: Color(0xFF5CF5FF), size: 58),
                          const SizedBox(height: 14),
                          const Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          const Text('Take a breath. Your stage is waiting.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.icon(
                                onPressed: _togglePause,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('RESUME'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.exit_to_app_rounded),
                                label: const Text('EXIT'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayCard({
    required Widget child,
    Color accent = const Color(0xFF5CF5FF),
  }) {
    final maxHeight = MediaQuery.sizeOf(context).height - 40;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xD9020610),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1429),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: accent.withOpacity(.34)),
              boxShadow: [BoxShadow(color: accent.withOpacity(.16), blurRadius: 34, spreadRadius: 2)],
            ),
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildDeathOverlay() {
    final canRetry = _livesRemaining > 0;
    return _buildOverlayCard(
      accent: const Color(0xFFFF5478),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.close_rounded, color: Color(0xFFFF5478), size: 58),
          const SizedBox(height: 12),
          const Text('YOU DIED', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text('The trap got you. Choose what to do next.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFF070E1D), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x33FF5478))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_rounded, color: Color(0xFFFF5478), size: 20),
                const SizedBox(width: 8),
                Text('$_livesRemaining / $_maxLives LIVES REMAINING', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canRetry)
                FilledButton.icon(
                  onPressed: _retryAfterDeath,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('RETRY STAGE'),
                ),
              OutlinedButton.icon(
                onPressed: widget.onFail,
                icon: const Icon(Icons.map_rounded),
                label: const Text('WORLD MAP'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _retryAfterVictory() async {
    _engine.retryCurrentRound();
    if (!mounted) return;
    setState(() {
      _victoryVisible = false;
      _rewardProcessed = false;
      _stageReward = null;
      _lastTime = Duration.zero;
    });
    _ticker.start();
    _focusNode.requestFocus();
  }

  Widget _buildVictoryOverlay() {
    final reward = _stageReward ?? const <String, dynamic>{};
    final isFirst = reward['isFirst'] == true;
    final gems = reward['gems'] as int? ?? 0;
    final gold = reward['gold'] as int? ?? 0;
    final isLastStage = widget.stageId >= 175;
    final displayStage = widget.seasonPlusStage ? 'SEASON + • STAGE 01' : (widget.testStage ? 'TEST STAGE 01' : 'STAGE ' + (widget.stageId > 100 ? widget.stageId - 100 : widget.stageId).toString());
    return _buildOverlayCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFF5CF5FF), size: 58),
          const SizedBox(height: 10),
          Text(widget.seasonPlusStage ? 'SEASON + STAGE COMPLETE' : (widget.testStage ? 'TEST STAGE COMPLETE' : 'STAGE COMPLETE'), style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 5),
          Text(displayStage, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 18),
          Text(
            (widget.seasonPlusStage || widget.testStage) ? 'HARD PROTOTYPE • NO ECONOMY REWARD' : (isFirst ? 'FIRST CLEAR REWARD' : 'REPLAY REWARD'),
            style: const TextStyle(color: Color(0xFF8EA7C7), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.6),
          ),
          const SizedBox(height: 10),
          if (widget.seasonPlusStage || widget.testStage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFF071225), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x335CF5FF))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.science_rounded, color: Color(0xFF5CF5FF), size: 30),
                  const SizedBox(width: 10),
                  Text(widget.seasonPlusStage ? 'SEASON + PROTOTYPE CLEARED' : 'PROTOTYPE CLEARED', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              decoration: BoxDecoration(color: const Color(0xFF071225), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x335CF5FF))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isFirst ? Icons.diamond_rounded : Icons.monetization_on_rounded, color: isFirst ? const Color(0xFF5CF5FF) : const Color(0xFFFFC857), size: 34),
                  const SizedBox(width: 12),
                  Text('+${isFirst ? gems : gold}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Text(isFirst ? 'GEMS' : 'GOLD', style: TextStyle(color: isFirst ? const Color(0xFF5CF5FF) : const Color(0xFFFFC857), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!widget.testStage && !widget.seasonPlusStage && !isLastStage)
                FilledButton.icon(onPressed: widget.onNextStage, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('NEXT STAGE')),
              FilledButton.icon(onPressed: _retryAfterVictory, icon: const Icon(Icons.replay_rounded), label: const Text('REPLAY STAGE')),
              OutlinedButton.icon(onPressed: widget.onFail, icon: const Icon(Icons.map_rounded), label: const Text('WORLD MAP')),
            ],
          ),
        ],
      ),
    );
  }
  Widget _hudPill({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xD90A1124),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _hudButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xD90A1124),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _hitHud() {
    final hits = _engine.currentHeartHits.clamp(0, 2);
    final bonus = _engine.bonusHitPoints;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xD90A1124),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x66FF5478)),
      ),
      child: Text(
        bonus > 0 ? '♥ $hits/2 +$bonus' : '♥ $hits/2',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
      ),
    );
  }

  Widget _currencyHud(IconData icon, int value, Color color) {
    final kind = color == const Color(0xFFFFD54A) ? 'gold' : 'gems';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xD90A1124),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeasonPlusCurrencyIcon(kind: kind, size: 17),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (_paused || _deathVisible || _victoryVisible) return;
        onDown();
        HapticFeedback.selectionClick();
      },
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xCC0A1124),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x445CF5FF)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 25),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionalGear() {
    return Container(
      width: 126,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xB80A1124),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x445CF5FF), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildGearDirection(
            icon: Icons.chevron_left_rounded,
            onDown: () {
              if (_paused || _deathVisible || _victoryVisible) return;
              HapticFeedback.selectionClick();
              _engine.movingLeft = true;
            },
            onUp: () => _engine.movingLeft = false,
          ),
          Container(
            width: 1,
            height: 30,
            color: const Color(0x22FFFFFF),
          ),
          _buildGearDirection(
            icon: Icons.chevron_right_rounded,
            onDown: () {
              if (_paused || _deathVisible || _victoryVisible) return;
              HapticFeedback.selectionClick();
              _engine.movingRight = true;
            },
            onUp: () => _engine.movingRight = false,
          ),
        ],
      ),
    );
  }

  Widget _buildGearDirection({
    required IconData icon,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: SizedBox(
        width: 52,
        height: 56,
        child: Center(
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

class _LifeHud extends StatefulWidget {
  const _LifeHud({this.seasonPlus = false});
  final bool seasonPlus;
  @override State<_LifeHud> createState() => _LifeHudState();
}
class _LifeHudState extends State<_LifeHud> {
  int _lives = 10;
  int _max = 10;
  @override void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    final s = await EconomyManager.checkEconomy();
    if (!mounted) return;
    setState(() { _lives = s['lives'] as int? ?? 10; _max = s['maxLives'] as int? ?? 10; });
    Future.delayed(const Duration(seconds: 1), _refresh);
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xD90A1124),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x66FF5478)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.seasonPlus
              ? const _SeasonPlusCurrencyIcon(kind: 'heart', size: 18)
              : const Icon(Icons.favorite_rounded, color: Color(0xFFFF5478), size: 17),
          const SizedBox(width: 6),
          Text('$_lives/$_max', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SeasonPlusCurrencyIcon extends StatelessWidget {
  const _SeasonPlusCurrencyIcon({required this.kind, required this.size});
  final String kind;
  final double size;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SeasonPlusCurrencyPainter(kind),
    );
  }
}

class _SeasonPlusCurrencyPainter extends CustomPainter {
  _SeasonPlusCurrencyPainter(this.kind);
  final String kind;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    if (kind == 'heart') {
      p.color = const Color(0xFFFF4F83);
      final path = Path()
        ..moveTo(cx, size.height * .86)
        ..cubicTo(size.width * .08, size.height * .53, size.width * .14, size.height * .15, size.width * .38, size.height * .18)
        ..cubicTo(size.width * .49, size.height * .19, cx, size.height * .29, cx, size.height * .29)
        ..cubicTo(cx, size.height * .29, size.width * .51, size.height * .19, size.width * .62, size.height * .18)
        ..cubicTo(size.width * .86, size.height * .15, size.width * .92, size.height * .53, cx, size.height * .86)
        ..close();
      canvas.drawPath(path, p);
      p.color = const Color(0xFFFFB5C9);
      canvas.drawCircle(Offset(size.width * .35, size.height * .32), size.width * .07, p);
    } else if (kind == 'gold') {
      p.color = const Color(0xFFFFC83D);
      canvas.drawCircle(Offset(cx, cy), size.width * .42, p);
      p.color = const Color(0xFFFFE27A);
      canvas.drawCircle(Offset(cx - size.width * .08, cy - size.height * .10), size.width * .10, p);
      final tp = TextPainter(
        text: const TextSpan(text: '\$', style: TextStyle(color: Color(0xFF7A4B00), fontSize: 9, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 + .5));
    } else {
      p.color = const Color(0xFF39E7FF);
      final path = Path()
        ..moveTo(cx, size.height * .04)
        ..lineTo(size.width * .86, cy)
        ..lineTo(cx, size.height * .96)
        ..lineTo(size.width * .14, cy)
        ..close();
      canvas.drawPath(path, p);
      p.color = const Color(0xFFB9F8FF).withOpacity(.8);
      final shine = Path()
        ..moveTo(cx, size.height * .16)
        ..lineTo(size.width * .43, cy)
        ..lineTo(cx, size.height * .47)
        ..close();
      canvas.drawPath(shine, p);
    }
  }
  @override
  bool shouldRepaint(covariant _SeasonPlusCurrencyPainter oldDelegate) => oldDelegate.kind != kind;
}
class _TrollPainter extends CustomPainter {
  _TrollPainter(this.engine, this.stageId);
  final TrollEngine engine;
  final int stageId;

  LvlloSeasonVisualTheme get theme => LvlloSeasonVisualTheme.forStage(stageId == 0 ? 101 : stageId);

  @override
  void paint(Canvas canvas, Size size) {
    double scaleX = size.width / engine.logicalWidth;
    double scaleY = size.height / engine.logicalHeight;
    
    
    canvas.save();
    canvas.scale(scaleX, scaleY);
    if (engine.isMirrorLevel) {
       canvas.translate(engine.logicalWidth, 0);
       canvas.scale(-1, 1);
    }


    if (engine.seasonPlusStageMode) {
      _drawSeasonPlusBackground(canvas);
    } else if (engine.testStageMode) {
      _drawTestBackground(canvas);
    } else {
      _drawBackground(canvas);
    }

    // Apply Camera for world elements
    canvas.save();
    canvas.translate(-engine.cameraX, 0);

    _drawGrid(canvas);

    var paint = Paint();
    
    for (var e in engine.entities) {
      if (!e.isVisible) continue;

      if (engine.testStageMode || engine.seasonPlusStageMode) {
        if (engine.seasonPlusStageMode && e.type == TrollEntityType.enemy) {
          _drawSeasonPlusEnemy(canvas, e);
        } else if (engine.seasonPlusStageMode && e.type == TrollEntityType.projectile) {
          _drawFireball(canvas, e);
        } else if (engine.seasonPlusStageMode && e.type == TrollEntityType.chest) {
          _drawRewardChest(canvas, e);
        } else if (e.id.startsWith('saw_')) {
          if (e.isVisible) _drawTestSaw(canvas, e.rect);
        } else if (e.id.startsWith('laser_')) {
          if (e.isVisible) _drawTestLaser(canvas, e.rect);
        } else if (e.id.startsWith('moving_platform_')) {
          _drawTestMovingPlatform(canvas, e.rect);
        } else if (e.id.startsWith('gate_')) {
          _drawTestGate(canvas, e.rect);
        } else if (e.id.startsWith('crusher_')) {
          _drawThwomp(canvas, e.rect);
        } else if (e.id == 'door') {
          _drawTestDoor(canvas, e.rect);
        } else if (e.type == TrollEntityType.block) {
          if (engine.seasonPlusStageMode) {
            _drawSeasonPlusArchitecture(canvas, e.rect, e.id);
          } else {
            _drawTestArchitecture(canvas, e.rect, e.id);
          }
        } else if (e.type == TrollEntityType.spike) {
          if (e.isVisible) _drawSpike(canvas, e.rect, const Color(0xFFFF3DAF), e.isInverted);
        }
        continue;
      }

      if (e.type == TrollEntityType.block) {
        final timedTrap = engine.traps.whereType<TimedPlatformTrap>().where(
          (t) => t.blockIds.contains(e.id)
        ).firstOrNull;

        if (timedTrap != null) {
          if (!timedTrap.isCurrentlyVisible) continue;
          final timeLeft = timedTrap.showDuration - timedTrap.elapsedVisible;
          if (timeLeft < 0.7) {
            final blink = (sin(timedTrap.elapsedVisible * 18) + 1) / 2;
            if (blink < 0.35) continue;
          }
        }
        final isThwomp = engine.traps.whereType<ThwompCeilingTrap>().any((t) => t.targetIds.contains(e.id)) ||
            engine.traps.whereType<MovingThwompTrap>().any((t) => t.targetIds.contains(e.id));
        final isSpring = engine.traps.whereType<TrollSpringTrap>().any((t) => t.springId == e.id);
        if (isThwomp) {
          _drawThwomp(canvas, e.rect);
        } else if (isSpring) {
          _drawSpring(canvas, e.rect);
        } else {
          _drawPlatform(canvas, e.rect, timedTrap != null, e.color.opacity);
        }
      } else if (e.type == TrollEntityType.spike) {
        _drawSpike(canvas, e.rect, theme.danger, e.isInverted);
      } else if (e.type == TrollEntityType.door) {
        _drawDoor(canvas, e.rect, theme.portal);
      }
    }

    // ── GravityFlipZone visual (drawn after entities, before player) ──────
    for (final trap in engine.traps.whereType<GravityFlipZoneTrap>()) {
      final zr = trap.zone;
      // Animated purple shimmer using time
      final shimmer = ((sin(engine.stageSeed * 0.173) + 1) * 0.075 + 0.15).clamp(0.0, 1.0);
      paint.color = theme.accent.withValues(alpha: 0.18 + shimmer * 0.12);
      canvas.drawRect(zr.toRect(), paint);
      // Border
      paint.color = theme.accentBright.withValues(alpha: 0.7);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawRect(zr.toRect(), paint);
      paint.style = PaintingStyle.fill;
      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: '⚡',
          style: TextStyle(fontSize: 18, color: theme.accentBright),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(zr.x + zr.w / 2 - 9, zr.y + zr.h / 2 - 9));
    }


    if (engine.isGhostLevel && engine.ghostHistory.isNotEmpty) {
      var ghostP = TrollEntity(
        id: "ghost", type: TrollEntityType.player,
        rect: RectD(engine.ghostHistory.first.dx, engine.ghostHistory.first.dy, engine.player.rect.w, engine.player.rect.h),
        color: const Color(0xFFFF3366)
      );
      _drawPlayer(canvas, ghostP, opacity: 0.5);
    }
    
    if (engine.isChasedLevel) {
      paint.color = const Color(0xFF220000);
      canvas.drawRect(Rect.fromLTWH(engine.chaseWallX - 1000, 0, 1000, 800), paint);
      
      paint.color = const Color(0xFFFF1111);
      for (double y = 0; y < 800; y += 40) {
        _drawRightSpike(canvas, RectD(engine.chaseWallX, y, 40, 40), paint.color); 
      }
    }

    if (!engine.isDead || engine.playerScale > 0) {
      _drawPlayer(canvas, engine.player);
    }
    
    for (var p in engine.particles) {
      paint.color = p.color.withOpacity(p.life / p.maxLife);
      canvas.drawCircle(Offset(p.x, p.y), 4 * (p.life / p.maxLife), paint);
    }
    
    if (engine.testStageMode) {
      _drawTestWater(canvas);
    }

    // Restore world camera
    canvas.restore();

    // --- SPOTLIGHT EFFECT ---
    if (engine.isSpotlightLevel) {
      final double screenPx = engine.player.rect.x + engine.player.rect.w / 2 - engine.cameraX;
      final double screenPy = engine.player.rect.y + engine.player.rect.h / 2;
      
      final Rect bgRect = Rect.fromLTWH(0, 0, engine.logicalWidth, engine.logicalHeight);
      
      canvas.saveLayer(bgRect, Paint());
      canvas.drawRect(bgRect, Paint()..color = const Color(0xE6030305)); // 90% opacity black

      final Paint holePaint = Paint()
        ..blendMode = BlendMode.clear
        ..shader = RadialGradient(
          colors: [Colors.transparent, const Color(0xE6030305)],
          stops: [0.15, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(screenPx, screenPy), radius: 250));
      
      canvas.drawCircle(Offset(screenPx, screenPy), 250, holePaint);
      canvas.restore();
    }

    // --- TIME FREEZE EFFECT ---
    if (engine.isTimeFreezeLevel) {
      bool playerIsMoving = engine.player.vx.abs() > 5 || engine.player.vy.abs() > 5 || engine.movingLeft || engine.movingRight || engine.jumping;
      final Rect bgRect = Rect.fromLTWH(0, 0, engine.logicalWidth, engine.logicalHeight);
      
      Paint freezePaint = Paint()
        ..blendMode = BlendMode.srcOver
        ..shader = RadialGradient(
          colors: [
            Colors.transparent, 
            playerIsMoving ? const Color(0x3300AAFF) : const Color(0x6600AAFF)
          ],
          stops: [0.5, 1.0],
        ).createShader(bgRect);
        
      canvas.drawRect(bgRect, freezePaint);
      
      if (!playerIsMoving && !engine.isDead && !engine.roundWon) {
        TextSpan span = const TextSpan(style: TextStyle(color: Color(0xFF00AAFF), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4), text: "TIME FROZEN");
        TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(engine.logicalWidth/2 - tp.width/2, 50));
      }
    }

    
    // --- LAVA EFFECT ---
    if (engine.isLavaLevel) {
      double lavaScreenY = engine.lavaY; // lava is static in world, wait, screen space?
      // No, world space! Need to apply camera.
      canvas.save();
      canvas.translate(-engine.cameraX, 0);
      Paint lavaPaint = Paint()..color = const Color(0xDDFF3300);
      canvas.drawRect(Rect.fromLTWH(engine.cameraX - 500, engine.lavaY, 2000, 800), lavaPaint);
      lavaPaint.color = const Color(0xFFFF8800);
      canvas.drawRect(Rect.fromLTWH(engine.cameraX - 500, engine.lavaY, 2000, 10), lavaPaint);
      canvas.restore();
    }
    
    // --- BLINK EFFECT ---
    if (engine.isBlinkLevel) {
       if (engine.blinkTimer % 3.5 > 2.5) { // 2.5s visible, 1.0s pitch black
         Paint blinkPaint = Paint()..color = Colors.black;
         canvas.drawRect(Rect.fromLTWH(0, 0, engine.logicalWidth, engine.logicalHeight), blinkPaint);
       }
    }

    // UI Layer (overlay, text, wipe)
    if (engine.isDead) {
      paint.color = Colors.black.withOpacity(1.0 - engine.deathTimer);
      canvas.drawRect(Rect.fromLTWH(0, 0, engine.logicalWidth, engine.logicalHeight), paint);
    }

    if (engine.roundWon) {
      double r = 800 * (1.0 - engine.transitionTimer);
      if (r < 0) r = 0;
      
      // Calculate screen position of player
      double screenX = engine.player.rect.x - engine.cameraX;
      double screenY = engine.player.rect.y;

      var path = Path()
        ..addRect(Rect.fromLTWH(0, 0, engine.logicalWidth, engine.logicalHeight))
        ..addOval(Rect.fromCircle(
            center: Offset(screenX + 20, screenY + 20), 
            radius: r))
        ..fillType = PathFillType.evenOdd;
      paint.color = const Color(0xFF07080A);
      canvas.drawPath(path, paint);
    }
    // Removed ROUND text to keep the player surprised
    canvas.restore();
  }

  void _drawSeasonPlusBackground(Canvas canvas) {
    final r = Rect.fromLTWH(0, 0, engine.logicalWidth, engine.logicalHeight);
    final p = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF050A25),
          Color(0xFF12062D),
          Color(0xFF02040E),
        ],
      ).createShader(r);
    canvas.drawRect(r, p);

    // Large ruined core in the distance.
    final coreX = 400 - engine.cameraX * .10;
    final glow = Paint()
      ..color = const Color(0xFF7B35FF).withOpacity(.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
    canvas.drawCircle(Offset(coreX, 225), 115, glow);

    final core = Paint()..color = const Color(0xFF17265A);
    final corePath = Path()
      ..moveTo(coreX - 95, 600)
      ..lineTo(coreX - 135, 290)
      ..lineTo(coreX - 55, 155)
      ..lineTo(coreX + 25, 215)
      ..lineTo(coreX + 110, 135)
      ..lineTo(coreX + 150, 320)
      ..lineTo(coreX + 95, 600)
      ..close();
    canvas.drawPath(corePath, core);

    // Repeating ruined towers create depth while the world scrolls.
    for (int i = 0; i < 9; i++) {
      final x = i * 210.0 - (engine.cameraX * .18) % 210;
      final h = 120.0 + (i % 4) * 38.0;
      final tower = Paint()..color = const Color(0xFF0D1740);
      canvas.drawRect(Rect.fromLTWH(x, 560 - h, 54, h), tower);
      canvas.drawRect(
        Rect.fromLTWH(x + 8, 560 - h + 16, 4, h - 28),
        Paint()..color = const Color(0xFF00CFFF).withOpacity(.22),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 38, 560 - h + 32, 3, h - 46),
        Paint()..color = const Color(0xFF9B4DFF).withOpacity(.25),
      );
    }

    // Floating crystals mark the route without becoming gameplay objects.
    for (int i = 0; i < 16; i++) {
      final x = i * 265.0 + 70 - engine.cameraX * .24;
      final y = 80.0 + (i % 5) * 62.0;
      final glowColor =
          i.isEven ? const Color(0xFF00D9FF) : const Color(0xFFA34DFF);
      canvas.drawCircle(
        Offset(x, y),
        15,
        Paint()
          ..color = glowColor.withOpacity(.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
      final crystal = Path()
        ..moveTo(x, y - 17)
        ..lineTo(x + 10, y)
        ..lineTo(x, y + 22)
        ..lineTo(x - 10, y)
        ..close();
      canvas.drawPath(crystal, Paint()..color = glowColor);
    }

    // Thin neon horizon gives the ruins a finished architectural silhouette.
    canvas.drawRect(
      Rect.fromLTWH(0, 556, engine.logicalWidth, 2),
      Paint()..color = const Color(0xFF00D9FF).withOpacity(.20),
    );
  }

  void _drawTestBackground(Canvas canvas) {
    final r = Rect.fromLTWH(0, 0, engine.logicalWidth, engine.logicalHeight);
    final p = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF07164A), Color(0xFF12052A), Color(0xFF03050F)],
      ).createShader(r);
    canvas.drawRect(r, p);

    // Deep cavern silhouettes.
    final back = Paint()..color = const Color(0xFF101B4A);
    final front = Paint()..color = const Color(0xFF080D28);
    for (int i = 0; i < 6; i++) {
      final x = i * 760.0 - engine.cameraX * .12;
      final path = Path()
        ..moveTo(x, 600)
        ..lineTo(x + 90, 260)
        ..lineTo(x + 260, 110)
        ..lineTo(x + 430, 260)
        ..lineTo(x + 610, 150)
        ..lineTo(x + 760, 320)
        ..lineTo(x + 760, 600)
        ..close();
      canvas.drawPath(path, back);
      final fp = Path()
        ..moveTo(x, 600)
        ..lineTo(x + 180, 380)
        ..lineTo(x + 350, 430)
        ..lineTo(x + 520, 300)
        ..lineTo(x + 760, 410)
        ..lineTo(x + 760, 600)
        ..close();
      canvas.drawPath(fp, front);
    }

    // Crystals and architectural light pillars.
    for (int i = 0; i < 18; i++) {
      final x = (i * 235.0 + 80) - engine.cameraX * .22;
      final y = 70.0 + (i % 5) * 65.0;
      final glow = Paint()
        ..color = (i.isEven ? const Color(0xFF00E7FF) : const Color(0xFFA53BFF)).withOpacity(.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(Offset(x, y), 20, glow);
      final crystal = Paint()..color = i.isEven ? const Color(0xFF00B9FF) : const Color(0xFF7E2BFF);
      final path = Path()
        ..moveTo(x, y - 18)
        ..lineTo(x + 10, y)
        ..lineTo(x, y + 24)
        ..lineTo(x - 9, y)
        ..close();
      canvas.drawPath(path, crystal);
    }
  }

  void _drawSeasonPlusArchitecture(Canvas canvas, RectD rect, String id) {
    final base = Paint()..color = const Color(0xFF0B1430);
    final edge = Paint()..color = const Color(0xFF2F5E96);
    final cyan = Paint()..color = const Color(0xFF00D9FF).withOpacity(.72);
    final violet = Paint()..color = const Color(0xFF9B4DFF).withOpacity(.72);

    if (id.startsWith('plus_pillar_')) {
      final glow = Paint()
        ..color = const Color(0xFF00BFFF).withOpacity(.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.toRect().inflate(4), const Radius.circular(8)),
        glow,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(5)),
        base,
      );
      canvas.drawRect(Rect.fromLTWH(rect.x, rect.y, 4, rect.h), edge);
      canvas.drawRect(Rect.fromLTWH(rect.right - 4, rect.y, 4, rect.h), violet);
      for (double y = rect.y + 22; y < rect.bottom - 8; y += 34) {
        canvas.drawRect(Rect.fromLTWH(rect.x + 9, y, rect.w - 18, 3), cyan);
      }
      return;
    }

    if (id.startsWith('plus_beam_')) {
      final glow = Paint()
        ..color = const Color(0xFF8A3DFF).withOpacity(.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.toRect().inflate(3), const Radius.circular(7)),
        glow,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(5)),
        base,
      );
      canvas.drawRect(Rect.fromLTWH(rect.x, rect.y, rect.w, 3), cyan);
      for (double x = rect.x + 24; x < rect.right - 12; x += 52) {
        canvas.drawCircle(Offset(x, rect.y + rect.h / 2), 4, violet);
      }
      return;
    }

    final glow = Paint()
      ..color = const Color(0xFF6D3DFF).withOpacity(.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(7)),
      glow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(7)),
      base,
    );
    canvas.drawRect(Rect.fromLTWH(rect.x, rect.y, rect.w, 4), edge);

    if (id.startsWith('plus_ledge_') || id.contains('recovery')) {
      for (double x = rect.x + 12; x < rect.right - 8; x += 34) {
        canvas.drawRect(Rect.fromLTWH(x, rect.y + 6, 3, min(9, rect.h - 6)), cyan);
      }
    }
  }

  void _drawTestArchitecture(Canvas canvas, RectD rect, String id) {
    final base = Paint()..color = const Color(0xFF10182F);
    final edge = Paint()..color = const Color(0xFF314A79);
    final glow = Paint()
      ..color = const Color(0xFF6D3DFF).withOpacity(.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(7)), glow);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(7)), base);
    canvas.drawRect(Rect.fromLTWH(rect.x, rect.y, rect.w, 5), edge);
    if (id.contains('ledge') || id.contains('arch')) {
      final p = Paint()..color = const Color(0xFF00D9FF).withOpacity(.55);
      for (double x = rect.x + 12; x < rect.right - 8; x += 34) {
        canvas.drawRect(Rect.fromLTWH(x, rect.y + 5, 3, min(10, rect.h - 5)), p);
      }
    }
  }

  void _drawTestMovingPlatform(Canvas canvas, RectD rect) {
    final p = Paint()..color = const Color(0xFF173B61);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(6)), p);
    p.color = const Color(0xFF00E7FF);
    canvas.drawRect(Rect.fromLTWH(rect.x, rect.y, rect.w, 4), p);
    p.color = const Color(0xFFA53BFF).withOpacity(.8);
    canvas.drawCircle(Offset(rect.x + rect.w / 2, rect.y + rect.h / 2), 5, p);
  }

  void _drawTestSaw(Canvas canvas, RectD rect) {
    final center = Offset(rect.x + rect.w / 2, rect.y + rect.h / 2);
    final p = Paint()..color = const Color(0xFFFF2EBE);
    canvas.drawCircle(center, rect.w * .38, p);
    p.color = const Color(0xFF080A18);
    canvas.drawCircle(center, rect.w * .16, p);
    p.color = const Color(0xFF00E7FF);
    for (int i = 0; i < 10; i++) {
      final a = i * pi / 5;
      final tip = Offset(center.dx + cos(a) * rect.w * .50, center.dy + sin(a) * rect.h * .50);
      final left = Offset(center.dx + cos(a - .15) * rect.w * .28, center.dy + sin(a - .15) * rect.h * .28);
      final right = Offset(center.dx + cos(a + .15) * rect.w * .28, center.dy + sin(a + .15) * rect.h * .28);
      final path = Path()..moveTo(left.dx, left.dy)..lineTo(tip.dx, tip.dy)..lineTo(right.dx, right.dy)..close();
      canvas.drawPath(path, p);
    }
  }

  void _drawTestLaser(Canvas canvas, RectD rect) {
    final p = Paint()
      ..color = const Color(0xFFFF3355)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 9);
    canvas.drawRect(rect.toRect(), p);
    p.maskFilter = null;
    p.color = const Color(0xFFFF6A8A);
    canvas.drawRect(rect.toRect(), p);
    p.color = Colors.white;
    if (rect.w < rect.h) {
      canvas.drawRect(Rect.fromLTWH(rect.x + rect.w / 2 - 1, rect.y, 2, rect.h), p);
    } else {
      canvas.drawRect(Rect.fromLTWH(rect.x, rect.y + rect.h / 2 - 1, rect.w, 2), p);
    }
  }

  void _drawTestGate(Canvas canvas, RectD rect) {
    final p = Paint()..color = const Color(0xFF8B3DFF);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(5)), p);
    p.color = const Color(0xFFFF3DAF);
    for (double y = rect.y + 10; y < rect.bottom; y += 28) {
      canvas.drawCircle(Offset(rect.x + rect.w / 2, y), 3, p);
    }
  }

  void _drawTestDoor(Canvas canvas, RectD rect) {
    final outer = rect.toRect().inflate(8);
    final p = Paint()..color = const Color(0xFFFFC94A);
    canvas.drawRRect(RRect.fromRectAndRadius(outer, const Radius.circular(12)), p);
    p.color = const Color(0xFF25124C);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(9)), p);
    p.color = const Color(0xFFFFE47A);
    canvas.drawCircle(Offset(rect.x + rect.w / 2, rect.y + 32), 8, p);
  }

  void _drawTestWater(Canvas canvas) {
    final y = engine.testWaterY;
    final p = Paint()..color = const Color(0xFF00B9FF).withOpacity(.34);
    canvas.drawRect(Rect.fromLTWH(engine.cameraX, y, engine.logicalWidth, 600 - y), p);
    p.color = const Color(0xFF5CF5FF).withOpacity(.75);
    canvas.drawRect(Rect.fromLTWH(engine.cameraX, y, engine.logicalWidth, 4), p);
    for (double x = engine.cameraX; x < engine.cameraX + engine.logicalWidth + 60; x += 70) {
      final wave = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + 18, y - 8, x + 35, y)
        ..quadraticBezierTo(x + 52, y + 8, x + 70, y);
      canvas.drawPath(wave, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF7CEBFF).withOpacity(.65));
    }
  }

  void _drawBackground(Canvas canvas) {
    final Rect bgRect = Rect.fromLTWH(0, 0, engine.logicalWidth, engine.logicalHeight);

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.backgroundTop, theme.backgroundBottom],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    final moonX = 400 - (engine.cameraX * 0.05);
    final moon = Paint()
      ..color = theme.accent.withOpacity(.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(Offset(moonX, 285), 92, moon);
    moon.maskFilter = null;
    moon.color = theme.accentBright.withOpacity(.18);
    canvas.drawCircle(Offset(moonX, 285), 62, moon);

    final backOffset = -(engine.cameraX * 0.16) % 800;
    final frontOffset = -(engine.cameraX * 0.34) % 800;
    final backPaint = Paint()..color = theme.mountainBack;
    final frontPaint = Paint()..color = theme.mountainFront;

    for (int i = 0; i < 2; i++) {
      final bx = backOffset + i * 800;
      final back = Path()
        ..moveTo(bx, 600)
        ..lineTo(bx, 330)
        ..lineTo(bx + 170, 205)
        ..lineTo(bx + 300, 320)
        ..lineTo(bx + 470, 155)
        ..lineTo(bx + 650, 345)
        ..lineTo(bx + 800, 260)
        ..lineTo(bx + 800, 600)
        ..close();
      canvas.drawPath(back, backPaint);

      final fx = frontOffset + i * 800;
      final front = Path()
        ..moveTo(fx, 600)
        ..lineTo(fx, 430)
        ..lineTo(fx + 210, 285)
        ..lineTo(fx + 360, 405)
        ..lineTo(fx + 520, 250)
        ..lineTo(fx + 800, 395)
        ..lineTo(fx + 800, 600)
        ..close();
      canvas.drawPath(front, frontPaint);
    }

    final shardPaint = Paint()..color = theme.accent.withOpacity(.16);
    for (int i = 0; i < 9; i++) {
      final x = ((i * 137.0) - engine.cameraX * .08) % engine.logicalWidth;
      final y = 90.0 + (i % 4) * 92.0;
      final path = Path()
        ..moveTo(x, y)
        ..lineTo(x + 7, y - 18)
        ..lineTo(x + 19, y + 2)
        ..lineTo(x + 5, y + 13)
        ..close();
      canvas.drawPath(path, shardPaint);
    }
  }

  void _drawGrid(Canvas canvas) {
    var paint = Paint()
      ..color = Colors.white.withOpacity(0.01)
      ..strokeWidth = 1;
    // Extend grid to maxMapWidth
    for(double i=0; i<=engine.maxMapWidth; i+=40) {
      canvas.drawLine(Offset(i, 0), Offset(i, 600), paint);
    }
    for(double i=0; i<=600; i+=40) {
      canvas.drawLine(Offset(0, i), Offset(engine.maxMapWidth, i), paint);
    }
  }

  // One LVL LOOL spike language shared by every season.
  void _drawSpike(Canvas canvas, RectD rect, Color color, bool inverted) {
    final count = (rect.w / 18.0).round().clamp(1, 6);
    final tw = rect.w / count;
    final spikeH = rect.h * .88;
    final paint = Paint();

    paint.color = theme.platform;
    canvas.drawRect(
      Rect.fromLTWH(rect.x, inverted ? rect.y + rect.h - 5 : rect.y, rect.w, 5),
      paint,
    );

    for (int i = 0; i < count; i++) {
      final lx = rect.x + i * tw;
      final rx = rect.x + (i + 1) * tw;
      final mx = (lx + rx) / 2;
      final path = Path();

      if (inverted) {
        path
          ..moveTo(lx, rect.y + 5)
          ..lineTo(mx, rect.y + spikeH)
          ..lineTo(rx, rect.y + 5)
          ..close();
      } else {
        path
          ..moveTo(lx, rect.y + rect.h - 5)
          ..lineTo(mx, rect.y + rect.h - spikeH)
          ..lineTo(rx, rect.y + rect.h - 5)
          ..close();
      }

      paint.color = color.withOpacity(.92);
      canvas.drawPath(path, paint);

      final edge = Path();
      if (inverted) {
        edge.moveTo(mx, rect.y + spikeH);
        edge.lineTo(lx + 3, rect.y + 6);
      } else {
        edge.moveTo(mx, rect.y + rect.h - spikeH);
        edge.lineTo(lx + 3, rect.y + rect.h - 6);
      }
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = theme.accentBright.withOpacity(.62);
      canvas.drawPath(edge, paint);
      paint.style = PaintingStyle.fill;
    }
  }

  void _drawBurstSpike(Canvas canvas, RectD rect, Color color) {
    final paint = Paint()..color = color;
    final cx = rect.x + rect.w / 2;
    final cy = rect.y + rect.h;
    
    // If it's deep underground (hidden), draw a glowing crack on the floor instead
    if (rect.y > 500) {
      paint.color = Colors.redAccent.withOpacity(0.6 + 0.4 * sin(DateTime.now().millisecondsSinceEpoch/150));
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final crack = Path()
        ..moveTo(cx - 10, cy - rect.h)
        ..lineTo(cx - 3, cy - rect.h + 2)
        ..lineTo(cx + 2, cy - rect.h - 1)
        ..lineTo(cx + 12, cy - rect.h + 1);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawPath(crack, paint);
      paint.style = PaintingStyle.fill;
      paint.maskFilter = null;
      return;
    }
    
    // Outer glow for erupting spike
    paint.maskFilter = const MaskFilter.blur(BlurStyle.outer, 15);
    paint.color = color.withOpacity(0.9);
    canvas.drawCircle(Offset(cx, cy - 10), 20, paint);
    paint.maskFilter = null;
    
    // Main enormous spike
    paint.color = color;
    final path = Path()
      ..moveTo(cx, rect.y - 15) // Extra sharp tip
      ..lineTo(cx + rect.w * 0.5, cy)
      ..lineTo(cx - rect.w * 0.5, cy)
      ..close();
    canvas.drawPath(path, paint);
    
    // Sharp edge highlight
    paint.color = Colors.white.withOpacity(0.5);
    final shine = Path()
      ..moveTo(cx, rect.y - 15)
      ..lineTo(cx + 4, cy - 10)
      ..lineTo(cx - 1, cy - 10)
      ..close();
    canvas.drawPath(shine, paint);
  }

  void _drawRightSpike(Canvas canvas, RectD rect, Color color) {
    var paint = Paint()..color = color;
    var path = Path();
    
    path.moveTo(rect.x, rect.y);
    path.lineTo(rect.x + rect.w, rect.y + rect.h / 2);
    path.lineTo(rect.x, rect.y + rect.h);
    path.close();
    
    paint.maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    canvas.drawPath(path, paint);
    paint.maskFilter = null;
    canvas.drawPath(path, paint);
  }

  void _drawPlatform(Canvas canvas, RectD rect, bool timed, double opacity) {
    final r = RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(5));
    final a = opacity.clamp(0.18, 1.0).toDouble();
    final paint = Paint()..color = theme.platform.withOpacity(a);
    canvas.drawRRect(r, paint);

    final top = Path()
      ..moveTo(rect.x + 5, rect.y)
      ..lineTo(rect.right - 5, rect.y)
      ..lineTo(rect.right - 11, rect.y + 5)
      ..lineTo(rect.x + 11, rect.y + 5)
      ..close();
    paint.color = (timed ? theme.accentBright : theme.platformTop).withOpacity(a);
    canvas.drawPath(top, paint);

    paint.color = theme.platformEdge.withOpacity(.95 * a);
    canvas.drawRect(Rect.fromLTWH(rect.x, rect.bottom - 4, rect.w, 4), paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = theme.accent.withOpacity(.30);
    canvas.drawRRect(r, paint);
    paint.style = PaintingStyle.fill;

    if (timed) {
      paint.color = theme.accentBright.withOpacity(.8);
      canvas.drawCircle(Offset(rect.right - 10, rect.y + 7), 2.2, paint);
    }
  }

  void _drawThwomp(Canvas canvas, RectD rect) {
    final outer = RRect.fromRectAndRadius(rect.toRect(), const Radius.circular(6));
    final paint = Paint()..color = theme.platform;
    canvas.drawRRect(outer, paint);

    paint.color = theme.accent.withOpacity(.9);
    canvas.drawRect(Rect.fromLTWH(rect.x + 4, rect.y + 4, rect.w - 8, 5), paint);

    // The same compact face is reused for ceiling and moving crushers.
    paint.color = const Color(0xFF05070D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.x + rect.w * .27, rect.y + rect.h * .27, rect.w * .46, rect.h * .42),
        const Radius.circular(4),
      ),
      paint,
    );

    paint.color = theme.accentBright;
    canvas.drawCircle(Offset(rect.x + rect.w * .39, rect.y + rect.h * .43), 2.8, paint);
    canvas.drawCircle(Offset(rect.x + rect.w * .61, rect.y + rect.h * .43), 2.8, paint);

    paint.color = theme.danger;
    for (int i = 0; i < 3; i++) {
      final x = rect.x + rect.w * (.25 + i * .25);
      final spike = Path()
        ..moveTo(x - 5, rect.bottom - 1)
        ..lineTo(x, rect.bottom + 8)
        ..lineTo(x + 5, rect.bottom - 1)
        ..close();
      canvas.drawPath(spike, paint);
    }
  }

  void _drawSpring(Canvas canvas, RectD rect) {
    final paint = Paint()..color = theme.platform;
    final base = Rect.fromLTWH(rect.x + 2, rect.bottom - 8, rect.w - 4, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, const Radius.circular(3)),
      paint,
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = theme.accentBright;
    final path = Path()
      ..moveTo(rect.x + 7, rect.bottom - 9)
      ..lineTo(rect.x + rect.w - 7, rect.bottom - 18)
      ..lineTo(rect.x + 7, rect.bottom - 27)
      ..lineTo(rect.x + rect.w - 7, rect.bottom - 36)
      ..lineTo(rect.x + rect.w / 2, rect.top + 2);
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.fill;
  }

  void _drawDoor(Canvas canvas, RectD rect, Color color) {
    final outer = rect.toRect().inflate(4);
    final inner = rect.toRect().deflate(4);
    final paint = Paint();

    paint.color = theme.platform;
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(8)),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = color.withOpacity(.95);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(5)),
      paint,
    );

    paint.style = PaintingStyle.fill;
    paint.color = color.withOpacity(.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner.deflate(3), const Radius.circular(3)),
      paint,
    );

    paint.color = theme.accentBright.withOpacity(.75);
    canvas.drawRect(
      Rect.fromLTWH(inner.left + 5, inner.top + 8, 3, inner.height - 16),
      paint,
    );
  }


  // ---------------------------------------------------------------------------
  // Season+ production character art
  //
  // This is intentionally hand-authored, layered character art rather than
  // generic rectangles.  Hitboxes stay in the engine; this layer is purely
  // visual, so art can be larger than the collision box without changing play.
  // ---------------------------------------------------------------------------

  Paint _spPaint(Color color, {double opacity = 1.0}) =>
      Paint()..color = color.withOpacity(opacity);

  void _spStroke(Canvas canvas, Path path, Color color, double width) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, p);
  }

  void _drawSeasonPlusEnemy(Canvas canvas, TrollEntity e) {
    final kind = e.enemyKind ?? 'sword';
    final dir = (engine.player.rect.centerX - e.rect.centerX).sign == 0
        ? 1.0
        : (engine.player.rect.centerX - e.rect.centerX).sign;
    final moving = e.vx.abs() > 3;
    final bob = moving ? sin(e.rect.left * 0.08) * 1.2 : sin(e.rect.left * 0.03) * .5;

    canvas.save();
    canvas.translate(e.rect.centerX, e.rect.bottom);
    canvas.scale(dir, 1);
    canvas.translate(0, bob);

    // Contact shadow.
    final shadow = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(const Rect.fromLTWH(-25, -4, 50, 9), shadow);

    if (kind == 'bat') {
      _drawSpBat(canvas);
    } else if (kind == 'spiked') {
      _drawSpSpikedWalker(canvas);
    } else {
      switch (kind) {
        case 'hammer':
          _drawSpHammerGuard(canvas, e);
          break;
        case 'wood':
          _drawSpWoodenClub(canvas, e);
          break;
        case 'knife':
          _drawSpKnifeThief(canvas, e);
          break;
        case 'fire':
          _drawSpFireShooter(canvas, e);
          break;
        case 'archer':
          _drawSpArcher(canvas, e);
          break;
        default:
          _drawSpSwordKnight(canvas, e);
      }
    }

    // Health bar is kept outside the art silhouette.
    if (e.health > 1) {
      final w = 44.0;
      final ratio = (e.health / 2).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-22, -62, 44, 5),
          const Radius.circular(3),
        ),
        _spPaint(const Color(0xAA05070D)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-22, -62, w * ratio, 5),
          const Radius.circular(3),
        ),
        _spPaint(const Color(0xFFFFD34D)),
      );
    }

    canvas.restore();
  }

  void _drawSpHumanoidBody(
    Canvas canvas, {
    required Color suit,
    required Color dark,
    required Color light,
    required Color skin,
    bool hood = false,
    bool helmet = false,
  }) {
    // Boots.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -17, 13, 15),
        const Radius.circular(4),
      ),
      _spPaint(const Color(0xFF10131D)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, -17, 13, 15),
        const Radius.circular(4),
      ),
      _spPaint(const Color(0xFF10131D)),
    );

    // Legs with hard rim.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, -32, 12, 20),
        const Radius.circular(4),
      ),
      _spPaint(dark),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, -32, 12, 20),
        const Radius.circular(4),
      ),
      _spPaint(dark),
    );

    // Main torso, shoulder plates and center seam.
    final torso = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-23, -60, 46, 32),
      const Radius.circular(9),
    );
    canvas.drawRRect(torso, _spPaint(dark));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-19, -57, 38, 25),
        const Radius.circular(7),
      ),
      _spPaint(suit),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-2, -55, 4, 22),
      _spPaint(light, opacity: .55),
    );

    // Shoulder armor.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-27, -55, 12, 12),
        const Radius.circular(4),
      ),
      _spPaint(light),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, -55, 12, 12),
        const Radius.circular(4),
      ),
      _spPaint(light),
    );

    // Neck.
    canvas.drawRect(const Rect.fromLTWH(-7, -67, 14, 9), _spPaint(skin));

    // Head/hood/helmet.
    final head = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-24, -91, 48, 29),
      const Radius.circular(11),
    );
    canvas.drawRRect(head, _spPaint(dark));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, -88, 40, 22),
        const Radius.circular(8),
      ),
      _spPaint(hood ? suit : skin),
    );

    if (hood || helmet) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-22, -87, 44, 14),
          const Radius.circular(7),
        ),
        _spPaint(suit),
      );
      canvas.drawRect(
        const Rect.fromLTWH(-19, -78, 38, 7),
        _spPaint(const Color(0xFF090B12)),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-19, -79, 38, 8),
          const Radius.circular(3),
        ),
        _spPaint(const Color(0xFF090B12)),
      );
    }

    // Eyes/visor highlights.
    canvas.drawCircle(
      const Offset(-9, -75),
      3,
      _spPaint(const Color(0xFFFFE9F3)),
    );
    canvas.drawCircle(
      const Offset(9, -75),
      3,
      _spPaint(const Color(0xFFFFE9F3)),
    );
    canvas.drawCircle(
      const Offset(-8, -75),
      1.2,
      _spPaint(const Color(0xFF11131B)),
    );
    canvas.drawCircle(
      const Offset(10, -75),
      1.2,
      _spPaint(const Color(0xFF11131B)),
    );

    // Belt and buckle.
    canvas.drawRect(
      const Rect.fromLTWH(-20, -33, 40, 5),
      _spPaint(const Color(0xFF171B27)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -35, 10, 9),
        const Radius.circular(2),
      ),
      _spPaint(const Color(0xFFFFC83D)),
    );
  }

  void _drawSpArm(Canvas canvas, Offset hand, Color suit, Color skin) {
    final arm = Paint()
      ..color = suit
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(20, -51), hand, arm);
    canvas.drawCircle(hand, 5, _spPaint(skin));
  }

  void _drawSpHammerGuard(Canvas canvas, TrollEntity e) {
    _drawSpHumanoidBody(
      canvas,
      suit: const Color(0xFFE33450),
      dark: const Color(0xFF4B1424),
      light: const Color(0xFFFF687A),
      skin: const Color(0xFFD98E72),
      helmet: true,
    );

    final hand = const Offset(27, -38);
    _drawSpArm(canvas, hand, const Color(0xFFE33450), const Color(0xFFD98E72));

    // Heavy hammer held in both hands.
    final hammerAngle = e.attackCooldown > 0 ? -.55 : -.18;
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(hammerAngle);
    canvas.drawRect(
      const Rect.fromLTWH(-4, -5, 9, 47),
      _spPaint(const Color(0xFF8A5A37)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-19, -12, 38, 17),
        const Radius.circular(5),
      ),
      _spPaint(const Color(0xFF4C5362)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-13, -9, 26, 4),
      _spPaint(const Color(0xFF8D96AA)),
    );
    canvas.restore();

    // Armor highlight.
    _spStroke(
      canvas,
      Path()
        ..moveTo(-15, -84)
        ..lineTo(-7, -87)
        ..lineTo(4, -87),
      const Color(0xFFFFA2B0),
      1.5,
    );
  }

  void _drawSpWoodenClub(Canvas canvas, TrollEntity e) {
    _drawSpHumanoidBody(
      canvas,
      suit: const Color(0xFFC56A2E),
      dark: const Color(0xFF4A2818),
      light: const Color(0xFFE9A15C),
      skin: const Color(0xFFC78B68),
    );
    final hand = const Offset(25, -38);
    _drawSpArm(canvas, hand, const Color(0xFFC56A2E), const Color(0xFFC78B68));
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(-.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, -2, 9, 43),
        const Radius.circular(4),
      ),
      _spPaint(const Color(0xFF7A4324)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -13, 24, 17),
        const Radius.circular(7),
      ),
      _spPaint(const Color(0xFFD28A4C)),
    );
    canvas.drawCircle(const Offset(-5, -5), 2, _spPaint(const Color(0xFF7A4324)));
    canvas.drawCircle(const Offset(5, -9), 1.5, _spPaint(const Color(0xFF7A4324)));
    canvas.restore();
  }

  void _drawSpKnifeThief(Canvas canvas, TrollEntity e) {
    _drawSpHumanoidBody(
      canvas,
      suit: const Color(0xFF3FA95B),
      dark: const Color(0xFF103827),
      light: const Color(0xFF83E06D),
      skin: const Color(0xFFB87563),
      hood: true,
    );
    final hand = const Offset(25, -38);
    _drawSpArm(canvas, hand, const Color(0xFF3FA95B), const Color(0xFFB87563));

    // Knife is held forward with a distinct grip and steel blade.
    canvas.drawRect(
      Rect.fromLTWH(hand.dx, hand.dy - 3, 10, 6),
      _spPaint(const Color(0xFF5D3726)),
    );
    final blade = Path()
      ..moveTo(hand.dx + 7, hand.dy - 5)
      ..lineTo(hand.dx + 36, hand.dy - 13)
      ..lineTo(hand.dx + 23, hand.dy + 2)
      ..lineTo(hand.dx + 7, hand.dy + 2)
      ..close();
    canvas.drawPath(blade, _spPaint(const Color(0xFFE4EEF9)));
    _spStroke(
      canvas,
      Path()
        ..moveTo(hand.dx + 12, hand.dy - 2)
        ..lineTo(hand.dx + 30, hand.dy - 9),
      const Color(0xFFFFFFFF),
      1.4,
    );

    // Small throwing-knife holster on the belt.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, -42, 9, 15),
        const Radius.circular(2),
      ),
      _spPaint(const Color(0xFF18231D)),
    );
  }

  void _drawSpSwordKnight(Canvas canvas, TrollEntity e) {
    _drawSpHumanoidBody(
      canvas,
      suit: const Color(0xFF6C3DB7),
      dark: const Color(0xFF25133E),
      light: const Color(0xFFB17CFF),
      skin: const Color(0xFFC78D78),
      helmet: true,
    );
    final hand = const Offset(26, -39);
    _drawSpArm(canvas, hand, const Color(0xFF6C3DB7), const Color(0xFFC78D78));

    // Sword: grip -> guard -> blade, all aligned as one held weapon.
    canvas.drawRect(
      Rect.fromLTWH(hand.dx - 2, hand.dy - 1, 8, 16),
      _spPaint(const Color(0xFF6E432D)),
    );
    canvas.drawLine(
      Offset(hand.dx - 6, hand.dy),
      Offset(hand.dx + 10, hand.dy),
      Paint()
        ..color = const Color(0xFFFFD45B)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final blade = Path()
      ..moveTo(hand.dx + 7, hand.dy - 4)
      ..lineTo(hand.dx + 43, hand.dy - 16)
      ..lineTo(hand.dx + 30, hand.dy + 2)
      ..lineTo(hand.dx + 7, hand.dy + 3)
      ..close();
    canvas.drawPath(blade, _spPaint(const Color(0xFFDDE9F7)));
    _spStroke(
      canvas,
      Path()
        ..moveTo(hand.dx + 11, hand.dy - 2)
        ..lineTo(hand.dx + 36, hand.dy - 12),
      Colors.white,
      1.6,
    );
  }

  void _drawSpFireShooter(Canvas canvas, TrollEntity e) {
    _drawSpHumanoidBody(
      canvas,
      suit: const Color(0xFF7138B9),
      dark: const Color(0xFF24123F),
      light: const Color(0xFFB47BFF),
      skin: const Color(0xFFB87872),
      hood: true,
    );
    final hand = const Offset(27, -40);
    _drawSpArm(canvas, hand, const Color(0xFF7138B9), const Color(0xFFB87872));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hand.dx + 1, hand.dy - 6, 18, 12),
        const Radius.circular(4),
      ),
      _spPaint(const Color(0xFF2D203B)),
    );
    final flame = Path()
      ..moveTo(hand.dx + 18, hand.dy)
      ..cubicTo(hand.dx + 27, hand.dy - 10, hand.dx + 34, hand.dy - 4, hand.dx + 37, hand.dy - 11)
      ..cubicTo(hand.dx + 40, hand.dy - 2, hand.dx + 35, hand.dy + 5, hand.dx + 25, hand.dy + 5)
      ..close();
    canvas.drawPath(flame, _spPaint(const Color(0xFFFF5B21)));
    canvas.drawCircle(
      Offset(hand.dx + 26, hand.dy),
      4,
      _spPaint(const Color(0xFFFFE17A)),
    );
  }

  void _drawSpArcher(Canvas canvas, TrollEntity e) {
    _drawSpHumanoidBody(
      canvas,
      suit: const Color(0xFF6D3DA1),
      dark: const Color(0xFF21112F),
      light: const Color(0xFFD39BFF),
      skin: const Color(0xFFBC7B68),
      hood: true,
    );
    final hand = const Offset(25, -40);
    _drawSpArm(canvas, hand, const Color(0xFF6D3DA1), const Color(0xFFBC7B68));
    final bow = Path()
      ..moveTo(hand.dx + 3, -63)
      ..quadraticBezierTo(hand.dx + 25, -40, hand.dx + 3, -17);
    _spStroke(canvas, bow, const Color(0xFFD8A15F), 3);
    _spStroke(
      canvas,
      Path()
        ..moveTo(hand.dx + 3, -63)
        ..lineTo(hand.dx + 3, -17),
      const Color(0xFFE8D4B2),
      1.3,
    );
    _spStroke(
      canvas,
      Path()
        ..moveTo(hand.dx + 3, -40)
        ..lineTo(hand.dx + 34, -40),
      const Color(0xFFE8EDF5),
      1.5,
    );
    final arrow = Path()
      ..moveTo(hand.dx + 34, -40)
      ..lineTo(hand.dx + 26, -44)
      ..lineTo(hand.dx + 26, -36)
      ..close();
    canvas.drawPath(arrow, _spPaint(const Color(0xFFE8EDF5)));
  }

  void _drawSpBat(Canvas canvas) {
    final wing = _spPaint(const Color(0xFF713AC2));
    final wingLight = _spPaint(const Color(0xFFB778FF));
    final flap = sin(engine.stageSeed * .03 + engine.player.rect.left * .01) * 4;
    final left = Path()
      ..moveTo(-7, -48)
      ..lineTo(-34, -68 - flap)
      ..lineTo(-28, -39)
      ..lineTo(-42, -49 - flap)
      ..lineTo(-34, -22)
      ..lineTo(-12, -30)
      ..close();
    final right = Path()
      ..moveTo(7, -48)
      ..lineTo(34, -68 + flap)
      ..lineTo(28, -39)
      ..lineTo(42, -49 + flap)
      ..lineTo(34, -22)
      ..lineTo(12, -30)
      ..close();
    canvas.drawPath(left, wing);
    canvas.drawPath(right, wing);
    canvas.drawPath(
      Path()
        ..moveTo(-26, -57)
        ..lineTo(-32, -65 - flap)
        ..lineTo(-28, -43),
      wingLight,
    );
    canvas.drawPath(
      Path()
        ..moveTo(26, -57)
        ..lineTo(32, -65 + flap)
        ..lineTo(28, -43),
      wingLight,
    );
    canvas.drawCircle(const Offset(0, -43), 20, _spPaint(const Color(0xFF24123F)));
    canvas.drawCircle(const Offset(-7, -46), 3.5, _spPaint(const Color(0xFFFF4E78)));
    canvas.drawCircle(const Offset(7, -46), 3.5, _spPaint(const Color(0xFFFF4E78)));
    canvas.drawPath(
      Path()
        ..moveTo(-9, -35)
        ..lineTo(-3, -35)
        ..lineTo(-6, -28)
        ..close(),
      _spPaint(Colors.white),
    );
    canvas.drawPath(
      Path()
        ..moveTo(3, -35)
        ..lineTo(9, -35)
        ..lineTo(6, -28)
        ..close(),
      _spPaint(Colors.white),
    );
  }

  void _drawSpSpikedWalker(Canvas canvas) {
    final dark = _spPaint(const Color(0xFF281735));
    final body = _spPaint(const Color(0xFF7650A4));
    final edge = _spPaint(const Color(0xFFD3A7FF));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-28, -42, 56, 29),
        const Radius.circular(13),
      ),
      dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-24, -39, 48, 23),
        const Radius.circular(10),
      ),
      body,
    );
    for (int i = -2; i <= 2; i++) {
      final x = i * 10.0;
      final spike = Path()
        ..moveTo(x - 5, -38)
        ..lineTo(x, -55)
        ..lineTo(x + 5, -38)
        ..close();
      canvas.drawPath(spike, edge);
    }
    canvas.drawCircle(const Offset(-10, -27), 4, _spPaint(const Color(0xFFFFF0FB)));
    canvas.drawCircle(const Offset(10, -27), 4, _spPaint(const Color(0xFFFFF0FB)));
    canvas.drawCircle(const Offset(-9, -27), 1.6, dark);
    canvas.drawCircle(const Offset(11, -27), 1.6, dark);
    canvas.drawOval(const Rect.fromLTWH(-21, -19, 14, 6), dark);
    canvas.drawOval(const Rect.fromLTWH(7, -19, 14, 6), dark);
  }

  void _drawFireball(Canvas canvas, TrollEntity e) {
    final center = Offset(e.rect.centerX, e.rect.centerY);
    final dir = e.vx.sign == 0 ? 1.0 : e.vx.sign;

    final glow = Paint()
      ..color = const Color(0xFFFF5B21).withOpacity(.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, 15, glow);

    final flame = Path()
      ..moveTo(center.dx - dir * 15, center.dy)
      ..cubicTo(
        center.dx - dir * 27, center.dy - 8,
        center.dx - dir * 20, center.dy + 9,
        center.dx - dir * 34, center.dy + 2,
      )
      ..cubicTo(
        center.dx - dir * 23, center.dy + 1,
        center.dx - dir * 17, center.dy + 6,
        center.dx - dir * 12, center.dy + 5,
      )
      ..close();
    canvas.drawPath(flame, _spPaint(const Color(0xFFFF3E20)));

    canvas.drawCircle(center, 9, _spPaint(const Color(0xFFFF7A22)));
    canvas.drawCircle(
      Offset(center.dx - dir * 2, center.dy - 2),
      5,
      _spPaint(const Color(0xFFFFE27A)),
    );
    canvas.drawCircle(
      Offset(center.dx - dir * 4, center.dy - 4),
      2,
      _spPaint(Colors.white),
    );
  }

  void _drawRewardChest(Canvas canvas, TrollEntity e) {
    final x = e.rect.centerX;
    final y = e.rect.bottom;
    canvas.save();
    canvas.translate(x, y);

    // Ground shadow.
    canvas.drawOval(
      const Rect.fromLTWH(-31, -2, 62, 10),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Outer glow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-30, -56, 60, 47),
        const Radius.circular(8),
      ),
      Paint()
        ..color = const Color(0xFFFFC83D).withOpacity(.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Lid with a real curved silhouette.
    final lid = Path()
      ..moveTo(-29, -42)
      ..quadraticBezierTo(-27, -58, 0, -61)
      ..quadraticBezierTo(27, -58, 29, -42)
      ..close();
    canvas.drawPath(lid, _spPaint(const Color(0xFF9B5A2E)));
    _spStroke(canvas, lid, const Color(0xFFFFC45B), 2);

    // Body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-29, -43, 58, 35),
        const Radius.circular(6),
      ),
      _spPaint(const Color(0xFF704022)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-26, -40, 52, 6),
      _spPaint(const Color(0xFFB96C31)),
    );

    // Wooden plank highlights.
    _spStroke(
      canvas,
      Path()
        ..moveTo(-21, -34)
        ..lineTo(20, -12),
      const Color(0xFFC9823C),
      2,
    );
    _spStroke(
      canvas,
      Path()
        ..moveTo(21, -34)
        ..lineTo(-20, -12),
      const Color(0xFFC9823C),
      2,
    );

    // Gold bands and lock.
    canvas.drawRect(
      const Rect.fromLTWH(-25, -44, 6, 35),
      _spPaint(const Color(0xFFE3AD3B)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(19, -44, 6, 35),
      _spPaint(const Color(0xFFE3AD3B)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -31, 16, 16),
        const Radius.circular(3),
      ),
      _spPaint(const Color(0xFFFFD45A)),
    );
    canvas.drawCircle(const Offset(0, -23), 3, _spPaint(const Color(0xFF70420A)));

    // Reward indicator is deliberately small and sits above the box.
    final markerColor = e.rewardKind == 'gems'
        ? const Color(0xFF39E7FF)
        : e.rewardKind == 'heart'
            ? const Color(0xFFFF4F83)
            : const Color(0xFFFFC83D);
    canvas.drawCircle(
      const Offset(0, -68),
      8,
      Paint()
        ..color = markerColor.withOpacity(.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(const Offset(0, -68), 5, _spPaint(markerColor));
    canvas.restore();
  }

  void _drawPlayer(Canvas canvas, TrollEntity p, {double opacity = 1.0}) {
    final moving = p.vx.abs() > 8;
    final airborne = p.vy.abs() > 25;
    final crouched = engine.crouching;
    final step = moving ? sin(engine.stageSeed * .17 + p.rect.left * .035) * 2.5 : 0.0;
    final squash = airborne ? 1.04 : (crouched ? .82 : 1.0);

    canvas.save();
    canvas.translate(p.rect.centerX, p.rect.bottom);
    if (engine.playerFaceDir < 0) canvas.scale(-1, 1);
    canvas.scale(1.08, squash);

    // Soft contact shadow.
    canvas.drawOval(
      const Rect.fromLTWH(-25, -3, 50, 8),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Feet/step animation.
    final footPaint = _spPaint(const Color(0xFF24133B).withOpacity(opacity));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-17 + step, -10, 13, 10),
        const Radius.circular(4),
      ),
      footPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4 - step, -10, 13, 10),
        const Radius.circular(4),
      ),
      footPaint,
    );

    // Body silhouette: keep the familiar LVL LOOL purple creature, but give
    // it readable anatomy and an actual animated stance.
    final body = Path()
      ..moveTo(-21, -17)
      ..quadraticBezierTo(-23, -42, -16, -55)
      ..quadraticBezierTo(0, -66, 16, -55)
      ..quadraticBezierTo(23, -42, 21, -17)
      ..quadraticBezierTo(0, -8, -21, -17)
      ..close();
    canvas.drawPath(
      body,
      _spPaint(const Color(0xFF9D62FF).withOpacity(opacity)),
    );
    _spStroke(
      canvas,
      body,
      const Color(0xFFD9B5FF).withOpacity(opacity),
      2,
    );

    // Face panel.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-17, -50, 34, 22),
        const Radius.circular(8),
      ),
      _spPaint(const Color(0xFFB978FF).withOpacity(opacity)),
    );

    // Eyes track facing direction.
    final eye = _spPaint(const Color(0xFF171021).withOpacity(opacity));
    canvas.drawOval(
      Rect.fromLTWH(-10, -45, 6, 10),
      eye,
    );
    canvas.drawOval(
      Rect.fromLTWH(4, -45, 6, 10),
      eye,
    );
    canvas.drawCircle(const Offset(-8, -42), 1.2, _spPaint(Colors.white.withOpacity(opacity)));
    canvas.drawCircle(const Offset(6, -42), 1.2, _spPaint(Colors.white.withOpacity(opacity)));

    // Small expressive mouth changes with crouch.
    if (!crouched) {
      _spStroke(
        canvas,
        Path()
          ..moveTo(-5, -31)
          ..quadraticBezierTo(0, -28, 5, -31),
        const Color(0xFF5D2D82).withOpacity(opacity),
        1.6,
      );
    }

    // Crouch keeps the same character identity while reducing the visual
    // silhouette to match the gameplay hitbox.
    if (crouched) {
      canvas.scale(1.0, .84);
    }

    // Fireball launch hand/arm is visible when the player is facing right.
    if (engine.shootCooldown > 0) {
      canvas.drawCircle(
        const Offset(22, -35),
        5,
        _spPaint(const Color(0xFFFF7A22).withOpacity(opacity)),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrollPainter oldDelegate) => true;
}




class _DuelHud extends StatelessWidget {
  const _DuelHud({required this.matchId, required this.progress, required this.startTime});
  final String matchId;
  final double progress;
  final int startTime;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: DuelService.streamMatch(matchId),
      builder: (context, snapshot) {
        double oppProgress = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (data['player1'] == uid) {
            oppProgress = (data['p2Progress'] ?? 0.0).toDouble();
          } else {
            oppProgress = (data['p1Progress'] ?? 0.0).toDouble();
          }
        }
        
        final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
        final remaining = (180000 - elapsed) ~/ 1000;
        final seconds = remaining > 0 ? remaining : 0;
        final minStr = (seconds ~/ 60).toString();
        final secStr = (seconds % 60).toString().padLeft(2, '0');

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xD90A1124),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5CF5FF).withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('TIME: ${minStr}:${secStr}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('YOU', style: const TextStyle(color: Color(0xFF5CF5FF), fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 4, color: Colors.white24),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(height: 4, color: const Color(0xFF5CF5FF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('OPP', style: const TextStyle(color: Color(0xFFFF5478), fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 4, color: Colors.white24),
                        FractionallySizedBox(
                          widthFactor: oppProgress,
                          child: Container(height: 4, color: const Color(0xFFFF5478)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}

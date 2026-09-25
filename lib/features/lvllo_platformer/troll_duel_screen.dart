import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/cosmic_background.dart';
import '../../core/theme/design_tokens.dart';
import '../multiplayer_engine/duel_service.dart';
import 'troll_game.dart';
import 'troll_stage_plan.dart';

class TrollDuelScreen extends StatefulWidget {
  const TrollDuelScreen({super.key});

  @override
  State<TrollDuelScreen> createState() => _TrollDuelScreenState();
}

class _TrollDuelScreenState extends State<TrollDuelScreen> {
  bool _isSearching = false;
  String? _matchId;
  StreamSubscription? _matchSub;

  @override
  void dispose() {
    _matchSub?.cancel();
    super.dispose();
  }

  void _startSearch() async {
    setState(() { _isSearching = true; });
    try {
      final res = await DuelService.findOrCreateDuel();
      _matchId = res['matchId'];
      _listenToMatch();
    } catch (e) {
      if (mounted) {
        setState(() { _isSearching = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _listenToMatch() {
    if (_matchId == null) return;
    _matchSub = DuelService.streamMatch(_matchId!).listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      
      if (data['status'] == 'playing') {
        _matchSub?.cancel();
        _startMatch(data['stageId'], data['seed'], _matchId!);
      }
    });
  }

  void _startMatch(int stageId, int seed, String matchId) async {
    final plan = TrollStagePlan.getPlan(stageId);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TrollGame(
          stageId: stageId,
          startRound: plan.localStage,
          maxRounds: 1,
          levelsPerMechanic: plan.levelsPerMechanic,
          mechanicOffset: plan.mechanicOffset,
          duelMatchId: matchId,
          duelSeed: seed,
          onWin: (_) async {
             try {
                await DuelService.claimDuelWin(matchId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('YOU WON! +1000 Gold!')));
                }
             } catch (e) {
                // handle error
             }
             if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.backgroundDeep,
      body: CosmicBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('TROLL DUEL', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: GameColors.danger)),
                const SizedBox(height: 20),
                const Text('Entry: 500 Gold', style: TextStyle(color: Colors.amber, fontSize: 18)),
                const SizedBox(height: 40),
                if (_isSearching) ...[
                  const CircularProgressIndicator(color: GameColors.accentBright),
                  const SizedBox(height: 20),
                  const Text('Searching for opponent...', style: TextStyle(color: Colors.white)),
                ] else ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                    onPressed: _startSearch,
                    child: const Text('FIND MATCH', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

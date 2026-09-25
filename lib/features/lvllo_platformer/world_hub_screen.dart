import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/cosmic_background.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/lvllo_brand.dart';
import 'troll_game.dart';
import '../../economy_manager.dart';
import '../../services/life_recovery_dialog.dart';
import 'troll_stage_plan.dart';
import '../multiplayer_engine/duel_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'troll_duel_screen.dart';

class LvlloPlatformerHubScreen extends StatefulWidget {
  const LvlloPlatformerHubScreen({super.key, this.inline = false});
  final bool inline;

  @override
  State<LvlloPlatformerHubScreen> createState() => _LvlloPlatformerHubScreenState();
}

class _LvlloPlatformerHubScreenState extends State<LvlloPlatformerHubScreen> {
  Set<int> _completedStages = <int>{};
  int _gold = 0;
  int _rp = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final completed = await EconomyManager.completedStageIds();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        _gold = doc.data()?['gold'] ?? 0;
        _rp = doc.data()?['rp'] ?? 1000;
      }
    }
    
    if (!mounted) return;
    setState(() {
      _completedStages = completed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.backgroundDeep,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: GameColors.accentBright),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Row(
                      children: [
                        Text('RP: ', style: const TextStyle(color: GameColors.accentBright, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        Text('GOLD: ', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Text(
                  'LVL LOOL',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: CosmicPanel(
                  glow: true,
                  padding: const EdgeInsets.all(16),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrollDuelScreen()));
                    },
                    child: Column(
                      children: [
                        const Text('TROLL DUEL', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: GameColors.danger)),
                        const SizedBox(height: 8),
                        const Text('1v1 MULTIPLAYER', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        const Text('ENTRY: 500 GOLD', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.only(left: 24, top: 16, bottom: 8),
                child: Text('WORLD / SOLO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GameColors.accentBright)),
              ),
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: 75,
                  itemBuilder: (context, index) {
                    final internalStageId = 101 + index;
                    final displayStage = index + 1;
                    final isCompleted = _completedStages.contains(internalStageId);
                    
                    return Card(
                      color: GameColors.surfaceGlass,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCompleted ? GameColors.success : GameColors.surfaceStrong,
                          child: Text(displayStage.toString(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text('Stage ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Reward: 250 Gold (Daily)', style: TextStyle(color: Colors.amber, fontSize: 12)),
                        trailing: const Icon(Icons.play_arrow, color: GameColors.accentBright),
                        onTap: () => _playSoloStage(internalStageId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playSoloStage(int internalStageId) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrollGame(
          stageId: internalStageId,
          
        ),
      ),
    );

    if (result == true) {
      // Won stage
      try {
        final reward = await DuelService.claimSoloWin(internalStageId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claimed  Gold!')));
          _loadProgress();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Already claimed today or error')));
          _loadProgress();
        }
      }
      
      // Update local storage so it shows as completed
      EconomyManager.processStageWin(internalStageId);
    }
  }
}

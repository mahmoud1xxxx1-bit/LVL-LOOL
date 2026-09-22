import 'package:flutter/material.dart';
import '../core/theme/cosmic_background.dart';
import '../core/theme/design_tokens.dart';
import 'rewarded_ads_service.dart';
import '../economy_manager.dart';

Future<void> showLifeRecoveryDialog(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _LifeRecoverySheet(),
  );
}

class _LifeRecoverySheet extends StatefulWidget {
  const _LifeRecoverySheet();
  @override State<_LifeRecoverySheet> createState() => _LifeRecoverySheetState();
}

class _LifeRecoverySheetState extends State<_LifeRecoverySheet> {
  bool _busy = false;

  Future<void> _recover() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await RewardedAdsService.grantLifeFromRewardedAd();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
    else ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No rewarded life is available right now.')),
    );
  }

  @override Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: CosmicPanel(
        glow: true,
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite_rounded, color: GameColors.danger, size: 52),
          const SizedBox(height: 10),
          const Text('OUT OF LIVES', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          const Text(
            'Get +1 Life from a rewarded video. VIP players receive the Life immediately without showing an ad.',
            textAlign: TextAlign.center,
            style: TextStyle(color: GameColors.muted, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _recover,
              icon: _busy ? const SizedBox(width: 18,height: 18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.ondemand_video_rounded),
              label: Text(_busy ? 'PLEASE WAIT…' : 'GET +1 LIFE'),
            ),
          ),
        ]),
      ),
    ),
  );
}

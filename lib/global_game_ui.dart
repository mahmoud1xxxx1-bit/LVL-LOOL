import 'package:flutter/material.dart';
import 'features/lvllo_platformer/troll_engine.dart';

import 'store_screen.dart';
import 'l10n.dart';

class GlobalGameHUD extends StatelessWidget {
  final int lives;
  final int maxLives;
  final int gems;
  final int gold;
  final int unreadMail;
  final VoidCallback onMailTap;
  final VoidCallback onStoreTap;
  final VoidCallback? onBackTap;
  final VoidCallback? onSettingsTap;
  final String? title;

  const GlobalGameHUD({
    super.key,
    required this.lives,
    required this.maxLives,
    required this.gems,
    required this.gold,
    required this.unreadMail,
    required this.onMailTap,
    required this.onStoreTap,
    this.onBackTap,
    this.onSettingsTap,
    this.title,
  });

  Widget _buildBadge(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onBackTap != null) ...[
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: onBackTap,
                    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
              _buildBadge(Icons.favorite, Colors.redAccent, '$lives/$maxLives'),
              
              // GOD MODE TOGGLE (Invincibility for testing)
              StatefulBuilder(
                builder: (context, setState) {
                  return IconButton(
                    icon: Icon(
                      TrollEngine.godMode ? Icons.shield : Icons.shield_outlined, 
                      color: TrollEngine.godMode ? Colors.greenAccent : Colors.white54,
                    ),
                    tooltip: 'God Mode (Invincibility)',
                    onPressed: () {
                      setState(() {
                        TrollEngine.godMode = !TrollEngine.godMode;
                      });
                    },
                  );
                }
              ),
              if (title != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Text(title!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                ),
              ],
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadge(Icons.diamond_rounded, Colors.cyanAccent, '$gems'),
              const SizedBox(width: 6),
              _buildBadge(Icons.monetization_on, Colors.amber, '$gold'),
              const SizedBox(width: 6),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Badge(
                    isLabelVisible: unreadMail > 0,
                    label: Text('$unreadMail'),
                    child: const Icon(Icons.mail_outline, color: Colors.white, size: 18),
                  ),
                  onPressed: onMailTap,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFB400FF).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFB400FF).withOpacity(0.5)),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
                  onPressed: onStoreTap,
                ),
              ),
              if (onSettingsTap != null) ...[
                const SizedBox(width: 6),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                    onPressed: onSettingsTap,
                  ),
                ),
              ],
            ],
          )
        ],
      ),
      ),
    );
  }
}

class GamePopups {
  static void _showDialog(BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String message,
    required List<Widget> actions,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF0F111A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.12), blurRadius: 30, spreadRadius: 2)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 60),
                const SizedBox(height: 16),
                Text(title, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(message, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: actions,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showError(BuildContext context, {required String message, VoidCallback? onStoreRoute}) {
    _showDialog(
      context,
      color: Colors.redAccent,
      icon: Icons.error_outline_rounded,
      title: 'INSUFFICIENT FUNDS',
      message: message,
      actions: [
        if (onStoreRoute != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onStoreRoute();
              },
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text('STORE', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        else
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OKAY', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  static void showSuccess(BuildContext context, {required String title, required String message}) {
    _showDialog(
      context,
      color: Colors.greenAccent,
      icon: Icons.check_circle_outline_rounded,
      title: title,
      message: message,
      actions: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('AWESOME!', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  static void showConfirm(BuildContext context, {
    required String title,
    required String message,
    required Color color,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
    _showDialog(
      context,
      color: color,
      icon: Icons.help_outline_rounded,
      title: title,
      message: message,
      actions: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white54,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}


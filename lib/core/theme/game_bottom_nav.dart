import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

class GameBottomNav extends StatelessWidget {
  const GameBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<GameBottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Container(
        height: 74,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: GameColors.surfaceGlass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GameColors.surfaceStrong),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GameBottomNavItem {
  const GameBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GameBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return AnimatedScale(
      scale: _pressed ? .92 : 1,
      duration: GameDurations.fast,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: AnimatedContainer(
            duration: GameDurations.normal,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              gradient: selected ? GameColors.cosmicGradient : null,
              borderRadius: BorderRadius.circular(18),
              boxShadow: selected ? GameShadows.primaryGlow : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: GameDurations.fast,
                  child: Icon(
                    selected ? widget.item.activeIcon : widget.item.icon,
                    key: ValueKey(selected),
                    size: selected ? 23 : 21,
                    color: selected
                        ? GameColors.backgroundDeep
                        : GameColors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? GameColors.backgroundDeep
                        : GameColors.muted,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

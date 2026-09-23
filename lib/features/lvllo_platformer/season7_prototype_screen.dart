import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/game_orientation.dart';
import 'troll_game.dart';

/// Season 7 prototype screen.
/// This screen is isolated from the existing six-season architecture.
class Season7PrototypeScreen extends StatefulWidget {
  const Season7PrototypeScreen({super.key});

  @override
  State<Season7PrototypeScreen> createState() => _Season7PrototypeScreenState();
}

class _Season7PrototypeScreenState extends State<Season7PrototypeScreen> {
  @override
  void initState() {
    super.initState();
    GameOrientation.enterGame();
  }

  @override
  void dispose() {
    GameOrientation.leaveGame();
    super.dispose();
  }

  Future<void> _startPrototypeStage() async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => TrollGame(
          // Temporary playable backend only. It does not alter the six
          // existing seasons while the Season 7 design is being evaluated.
          stageId: 101,
          startRound: 1,
          maxRounds: 1,
          levelsPerMechanic: 3,
          mechanicOffset: 0,
          onWin: (_) async {
            if (context.mounted) Navigator.of(context).pop();
          },
          onFail: () async {
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030714),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return wide ? _wideLayout() : _compactLayout();
          },
        ),
      ),
    );
  }

  Widget _wideLayout() {
    return Row(
      children: [
        SizedBox(width: 280, child: _levelRail()),
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _topBar()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 16, 18),
                sliver: SliverToBoxAdapter(child: _stagePreview()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 16, 20),
                sliver: SliverToBoxAdapter(child: _infoRow()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactLayout() {
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              _stagePreview(),
              const SizedBox(height: 12),
              _infoRow(),
              const SizedBox(height: 12),
              _levelRail(compact: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFB9C7FF)),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Row(
              children: [
                Text(
                  'LVL LOOL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'SEASON 7',
                  style: TextStyle(
                    color: Color(0xFFF05CFF),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          _resourcePill(Icons.diamond_rounded, '0', const Color(0xFF61D8FF)),
          const SizedBox(width: 8),
          _resourcePill(Icons.monetization_on_rounded, '0', const Color(0xFFFFC94D)),
          const SizedBox(width: 5),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_rounded, color: Color(0xFFB9C7FF)),
          ),
        ],
      ),
    );
  }

  Widget _resourcePill(IconData icon, String value, Color color) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF08112A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(width: 3),
          const Icon(Icons.add_rounded, size: 14, color: Color(0xFF7F8EAE)),
        ],
      ),
    );
  }

  Widget _levelRail({bool compact = false}) {
    return Container(
      margin: compact ? EdgeInsets.zero : const EdgeInsets.fromLTRB(12, 10, 0, 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF050B1B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF27355F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFFF05CFF), size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('SEASON 7', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ),
              const Text(
                '1 / 10',
                style: TextStyle(color: Color(0xFF9AA8C8), fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              minHeight: 7,
              value: .1,
              backgroundColor: Color(0xFF111A35),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD33CFF)),
            ),
          ),
          const SizedBox(height: 12),
          for (var level = 1; level <= 10; level++) ...[
            _levelItem(level),
            if (level != 10) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }

  Widget _levelItem(int level) {
    final active = level == 1;
    return Container(
      height: 53,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF32104F) : const Color(0xFF071024),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? const Color(0xFFD33CFF) : const Color(0xFF17254A),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 9),
          Icon(
            active ? Icons.play_circle_fill_rounded : Icons.lock_rounded,
            color: active ? const Color(0xFFE15AFF) : const Color(0xFF536384),
            size: 25,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEVEL $level',
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF687695),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  active ? 'The Fake Path' : '???',
                  style: TextStyle(
                    color: active ? const Color(0xFFB9C7FF) : const Color(0xFF45516D),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFE15AFF)),
          const SizedBox(width: 7),
        ],
      ),
    );
  }

  Widget _stagePreview() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF040A19),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF293861)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1C0A39), Color(0xFF35105D)]),
            ),
            alignment: Alignment.centerLeft,
            child: const Text(
              'LEVEL 1 — THE FAKE PATH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 2.35,
            child: CustomPaint(
              painter: _Season7PreviewPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _infoCard(
            title: 'معلومات المرحلة',
            icon: Icons.track_changes_rounded,
            children: const [
              _InfoLine('اسم المرحلة', 'The Fake Path'),
              _InfoLine('الموسم', '7'),
              _InfoLine('المرحلة', '1'),
              _InfoLine('النجوم', '3'),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoCard(
            title: 'الفخاخ والأفكار',
            icon: Icons.priority_high_rounded,
            iconColor: Color(0xFFFF4D6D),
            children: const [
              _InfoLine('الفخ', 'منصة وهمية'),
              _InfoLine('الخداع', 'المسار العلوي يبدو آمناً'),
              _InfoLine('الخدعة', 'المفتاح ليس في الطريق المتوقع'),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoCard(
            title: 'الفكرة الرئيسية',
            icon: Icons.lightbulb_rounded,
            iconColor: Color(0xFFFFC94D),
            children: const [
              _InfoLine('التوقع', 'الطريق واضح في البداية'),
              _InfoLine('الخداع', 'الطريق الآمن الظاهر ليس هو الصحيح'),
              _InfoLine('النجاح', 'راقب الإشارة ولا تتسرع'),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _rewardCard()),
      ],
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<_InfoLine> children,
    Color iconColor = const Color(0xFFB45CFF),
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF061024),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1C2B51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 21),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in children) ...[
            Text(
              line.label,
              style: const TextStyle(
                color: Color(0xFF667698),
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              line.value,
              style: const TextStyle(color: Color(0xFFD5DCED), fontSize: 9, height: 1.2),
            ),
            const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }

  Widget _rewardCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF061024),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1C2B51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFC94D), size: 21),
              SizedBox(width: 7),
              Text('المكافأة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const Spacer(),
          const Text('إكمال المرحلة يمنحك:', style: TextStyle(color: Color(0xFF667698), fontSize: 9)),
          const SizedBox(height: 8),
          const Text(
            '+ 3 GEMS',
            style: TextStyle(color: Color(0xFF61D8FF), fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const Text(
            '+ 250 GOLD',
            style: TextStyle(color: Color(0xFFFFC94D), fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: FilledButton.icon(
              onPressed: _startPrototypeStage,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ابدأ المرحلة', style: TextStyle(fontWeight: FontWeight.w900)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD33CFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine {
  const _InfoLine(this.label, this.value);
  final String label;
  final String value;
}

class _Season7PreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF101A3C), Color(0xFF050A18)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final glow = Paint()
      ..color = const Color(0xFF7B3CFF).withOpacity(.13)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35);
    canvas.drawCircle(Offset(w * .82, h * .30), h * .42, glow);

    final rock = Paint()..color = const Color(0xFF111B38);
    final edge = Paint()..color = const Color(0xFF263A67);
    final cyan = Paint()..color = const Color(0xFF35D8FF);
    final magenta = Paint()..color = const Color(0xFFE044FF);
    final danger = Paint()..color = const Color(0xFFFF3E69);
    final player = Paint()..color = const Color(0xFF62F4D7);

    void platform(double x, double y, double pw, double ph) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, pw, ph),
        const Radius.circular(4),
      );
      canvas.drawRRect(r, rock);
      canvas.drawRect(Rect.fromLTWH(x, y, pw, 4), edge);
      canvas.drawRect(Rect.fromLTWH(x + 4, y, pw - 8, 2), cyan);
    }

    void spikes(double x, double y, double sw) {
      final count = (sw / 18).clamp(2, 7).round();
      final tw = sw / count;
      for (var i = 0; i < count; i++) {
        final p = Path()
          ..moveTo(x + i * tw, y)
          ..lineTo(x + i * tw + tw / 2, y - 18)
          ..lineTo(x + (i + 1) * tw, y)
          ..close();
        canvas.drawPath(p, danger);
      }
    }

    platform(w * .02, h * .69, w * .20, 24);
    platform(w * .27, h * .69, w * .18, 24);
    platform(w * .53, h * .72, w * .16, 24);
    platform(w * .76, h * .59, w * .21, 24);

    canvas.drawRect(
      Rect.fromLTWH(w * .20, h * .78, w * .58, h * .22),
      Paint()..color = const Color(0xFF8C1434),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * .20, h * .78, w * .58, 5),
      Paint()..color = const Color(0xFFFF4D72),
    );
    spikes(w * .22, h * .78, w * .13);
    spikes(w * .43, h * .78, w * .13);
    spikes(w * .59, h * .78, w * .16);

    // Fake-path platform shown in the approved prototype concept.
    platform(w * .35, h * .49, w * .15, 22);
    canvas.drawRect(
      Rect.fromLTWH(w * .355, h * .49, w * .14, 4),
      Paint()..color = magenta,
    );

    // Ceiling spike.
    final hanging = Path()
      ..moveTo(w * .49, h * .10)
      ..lineTo(w * .54, h * .10)
      ..lineTo(w * .515, h * .31)
      ..close();
    canvas.drawPath(hanging, danger);

    // Key.
    canvas.drawCircle(Offset(w * .66, h * .54), 7, cyan);
    canvas.drawRect(Rect.fromLTWH(w * .66, h * .53, 27, 4), cyan);
    canvas.drawRect(Rect.fromLTWH(w * .68, h * .57, 4, 8), cyan);

    // Goal door.
    final door = Rect.fromLTWH(w * .84, h * .36, w * .10, h * .23);
    final doorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = magenta;
    canvas.drawRRect(
      RRect.fromRectAndRadius(door, const Radius.circular(8)),
      doorPaint,
    );

    // Player.
    final px = w * .075;
    final py = h * .69 - 25;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px, py, 25, 25),
        const Radius.circular(6),
      ),
      player,
    );
    final eye = Paint()..color = const Color(0xFF07101C);
    canvas.drawRect(Rect.fromLTWH(px + 6, py + 7, 4, 8), eye);
    canvas.drawRect(Rect.fromLTWH(px + 15, py + 7, 4, 8), eye);

    // Small direction arrow from the reference concept.
    final arrow = Paint()..color = const Color(0xFFFFC94D);
    final arrowPath = Path()
      ..moveTo(w * .15, h * .58)
      ..lineTo(w * .20, h * .58)
      ..lineTo(w * .20, h * .54)
      ..lineTo(w * .23, h * .61)
      ..lineTo(w * .20, h * .68)
      ..lineTo(w * .20, h * .64)
      ..lineTo(w * .15, h * .64)
      ..close();
    canvas.drawPath(arrowPath, arrow);
  }

  @override
  bool shouldRepaint(covariant _Season7PreviewPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'lvllo_engine.dart';

class LvlloPlatformerGame extends StatefulWidget {
  const LvlloPlatformerGame({super.key, required this.levelId});
  final int levelId;

  @override
  State<LvlloPlatformerGame> createState() => _LvlloPlatformerGameState();
}

class _LvlloPlatformerGameState extends State<LvlloPlatformerGame> with SingleTickerProviderStateMixin {
  late LvlloPlatformerEngine _engine;
  late Ticker _ticker;
  Duration _lastTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _engine = LvlloPlatformerEngine(levelId: widget.levelId);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;

    setState(() {
      _engine.update(dt);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _engine.movingLeft = true;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) _engine.movingRight = true;
      if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp) _engine.jumping = true;
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _engine.movingLeft = false;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) _engine.movingRight = false;
      if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp) _engine.jumping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF111111),
        body: Column(
          children: [
            if (_engine.isDead)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red,
                child: const Text("DIED! Troll got you. Refresh to restart.", style: TextStyle(color: Colors.white)),
              ),
            if (_engine.isWon)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.green,
                child: const Text("YOU WON! (Survived the Troll).", style: TextStyle(color: Colors.white)),
              ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 800 / 600,
                  child: Container(
                    color: Colors.black,
                    child: CustomPaint(
                      painter: _LvlloPlatformerPainter(_engine),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
            // On screen controls
            Container(
              height: 100,
              color: const Color(0xFF222222),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTapDown: (_) => _engine.movingLeft = true,
                    onTapUp: (_) => _engine.movingLeft = false,
                    onTapCancel: () => _engine.movingLeft = false,
                    child: Container(
                      width: 80, height: 80, color: Colors.blueGrey,
                      child: const Icon(Icons.arrow_left, size: 50, color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (_) => _engine.movingRight = true,
                    onTapUp: (_) => _engine.movingRight = false,
                    onTapCancel: () => _engine.movingRight = false,
                    child: Container(
                      width: 80, height: 80, color: Colors.blueGrey,
                      child: const Icon(Icons.arrow_right, size: 50, color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (_) => _engine.jumping = true,
                    onTapUp: (_) => _engine.jumping = false,
                    onTapCancel: () => _engine.jumping = false,
                    child: Container(
                      width: 80, height: 80, color: Colors.redAccent,
                      child: const Icon(Icons.arrow_upward, size: 50, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LvlloPlatformerPainter extends CustomPainter {
  _LvlloPlatformerPainter(this.engine);
  final LvlloPlatformerEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    double scaleX = size.width / 800;
    double scaleY = size.height / 600;
    
    canvas.save();
    canvas.scale(scaleX, scaleY);

    var paint = Paint();
    
    for (var e in engine.entities) {
      paint.color = e.color;
      if (e.type == EntityType.spike) {
        // Draw spike as a triangle
        var path = Path()
          ..moveTo(e.rect.left + e.rect.w / 2, e.rect.top)
          ..lineTo(e.rect.right, e.rect.bottom)
          ..lineTo(e.rect.left, e.rect.bottom)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawRect(e.rect.toRect(), paint);
      }
    }

    // Draw player
    paint.color = engine.player.color;
    canvas.drawRect(engine.player.rect.toRect(), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LvlloPlatformerPainter oldDelegate) => true;
}

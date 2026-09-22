import 'dart:ui';
import 'package:flutter/material.dart';

enum EntityType { player, block, spike, door }

class RectD {
  double x, y, w, h;
  RectD(this.x, this.y, this.w, this.h);
  double get left => x;
  double get right => x + w;
  double get top => y;
  double get bottom => y + h;

  bool intersects(RectD other) {
    return left < other.right &&
        right > other.left &&
        top < other.bottom &&
        bottom > other.top;
  }
  
  Rect toRect() => Rect.fromLTWH(x, y, w, h);
}

class Entity {
  Entity({
    required this.id,
    required this.type,
    required this.rect,
    this.color = Colors.white,
    this.isSolid = true,
  });

  String id;
  EntityType type;
  RectD rect;
  Color color;
  bool isSolid;

  double vx = 0;
  double vy = 0;
  bool activePhysics = false;
}

abstract class TrollTrigger {
  RectD activationArea;
  bool triggered = false;
  TrollTrigger(this.activationArea);

  void update(LvlloPlatformerEngine engine, double dt);
}

class FallingFloorTroll extends TrollTrigger {
  FallingFloorTroll(RectD area, this.targetIds) : super(area);
  List<String> targetIds;

  @override
  void update(LvlloPlatformerEngine engine, double dt) {
    if (triggered) return;
    if (activationArea.intersects(engine.player.rect)) {
      triggered = true;
      for (var id in targetIds) {
        var block = engine.entities.where((e) => e.id == id).firstOrNull;
        if (block != null) {
          block.activePhysics = true;
          block.vy = 50; 
        }
      }
    }
  }
}

class HiddenSpikeTroll extends TrollTrigger {
  HiddenSpikeTroll(RectD area, this.targetIds) : super(area);
  List<String> targetIds;

  @override
  void update(LvlloPlatformerEngine engine, double dt) {
    if (triggered) return;
    if (activationArea.intersects(engine.player.rect)) {
      triggered = true;
      for (var id in targetIds) {
        var spike = engine.entities.where((e) => e.id == id).firstOrNull;
        if (spike != null) {
          spike.rect.y -= 40;
          spike.color = Colors.redAccent; 
        }
      }
    }
  }
}

class LvlloPlatformerEngine {
  LvlloPlatformerEngine({required this.levelId}) {
    _loadLevel(levelId);
  }

  final int levelId;
  
  late Entity player;
  List<Entity> entities = [];
  List<TrollTrigger> triggers = [];
  
  bool isDead = false;
  bool isWon = false;
  
  final double gravity = 1800.0;
  final double moveSpeed = 300.0;
  final double jumpForce = -650.0;
  
  bool movingLeft = false;
  bool movingRight = false;
  bool jumping = false;
  
  bool _isGrounded = false;
  
  final double gs = 40.0; 

  void _loadLevel(int id) {
    entities.clear();
    triggers.clear();
    isDead = false;
    isWon = false;
    movingLeft = false;
    movingRight = false;
    jumping = false;

    List<String> map = [];
    if (id == 1) {
      map = [
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "...................D",
        "....P...............",
        "XXXXX11112222XXXXXXX",
        "XXXXXXXXXXXXXXXXXXXX",
      ];
      triggers.add(FallingFloorTroll(RectD(5*gs, 12*gs, 4*gs, gs), ["b_13_5","b_13_6","b_13_7","b_13_8"]));
    } else if (id == 2) {
       map = [
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "...................D",
        "..P.................",
        "XXXX....XXXX....XXXX",
        "XXXXSSSSXXXXSSSSXXXX",
      ];
      triggers.add(HiddenSpikeTroll(RectD(11*gs, 10*gs, 4*gs, 3*gs), ["s_14_12","s_14_13","s_14_14","s_14_15"]));
    } else {
      map = [
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        "...................D",
        "..P.................",
        "XXXXXXXXXXXXXXXXXXXX",
        "XXXXXXXXXXXXXXXXXXXX",
      ];
    }

    _parseMap(map);
  }

  void _parseMap(List<String> map) {
    for (int row = 0; row < map.length; row++) {
      for (int col = 0; col < map[row].length; col++) {
        String char = map[row][col];
        double x = col * gs;
        double y = row * gs;
        
        if (char == 'P') {
          player = Entity(
            id: 'player',
            type: EntityType.player,
            rect: RectD(x + 5, y + 10, 30, 30),
            color: Colors.blueAccent,
          );
        } else if (char == 'X' || char == '1' || char == '2') {
          entities.add(Entity(
            id: 'b_${row}_${col}',
            type: EntityType.block,
            rect: RectD(x, y, gs, gs),
            color: const Color(0xFF444444),
          ));
        } else if (char == 'S') {
          entities.add(Entity(
            id: 's_${row}_${col}',
            type: EntityType.spike,
            rect: RectD(x, y + gs, gs, gs), 
            color: Colors.transparent, 
            isSolid: false,
          ));
        } else if (char == 'D') {
          entities.add(Entity(
            id: 'door',
            type: EntityType.door,
            rect: RectD(x, y - 20, 40, 60),
            color: Colors.yellowAccent,
            isSolid: false,
          ));
        }
      }
    }
  }

  void update(double dt) {
    if (dt > 0.05) dt = 0.05;
    if (isDead || isWon) return;

    for (var trigger in triggers) {
      trigger.update(this, dt);
    }

    if (movingLeft) {
      player.vx = -moveSpeed;
    } else if (movingRight) {
      player.vx = moveSpeed;
    } else {
      player.vx = 0;
    }

    player.rect.x += player.vx * dt;
    _resolveCollisions(true);

    player.vy += gravity * dt;
    
    if (jumping && _isGrounded) {
      player.vy = jumpForce;
      _isGrounded = false;
      jumping = false;
    }

    player.rect.y += player.vy * dt;
    _isGrounded = false;
    _resolveCollisions(false);
    
    for (var e in entities) {
      if (e.activePhysics) {
        e.vy += gravity * dt;
        e.rect.y += e.vy * dt;
      }
    }
    
    if (player.rect.top > 800) {
      isDead = true;
    }
    
    for (var e in entities) {
      if (e.rect.intersects(player.rect)) {
        if (e.type == EntityType.spike) {
          isDead = true;
        } else if (e.type == EntityType.door) {
          isWon = true;
        }
      }
    }
  }

  void _resolveCollisions(bool isAxisX) {
    for (var e in entities) {
      if (!e.isSolid) continue;
      
      if (player.rect.intersects(e.rect)) {
        if (isAxisX) {
          if (player.vx > 0) {
            player.rect.x = e.rect.left - player.rect.w;
          } else if (player.vx < 0) {
            player.rect.x = e.rect.right;
          }
          player.vx = 0;
        } else {
          if (player.vy > 0) {
            player.rect.y = e.rect.top - player.rect.h;
            _isGrounded = true;
          } else if (player.vy < 0) {
            player.rect.y = e.rect.bottom;
          }
          player.vy = 0;
        }
      }
    }
  }
}

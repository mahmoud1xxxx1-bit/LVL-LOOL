import 'dart:math';
import 'package:flutter/material.dart';

enum TrollEntityType { player, block, spike, door, particle }

class RectD {
  double x, y, w, h;
  RectD(this.x, this.y, this.w, this.h);
  
  double get left => x;
  double get right => x + w;
  double get top => y;
  double get bottom => y + h;
  
  RectD clone() => RectD(x, y, w, h);
  
  bool intersects(RectD other) {
    return left < other.right && right > other.left &&
           top < other.bottom && bottom > other.top;
  }
  
  Rect toRect() => Rect.fromLTWH(x, y, w, h);
}

class TrollEntity {
  String id;
  TrollEntityType type;
  RectD rect;
  Color color;
  bool isSolid;
  bool isVisible;
  bool activePhysics;
  double vy;
  bool isInverted;

  TrollEntity({
    required this.id,
    required this.type,
    required this.rect,
    this.color = Colors.white,
    this.isSolid = true,
    this.isVisible = true,
    this.activePhysics = false,
    this.vy = 0,
    this.isInverted = false,
  });

  double vx = 0;
}

class Particle {
  double x, y, vx, vy, life, maxLife;
  Color color;
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.color) : maxLife = life;
}

// ---------------- Traps State Machine ----------------

abstract class TrollTrap {
  void update(TrollEngine engine, double dt);
}

// Drops floor blocks when player enters a trigger zone BEFORE the blocks.
class FallingPlatformTrap extends TrollTrap {
  final RectD triggerArea;
  final List<String> targetIds;
  List<TrollEntity>? _cachedEntities;
  bool triggered = false;
  
  FallingPlatformTrap(this.triggerArea, this.targetIds);

  @override
  void update(TrollEngine engine, double dt) {
    if (triggered) return;
    
    if (_cachedEntities == null) {
      _cachedEntities = [];
      for (var id in targetIds) {
        var e = engine.entities.where((e) => e.id == id).firstOrNull;
        if (e != null) _cachedEntities!.add(e);
      }
    }
    
    if (triggerArea.intersects(engine.player.rect)) {
      triggered = true;
      for (var block in _cachedEntities!) {
        block.activePhysics = true;
        block.vy = engine.isGravityInverted ? -200 : 200; // Fall!
      }
    }
  }
}

// Spikes that suddenly appear ON the floor when you get near, disappear when you back away.
class AppearingSpikesTrap extends TrollTrap {
  final RectD triggerArea;
  final List<String> targetIds;
  List<TrollEntity>? _cachedEntities;
  bool isUp = false;
  
  AppearingSpikesTrap(this.triggerArea, this.targetIds);

  @override
  void update(TrollEngine engine, double dt) {
    if (_cachedEntities == null) {
      _cachedEntities = [];
      for (var id in targetIds) {
        var e = engine.entities.where((e) => e.id == id).firstOrNull;
        if (e != null) _cachedEntities!.add(e);
      }
    }

    bool inZone = triggerArea.intersects(engine.player.rect);
    if (inZone && !isUp) {
      isUp = true;
      for (var spike in _cachedEntities!) {
        spike.isVisible = true; // Suddenly appear!
      }
    } else if (!inZone && isUp) {
      isUp = false;
      for (var spike in _cachedEntities!) {
        spike.isVisible = false; // Disappear when backed away!
      }
    }
  }
}

// Blocks that suddenly appear to block your jump!
class AppearingWallTrap extends TrollTrap {
  final RectD triggerArea;
  final List<String> targetIds;
  List<TrollEntity>? _cachedEntities;
  bool isUp = false;
  
  AppearingWallTrap(this.triggerArea, this.targetIds);

  @override
  void update(TrollEngine engine, double dt) {
    if (_cachedEntities == null) {
      _cachedEntities = [];
      for (var id in targetIds) {
        var e = engine.entities.where((e) => e.id == id).firstOrNull;
        if (e != null) _cachedEntities!.add(e);
      }
    }

    bool inZone = triggerArea.intersects(engine.player.rect);
    if (inZone && !isUp) {
      isUp = true;
      for (var block in _cachedEntities!) {
        block.isVisible = true;
        block.isSolid = true;
      }
    } else if (!inZone && isUp) {
      isUp = false;
      for (var block in _cachedEntities!) {
        block.isVisible = false;
        block.isSolid = false;
      }
    }
  }
}

class ThwompCeilingTrap extends TrollTrap {
  final RectD triggerArea;
  final List<String> targetIds;
  Map<TrollEntity, double> cachedEntities = {}; // Cache entity -> originalY
  final double dropHeight;
  bool triggered = false; 
  
  ThwompCeilingTrap(this.triggerArea, this.targetIds, this.dropHeight);

  @override
  void update(TrollEngine engine, double dt) {
    if (targetIds.isEmpty) return;
    
    // Cache entities and their original Ys on first tick
    if (cachedEntities.isEmpty) {
      for (var id in targetIds) {
        var e = engine.entities.where((e) => e.id == id).firstOrNull;
        if (e != null) {
          cachedEntities[e] = e.rect.y;
        }
      }
    }
    
    if (!triggered && triggerArea.intersects(engine.player.rect)) {
      triggered = true;
    }
    
    if (triggered) {
      for (var entry in cachedEntities.entries) {
        var entity = entry.key;
        double thisOriginalY = entry.value;
        
        entity.rect.y += 2400 * dt; // Slam down even faster!
        if (entity.rect.y > thisOriginalY + dropHeight) {
          entity.rect.y = thisOriginalY + dropHeight;
        }
      }
    }
  }
}

class RunningDoorTrap extends TrollTrap {
  final RectD triggerArea;
  final String doorId;
  TrollEntity? _cachedDoor;
  final double moveDistanceX;
  bool isMoving = false;
  bool triggered = false;
  double targetX = 0;
  
  RunningDoorTrap(this.triggerArea, this.doorId, this.moveDistanceX);

  @override
  void update(TrollEngine engine, double dt) {
    if (_cachedDoor == null) {
      _cachedDoor = engine.entities.where((e) => e.id == doorId).firstOrNull;
    }
    var door = _cachedDoor;
    if (door == null) return;

    if (!triggered && triggerArea.intersects(engine.player.rect)) {
      triggered = true;
      isMoving = true;
      targetX = door.rect.x + moveDistanceX;
    }

    if (isMoving) {
      double dir = (targetX - door.rect.x).sign;
      door.rect.x += dir * 700 * dt; 
      if (dir > 0 && door.rect.x >= targetX) {
        door.rect.x = targetX;
        isMoving = false;
      } else if (dir < 0 && door.rect.x <= targetX) {
        door.rect.x = targetX;
        isMoving = false;
      }
    }
  }
}

// ---------------- NEW C2 TRAPS ----------------

// Fake Solid Trap: Looks like a solid block, but becomes non-solid and slightly transparent when touched.
class FakeSolidTrap extends TrollTrap {
  final RectD triggerArea;
  final List<String> targetIds;
  List<TrollEntity>? _cachedEntities;
  bool triggered = false;
  
  FakeSolidTrap(this.triggerArea, this.targetIds);

  @override
  void update(TrollEngine engine, double dt) {
    if (triggered) return;
    
    if (_cachedEntities == null) {
      _cachedEntities = [];
      for (var id in targetIds) {
        var e = engine.entities.where((e) => e.id == id).firstOrNull;
        if (e != null) _cachedEntities!.add(e);
      }
    }
    
    if (triggerArea.intersects(engine.player.rect)) {
      triggered = true;
      for (var block in _cachedEntities!) {
        block.isSolid = false;
        block.color = block.color.withOpacity(0.3); // Reveal the fake!
      }
    }
  }
}

// Erratic Patrol Spike: Moves back and forth but changes its bounds randomly every time it turns!
class ErraticPatrolSpikeTrap extends TrollTrap {
  final String spikeId;
  TrollEntity? _cachedSpike;
  final double speed;
  double leftBound = -1;
  double rightBound = -1;
  int direction = 1;
  Random? _movementRng;
  
  ErraticPatrolSpikeTrap(this.spikeId, this.speed);

  @override
  void update(TrollEngine engine, double dt) {
    if (_cachedSpike == null) {
      _cachedSpike = engine.entities.where((e) => e.id == spikeId).firstOrNull;
    }
    var spike = _cachedSpike;
    if (spike == null) return;

    // Gameplay movement gets its own deterministic RNG. It never consumes the
    // level-generation RNG, so frame timing/order cannot change the sequence.
    _movementRng ??= Random(engine.stageSeed ^ spikeId.hashCode);

    if (leftBound == -1) {
      leftBound = spike.rect.x - (_movementRng!.nextDouble() * 3 + 1) * 40.0;
      rightBound = spike.rect.x + (_movementRng!.nextDouble() * 3 + 2) * 40.0;
    }
    
    spike.rect.x += speed * direction * dt;
    if (direction == 1 && spike.rect.x >= rightBound) {
      spike.rect.x = rightBound;
      direction = -1;
      leftBound = spike.rect.x - (_movementRng!.nextDouble() * 4 + 2) * 40.0;
    } else if (direction == -1 && spike.rect.x <= leftBound) {
      spike.rect.x = leftBound;
      direction = 1;
      rightBound = spike.rect.x + (_movementRng!.nextDouble() * 4 + 2) * 40.0;
    }
  }
}

// Reverse Controls Trap: Permanently reverses the player's controls when stepping in the zone!
class ReverseControlsTrap extends TrollTrap {
  final RectD triggerArea;
  bool triggered = false;
  
  ReverseControlsTrap(this.triggerArea);

  @override
  void update(TrollEngine engine, double dt) {
    if (triggered) return;
    if (triggerArea.intersects(engine.player.rect)) {
      triggered = true;
      engine.invertedControls = !engine.invertedControls;
      // Spawn some purple particles to indicate curse!
      engine._spawnParticles(engine.player.rect.x + 15, engine.player.rect.y + 15, 30, const Color(0xFF9900FF));
    }
  }
}

// --- NEW C3 TRAPS ---

class JumpTriggeredDropTrap extends TrollTrap {
  final List<String> blockIds;
  List<TrollEntity> _blocks = [];
  bool triggered = false;
  
  JumpTriggeredDropTrap(this.blockIds);

  @override
  void update(TrollEngine engine, double dt) {
    if (_blocks.isEmpty) {
      _blocks = engine.entities.where((e) => blockIds.contains(e.id)).toList();
    }
    if (triggered) {
      for (var b in _blocks) {
        b.rect.y += 1000 * dt;
      }
      return;
    }
    
    // Check if player is standing on any of these blocks
    bool standingOnIt = false;
    RectD playerFoot = RectD(engine.player.rect.x + 5, engine.player.rect.bottom, engine.player.rect.w - 10, 2);
    for (var b in _blocks) {
      if (b.rect.intersects(playerFoot)) {
        standingOnIt = true;
        break;
      }
    }
    
    // If standing on it and tried to jump
    if (standingOnIt && engine.jumpBufferTimer > 0) {
      triggered = true;
      for (var b in _blocks) {
        b.isSolid = false;
      }
      engine.jumpBufferTimer = 0; 
      engine.coyoteTimer = 0;
    }
  }
}

class TrollSpringTrap extends TrollTrap {
  final String springId;
  TrollEntity? _spring;
  bool triggered = false;

  TrollSpringTrap(this.springId);

  @override
  void update(TrollEngine engine, double dt) {
    if (_spring == null) {
      _spring = engine.entities.where((e) => e.id == springId).firstOrNull;
    }
    var s = _spring;
    if (s == null) return;

    if (!triggered) {
      RectD expanded = RectD(s.rect.x - 2, s.rect.y - 2, s.rect.w + 4, s.rect.h + 4);
      if (expanded.intersects(engine.player.rect)) {
        triggered = true;
        s.type = TrollEntityType.spike;
        s.color = const Color(0xFFFF3366);
        s.rect = RectD(s.rect.x, s.rect.y + 20, s.rect.w, s.rect.h - 20); 
        s.isSolid = false;
      }
    }
  }
}

class AggressiveDoorTrap extends TrollTrap {
  final String doorId;
  TrollEntity? _door;
  bool triggered = false;

  AggressiveDoorTrap(this.doorId);

  @override
  void update(TrollEngine engine, double dt) {
    if (_door == null) {
      _door = engine.entities.where((e) => e.id == doorId).firstOrNull;
    }
    var d = _door;
    if (d == null) return;

    if (!triggered && (engine.player.rect.x - d.rect.x).abs() < 200) {
      triggered = true;
      d.type = TrollEntityType.spike; 
      d.color = const Color(0xFFFF3366);
    }

    if (triggered) {
      d.rect.x -= 800 * dt; 
    }
  }
}

class SpotlightToggleTrap extends TrollTrap {
  final String triggerId;
  TrollEntity? _trigger;
  bool triggered = false;

  SpotlightToggleTrap(this.triggerId);

  @override
  void update(TrollEngine engine, double dt) {
    if (_trigger == null) {
      _trigger = engine.entities.where((e) => e.id == triggerId).firstOrNull;
    }
    var t = _trigger;
    if (t == null) return;

    if (!triggered && (engine.player.rect.x - t.rect.x).abs() < 20) {
      triggered = true;
      engine.isSpotlightLevel = !engine.isSpotlightLevel;
      engine._spawnParticles(t.rect.x, t.rect.y + 20, 40, engine.isSpotlightLevel ? const Color(0xFF222222) : const Color(0xFFEEEEEE));
    }
  }
}

class TimeFreezeToggleTrap extends TrollTrap {
  final String triggerId;
  TrollEntity? _trigger;
  bool triggered = false;

  TimeFreezeToggleTrap(this.triggerId);

  @override
  void update(TrollEngine engine, double dt) {
    if (_trigger == null) {
      _trigger = engine.entities.where((e) => e.id == triggerId).firstOrNull;
    }
    var t = _trigger;
    if (t == null) return;

    if (!triggered && (engine.player.rect.x - t.rect.x).abs() < 20) {
      triggered = true;
      engine.isTimeFreezeLevel = !engine.isTimeFreezeLevel;
      engine._spawnParticles(t.rect.x, t.rect.y + 20, 40, const Color(0xFF00AAFF)); // Ice blue particles
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// NEW TRAPS (Phase 2)
// ──────────────────────────────────────────────────────────────────────────────

/// Solid platform that disappears after [showDuration] seconds and reappears
/// after [hideDuration] seconds. Loops forever. Player must cross in time.
class TimedPlatformTrap extends TrollTrap {
  final List<String> blockIds;
  final double showDuration; // ≥ 2.0 s  (enough for player to cross)
  final double hideDuration; // 3-5 s
  List<TrollEntity>? _blocks;
  double _elapsed = 0;
  bool _visible = true;

  // ── Public getters for the painter ─────────────────────────────────────
  bool get isCurrentlyVisible => _visible;
  double get elapsedVisible   => _visible ? _elapsed : 0.0;

  TimedPlatformTrap(this.blockIds,
      {this.showDuration = 2.5, this.hideDuration = 4.0})
      : assert(showDuration >= 2.0,
            'TimedPlatformTrap: showDuration must be >= 2.0 s');

  @override
  void update(TrollEngine engine, double dt) {
    _blocks ??= blockIds
        .map((id) =>
            engine.entities.where((e) => e.id == id).firstOrNull)
        .whereType<TrollEntity>()
        .toList();

    _elapsed += dt;
    if (_visible && _elapsed >= showDuration) {
      _elapsed = 0;
      _visible = false;
      for (var b in _blocks!) {
        b.isVisible = false;
        b.isSolid = false;
      }
    } else if (!_visible && _elapsed >= hideDuration) {
      _elapsed = 0;
      _visible = true;
      for (var b in _blocks!) {
        b.isVisible = true;
        b.isSolid = true;
      }
    }
  }
}

/// Blocks fall one group at a time like dominoes once player enters trigger.
class ChainFallTrap extends TrollTrap {
  final RectD triggerArea;
  final List<List<String>> chainGroups;
  final double delayBetween; // seconds between each group drop
  bool _triggered = false;
  int _currentGroup = 0;
  double _groupTimer = 0;
  List<List<TrollEntity>>? _groupEntities;

  ChainFallTrap(this.triggerArea, this.chainGroups,
      {this.delayBetween = 0.35});

  @override
  void update(TrollEngine engine, double dt) {
    _groupEntities ??= chainGroups
        .map((grp) => grp
            .map((id) =>
                engine.entities.where((e) => e.id == id).firstOrNull)
            .whereType<TrollEntity>()
            .toList())
        .toList();

    if (!_triggered && triggerArea.intersects(engine.player.rect)) {
      _triggered = true;
    }
    if (!_triggered || _currentGroup >= _groupEntities!.length) return;

    _groupTimer += dt;
    if (_groupTimer >= delayBetween) {
      _groupTimer = 0;
      for (var e in _groupEntities![_currentGroup]) {
        e.activePhysics = true;
        e.vy = engine.isGravityInverted ? -350 : 350;
        e.isSolid = false;
      }
      _currentGroup++;
    }
  }
}

/// Looks exactly like the real door but kills the player on contact.
class FakeDoorTrap extends TrollTrap {
  final String fakeDoorId;
  TrollEntity? _fd;
  bool _triggered = false;

  FakeDoorTrap(this.fakeDoorId);

  @override
  void update(TrollEngine engine, double dt) {
    _fd ??= engine.entities.where((e) => e.id == fakeDoorId).firstOrNull;
    if (_fd == null || _triggered) return;
    if (_fd!.rect.intersects(engine.player.rect)) {
      _triggered = true;
      _fd!.type = TrollEntityType.spike;
      _fd!.color = const Color(0xFFFF0033);
      engine._spawnParticles(
        _fd!.rect.x + _fd!.rect.w / 2,
        _fd!.rect.y + _fd!.rect.h / 2,
        50,
        const Color(0xFFFF0000),
      );
      engine.killPlayer();
    }
  }
}

/// A rectangular zone that temporarily flips gravity while player is inside.
class GravityFlipZoneTrap extends TrollTrap {
  final RectD zone;
  bool _inside = false;

  GravityFlipZoneTrap(this.zone);

  @override
  void update(TrollEngine engine, double dt) {
    final inNow = zone.intersects(engine.player.rect);
    if (inNow && !_inside) {
      _inside = true;
      engine.isGravityInverted = !engine.isGravityInverted;
      engine._spawnParticles(
          engine.player.rect.x + 15, engine.player.rect.y, 20,
          const Color(0xFF9900FF));
    } else if (!inNow && _inside) {
      _inside = false;
      engine.isGravityInverted = !engine.isGravityInverted;
    }
  }
}

/// A Thwomp that moves horizontally toward the player after triggering.
class MovingThwompTrap extends TrollTrap {
  final List<String> targetIds;
  List<TrollEntity>? _thwomps;
  bool _triggered = false;

  MovingThwompTrap(this.targetIds);

  @override
  void update(TrollEngine engine, double dt) {
    if (_thwomps == null) {
      _thwomps = [];
      for(var id in targetIds) {
        var e = engine.entities.where((e) => e.id == id).firstOrNull;
        if (e != null) _thwomps!.add(e);
      }
    }
    if (_thwomps!.isEmpty) return;

    var ref = _thwomps!.first;
    if (!_triggered && (engine.player.rect.x - ref.rect.x).abs() < 250) {
      _triggered = true;
    }
    if (_triggered) {
      double centerX = ref.rect.x + (ref.rect.w * 2); 
      final dir = (engine.player.rect.x + engine.player.rect.w/2 - centerX).sign;
      double moveDelta = dir * 180 * dt; 
      
      for(var b in _thwomps!) {
        b.rect.x += moveDelta;
        if (b.rect.intersects(engine.player.rect)) {
          engine.killPlayer();
        }
      }
    }
  }
}

/// A spike that teleports between [columns] positions every [interval] seconds.
class TeleportSpikeTrap extends TrollTrap {
  final List<double> xPositions; // world-x positions
  final double interval;
  TrollEntity? _spike;
  final String spikeId;
  double _timer = 0;
  int _idx = 0;

  TeleportSpikeTrap(this.spikeId, this.xPositions,
      {this.interval = 1.5});

  @override
  void update(TrollEngine engine, double dt) {
    _spike ??=
        engine.entities.where((e) => e.id == spikeId).firstOrNull;
    if (_spike == null) return;
    _timer += dt;
    if (_timer >= interval) {
      _timer = 0;
      _idx = (_idx + 1) % xPositions.length;
      _spike!.rect.x = xPositions[_idx];
    }
  }
}

// ---------------- Engine Core ----------------

class TrollEngine {
  static bool godMode = false;

  // ── Safety constants (never change these) ──────────────────────────────────
  static const int kMinGap        = 4;  // min blocks between any two traps
  static const int kDoorClearance = 10; // blocks after last trap → door
  static const int kStartCol      = 15; // player start safe zone

  TrollEngine({
    this.round = 1,
    this.maxRounds = 2,
    this.levelsPerMechanic = 3,
    this.mechanicOffset = 0,
    this.stageSeedOverride,
  }) {
    stageSeed = _seedForRound(round);
    rng = Random(stageSeed); // generation RNG only
    _loadLevel(round);
  }

  late Random rng;
  late int stageSeed;

  int round;
  // One attempt per stage; persistent player Lives are handled by EconomyManager.
  int roundHearts = 1;
  final int maxRounds;
  final int levelsPerMechanic;
  final int mechanicOffset;
  /// Optional global-stage seed. Used by host mode so reused Season 6 ideas
  /// still produce distinct deterministic layouts from their original stages.
  final int? stageSeedOverride;

  bool invertedControls = false;
  
  final double logicalWidth = 800;
  final double logicalHeight = 600;
  final double gs = 40.0; // Grid size
  double maxMapWidth = 800.0;
  double cameraX = 0;
  
  late TrollEntity player;
  List<TrollEntity> entities = [];
  List<TrollTrap> traps = [];
  List<Particle> particles = [];
  
  // Game State
  bool isDead = false;
  bool roundWon = false;
  bool allComplete = false;
  double transitionTimer = 0;
  double deathTimer = 0;
  
  // Score Tracking
  int totalScore = 0;
  // A stage has one gameplay attempt; the persistent Lives system is global.\n  int roundHearts = 1;
  int roundIndex = 0;
  int errorCount = 0;

  // Advanced Level Mechanics
  bool isSpotlightLevel = false;
  bool isWrapLevel = false;
  bool isTimeFreezeLevel = false;
  bool isLavaLevel = false;
  double lavaY = 800.0;
  bool isLowGravityLevel = false;
  bool isFlappyLevel = false;
  bool isTinyLevel = false;
  bool isDashLevel = false;
  bool hasDashed = false;
  bool isWindLevel = false;
  bool isIceLevel = false;
  bool isBlinkLevel = false;
  double blinkTimer = 0.0;
  bool isMirrorLevel = false;

  bool isGravityInverted = false;
  bool isBouncyLevel = false;
  bool isGhostLevel = false;
  bool isConveyorLevel = false;
  bool isChasedLevel = false;
  
  List<Offset> ghostHistory = [];
  double chaseWallX = -200;
  double chaseWallSpeed = 250;

  // Physics config
  final double gravity = 2500.0;
  final double moveAcceleration = 3500.0;
  final double friction = 2500.0;
  final double maxMoveSpeed = 380.0;
  final double jumpForce = -950.0; 
  
  // Input State
  bool movingLeft = false;
  bool movingRight = false;
  bool jumping = false;
  
  // Pro Mechanics
  double coyoteTimer = 0;
  double jumpBufferTimer = 0;
  bool _isGrounded = false;
  
  // Player Animation state
  double playerFaceDir = 1.0; 
  double playerScale = 1.0;

  int _seedForRound(int roundId) =>
      stageSeedOverride ?? (roundId + (mechanicOffset * 1000));

  // ── Level design helpers ─────────────────────────────────────────────────

  /// Trap counts: 5-level system (6/9/13/17/22) or 3-level (11/14/18)
  int _getTrapTarget(int roundId) {
    int local = (roundId - 1) % levelsPerMechanic + 1;
    if (levelsPerMechanic == 5) {
      if (local == 1) return 11;
      if (local == 2) return 13;
      if (local == 3) return 16;
      if (local == 4) return 18;
      return 24;
    }
    // Fallback for Season 11 (3 levels per mechanic)
    if (local == 1) return 11;
    if (local == 2) return 18;
    return 24;
  }

  /// Returns mechanic number (1-20) — offset applied for multi-season support
  int _getMechanicId(int roundId) =>
      ((roundId - 1) ~/ levelsPerMechanic) + 1 + mechanicOffset;

  /// Returns difficulty level:
  /// levelsPerMechanic=3 -> 1/2/3 (easy/medium/hard)
  /// levelsPerMechanic=5 -> mapped to 1(easy)/2(medium)/3(hard) based on 2-2-1 structure
  int _getDifficulty(int roundId) {
    int local = (roundId - 1) % levelsPerMechanic + 1;
    if (levelsPerMechanic == 5) {
      if (local == 1 || local == 2) return 1; // Easy
      if (local == 3 || local == 4) return 2; // Medium
      return 3;                               // Hard
    }
    return local; // 1, 2, 3 directly for Season 11
  }

  /// Random safe gap between traps: kMinGap to kMinGap+3
  String? lastTrap = null;
  int _gap([String? lastTrap, String? nextTrap]) {
    int baseGap = rng.nextInt(4) + kMinGap;
    
    // --- STAGE VALIDATOR LOGIC ---
    // Prevent impossible overlapping or overly tight timings
    if (lastTrap != null && nextTrap != null) {
      if ((lastTrap == 'Thwomp' || lastTrap == 'MThwomp') && nextTrap.contains('Spike')) {
        baseGap += 4; // Extra space after a thwomp before spikes
      }
      if (lastTrap == 'JDrop' && nextTrap == 'Thwomp') {
        baseGap += 5; // Impossible to dodge thwomp if floor just dropped
      }
      if (lastTrap == 'FFloor' && nextTrap == 'FFloor') {
        baseGap += 2; // Space out falling floors
      }
      if (lastTrap == 'RevCtrl' || nextTrap == 'RevCtrl') {
        baseGap += 6; // Give player time to adjust to reverse controls
      }
    }
    return baseGap;
  }


  void _spawnParticles(double px, double py, int count, Color c) {
    final rand = Random();
    for (int i = 0; i < count; i++) {
      double angle = rand.nextDouble() * 2 * pi;
      double speed = rand.nextDouble() * 400 + 100;
      particles.add(Particle(
        px, py,
        cos(angle) * speed, sin(angle) * speed,
        0.5 + rand.nextDouble() * 0.5,
        c
      ));
    }
  }

  void killPlayer() {
    if (isDead || roundWon) return;
    if (TrollEngine.godMode) return;
    isDead = true;
    errorCount++;
    _spawnParticles(player.rect.x + player.rect.w/2, player.rect.y + player.rect.h/2, 40, const Color(0xFF00FFCC));
    deathTimer = 1.0;
    roundHearts--;
  }

  bool completedAsWin = false; // true = player actually reached the door

  /// Restarts the exact current round after the player chooses Retry.
  /// The deterministic round seed is preserved for muscle-memory gameplay.
  void retryCurrentRound() {
    allComplete = false;
    completedAsWin = false;
    roundHearts = 1;
    stageSeed = _seedForRound(round);
    rng = Random(stageSeed);
    _loadLevel(round);
  }

  void nextRound({bool failed = false}) {
    if (failed) {
      if (roundHearts > 0) {
        // Retry same round, reseed for exact same layout (muscle memory)
        stageSeed = _seedForRound(round);
        rng = Random(stageSeed);
        _loadLevel(round);
      } else {
        allComplete = true;
        completedAsWin = false;
      }
    } else {
      totalScore += roundHearts * 250;
      roundIndex++;
      if (roundIndex >= maxRounds) {
        allComplete = true;
        completedAsWin = true;
      } else {
        roundHearts = 1;
        round++;
        stageSeed = _seedForRound(round);
        rng = Random(stageSeed);
        _loadLevel(round);
      }
    }
  }

  void _loadLevel(int id) {
    entities.clear();
    traps.clear();
    particles.clear();
    isDead = false;
    roundWon = false;
    invertedControls = false; // Reset controls on new round
    transitionTimer = 0;
    
    // ... rest of load level logic (will be handled by target content replacement)

    movingLeft = false;
    movingRight = false;
    jumping = false;
    playerFaceDir = 1.0;
    playerScale = 1.0;
    coyoteTimer = 0;
    jumpBufferTimer = 0;
    cameraX = 0;
    isSpotlightLevel = false;
    isWrapLevel = false;
    isTimeFreezeLevel = false;
    isLavaLevel = false;
    lavaY = 800;
    isLowGravityLevel = false;
    isFlappyLevel = false;
    isTinyLevel = false;
    isDashLevel = false;
    hasDashed = false;
    isWindLevel = false;
    isIceLevel = false;
    isBlinkLevel = false;
    blinkTimer = 0;
    isMirrorLevel = false;

    isGravityInverted = false;
    isBouncyLevel = false;
    isGhostLevel = false;
    isConveyorLevel = false;
    isChasedLevel = false;
    ghostHistory.clear();
    chaseWallX = -200;

    int mapCols = 180; // will be overridden per-difficulty below
    int currentCol = 15;
    List<List<String>> grid = List.generate(15, (r) => List.generate(mapCols, (c) => '.'));

    // Base floor at row 13 and 14
    for (int c = 0; c < mapCols; c++) {
      grid[13][c] = 'X';
      grid[14][c] = 'X';
    }
    
    grid[12][2] = 'P';

    void addThwomp(int col) {
      for (int c = col; c < col + 4; c++) {
        grid[4][c] = 'X';
        grid[5][c] = 'v';
      }
      traps.add(ThwompCeilingTrap(
        RectD((col - 3) * gs, 10 * gs, 10 * gs, 5 * gs), 
        List.generate(4, (i) => "b_4_${col+i}") + List.generate(4, (i) => "s_5_${col+i}"),
        7 * gs 
      ));
    }

    void addAppearingSpikes(int col) {
      int r = isGravityInverted ? 4 : 12;
      for (int c = col; c < col + 3; c++) {
        grid[r][c] = 'h';
      }
      traps.add(AppearingSpikesTrap(
        RectD((col - 3) * gs, (isGravityInverted ? 1 : 10) * gs, 9 * gs, 5 * gs), 
        List.generate(3, (i) => isGravityInverted ? "v_${r}_${col+i}" : "s_${r}_${col+i}")
      ));
    }
    
    void addAppearingWall(int col) {
      for (int r = 10; r <= 12; r++) {
        grid[r][col] = 'W'; // W for hidden wall
      }
      traps.add(AppearingWallTrap(
        RectD((col - 4) * gs, 10 * gs, 8 * gs, 5 * gs), 
        ["b_10_$col", "b_11_$col", "b_12_$col"]
      ));
    }

    void addFallingFloor(int col, int width, {bool immediate = false}) {
      int r1 = isGravityInverted ? 2 : 13;
      int r2 = isGravityInverted ? 3 : 14;
      double ty = isGravityInverted ? 0 : 10 * gs;
      traps.add(FallingPlatformTrap(
        immediate 
          ? RectD(col * gs, ty, width * gs, 5 * gs) 
          : RectD((col - 3) * gs, ty, 2 * gs, 5 * gs),
        List.generate(width, (i) => "b_${r1}_${col+i}") + List.generate(width, (i) => "b_${r2}_${col+i}")
      ));
    }

    void addRunningDoor(int distanceAfterTrap, int moveDistance) {
      int doorCol = currentCol + distanceAfterTrap;
      if (doorCol >= mapCols - 5) doorCol = mapCols - 6; // Safety bounds
      
      if (isGravityInverted) {
        grid[4][doorCol] = 'D'; // Place on ceiling
      } else {
        grid[12][doorCol] = 'D'; // Place on floor
      }
      
      traps.add(RunningDoorTrap(
        RectD((doorCol - 6) * gs, isGravityInverted ? 0 : 7 * gs, 6 * gs, 6 * gs), 
        "door", 
        moveDistance * gs
      ));
      
      for (int c = doorCol + 5; c < mapCols; c++) {
        if (!isGravityInverted) {
          grid[13][c] = '.';
          grid[14][c] = '.';
        } else {
          grid[2][c] = '.';
          grid[3][c] = '.';
        }
      }
    }

    // NEW C2 HELPERS
    void addFakeSolid(int col, int width) {
      int r1 = isGravityInverted ? 2 : 13;
      int r2 = isGravityInverted ? 3 : 14;
      for (int c = col; c < col + width; c++) {
        grid[r1][c] = 'X'; 
        grid[r2][c] = 'X'; 
      }
      traps.add(FakeSolidTrap(
        RectD(col * gs, (isGravityInverted ? 0 : 10) * gs, width * gs, 5 * gs), 
        List.generate(width, (i) => "b_${r1}_${col+i}") + List.generate(width, (i) => "b_${r2}_${col+i}")
      ));
    }

    void addReverseControls(int col) {
      traps.add(ReverseControlsTrap(
        RectD(col * gs, 8 * gs, 2 * gs, 8 * gs) // Trigger is tall so you can't jump over it
      ));
    }

    void addErraticSpike(int col) {
      int r = isGravityInverted ? 4 : 12;
      grid[r][col] = isGravityInverted ? 'v' : 's';
      traps.add(ErraticPatrolSpikeTrap(isGravityInverted ? "v_${r}_$col" : "s_${r}_$col", 220)); 
    }

    // NEW C3 HELPERS
    void addJumpTriggeredDrop(int col, int width) {
      for (int c = col; c < col + width; c++) {
        grid[13][c] = 'X'; 
        grid[14][c] = 'X'; 
      }
      traps.add(JumpTriggeredDropTrap(
        List.generate(width, (i) => "b_13_${col+i}") + List.generate(width, (i) => "b_14_${col+i}")
      ));
    }

    void addTrollSpring(int col) {
      grid[12][col] = 'S'; 
      traps.add(TrollSpringTrap("S_12_$col"));
    }

    void addAggressiveDoor(int col) {
      grid[11][col] = 'A'; // Aggressive door
      traps.add(AggressiveDoorTrap("A_11_$col"));
    }

    void addSpotlightToggle(int col) {
      grid[12][col] = 'L'; // Spotlight Trigger
      traps.add(SpotlightToggleTrap("L_12_$col"));
    }

    void addTimeFreezeToggle(int col) {
      grid[12][col] = 'T'; // Time Freeze Trigger
      traps.add(TimeFreezeToggleTrap("T_12_$col"));
    }

    // ── NEW Phase 2 helpers ────────────────────────────────────────────────

    void addTimedPlatform(int col, int width) {
      for (int c = col; c < col + width; c++) {
        grid[13][c] = 'X';
        grid[14][c] = 'X';
      }
      traps.add(TimedPlatformTrap(
        List.generate(width, (i) => 'b_13_${col + i}') +
            List.generate(width, (i) => 'b_14_${col + i}'),
        showDuration: 2.5,
        hideDuration: 4.0,
      ));
    }

    void addChainFall(int col, int groups) {
      const groupWidth = 3;
      final chainGroups = <List<String>>[];
      for (int g = 0; g < groups; g++) {
        final gc = col + g * (groupWidth + 1);
        final group = <String>[];
        for (int c = gc; c < gc + groupWidth && gc + groupWidth < mapCols; c++) {
          grid[13][c] = 'X';
          grid[14][c] = 'X';
          group.addAll(['b_13_$c', 'b_14_$c']);
        }
        if (group.isNotEmpty) chainGroups.add(group);
      }
      if (chainGroups.isEmpty) return;
      traps.add(ChainFallTrap(
        RectD((col - 4) * gs, 8 * gs, 4 * gs, 8 * gs),
        chainGroups,
      ));
    }

    void addFakeDoor(int col) {
      if (col >= mapCols) return;
      grid[11][col] = 'A'; // reuse 'A' char → gold door appearance
      final fid = 'A_11_$col';
      entities.add(TrollEntity(
        id: fid,
        type: TrollEntityType.door,
        rect: RectD(col * gs, 11 * gs - 20, gs, gs + 20),
        color: const Color(0xFFFFD700),
        isSolid: false,
      ));
      traps.add(FakeDoorTrap(fid));
    }

    void addGravFlipZone(int col, int width) {
      traps.add(GravityFlipZoneTrap(
        RectD(col * gs, 4 * gs, width * gs, 9 * gs),
      ));
    }

    void addMovingThwomp(int col) {
      if (col >= mapCols - 4) return;
      int r1 = isGravityInverted ? 11 : 7;
      int r2 = isGravityInverted ? 12 : 8;
      for (int c = col; c < col + 4; c++) {
        grid[r1][c] = 'X'; 
        grid[r2][c] = 'X';
      }
      traps.add(MovingThwompTrap(
        List.generate(4, (i) => "b_${r1}_${col+i}") + List.generate(4, (i) => "b_${r2}_${col+i}")
      ));
    }

    void addTeleportSpike(int col) {
      if (col >= mapCols - 12) return;
      grid[12][col] = 's';
      final sid = 's_12_$col';
      traps.add(TeleportSpikeTrap(
        sid,
        [col * gs, (col + 5) * gs, (col + 10) * gs],
      ));
    }

    void addDoubleSpike(int col) {
      if (col >= mapCols) return;
      grid[12][col] = 's'; // floor spike
      grid[4][col]  = 'v'; // ceiling spike (inverted)
    }

    // Unified trap dispatcher — called by the new generator
    void placeTrap(String type, int col) {
      switch (type) {
        case 'ASpike':  addAppearingSpikes(col); break;
        case 'Thwomp':  addThwomp(col); break;
        case 'FFloor':  addFallingFloor(col, 3 + rng.nextInt(2)); break;
        case 'ESpike':  addErraticSpike(col); break;
        case 'FSolid':  addFakeSolid(col, 3 + rng.nextInt(2)); break;
        case 'JDrop':   addJumpTriggeredDrop(col, 4 + rng.nextInt(2)); break;
        case 'Spring':  addTrollSpring(col); break;
        case 'AggDoor': addAggressiveDoor(col); break;
        case 'SpotTog': addSpotlightToggle(col); break;
        case 'TimeTog': addTimeFreezeToggle(col); break;
        case 'RevCtrl': addReverseControls(col); break;
        case 'Timed':   addTimedPlatform(col, 3 + rng.nextInt(2)); break;
        case 'Chain':   addChainFall(col, 2); break;
        case 'FDoor':   addFakeDoor(col); break;
        case 'GFlip':   addGravFlipZone(col, 3); break;
        case 'MThwomp': addMovingThwomp(col); break;
        case 'TSpy':    addTeleportSpike(col); break;
        case '2Spike':  addDoubleSpike(col); break;
        case 'Spike':   { if (col < mapCols) grid[isGravityInverted ? 4 : 12][col] = isGravityInverted ? 'v' : 's'; } break;
      }
    }

    // ── New generator: build trap sequence and execute ─────────────────────
    // ignore: unused_element
    void runRecipe(List<String> pool, {int startCol = 15, bool addDoor = true}) {
      currentCol = startCol;
      pool.shuffle(rng);
      lastTrap = null;
      for (final trapType in pool) {
        if (currentCol + 15 >= mapCols) break; // safety: don't overflow grid
        placeTrap(trapType, currentCol);
        currentCol += _gap(lastTrap, trapType) + 5; // gap + trap footprint
        lastTrap = trapType;
      }
      if (addDoor) addRunningDoor(kDoorClearance, 0);
    }

    // Build recipe pool: [type × count, ...]
    // ignore: unused_element
    List<String> recipe(Map<String, int> counts) {
      final pool = <String>[];
      counts.forEach((t, n) {
        for (int i = 0; i < n; i++) {
          pool.add(t);
        }
      });
      return pool;
    }


    final int diff = _getDifficulty(id);

    // Season 6 mashup builder: every Season 6 group combines mechanics already
    // present in Seasons 1-5. It never introduces a new stage identity.
    void runMashup({
      bool spotlight = false,
      bool wrap = false,
      bool freeze = false,
      bool inverted = false,
      bool bouncy = false,
      bool ghost = false,
      bool conveyor = false,
      bool chase = false,
      bool lava = false,
      bool lowGravity = false,
      bool flappy = false,
      bool tiny = false,
      bool dash = false,
      bool wind = false,
      bool ice = false,
      bool blink = false,
      bool mirror = false,
      Map<String, int>? easy,
      Map<String, int>? medium,
      Map<String, int>? hard,
    }) {
      isSpotlightLevel = spotlight;
      isWrapLevel = wrap;
      isTimeFreezeLevel = freeze;
      isGravityInverted = inverted;
      isBouncyLevel = bouncy;
      isGhostLevel = ghost;
      isConveyorLevel = conveyor;
      isChasedLevel = chase;
      isLavaLevel = lava;
      isLowGravityLevel = lowGravity;
      isFlappyLevel = flappy;
      isTinyLevel = tiny;
      isDashLevel = dash;
      isWindLevel = wind;
      isIceLevel = ice;
      isBlinkLevel = blink;
      isMirrorLevel = mirror;

      if (chase) {
        chaseWallX = -200;
        chaseWallSpeed = 210 + diff * 15;
      }

      // Geometry for the environmental mechanics is intentionally kept simple
      // and deterministic so the same stage seed always produces the same run.
      if (conveyor) {
        for (int c = 10; c < mapCols; c++) {
          final goRight = c % 14 < 7;
          grid[13][c] = goRight ? '>' : '<';
          grid[14][c] = goRight ? '>' : '<';
        }
      }

      if (inverted) {
        for (int c = 0; c < mapCols; c++) {
          grid[2][c] = 'X';
          grid[3][c] = 'X';
          grid[13][c] = '.';
          grid[14][c] = '.';
        }
        grid[12][2] = 'P';
      }

      if (flappy || lava) {
        for (int c = 8; c < mapCols; c++) {
          grid[13][c] = '.';
          grid[14][c] = '.';
        }
        if (lava) lavaY = 700;
      }

      runRecipe(recipe(diff == 1
          ? (easy ?? {'Spike': 4, 'FFloor': 3, 'ASpike': 3})
          : diff == 2
              ? (medium ?? {'Spike': 4, 'FFloor': 4, 'ESpike': 3, 'ASpike': 3})
              : (hard ?? {'Spike': 5, 'FFloor': 4, 'ESpike': 4, 'ASpike': 3, 'Thwomp': 2})));
    }

    void addInvisibleBlocks(int col, int width) {
      for (int c = col; c < col + width && c < mapCols; c++) {
        grid[10][c] = 'b';
        if (c + 1 < mapCols) grid[11][c] = 'b';
      }
    }

    // ignore: unused_local_variable
    final int mechId = _getMechanicId(id);
    // Map width scales with difficulty:
    // 5-level: 160/200/240/280/320   3-level: 200/260/320
    // diff is now always 1, 2, or 3
    mapCols = (diff == 1) ? 200 : (diff == 2) ? 260 : 320;

    // Regenerate grid with new column count
    grid = List.generate(15, (r) => List.generate(mapCols, (c) => '.'));
    for (int c = 0; c < mapCols; c++) {
      grid[13][c] = 'X';
      grid[14][c] = 'X';
    }
    grid[12][2] = 'P';

    // ══════════════════════════════════════════════════════════════════════════
    // NEW RECIPE SYSTEM — 11/14/18 traps, seeded random placement
    // ══════════════════════════════════════════════════════════════════════════

    if (mechId == 1) {
      // ── Appearing Spikes ──────────────────────────────────────────────────
      runRecipe(recipe(diff == 1
          ? {'ASpike': 6, 'Spike': 2, 'FFloor': 3}
          : diff == 2
              ? {'ASpike': 5, 'Thwomp': 3, 'FFloor': 3, 'ESpike': 3}
              : {'ASpike': 5, 'Thwomp': 4, 'FFloor': 3, 'ESpike': 3, 'Timed': 3}));

    } else if (mechId == 2) {
      // ── Erratic Spike + Thwomp ────────────────────────────────────────────
      runRecipe(recipe(diff == 1
          ? {'ESpike': 5, 'Thwomp': 3, 'FSolid': 3}
          : diff == 2
              ? {'ESpike': 5, 'Thwomp': 4, 'FSolid': 3, 'ASpike': 2}
              : {'ESpike': 5, 'Thwomp': 4, 'FSolid': 4, 'ASpike': 2, 'MThwomp': 3}));

    } else if (mechId == 3) {
      // ── Jump Drop Floor ───────────────────────────────────────────────────
      runRecipe(recipe(diff == 1
          ? {'JDrop': 6, 'Spike': 3, 'ASpike': 2}
          : diff == 2
              ? {'JDrop': 5, 'Spring': 3, 'ASpike': 3, 'ESpike': 3}
              : {'JDrop': 5, 'Spring': 3, 'ASpike': 3, 'Chain': 4, 'ESpike': 3}));

    } else if (mechId == 4) {
      // ── Spotlight ─────────────────────────────────────────────────────────
      isSpotlightLevel = diff >= 2;
      isWrapLevel = diff == 3;
      runRecipe(recipe(diff == 1
          ? {'SpotTog': 4, 'Thwomp': 4, 'ASpike': 3}
          : diff == 2
              ? {'SpotTog': 4, 'Thwomp': 3, 'ESpike': 3, 'FFloor': 2, 'ASpike': 2}
              : {'SpotTog': 5, 'ESpike': 4, 'Thwomp': 3, 'FFloor': 3, 'TSpy': 3}));

    } else if (mechId == 5) {
      // ── Time Freeze ───────────────────────────────────────────────────────
      isTimeFreezeLevel = diff >= 2;
      runRecipe(recipe(diff == 1
          ? {'TimeTog': 4, 'Thwomp': 4, 'FSolid': 3}
          : diff == 2
              ? {'TimeTog': 4, 'Thwomp': 3, 'FSolid': 3, 'ASpike': 2, 'FFloor': 2}
              : {'TimeTog': 4, 'Thwomp': 4, 'FSolid': 3, 'ASpike': 3, 'RevCtrl': 2, 'TSpy': 2}));

    } else if (mechId == 6) {
      // ── Inverted Gravity ──────────────────────────────────────────────────
      isGravityInverted = true;
      for (int c = 0; c < mapCols; c++) {
        grid[2][c] = 'X'; grid[3][c] = 'X';
        grid[13][c] = '.'; grid[14][c] = '.';
      }
      grid[12][2] = 'P';
      runRecipe(recipe(diff == 1
          ? {'ESpike': 6, 'FSolid': 3, 'FFloor': 2}
          : diff == 2
              ? {'ESpike': 5, 'FSolid': 4, 'ASpike': 3, 'GFlip': 2}
              : {'ESpike': 5, 'FSolid': 4, 'ASpike': 3, '2Spike': 3, 'GFlip': 3}));

    } else if (mechId == 7) {
      // ── Bouncy ───────────────────────────────────────────────────────────
      isBouncyLevel = true;
      runRecipe(recipe(diff == 1
          ? {'Thwomp': 5, 'JDrop': 4, 'Spike': 2}
          : diff == 2
              ? {'Thwomp': 4, 'JDrop': 4, 'ESpike': 3, 'ASpike': 3}
              : {'Thwomp': 5, 'JDrop': 4, 'ESpike': 3, 'MThwomp': 3, 'Chain': 3}));

    } else if (mechId == 8) {
      // ── Ghost Shadow ──────────────────────────────────────────────────────
      isGhostLevel = true;
      runRecipe(recipe(diff == 1
          ? {'FFloor': 5, 'ASpike': 4, 'ESpike': 2}
          : diff == 2
              ? {'FFloor': 4, 'ASpike': 3, 'FSolid': 3, 'ESpike': 2, 'FDoor': 1, 'Thwomp': 1}
              : {'FFloor': 5, 'ASpike': 4, 'FSolid': 3, 'FDoor': 2, 'Chain': 2, 'ESpike': 2}));

    } else if (mechId == 9) {
      // ── Conveyor Belt ─────────────────────────────────────────────────────
      isConveyorLevel = true;
      for (int c = 10; c < mapCols; c++) {
        final goRight = diff == 3 || (c % 15 < 7);
        grid[13][c] = goRight ? '>' : '<';
        grid[14][c] = goRight ? '>' : '<';
      }
      runRecipe(recipe(diff == 1
          ? {'Thwomp': 5, 'ESpike': 4, 'ASpike': 2}
          : diff == 2
              ? {'Thwomp': 4, 'ESpike': 4, 'MThwomp': 3, 'ASpike': 3}
              : {'Thwomp': 5, 'ESpike': 4, 'AggDoor': 1, 'MThwomp': 4, 'FFloor': 2, 'ASpike': 2}));

    } else if (mechId == 10) {
      // ── Wall Chase ────────────────────────────────────────────────────────
      isChasedLevel = true;
      chaseWallX = -200;
      chaseWallSpeed = 220 + diff * 15;
      runRecipe(recipe(diff == 1
          ? {'FSolid': 4, 'Thwomp': 4, 'ESpike': 3}
          : diff == 2
              ? {'FSolid': 4, 'Thwomp': 4, 'ESpike': 3, 'MThwomp': 3}
              : {'FSolid': 5, 'Thwomp': 4, 'ESpike': 3, 'Chain': 3, 'MThwomp': 3}));

    } else if (mechId == 11) {
      // ── Lava Rising — platform-jump layout ───────────────────────────────
      isLavaLevel = true;
      lavaY = 700;
      for (int c = 0; c < mapCols; c++) {
        grid[13][c] = '.'; grid[14][c] = '.';
      }
      grid[12][2] = 'P';
      for (int c = 0; c < 6; c++) { grid[13][c] = 'X'; grid[14][c] = 'X'; }
      currentCol = 6;
      final platformCount = _getTrapTarget(id);
      for (int i = 0; i < platformCount; i++) {
        final gap = rng.nextInt(2) + 2;
        final w   = rng.nextInt(2) + 2;
        final hOff = rng.nextInt(3);
        currentCol += gap;
        final row = 13 - hOff;
        for (int c = currentCol; c < currentCol + w && c < mapCols; c++) {
          grid[row][c] = 'X';
          if (row + 1 < 15) grid[row + 1][c] = 'X';
        }
        if (diff >= 2 && i % 3 == 0 && currentCol + 1 < mapCols) {
          grid[row - 1][currentCol] = 's';
        }
        if (diff == 3 && i % 4 == 1 && currentCol + 2 < mapCols) {
          addErraticSpike(currentCol + 1);
        }
        currentCol += w;
      }
      for (int c = currentCol + 2; c < currentCol + 12 && c < mapCols; c++) {
        grid[13][c] = 'X'; grid[14][c] = 'X';
      }
      addRunningDoor(5, 0);

    } else if (mechId == 12) {
      // ── Low Gravity ───────────────────────────────────────────────────────
      isLowGravityLevel = true;
      final pool12 = recipe(diff == 1
          ? {'FFloor': 4, 'ESpike': 4, 'ASpike': 3}
          : diff == 2
              ? {'FFloor': 3, 'ESpike': 4, 'Thwomp': 4, 'ASpike': 3}
              : {'FFloor': 3, 'ESpike': 4, 'Thwomp': 3, 'Timed': 3, '2Spike': 2, 'ASpike': 3});
      pool12.shuffle(rng);
      currentCol = 15;
      for (final t in pool12) {
        if (currentCol + 20 >= mapCols) break;
        final gapSize = diff == 1 ? 8 : diff == 2 ? 10 : 12;
        for (int i = 0; i < gapSize && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = '.'; grid[14][currentCol + i] = '.';
        }
        currentCol += gapSize;
        for (int i = 0; i < 4 && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = 'X';
        }
        placeTrap(t, currentCol);
          currentCol += _gap(lastTrap, t) + 4;
          lastTrap = t;
      }
      addRunningDoor(kDoorClearance, 0);

    } else if (mechId == 13) {
      // ── Flappy Mode — pipe-gap layout ────────────────────────────────────
      isFlappyLevel = true;
      for (int c = 10; c < mapCols; c++) { grid[13][c] = '.'; grid[14][c] = '.'; }
      final obstacleCount = _getTrapTarget(id);
      currentCol = 15;
      final gapPositions13 = [4, 5, 6, 7, 8, 9, 10];
      final gapSize13 = diff == 3 ? 4 : 5;
      for (int i = 0; i < obstacleCount; i++) {
        if (currentCol + 2 >= mapCols) break;
        final gapRow = gapPositions13[rng.nextInt(gapPositions13.length)];
        for (int r = 2; r < gapRow && r < 15; r++) grid[r][currentCol] = 'X';
        for (int r = gapRow + gapSize13; r < 13; r++) grid[r][currentCol] = 'X';
        if (diff >= 2 && i % 3 == 0 && gapRow < 14) grid[gapRow][currentCol] = 's';
        currentCol += rng.nextInt(4) + 8;
      }
      for (int c = currentCol; c < currentCol + 8 && c < mapCols; c++) {
        grid[13][c] = 'X'; grid[14][c] = 'X';
      }
      addRunningDoor(5, 0);

    } else if (mechId == 14) {
      // ── Tiny Character ────────────────────────────────────────────────────
      isTinyLevel = true;
      final pool14 = recipe(diff == 1
          ? {'ASpike': 4, 'FFloor': 4, 'Spike': 3}
          : diff == 2
              ? {'ASpike': 4, 'FFloor': 3, 'Thwomp': 3, 'ESpike': 2, 'Spike': 2}
              : {'ASpike': 5, 'FFloor': 3, 'Thwomp': 3, 'ESpike': 3, 'FSolid': 2, 'Spike': 2});
      pool14.shuffle(rng);
      currentCol = 15;
      int wallInterval = 0;
      for (final t in pool14) {
        if (currentCol + 10 >= mapCols) break;
        wallInterval++;
        if (wallInterval % 3 == 0) {
          for (int r = 10; r <= 12; r++) grid[r][currentCol] = 'X';
          grid[12][currentCol] = '.';
          currentCol += 4;
        }
        placeTrap(t, currentCol);
          currentCol += _gap(lastTrap, t) + 4;
          lastTrap = t;
      }
      addRunningDoor(kDoorClearance, 0);

    } else if (mechId == 15) {
      // ── Dash Mode ────────────────────────────────────────────────────────
      isDashLevel = true;
      final gapW15 = diff == 1 ? 9 : diff == 2 ? 11 : 13;
      final pool15 = recipe(diff == 1
          ? {'Spike': 4, 'FFloor': 4, 'ASpike': 3}
          : diff == 2
              ? {'Spike': 4, 'FFloor': 4, 'ASpike': 3, 'ESpike': 3}
              : {'Spike': 5, 'FFloor': 5, 'ASpike': 3, 'ESpike': 3, 'AggDoor': 1, 'MThwomp': 1});
      pool15.shuffle(rng);
      currentCol = 15;
      for (final t in pool15) {
        if (currentCol + gapW15 + 15 >= mapCols) break;
        for (int i = 0; i < gapW15 && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = '.'; grid[14][currentCol + i] = '.';
        }
        currentCol += gapW15;
        for (int i = 0; i < 10 && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = 'X';
        }
        placeTrap(t, currentCol);
          currentCol += _gap(lastTrap, t) + 10;
          lastTrap = t;
      }
      addRunningDoor(kDoorClearance, 0);

    } else if (mechId == 16) {
      // ── Wind ─────────────────────────────────────────────────────────────
      isWindLevel = true;
      final pool16 = recipe(diff == 1
          ? {'Spike': 3, 'JDrop': 5, 'ASpike': 3}
          : diff == 2
              ? {'Spike': 3, 'JDrop': 5, 'ESpike': 4, 'ASpike': 2}
              : {'Spike': 4, 'JDrop': 5, 'ESpike': 4, 'Thwomp': 2, 'MThwomp': 2, 'ASpike': 1});
      pool16.shuffle(rng);
      currentCol = 15;
      for (final t in pool16) {
        if (currentCol + 10 >= mapCols) break;
        final gapW = rng.nextInt(2) + 2;
        for (int i = 0; i < gapW && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = '.'; grid[14][currentCol + i] = '.';
        }
        currentCol += gapW;
        for (int i = 0; i < 4 && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = 'X';
        }
        placeTrap(t, currentCol);
          currentCol += _gap(lastTrap, t) + 4;
          lastTrap = t;
      }
      addRunningDoor(kDoorClearance, 0);

    } else if (mechId == 17) {
      // ── Ice Floor ────────────────────────────────────────────────────────
      isIceLevel = true;
      final pool17 = recipe(diff == 1
          ? {'Timed': 4, 'Spike': 4, 'FFloor': 3}
          : diff == 2
              ? {'Timed': 4, 'Spike': 4, 'ESpike': 3, 'FFloor': 3}
              : {'Timed': 4, 'Spike': 5, 'ESpike': 4, 'FFloor': 3, 'Chain': 2});
      pool17.shuffle(rng);
      currentCol = 15;
      for (final t in pool17) {
        if (currentCol + 14 >= mapCols) break;
        final gapW = rng.nextInt(2) + 3;
        for (int i = 0; i < gapW && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = '.'; grid[14][currentCol + i] = '.';
        }
        currentCol += gapW;
        for (int i = 0; i < 8 && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = 'X';
        }
        placeTrap(t, currentCol);
          currentCol += _gap(lastTrap, t) + 8;
          lastTrap = t;
      }
      addRunningDoor(kDoorClearance, 0);

    } else if (mechId == 18) {
      // ── Screen Blink ─────────────────────────────────────────────────────
      isBlinkLevel = true;
      final pool18 = recipe(diff == 1
          ? {'Spike': 3, 'TSpy': 4, 'FFloor': 4}
          : diff == 2
              ? {'Spike': 4, 'TSpy': 4, 'ESpike': 3, 'FFloor': 3}
              : {'Spike': 4, 'TSpy': 5, 'ESpike': 4, 'FDoor': 2, 'Thwomp': 2, 'FFloor': 1});
      pool18.shuffle(rng);
      currentCol = 15;
      for (final t in pool18) {
        if (currentCol + 10 >= mapCols) break;
        final gapW = rng.nextInt(2) + 2;
        for (int i = 0; i < gapW && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = '.'; grid[14][currentCol + i] = '.';
        }
        currentCol += gapW;
        for (int i = 0; i < 6 && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = 'X';
        }
        placeTrap(t, currentCol);
          currentCol += _gap(lastTrap, t) + 6;
          lastTrap = t;
      }
      addRunningDoor(kDoorClearance, 0);

    } else if (mechId == 19) {
      // ── Mirror Controls ───────────────────────────────────────────────────
      isMirrorLevel = true;
      final pool19 = recipe(diff == 1
          ? {'Spike': 4, 'FFloor': 4, 'RevCtrl': 3}
          : diff == 2
              ? {'Spike': 4, 'FFloor': 3, 'RevCtrl': 3, 'ESpike': 4}
              : {'Spike': 4, 'FFloor': 3, 'RevCtrl': 4, 'ESpike': 4, '2Spike': 3, 'FDoor': 2});
      pool19.shuffle(rng);
      currentCol = 15;
      for (final t in pool19) {
        if (currentCol + 10 >= mapCols) break;
        final gapW = rng.nextInt(2) + 2;
        for (int i = 0; i < gapW && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = '.'; grid[14][currentCol + i] = '.';
        }
        currentCol += gapW;
        for (int i = 0; i < 5 && currentCol + i < mapCols; i++) {
          grid[13][currentCol + i] = 'X';
        }
        placeTrap(t, currentCol);
          currentCol += _gap(lastTrap, t) + 5;
          lastTrap = t;
      }
      addRunningDoor(kDoorClearance, 0);

    } else if (mechId == 20) {
      // ── mechId == 20: Absolute Chaos ─────────────────────────────────────
      isBouncyLevel = true;
      isGhostLevel  = diff >= 2;
      isWindLevel   = diff >= 2;
      isBlinkLevel  = diff == 3;
      isChasedLevel = diff == 3;
      if (diff == 3) { chaseWallX = -200; chaseWallSpeed = 200; }
      runRecipe(recipe(diff == 1
          ? {'ASpike': 2, 'Thwomp': 3, 'ESpike': 2, 'FSolid': 2, 'Chain': 1, 'FDoor': 1}
          : diff == 2
              ? {'ASpike': 2, 'Thwomp': 3, 'ESpike': 3, 'FSolid': 2, 'Chain': 2, 'FDoor': 2, 'MThwomp': 2, 'Timed': 2}
              : {'ASpike': 2, 'Thwomp': 3, 'ESpike': 3, 'FSolid': 2, 'Chain': 2, 'FDoor': 3,
                 'MThwomp': 2, 'Timed': 2, 'TSpy': 2, '2Spike': 2, 'JDrop': 2, 'RevCtrl': 1}));

    } else if (mechId == 21) {
      // S6 Group 1 — Invisible Blocks: hidden geometry remains the core idea,
      // but every difficulty also uses supporting traps for a complete route.
      final hiddenWidth = diff == 1 ? 3 : diff == 2 ? 4 : 5;
      currentCol = 18;
      for (int i = 0; i < (diff == 1 ? 5 : diff == 2 ? 6 : 8); i++) {
        addInvisibleBlocks(currentCol, hiddenWidth);
        if (diff >= 2 && i.isEven && currentCol + hiddenWidth < mapCols) {
          grid[12][currentCol + hiddenWidth] = 's';
        }
        currentCol += hiddenWidth + (diff == 1 ? 6 : 5);
      }
      runRecipe(recipe(diff == 1
          ? {'FSolid': 3, 'Spike': 3, 'FFloor': 2, 'ASpike': 2}
          : diff == 2
              ? {'FSolid': 3, 'ESpike': 3, 'ASpike': 3, 'FFloor': 2, 'Thwomp': 2}
              : {'FSolid': 4, 'ESpike': 3, 'ASpike': 3, 'FFloor': 2, 'Thwomp': 2, 'Chain': 2}));

    } else if (mechId == 22) {
      // S6 Group 2 — Shifting Floors: moving/falling floor sections are the
      // identity, supported by different secondary traps per difficulty.
      runRecipe(recipe(diff == 1
          ? {'FFloor': 4, 'Spike': 3, 'Timed': 2, 'ASpike': 2}
          : diff == 2
              ? {'FFloor': 4, 'ESpike': 3, 'JDrop': 3, 'ASpike': 2, 'Thwomp': 2}
              : {'FFloor': 5, 'ESpike': 3, 'JDrop': 3, 'Chain': 2, 'MThwomp': 2, 'TSpy': 2}));

    } else if (mechId == 23) {
      // S6 Group 3 — Runaway Door: the door must move, but the route is not
      // a wall of repeated spikes. Supporting traps are deliberately varied.
      final moveDistance = diff == 1 ? 3 : diff == 2 ? 5 : 8;
      runRecipe(recipe(diff == 1
          ? {'Spike': 4, 'FFloor': 2, 'ASpike': 2, 'Timed': 2, 'AggDoor': 1}
          : diff == 2
              ? {'Spike': 4, 'FFloor': 2, 'ESpike': 3, 'ASpike': 2, 'MThwomp': 2, 'AggDoor': 1}
              : {'Spike': 4, 'FFloor': 3, 'ESpike': 3, 'ASpike': 2, 'MThwomp': 2, 'TSpy': 2, 'FDoor': 1}),
        addDoor: false);
      addRunningDoor(kDoorClearance, moveDistance);

    } else if (mechId == 24) {
      // S6 Group 4 — Friendly Spike: visual/friendly spikes are retained as
      // the signature, while the actual route uses varied hazards.
      final friendCount = diff == 1 ? 3 : diff == 2 ? 5 : 6;
      currentCol = 18;
      for (int i = 0; i < friendCount; i++) {
        if (currentCol < mapCols) {
          grid[11][currentCol] = 'h';
          currentCol += diff == 1 ? 7 : 6;
        }
      }
      runRecipe(recipe(diff == 1
          ? {'Spike': 3, 'Spring': 3, 'ASpike': 2, 'FFloor': 2, 'ESpike': 1}
          : diff == 2
              ? {'Spike': 3, 'Spring': 3, 'ESpike': 3, 'FFloor': 2, 'JDrop': 2, 'ASpike': 2}
              : {'Spike': 3, 'Spring': 3, 'ESpike': 3, 'FFloor': 2, 'JDrop': 2, 'MThwomp': 2, 'Chain': 2}));

    } else if (mechId == 25) {
      // S6 Group 5 — Timed Platforms: timed platforms stay the main mechanic,
      // with secondary traps creating a complete and varied final group.
      isIceLevel = false;
      currentCol = 18;
      final platformWidth = diff == 1 ? 5 : diff == 2 ? 4 : 3;
      final platformCount = diff == 1 ? 9 : diff == 2 ? 12 : 15;

      for (int i = 0; i < platformCount; i++) {
        if (currentCol + platformWidth + 8 >= mapCols) break;

        for (int j = 0; j < platformWidth; j++) {
          grid[13][currentCol + j] = 'X';
          grid[14][currentCol + j] = 'X';
        }

        traps.add(TimedPlatformTrap(
          List.generate(
            platformWidth,
            (j) => 'b_13_' + (currentCol + j).toString(),
          ) +
              List.generate(
                platformWidth,
                (j) => 'b_14_' + (currentCol + j).toString(),
              ),
          showDuration: diff == 1 ? 3.2 : diff == 2 ? 2.6 : 2.1,
          hideDuration: diff == 1 ? 2.8 : diff == 2 ? 2.4 : 2.0,
        ));

        if (diff >= 2 && i.isOdd && currentCol + platformWidth + 2 < mapCols) {
          grid[12][currentCol + platformWidth + 2] = 's';
        }

        // Add secondary hazards between timed sections without replacing the
        // timed-platform identity of the stage.
        if (i % (diff == 1 ? 4 : 3) == 0) {
          final supportCol = currentCol + platformWidth + 2;
          if (supportCol + 4 < mapCols) {
            placeTrap(diff == 1
                ? 'Spike'
                : diff == 2
                    ? (i.isEven ? 'ESpike' : 'FFloor')
                    : (i.isEven ? 'MThwomp' : 'TSpy'),
                supportCol);
          }
        }

        currentCol += platformWidth + (diff == 1 ? 5 : diff == 2 ? 4 : 3);
      }

      for (int c = currentCol; c < currentCol + 10 && c < mapCols; c++) {
        grid[13][c] = 'X';
        grid[14][c] = 'X';
      }
      addRunningDoor(5, 0);

    } else if (mechId == 26) {
      runMashup(bouncy: true, easy: {'JDrop': 4, 'Spike': 3, 'FFloor': 3},
          medium: {'JDrop': 5, 'ESpike': 3, 'FFloor': 3, 'Thwomp': 2},
          hard: {'JDrop': 5, 'ESpike': 4, 'Chain': 3, 'Thwomp': 3});

    } else if (mechId == 27) {
      runMashup(spotlight: true, conveyor: true, easy: {'SpotTog': 3, 'Spike': 3, 'Thwomp': 3},
          medium: {'SpotTog': 4, 'ESpike': 3, 'FFloor': 2, 'Thwomp': 3},
          hard: {'SpotTog': 4, 'ESpike': 4, 'TSpy': 3, 'Thwomp': 3});

    } else if (mechId == 28) {
      runMashup(wrap: true, lava: true, easy: {'Spike': 3, 'FFloor': 2, 'ASpike': 2},
          medium: {'Spike': 4, 'FFloor': 3, 'ESpike': 2, 'ASpike': 2},
          hard: {'Spike': 5, 'FFloor': 3, 'ESpike': 3, '2Spike': 2});

    } else if (mechId == 29) {
      runMashup(inverted: true, flappy: true, easy: {'ESpike': 4, 'FSolid': 2, 'Spike': 2},
          medium: {'ESpike': 4, 'FSolid': 3, 'ASpike': 2, 'GFlip': 1},
          hard: {'ESpike': 5, 'FSolid': 4, 'ASpike': 3, '2Spike': 2});

    } else if (mechId == 30) {
      runMashup(ghost: true, dash: true, easy: {'FFloor': 4, 'Spike': 3, 'ASpike': 2},
          medium: {'FFloor': 4, 'ASpike': 3, 'ESpike': 3, 'FDoor': 1},
          hard: {'FFloor': 5, 'ASpike': 4, 'ESpike': 3, 'FDoor': 2, 'Chain': 2});

    } else if (mechId == 31) {
      runMashup(wind: true, ice: true, easy: {'Spike': 4, 'JDrop': 3, 'Timed': 2},
          medium: {'Spike': 4, 'ESpike': 3, 'JDrop': 3, 'Timed': 2},
          hard: {'Spike': 5, 'ESpike': 4, 'JDrop': 3, 'Chain': 2, 'Timed': 2});

    } else if (mechId == 32) {
      runMashup(blink: true, mirror: true, easy: {'Spike': 3, 'TSpy': 3, 'FFloor': 3},
          medium: {'Spike': 4, 'TSpy': 4, 'RevCtrl': 2, 'FFloor': 2},
          hard: {'Spike': 4, 'TSpy': 5, 'RevCtrl': 3, 'FDoor': 2, 'ESpike': 2});

    } else if (mechId == 33) {
      runMashup(tiny: true, freeze: true, easy: {'Spike': 4, 'FFloor': 3, 'TimeTog': 2},
          medium: {'Spike': 4, 'FFloor': 3, 'TimeTog': 3, 'ESpike': 2},
          hard: {'Spike': 5, 'FFloor': 3, 'TimeTog': 3, 'Thwomp': 3, 'ESpike': 2});

    } else if (mechId == 34) {
      runMashup(lowGravity: true, conveyor: true, easy: {'FFloor': 3, 'ESpike': 3, 'Spike': 3},
          medium: {'FFloor': 3, 'ESpike': 4, 'Thwomp': 3, 'ASpike': 2},
          hard: {'FFloor': 3, 'ESpike': 4, 'Thwomp': 3, 'Timed': 3, '2Spike': 2});

    } else if (mechId == 35) {
      runMashup(chase: true, bouncy: true, easy: {'FSolid': 3, 'Thwomp': 3, 'ESpike': 3},
          medium: {'FSolid': 4, 'Thwomp': 3, 'ESpike': 3, 'MThwomp': 2},
          hard: {'FSolid': 4, 'Thwomp': 4, 'ESpike': 3, 'Chain': 2, 'MThwomp': 2});

    } else if (mechId == 36) {
      runMashup(lava: true, dash: true, easy: {'Spike': 4, 'FFloor': 2, 'JDrop': 2},
          medium: {'Spike': 4, 'FFloor': 3, 'ESpike': 2, 'JDrop': 3},
          hard: {'Spike': 5, 'FFloor': 3, 'ESpike': 3, 'JDrop': 3, 'MThwomp': 2});

    } else if (mechId == 37) {
      runMashup(flappy: true, wind: true, easy: {'Spike': 3, 'ASpike': 3, 'Thwomp': 2},
          medium: {'Spike': 4, 'ASpike': 3, 'ESpike': 3, 'Thwomp': 2},
          hard: {'Spike': 4, 'ASpike': 4, 'ESpike': 4, 'Thwomp': 3, 'TSpy': 2});

    } else if (mechId == 38) {
      runMashup(inverted: true, ghost: true, easy: {'ESpike': 4, 'FSolid': 3, 'FFloor': 2},
          medium: {'ESpike': 4, 'FSolid': 3, 'FFloor': 3, 'ASpike': 2},
          hard: {'ESpike': 5, 'FSolid': 4, 'FFloor': 3, '2Spike': 2, 'FDoor': 1});

    } else if (mechId == 39) {
      runMashup(spotlight: true, ice: true, easy: {'SpotTog': 3, 'Timed': 3, 'Spike': 3},
          medium: {'SpotTog': 3, 'Timed': 4, 'ESpike': 3, 'FFloor': 2},
          hard: {'SpotTog': 4, 'Timed': 4, 'ESpike': 4, 'Chain': 2, 'TSpy': 2});

    } else if (mechId == 40) {
      runMashup(wrap: true, mirror: true, easy: {'Spike': 4, 'FFloor': 3, 'RevCtrl': 2},
          medium: {'Spike': 4, 'FFloor': 3, 'RevCtrl': 3, 'ESpike': 2},
          hard: {'Spike': 5, 'FFloor': 3, 'RevCtrl': 4, 'ESpike': 3, '2Spike': 2});

    } else if (mechId == 41) {
      runMashup(tiny: true, dash: true, easy: {'Spike': 4, 'FFloor': 3, 'ASpike': 2},
          medium: {'Spike': 4, 'FFloor': 4, 'ASpike': 3, 'ESpike': 2},
          hard: {'Spike': 5, 'FFloor': 4, 'ASpike': 3, 'ESpike': 3, 'AggDoor': 1});

    } else if (mechId == 42) {
      runMashup(bouncy: true, wind: true, easy: {'Thwomp': 3, 'JDrop': 3, 'Spike': 3},
          medium: {'Thwomp': 4, 'JDrop': 3, 'ESpike': 3, 'ASpike': 2},
          hard: {'Thwomp': 4, 'JDrop': 4, 'ESpike': 4, 'MThwomp': 2, 'Chain': 2});

    } else if (mechId == 43) {
      runMashup(ghost: true, blink: true, easy: {'FFloor': 3, 'TSpy': 3, 'Spike': 3},
          medium: {'FFloor': 4, 'TSpy': 4, 'ESpike': 3, 'ASpike': 2},
          hard: {'FFloor': 4, 'TSpy': 5, 'ESpike': 4, 'FDoor': 2, 'Chain': 2});

    } else if (mechId == 44) {
      runMashup(freeze: true, mirror: true, easy: {'TimeTog': 3, 'RevCtrl': 2, 'Spike': 3},
          medium: {'TimeTog': 4, 'RevCtrl': 3, 'ESpike': 3, 'FFloor': 2},
          hard: {'TimeTog': 4, 'RevCtrl': 4, 'ESpike': 4, 'FDoor': 2, 'TSpy': 2});

    } else if (mechId == 45) {
      // S6 Group 25 — final mashup of established Season 1-5 mechanics.
      runMashup(bouncy: true, ghost: true, wind: true, mirror: true, blink: true,
          easy: {'Spike': 3, 'ASpike': 2, 'Thwomp': 2, 'FFloor': 2},
          medium: {'Spike': 4, 'ASpike': 3, 'ESpike': 3, 'Thwomp': 3, 'RevCtrl': 2, 'TSpy': 2},
          hard: {'Spike': 5, 'ASpike': 3, 'ESpike': 4, 'Thwomp': 4, 'Chain': 2, 'RevCtrl': 2, 'FDoor': 2});
    }

    List<String> mapStrings = [];
    for (int r = 0; r < 15; r++) {
      mapStrings.add(grid[r].join(''));
    }
    
    
    _parseMap(mapStrings);
    
    if (isTinyLevel) {
      player.rect.w = 20;
      player.rect.h = 20;
      player.rect.y += 15; // adjust to floor
    }

  }

  void _parseMap(List<String> map) {
    maxMapWidth = map[0].length * gs;
    for (int row = 0; row < map.length; row++) {
      for (int col = 0; col < map[row].length; col++) {
        String char = map[row][col];
        double x = col * gs;
        double y = row * gs;
        
        if (char == 'S') { // Troll Spring
          entities.add(TrollEntity(
            id: 'S_${row}_${col}', type: TrollEntityType.block,
            rect: RectD(x, y + 20, gs, gs - 20),
            color: const Color(0xFF00FF00), // Bright green
            isSolid: true, // Acts as a block at first
          ));
        } else if (char == 'A') { // Aggressive Door
          entities.add(TrollEntity(
            id: 'A_${row}_${col}', type: TrollEntityType.door,
            rect: RectD(x, y - 20, gs, gs + 20),
            color: const Color(0xFFFFD700), // Looks like a door!
            isSolid: false,
          ));
        } else if (char == 'P') {
          player = TrollEntity(
            id: 'player', type: TrollEntityType.player,
            rect: RectD(x + 5, y + 5, 30, 35),
            color: const Color(0xFF00FFCC),
          );
        } else if (char == 'r') {
          entities.add(TrollEntity(
            id: 'r_${row}_${col}', type: TrollEntityType.block,
            rect: RectD(x, y, gs, gs), isSolid: false, isVisible: false
          ));
        } else if (char == 'L') {
          entities.add(TrollEntity(
            id: 'L_${row}_${col}', type: TrollEntityType.block,
            rect: RectD(x + 15, y - 3 * gs, 10, 4 * gs),
            color: const Color(0x66FFFFFF),
            isSolid: false, isVisible: true
          ));
        } else if (char == 'T') {
          entities.add(TrollEntity(
            id: 'T_${row}_${col}', type: TrollEntityType.block,
            rect: RectD(x + 15, y - 3 * gs, 10, 4 * gs),
            color: const Color(0x6600AAFF),
            isSolid: false, isVisible: true
          ));
        } else if (char == '>') {
          entities.add(TrollEntity(
            id: 'b_${row}_${col}', type: TrollEntityType.block,
            rect: RectD(x, y, gs, gs),
            color: const Color(0xFF00FF00),
          ));
        } else if (char == '<') {
          entities.add(TrollEntity(
            id: 'b_${row}_${col}', type: TrollEntityType.block,
            rect: RectD(x, y, gs, gs),
            color: const Color(0xFFFF0000),
          ));
        } else if (char == 'b') { // Invisible solid block
          // Invisible Blocks must remain collidable while hidden.
          // The player cannot see the block, but it still acts as real level geometry.
          entities.add(TrollEntity(
            id: 'b_${row}_${col}', type: TrollEntityType.block,
            rect: RectD(x, y, gs, gs),
            color: const Color(0xFF333333),
            isSolid: true,
            isVisible: false,
          ));
        } else if (char == 'X') {
          entities.add(TrollEntity(
            id: 'b_${row}_${col}', type: TrollEntityType.block,
            rect: RectD(x, y, gs, gs),
            color: const Color(0xFF2C2F33),
          ));
        } else if (char == 'W') { // Hidden wall block
          entities.add(TrollEntity(
            id: 'b_${row}_${col}', type: TrollEntityType.block,
            rect: RectD(x, y, gs, gs),
            color: const Color(0xFF333333),
            isSolid: false,
            isVisible: false,
          ));
        } else if (char == 'h') { // Hidden spike on ground
          entities.add(TrollEntity(
            id: 's_${row}_${col}', type: TrollEntityType.spike,
            rect: RectD(x, y + 20, gs, gs - 20), // Short spike
            color: const Color(0xFFFF3366),
            isSolid: false,
            isVisible: false, // Starts hidden!
          ));
        } else if (char == 's') { // Normal visible spike on ground
          entities.add(TrollEntity(
            id: 's_${row}_${col}', type: TrollEntityType.spike,
            rect: RectD(x, y + 20, gs, gs - 20), // Short spike
            color: const Color(0xFFFF3366),
            isSolid: false,
          ));
        } else if (char == 'v') { // Inverted spike under ceiling
          entities.add(TrollEntity(
            id: 's_${row}_${col}', type: TrollEntityType.spike,
            rect: RectD(x, y, gs, gs - 20),
            color: const Color(0xFFFF3366),
            isSolid: false,
            isInverted: true,
          ));
        } else if (char == 'D') {
          entities.add(TrollEntity(
            id: 'door', type: TrollEntityType.door,
            rect: RectD(x, y - 20, 40, 60),
            color: const Color(0xFFFFD700),
            isSolid: false,
          ));
        }
      }
    }
  }

  void update(double dt) {
    if (dt > 0.05) dt = 0.05;
    
    final double maxFallSpeed = 900.0;
    
    // Camera Logic
    if (player != null && !isDead) {
      double targetCameraX = player.rect.x - logicalWidth / 2 + player.rect.w / 2;
      if (targetCameraX < 0) targetCameraX = 0;
      if (targetCameraX > maxMapWidth - logicalWidth) targetCameraX = maxMapWidth - logicalWidth;
      cameraX += (targetCameraX - cameraX) * 5 * dt; // Smooth follow
    }

    // Particles
    for (int i = particles.length - 1; i >= 0; i--) {
      var p = particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += gravity * 0.5 * dt;
      p.life -= dt;
      if (p.life <= 0) particles.removeAt(i);
    }

    if (isDead) {
      playerScale = max(0.0, playerScale - dt * 4);
      deathTimer -= dt;
      if (deathTimer <= 0) {
        nextRound(failed: true); // 1-Hit Kill
      }
      return;
    }
    
    if (roundWon) {
      transitionTimer += dt;
      if (transitionTimer >= 1.0) {
        nextRound();
      }
      return;
    }
    if (allComplete) return;

    bool playerIsMoving = player.vx.abs() > 5 || player.vy.abs() > 5 || movingLeft || movingRight || jumping;

    // Update Traps
    for (var t in traps) {
      if (isTimeFreezeLevel && !playerIsMoving) continue;
      t.update(this, dt);
    }

    // --- Pro Platformer Physics ---
    
    double currentJumpForce = jumpForce;
    double currentGravity = 2500.0;
    double currentAccel = moveAcceleration;
    double currentFriction = friction;
    
    if (isLowGravityLevel) {
       currentGravity = 800.0;
       currentJumpForce = -650.0;
    }
    if (isIceLevel) {
       currentFriction = 300.0; // Slippery
       currentAccel = 800.0;
    }
    if (isFlappyLevel) {
       currentJumpForce = -500.0;
    }

    if (jumping) {
      jumpBufferTimer = 0.15; // Queue jump
      jumping = false;
    } else {
      jumpBufferTimer -= dt;
    }

    if (_isGrounded) {
      coyoteTimer = 0.15;
      hasDashed = false; // Reset dash on ground
    } else {
      coyoteTimer -= dt;
    }
    
    if (isFlappyLevel) {
       // Infinite mid-air jumps
       coyoteTimer = 1.0; 
    }

    if (jumpBufferTimer > 0 && coyoteTimer > 0) {
      player.vy = isGravityInverted ? -currentJumpForce : currentJumpForce;
      coyoteTimer = 0;
      jumpBufferTimer = 0;
    } else if (isDashLevel && jumpBufferTimer > 0 && coyoteTimer <= 0 && !hasDashed) {
      // Air Dash mechanic
      hasDashed = true;
      player.vx = playerFaceDir * 1500.0; 
      player.vy = 0;
      jumpBufferTimer = 0;
    }

    // INVERTED CONTROLS LOGIC
    bool actualMoveLeft = invertedControls ? movingRight : movingLeft;
    bool actualMoveRight = invertedControls ? movingLeft : movingRight;

    if (actualMoveLeft) {
      playerFaceDir = invertedControls ? 1.0 : -1.0;
      player.vx -= currentAccel * dt;
      if (player.vx < -maxMoveSpeed && !(isDashLevel && hasDashed)) player.vx = -maxMoveSpeed;
    } else if (actualMoveRight) {
      playerFaceDir = invertedControls ? -1.0 : 1.0;
      player.vx += currentAccel * dt;
      if (player.vx > maxMoveSpeed && !(isDashLevel && hasDashed)) player.vx = maxMoveSpeed;
    } else {
      if (player.vx > 0) {
        player.vx -= currentFriction * dt;
        if (player.vx < 0) player.vx = 0;
      } else if (player.vx < 0) {
        player.vx += currentFriction * dt;
        if (player.vx > 0) player.vx = 0;
      }
    }
    
    if (isWindLevel) {
       player.vx -= 300.0 * dt; // Wind pushes left constantly
    }

    if (isGravityInverted) {
      player.vy -= currentGravity * dt; // Fall UP
    } else {
      player.vy += currentGravity * dt; // Fall DOWN
    }
    
    if (player.vy > maxFallSpeed) player.vy = maxFallSpeed;
    if (player.vy < -maxFallSpeed) player.vy = -maxFallSpeed;

    _isGrounded = false;
    
    if (isGhostLevel) {
       if (ghostHistory.isEmpty) {
         if (movingLeft || movingRight || jumping) {
           ghostHistory.add(Offset(player.rect.x, player.rect.y));
         }
       } else {
         ghostHistory.add(Offset(player.rect.x, player.rect.y));
         int maxHistory = (2.0 / 0.016).round();
         if (ghostHistory.length > maxHistory) {
           ghostHistory.removeAt(0);
         }
         if (ghostHistory.length >= maxHistory && !isDead) {
           RectD ghostRect = RectD(ghostHistory.first.dx, ghostHistory.first.dy, player.rect.w, player.rect.h);
           if (ghostRect.intersects(player.rect)) {
             killPlayer();
           }
         }
       }
    }

    // Move X
    player.rect.x += player.vx * dt;
    _resolveCollisions(true);

    // Move Y
    player.rect.y += player.vy * dt;
    _resolveCollisions(false);
    
    if (isConveyorLevel && _isGrounded) {
      for (var e in entities) {
        if (e.isSolid && e.rect.top == player.rect.bottom &&
            player.rect.right > e.rect.left && player.rect.left < e.rect.right) {
           if (e.color == const Color(0xFF00FF00)) player.rect.x += 350 * dt; 
           if (e.color == const Color(0xFFFF0000)) player.rect.x -= 350 * dt; 
        }
      }
    }
    
    if (isBouncyLevel && _isGrounded) {
       player.vy = isGravityInverted ? 700 : -700; // BOUNCE!
       _spawnParticles(player.rect.x + 10, player.rect.bottom, 10, const Color(0xFF00FFCC));
    }
    
    
    if (_isGrounded) {
       hasDashed = false;
    }
    
    if (isLavaLevel) {
       // Retreat lava safely when player near door
       if (player.rect.x > maxMapWidth - (25 * gs)) {
           lavaY += 400 * dt; // Fast retreat so player isn't killed at victory
       } else {
           // Rise speed: 30 px/s — gives ~23s to traverse a 320-col level
           lavaY -= 30 * dt;
       }
       if (player.rect.bottom > lavaY) {
          killPlayer();
       }
    }
    
    if (isBlinkLevel) {
       blinkTimer += dt;
    }

    if (isChasedLevel) {
       chaseWallX += chaseWallSpeed * dt;
       if (player.rect.x < chaseWallX) {
         killPlayer();
       }
    }
    
    if (player.rect.y > 700 || player.rect.y < -300) { // Check both bounds for inverted gravity
      if (isWrapLevel) {
        player.rect.y = player.rect.y > 700 ? -50 : 650;
        player.vy = 0;
      } else if (TrollEngine.godMode) {
        player.rect.y = isGravityInverted ? 300 : 100;
        player.vy = 0;
        player.vx = 0;
      } else {
        killPlayer();
      }
    }

    for (var e in entities) {
      if (isTimeFreezeLevel && !playerIsMoving) continue;
      if (e.activePhysics) {
        e.vy += gravity * dt;
        e.rect.y += e.vy * dt;
        
        if (player.rect.bottom >= e.rect.top && 
            player.rect.bottom <= e.rect.top + 15 &&
            player.rect.right > e.rect.left && 
            player.rect.left < e.rect.right && player.vy > 0) {
           player.rect.y = e.rect.top - player.rect.h;
           _isGrounded = true;
           player.vy = e.vy;
        }
      }
    }

    // Hitboxes (shrink player hitbox slightly to prevent unfair deaths)
    RectD shrinkHitbox = RectD(player.rect.x + 8, player.rect.y + 10, player.rect.w - 16, player.rect.h - 15);
    
    for (var e in entities) {
      if (e.type == TrollEntityType.spike && e.isVisible) {
        if (shrinkHitbox.intersects(e.rect)) {
          killPlayer();
        }
      } else if (e.type == TrollEntityType.door) {
        if (player.rect.intersects(e.rect)) {
          roundWon = true;
          playerScale = 0.0; // disappear into door
          _spawnParticles(e.rect.x + 20, e.rect.y + 30, 20, const Color(0xFFFFD700));
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
            if (!isGravityInverted) _isGrounded = true;
          } else if (player.vy < 0) {
            player.rect.y = e.rect.bottom;
            if (isGravityInverted) _isGrounded = true;
          }
          player.vy = 0;
        }
      }
    }
  }
}

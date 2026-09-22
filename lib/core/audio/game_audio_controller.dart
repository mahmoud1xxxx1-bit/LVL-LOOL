import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../settings/game_settings_controller.dart';

enum GameAudioScene { silent, menu, match }

enum GameSfx { tap, reward, matchStart }

class GameAudioController {
  GameAudioController._();

  static final GameAudioController instance = GameAudioController._();

  final AudioPlayer _musicPlayer = AudioPlayer(playerId: 'lvllo_music');
  final AudioPlayer _sfxPlayer = AudioPlayer(playerId: 'lvllo_sfx');
  final GameSettingsController _settings = GameSettingsController.instance;

  GameAudioScene _scene = GameAudioScene.silent;
  bool _initialized = false;
  late final Uint8List _menuLoop;
  late final Uint8List _matchLoop;
  late final Map<GameSfx, Uint8List> _effects;

  GameAudioScene get scene => _scene;

  Future<void> initialize() async {
    if (_initialized) return;
    _menuLoop = _PcmFactory.menuLoop();
    _matchLoop = _PcmFactory.matchLoop();
    _effects = <GameSfx, Uint8List>{
      GameSfx.tap: _PcmFactory.tap(),
      GameSfx.reward: _PcmFactory.reward(),
      GameSfx.matchStart: _PcmFactory.matchStart(),
    };
    _initialized = true;
    _settings.addListener(_applyVolumes);
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    await _applyVolumes();
  }

  Future<void> dispose() async {
    _settings.removeListener(_applyVolumes);
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
  }

  Future<void> _applyVolumes() async {
    if (!_initialized) return;
    try {
      await _musicPlayer.setVolume(_settings.effectiveMusicVolume);
      await _sfxPlayer.setVolume(_settings.effectiveSfxVolume);
    } catch (_) {
      // Audio is experiential only. Never let an audio-device failure block gameplay.
    }
  }

  Future<void> playMenuMusic() => _switchScene(GameAudioScene.menu, _menuLoop);

  Future<void> playMatchMusic() => _switchScene(GameAudioScene.match, _matchLoop);

  Future<void> stopMusic() async {
    _scene = GameAudioScene.silent;
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  Future<void> _switchScene(GameAudioScene scene, Uint8List bytes) async {
    if (!_initialized) await initialize();
    if (_scene == scene && _musicPlayer.state == PlayerState.playing) {
      await _applyVolumes();
      return;
    }
    _scene = scene;
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_settings.effectiveMusicVolume);
      await _musicPlayer.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Fail soft: a device audio problem must never interrupt a match.
    }
  }

  Future<void> playSfx(GameSfx effect) async {
    if (!_initialized) await initialize();
    if (_settings.effectiveSfxVolume <= 0) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(_settings.effectiveSfxVolume);
      await _sfxPlayer.play(
        BytesSource(_effects[effect]!, mimeType: 'audio/wav'),
      );
    } catch (_) {}
  }
}

class _PcmFactory {
  const _PcmFactory._();

  static const int _sampleRate = 22050;

  static Uint8List menuLoop() {
    const seconds = 12.0;
    return _wav(seconds, (t) {
      final slow = 0.78 + 0.22 * math.sin(2 * math.pi * t / seconds);
      final pad =
          0.19 * math.sin(2 * math.pi * 65.333333 * t) +
          0.10 * math.sin(2 * math.pi * 82.333333 * t + 0.6) +
          0.07 * math.sin(2 * math.pi * 98.0 * t + 1.1) +
          0.045 * math.sin(2 * math.pi * 130.666667 * t + 0.25);
      final shimmer = 0.018 *
          math.sin(2 * math.pi * 261.333333 * t) *
          (0.5 + 0.5 * math.sin(2 * math.pi * t / 3));
      return (pad * slow + shimmer) * 0.72;
    });
  }

  static Uint8List matchLoop() {
    const seconds = 12.0;
    const beat = 0.6;
    const notes = <double>[
      220.0,
      261.333333,
      293.333333,
      261.333333,
      196.0,
      220.0,
      246.666667,
      220.0,
    ];
    return _wav(seconds, (t) {
      final bed =
          0.11 * math.sin(2 * math.pi * 73.333333 * t) +
          0.045 * math.sin(2 * math.pi * 110.0 * t + 0.4);
      final halfBeat = beat / 2;
      final index = (t / halfBeat).floor();
      final phase = t - index * halfBeat;
      final env = math.exp(-phase / 0.065);
      final note = notes[index % notes.length];
      final pluck = 0.050 * env *
          (math.sin(2 * math.pi * note * phase) +
              0.22 * math.sin(2 * math.pi * note * 2 * phase));
      final beatPhase = t - (t / beat).floor() * beat;
      final pulse = 0.028 * math.exp(-beatPhase / 0.05) *
          math.sin(2 * math.pi * 55 * beatPhase);
      return (bed + pluck + pulse) * 0.82;
    });
  }

  static Uint8List tap() => _wav(0.08, (t) {
        final normalized = t / 0.08;
        final frequency = 720 - 230 * normalized;
        return 0.24 * math.exp(-t / 0.018) *
            math.sin(2 * math.pi * frequency * t);
      });

  static Uint8List reward() => _wav(0.52, (t) {
        const events = <(double, double)>[
          (0.00, 523.25),
          (0.09, 659.25),
          (0.18, 783.99),
          (0.27, 1046.50),
        ];
        var value = 0.0;
        for (final event in events) {
          final local = t - event.$1;
          if (local >= 0) {
            value += 0.12 * math.exp(-local / 0.12) *
                math.sin(2 * math.pi * event.$2 * local);
          }
        }
        return value;
      });

  static Uint8List matchStart() => _wav(0.65, (t) {
        const duration = 0.65;
        const start = 170.0;
        const end = 620.0;
        final phase = 2 * math.pi *
            (start * t + (end - start) * t * t / (2 * duration));
        final env = math.pow(
          math.sin(math.pi * t / duration).clamp(0.0, 1.0),
          1.2,
        );
        return (0.17 * env * math.sin(phase) +
                0.055 * env * math.sin(phase * 2))
            .toDouble();
      });

  static Uint8List _wav(
    double seconds,
    double Function(double seconds) sample,
  ) {
    final sampleCount = (_sampleRate * seconds).round();
    final dataLength = sampleCount * 2;
    final bytes = ByteData(44 + dataLength);

    void text(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, _sampleRate, Endian.little);
    bytes.setUint32(28, _sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    text(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
      final t = i / _sampleRate;
      final value = sample(t).clamp(-0.96, 0.96);
      bytes.setInt16(
        44 + i * 2,
        (value * 32767).round(),
        Endian.little,
      );
    }
    return bytes.buffer.asUint8List();
  }
}

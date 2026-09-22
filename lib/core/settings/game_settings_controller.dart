import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameSettingsController extends ChangeNotifier {
  GameSettingsController._();

  static final GameSettingsController instance = GameSettingsController._();

  static const _musicVolumeKey = 'settings.musicVolume';
  static const _sfxVolumeKey = 'settings.sfxVolume';
  static const _musicMutedKey = 'settings.musicMuted';
  static const _sfxMutedKey = 'settings.sfxMuted';
  static const _hapticsKey = 'settings.hapticsEnabled';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  double _musicVolume = 0.42;
  double _sfxVolume = 0.70;
  bool _musicMuted = false;
  bool _sfxMuted = false;
  bool _hapticsEnabled = true;
  bool _loaded = false;

  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get musicMuted => _musicMuted;
  bool get sfxMuted => _sfxMuted;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get loaded => _loaded;

  double get effectiveMusicVolume => _musicMuted ? 0 : _musicVolume;
  double get effectiveSfxVolume => _sfxMuted ? 0 : _sfxVolume;

  Future<void> load() async {
    if (_loaded) return;
    final music = await _prefs.getDouble(_musicVolumeKey);
    final sfx = await _prefs.getDouble(_sfxVolumeKey);
    final musicMuted = await _prefs.getBool(_musicMutedKey);
    final sfxMuted = await _prefs.getBool(_sfxMutedKey);
    final haptics = await _prefs.getBool(_hapticsKey);

    _musicVolume = (music ?? _musicVolume).clamp(0.0, 1.0);
    _sfxVolume = (sfx ?? _sfxVolume).clamp(0.0, 1.0);
    _musicMuted = musicMuted ?? _musicMuted;
    _sfxMuted = sfxMuted ?? _sfxMuted;
    _hapticsEnabled = haptics ?? _hapticsEnabled;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0);
    notifyListeners();
    await _prefs.setDouble(_musicVolumeKey, _musicVolume);
  }

  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value.clamp(0.0, 1.0);
    notifyListeners();
    await _prefs.setDouble(_sfxVolumeKey, _sfxVolume);
  }

  Future<void> setMusicMuted(bool value) async {
    _musicMuted = value;
    notifyListeners();
    await _prefs.setBool(_musicMutedKey, value);
  }

  Future<void> setSfxMuted(bool value) async {
    _sfxMuted = value;
    notifyListeners();
    await _prefs.setBool(_sfxMutedKey, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    notifyListeners();
    await _prefs.setBool(_hapticsKey, value);
  }
}
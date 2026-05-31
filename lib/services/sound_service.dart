import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer2 = AudioPlayer();

  bool _enabled = true;
  double _volume = 0.72;

  DateTime _lastClickAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSfxAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastSfx;
  int _sfxTurn = 0;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _enabled = prefs.getBool('sound_enabled') ?? true;
    _volume = prefs.getDouble('sound_volume') ?? 0.72;

    await _clickPlayer.setReleaseMode(ReleaseMode.stop);
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    await _sfxPlayer2.setReleaseMode(ReleaseMode.stop);

    unawaited(AudioCache.instance.loadAll([
      'sounds/click.wav',
      'sounds/correct.wav',
      'sounds/wrong.wav',
      'sounds/quiz_complete.wav',
      'sounds/victory.wav',
      'sounds/defeat.wav',
      'sounds/energy_gain.wav',
      'sounds/reward.wav',
      'sounds/notification.wav',
      'sounds/level_unlock.wav',
      'sounds/purchase_success.wav',
    ]));
  }

  bool get enabled => _enabled;
  double get volume => _volume;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', value);
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sound_volume', _volume);
  }

  Future<void> click() async {
    if (!_enabled) return;

    final now = DateTime.now();
    if (now.difference(_lastClickAt).inMilliseconds < 145) return;
    _lastClickAt = now;

    try {
      await _clickPlayer.stop();
      await _clickPlayer.play(
        AssetSource('sounds/click.wav'),
        volume: (_volume * 0.30).clamp(0.0, 1.0),
      );
    } catch (_) {}
  }

  Future<void> play(String fileName, {double? volume}) async {
    if (!_enabled) return;

    final now = DateTime.now();
    if (_lastSfx == fileName && now.difference(_lastSfxAt).inMilliseconds < 130) {
      return;
    }

    _lastSfx = fileName;
    _lastSfxAt = now;

    try {
      final player = (_sfxTurn++ % 2 == 0) ? _sfxPlayer : _sfxPlayer2;
      await player.stop();
      await player.play(
        AssetSource('sounds/$fileName'),
        volume: volume ?? _volume,
      );
    } catch (_) {}
  }

  Future<void> correct() => play('correct.wav', volume: (_volume * 0.55).clamp(0.0, 1.0));
  Future<void> wrong() => play('wrong.wav', volume: (_volume * 0.48).clamp(0.0, 1.0));
  Future<void> quizComplete() => play('quiz_complete.wav', volume: (_volume * 0.58).clamp(0.0, 1.0));
  Future<void> victory() => play('victory.wav', volume: (_volume * 0.60).clamp(0.0, 1.0));
  Future<void> defeat() => play('defeat.wav', volume: (_volume * 0.48).clamp(0.0, 1.0));
  Future<void> energyGain() => play('energy_gain.wav', volume: (_volume * 0.54).clamp(0.0, 1.0));
  Future<void> reward() => play('reward.wav', volume: (_volume * 0.52).clamp(0.0, 1.0));
  Future<void> notification() => play('notification.wav', volume: (_volume * 0.42).clamp(0.0, 1.0));
  Future<void> levelUnlock() => play('level_unlock.wav', volume: (_volume * 0.54).clamp(0.0, 1.0));
  Future<void> purchaseSuccess() => play('purchase_success.wav', volume: (_volume * 0.56).clamp(0.0, 1.0));

  Future<void> quizResultByScore({
    required int correct,
    required int total,
  }) async {
    if (total <= 0) {
      await defeat();
      return;
    }

    final ratio = correct / total;
    if (ratio >= 0.8) {
      await victory();
    } else if (ratio >= 0.5) {
      await quizComplete();
    } else {
      await defeat();
    }
  }

  Future<void> dispose() async {
    await _clickPlayer.dispose();
    await _sfxPlayer.dispose();
    await _sfxPlayer2.dispose();
  }
}

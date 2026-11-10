import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Trade success / error tones (portal mp3s).
///
/// Uses the notification audio stream on Android so sound still plays when
/// media volume is muted (common on Oppo/OnePlus/etc.).
class TradeSound {
  static AudioPlayer? _player;
  static Future<void>? _ready;

  static final _ctx = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationRingtone,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      audioMode: AndroidAudioMode.normal,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  /// Call once after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> warmUp() {
    return _ensureReady();
  }

  static Future<void> _ensureReady() {
    return _ready ??= () async {
      try {
        await AudioPlayer.global.setAudioContext(_ctx);
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(1);
        await player.setAudioContext(_ctx);
        // Force asset extract + MediaPlayer prepare so first trade is instant.
        await player.setSource(AssetSource('sounds/success.mp3'));
        _player = player;
        debugPrint('TradeSound ready');
      } catch (e, st) {
        _ready = null;
        debugPrint('TradeSound.warmUp failed: $e\n$st');
        rethrow;
      }
    }();
  }

  static Future<void> ok() async {
    HapticFeedback.mediumImpact();
    await _play('sounds/success.mp3');
  }

  static Future<void> error() async {
    HapticFeedback.heavyImpact();
    await _play('sounds/error.mp3');
  }

  static Future<void> _play(String asset) async {
    try {
      await _ensureReady();
      var player = _player;
      if (player == null || player.state == PlayerState.disposed) {
        _ready = null;
        _player = null;
        await _ensureReady();
        player = _player!;
      }
      await player.stop();
      await player.setVolume(1);
      await player.setAudioContext(_ctx);
      await player.play(AssetSource(asset), volume: 1);
      debugPrint('TradeSound playing $asset');
    } catch (e, st) {
      debugPrint('TradeSound play failed ($asset): $e\n$st');
      // Last resort: fresh player (avoids sticky native state).
      try {
        final fresh = AudioPlayer();
        await fresh.setReleaseMode(ReleaseMode.stop);
        await fresh.play(AssetSource(asset), volume: 1, ctx: _ctx);
        _player = fresh;
      } catch (e2, st2) {
        debugPrint('TradeSound retry failed ($asset): $e2\n$st2');
      }
    }
  }
}

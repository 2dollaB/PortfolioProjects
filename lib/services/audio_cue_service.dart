import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2.6 — Audio cue service for spoken zone changes and workout milestones
class AudioCueService {
  static final _tts = FlutterTts();
  static bool _initialized = false;
  static bool _enabled = true;
  static const _prefKey = 'audio_cues_enabled';

  /// Initialize TTS engine
  static Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(0.8);
    await _tts.setPitch(1.0);
    _initialized = true;

    // Load preference
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;
  }

  /// Toggle audio cues on/off
  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  static bool get isEnabled => _enabled;

  /// Speak zone change
  static Future<void> announceZone(int zone, String zoneName) async {
    if (!_enabled || !_initialized) return;
    await _tts.speak('Zone $zone. $zoneName');
  }

  /// Speak below-target alert
  static Future<void> announceBelowTarget(int targetZone) async {
    if (!_enabled || !_initialized) return;
    await _tts.speak('Below target. Push to zone $targetZone');
  }

  /// Speak workout milestone
  static Future<void> announceMilestone(String text) async {
    if (!_enabled || !_initialized) return;
    await _tts.speak(text);
  }

  /// Speak workout done
  static Future<void> announceWorkoutComplete(Duration duration, int calories) async {
    if (!_enabled || !_initialized) return;
    final min = duration.inMinutes;
    await _tts.speak('Workout complete. $min minutes. $calories calories burned.');
  }

  /// Stop speaking
  static Future<void> stop() async {
    await _tts.stop();
  }
}

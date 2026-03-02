import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// WebSocket client that connects to a TvServer hub
/// Used by participants to send their HR data to the trainer's hub
class SessionClient {
  WebSocket? _ws;
  Timer? _reconnectTimer;
  String? _serverUrl;
  bool _shouldReconnect = false;

  bool get isConnected => _ws != null;
  String? get serverUrl => _serverUrl;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Connect to a hub server
  Future<bool> connect(String ip, int port) async {
    _serverUrl = 'ws://$ip:$port/ws';
    _shouldReconnect = true;

    return _doConnect();
  }

  Future<bool> _doConnect() async {
    try {
      _ws = await WebSocket.connect(_serverUrl!)
          .timeout(const Duration(seconds: 5));
      debugPrint('[SessionClient] Connected to $_serverUrl');
      _connectionController.add(true);

      _ws!.listen(
        (_) {}, // We don't need to receive data from hub
        onDone: () {
          debugPrint('[SessionClient] Disconnected from hub');
          _ws = null;
          _connectionController.add(false);
          _scheduleReconnect();
        },
        onError: (e) {
          debugPrint('[SessionClient] Error: $e');
          _ws = null;
          _connectionController.add(false);
          _scheduleReconnect();
        },
      );

      return true;
    } catch (e) {
      debugPrint('[SessionClient] Failed to connect: $e');
      _ws = null;
      _connectionController.add(false);
      _scheduleReconnect();
      return false;
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_shouldReconnect && _ws == null) {
        debugPrint('[SessionClient] Reconnecting...');
        _doConnect();
      }
    });
  }

  /// Send HR update to hub
  void sendHrUpdate({
    required String userId,
    required String name,
    required int bpm,
    required int zone,
    required int hrMax,
  }) {
    if (_ws == null) return;
    try {
      _ws!.add(jsonEncode({
        'type': 'hr_update',
        'userId': userId,
        'name': name,
        'bpm': bpm,
        'zone': zone,
        'hrMax': hrMax,
      }));
    } catch (e) {
      debugPrint('[SessionClient] Send error: $e');
    }
  }

  /// Send remove notification (workout ended)
  void sendRemove(String userId) {
    if (_ws == null) return;
    try {
      _ws!.add(jsonEncode({
        'type': 'remove',
        'userId': userId,
      }));
    } catch (_) {}
  }

  /// Disconnect from hub
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    await _ws?.close();
    _ws = null;
    _connectionController.add(false);
    debugPrint('[SessionClient] Disconnected');
  }

  void dispose() {
    disconnect();
    _connectionController.close();
  }
}

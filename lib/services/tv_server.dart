import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Local WebSocket server for TV display
/// Serves the TV dashboard HTML and broadcasts HR data via WebSocket
class TvServer {
  HttpServer? _server;
  final List<WebSocket> _tvClients = [];
  final Map<String, UserHrState> _userStates = {};
  int _port = 8080;

  bool get isRunning => _server != null;
  int get port => _port;

  /// Get the device's local WiFi IP address
  static Future<String?> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        if (iface.name.contains('lo') || iface.name.contains('docker')) continue;
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168')) {
            return addr.address;
          }
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      debugPrint('[TvServer] Error getting IP: $e');
    }
    return null;
  }

  /// Start the server
  Future<String?> start({int port = 8080}) async {
    if (_server != null) return null;
    _port = port;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('[TvServer] Server running on port $port');
      _server!.listen(_handleRequest);
      return await getLocalIp();
    } catch (e) {
      debugPrint('[TvServer] Failed to start: $e');
      try {
        _port = port + 1;
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        _server!.listen(_handleRequest);
        return await getLocalIp();
      } catch (e2) {
        debugPrint('[TvServer] Failed on alt port too: $e2');
        return null;
      }
    }
  }

  /// Stop the server
  Future<void> stop() async {
    for (final ws in _tvClients) {
      await ws.close();
    }
    _tvClients.clear();
    _userStates.clear();
    await _server?.close(force: true);
    _server = null;
    debugPrint('[TvServer] Server stopped');
  }

  /// Update HR data for a user (called from workout screen)
  void updateUserHr({
    required String userId,
    required String name,
    required int bpm,
    required int zone,
    required int hrMax,
  }) {
    _userStates[userId] = UserHrState(
      userId: userId,
      name: name,
      bpm: bpm,
      zone: zone,
      hrMax: hrMax,
      lastUpdate: DateTime.now(),
    );
    _broadcastState();
  }

  /// Remove a user (when workout ends)
  void removeUser(String userId) {
    _userStates.remove(userId);
    _broadcastState();
  }

  /// Broadcast current state to all TV clients
  void _broadcastState() {
    final now = DateTime.now();
    _userStates.removeWhere((_, state) =>
        now.difference(state.lastUpdate).inSeconds > 30);

    final payload = jsonEncode({
      'type': 'state',
      'users': _userStates.values.map((u) => u.toJson()).toList(),
      'timestamp': now.millisecondsSinceEpoch,
    });

    final deadClients = <WebSocket>[];
    for (final ws in _tvClients) {
      try {
        ws.add(payload);
      } catch (_) {
        deadClients.add(ws);
      }
    }
    _tvClients.removeWhere(deadClients.contains);
  }

  /// Handle incoming HTTP requests
  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    if (path == '/ws') {
      try {
        final ws = await WebSocketTransformer.upgrade(request);
        _tvClients.add(ws);
        debugPrint('[TvServer] TV client connected (${_tvClients.length} total)');
        _broadcastState();

        ws.listen(
          (_) {},
          onDone: () {
            _tvClients.remove(ws);
            debugPrint('[TvServer] TV client disconnected');
          },
          onError: (_) => _tvClients.remove(ws),
        );
      } catch (e) {
        debugPrint('[TvServer] WebSocket upgrade failed: $e');
      }
    } else {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(_buildDashboardHtml())
        ..close();
    }
  }

  /// Build the TV Dashboard HTML
  String _buildDashboardHtml() {
    final buf = StringBuffer();
    buf.write('<!DOCTYPE html><html lang="en"><head>');
    buf.write('<meta charset="UTF-8">');
    buf.write('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buf.write('<title>BeatSync TV</title>');
    buf.write('<style>');
    buf.write(_cssStyles);
    buf.write('</style></head><body>');
    buf.write(_bodyHtml);
    buf.write('<script>');
    buf.write(_jsCode);
    buf.write('</script></body></html>');
    return buf.toString();
  }

  String get _cssStyles => r'''
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  background: #0a0a12; color: white;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  min-height: 100vh; overflow: hidden;
}
.header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 20px 40px; background: rgba(255,255,255,0.03);
  border-bottom: 1px solid rgba(255,255,255,0.05);
}
.logo {
  font-size: 28px; font-weight: 700; letter-spacing: 2px;
  background: linear-gradient(135deg, #6C63FF, #00D4AA);
  -webkit-background-clip: text; -webkit-text-fill-color: transparent;
}
.status { font-size: 14px; color: rgba(255,255,255,0.4); }
.status .dot {
  display: inline-block; width: 8px; height: 8px; border-radius: 50%;
  background: #22c55e; margin-right: 8px; animation: pulse-dot 2s infinite;
}
.status.disconnected .dot { background: #ef4444; animation: none; }
.grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px; padding: 30px 40px; max-height: calc(100vh - 80px); overflow-y: auto;
}
.empty {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  height: calc(100vh - 80px); color: rgba(255,255,255,0.3); font-size: 20px;
}
.empty-icon { font-size: 64px; margin-bottom: 16px; }
.card {
  position: relative; background: rgba(255,255,255,0.04); border-radius: 20px;
  padding: 24px; border: 1px solid rgba(255,255,255,0.06); overflow: hidden;
  transition: all 0.3s ease;
}
.card::before {
  content: ''; position: absolute; top: 0; left: 0; right: 0; height: 4px;
  background: var(--zone-color); opacity: 0.8;
}
.card-glow {
  position: absolute; top: -50%; left: -50%; width: 200%; height: 200%;
  background: radial-gradient(circle, var(--zone-color) 0%, transparent 70%);
  opacity: 0.06; pointer-events: none;
}
.user-name { font-size: 16px; font-weight: 600; color: rgba(255,255,255,0.7); margin-bottom: 8px; }
.bpm-row { display: flex; align-items: baseline; gap: 8px; }
.bpm { font-size: 72px; font-weight: 200; line-height: 1; color: white; text-shadow: 0 0 30px var(--zone-color); }
.bpm-label { font-size: 16px; color: rgba(255,255,255,0.4); letter-spacing: 2px; }
.zone-pill {
  display: inline-block; margin-top: 12px; padding: 6px 14px; border-radius: 12px;
  background: var(--zone-color); color: white; font-size: 13px; font-weight: 700;
  letter-spacing: 1px; opacity: 0.9;
}
.pct { float: right; font-size: 14px; color: rgba(255,255,255,0.4); margin-top: 14px; }
@keyframes pulse-dot { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
@keyframes pulse-bpm { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.02); } }
.card.active { animation: pulse-bpm 1s infinite; }
''';

  String get _bodyHtml => r'''
<div class="header">
  <div class="logo">BEATSYNC</div>
  <div class="status disconnected" id="status">
    <span class="dot"></span>
    <span id="statusText">Connecting...</span>
  </div>
</div>
<div id="content">
  <div class="empty">
    <div class="empty-icon">&#x1F493;</div>
    <div>Waiting for athletes...</div>
    <div style="font-size:14px; margin-top:8px; color:rgba(255,255,255,0.2)">
      Start a workout on your phone to appear here
    </div>
  </div>
</div>
''';

  String get _jsCode => r'''
var ZONE_COLORS = {0:'#666666',1:'#3B82F6',2:'#22C55E',3:'#EAB308',4:'#F97316',5:'#EF4444'};
var ZONE_NAMES = {0:'REST',1:'WARM UP',2:'FAT BURN',3:'CARDIO',4:'HARD',5:'PEAK'};
var ws, reconnectTimer;

function connect() {
  var protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
  ws = new WebSocket(protocol + '//' + location.host + '/ws');
  ws.onopen = function() {
    document.getElementById('status').className = 'status';
    document.getElementById('statusText').textContent = 'Live';
    clearTimeout(reconnectTimer);
  };
  ws.onclose = function() {
    document.getElementById('status').className = 'status disconnected';
    document.getElementById('statusText').textContent = 'Reconnecting...';
    reconnectTimer = setTimeout(connect, 2000);
  };
  ws.onerror = function() { ws.close(); };
  ws.onmessage = function(event) {
    try {
      var data = JSON.parse(event.data);
      if (data.type === 'state') renderUsers(data.users);
    } catch(e) {}
  };
}

function renderUsers(users) {
  var el = document.getElementById('content');
  if (!users || users.length === 0) {
    el.innerHTML = '<div class="empty"><div class="empty-icon">&#x1F493;</div><div>Waiting for athletes...</div></div>';
    document.getElementById('statusText').textContent = 'Live';
    return;
  }
  document.getElementById('statusText').textContent = 'Live \u00b7 ' + users.length + ' athlete' + (users.length > 1 ? 's' : '');
  var h = '<div class="grid">';
  for (var i = 0; i < users.length; i++) {
    var u = users[i];
    var c = ZONE_COLORS[u.zone] || ZONE_COLORS[0];
    var zn = ZONE_NAMES[u.zone] || 'REST';
    var pct = u.hrMax > 0 ? Math.round((u.bpm / u.hrMax) * 100) : 0;
    h += '<div class="card active" style="--zone-color:'+c+'">';
    h += '<div class="card-glow"></div>';
    h += '<div class="user-name">'+(u.name||'Athlete')+'</div>';
    h += '<div class="bpm-row"><div class="bpm">'+(u.bpm||'--')+'</div>';
    h += '<div class="bpm-label">BPM</div></div>';
    h += '<div class="zone-pill">Z'+u.zone+' \u00b7 '+zn+'</div>';
    h += '<div class="pct">'+pct+'%</div></div>';
  }
  h += '</div>';
  el.innerHTML = h;
}

connect();
''';
}

/// Represents a user's current HR state
class UserHrState {
  final String userId;
  final String name;
  final int bpm;
  final int zone;
  final int hrMax;
  final DateTime lastUpdate;

  UserHrState({
    required this.userId,
    required this.name,
    required this.bpm,
    required this.zone,
    required this.hrMax,
    required this.lastUpdate,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'bpm': bpm,
    'zone': zone,
    'hrMax': hrMax,
  };
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Local WebSocket server for TV display & group session management
class TvServer {
  HttpServer? _server;
  final List<WebSocket> _tvClients = [];
  final Map<String, UserHrState> _userStates = {};
  int _port = 8080;
  String sessionName = 'BeatSync Session';
  int maxParticipants = 15;

  // ── Session Timer & Intervals (5.2) ──
  int _sessionSeconds = 0;
  Timer? _sessionTimer;
  bool _sessionTimerRunning = false;
  IntervalPhase _currentPhase = IntervalPhase.idle;
  int _intervalSecondsLeft = 0;
  Timer? _intervalTimer;
  String _intervalLabel = '';

  bool get isRunning => _server != null;
  int get port => _port;
  int get participantCount => _userStates.length;
  int get sessionSeconds => _sessionSeconds;
  bool get sessionTimerRunning => _sessionTimerRunning;
  IntervalPhase get currentPhase => _currentPhase;
  int get intervalSecondsLeft => _intervalSecondsLeft;
  String get intervalLabel => _intervalLabel;
  Map<String, UserHrState> get userStates => Map.unmodifiable(_userStates);

  // Callback for when state changes (so phone UI can rebuild)
  VoidCallback? onStateChanged;

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
      _startSessionTimer();
      return await getLocalIp();
    } catch (e) {
      debugPrint('[TvServer] Failed to start: $e');
      try {
        _port = port + 1;
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        _server!.listen(_handleRequest);
        _startSessionTimer();
        return await getLocalIp();
      } catch (e2) {
        debugPrint('[TvServer] Failed on alt port too: $e2');
        return null;
      }
    }
  }

  /// Stop the server
  Future<void> stop() async {
    _sessionTimer?.cancel();
    _intervalTimer?.cancel();
    _sessionTimer = null;
    _intervalTimer = null;
    for (final ws in _tvClients) {
      await ws.close();
    }
    _tvClients.clear();
    _userStates.clear();
    await _server?.close(force: true);
    _server = null;
    _sessionSeconds = 0;
    _sessionTimerRunning = false;
    _currentPhase = IntervalPhase.idle;
    debugPrint('[TvServer] Server stopped');
  }

  // ═══════════════════════════════════════════
  // 5.2 Session Timer
  // ═══════════════════════════════════════════

  void _startSessionTimer() {
    _sessionTimerRunning = true;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
      _broadcastState();
    });
  }

  /// Send a GO (work) interval command to all clients
  void startWorkInterval({required int seconds, String label = 'WORK'}) {
    _intervalTimer?.cancel();
    _currentPhase = IntervalPhase.work;
    _intervalSecondsLeft = seconds;
    _intervalLabel = label;
    _broadcastCommand('interval_work', seconds: seconds, label: label);
    onStateChanged?.call();
    _intervalTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _intervalSecondsLeft--;
      if (_intervalSecondsLeft <= 0) {
        t.cancel();
        _currentPhase = IntervalPhase.idle;
        _broadcastCommand('interval_done');
        onStateChanged?.call();
      }
      _broadcastState();
    });
  }

  /// Send a REST interval command to all clients
  void startRestInterval({required int seconds, String label = 'REST'}) {
    _intervalTimer?.cancel();
    _currentPhase = IntervalPhase.rest;
    _intervalSecondsLeft = seconds;
    _intervalLabel = label;
    _broadcastCommand('interval_rest', seconds: seconds, label: label);
    onStateChanged?.call();
    _intervalTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _intervalSecondsLeft--;
      if (_intervalSecondsLeft <= 0) {
        t.cancel();
        _currentPhase = IntervalPhase.idle;
        _broadcastCommand('interval_done');
        onStateChanged?.call();
      }
      _broadcastState();
    });
  }

  void cancelInterval() {
    _intervalTimer?.cancel();
    _currentPhase = IntervalPhase.idle;
    _intervalSecondsLeft = 0;
    _broadcastCommand('interval_done');
    onStateChanged?.call();
  }

  void _broadcastCommand(String type, {int? seconds, String? label}) {
    final cmd = jsonEncode({
      'type': type,
      'seconds': seconds,
      'label': label,
      'sessionSeconds': _sessionSeconds,
    });
    final dead = <WebSocket>[];
    for (final ws in _tvClients) {
      try {
        ws.add(cmd);
      } catch (_) {
        dead.add(ws);
      }
    }
    _tvClients.removeWhere(dead.contains);
  }

  // ═══════════════════════════════════════════
  // HR Updates
  // ═══════════════════════════════════════════

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
    onStateChanged?.call();
    _broadcastState();
  }

  void removeUser(String userId) {
    _userStates.remove(userId);
    onStateChanged?.call();
    _broadcastState();
  }

  void _broadcastState() {
    final now = DateTime.now();
    _userStates.removeWhere((_, s) => now.difference(s.lastUpdate).inSeconds > 30);

    // Sort by HR% descending for leaderboard (5.3)
    final sorted = _userStates.values.toList()
      ..sort((a, b) {
        final pctA = a.hrMax > 0 ? a.bpm / a.hrMax : 0;
        final pctB = b.hrMax > 0 ? b.bpm / b.hrMax : 0;
        return pctB.compareTo(pctA);
      });

    final payload = jsonEncode({
      'type': 'state',
      'users': sorted.map((u) => u.toJson()).toList(),
      'sessionName': sessionName,
      'sessionSeconds': _sessionSeconds,
      'phase': _currentPhase.name,
      'intervalSecondsLeft': _intervalSecondsLeft,
      'intervalLabel': _intervalLabel,
      'timestamp': now.millisecondsSinceEpoch,
    });

    final dead = <WebSocket>[];
    for (final ws in _tvClients) {
      try {
        ws.add(payload);
      } catch (_) {
        dead.add(ws);
      }
    }
    _tvClients.removeWhere(dead.contains);
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/ws') {
      try {
        final ws = await WebSocketTransformer.upgrade(request);
        _tvClients.add(ws);
        debugPrint('[TvServer] TV client connected (${_tvClients.length} total)');
        _broadcastState();
        ws.listen(
          (data) => _handleWsMessage(data),
          onDone: () {
            _tvClients.remove(ws);
            debugPrint('[TvServer] Client disconnected');
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

  void _handleWsMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      if (type == 'hr_update') {
        final userId = msg['userId'] as String? ?? 'unknown';
        if (!_userStates.containsKey(userId) && _userStates.length >= maxParticipants) return;
        updateUserHr(
          userId: userId,
          name: msg['name'] as String? ?? 'Athlete',
          bpm: msg['bpm'] as int? ?? 0,
          zone: msg['zone'] as int? ?? 0,
          hrMax: msg['hrMax'] as int? ?? 180,
        );
      } else if (type == 'remove') {
        removeUser(msg['userId'] as String? ?? '');
      }
    } catch (e) {
      debugPrint('[TvServer] Message parse error: $e');
    }
  }

  // ═══════════════════════════════════════════
  // 5.3 TV Dashboard HTML — Leaderboard Mode
  // ═══════════════════════════════════════════

  String _buildDashboardHtml() {
    return '''<!DOCTYPE html><html lang="en"><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>BeatSync TV</title>
<style>$_cssStyles</style>
</head><body>$_bodyHtml<script>$_jsCode</script></body></html>''';
  }

  String get _cssStyles => r'''
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  background: #080810; color: white;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  min-height: 100vh; overflow: hidden;
}
/* ── Header ── */
.header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 16px 40px; background: rgba(255,255,255,0.025);
  border-bottom: 1px solid rgba(255,255,255,0.06);
}
.logo {
  font-size: 22px; font-weight: 800; letter-spacing: 3px;
  background: linear-gradient(135deg, #6C63FF, #00D4AA);
  -webkit-background-clip: text; -webkit-text-fill-color: transparent;
}
.header-center { display: flex; flex-direction: column; align-items: center; gap: 2px; }
.session-name { font-size: 16px; font-weight: 600; color: rgba(255,255,255,0.8); letter-spacing: 1px; }
.session-timer { font-size: 28px; font-weight: 200; color: white; letter-spacing: 4px; font-variant-numeric: tabular-nums; }
.status-dot { width: 8px; height: 8px; border-radius: 50%; background: #22c55e; display: inline-block; margin-right: 6px; animation: blink 2s infinite; }

/* ── Interval banner ── */
.interval-banner {
  position: fixed; top: 72px; left: 0; right: 0; z-index: 100;
  display: flex; align-items: center; justify-content: center; gap: 20px;
  padding: 14px 40px;
  background: var(--banner-bg, rgba(34,197,94,0.15));
  border-bottom: 2px solid var(--banner-color, #22c55e);
  backdrop-filter: blur(10px);
  transition: all 0.4s ease;
}
.interval-banner.hidden { transform: translateY(-100%); opacity: 0; }
.interval-label {
  font-size: 36px; font-weight: 900; letter-spacing: 6px;
  color: var(--banner-color, #22c55e);
  text-shadow: 0 0 40px var(--banner-color, #22c55e);
}
.interval-countdown {
  font-size: 56px; font-weight: 200; color: white;
  font-variant-numeric: tabular-nums; letter-spacing: 2px;
}

/* ── Main grid ── */
.main {
  display: grid;
  grid-template-columns: 1fr 340px;
  height: calc(100vh - 72px);
}

/* ── Leaderboard ── */
.leaderboard {
  padding: 20px 20px 20px 40px;
  overflow-y: auto;
  display: flex; flex-direction: column; gap: 12px;
}
.lb-row {
  display: flex; align-items: center; gap: 16px;
  background: rgba(255,255,255,0.03); border-radius: 14px;
  padding: 14px 20px; border: 1px solid rgba(255,255,255,0.05);
  border-left: 4px solid var(--zone-color, #666);
  transition: all 0.4s ease;
  position: relative; overflow: hidden;
}
.lb-row .glow {
  position: absolute; inset: 0;
  background: radial-gradient(ellipse at left, var(--zone-color) 0%, transparent 60%);
  opacity: 0.06; pointer-events: none;
}
.lb-rank {
  font-size: 14px; font-weight: 800; color: rgba(255,255,255,0.25);
  width: 28px; text-align: center; flex-shrink: 0;
}
.lb-rank.gold   { color: #FFD700; }
.lb-rank.silver { color: #C0C0C0; }
.lb-rank.bronze { color: #CD7F32; }
.lb-name { flex: 1; font-size: 18px; font-weight: 600; color: rgba(255,255,255,0.85); }
.lb-bpm  { font-size: 42px; font-weight: 200; color: white; text-shadow: 0 0 20px var(--zone-color); line-height: 1; }
.lb-bpm-label { font-size: 11px; color: rgba(255,255,255,0.35); letter-spacing: 2px; }
.lb-bar-wrap { width: 120px; flex-shrink: 0; }
.lb-bar-bg { height: 6px; background: rgba(255,255,255,0.08); border-radius: 3px; overflow: hidden; }
.lb-bar-fill { height: 100%; border-radius: 3px; background: var(--zone-color); transition: width 0.6s ease; }
.lb-pct { font-size: 13px; font-weight: 700; color: var(--zone-color); text-align: right; margin-top: 3px; }
.lb-zone { font-size: 11px; font-weight: 700; letter-spacing: 2px; color: var(--zone-color); flex-shrink: 0; text-align: center; width: 52px; }

/* ── Right sidebar: group stats ── */
.sidebar {
  background: rgba(255,255,255,0.02);
  border-left: 1px solid rgba(255,255,255,0.05);
  padding: 20px;
  display: flex; flex-direction: column; gap: 16px;
  overflow-y: auto;
}
.sidebar-title { font-size: 10px; font-weight: 700; letter-spacing: 3px; color: rgba(255,255,255,0.3); }
.stat-card {
  background: rgba(255,255,255,0.04); border-radius: 12px;
  padding: 14px 16px;
  border: 1px solid rgba(255,255,255,0.06);
}
.stat-value { font-size: 36px; font-weight: 200; color: white; }
.stat-label { font-size: 11px; color: rgba(255,255,255,0.35); letter-spacing: 2px; margin-top: 2px; }
.zone-dist { display: flex; flex-direction: column; gap: 6px; }
.zone-row { display: flex; align-items: center; gap: 8px; }
.zone-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.zone-bar-bg { flex: 1; height: 4px; background: rgba(255,255,255,0.06); border-radius: 2px; overflow: hidden; }
.zone-bar-fill { height: 100%; border-radius: 2px; transition: width 0.6s; }
.zone-count { font-size: 11px; color: rgba(255,255,255,0.4); width: 20px; text-align: right; }

/* ── Empty state ── */
.empty {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  height: 100%; color: rgba(255,255,255,0.25); font-size: 18px; gap: 12px;
}
.empty-icon { font-size: 56px; }

/* ── Animations ── */
@keyframes blink { 0%,100%{opacity:1;} 50%{opacity:0.3;} }
@keyframes rank-flash { 0%{background: rgba(255,215,0,0.15);} 100%{background: transparent;} }
''';

  String get _bodyHtml => '''
<div class="header">
  <div class="logo">BEATSYNC</div>
  <div class="header-center">
    <div class="session-name" id="sessionName">Session</div>
    <div class="session-timer" id="sessionTimer">00:00</div>
  </div>
  <div style="display:flex;align-items:center;gap:6px;font-size:13px;color:rgba(255,255,255,0.4)">
    <span class="status-dot" id="statusDot"></span>
    <span id="statusText">Connecting…</span>
  </div>
</div>

<div class="interval-banner hidden" id="intervalBanner">
  <div class="interval-label" id="intervalLabel">WORK</div>
  <div class="interval-countdown" id="intervalCountdown">0:30</div>
</div>

<div class="main">
  <div class="leaderboard" id="leaderboard">
    <div class="empty"><div class="empty-icon">💓</div><div>Waiting for athletes…</div></div>
  </div>
  <div class="sidebar">
    <div class="sidebar-title">GROUP STATS</div>
    <div class="stat-card">
      <div class="stat-value" id="statAthletes">0</div>
      <div class="stat-label">ATHLETES ACTIVE</div>
    </div>
    <div class="stat-card">
      <div class="stat-value" id="statAvgHr">--</div>
      <div class="stat-label">AVG GROUP HR</div>
    </div>
    <div class="stat-card">
      <div class="stat-value" id="statMaxHr">--</div>
      <div class="stat-label">HIGHEST HR</div>
    </div>
    <div class="sidebar-title" style="margin-top:4px">ZONE DISTRIBUTION</div>
    <div class="zone-dist" id="zoneDist"></div>
  </div>
</div>
''';

  String get _jsCode => r'''
var ZC = {0:'#444',1:'#3B82F6',2:'#22C55E',3:'#EAB308',4:'#F97316',5:'#EF4444'};
var ZN = {0:'REST',1:'Z1',2:'Z2',3:'Z3',4:'Z4',5:'Z5'};
var ws, reconnTimer, prevRanks = {}, intervalTimer;

function connect() {
  ws = new WebSocket((location.protocol==='https:'?'wss:':'ws:')+'//'+location.host+'/ws');
  ws.onopen = function() {
    document.getElementById('statusDot').style.background='#22c55e';
    document.getElementById('statusText').textContent='Live';
    clearTimeout(reconnTimer);
  };
  ws.onclose = function() {
    document.getElementById('statusDot').style.background='#ef4444';
    document.getElementById('statusText').textContent='Reconnecting…';
    reconnTimer = setTimeout(connect, 2000);
  };
  ws.onerror = function(){ ws.close(); };
  ws.onmessage = function(e) {
    try {
      var d = JSON.parse(e.data);
      if (d.type === 'state') {
        renderLeaderboard(d.users);
        renderSidebar(d.users);
        updateTimer(d.sessionSeconds||0);
        if (d.sessionName) document.getElementById('sessionName').textContent = d.sessionName;
      } else if (d.type === 'interval_work') {
        showBanner(d.label||'WORK', d.seconds, '#22C55E', 'rgba(34,197,94,0.12)');
      } else if (d.type === 'interval_rest') {
        showBanner(d.label||'REST', d.seconds, '#6C63FF', 'rgba(108,99,255,0.12)');
      } else if (d.type === 'interval_done') {
        hideBanner();
      }
    } catch(e){}
  };
}

function fmt(s) {
  var m = Math.floor(s/60), sec = s%60;
  return m+':'+(sec<10?'0':'')+sec;
}
function updateTimer(s) {
  document.getElementById('sessionTimer').textContent = fmt(s);
}

function showBanner(label, seconds, color, bg) {
  clearInterval(intervalTimer);
  var banner = document.getElementById('intervalBanner');
  banner.style.setProperty('--banner-color', color);
  banner.style.setProperty('--banner-bg', bg);
  document.getElementById('intervalLabel').textContent = label;
  banner.classList.remove('hidden');
  var left = seconds;
  document.getElementById('intervalCountdown').textContent = fmt(left);
  intervalTimer = setInterval(function(){
    left--;
    document.getElementById('intervalCountdown').textContent = fmt(left);
    if (left <= 0) { clearInterval(intervalTimer); hideBanner(); }
  }, 1000);
}
function hideBanner() {
  clearInterval(intervalTimer);
  document.getElementById('intervalBanner').classList.add('hidden');
}

function renderLeaderboard(users) {
  var el = document.getElementById('leaderboard');
  if (!users || users.length === 0) {
    el.innerHTML = '<div class="empty"><div class="empty-icon">💓</div><div>Waiting for athletes…</div></div>';
    return;
  }
  var html = '';
  for (var i = 0; i < users.length; i++) {
    var u = users[i], c = ZC[u.zone]||ZC[0];
    var pct = u.hrMax > 0 ? Math.round(u.bpm/u.hrMax*100) : 0;
    var rankClass = i===0?'gold':i===1?'silver':i===2?'bronze':'';
    var medal = i===0?'🥇':i===1?'🥈':i===2?'🥉':'#'+(i+1);
    var flash = prevRanks[u.userId] !== undefined && prevRanks[u.userId] !== i ? ' style="animation:rank-flash 0.8s ease"' : '';
    html += '<div class="lb-row"'+flash+' style="--zone-color:'+c+'">';
    html += '<div class="lb-rank '+rankClass+'">'+medal+'</div>';
    html += '<div class="glow"></div>';
    html += '<div class="lb-name">'+(u.name||'Athlete')+'</div>';
    html += '<div style="text-align:right">';
    html += '<div class="lb-bpm">'+(u.bpm||'--')+'</div>';
    html += '<div class="lb-bpm-label">BPM</div>';
    html += '</div>';
    html += '<div class="lb-bar-wrap">';
    html += '<div class="lb-bar-bg"><div class="lb-bar-fill" style="width:'+pct+'%;background:'+c+'"></div></div>';
    html += '<div class="lb-pct">'+pct+'% HRmax</div>';
    html += '</div>';
    html += '<div class="lb-zone">'+ZN[u.zone]+'</div>';
    html += '</div>';
    prevRanks[u.userId] = i;
  }
  el.innerHTML = html;
  document.getElementById('statusText').textContent = 'Live · '+users.length+' athlete'+(users.length>1?'s':'');
}

function renderSidebar(users) {
  if (!users || users.length === 0) {
    document.getElementById('statAthletes').textContent = '0';
    document.getElementById('statAvgHr').textContent = '--';
    document.getElementById('statMaxHr').textContent = '--';
    document.getElementById('zoneDist').innerHTML = '';
    return;
  }
  document.getElementById('statAthletes').textContent = users.length;
  var sum = users.reduce(function(s,u){return s+u.bpm;},0);
  document.getElementById('statAvgHr').textContent = Math.round(sum/users.length);
  var mx = users.reduce(function(m,u){return u.bpm>m?u.bpm:m;},0);
  document.getElementById('statMaxHr').textContent = mx;
  var zoneCounts = {1:0,2:0,3:0,4:0,5:0};
  users.forEach(function(u){ if(zoneCounts[u.zone]!==undefined) zoneCounts[u.zone]++; });
  var dh = '';
  for (var z=5;z>=1;z--) {
    var pct = users.length > 0 ? zoneCounts[z]/users.length*100 : 0;
    dh += '<div class="zone-row">';
    dh += '<div class="zone-dot" style="background:'+ZC[z]+'"></div>';
    dh += '<div class="zone-bar-bg"><div class="zone-bar-fill" style="width:'+pct+'%;background:'+ZC[z]+'"></div></div>';
    dh += '<div class="zone-count">'+zoneCounts[z]+'</div></div>';
  }
  document.getElementById('zoneDist').innerHTML = dh;
}

connect();
''';
}

/// Interval phase enum
enum IntervalPhase { idle, work, rest }

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

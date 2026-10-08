import 'package:flutter/material.dart';
import 'dart:async';
import 'vitals_screen.dart';
import 'symptoms_screen.dart';
import 'reminders_screen.dart';
import 'nutrition_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/ble_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _DashboardTab(),
          VitalsScreen(),
          SymptomsScreen(),
          RemindersScreen(),
          NutritionScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: 'Vitals'),
          NavigationDestination(icon: Icon(Icons.sick_outlined), selectedIcon: Icon(Icons.sick), label: 'Symptoms'),
          NavigationDestination(icon: Icon(Icons.alarm_outlined), selectedIcon: Icon(Icons.alarm), label: 'Reminders'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Nutrition'),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String _name = '...';
  int _week = 28;
  String _due = 'Sep 15, 2026';
  int _age = 27;   // shown in the dashboard greeting
  Map<String, dynamic> _vitals = Map.from(ApiService.fallbackVitals);
  Map<String, dynamic> _risk = Map.from(ApiService.fallbackRisk);
  bool _loading = true;
  bool _bpRecorded = false;
  String _bpLoggedAt = '';

  // BLE wearable gateway (phone -> backend). Null-safe: everything
  // keeps working from mock fallback when the ESP32 is off.
  final BleGateway _ble = BleGateway();
  StreamSubscription<WearableVitals>? _bleSub;
  StreamSubscription<BleConnState>? _bleStateSub;
  WearableVitals? _live;
  BleConnState _bleState = BleConnState.idle;
  bool _bleBusy = false;
  DateTime? _lastPush;
  String _emergencyContact = '';

  @override
  void initState() {
    super.initState();
    _bleSub = _ble.stream.listen(_onLive);
    _bleStateSub = _ble.stateStream.listen((s) {
      if (mounted) {
        setState(() {
          _bleState = s;
          _bleBusy = s == BleConnState.scanning ||
              s == BleConnState.connecting;
        });
      }
    });
    _load();
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _bleStateSub?.cancel();
    _ble.dispose();
    super.dispose();
  }

  /// Live BLE reading: show instantly + forward to backend (throttled).
  Future<void> _onLive(WearableVitals w) async {
    if (!mounted) return;
    final hadCandidate = _live?.fallCandidate ?? false;
    setState(() => _live = w);
    // Safety alert: prototype flag only - "possible sudden movement".
    if (w.fallCandidate && !hadCandidate) _showFallAlert();
    final now = DateTime.now();
    if (_lastPush != null &&
        now.difference(_lastPush!).inSeconds < 5) return;
    _lastPush = now;
    final profile = await SessionService.loadProfile();
    await ApiService.postLiveVitals(
        w.toLivePost((profile['patientId'] as String?) ?? 'P001'));
  }

  void _showFallAlert() {
    final emergency = _emergencyContact;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.red, size: 44),
        title: const Text('Possible sudden movement detected',
            textAlign: TextAlign.center),
        content: Text(
          emergency.isEmpty
              ? 'Your wearable sensed a sudden movement, then stillness. '
                  'This is a prototype alert, not a confirmed fall. '
                  'If you are hurt, contact emergency services.'
              : 'Your wearable sensed a sudden movement, then stillness. '
                  'This is a prototype alert, not a confirmed fall.\n\n'
                  'Emergency contact: $emergency',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I am okay'),
          ),
          if (emergency.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Call contact',
                  style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleBle() async {
    if (_bleBusy) return;
    if (_bleState == BleConnState.connected) {
      await _ble.disconnect();
    } else {
      final ok = await _ble.connect();
      if (!mounted) return;
      if (!ok && _bleState == BleConnState.notFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Nestora-V1 not found. Check the wearable is powered.')),
        );
      }
    }
  }

  String get _topFactor {
    final factors = (_risk['factors'] as List?)?.cast<String>() ?? [];
    if (factors.isEmpty) return 'Based on your recorded vitals.';
    return factors.first;
  }

  bool get _hasLive =>
      _live != null &&
      DateTime.now().difference(_live!.receivedAt).inSeconds < 5;

  Future<void> _load() async {
    setState(() => _loading = true);
    await ApiService.loadBase();
    final profile = await SessionService.loadProfile();
    final pid = (profile['patientId'] as String?) ?? 'P001';
    final results = await Future.wait([
      ApiService.getLatestVital(pid),
      ApiService.getRisk(pid),
    ]);
    if (!mounted) return;
    final name = (profile['name'] as String?) ?? '';
    setState(() {
      _name = name.isEmpty ? 'Priya' : name;
      _week = profile['week'] as int? ?? 28;
      _due = profile['due'] as String? ?? 'Sep 15, 2026';
      _age = (profile['age'] as num?)?.toInt() ?? 27;
      _emergencyContact = profile['emergency'] as String? ?? '';
      _vitals = results[0] as Map<String, dynamic>;
      _risk = results[1] as Map<String, dynamic>;
      // BP is manual: reflect whether it was actually recorded, and when.
      _bpRecorded =
          _vitals['bp_logged_at'] != null || _vitals['bp_source'] != null;
      _bpLoggedAt = (_vitals['bp_logged_at'] as String?) ?? '';
      _loading = false;
    });
    _maybeAlertHighRisk();
  }

  String _lastAlertedLevel = '';

  /// High-risk flow: warn the mother once per level change, naming the
  /// reason, so the app never contradicts the engine quietly.
  void _maybeAlertHighRisk() {
    final level = (_risk['risk_level'] as String? ?? 'low').toLowerCase();
    final isHigh = level == 'high' || level == 'critical';
    if (!isHigh || _lastAlertedLevel == level) return;
    _lastAlertedLevel = level;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded,
              color: level == 'critical' ? Colors.red : Colors.orange,
              size: 44),
          title: Text(
              level == 'critical'
                  ? 'Critical Risk Detected'
                  : 'High Risk Detected',
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reason: ${_topFactor}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 12),
              Text(
                (_risk['recommendation'] as String?) ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
    });
  }

  /// Safe title case: an empty or unexpected risk_level must not throw.
  static String _titleCase(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Unknown';
    return t[0].toUpperCase() + t.substring(1);
  }

  static String _shortDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _relativeSync() {
    if (!_hasLive) return 'Not synced - connect band';
    final secs = DateTime.now().difference(_live!.receivedAt).inSeconds;
    if (secs < 5) return 'Live now';
    if (secs < 60) return 'Last synced ${secs}s ago';
    final mins = secs ~/ 60;
    if (mins < 60) return 'Last synced ${mins}m ago';
    return 'Last synced ${mins ~/ 60}h ago';
  }

  void _showRiskDetails() {
    final factors = (_risk['factors'] as List?)?.cast<String>() ?? [];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Text('Why this risk level?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Week $_week  •  score ${_risk['score'] ?? 0}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 14),
            ...factors.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 8, color: Color(0xFFFF2D95)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(f,
                              style: const TextStyle(fontSize: 14, height: 1.4))),
                    ],
                  ),
                )),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (_risk['recommendation'] as String?) ?? '',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logBp() async {
    final sysCtrl = TextEditingController();
    final diaCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record blood pressure'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The wearable does not measure BP. Enter the reading from your '
              'home BP monitor.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sysCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Systolic'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('/'),
                ),
                Expanded(
                  child: TextField(
                    controller: diaCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Diastolic'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D95),
                foregroundColor: Colors.white),
            onPressed: () async {
              final s = int.tryParse(sysCtrl.text.trim());
              final d = int.tryParse(diaCtrl.text.trim());
              if (s == null || d == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter both values')));
                return;
              }
              final profile = await SessionService.loadProfile();
              final res = await ApiService.logBp(
                  profile['patientId'] as String? ?? 'P001', s, d,
                  source: 'external_monitor');
              if (!context.mounted) return;
              if (res != null && res['error'] == null) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text((res?['error'] as String?) ??
                          'Could not save. Check Server IP in Profile.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) _load();
  }

  Color _riskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
      case 'critical':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskLevel =
        (_risk['risk_level'] as String? ?? 'low').toLowerCase();
    final riskColor = _riskColor(riskLevel);
    // Prefer fresh BLE wearable values; fall back to API/mock.
    // Wearable connected but no skin contact (or no packet yet):
    // show a placeholder dash, never a stale or invented number.
    String hrText;
    Color hrColor = Colors.red;
    bool hrLiveDot = false;
    if (_bleState == BleConnState.connected) {
      if (_hasLive && _live!.contact && _live!.heartRate != null) {
        hrText = '${_live!.heartRate} bpm';
        hrLiveDot = true;
      } else {
        hrText = '—';
        hrColor = Colors.grey;
      }
    } else {
      final fallbackHr = _vitals['heart_rate']?.toString() ?? '--';
      hrText = '$fallbackHr bpm';
    }
    final spo2 = _vitals['spo2']?.toString() ?? '--';
    final sys = _vitals['systolic_bp']?.toString() ?? '--';
    final dia = _vitals['diastolic_bp']?.toString() ?? '--';
    final progress = (_week / 40).clamp(0.0, 1.0);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${_name.split(' ').first}!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text('Week $_week • $_age yrs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.pushNamed(context, '/profile');
                      if (mounted) _load();
                    },
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          const Color(0xFFE91E63).withAlpha(25),
                      child: Text(
                        _name.isEmpty ? '?' : _name[0].toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE91E63),
                            fontSize: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFFE91E63),
                    Color(0xFF9C27B0)
                  ]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pregnancy Progress',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Week $_week of 40',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withAlpha(77),
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '${(progress * 100).round()}% complete  •  Due: $_due',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('Current Vitals',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  if (_loading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  if (_loading) const SizedBox(width: 8),
                  // Flexible directly on the chip: wrapping it in a Row and
                  // making that Flexible left the chip with an unbounded
                  // width, so the label ran past the header.
                  Flexible(child: _bleChip()),
                ],
              ),
              const SizedBox(height: 12),
              // Wrap, not GridView.count: a grid needs a fixed aspect ratio,
              // and the height this tile actually wants (~120px) does not fit
              // the ratio that the available width allows. That mismatch is
              // what produced the overflow stripes on the dashboard.
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 12) / 2;
                  Widget tile(Widget child) => SizedBox(
                        width: tileWidth,
                        child: child,
                      );
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      tile(_vitalCard('Heart Rate', hrText, Icons.favorite,
                          hrColor,
                          live: hrLiveDot, source: 'Wearable')),
                      tile(_vitalCard('SpO2', '$spo2%',
                          Icons.water_drop, Colors.blue, source: 'Wearable')),
                      tile(GestureDetector(
                        onTap: _logBp,
                        child: _vitalCard(
                          'Blood Pressure',
                          _bpRecorded ? '$sys/$dia' : 'Not recorded',
                          Icons.monitor_heart,
                          _bpRecorded ? Colors.purple : Colors.grey,
                          source:
                              _bpRecorded ? 'Manual entry' : 'Tap to record',
                          sourceColor:
                              _bpRecorded ? Colors.purple : Colors.orange,
                        ),
                      )),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              // Both labels are Flexible: as unbounded siblings they would
              // overflow the row on a narrow device or at a large text scale.
              Row(
                children: [
                  const Icon(Icons.sync, size: 13, color: Colors.grey),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(_relativeSync(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
                  if (_bpLoggedAt.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.history,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text('BP logged ${_shortDate(_bpLoggedAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: riskColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: riskColor.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: riskColor.withAlpha(51),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.warning_amber,
                          color: riskColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Current risk: ${_titleCase(riskLevel)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: riskColor)),
                          Text(
                              _topFactor,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _showRiskDetails,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Flexible: the label and the chevron are
                                // unbounded Row children, so on a narrow
                                // screen the label ran past the edge.
                                Flexible(
                                  child: Text(
                                    'View Risk Details',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: riskColor),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.chevron_right,
                                    size: 16, color: riskColor),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Quick Actions',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _actionButton(
                      context,
                      'Log\nSymptom',
                      Icons.add_circle_outline,
                      const Color(0xFFE91E63),
                      const SymptomsScreen()),
                  const SizedBox(width: 12),
                  _actionButton(
                      context,
                      'Vitals\nHistory',
                      Icons.monitor_heart_outlined,
                      const Color(0xFF7B1FA2),
                      const VitalsScreen()),
                  const SizedBox(width: 12),
                  _actionButton(
                      context,
                      'Nutrition\nTracker',
                      Icons.restaurant_outlined,
                      Colors.blue,
                      const NutritionScreen()),
                  const SizedBox(width: 12),
                  _actionButton(
                      context,
                      'Reminders',
                      Icons.alarm_outlined,
                      Colors.teal,
                      const RemindersScreen()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bleChip() {
    final connected = _bleState == BleConnState.connected;
    final label = _bleBusy
        ? 'Scanning…'
        : connected
            ? (_hasLive ? 'LIVE' : 'Connected')
            : 'Connect band';
    final color = connected && _hasLive
        ? Colors.green
        : connected
            ? Colors.blue
            : Colors.grey;
    return GestureDetector(
      onTap: _toggleBle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_bleBusy)
              SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color))
            else
              Icon(Icons.bluetooth, size: 14, color: color),
            const SizedBox(width: 4),
            // ConstrainedBox rather than Flexible: a Flexible child of a
            // mainAxisSize.min Row receives no share of the width, which
            // left the label at its full intrinsic width.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 64),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _vitalCard(
      String title, String value, IconData icon, Color color,
      {bool live = false,
      String? source,
      Color? sourceColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
              if (live) ...[
                const SizedBox(width: 4),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
          if (source != null) ...[
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: sourceColor ?? Colors.grey.shade500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _actionButton(BuildContext context, String label,
      IconData icon, Color color, Widget screen) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => screen)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

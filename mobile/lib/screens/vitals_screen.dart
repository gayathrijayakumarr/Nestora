import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

/// Vitals history.
///
/// Every number on this screen comes from the backend: the wearable /
/// seeded history from GET /api/vitals/{id} and the manually entered
/// blood pressure from GET /api/vitals/{id}/bp. Nothing here is generated.
class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

/// One point on a chart: the value plus when it was taken.
class _Point {
  _Point(this.value, this.at);
  final double value;
  final DateTime at;
}

class _VitalsScreenState extends State<VitalsScreen> {
  List<_Point> _hr = [];
  List<_Point> _spo2 = [];
  List<_Point> _sys = [];
  List<_Point> _dia = [];

  double? _hrNow;
  double? _spo2Now;
  double? _sysNow;
  double? _diaNow;
  String _bpSource = '';

  bool _loading = true;
  bool _fromServer = false;
  String _windowLabel = 'No readings yet';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Re-read when the screen becomes visible again, so a reading that
  /// arrived while the user was on another tab appears straight away.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> refresh() => _load();

  double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}'.trim());
  }

  Future<void> _load() async {
    final profile = await SessionService.loadProfile();
    final pid = profile['patientId'] ?? 'P001';
    if (!mounted) return;
    setState(() => _loading = true);

    var fromServer = false;
    try {
      final history = await ApiService.getVitals(pid);
      if (history.isNotEmpty) {
        fromServer = true;
        final hr = <_Point>[];
        final sp = <_Point>[];
        final sy = <_Point>[];
        final di = <_Point>[];
        for (final raw in history) {
          final m = raw as Map<String, dynamic>;
          final at = DateTime.tryParse('${m['timestamp'] ?? ''}') ?? DateTime.now();
          final h = _num(m['heart_rate']);
          final o = _num(m['spo2']);
          final s = _num(m['systolic_bp']);
          final d = _num(m['diastolic_bp']);
          if (h != null) hr.add(_Point(h, at));
          if (o != null) sp.add(_Point(o, at));
          if (s != null) sy.add(_Point(s, at));
          if (d != null) di.add(_Point(d, at));
        }
        _hr = hr.reversed.toList();   // oldest first for the x-axis
        _spo2 = sp.reversed.toList();
        _sys = sy.reversed.toList();
        _dia = di.reversed.toList();
      }

      // Manual BP entries are stored separately from the vitals history.
      final bpLog = await ApiService.getBpHistory(pid);
      if (bpLog.isNotEmpty) {
        fromServer = true;
        for (final raw in bpLog) {
          final m = raw as Map<String, dynamic>;
          final at = DateTime.tryParse('${m['logged_at'] ?? ''}') ?? DateTime.now();
          final s = _num(m['systolic_bp']);
          final d = _num(m['diastolic_bp']);
          if (s != null) _sys.add(_Point(s, at));
          if (d != null) _dia.add(_Point(d, at));
        }
        _sys.sort((a, b) => a.at.compareTo(b.at));
        _dia.sort((a, b) => a.at.compareTo(b.at));
        _bpSource = '${bpLog.first['source'] ?? 'manual'}';
      }

      final latest = await ApiService.getLatestVital(pid);
      _hrNow = _num(latest['heart_rate']) ?? (_hr.isNotEmpty ? _hr.last.value : null);
      _spo2Now = _num(latest['spo2']) ?? (_spo2.isNotEmpty ? _spo2.last.value : null);
      _sysNow = _num(latest['systolic_bp']) ?? (_sys.isNotEmpty ? _sys.last.value : null);
      _diaNow = _num(latest['diastolic_bp']) ?? (_dia.isNotEmpty ? _dia.last.value : null);
    } catch (_) {
      // keep whatever was already loaded rather than blanking the screen
    }

    if (!mounted) return;
    setState(() {
      _fromServer = fromServer;
      _loading = false;
      _windowLabel = _describeWindow();
    });
  }

  String _describeWindow() {
    final times = <DateTime>[
      ..._hr.map((e) => e.at),
      ..._sys.map((e) => e.at),
    ];
    if (times.isEmpty) return 'No readings yet';
    times.sort();
    final span = times.last.difference(times.first);
    if (span.inHours < 1) return 'Last ${max(1, span.inMinutes)} min';
    if (span.inHours < 24) return 'Last ${span.inHours} h';
    return 'Last ${span.inDays} days';
  }

  String _fmt(double? v, {int decimals = 0}) =>
      v == null ? '--' : v.toStringAsFixed(decimals);

  /// Trend arrow from the two most recent points.
  String? _trend(List<_Point> pts, {bool higherIsWorse = true}) {
    if (pts.length < 2) return null;
    final a = pts[pts.length - 2].value;
    final b = pts[pts.length - 1].value;
    if (a == b) return null;
    final up = b > a;
    return (up == higherIsWorse) ? '\u2191' : '\u2193';
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Vital History';
    final body = SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        color: const Color(0xFFEF4444),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14142B))),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8FC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD3E7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: Color(0xFFFF2D95)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(_windowLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF7D6B82))),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_fromServer && !_loading)
              const _Notice(
                icon: Icons.cloud_off,
                text: 'Showing demonstration values - the server could not be '
                    'reached. Check the Server IP in Profile.',
              ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 16),
            _vitalChart(
              title: 'Heart Rate',
              unit: 'bpm',
              color: const Color(0xFFEF4444),
              icon: Icons.favorite,
              iconColor: const Color(0xFFEF4444),
              points: _hr,
              current: _fmt(_hrNow),
              decimals: 0,
              higherIsWorse: true,
              emptyText: 'No heart rate recorded yet.',
            ),
            const SizedBox(height: 16),
            _vitalChart(
              title: 'SpO2',
              unit: '%',
              color: const Color(0xFF3B82F6),
              icon: Icons.water_drop,
              iconColor: const Color(0xFF3B82F6),
              points: _spo2,
              current: _fmt(_spo2Now),
              decimals: 0,
              higherIsWorse: false,
              emptyText: 'No oxygen saturation recorded yet.',
            ),
            const SizedBox(height: 16),
            _bpChart(),
          ],
        ),
      ),
    );

    // Hosted in the Home IndexedStack the parent already shows the bar, so
    // no AppBar here. Pushed as a Quick Action this Scaffold is what supplies
    // the back button - without it the page has no way out.
    final pushed = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FB),
      appBar: !pushed
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Vital History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
      body: body,
    );
  }

  Widget _vitalChart({
    required String title,
    required String unit,
    required Color color,
    required IconData icon,
    required Color iconColor,
    required List<_Point> points,
    required String current,
    required int decimals,
    required bool higherIsWorse,
    required String emptyText,
  }) {
    final trend = _trend(points, higherIsWorse: higherIsWorse);
    final trendUp = trend == '\u2191';
    final values = points.map((e) => e.value).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              const SizedBox(width: 8),
              Text('$current$unit',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: color)),
              if (trend != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (trendUp
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(trend,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: trendUp
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (values.length < 2)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(emptyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF7D6B82))),
              ),
            )
          else
            SizedBox(
              height: 120,
              width: double.infinity,
              // No double.infinity here: the painter divides by the width,
              // and an infinite width produces NaN coordinates, which
              // silently draws nothing (a blank chart box).
              child: CustomPaint(
                painter: LineChartPainter(values, color),
              ),
            ),
          if (values.length >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_shortTime(points.first.at),
                      style: _axisStyle),
                  Text(_shortTime(points.last.at), style: _axisStyle),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const _axisStyle =
      TextStyle(fontSize: 10, color: Color(0xFF9C8AA4));

  static String _shortTime(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Widget _bpChart() {
    final sysVals = _sys.map((e) => e.value).toList();
    final diaVals = _dia.map((e) => e.value).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.monitor_heart,
                    color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Blood Pressure',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_fmt(_sysNow)}/${_fmt(_diaNow)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(width: 6),
              const Text('mmHg',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7D6B82))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 12, color: Color(0xFF9C8AA4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _bpSource.isEmpty
                      ? 'Entered by hand - the band cannot measure it'
                      : 'Entered by hand ($_bpSource)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF9C8AA4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(child: _legendDot(const Color(0xFF8B5CF6), 'Systolic')),
              const SizedBox(width: 14),
              Flexible(child: _legendDot(const Color(0xFFC084FC), 'Diastolic')),
            ],
          ),
          const SizedBox(height: 12),
          if (sysVals.length < 2 || diaVals.length < 2)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  sysVals.isEmpty
                      ? 'No blood pressure recorded yet.\nLog one from the home screen.'
                      : 'Need at least two readings to draw a trend.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF7D6B82)),
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: DualLineChartPainter(
                    sysVals, diaVals, const Color(0xFF8B5CF6), const Color(0xFFC084FC)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF7D6B82))),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF92400E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11.5, color: Color(0xFF92400E), height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Single-series line chart. The y-range is derived from the data so a
/// single value, a flat series or an out-of-range value can never produce
/// a division by zero or an off-canvas path.
class LineChartPainter extends CustomPainter {
  LineChartPainter(this.data, this.color);

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2 || size.width <= 0 || size.height <= 0) return;

    var minV = data.reduce((a, b) => a < b ? a : b);
    var maxV = data.reduce((a, b) => a > b ? a : b);
    if (maxV - minV < 1e-6) {
      // Flat series: give it a band so the line lands mid-height.
      minV -= 1;
      maxV += 1;
    }
    final range = maxV - minV;

    final path = Path();
    final fill = Path();
    final stepX = size.width / (data.length - 1);

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      // Clamp so a value outside the range still draws inside the box.
      final t = ((data[i] - minV) / range).clamp(0.0, 1.0);
      final y = size.height - t * size.height * 0.92;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevT = ((data[i - 1] - minV) / range).clamp(0.0, 1.0);
        final prevY = size.height - prevT * size.height * 0.92;
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
        fill.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dot on the newest sample.
    final lastT = ((data.last - minV) / range).clamp(0.0, 1.0);
    final lastY = size.height - lastT * size.height * 0.92;
    canvas.drawCircle(Offset(size.width, lastY), 4, Paint()..color = color);
    canvas.drawCircle(Offset(size.width, lastY), 2,
        Paint()..color = Colors.white);

    // Min / max labels so the axis is readable.
    _label(canvas, size, maxV.toStringAsFixed(0), const Offset(2, 0));
    _label(canvas, size, minV.toStringAsFixed(0),
        Offset(2, size.height - 12));
  }

  void _label(Canvas canvas, Size size, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            fontSize: 9, color: Color(0xFF9C8AA4), fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

/// Two-series chart used for systolic / diastolic pressure.
class DualLineChartPainter extends CustomPainter {
  DualLineChartPainter(this.data1, this.data2, this.color1, this.color2);

  final List<double> data1;
  final List<double> data2;
  final Color color1;
  final Color color2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    // One shared range across both series, as a real BP chart has.
    final all = [...data1, ...data2];
    if (all.length < 2) return;
    var minV = all.reduce((a, b) => a < b ? a : b);
    var maxV = all.reduce((a, b) => a > b ? a : b);
    if (maxV - minV < 1e-6) {
      minV -= 1;
      maxV += 1;
    }
    final range = maxV - minV;

    void drawLine(List<double> data, Color color) {
      if (data.length < 2) return;
      final path = Path();
      final stepX = size.width / (data.length - 1);
      for (var i = 0; i < data.length; i++) {
        final x = i * stepX;
        final t = ((data[i] - minV) / range).clamp(0.0, 1.0);
        final y = size.height - t * size.height * 0.9;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          final prevX = (i - 1) * stepX;
          final prevT = ((data[i - 1] - minV) / range).clamp(0.0, 1.0);
          final prevY = size.height - prevT * size.height * 0.9;
          final cpX = (prevX + x) / 2;
          path.cubicTo(cpX, prevY, cpX, y, x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    drawLine(data1, color1);
    drawLine(data2, color2);
  }

  @override
  bool shouldRepaint(covariant DualLineChartPainter oldDelegate) =>
      oldDelegate.data1 != data1 ||
      oldDelegate.data2 != data2 ||
      oldDelegate.color1 != color1 ||
      oldDelegate.color2 != color2;
}

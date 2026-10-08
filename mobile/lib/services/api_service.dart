import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_service.dart';

/// API layer with offline fallback.
///
/// Tries the backend (emulator localhost mapping). Every call has a short
/// timeout and on any failure returns local fallback data so the app stays
/// fully functional on a physical device without the backend running.
class ApiService {
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';
  static String _customBase = '';

  /// Call once at startup (and after profile save): picks up a LAN IP
  /// entered on the Profile screen so physical phones can reach the PC.
  static Future<void> loadBase() async {
    final ip = await SessionService.loadServerIp();
    _customBase = ip.isEmpty ? '' : 'http://$ip:8000';
  }

  static String get baseUrl =>
      _customBase.isEmpty ? defaultBaseUrl : _customBase;

  static const Map<String, dynamic> fallbackVitals = {
    'heart_rate': 82,
    'spo2': 97,
    'temperature': 36.8,
    'systolic_bp': 120,
    'diastolic_bp': 80,
  };

  static const Map<String, dynamic> fallbackRisk = {
    'risk_level': 'medium',
    'score': 45,
    'factors': ['Elevated BP trend'],
    'recommendation': 'AI detected elevated BP trend. Consult your doctor.',
  };

  static const Map<String, dynamic> fallbackNutrition = {
    'daily_calories': {'target': 2200, 'consumed': 1700},
    'water_glasses': 6,
    'water_target': 8,
  };

  static Future<dynamic> _get(String path) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) return json.decode(res.body);
    } catch (_) {
      // offline -> caller uses fallback
    }
    return null;
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl$path'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(body))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return json.decode(res.body);
      }
    } catch (_) {
      // offline -> caller keeps local state
    }
    return null;
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .put(Uri.parse('$baseUrl$path'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(body))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) return json.decode(res.body);
    } catch (_) {
      // offline -> caller keeps local state
    }
    return null;
  }

  static Future<Map<String, dynamic>> getPatient(String patientId) async {
    final data = await _get('/api/patients/$patientId');
    if (data is Map<String, dynamic> && data['id'] != null) {
      return Map<String, dynamic>.from(data);
    }
    return {
      'id': patientId,
      'name': 'Priya Sharma',
      'gestational_week': 28,
      'due_date': '2026-09-15',
    };
  }

  static Future<List<dynamic>> getVitals(String patientId) async {
    final data = await _get('/api/vitals/$patientId');
    if (data is List && data.isNotEmpty) return data;
    return [Map<String, dynamic>.from(fallbackVitals)];
  }

  static Future<Map<String, dynamic>> getLatestVital(String patientId) async {
    final data = await _get('/api/vitals/$patientId/latest');
    if (data is Map<String, dynamic> && data['heart_rate'] != null) {
      return Map<String, dynamic>.from(data);
    }
    return Map<String, dynamic>.from(fallbackVitals);
  }

  /// Manually entered BP history (GET /api/vitals/{id}/bp).
  static Future<List<dynamic>> getBpHistory(String patientId) async {
    final data = await _get('/api/vitals/$patientId/bp');
    if (data is List) return data;
    return const [];
  }

  static Future<Map<String, dynamic>> getRisk(String patientId) async {
    final data = await _get('/api/risk/$patientId');
    if (data is Map<String, dynamic> && data['risk_level'] != null) {
      return Map<String, dynamic>.from(data);
    }
    return Map<String, dynamic>.from(fallbackRisk);
  }

  static Future<List<dynamic>> getSymptoms(String patientId) async {
    final data = await _get('/api/symptoms/$patientId');
    if (data is List) return data;
    return [];
  }

  static Future<Map<String, dynamic>?> postSymptom(
      Map<String, dynamic> body) async {
    final data = await _post('/api/symptoms/', body);
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    return null;
  }

  static Future<List<dynamic>> getReminders(String patientId) async {
    final data = await _get('/api/reminders/$patientId');
    if (data is List) return data;
    return [];
  }

  static Future<Map<String, dynamic>?> postReminder(
      Map<String, dynamic> body) async {
    final data = await _post('/api/reminders/', body);
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    return null;
  }

  static Future<void> putReminder(String id, bool completed) async {
    await _put('/api/reminders/$id', {'completed': completed});
  }

  static Future<Map<String, dynamic>> getNutrition(String patientId) async {
    final data = await _get('/api/nutrition/$patientId');
    if (data is Map<String, dynamic> && data.isNotEmpty) {
      return Map<String, dynamic>.from(data);
    }
    return Map<String, dynamic>.from(fallbackNutrition);
  }

  /// Gateway POST: forward a BLE wearable reading to the backend.
  /// Best-effort; offline failures are silently ignored (local UI
  /// already shows the live values).
  static Future<void> postLiveVitals(Map<String, dynamic> body) async {
    await _post('/api/vitals/live', body);
  }

  // ── Auth ────────────────────────────────────────────────────────────────
  /// Enrolment-gated login. Returns {ok, error} or {ok:true, patient...}.
  static Future<Map<String, dynamic>> login(String name, String phone) async {
    final data = await _post('/api/auth/login',
        {'name': name, 'phone': phone});
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    return {
      'ok': false,
      'error': 'Could not reach the server. Check the Server IP in Profile.'
    };
  }

  // ── Manual BP ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> logBp(String patientId, int sysBp,
      int diaBp, {String source = 'manual'}) async {
    final data = await _post('/api/vitals/$patientId/bp', {
      'systolic_bp': sysBp,
      'diastolic_bp': diaBp,
      'source': source,
    });
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    return null;
  }

  // ── Week-based nutrition ────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getNutritionGuide(String patientId) async {
    final data = await _get('/api/nutrition/$patientId');
    if (data is Map<String, dynamic> && data['meals'] != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }
}

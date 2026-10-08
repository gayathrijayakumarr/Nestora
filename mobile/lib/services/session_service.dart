import 'package:shared_preferences/shared_preferences.dart';

/// Local session + profile store. Keeps login persistent and powers
/// the profile screen. Patient id defaults to the backend mock id P001.
class SessionService {
  static const _kName = 'profile_name';
  static const _kPhone = 'profile_phone';
  static const _kWeek = 'profile_week';
  static const _kDue = 'profile_due';
  static const _kEmergency = 'profile_emergency';
  static const _kPatientId = 'patient_id';
  static const _kAge = 'profile_age';
  static const _kBloodGroup = 'profile_blood_group';
  static const _kServerIp = 'server_ip';

  static Future<void> saveProfile({
    required String name,
    required String phone,
    int week = 28,
    String due = 'Sep 15, 2026',
    String emergency = '',
    int age = 27,
    String bloodGroup = '',
    String patientId = 'P001',
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, name);
    await p.setString(_kPhone, phone);
    await p.setInt(_kWeek, week);
    await p.setString(_kDue, due);
    await p.setString(_kEmergency, emergency);
    await p.setInt(_kAge, age);
    await p.setString(_kBloodGroup, bloodGroup);
    await p.setString(_kPatientId, patientId);
  }

  static Future<Map<String, dynamic>> loadProfile() async {
    final p = await SharedPreferences.getInstance();
    return {
      'name': p.getString(_kName) ?? '',
      'phone': p.getString(_kPhone) ?? '',
      'week': p.getInt(_kWeek) ?? 28,
      'due': p.getString(_kDue) ?? 'Sep 15, 2026',
      'emergency': p.getString(_kEmergency) ?? '',
      'age': p.getInt(_kAge) ?? 27,
      'bloodGroup': p.getString(_kBloodGroup) ?? '',
      'patientId': p.getString(_kPatientId) ?? 'P001',
    };
  }

  static Future<bool> isLoggedIn() async {    final p = await SharedPreferences.getInstance();
    final name = p.getString(_kName) ?? '';
    final phone = p.getString(_kPhone) ?? '';
    return name.isNotEmpty && phone.isNotEmpty;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }

  /// Backend LAN IP for physical devices (emulator uses 10.0.2.2).
  static Future<String> loadServerIp() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kServerIp) ?? '';
  }

  static Future<void> saveServerIp(String ip) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kServerIp, ip.trim());
  }
}

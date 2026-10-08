import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Wearable reading from NESTORA-V1 (ESP32-S3).
/// Nullable where the sensor cannot produce a value (null != zero).
class WearableVitals {
  final String deviceId;
  final int timestamp;
  final int? heartRate;
  final int? heartRateAvg;
  final int? spo2;
  final int steps;
  final String activity;
  final double movement;
  final int restSeconds;
  final bool contact;
  final int signalQuality;
  final bool fallCandidate;
  final DateTime receivedAt;

  WearableVitals({
    required this.deviceId,
    required this.timestamp,
    required this.heartRate,
    required this.heartRateAvg,
    required this.spo2,
    required this.steps,
    required this.activity,
    required this.movement,
    required this.restSeconds,
    required this.contact,
    required this.signalQuality,
    required this.fallCandidate,
    required this.receivedAt,
  });

  factory WearableVitals.fromJson(Map<String, dynamic> j) {
    int? asInt(dynamic v) =>
        v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    return WearableVitals(
      deviceId: (j['device_id'] as String?) ?? 'NESTORA-V1-001',
      timestamp: (j['timestamp'] as num?)?.toInt() ?? 0,
      heartRate: asInt(j['heart_rate']),
      heartRateAvg: asInt(j['heart_rate_avg']),
      spo2: asInt(j['spo2']),
      steps: (j['steps'] as num?)?.toInt() ?? 0,
      activity: (j['activity'] as String?) ?? 'UNKNOWN',
      movement: (j['movement'] as num?)?.toDouble() ?? 0.0,
      restSeconds: (j['rest_seconds'] as num?)?.toInt() ?? 0,
      contact: (j['contact'] as bool?) ?? false,
      signalQuality: (j['signal_quality'] as num?)?.toInt() ?? 0,
      fallCandidate: (j['fall_candidate'] as bool?) ?? false,
      receivedAt: DateTime.now(),
    );
  }

  /// Body for POST /api/vitals/live (gateway role: phone -> backend).
  ///
  /// SpO2 is deliberately NOT forwarded: the wearable's SpO2 is not yet
  /// clinically validated (it pegs 96-100), and feeding it into the risk
  /// engine produced false HIGH/CRITICAL escalation from mock BP.
  Map<String, dynamic> toLivePost(String patientId) => {
        'patient_id': patientId,
        'device_id': deviceId,
        'timestamp': timestamp,
        'heart_rate': heartRate,
        'heart_rate_avg': heartRateAvg,
        'steps': steps,
        'activity': activity,
        'movement': movement,
        'rest_seconds': restSeconds,
        'contact': contact,
        'signal_quality': signalQuality,
        'fall_candidate': fallCandidate,
      };
}

/// BLE gateway: phone is the ONLY BLE client.
/// Flow: ESP32 -> (BLE notify) -> here -> POST /api/vitals/live.
class BleGateway {
  static const String deviceName = 'Nestora-V1';
  static const String serviceUuid = '7e570001-7e57-4e57-9e57-7e5700000001';
  static const String vitalsCharUuid = '7e570002-7e57-4e57-9e57-7e5700000002';

  /// Demo mapping: this prototype wearable belongs to P001.
  static const String demoPatientId = 'P001';

  final StreamController<WearableVitals> _ctrl =
      StreamController<WearableVitals>.broadcast();
  Stream<WearableVitals> get stream => _ctrl.stream;

  final StreamController<BleConnState> _stateCtrl =
      StreamController<BleConnState>.broadcast();
  Stream<BleConnState> get stateStream => _stateCtrl.stream;

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  WearableVitals? latest;
  BleConnState state = BleConnState.idle;

  void _setState(BleConnState s) {
    state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  /// Scan up to [timeout] for Nestora-V1 and connect. Returns true on success.
  Future<bool> connect({Duration timeout = const Duration(seconds: 10)}) async {
    if (_device != null) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      _setState(BleConnState.scanning);
      if (await FlutterBluePlus.isSupported == false) {
        _setState(BleConnState.unavailable);
        return false;
      }
      await FlutterBluePlus.startScan(timeout: timeout);
      BluetoothDevice? found;
      await for (final r in FlutterBluePlus.scanResults) {
        for (final res in r) {
          final name = res.device.platformName.isNotEmpty
              ? res.device.platformName
              : res.advertisementData.advName;
          if (name == deviceName) {
            found = res.device;
            break;
          }
        }
        if (found != null) break;
      }
      await FlutterBluePlus.stopScan();
      if (found == null) {
        _setState(BleConnState.notFound);
        return false;
      }
      _setState(BleConnState.connecting);
      await found.connect(
          license: License.nonprofit,
          timeout: const Duration(seconds: 10));
      _device = found;

      final services = await found.discoverServices();
      BluetoothCharacteristic? vitalsChar;
      for (final s in services) {
        if (s.uuid.toString().toLowerCase() != serviceUuid) continue;
        for (final c in s.characteristics) {
          if (c.uuid.toString().toLowerCase() == vitalsCharUuid) {
            vitalsChar = c;
          }
        }
      }
      if (vitalsChar == null) {
        await disconnect();
        _setState(BleConnState.notFound);
        return false;
      }
      await vitalsChar.setNotifyValue(true);
      _notifySub = vitalsChar.onValueReceived.listen(_onBytes);
      _connSub = found.connectionState.listen((cs) {
        if (cs == BluetoothConnectionState.disconnected) {
          _device = null;
          _setState(BleConnState.disconnected);
        }
      });
      _setState(BleConnState.connected);
      return true;
    } catch (_) {
      await disconnect();
      _setState(BleConnState.notFound);
      return false;
    }
  }

  void _onBytes(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      final j = json.decode(text);
      if (j is Map<String, dynamic>) {
        latest = WearableVitals.fromJson(j);
        if (!_ctrl.isClosed) _ctrl.add(latest!);
      }
    } catch (_) {
      // Ignore malformed/truncated notifies; next second brings a new one.
    }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    _notifySub = null;
    _connSub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    if (state != BleConnState.idle) _setState(BleConnState.idle);
  }

  void dispose() {
    disconnect();
    _ctrl.close();
    _stateCtrl.close();
  }
}

enum BleConnState {
  idle,
  scanning,
  connecting,
  connected,
  disconnected,
  notFound,
  unavailable,
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A configurable daily reminder slot (morning / midday / evening).
class NotifSlot {
  final String key; // 'morning' | 'midday' | 'evening'
  bool enabled;
  int hour;
  int minute;

  NotifSlot({required this.key, this.enabled = true, required this.hour, this.minute = 0});

  Map<String, Object?> toJson() => {'key': key, 'enabled': enabled, 'hour': hour, 'minute': minute};

  factory NotifSlot.fromJson(Map<String, dynamic> j) => NotifSlot(
        key: j['key'] as String? ?? 'morning',
        enabled: (j['enabled'] as bool?) ?? true,
        hour: j['hour'] as int? ?? 8,
        minute: j['minute'] as int? ?? 0,
      );
}

/// Persisted user settings in SharedPreferences.
class SettingsStore {
  static const _kLang = 'settings.lang';
  static const _kTheme = 'settings.theme';
  static const _kLockEnabled = 'settings.lockEnabled';
  static const _kPinHash = 'settings.pinHash';
  static const _kUseBiometrics = 'settings.useBiometrics';
  static const _kDemoAdded = 'settings.demoAdded';
  static const _kDemoSeen = 'settings.demoSeen';
  static const _kLastPayment = 'settings.lastPayment';
  static const _kNotifEnabled = 'settings.notifEnabled';
  static const _kNotifSlots = 'settings.notifSlots';

  String lang = 'fr';
  String theme = 'system'; // light | dark | system
  bool lockEnabled = false;
  bool useBiometrics = false;
  bool demoAdded = false;
  bool demoSeen = false;
  String? pinHash;
  String lastPayment = 'cash';
  bool notifEnabled = false;
  List<NotifSlot> notifSlots = [
    NotifSlot(key: 'morning', hour: 8),
    NotifSlot(key: 'midday', hour: 11),
    NotifSlot(key: 'evening', hour: 18),
  ];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    lang = p.getString(_kLang) ?? 'fr';
    theme = p.getString(_kTheme) ?? 'system';
    lockEnabled = p.getBool(_kLockEnabled) ?? false;
    useBiometrics = p.getBool(_kUseBiometrics) ?? false;
    demoAdded = p.getBool(_kDemoAdded) ?? false;
    demoSeen = p.getBool(_kDemoSeen) ?? false;
    pinHash = p.getString(_kPinHash);
    lastPayment = p.getString(_kLastPayment) ?? 'cash';
    notifEnabled = p.getBool(_kNotifEnabled) ?? false;
    final rawSlots = p.getString(_kNotifSlots);
    if (rawSlots != null && rawSlots.isNotEmpty) {
      try {
        final list = (jsonDecode(rawSlots) as List).cast<Map<String, dynamic>>();
        notifSlots = list.map(NotifSlot.fromJson).toList();
      } catch (_) {
        // fall back to defaults
      }
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLang, lang);
    await p.setString(_kTheme, theme);
    await p.setBool(_kLockEnabled, lockEnabled);
    await p.setBool(_kUseBiometrics, useBiometrics);
    await p.setBool(_kDemoAdded, demoAdded);
    await p.setBool(_kDemoSeen, demoSeen);
    await p.setString(_kLastPayment, lastPayment);
    await p.setBool(_kNotifEnabled, notifEnabled);
    await p.setString(_kNotifSlots, jsonEncode(notifSlots.map((s) => s.toJson()).toList()));
    if (pinHash != null) {
      await p.setString(_kPinHash, pinHash!);
    } else {
      await p.remove(_kPinHash);
    }
  }

  void setLang(String v) {
    lang = v;
    save();
  }

  void setTheme(String v) {
    theme = v;
    save();
  }

  void setLockEnabled(bool v) {
    lockEnabled = v;
    save();
  }

  void setUseBiometrics(bool v) {
    useBiometrics = v;
    save();
  }

  void setPin(String? hash) {
    pinHash = hash;
    save();
  }

  void setDemoAdded(bool v) {
    demoAdded = v;
    save();
  }

  void setDemoSeen(bool v) {
    demoSeen = v;
    save();
  }

  void setLastPayment(String v) {
    lastPayment = v;
    save();
  }

  void setNotifEnabled(bool v) {
    notifEnabled = v;
    save();
  }

  void setSlot(int index, {bool? enabled, int? hour, int? minute}) {
    if (index < 0 || index >= notifSlots.length) return;
    final slot = notifSlots[index];
    notifSlots[index] = NotifSlot(
      key: slot.key,
      enabled: enabled ?? slot.enabled,
      hour: hour ?? slot.hour,
      minute: minute ?? slot.minute,
    );
    save();
  }

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;
}

String sha256Hex(String input) {
  var msg = input.codeUnits.toList();
  final ml = msg.length * 8;
  msg.addAll(const [0x80]);
  while (msg.length % 64 != 56) {
    msg.add(0);
  }
  final mlBytes = <int>[];
  for (var i = 7; i >= 0; i--) {
    mlBytes.add((ml >> (i * 8)) & 0xff);
  }
  msg.addAll(mlBytes);

  var h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a,
      h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

  final k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  final w = List<int>.filled(64, 0);
  for (final chunkStart in _steps(msg.length ~/ 64)) {
    final chunk = msg.sublist(chunkStart * 64, chunkStart * 64 + 64);
    for (var i = 0; i < 16; i++) {
      w[i] = (chunk[i * 4] << 24) | (chunk[i * 4 + 1] << 16) | (chunk[i * 4 + 2] << 8) | chunk[i * 4 + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final t1 = (h + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      h = g; g = f; f = e; e = (d + t1) & 0xffffffff;
      d = c; c = b; b = a; a = (t1 + t2) & 0xffffffff;
    }
    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }
  return [h0, h1, h2, h3, h4, h5, h6, h7]
      .map((v) => v.toRadixString(16).padLeft(8, '0'))
      .join();
}

Iterable<int> _steps(int n) => List.generate(n, (i) => i);

int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xffffffff;
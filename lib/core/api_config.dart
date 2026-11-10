import 'package:shared_preferences/shared_preferences.dart';

/// Backend base — production HTTPS API.
/// Override via [save] (Settings) if needed for local debug.
abstract final class ApiConfig {
  /// `--dart-define=API_HOST=10.x.x.x:4000` → local; else production.
  static const String _apiHostDefine = String.fromEnvironment('API_HOST');
  static const String defaultHost = _apiHostDefine != ''
      ? _apiHostDefine
      : 'mt5-api.blackossoftwaresolution.in';

  /// White-label broker search filter.
  /// Oceana app defaults to `oceana` (FP Trades never listed).
  static const String brokerApp = String.fromEnvironment(
    'BROKER_APP',
    defaultValue: 'oceana',
  );

  static const String _key = 'server_host_v2';
  static const String _legacyKey = 'server_host';

  /// True if this broker row should show in Find-broker for this APK build.
  static bool isBrokerVisibleInApp({
    required String code,
    required String displayName,
  }) {
    final flavor = brokerApp.trim().toLowerCase();
    final c = code.trim().toUpperCase();
    final n = displayName.trim().toLowerCase();
    final isOceana = c.contains('OCEANA') || n.contains('oceana');
    final isFp =
        c == 'BLACKOS' ||
        c.contains('FPTRADE') ||
        c.contains('FP_TRADE') ||
        c.contains('FP ') ||
        n.contains('fptrade') ||
        n.contains('fp trade') ||
        n.contains('fp trades') ||
        n == 'fp';
    // Oceana APK: only Oceana — never FP / BlackOS.
    if (flavor.isEmpty ||
        flavor == 'oceana' ||
        flavor == 'oceanaprofx') {
      return isOceana && !isFp;
    }
    if (flavor == 'fptrades' || flavor == 'fp' || flavor == 'fptrade') {
      return isFp;
    }
    return false;
  }

  /// UI server label from broker brand (Oceana / FP / …). Never API host.
  /// Demo → "{Brand}-Demo", live → "{Brand}" (no "-Live" badge text).
  static String serverNameFor(
    String accountType, {
    String? brokerDisplayName,
  }) {
    final brand = _brandLabel(brokerDisplayName);
    final demo = accountType.toLowerCase().contains('demo');
    return demo ? '$brand-Demo' : brand;
  }

  /// Settings / About when no session — generic, not a specific broker.
  static String get publicServerLabel => 'Trading Server';

  static String _brandLabel(String? brokerDisplayName) {
    final b = (brokerDisplayName ?? '').trim();
    if (b.isNotEmpty) return b;
    return publicServerLabel;
  }

  static String host = defaultHost;

  /// Strip hosts / URLs from any error text before UI display.
  static String scrubMessage(String raw) {
    var msg = raw.trim();
    msg = msg.replaceFirst(RegExp(r'^Exception:\s*'), '');
    msg = msg.replaceFirst(RegExp(r'^ApiException:\s*'), '');
    msg = msg.replaceFirst(RegExp(r'^SocketException:\s*'), '');
    msg = msg.replaceFirst(RegExp(r'^HttpException:\s*'), '');
    msg = msg.replaceFirst(RegExp(r'^ClientException:\s*'), '');

    final patterns = <RegExp>[
      RegExp(r'https?://[^\s,;]+', caseSensitive: false),
      RegExp(r'wss?://[^\s,;]+', caseSensitive: false),
      if (host.trim().isNotEmpty)
        RegExp(RegExp.escape(host), caseSensitive: false),
      RegExp(RegExp.escape(defaultHost), caseSensitive: false),
      RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b'),
      RegExp(r'Failed host lookup:\s*[^\s,;]+', caseSensitive: false),
      RegExp(r'Connection refused[^\n]*', caseSensitive: false),
      RegExp(r'Network is unreachable[^\n]*', caseSensitive: false),
    ];
    for (final p in patterns) {
      msg = msg.replaceAll(p, '');
    }

    msg = msg.replaceAll(
      RegExp(r'Server not reachable\s*:?\s*', caseSensitive: false),
      'Unable to connect to server',
    );
    msg = msg.replaceAll(RegExp(r'\s{2,}'), ' ');
    msg = msg.replaceAll(RegExp(r'\s+([,;:.])'), r'$1').trim();
    if (msg.isEmpty || msg == ':' || msg == '-' || msg == '.') {
      return 'Something went wrong. Please try again.';
    }
    return msg;
  }

  /// SnackBars / dialogs: never show raw API host.
  static String userFacingError(Object error) => scrubMessage('$error');

  /// Local/LAN hosts stay on http/ws; production domain uses https/wss.
  static bool get useTls {
    final h = host.toLowerCase();
    if (h.startsWith('localhost') ||
        h.startsWith('127.') ||
        h.startsWith('10.') ||
        h.startsWith('192.168.') ||
        h.startsWith('172.')) {
      return false;
    }
    return true;
  }

  static String get httpBase =>
      '${useTls ? 'https' : 'http'}://$host/api';

  static String get wsUrl =>
      '${useTls ? 'wss' : 'ws'}://$host/ws/market';

  /// Absolute URL for a path that starts with `/` (e.g. APK downloads).
  static String absoluteUrl(String path) =>
      '${useTls ? 'https' : 'http'}://$host$path';

  static Future<void> load() async {
    // Local/debug host from flutter run --dart-define wins over prefs.
    if (_apiHostDefine.isNotEmpty) {
      host = _normalizeHost(_apiHostDefine);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.trim().isNotEmpty) {
      host = _normalizeHost(saved);
      return;
    }
    // Migrate off old LAN default so the app actually hits production.
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null &&
        legacy.trim().isNotEmpty &&
        !_isLegacyLanHost(legacy)) {
      host = _normalizeHost(legacy);
      await prefs.setString(_key, host);
      return;
    }
    host = defaultHost;
    await prefs.setString(_key, host);
  }

  static Future<void> save(String value) async {
    host = value.trim().isEmpty ? defaultHost : _normalizeHost(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, host);
  }

  static String _normalizeHost(String raw) {
    var v = raw.trim();
    v = v.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    v = v.replaceFirst(RegExp(r'^wss?://', caseSensitive: false), '');
    if (v.endsWith('/')) v = v.substring(0, v.length - 1);
    // Strip accidental /api suffix if pasted as full URL.
    if (v.toLowerCase().endsWith('/api')) {
      v = v.substring(0, v.length - 4);
    }
    return v;
  }

  static bool _isLegacyLanHost(String raw) {
    final h = _normalizeHost(raw).toLowerCase();
    return h.contains('172.30.') ||
        h.endsWith(':4000') ||
        h.startsWith('192.168.') ||
        h.startsWith('10.');
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => ApiConfig.scrubMessage(message);
}

/// Login succeeded but email is not verified — show verify screen (Trade-Portal).
class EmailNotVerifiedException implements Exception {
  EmailNotVerifiedException(this.email);
  final String email;
  @override
  String toString() => 'Please verify your email first';
}

class Session {
  const Session({
    required this.token,
    required this.accountId,
    required this.accountNumber,
    required this.accountType,
    required this.sessionType,
    this.name = '',
    this.refreshToken = '',
    this.source = 'server',
    this.brokerCode = '',
    this.brokerDisplayName = '',
  });

  /// 'server' = broker trading account, 'mq' = MetaQuotes demo.
  final String source;

  final String token;
  final String accountId;
  final String accountNumber;
  final String accountType;
  final String sessionType;

  /// Broker brand from backend (Oceana Pro FX, FP Trades, …).
  final String brokerCode;
  final String brokerDisplayName;

  /// true jab account_type demo ho (live accounts pe false).
  bool get isDemo {
    final t = accountType.trim().toLowerCase();
    if (t.isEmpty) return false;
    return t.contains('demo');
  }

  /// Watch / investor (read-only) password login.
  bool get isWatchSession => sessionType.toUpperCase() == 'WATCH';

  /// Sidebar / settings server line (no API host).
  String get serverLabel => ApiConfig.serverNameFor(
    accountType,
    brokerDisplayName: brokerDisplayName,
  );

  /// Account holder ka naam (sidebar me number ki jagah dikhta hai).
  final String name;

  /// Long-lived (30 din) refresh token — access token (12h) expire
  /// hone pe app isse chup chaap naya session le leta hai. Purane
  /// stored sessions me ye khali hoga; wo ek baar logout honge.
  final String refreshToken;

  Session copyWith({
    String? token,
    String? refreshToken,
    String? name,
    String? brokerCode,
    String? brokerDisplayName,
  }) {
    return Session(
      token: token ?? this.token,
      accountId: accountId,
      accountNumber: accountNumber,
      accountType: accountType,
      sessionType: sessionType,
      name: name ?? this.name,
      refreshToken: refreshToken ?? this.refreshToken,
      source: source,
      brokerCode: brokerCode ?? this.brokerCode,
      brokerDisplayName: brokerDisplayName ?? this.brokerDisplayName,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'token': token,
    'accountId': accountId,
    'accountNumber': accountNumber,
    'accountType': accountType,
    'sessionType': sessionType,
    'name': name,
    'refreshToken': refreshToken,
    'brokerCode': brokerCode,
    'brokerDisplayName': brokerDisplayName,
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    token: j['token'] as String,
    accountId: j['accountId'] as String,
    accountNumber: j['accountNumber'] as String? ?? '',
    accountType: j['accountType'] as String? ?? '',
    sessionType: j['sessionType'] as String? ?? 'TRADE',
    name: j['name'] as String? ?? '',
    refreshToken: j['refreshToken'] as String? ?? '',
    source: j['source'] as String? ?? 'server',
    brokerCode: j['brokerCode'] as String? ?? '',
    brokerDisplayName: j['brokerDisplayName'] as String? ?? '',
  );
}

/// Public broker row for Find-broker search (no auth).
class PublicBroker {
  const PublicBroker({
    required this.id,
    required this.code,
    required this.displayName,
    this.legalName = '',
    this.logoUrl = '',
    this.primaryColor = '#0066FF',
    this.portalHosts = const [],
  });

  final String id;
  final String code;
  final String displayName;
  final String legalName;
  final String logoUrl;
  final String primaryColor;
  final List<String> portalHosts;

  String get subtitle {
    if (portalHosts.isNotEmpty) return portalHosts.first;
    if (legalName.trim().isNotEmpty && legalName != displayName) {
      return legalName;
    }
    return 'Login to trading account';
  }

  factory PublicBroker.fromJson(Map<String, dynamic> j) => PublicBroker(
    id: '${j['id'] ?? ''}',
    code: '${j['code'] ?? ''}',
    displayName: '${j['displayName'] ?? j['code'] ?? ''}',
    legalName: '${j['legalName'] ?? ''}',
    logoUrl: '${j['logoUrl'] ?? ''}',
    primaryColor: '${j['primaryColor'] ?? '#0066FF'}',
    portalHosts: [
      for (final h in (j['portalHosts'] as List? ?? const [])) '$h',
    ],
  );
}

/// Phone me yaad rakha hua FP Trades account (Manage Accounts card).
/// Password sirf tab hota hai jab login pe "Save password" ON tha.
class SavedFpAccount {
  const SavedFpAccount({
    required this.accountNumber,
    this.name = '',
    this.accountType = '',
    this.password = '',
    this.balance = 0,
    this.lastLogin,
    this.brokerCode = '',
    this.brokerDisplayName = '',
  });

  final String accountNumber;
  final String name;
  final String accountType;
  final String password;
  final double balance;
  final DateTime? lastLogin;
  final String brokerCode;
  final String brokerDisplayName;

  bool get isDemo => accountType.toLowerCase().contains('demo');

  String get brandLabel {
    final b = brokerDisplayName.trim();
    if (b.isNotEmpty) return b;
    return ApiConfig.publicServerLabel;
  }

  String get serverLabel => ApiConfig.serverNameFor(
    accountType,
    brokerDisplayName: brokerDisplayName,
  );

  SavedFpAccount copyWith({
    String? name,
    String? accountType,
    String? password,
    double? balance,
    DateTime? lastLogin,
    String? brokerCode,
    String? brokerDisplayName,
  }) => SavedFpAccount(
    accountNumber: accountNumber,
    name: name ?? this.name,
    accountType: accountType ?? this.accountType,
    password: password ?? this.password,
    balance: balance ?? this.balance,
    lastLogin: lastLogin ?? this.lastLogin,
    brokerCode: brokerCode ?? this.brokerCode,
    brokerDisplayName: brokerDisplayName ?? this.brokerDisplayName,
  );

  Map<String, dynamic> toJson() => {
    'accountNumber': accountNumber,
    'name': name,
    'accountType': accountType,
    'password': password,
    'balance': balance,
    'lastLogin': lastLogin?.toIso8601String(),
    'brokerCode': brokerCode,
    'brokerDisplayName': brokerDisplayName,
  };

  factory SavedFpAccount.fromJson(Map<String, dynamic> j) => SavedFpAccount(
    accountNumber: '${j['accountNumber'] ?? ''}',
    name: '${j['name'] ?? ''}',
    accountType: '${j['accountType'] ?? ''}',
    password: '${j['password'] ?? ''}',
    balance: (j['balance'] as num?)?.toDouble() ?? 0,
    lastLogin: DateTime.tryParse('${j['lastLogin'] ?? ''}'),
    brokerCode: '${j['brokerCode'] ?? ''}',
    brokerDisplayName: '${j['brokerDisplayName'] ?? ''}',
  );
}

int digitsFor(String symbol, double price) {
  final s = symbol.toUpperCase();
  if (s.contains('JPY') || s.contains('RUB')) return 3;
  if (s.contains('XAU') || s.contains('GOLD')) return 2;
  if (s.contains('XAG') || s.contains('SILVER')) return 3;
  // MT5 har symbol ki apni digits use karta hai: BTC/indices
  // jaisi badi कीमतon pe 2, warna EURUSD jaiso pe 5.
  if (price >= 1000) return 2;
  if (price >= 100) return 3;
  return 5;
}

class LiveQuote {
  LiveQuote(this.symbol);
  final String symbol;
  double bid = 0;
  double ask = 0;
  double prevBid = 0;
  double dayOpen = 0;
  double dayHigh = 0;
  double dayLow = 0;
  double dayClose = 0;
  /// Session bid/ask extremes (Market Statistics).
  double bidHigh = 0;
  double bidLow = 0;
  double askHigh = 0;
  double askLow = 0;
  DateTime? time;

  int get digits => digitsFor(symbol, bid);
  bool get hasPrice => bid > 0 && ask > 0;
  bool get priceUp => bid >= prevBid;

  /// MT5 daily change vs day's open (fallback: prev close).
  double get _ref => dayOpen > 0 ? dayOpen : dayClose;
  double get changeDelta => _ref > 0 ? bid - _ref : 0;
  int get changePoints =>
      _ref > 0 ? (changeDelta * _pow10(digits)).round() : 0;
  double get changePct => _ref > 0 ? changeDelta / _ref * 100 : 0;
  bool get changeUp => changeDelta >= 0;
  int get spreadPoints => hasPrice ? ((ask - bid) * _pow10(digits)).round() : 0;

  /// Quotes row: forex → integer points (`-127`); BTC/gold/indices →
  /// price delta (`-530.17`) so huge point counts na dikhen.
  String get changeLabel {
    if (_ref <= 0 || bid <= 0) return '0 0.00%';
    final d = digits;
    final delta = changeDelta;
    final pct = changePct;
    final String left;
    if (d >= 4) {
      final pts = (delta * _pow10(d)).round();
      left = pts > 0 ? '+$pts' : '$pts';
    } else {
      left = '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(d)}';
    }
    // MT5: `+99 0.06%` / `-127 -0.11%` — + sirf left pe jab positive.
    final right = '${pct.toStringAsFixed(2)}%';
    return '$left $right';
  }

  void noteTick(double newBid, double newAsk) {
    if (newBid > 0) {
      bidHigh = bidHigh <= 0 ? newBid : (newBid > bidHigh ? newBid : bidHigh);
      bidLow = bidLow <= 0 ? newBid : (newBid < bidLow ? newBid : bidLow);
    }
    if (newAsk > 0) {
      askHigh = askHigh <= 0 ? newAsk : (newAsk > askHigh ? newAsk : askHigh);
      askLow = askLow <= 0 ? newAsk : (newAsk < askLow ? newAsk : askLow);
    }
  }

  static double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}

class LivePosition {
  const LivePosition({
    required this.positionId,
    this.ticket,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.openPrice,
    required this.currentPrice,
    required this.floatingPnL,
    required this.openTime,
    this.stopLoss,
    this.takeProfit,
    this.swap = 0,
    this.commission = 0,
  });

  final String positionId;
  final int? ticket;
  final String symbol;
  final String side; // BUY / SELL
  final double volume;
  final double openPrice;
  final double currentPrice;
  final double floatingPnL;
  final DateTime? openTime;
  final double? stopLoss;
  final double? takeProfit;
  final double swap;
  final double commission;

  bool get isBuy => side == 'BUY';

  LivePosition copyWith({
    double? currentPrice,
    double? floatingPnL,
  }) =>
      LivePosition(
        positionId: positionId,
        ticket: ticket,
        symbol: symbol,
        side: side,
        volume: volume,
        openPrice: openPrice,
        currentPrice: currentPrice ?? this.currentPrice,
        floatingPnL: floatingPnL ?? this.floatingPnL,
        openTime: openTime,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        swap: swap,
        commission: commission,
      );

  factory LivePosition.fromWs(Map<String, dynamic> j) => LivePosition(
    positionId: '${j['positionId'] ?? j['orderId'] ?? ''}',
    ticket: (j['ticket'] as num?)?.toInt(),
    symbol: '${j['symbol'] ?? ''}',
    side: '${j['side'] ?? 'BUY'}',
    volume: _d(j['volume'] ?? j['qty']),
    openPrice: _d(j['openPrice']),
    currentPrice: _d(j['currentPrice'] ?? j['closePrice'] ?? j['openPrice']),
    floatingPnL: _d(j['floatingPnL'] ?? j['profitLoss'] ?? j['profit']),
    openTime: _date(j['openTime']),
    stopLoss: j['stopLoss'] == null ? null : _d(j['stopLoss']),
    takeProfit: j['takeProfit'] == null ? null : _d(j['takeProfit']),
    swap: _d(j['swap']),
    commission: _d(j['commission']),
  );
}

class PendingOrder {
  const PendingOrder({
    required this.orderId,
    this.ticket,
    required this.symbol,
    required this.side,
    required this.orderType,
    required this.volume,
    this.filledVolume = 0,
    required this.price,
    this.stopLoss,
    this.takeProfit,
    this.createdAt,
    this.currentPrice,
  });

  final String orderId;
  final int? ticket;
  final String symbol;
  final String side;
  final String orderType;
  final double volume;
  final double filledVolume;
  final double price;
  final double? stopLoss;
  final double? takeProfit;
  final DateTime? createdAt;
  final double? currentPrice;

  bool get isBuy => side == 'BUY';

  factory PendingOrder.fromWs(Map<String, dynamic> j) => PendingOrder(
    orderId: '${j['orderId'] ?? j['positionId'] ?? ''}',
    ticket: (j['ticket'] as num?)?.toInt(),
    symbol: '${j['symbol'] ?? ''}',
    side: '${j['side'] ?? 'BUY'}',
    orderType: '${j['orderType'] ?? j['type'] ?? j['order_type'] ?? ''}',
    volume: _d(j['volume'] ?? j['qty']),
    filledVolume: _d(j['filledVolume'] ?? j['volumeFilled']),
    price: _d(j['price'] ?? j['openPrice']),
    stopLoss: j['stopLoss'] == null ? null : _d(j['stopLoss']),
    takeProfit: j['takeProfit'] == null ? null : _d(j['takeProfit']),
    createdAt: _date(j['createdAt'] ?? j['openTime']),
    currentPrice: j['currentPrice'] == null ? null : _d(j['currentPrice']),
  );
}

class LiveAccount {
  const LiveAccount({
    this.balance = 0,
    this.equity = 0,
    this.usedMargin = 0,
    this.freeMargin = 0,
  });

  final double balance;
  final double equity;
  final double usedMargin;
  final double freeMargin;

  double get marginLevel => usedMargin > 0 ? equity / usedMargin * 100 : 0;

  factory LiveAccount.fromJson(Map<String, dynamic> j) => LiveAccount(
    balance: _d(j['balance']),
    equity: _d(j['equity']),
    usedMargin: _d(j['usedMargin'] ?? j['margin']),
    freeMargin: _d(j['freeMargin']),
  );
}

class WatchSymbol {
  const WatchSymbol({
    required this.code,
    required this.name,
    this.segment = '',
    this.isAdded = false,
  });
  final String code;
  final String name;
  final String segment;
  final bool isAdded;
}

/// Ek symbol category (folder) - Add Symbol screen ke liye,
/// backend ke asal counts ke saath (added/total).
class SymbolSegment {
  const SymbolSegment({
    required this.segment,
    required this.total,
    required this.added,
  });
  final String segment;
  final int total;
  final int added;
}

double _d(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return DateTime.tryParse('$v');
}

/// Portal (email) session — lists accounts; trading still needs [Session].
class UserPortalSession {
  const UserPortalSession({
    required this.accessToken,
    this.refreshToken = '',
    this.email = '',
  });

  final String accessToken;
  final String refreshToken;
  final String email;

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'email': email,
      };

  factory UserPortalSession.fromJson(Map<String, dynamic> j) =>
      UserPortalSession(
        accessToken: '${j['accessToken'] ?? ''}',
        refreshToken: '${j['refreshToken'] ?? ''}',
        email: '${j['email'] ?? ''}',
      );
}

/// One trading account under the logged-in email user.
class LinkedTradingAccount {
  const LinkedTradingAccount({
    required this.id,
    required this.accountNumber,
    required this.accountType,
    this.planName = '',
    this.balance = 0,
    this.equity = 0,
    this.currency = 'USD',
    this.status = 'active',
    this.isPrimary = false,
  });

  final String id;
  final String accountNumber;
  final String accountType;
  final String planName;
  final double balance;
  final double equity;
  final String currency;
  final String status;
  final bool isPrimary;

  bool get isDemo => accountType.toLowerCase().contains('demo');
  bool get isLive => !isDemo;

  factory LinkedTradingAccount.fromJson(Map<String, dynamic> j) =>
      LinkedTradingAccount(
        id: '${j['_id'] ?? j['id'] ?? ''}',
        accountNumber: '${j['account_number'] ?? ''}',
        accountType: '${j['account_type'] ?? ''}',
        planName: '${j['plan_name'] ?? ''}',
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        equity: (j['equity'] as num?)?.toDouble() ?? 0,
        currency: '${j['currency'] ?? 'USD'}',
        status: '${j['status'] ?? 'active'}',
        isPrimary: j['is_primary'] == true || j['isPrimary'] == true,
      );
}

/// Central live-trading service: REST (account-auth) + market/account WS.
class TradingService extends ChangeNotifier {
  TradingService();

  /// Own listener list so a dead hot-reload tear-off can be purged
  /// instead of spamming NoSuchMethodError on every tick (UI freeze).
  final List<VoidCallback?> _uiListeners = <VoidCallback?>[];

  @override
  void addListener(VoidCallback listener) {
    _uiListeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    for (var i = 0; i < _uiListeners.length; i++) {
      if (_uiListeners[i] == listener) {
        _uiListeners[i] = null;
        break;
      }
    }
  }

  @override
  bool get hasListeners => _uiListeners.any((l) => l != null);

  @override
  void notifyListeners() {
    if (_uiListeners.isEmpty) return;
    final snap = List<VoidCallback?>.of(_uiListeners);
    var compact = false;
    for (final listener in snap) {
      if (listener == null) {
        compact = true;
        continue;
      }
      try {
        listener();
      } catch (_) {
        // Hot reload left a deleted method tear-off — drop it once.
        removeListener(listener);
        compact = true;
      }
    }
    if (compact) {
      _uiListeners.removeWhere((l) => l == null);
    }
  }

  Session? session;
  bool get isLoggedIn => session != null;

  /// Email/password portal identity (before / after picking a trading account).
  UserPortalSession? userPortal;
  bool get hasUserPortal =>
      userPortal != null && userPortal!.accessToken.isNotEmpty;
  List<LinkedTradingAccount> linkedAccounts = const [];
  static const _userPortalKey = 'user_portal_session';
  /// Last successful email login (prefill Login form — survives logout).
  static const _emailCredsKey = 'email_login_credentials';

  // MetaQuotes demo account (Brokers -> MetaQuotes Ltd.) - profile.
  // Iska apna server trading account hai; active hone par [session]
  // usi ka hota hai (source 'mq'), FP ka nahi.
  Map<String, dynamic>? mqAccount;
  bool get mqLoggedIn => activeSource == 'mq' && mqAccount != null;

  /// Trading session OR email portal (account picker) counts as signed-in.
  bool get hasAnyAccount => isLoggedIn || mqLoggedIn || hasUserPortal;

  /// Sidebar ribbon: active session demo hai ya live.
  /// MQ MetaQuotes accounts demo treat; FP pe session.accountType.
  bool get isActiveAccountDemo {
    if (mqLoggedIn) return true;
    final s = session;
    if (s == null) return false;
    return s.isDemo;
  }

  /// Sabse last me login kiya hua account source: 'server'
  /// (FP Trades session) ya 'mq' (MetaQuotes demo). Sidebar aur
  /// Accounts screen me yahi wala account upar dikhta hai -
  /// warna purana MQ account chipka rehta tha aur FP login
  /// dikhai hi nahi deta tha.
  String activeSource = '';

  /// Saare FP Trades accounts jinme kabhi login hua (naya pehle).
  List<SavedFpAccount> fpAccounts = const [];
  static const _fpAccountsKey = 'fp_saved_accounts';

  /// User ne khud FP logout kiya - tab tak chup chaap dobara login nahi.
  bool loggedOutByUser = false;

  final quotes = <String, LiveQuote>{};
  final positions = <String, LivePosition>{};
  final pendings = <String, PendingOrder>{};
  LiveAccount account = const LiveAccount();
  bool accountLoaded = false;
  List<WatchSymbol> watchlist = const [];
  bool wsConnected = false;
  String? lastError;

  /// segment (lowercase) → market open? Quotes gray jab false.
  final marketOpenBySegment = <String, bool>{};

  final _subs = <String, String>{}; // symbol -> market
  final _ticks = <String, List<(DateTime, double, double)>>{};
  WebSocket? _ws;
  Timer? _reconnect;
  Timer? _marketStatusTimer;
  bool _closed = false;
  // WebSocket stays OFF while logged out; it connects only on login.
  bool _wsEnabled = false;
  // Tick notifications are throttled so live bid/ask updates don't
  // rebuild the whole UI on every single tick (app slow ho jata tha).
  Timer? _tickTimer;
  DateTime? _lastTickNotify;
  /// Bumps on every account reset so late WS frames from account A
  /// cannot mutate account B after a switch.
  int _sessionGen = 0;

  /// UI screens (Trade / History / Shell) isse account change detect karti hain.
  String get accountKey =>
      '${session?.source ?? ''}|${session?.accountId ?? ''}|${session?.accountNumber ?? ''}';

  // ---------------- session ----------------

  bool _bootstrapped = false;

  /// Disk se session / accounts — network nahi. First frame ke pehle.
  Future<void> restoreLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final mqRaw = prefs.getString('mq_active_account');
    if (mqRaw != null) {
      try {
        final decoded = jsonDecode(mqRaw);
        if (decoded is Map<String, dynamic>) mqAccount = decoded;
      } catch (_) {}
    }
    activeSource =
        prefs.getString('active_source') ?? (mqAccount != null ? 'mq' : '');
    fpAccounts = [
      for (final raw in prefs.getStringList(_fpAccountsKey) ?? const [])
        ?_decodeFp(raw),
    ];
    final raw = prefs.getString('session');
    if (raw != null) {
      try {
        session = Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final portalRaw = prefs.getString(_userPortalKey);
    if (portalRaw != null) {
      try {
        userPortal = UserPortalSession.fromJson(
          jsonDecode(portalRaw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Server validate + WS — first frame ke baad (splash ko block mat karo).
  Future<void> bootstrapNetwork() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    if (session != null) {
      await _validateSession();
      if (session != null) {
        if (session!.source == 'server') unawaited(_rememberFp());
        connectWs();
        unawaited(refreshAccount());
        unawaited(refreshWatchlist());
      }
    }
    if (session == null) await ensureSession();
    notifyListeners();
  }

  /// Full restore (tests / rare callers).
  Future<void> restore() async {
    await restoreLocal();
    await bootstrapNetwork();
  }

  static SavedFpAccount? _decodeFp(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) {
        final a = SavedFpAccount.fromJson(d);
        return a.accountNumber.isEmpty ? null : a;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveFpAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_fpAccountsKey, [
      for (final a in fpAccounts) jsonEncode(a.toJson()),
    ]);
  }

  /// Chalu session wala account list me jodo / update karo (sabse upar).
  /// [password] null = purana saved password rehne do.
  Future<void> _rememberFp({String? password, bool touch = false}) async {
    final s = session;
    if (s == null) return;
    final old = fpAccounts
        .where((a) => a.accountNumber == s.accountNumber)
        .firstOrNull;
    final updated = (old ?? SavedFpAccount(accountNumber: s.accountNumber))
        .copyWith(
          name: s.name.isNotEmpty ? s.name : null,
          accountType: s.accountType.isNotEmpty ? s.accountType : null,
          password: password,
          lastLogin: touch || old == null ? DateTime.now() : null,
          brokerCode: s.brokerCode.isNotEmpty ? s.brokerCode : null,
          brokerDisplayName:
              s.brokerDisplayName.isNotEmpty ? s.brokerDisplayName : null,
        );
    fpAccounts = [
      updated,
      for (final a in fpAccounts)
        if (a.accountNumber != s.accountNumber) a,
    ];
    await _saveFpAccounts();
  }

  Future<void> removeFpAccount(String accountNumber) async {
    fpAccounts = [
      for (final a in fpAccounts)
        if (a.accountNumber != accountNumber) a,
    ];
    await _saveFpAccounts();
    notifyListeners();
  }

  /// Sidebar / Accounts me kaunsa account upar (active) dikhe.
  Future<void> setActiveSource(String source) async {
    activeSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_source', source);
    notifyListeners();
  }

  /// Login response (FP account-auth ya MQ demo ka `session`) se naya
  /// trading session chalu karo. Har naye session pe pehle WS + trade +
  /// pricing caches poori tarah saaf — multi-account mix band.
  Future<void> _startSession(
    Map<String, dynamic> data, {
    required String source,
    required String fallbackNumber,
  }) async {
    final token = data['tradeToken'] as String?;
    if (token == null) throw ApiException('Login failed: no token');
    final number = '${data['account_number'] ?? data['accountNumber'] ?? ''}'
        .trim();
    final next = Session(
      token: token,
      accountId: '${data['accountId'] ?? data['account_id'] ?? ''}',
      accountNumber: number.isNotEmpty ? number : fallbackNumber.trim(),
      accountType: '${data['account_type'] ?? data['accountType'] ?? ''}',
      sessionType: '${data['sessionType'] ?? 'TRADE'}',
      name: '${data['name'] ?? ''}',
      refreshToken: '${data['refreshToken'] ?? ''}',
      source: source,
      brokerCode: '${data['brokerCode'] ?? ''}',
      brokerDisplayName: '${data['brokerDisplayName'] ?? ''}',
    );
    // Always tear down before applying next session (even same number
    // re-login). Partial clear was leaking A quotes/positions into B.
    disconnectWs();
    _resetTradingState();
    session = next;
    loggedOutByUser = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session', jsonEncode(next.toJson()));
    notifyListeners();
    // WebSocket connects only now that we are logged in.
    connectWs();
    _identify();
    unawaited(refreshAccount());
    unawaited(refreshWatchlist());
  }

  /// Positions / pendings only (logout + session switch shared base).
  void _clearAccountState() {
    positions.clear();
    pendings.clear();
    account = const LiveAccount();
    accountLoaded = false;
  }

  /// Full trading + pricing wipe for account switch / logout.
  void _resetTradingState() {
    _sessionGen++;
    _clearAccountState();
    quotes.clear();
    _subs.clear();
    _ticks.clear();
    watchlist = const [];
    lastError = null;
  }

  /// Login candidates: typed ID, plus with/without "AC" (users often omit AC).
  static List<String> accountLoginCandidates(String raw) {
    final s = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return const [];
    final upper = s.toUpperCase();
    final out = <String>[s];
    if (upper.startsWith('AC') && s.length > 2) {
      out.add(s.substring(2));
    } else if (RegExp(r'^\d+$').hasMatch(s)) {
      out.add('AC$s');
    }
    return [...{...out}];
  }

  /// MT5 Find-broker: ACTIVE brokers from backend (`q` optional).
  /// Filtered by `--dart-define=BROKER_APP=oceana|fptrades` for white-label APKs.
  Future<List<PublicBroker>> searchPublicBrokers({String q = ''}) async {
    final data = await _request(
      'GET',
      '/v1/brokers/public',
      auth: false,
      query: {if (q.trim().isNotEmpty) 'q': q.trim()},
    );
    final raw = data['data'];
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map)
          PublicBroker.fromJson(Map<String, dynamic>.from(row)),
    ].where((b) {
      return ApiConfig.isBrokerVisibleInApp(
        code: b.code,
        displayName: b.displayName,
      );
    }).toList();
  }

  Future<void> _persistUserPortal() async {
    final prefs = await SharedPreferences.getInstance();
    final p = userPortal;
    if (p == null || p.accessToken.isEmpty) {
      await prefs.remove(_userPortalKey);
    } else {
      await prefs.setString(_userPortalKey, jsonEncode(p.toJson()));
    }
  }

  /// Last email + password used for portal login (device local).
  Future<({String email, String password})?> savedEmailLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_emailCredsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final email = '${j['email'] ?? ''}'.trim();
      final password = '${j['password'] ?? ''}';
      if (email.isEmpty || password.isEmpty) return null;
      return (email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<void> rememberEmailLogin(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final e = email.trim().toLowerCase();
    if (e.isEmpty || password.isEmpty) {
      await prefs.remove(_emailCredsKey);
      return;
    }
    await prefs.setString(
      _emailCredsKey,
      jsonEncode({'email': e, 'password': password}),
    );
  }

  /// Email + portal password → user JWT, then open primary trading account.
  Future<void> loginWithEmail(String email, String password) async {
    final data = await _request(
      'POST',
      '/v1/auth/login',
      auth: false,
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
    final payload = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    final access = '${payload['accessToken'] ?? ''}';
    if (access.isEmpty) {
      throw ApiException('Login failed');
    }
    final mailOk = payload['isMailVerified'] == true ||
        payload['isMailVerified'] == 1 ||
        '${payload['isMailVerified']}'.toLowerCase() == 'true';
    if (!mailOk) {
      throw EmailNotVerifiedException(email.trim().toLowerCase());
    }
    userPortal = UserPortalSession(
      accessToken: access,
      refreshToken: '${payload['refreshToken'] ?? ''}',
      email: email.trim().toLowerCase(),
    );
    loggedOutByUser = false;
    await _persistUserPortal();
    await rememberEmailLogin(email, password);
    await refreshLinkedAccounts();
    await activatePrimaryAccount();
    notifyListeners();
  }

  /// `POST /v1/user/save-fcm-token` — links this device to the portal user.
  Future<void> saveFcmToken(String token) async {
    final t = token.trim();
    if (t.isEmpty) return;
    if (!hasUserPortal) {
      throw ApiException('Sign in with email first');
    }
    await _request(
      'POST',
      '/v1/user/save-fcm-token',
      auth: false,
      userAuth: true,
      body: {
        'token': t,
        'platform': Platform.isIOS ? 'ios' : 'android',
      },
    );
  }

  /// Unread inbox for portal user (`GET /v1/notification/inbox`).
  Future<({List<Map<String, dynamic>> list, int unreadCount})>
      fetchNotificationInbox({int limit = 40}) async {
    if (!hasUserPortal) {
      return (list: <Map<String, dynamic>>[], unreadCount: 0);
    }
    final data = await _request(
      'GET',
      '/v1/notification/inbox',
      auth: false,
      userAuth: true,
      query: {'limit': '$limit'},
    );
    final raw = data['list'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final unread = (data['unreadCount'] as num?)?.toInt() ?? list.length;
    return (list: list, unreadCount: unread);
  }

  Future<int> fetchNotificationUnreadCount() async {
    if (!hasUserPortal) return 0;
    final data = await _request(
      'GET',
      '/v1/notification/inbox/count',
      auth: false,
      userAuth: true,
    );
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<int> markNotificationRead(String id) async {
    if (!hasUserPortal || id.trim().isEmpty) return 0;
    final data = await _request(
      'POST',
      '/v1/notification/inbox/${Uri.encodeComponent(id.trim())}/read',
      auth: false,
      userAuth: true,
    );
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAllNotificationsRead() async {
    if (!hasUserPortal) return;
    await _request(
      'POST',
      '/v1/notification/inbox/read-all',
      auth: false,
      userAuth: true,
    );
  }

  /// Resend email verification link (`POST /v1/auth/resend-verify-email`).
  Future<void> resendVerifyEmail(String email) async {
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty) {
      throw ApiException('Please enter your email');
    }
    await _request(
      'POST',
      '/v1/auth/resend-verify-email',
      auth: false,
      body: {'email': trimmed},
    );
  }

  /// Forgot password — backend emails reset link (`POST /v1/auth/forgot-password`).
  Future<String> forgotPassword(String email) async {
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty) {
      throw ApiException('Please enter your email');
    }
    final data = await _request(
      'POST',
      '/v1/auth/forgot-password',
      auth: false,
      body: {'email': trimmed},
    );
    final msg = '${data['message'] ?? ''}'.trim();
    return msg.isEmpty
        ? 'Reset link sent to your email successfully'
        : msg;
  }

  /// Active account plans for the portal user's broker (`GET /v1/account-plans/active`).
  Future<List<Map<String, dynamic>>> fetchAccountPlans() async {
    if (!hasUserPortal) return const [];
    final data = await _request(
      'GET',
      '/v1/account-plans/active',
      auth: false,
      userAuth: true,
    );
    final raw = data['data'];
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  /// Create live/demo trading account under email portal user.
  Future<Map<String, dynamic>> createPortalAccount({
    required String accountPlanId,
    required String accountType,
    double? openingBalance,
    int? leverage,
    String? tradePassword,
    String? watchPassword,
  }) async {
    if (!hasUserPortal) {
      throw ApiException('Sign in with email first');
    }
    if (accountPlanId.trim().isEmpty) {
      throw ApiException('Invalid plan — please reselect');
    }
    final body = <String, dynamic>{
      'account_plan_id': accountPlanId.trim(),
      'account_type': accountType,
    };
    if (openingBalance != null) body['opening_balance'] = openingBalance;
    if (leverage != null) body['leverage'] = leverage;
    if (tradePassword != null && tradePassword.isNotEmpty) {
      body['trade_password'] = tradePassword;
    }
    if (watchPassword != null && watchPassword.isNotEmpty) {
      body['watch_password'] = watchPassword;
    }
    final data = await _request(
      'POST',
      '/v1/accounts',
      auth: false,
      userAuth: true,
      body: body,
    );
    final created = data['data'];
    final map = created is Map
        ? Map<String, dynamic>.from(created)
        : <String, dynamic>{};
    try {
      await refreshLinkedAccounts();
    } catch (_) {}
    if (map.isEmpty) {
      throw ApiException('Account created but response was empty');
    }
    return map;
  }

  /// Cached portal profile for verify % + settings.
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? myKyc;

  /// `GET /v1/user/me`
  Future<Map<String, dynamic>> fetchUserProfile({bool force = false}) async {
    if (!hasUserPortal) throw ApiException('Sign in with email first');
    if (!force && userProfile != null) return userProfile!;
    final res = await _request(
      'GET',
      '/v1/user/me',
      auth: false,
      userAuth: true,
    );
    final data = res['data'];
    userProfile = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    notifyListeners();
    return userProfile!;
  }

  /// `PUT /v1/user/me`
  Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> body,
  ) async {
    if (!hasUserPortal) throw ApiException('Sign in with email first');
    final res = await _request(
      'PUT',
      '/v1/user/me',
      auth: false,
      userAuth: true,
      body: body,
    );
    final data = res['data'];
    if (data is Map) {
      userProfile = Map<String, dynamic>.from(data);
    } else {
      await fetchUserProfile(force: true);
    }
    notifyListeners();
    return userProfile ?? <String, dynamic>{};
  }

  /// `GET /v1/kyc/me`
  Future<Map<String, dynamic>> fetchMyKyc({bool force = false}) async {
    if (!hasUserPortal) throw ApiException('Sign in with email first');
    if (!force && myKyc != null) return myKyc!;
    final res = await _request(
      'GET',
      '/v1/kyc/me',
      auth: false,
      userAuth: true,
    );
    final data = res['data'];
    myKyc = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{'status': 'NOT_STARTED'};
    notifyListeners();
    return myKyc!;
  }

  /// Upload KYC image to Cloudinary (unsigned preset), then `POST /v1/kyc`.
  Future<({String imageUrl, String publicId})> uploadKycImage(
    String filePath, {
    String folder = 'kyc',
  }) async {
    const cloud = 'ds1mkqecg';
    const preset = 'Trading';
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await req.send().timeout(const Duration(seconds: 40));
    final body = await streamed.stream.bytesToString();
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
    if (streamed.statusCode >= 400) {
      final err = data['error'];
      final msg = err is Map
          ? '${err['message'] ?? ''}'
          : '${data['message'] ?? ''}';
      throw ApiException(msg.trim().isEmpty ? 'Image upload failed' : msg);
    }
    final url = '${data['secure_url'] ?? ''}';
    final id = '${data['public_id'] ?? ''}';
    if (url.isEmpty || id.isEmpty) {
      throw ApiException('Image upload failed');
    }
    return (imageUrl: url, publicId: id);
  }

  /// Support ticket (`POST /v1/inquiry`) — public create like Trade-Portal.
  Future<void> createSupportInquiry({
    required String name,
    required String email,
    required String phone,
    required String title,
    required String description,
  }) async {
    await _request(
      'POST',
      '/v1/inquiry',
      auth: false,
      userAuth: false,
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'title': title,
        'description': description,
      },
    );
  }

  /// `POST /v1/kyc`
  Future<Map<String, dynamic>> submitKyc({
    required String documentType,
    required Map<String, dynamic> front,
    required Map<String, dynamic> selfie,
    Map<String, dynamic>? back,
  }) async {
    if (!hasUserPortal) throw ApiException('Sign in with email first');
    final res = await _request(
      'POST',
      '/v1/kyc',
      auth: false,
      userAuth: true,
      body: {
        'documentType': documentType,
        'documents': {
          'front': front,
          'back': back ??
              {'image_url': '', 'image_public_id': ''},
          'selfie': selfie,
        },
      },
    );
    final data = res['data'];
    myKyc = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{'status': 'PENDING'};
    await fetchUserProfile(force: true);
    notifyListeners();
    return myKyc!;
  }

  /// Portal wallet/ledger history (`GET /v1/transactions`).
  Future<({List<Map<String, dynamic>> data, int page, int totalPages, int total})>
      fetchTransactions({
    int page = 1,
    int limit = 50,
    String? type,
    String? fromDate,
    String? toDate,
    String? accountId,
  }) async {
    if (!hasUserPortal) {
      throw ApiException('Sign in with email first');
    }
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (type != null && type.isNotEmpty) 'type': type,
      if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
      if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
    };
    final res = await _request(
      'GET',
      '/v1/transactions',
      auth: false,
      userAuth: true,
      query: query,
    );
    final raw = res['data'];
    final list = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map) list.add(Map<String, dynamic>.from(row));
      }
    }
    final pagination = res['pagination'];
    final p = pagination is Map ? pagination : const {};
    return (
      data: list,
      page: (p['page'] as num?)?.toInt() ?? page,
      totalPages: (p['totalPages'] as num?)?.toInt() ?? 1,
      total: (p['total'] as num?)?.toInt() ?? list.length,
    );
  }

  /// Live → Live internal fund transfer (`POST /v1/internal-transfer`).
  Future<Map<String, dynamic>> createInternalTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
  }) async {
    if (!hasUserPortal) {
      throw ApiException('Sign in with email first');
    }
    final data = await _request(
      'POST',
      '/v1/internal-transfer',
      auth: false,
      userAuth: true,
      body: {
        'fromAccount': fromAccountId,
        'toAccount': toAccountId,
        'amount': amount,
      },
    );
    await refreshLinkedAccounts();
    final sessionNum = session?.accountNumber.trim() ?? '';
    if (sessionNum.isNotEmpty) {
      try {
        await refreshAccount();
      } catch (_) {}
    }
    return data;
  }

  /// Owned trading accounts for the email user (user JWT).
  Future<List<LinkedTradingAccount>> refreshLinkedAccounts() async {
    if (!hasUserPortal) {
      linkedAccounts = const [];
      notifyListeners();
      return linkedAccounts;
    }
    final data = await _request(
      'GET',
      '/v1/accounts',
      auth: false,
      userAuth: true,
    );
    final raw = data['data'];
    final list = <LinkedTradingAccount>[];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map) {
          list.add(
            LinkedTradingAccount.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }
    }
    linkedAccounts = list;
    notifyListeners();
    return list;
  }

  /// Mint TRADE session for an owned account (email user JWT).
  Future<void> activateLinkedAccount(
    String accountId, {
    String? tradePassword,
  }) async {
    if (!hasUserPortal) {
      throw ApiException('Sign in with email first');
    }
    final data = await _request(
      'POST',
      '/v1/account-auth/activate',
      auth: false,
      userAuth: true,
      body: {
        'accountId': accountId,
        if (tradePassword != null && tradePassword.isNotEmpty)
          'tradePassword': tradePassword,
      },
    );
    final payload = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    await _startSession(
      payload,
      source: 'server',
      fallbackNumber: '${payload['account_number'] ?? ''}',
    );
    await _rememberFp(password: '', touch: true);
    await setActiveSource('server');
  }

  /// Open the user's primary trading account (no picker).
  Future<void> activatePrimaryAccount({String? tradePassword}) async {
    if (!hasUserPortal) {
      throw ApiException('Sign in with email first');
    }
    try {
      final data = await _request(
        'POST',
        '/v1/account-auth/activate-primary',
        auth: false,
        userAuth: true,
        body: {
          if (tradePassword != null && tradePassword.isNotEmpty)
            'tradePassword': tradePassword,
        },
      );
      final payload = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;
      await _startSession(
        payload,
        source: 'server',
        fallbackNumber: '${payload['account_number'] ?? ''}',
      );
      await _rememberFp(password: '', touch: true);
      await setActiveSource('server');
      return;
    } catch (_) {
      // Fallback: pick from linked list if endpoint unavailable.
    }
    if (linkedAccounts.isEmpty) {
      await refreshLinkedAccounts();
    }
    if (linkedAccounts.isEmpty) {
      throw ApiException('No trading account found');
    }
    final primary = linkedAccounts.firstWhere(
      (a) => a.isPrimary,
      orElse: () {
        final live = linkedAccounts.where((a) => a.isLive);
        if (live.isNotEmpty) return live.first;
        return linkedAccounts.first;
      },
    );
    await activateLinkedAccount(primary.id, tradePassword: tradePassword);
  }

  Future<void> switchLinkedAccount(String accountId) =>
      activateLinkedAccount(accountId);

  /// FP Trades account login (account-auth).
  Future<void> login(
    String accountNumber,
    String password, {
    bool activate = true,
    bool savePassword = true,
  }) async {
    final candidates = accountLoginCandidates(accountNumber);
    if (candidates.isEmpty) {
      throw ApiException('Enter login and password');
    }

    Object? lastError;
    Map<String, dynamic>? data;
    var usedNumber = candidates.first;
    for (final num in candidates) {
      try {
        data = await _request(
          'POST',
          '/v1/account-auth/login',
          auth: false,
          body: {'account_number': num, 'password': password},
        );
        usedNumber = num;
        break;
      } catch (e) {
        lastError = e;
      }
    }
    if (data == null) {
      throw lastError ?? ApiException('Invalid credentials');
    }

    await _startSession(data, source: 'server', fallbackNumber: usedNumber);
    // Har FP login Manage Accounts list me save (dusra login karne par
    // bhi card gayab nahi hoga).
    await _rememberFp(password: savePassword ? password : '', touch: true);
    if (activate) {
      // FP Trades login ab sabse upar wala (active) account hai.
      await setActiveSource('server');
    }
  }

  Future<bool>? _ensuring;

  /// Session na ho (app start pe server band tha, ya refresh fail hua) to
  /// ACTIVE account (FP ya MQ) ke saved password se chup chaap dobara
  /// login. Koi active account / password nahi = false (logged out).
  Future<bool> ensureSession() {
    if (session != null) return Future.value(true);
    if (loggedOutByUser) return Future.value(false);
    return _ensuring ??= () async {
      try {
        final mq = mqAccount;
        final mqPass = '${mq?['password'] ?? ''}';
        if (activeSource == 'mq' && mq != null && mqPass.isNotEmpty) {
          await loginMetaQuotesDemo(
            type: 'TRADE_ACCOUNT',
            identifier: '${mq['login_id']}',
            password: mqPass,
          );
        } else if (activeSource == 'server') {
          // Prefer the most recently used FP card (list is newest-first).
          final saved = fpAccounts
              .where((a) => a.password.isNotEmpty)
              .firstOrNull;
          if (saved != null) {
            await login(saved.accountNumber, saved.password, activate: false);
          }
        }
      } catch (e) {
        lastError = ApiConfig.userFacingError(e);
      }
      return session != null;
    }().whenComplete(() => _ensuring = null);
  }

  /// Stored session ko server se validate karo (app start pe).
  /// Token expire ho to _request khud refresh token se naya le
  /// lega; refresh bhi fail ho to wahi force-logout kar dega aur
  /// session null ho jayega. Server unreachable ho to session
  /// rakha rahega (offline me logout nahi karna).
  Future<bool> _validateSession() async {
    try {
      final data = await _request('GET', '/v1/account-auth/me');
      if (session == null) return false;
      final name = '${data['name'] ?? ''}'.trim();
      final brokerCode = '${data['brokerCode'] ?? ''}'.trim();
      final brokerDisplayName = '${data['brokerDisplayName'] ?? ''}'.trim();
      final changed =
          (name.isNotEmpty && session!.name != name) ||
          (brokerCode.isNotEmpty && session!.brokerCode != brokerCode) ||
          (brokerDisplayName.isNotEmpty &&
              session!.brokerDisplayName != brokerDisplayName);
      if (changed) {
        session = session!.copyWith(
          name: name.isNotEmpty ? name : null,
          brokerCode: brokerCode.isNotEmpty ? brokerCode : null,
          brokerDisplayName:
              brokerDisplayName.isNotEmpty ? brokerDisplayName : null,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session', jsonEncode(session!.toJson()));
        notifyListeners();
      }
    } catch (_) {
      // 401 wala case _request/logout sambhal chuka hoga; network
      // error pe session rehne do.
    }
    return session != null;
  }

  Future<bool>? _refreshing;

  /// Access token expire (401) hone pe refresh token se naya
  /// session lo. Parallel requests ek hi refresh share karte hain.
  Future<bool> _refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _doRefresh() async {
    final s = session;
    if (s == null || s.refreshToken.isEmpty) return false;
    try {
      final data = await _request(
        'POST',
        '/v1/account-auth/refresh',
        auth: false,
        body: {'refreshToken': s.refreshToken},
      );
      final token = data['tradeToken'] as String?;
      if (token == null || session == null) return false;
      final name = '${data['name'] ?? ''}'.trim();
      final brokerCode = '${data['brokerCode'] ?? ''}'.trim();
      final brokerDisplayName = '${data['brokerDisplayName'] ?? ''}'.trim();
      session = session!.copyWith(
        token: token,
        refreshToken: '${data['refreshToken'] ?? s.refreshToken}',
        name: name.isNotEmpty ? name : null,
        brokerCode: brokerCode.isNotEmpty ? brokerCode : null,
        brokerDisplayName:
            brokerDisplayName.isNotEmpty ? brokerDisplayName : null,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session', jsonEncode(session!.toJson()));
      _identify();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// [byUser] = user ne khud logout dabaya (token expire wala nahi).
  /// User logout = koi account active nahi -> logged-out screens.
  /// Token-expire wala logout ([byUser] false) active account rakhta hai
  /// taaki saved password se dobara login ho sake.
  Future<void> logout({bool byUser = true}) async {
    final wasMq = session?.source == 'mq';
    session = null;
    // Logged out: WebSocket band - koi live feed connection nahi.
    disconnectWs();
    _resetTradingState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session');
    if (byUser) {
      loggedOutByUser = true;
      userPortal = null;
      linkedAccounts = const [];
      await prefs.remove(_userPortalKey);
      if (wasMq || activeSource == 'mq') {
        mqAccount = null;
        await prefs.remove('mq_active_account');
      }
      activeSource = '';
      await prefs.setString('active_source', activeSource);
    }
    notifyListeners();
  }

  // ---------------- MetaQuotes demo (local) ----------------

  Future<Map<String, dynamic>> registerMetaQuotesDemo(
    Map<String, dynamic> body,
  ) =>
      _request('POST', '/v1/metaquotes/demo/register', auth: false, body: body);

  /// MQ demo login: server pe us demo ka apna trading account hai -
  /// usi ka session chalu hota hai (trades, positions, History sab
  /// isi account ke). Purane local-only data ke saath merge hota hai.
  Future<Map<String, dynamic>> loginMetaQuotesDemo({
    required String type,
    required String identifier,
    required String password,
  }) async {
    final profile = await _request(
      'POST',
      '/v1/metaquotes/demo/login',
      auth: false,
      body: {'type': type, 'identifier': identifier, 'password': password},
    );
    final sessionData = profile.remove('session');
    if (sessionData is! Map<String, dynamic>) {
      throw ApiException('Login failed: trading account not available');
    }
    await _startSession(
      sessionData,
      source: 'mq',
      fallbackNumber: '${profile['login_id'] ?? identifier}',
    );
    final local =
        mqAccount != null &&
            '${mqAccount!['login_id']}' == '${profile['login_id']}'
        ? mqAccount!
        : const <String, dynamic>{};
    await setMqAccount({
      ...local,
      ...profile,
      'email': profile['email'] ?? identifier,
      'password': password,
    });
    return profile;
  }

  /// Active MetaQuotes account set karo (ya null = MQ logout) aur
  /// locally persist; listeners rebuild (sidebar, screens).
  Future<void> setMqAccount(Map<String, dynamic>? account) async {
    if (account == null) {
      if (session?.source == 'mq' || activeSource == 'mq') {
        // MQ ka trading session bhi band -> logged-out screen.
        await logout();
        return;
      }
      mqAccount = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mq_active_account');
      notifyListeners();
      return;
    }
    mqAccount = account;
    activeSource = 'mq';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mq_active_account', jsonEncode(account));
    await prefs.setString('active_source', activeSource);
    await _upsertSavedMq(account);
    notifyListeners();
  }

  // ---------------- saved accounts (Manage Accounts) ----------------

  static const _mqListKey = 'mq_created_accounts';

  /// Phone me saved saare MetaQuotes demo accounts.
  Future<List<Map<String, dynamic>>> savedMqAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final raw in prefs.getStringList(_mqListKey) ?? const [])
        ?_decodeMap(raw),
    ];
  }

  static Map<String, dynamic>? _decodeMap(String raw) {
    try {
      final d = jsonDecode(raw);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSavedMq(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_mqListKey, [
      for (final a in list) jsonEncode(a),
    ]);
  }

  /// MQ account list me jodo / update (login se aaya ho to bhi card bane).
  Future<void> _upsertSavedMq(Map<String, dynamic> account) async {
    final id = '${account['login_id']}';
    final list = await savedMqAccounts();
    final i = list.indexWhere((a) => '${a['login_id']}' == id);
    if (i >= 0) {
      list[i] = {...list[i], ...account};
    } else {
      list.add(account);
    }
    await _writeSavedMq(list);
  }

  /// MQ account list se hatao (active ho to logout bhi).
  Future<void> forgetMqAccount(String loginId) async {
    final list = await savedMqAccounts();
    list.removeWhere((a) => '${a['login_id']}' == loginId);
    await _writeSavedMq(list);
    if ('${mqAccount?['login_id']}' == loginId) {
      await setMqAccount(null);
    }
    notifyListeners();
  }

  /// Active account ka saved password phone se hatao (dobara login pe
  /// password puchha jayega).
  Future<void> clearSavedPassword() async {
    if (mqLoggedIn) {
      final id = '${mqAccount!['login_id']}';
      mqAccount = {...mqAccount!}..remove('password');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mq_active_account', jsonEncode(mqAccount));
      final list = await savedMqAccounts();
      for (final a in list) {
        if ('${a['login_id']}' == id) a.remove('password');
      }
      await _writeSavedMq(list);
    } else if (session?.source == 'server') {
      _setFpPassword(session!.accountNumber, '');
      await _saveFpAccounts();
    }
    notifyListeners();
  }

  void _setFpPassword(String accountNumber, String password) {
    fpAccounts = [
      for (final a in fpAccounts)
        a.accountNumber == accountNumber ? a.copyWith(password: password) : a,
    ];
  }

  /// MT5 Change password: kind = master / investor / trader / money_manager.
  /// Master badla to phone ka saved password bhi naya.
  Future<void> changePassword({
    required String kind,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _request(
      'POST',
      '/v1/account-auth/change-password',
      body: {
        'kind': kind,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    if (kind != 'master') return;
    if (session?.source == 'mq' && mqAccount != null) {
      final updated = {...mqAccount!, 'password': newPassword};
      mqAccount = updated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mq_active_account', jsonEncode(updated));
      await _upsertSavedMq(updated);
    } else if (session?.source == 'server') {
      final saved = fpAccounts
          .where((a) => a.accountNumber == session!.accountNumber)
          .firstOrNull;
      // Pehle se password saved tha tabhi naya save karo.
      if (saved != null && saved.password.isNotEmpty) {
        _setFpPassword(saved.accountNumber, newPassword);
        await _saveFpAccounts();
      }
    }
    notifyListeners();
  }

  // ---------------- REST ----------------

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    bool userAuth = false,
    bool retried = false,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.httpBase}$path',
    ).replace(queryParameters: query);
    final client = HttpClient();
    // Short connect timeout — unreachable host pe app hang na kare.
    client.connectionTimeout = const Duration(seconds: 5);
    client.idleTimeout = const Duration(seconds: 10);
    try {
      final req = await client.openUrl(method, uri);
      req.headers.contentType = ContentType.json;
      if (userAuth && hasUserPortal) {
        req.headers.set(
          'Authorization',
          'Bearer ${userPortal!.accessToken}',
        );
      } else if (auth && session != null) {
        req.headers.set('Authorization', 'Bearer ${session!.token}');
      }
      if (body != null) req.write(jsonEncode(body));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
      if (resp.statusCode >= 400) {
        // Access token expire/invalid: ek baar refresh token se
        // chup chaap naya session lo aur request dobara bhejo.
        // Refresh bhi fail ho jaye to pura force-logout — app
        // aadhi logged-in haalat me nahi atkega.
        if (resp.statusCode == 401 &&
            auth &&
            !retried &&
            session != null &&
            !path.contains('/account-auth/')) {
          if (await _refreshSession()) {
            return _request(
              method,
              path,
              body: body,
              query: query,
              auth: auth,
              userAuth: userAuth,
              retried: true,
            );
          }
          await logout(byUser: false);
          throw ApiException('Session expired. Please login again');
        }
        final msg = data['message'] as String?;
        final detail = data['error'] as String?;
        // Prefer specific backend error when generic "Internal server error".
        final shown = (msg == null ||
                msg.isEmpty ||
                (msg == 'Internal server error' &&
                    detail != null &&
                    detail.isNotEmpty))
            ? (detail ?? msg ?? 'Request failed (${resp.statusCode})')
            : msg;
        throw ApiException(shown);
      }
      return data;
    } on SocketException {
      throw ApiException('Unable to connect to server. Please try again.');
    } finally {
      client.close();
    }
  }

  Future<void> refreshAccount() async {
    if (!await ensureSession()) return;
    try {
      final res = await _request('GET', '/v1/trade/account');
      final data = res['data'];
      if (data is Map<String, dynamic>) {
        account = LiveAccount.fromJson(data);
        accountLoaded = true;
        notifyListeners();
        final number = session?.accountNumber;
        final i = fpAccounts.indexWhere((a) => a.accountNumber == number);
        if (i >= 0 && fpAccounts[i].balance != account.balance) {
          fpAccounts = [...fpAccounts]
            ..[i] = fpAccounts[i].copyWith(balance: account.balance);
          unawaited(_saveFpAccounts());
        }
      }
      final pos = await _request(
        'GET',
        '/v1/trade/positions',
        query: {'status': 'OPEN', 'limit': '100'},
      );
      final list = pos['positions'];
      if (list is List) {
        // Full replace from REST so previous account positions cannot linger.
        // Live mark (bid/ask) applied from current quotes when available.
        final fresh = <String, LivePosition>{};
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            var p = LivePosition.fromWs(item);
            if (p.positionId.isEmpty) continue;
            final q = quoteFor(p.symbol);
            if (q != null && q.hasPrice) {
              p = p.copyWith(currentPrice: p.isBuy ? q.bid : q.ask);
            }
            fresh[p.positionId] = p;
          }
        }
        positions
          ..clear()
          ..addAll(fresh);
        for (final p in positions.values) {
          ensureSubscribed(p.symbol);
        }
        notifyListeners();
      }
    } catch (e) {
      lastError = ApiConfig.userFacingError(e);
    }
  }

  Future<void> refreshWatchlist() async {
    if (!isLoggedIn) return;
    try {
      final res = await _request('GET', '/v1/watchlist');
      final list = res['data'];
      if (list is List) {
        watchlist = [
          for (final item in list)
            if (item is Map<String, dynamic>)
              WatchSymbol(
                code: '${item['code'] ?? item['symbol'] ?? ''}',
                name: '${item['name'] ?? ''}',
                segment: '${item['segment'] ?? ''}',
              ),
        ].where((w) => w.code.isNotEmpty).toList();
        for (final w in watchlist) {
          subscribe(w.code, market: _marketFor(w));
        }
        notifyListeners();
      }
    } catch (e) {
      lastError = ApiConfig.userFacingError(e);
    }
  }

  /// Broker instrument specification and market schedule for the symbol page.
  Future<Map<String, dynamic>> instrumentProperty(String symbol) async {
    if (!await ensureSession() || session?.source != 'server') {
      throw ApiException(
        'Sign in to a trading account to view symbol properties',
      );
    }
    final response = await _request(
      'GET',
      '/v1/property/${Uri.encodeComponent(symbol)}',
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid symbol properties response');
    }
    return data;
  }

  /// Market Statistics: Alltick daily OHLC + live bid/ask.
  Future<Map<String, dynamic>> marketStatistics(String symbol) async {
    final response = await _request(
      'GET',
      '/v1/market/statistics/${Uri.encodeComponent(symbol)}',
      auth: false,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid market statistics response');
    }
    return data;
  }

  String _marketFor(WatchSymbol w) {
    final seg = w.segment.toUpperCase();
    if (seg.contains('STOCK') || seg.contains('EQUIT')) return 'stock';
    if (seg.isNotEmpty) return seg.toLowerCase();
    return 'crypto';
  }

  Future<Map<String, dynamic>> history(
    String kind, {
    DateTime? from,
    DateTime? to,
  }) async {
    final path = switch (kind) {
      'orders' => '/v1/trade/orders',
      'deals' => '/v1/trade/deals',
      _ => '/v1/trade/positions',
    };
    final query = <String, String>{'limit': '1000', 'page': '1'};
    if (kind == 'positions') query['status'] = 'CLOSED';
    if (from != null) query['from'] = from.toIso8601String();
    if (to != null) query['to'] = to.toIso8601String();
    return _request('GET', path, query: query);
  }

  Future<Map<String, dynamic>> summary() =>
      _request('GET', '/v1/trade/summary');

  Future<Map<String, dynamic>> placeMarketOrder({
    required String symbol,
    required String side,
    required double volume,
    double? stopLoss,
    double? takeProfit,
  }) async {
    final res = await _request(
      'POST',
      '/v1/trade/market',
      body: {
        'symbol': symbol,
        'side': side,
        'volume': volume,
        if (stopLoss != null) 'stopLoss': stopLoss,
        if (takeProfit != null) 'takeProfit': takeProfit,
      },
    );
    unawaited(refreshAccount());
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> placePendingOrder({
    required String symbol,
    required String side,
    required String orderType,
    required double price,
    double? limitPrice,
    required double volume,
    double? stopLoss,
    double? takeProfit,
    String expireType = 'GTC',
    DateTime? expireAt,
  }) async {
    final res = await _request(
      'POST',
      '/v1/trade/pending',
      body: {
        'symbol': symbol,
        'side': side,
        'orderType': orderType,
        'price': price,
        if (limitPrice != null) 'limitPrice': limitPrice,
        'volume': volume,
        if (stopLoss != null) 'stopLoss': stopLoss,
        if (takeProfit != null) 'takeProfit': takeProfit,
        'expireType': expireType,
        if (expireAt != null) 'expireAt': expireAt.toIso8601String(),
      },
    );
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> closePosition(String positionId) async {
    final res = await _request(
      'POST',
      '/v1/trade/position/close',
      body: {'positionId': positionId},
    );
    positions.remove(positionId);
    notifyListeners();
    unawaited(refreshAccount());
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> modifyPosition({
    required String positionId,
    double? stopLoss,
    double? takeProfit,
  }) async {
    await _request(
      'PATCH',
      '/v1/trade/position/modify',
      body: {
        'positionId': positionId,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
      },
    );
  }

  Future<void> modifyPending({
    required String orderId,
    required double price,
    double? stopLoss,
    double? takeProfit,
  }) async {
    await _request(
      'PATCH',
      '/v1/trade/pending/modify',
      body: {
        'orderId': orderId,
        'price': price,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
      },
    );
  }

  Future<void> cancelPending(String orderId) async {
    await _request(
      'POST',
      '/v1/trade/pending/cancel',
      body: {'orderId': orderId},
    );
    pendings.remove(orderId);
    notifyListeners();
  }

  Future<void> addWatchlist(String code, String name) async {
    await _request(
      'POST',
      '/v1/watchlist/add',
      body: {'code': code, 'name': name},
    );
    unawaited(refreshWatchlist());
  }

  /// Drag karke badli hui watchlist order backend par save karo,
  /// taaki app dobara khulne par bhi wahi position mile.
  Future<void> reorderWatchlist(List<String> codes) async {
    await _request('PUT', '/v1/watchlist/reorder', body: {'codes': codes});
    final byCode = {for (final w in watchlist) w.code: w};
    watchlist = [
      for (final c in codes)
        if (byCode[c] != null) byCode[c]!,
      for (final w in watchlist)
        if (!codes.contains(w.code)) w,
    ];
    notifyListeners();
  }

  Future<void> removeWatchlist(String code) async {
    await _request('DELETE', '/v1/watchlist/remove/$code');
    watchlist = watchlist.where((w) => w.code != code).toList();
    notifyListeners();
  }

  Future<List<WatchSymbol>> searchInstruments(String q) async {
    final res = await _request(
      'GET',
      '/v1/watchlist/search/instruments',
      query: {'q': q, 'limit': '200'},
    );
    final list = res['data'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>)
          WatchSymbol(
            code: '${item['code'] ?? ''}',
            name: '${item['name'] ?? ''}',
            segment: '${item['segment'] ?? ''}',
          ),
    ].where((w) => w.code.isNotEmpty).toList();
  }

  /// Add Symbol screen ke folders: har segment ka total aur
  /// watchlist me added count (backend se live).
  Future<List<SymbolSegment>> symbolSegments() async {
    final res = await _request('GET', '/v1/watchlist/segments');
    final list = res['data'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>)
          SymbolSegment(
            segment: '${item['segment'] ?? ''}',
            total: (item['total'] as num?)?.toInt() ?? 0,
            added: (item['added'] as num?)?.toInt() ?? 0,
          ),
    ].where((s) => s.segment.isNotEmpty && s.total > 0).toList();
  }

  /// Ek segment (folder) ke saare symbols, isAdded status ke saath.
  Future<List<WatchSymbol>> segmentInstruments(String segment) async {
    final res = await _request(
      'GET',
      '/v1/watchlist/segment/$segment',
      query: {'limit': '200'},
    );
    final list = res['data'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>)
          WatchSymbol(
            code: '${item['code'] ?? ''}',
            name: '${item['name'] ?? ''}',
            segment: '${item['segment'] ?? ''}',
            isAdded: item['isAdded'] == true,
          ),
    ].where((w) => w.code.isNotEmpty).toList();
  }

  // ---------------- WebSocket ----------------

  void subscribe(String symbol, {String market = 'crypto'}) {
    final sym = symbol.toUpperCase();
    _subs[sym] = market;
    quotes.putIfAbsent(sym, () => LiveQuote(sym));
    _send({'type': 'subscribe', 'market': market, 'symbol': sym});
  }

  /// Position / pending symbol pe live feed (watchlist me na ho to bhi).
  void ensureSubscribed(String symbol) {
    final sym = symbol.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (sym.isEmpty || _subs.containsKey(sym)) return;
    subscribe(sym, market: 'crypto');
  }

  /// LiveQuote by app symbol — BTCUSD/BTCUSDT jaisi aliases bhi.
  LiveQuote? quoteFor(String symbol) {
    final s = symbol.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (s.isEmpty) return null;
    final direct = quotes[s];
    if (direct != null && direct.hasPrice) return direct;
    for (final a in _instrumentAliases(s)) {
      final q = quotes[a];
      if (q != null && q.hasPrice) return q;
    }
    return direct ?? quotes[s];
  }

  /// BTCUSD ↔ BTCUSDT, ETHUSD ↔ ETHUSDT, etc.
  static bool sameInstrument(String a, String b) {
    final x = a.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final y = b.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    return _instrumentAliases(x).contains(y);
  }

  static List<String> _instrumentAliases(String sym) {
    final s = sym.toUpperCase();
    if (s.endsWith('USDT') && s.length > 4) {
      return ['${s.substring(0, s.length - 1)}']; // BTCUSDT → BTCUSD
    }
    if (s.endsWith('USD') && !s.endsWith('USDT') && s.length > 3) {
      return ['${s}T']; // BTCUSD → BTCUSDT
    }
    return const [];
  }

  void connectWs() {
    _wsEnabled = true;
    _marketStatusTimer?.cancel();
    _marketStatusTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(refreshMarketStatuses()),
    );
    unawaited(refreshMarketStatuses());
    if (_ws != null || _closed) return;
    unawaited(_connect());
  }

  /// Logout pe WebSocket puri tarah band (koi reconnect nahi).
  void disconnectWs() {
    _wsEnabled = false;
    _reconnect?.cancel();
    _marketStatusTimer?.cancel();
    _marketStatusTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    final old = _ws;
    _ws = null;
    wsConnected = false;
    try {
      old?.close();
    } catch (_) {}
  }

  void reconnectWs() {
    if (!_wsEnabled) return;
    _reconnect?.cancel();
    final old = _ws;
    _ws = null;
    wsConnected = false;
    try {
      old?.close();
    } catch (_) {}
    unawaited(_connect());
  }

  /// Max ~6–7 updates/sec to the UI, no matter how fast ticks arrive.
  /// Lower = snappier prices; higher = less rebuild pressure.
  static const _tickUiMs = 160;

  void _notifyTick() {
    final now = DateTime.now();
    final last = _lastTickNotify;
    if (last == null || now.difference(last).inMilliseconds >= _tickUiMs) {
      _lastTickNotify = now;
      notifyListeners();
      return;
    }
    _tickTimer ??= Timer(const Duration(milliseconds: _tickUiMs), () {
      _tickTimer = null;
      _lastTickNotify = DateTime.now();
      notifyListeners();
    });
  }

  Future<void> _connect() async {
    final gen = _sessionGen;
    try {
      final ws = await WebSocket.connect(ApiConfig.wsUrl);
      // Account switched while connecting — drop this socket.
      if (!_wsEnabled || gen != _sessionGen) {
        try {
          await ws.close();
        } catch (_) {}
        return;
      }
      _ws = ws;
      wsConnected = true;
      notifyListeners();
      _identify();
      unawaited(refreshMarketStatuses());
      for (final e in _subs.entries) {
        _send({'type': 'subscribe', 'market': e.value, 'symbol': e.key});
      }
      ws.listen(
        (raw) {
          if (gen != _sessionGen || !identical(_ws, ws)) return;
          _onMessage(raw);
        },
        onDone: () => _onDrop(ws),
        onError: (_) => _onDrop(ws),
        cancelOnError: true,
      );
    } catch (_) {
      if (gen == _sessionGen) _onDrop();
    }
  }

  /// Admin schedule / cron se open-closed; quotes gray ke liye.
  Future<void> refreshMarketStatuses() async {
    try {
      final res = await _request('GET', '/v1/market/statuses', auth: false);
      final data = res['data'];
      if (data is! Map) return;
      var changed = false;
      for (final e in data.entries) {
        final seg = '${e.key}'.trim().toLowerCase();
        if (seg.isEmpty) continue;
        final raw = e.value;
        final open = raw is Map && raw['isMarketOpen'] == true;
        if (marketOpenBySegment[seg] != open) {
          marketOpenBySegment[seg] = open;
          changed = true;
        } else {
          marketOpenBySegment.putIfAbsent(seg, () => open);
        }
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  String segmentForSymbol(String symbol) {
    final code = symbol.trim().toUpperCase();
    for (final w in watchlist) {
      if (w.code.toUpperCase() == code && w.segment.trim().isNotEmpty) {
        return w.segment.trim().toLowerCase();
      }
    }
    if (code.contains('USDT') ||
        code.endsWith('USD') &&
            (code.startsWith('BTC') || code.startsWith('ETH'))) {
      return 'crypto';
    }
    if (code.startsWith('XAU') ||
        code.startsWith('XAG') ||
        code == 'SILVER' ||
        code == 'GOLD') {
      return 'metal';
    }
    if (code.contains('OIL') || code.startsWith('UKO') || code.startsWith('USO')) {
      return 'energy';
    }
    if (code.contains('30') ||
        code.contains('100') ||
        code.contains('500') ||
        code.startsWith('NAS') ||
        code.startsWith('US') && code.length <= 5 && !code.contains('USD')) {
      // rough indices heuristic; watchlist segment preferred
      if (code == 'US30' ||
          code == 'NAS100' ||
          code == 'US500' ||
          code == 'GER30') {
        return 'indices';
      }
    }
    return 'forex';
  }

  bool isMarketOpenForSymbol(String symbol) {
    final seg = segmentForSymbol(symbol);
    if (!marketOpenBySegment.containsKey(seg)) {
      // aliases: indexes ↔ indices
      if (seg == 'indices' && marketOpenBySegment.containsKey('indexes')) {
        return marketOpenBySegment['indexes'] == true;
      }
      if (seg == 'indexes' && marketOpenBySegment.containsKey('indices')) {
        return marketOpenBySegment['indices'] == true;
      }
      // Status abhi load nahi — sirf price se decide (no false gray flash).
      return true;
    }
    return marketOpenBySegment[seg] == true;
  }

  /// Closed market ya live quote nahi → bid/ask gray.
  bool isQuoteInactive(String symbol) {
    final live = quoteFor(symbol);
    final noPrice = live == null || !live.hasPrice;
    final closed = !isMarketOpenForSymbol(symbol);
    return noPrice || closed;
  }

  void _onDrop([WebSocket? closed]) {
    // Stale socket from a previous account must not wipe the new connection.
    if (closed != null && _ws != null && !identical(closed, _ws)) return;
    _ws = null;
    if (wsConnected) {
      wsConnected = false;
      notifyListeners();
    }
    _reconnect?.cancel();
    if (!_closed && _wsEnabled) {
      _reconnect = Timer(
        const Duration(seconds: 3),
        () => unawaited(_connect()),
      );
    }
  }

  /// Account-scoped WS payloads: drop if they belong to another account.
  bool _eventForCurrentAccount(Map<String, dynamic> data) {
    final id = '${data['accountId'] ?? ''}'.trim();
    if (id.isEmpty) return true;
    final current = session?.accountId ?? '';
    if (current.isEmpty) return false;
    return id == current;
  }

  void _identify() {
    final s = session;
    if (s == null) return;
    _send({'type': 'join', 'route': 'account'});
    _send({'type': 'identify', 'accountId': s.accountId});
  }

  void _send(Map<String, dynamic> msg) {
    try {
      if (session != null && msg['type'] == 'subscribe') {
        msg.putIfAbsent('accountId', () => session!.accountId);
      }
      _ws?.add(jsonEncode(msg));
    } catch (_) {}
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode('$raw') as Map<String, dynamic>;
      final type = msg['type'] as String?;
      if (type == 'market_status') {
        final data = msg['data'];
        if (data is Map) {
          final seg = '${data['segment'] ?? ''}'.trim().toLowerCase();
          if (seg.isNotEmpty) {
            marketOpenBySegment[seg] = data['isMarketOpen'] == true;
            _notifyTick();
          }
        }
        return;
      }
      if (type == 'orderbook') {
        final data = msg['data'] as Map<String, dynamic>?;
        if (data == null) return;
        final code = '${data['code'] ?? ''}'
            .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
            .toUpperCase();
        if (code.isEmpty) return;
        final bid = _d(data['bids']?[0]?['price']);
        final ask = _d(data['asks']?[0]?['price']);
        if (bid <= 0 || ask <= 0) return;
        final t = _date(data['tick_time']) ?? DateTime.now();

        // Provider code (BTCUSDT) + app symbols (BTCUSD) dono update.
        final targets = <String>{code, ..._instrumentAliases(code)};
        for (final sub in _subs.keys) {
          if (sameInstrument(sub, code)) targets.add(sub);
        }
        for (final p in positions.values) {
          if (sameInstrument(p.symbol, code)) {
            targets.add(p.symbol.toUpperCase());
          }
        }

        for (final sym in targets) {
          final q = quotes.putIfAbsent(sym, () => LiveQuote(sym));
          q.prevBid = q.bid == 0 ? bid : q.bid;
          q.bid = bid;
          q.ask = ask;
          q.noteTick(bid, ask);
          q.time = t;
          if (q.dayHigh > 0) q.dayHigh = q.dayHigh < bid ? bid : q.dayHigh;
          if (q.dayLow > 0) q.dayLow = q.dayLow > bid ? bid : q.dayLow;
          final list = _ticks.putIfAbsent(sym, () => []);
          list.add((t, bid, ask));
          if (list.length > 4000) list.removeRange(0, list.length - 4000);
        }

        // Trade mark = same live tick (BUY=bid, SELL=ask). PnL server se aata hai.
        var posChanged = false;
        for (final e in positions.entries.toList()) {
          final p = e.value;
          if (!sameInstrument(p.symbol, code)) continue;
          final mark = p.isBuy ? bid : ask;
          if ((p.currentPrice - mark).abs() < 1e-12) continue;
          positions[e.key] = p.copyWith(currentPrice: mark);
          posChanged = true;
        }
        // Always throttle — unthrottled notify was freezing the UI.
        if (posChanged || targets.isNotEmpty) {
          _notifyTick();
        }
        return;
      }
      if (msg['status'] == 'subscribed') {
        final sym = '${msg['symbol'] ?? ''}'.toUpperCase();
        final q = quotes.putIfAbsent(sym, () => LiveQuote(sym));
        q.dayOpen = _d(msg['dayOpen']);
        q.dayHigh = _d(msg['dayHigh']);
        q.dayLow = _d(msg['dayLow']);
        q.dayClose = _d(msg['dayClose']);
        // Weekend / closed market: live ticks nahi aate — last close se seed
        // taaki watchlist 0.00 na dikhe (gray + last price).
        final seedBid = _d(msg['bid']);
        final seedAsk = _d(msg['ask']);
        if (!q.hasPrice) {
          final double bid = seedBid > 0
              ? seedBid
              : (q.dayClose > 0
                    ? q.dayClose
                    : (q.dayOpen > 0 ? q.dayOpen : 0.0));
          final double ask = seedAsk > 0 ? seedAsk : bid;
          if (bid > 0 && ask > 0) {
            q.bid = bid;
            q.ask = ask;
            q.prevBid = bid;
            q.time ??= DateTime.now();
          }
        }
        notifyListeners();
        return;
      }
      final data = msg['data'];
      if (data is! Map<String, dynamic>) return;
      if (!_eventForCurrentAccount(data)) return;
      switch (type) {
        case 'live_account':
          account = LiveAccount.fromJson(data);
          accountLoaded = true;
          notifyListeners();
        case 'live_position':
          final p = LivePosition.fromWs(data);
          if (p.positionId.isNotEmpty) {
            if (p.ticket != null) {
              positions.removeWhere(
                (id, old) => id != p.positionId && old.ticket == p.ticket,
              );
            }
            // Prefer fresher LiveQuote mark over stale REST/WS snapshot.
            final q = quoteFor(p.symbol);
            final merged = (q != null && q.hasPrice)
                ? p.copyWith(currentPrice: p.isBuy ? q.bid : q.ask)
                : p;
            positions[p.positionId] = merged;
            ensureSubscribed(p.symbol);
            notifyListeners();
          }
        case 'live_position_closed':
          positions.remove('${data['positionId'] ?? ''}');
          notifyListeners();
          unawaited(refreshAccount());
        case 'live_pending':
          final o = PendingOrder.fromWs(data);
          if (o.orderId.isNotEmpty) {
            if (o.ticket != null) {
              pendings.removeWhere(
                (id, old) => id != o.orderId && old.ticket == o.ticket,
              );
            }
            pendings[o.orderId] = o;
            ensureSubscribed(o.symbol);
            notifyListeners();
          }
        case 'live_pending_cancel':
        case 'live_pending_execute':
          pendings.remove('${data['orderId'] ?? data['positionId'] ?? ''}');
          notifyListeners();
          unawaited(refreshAccount());
      }
    } catch (_) {}
  }

  /// Last [max] bid tick prices (New Order screen ke tick chart
  /// ke liye, purane se naye order me).
  List<double> tickHistoryFor(String symbol, {int max = 200}) {
    final list = _ticks[symbol.toUpperCase()] ?? const [];
    final start = list.length > max ? list.length - max : 0;
    return [for (var i = start; i < list.length; i++) list[i].$2];
  }

  /// Last [max] bid+ask tick pairs - chart pe bid aur ask ki
  /// alag-alag lines ke liye.
  List<({double bid, double ask})> tickPairsFor(
    String symbol, {
    int max = 200,
  }) {
    final list = _ticks[symbol.toUpperCase()] ?? const [];
    final start = list.length > max ? list.length - max : 0;
    return [
      for (var i = start; i < list.length; i++)
        (bid: list[i].$2, ask: list[i].$3),
    ];
  }

  /// Build OHLC candles from collected ticks. [frameMinutes] e.g. 1,5,15,60.
  List<({DateTime t, double o, double h, double l, double c})> candlesFor(
    String symbol,
    int frameMinutes, {
    int count = 120,
  }) {
    final ticks = _ticks[symbol.toUpperCase()] ?? const [];
    if (ticks.isEmpty) return const [];
    final buckets = <int, List<double>>{};
    final order = <int>[];
    for (final (time, price, _) in ticks) {
      final key = time.millisecondsSinceEpoch ~/ (frameMinutes * 60000);
      if (!buckets.containsKey(key)) {
        buckets[key] = [];
        order.add(key);
      }
      buckets[key]!.add(price);
    }
    order.sort();
    final result = [
      for (final key in order)
        (
          t: DateTime.fromMillisecondsSinceEpoch(key * frameMinutes * 60000),
          o: buckets[key]!.first,
          h: buckets[key]!.reduce((a, b) => a > b ? a : b),
          l: buckets[key]!.reduce((a, b) => a < b ? a : b),
          c: buckets[key]!.last,
        ),
    ];
    return result.length > count
        ? result.sublist(result.length - count)
        : result;
  }

  @override
  void dispose() {
    _closed = true;
    _reconnect?.cancel();
    _tickTimer?.cancel();
    _ws?.close();
    super.dispose();
  }
}

/// Global app-wide instance.
final tradingService = TradingService();

void unawaited(Future<void> f) {
  f.catchError((_) {});
}

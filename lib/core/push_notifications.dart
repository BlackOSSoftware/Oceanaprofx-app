import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trading_service.dart';

const _prefsKeyEnabled = 'push_notifications_enabled';
const _channelId = 'oceana_default';
const _channelName = 'Oceana Alerts';

/// Background isolate — must be top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep lightweight — no UI work here.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
}

/// FCM bootstrap for Oceana Android APK.
///
/// Requires `android/app/google-services.json` from Firebase project
/// `trading-fdee2` for package `com.alstrades.portal`.
///
/// Android does **not** auto-display notification payloads while the app is
/// in the foreground — we mirror them via [flutter_local_notifications].
abstract final class PushNotifications {
  static bool _ready = false;
  static bool _enabled = true;
  static int _localId = 0;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _openSub;
  static StreamSubscription<RemoteMessage>? _fgSub;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Bumps when a push arrives so inbox UI / More badge can refresh.
  /// Value is a monotonic tick (listeners ignore the number).
  static final ValueNotifier<int> inboxTick = ValueNotifier<int>(0);

  static bool get enabled => _enabled;

  static void _notifyInboxChanged() {
    inboxTick.value = inboxTick.value + 1;
  }

  /// FCM often lands before inbox DB write finishes — soft delay + immediate.
  static void _scheduleInboxRefresh() {
    _notifyInboxChanged();
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        _notifyInboxChanged();
      }),
    );
  }

  static Future<void> init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKeyEnabled) ?? true;

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _initLocalNotifications();

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (_enabled) {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint('[FCM] permission denied');
          _enabled = false;
          await prefs.setBool(_prefsKeyEnabled, false);
          _ready = true;
          return;
        }
      }

      _openSub?.cancel();
      _openSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        debugPrint('[FCM] opened: ${msg.messageId} ${msg.notification?.title}');
        _scheduleInboxRefresh();
      });

      _fgSub?.cancel();
      _fgSub = FirebaseMessaging.onMessage.listen((msg) {
        debugPrint(
          '[FCM] foreground: ${msg.notification?.title} / ${msg.notification?.body}',
        );
        unawaited(_showForeground(msg));
        _scheduleInboxRefresh();
      });

      _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen((t) {
        if (_enabled) unawaited(_uploadToken(t));
      });

      _ready = true;
      if (_enabled) await syncTokenWithBackend();
    } catch (e, st) {
      // Missing google-services.json / Firebase misconfig should not crash app.
      debugPrint('[FCM] init failed: $e\n$st');
      _ready = false;
    }
  }

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (_) => _scheduleInboxRefresh(),
    );

    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Trading and account notifications',
        importance: Importance.high,
      ),
    );
    if (_enabled) {
      await android?.requestNotificationsPermission();
    }
  }

  /// Settings toggle — More → Notifications.
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, value);

    if (!_ready) {
      await init();
      return;
    }

    if (value) {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _enabled = false;
        await prefs.setBool(_prefsKeyEnabled, false);
        return;
      }
      await syncTokenWithBackend();
    } else {
      await _local.cancelAll();
    }
  }

  static Future<void> _showForeground(RemoteMessage msg) async {
    if (!_enabled) return;
    final n = msg.notification;
    final title = n?.title ?? msg.data['title']?.toString() ?? 'Oceana';
    final body = n?.body ?? msg.data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;

    _localId = (_localId + 1) % 100000;
    await _local.show(
      id: _localId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Trading and account notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: msg.data.isEmpty ? null : msg.data.toString(),
    );
  }

  /// Call after portal login / restore so token is linked to user.
  static Future<void> syncTokenWithBackend() async {
    if (!_enabled) return;
    if (!_ready && Firebase.apps.isEmpty) return;
    try {
      if (!_ready) {
        await init();
        if (!_ready || !_enabled) return;
      }
      if (!tradingService.hasUserPortal) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] no token yet');
        return;
      }
      await _uploadToken(token);
    } catch (e) {
      debugPrint('[FCM] sync failed: $e');
    }
  }

  static Future<void> _uploadToken(String token) async {
    if (!tradingService.hasUserPortal || !_enabled) return;
    try {
      await tradingService.saveFcmToken(token);
      debugPrint('[FCM] token saved (${token.substring(0, 12)}…)');
    } catch (e) {
      debugPrint('[FCM] save token API failed: $e');
    }
  }
}

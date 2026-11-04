import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/push_notifications.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

/// Portal notification inbox — tap opens detail; closing marks it read.
class OceanaNotificationsPage extends StatefulWidget {
  const OceanaNotificationsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OceanaNotificationsPage()),
    );
  }

  @override
  State<OceanaNotificationsPage> createState() =>
      _OceanaNotificationsPageState();
}

class _OceanaNotificationsPageState extends State<OceanaNotificationsPage>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _busy = false;
  bool _loadingInFlight = false;
  bool _loadAgain = false;
  String? _error;
  int _unread = 0;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotifications.inboxTick.addListener(_onPushInbox);
    _load(showSpinner: true);
    // Push often lands before inbox DB is ready — soft retry.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _load(showSpinner: false);
      }),
    );
  }

  @override
  void dispose() {
    PushNotifications.inboxTick.removeListener(_onPushInbox);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _load(showSpinner: false);
    }
  }

  void _onPushInbox() {
    if (!mounted) return;
    _load(showSpinner: false);
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (!tradingService.hasUserPortal) {
      setState(() {
        _loading = false;
        _items = [];
        _unread = 0;
        _error = 'Sign in to see notifications';
      });
      return;
    }
    if (_loadingInFlight) {
      _loadAgain = true;
      return;
    }
    _loadingInFlight = true;
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      do {
        _loadAgain = false;
        final res = await tradingService.fetchNotificationInbox();
        if (!mounted) return;
        setState(() {
          _items = res.list;
          _unread = res.unreadCount;
          _loading = false;
          _error = null;
        });
      } while (_loadAgain && mounted);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_items.isEmpty) {
          _error = e.toString().replaceFirst('ApiException: ', '');
        }
      });
    } finally {
      _loadingInFlight = false;
    }
  }

  Future<void> _openDetail(Map<String, dynamic> n) async {
    if (!mounted) return;
    final title = '${n['title'] ?? 'Oceana'}';
    final message = '${n['message'] ?? ''}';
    final type =
        '${(n['data'] is Map ? n['data']['type'] : null) ?? 'GENERAL'}';
    final when = _when(n['createdAt']);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              16 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OcColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: OcColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        OcIcons.bell,
                        color: OcColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notification',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: OcColors.text,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: OcColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: OcColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: OcColors.text,
                    height: 1.25,
                  ),
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    when,
                    style: TextStyle(
                      color: OcColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: OcColors.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: OcColors.border),
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: OcColors.textSecondary,
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: OcColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // After user has opened/read the detail, clear from unread inbox.
    if (mounted) await _markOne(n);
  }

  Future<void> _markOne(Map<String, dynamic> n) async {
    final id = '${n['_id'] ?? ''}';
    if (id.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final left = await tradingService.markNotificationRead(id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => '${e['_id']}' != id).toList();
        _unread = left;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markAll() async {
    if (_busy || _items.isEmpty) return;
    setState(() => _busy = true);
    try {
      await tradingService.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        _items = [];
        _unread = 0;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _when(dynamic raw) {
    final dt = DateTime.tryParse('$raw');
    if (dt == null) return '';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year}, $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OcColors.bg,
      appBar: AppBar(
        backgroundColor: OcColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(OcIcons.arrowBack, color: OcColors.text, size: 22),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: OcColors.text,
          ),
        ),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _busy ? null : _markAll,
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: OcColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: OcColors.primary,
                ),
              ),
            )
          : RefreshIndicator(
              color: OcColors.primary,
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.22,
                        ),
                        Icon(OcIcons.bell, size: 40, color: OcColors.textMuted),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: OcColors.textSecondary,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.18,
                            ),
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: OcColors.primarySoft,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Icon(
                                  OcIcons.bell,
                                  color: OcColors.primary,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "You're all caught up",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: OcColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'New alerts from Oceana will show here.\nOpen a notification to read it.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: OcColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          itemCount: _items.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 4, left: 2),
                                child: Text(
                                  '$_unread unread — tap to open',
                                  style: TextStyle(
                                    color: OcColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }
                            final n = _items[i - 1];
                            final title = '${n['title'] ?? 'Oceana'}';
                            final message = '${n['message'] ?? ''}';
                            final type =
                                '${(n['data'] is Map ? n['data']['type'] : null) ?? 'GENERAL'}';
                            return Material(
                              color: OcColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => _openDetail(n),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    14,
                                    14,
                                    14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: OcColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: OcColors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: OcColors.primary
                                                  .withValues(alpha: 0.28),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 14.5,
                                                      color: OcColors.text,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: OcColors.primarySoft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      6,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    type,
                                                    style: TextStyle(
                                                      color: OcColors.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 9.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (message.isNotEmpty) ...[
                                              const SizedBox(height: 5),
                                              Text(
                                                message,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: OcColors.textSecondary,
                                                  fontSize: 13,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _when(n['createdAt']),
                                                    style: TextStyle(
                                                      color: OcColors.textMuted,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  'Open',
                                                  style: TextStyle(
                                                    color: OcColors.primary,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                Icon(
                                                  OcIcons.chevronRight,
                                                  size: 14,
                                                  color: OcColors.primary,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}

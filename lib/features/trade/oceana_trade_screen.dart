import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/shell_controller.dart';
import '../../core/trade_sound.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_badge.dart';
import '../../ui/widgets/oc_svc_scope.dart';
import '../quotes/symbol_flags.dart';
import 'oceana_close_modify_page.dart';
import 'oceana_pending_order_page.dart';

/// Trade tab — Market / Pending / History matching Tenax SS (`#1414C7`).
class OceanaTradeScreen extends StatefulWidget {
  const OceanaTradeScreen({super.key, this.active = true});

  final bool active;

  @override
  State<OceanaTradeScreen> createState() => _OceanaTradeScreenState();
}

class _OceanaTradeScreenState extends State<OceanaTradeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // History filters
  _HistPeriod _period = _HistPeriod.today;
  _Direction _direction = _Direction.all;
  final _expanded = <String>{};
  bool _histLoading = false;
  bool _switching = false;
  List<_HistDeal> _deals = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) {
        setState(() {});
        if (_tabs.index == 2) _loadHistory();
      }
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!await tradingService.ensureSession()) {
      if (mounted) setState(() => _histLoading = false);
      return;
    }
    if (!mounted) return;
    setState(() => _histLoading = true);
    try {
      final range = _period.range;
      final from = range?.start;
      final to = range?.end;
      // History tab = closed trades only (not deal in/out / balance rows).
      final res =
          await tradingService.history('positions', from: from, to: to);
      List<Map<String, dynamic>> asMaps(Object? v) => [
            if (v is List)
              for (final e in v)
                if (e is Map) Map<String, dynamic>.from(e),
          ];
      final posMaps = asMaps(res['positions'] ?? res['data']);
      final list = <_HistDeal>[
        for (final m in posMaps) ?_HistDeal.fromClosedPosition(m),
      ]..sort((a, b) {
          final at = a.closeTime?.millisecondsSinceEpoch ?? 0;
          final bt = b.closeTime?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
      if (!mounted) return;
      setState(() => _deals = list);
    } catch (_) {
      if (mounted) setState(() => _deals = const []);
    } finally {
      if (mounted) setState(() => _histLoading = false);
    }
  }

  List<_HistDeal> get _filteredDeals {
    return [
      for (final d in _deals)
        if (_direction == _Direction.all ||
            (_direction == _Direction.buy && d.isBuy) ||
            (_direction == _Direction.sell && !d.isBuy))
          d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Keep TabBarView OUT of the tick rebuild path — only chrome (PnL /
    // counts / summary) listens to ticks. Lists update themselves.
    final tab = _tabs.index;
    return Scaffold(
      backgroundColor: OcColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            OcSvcScope(
              active: widget.active,
              builder: (context) {
                final live = tradingService.account;
                final positions = tradingService.positions.values.toList();
                final pendings = tradingService.pendings.values.toList();
                final pnl =
                    positions.fold<double>(0, (s, p) => s + p.floatingPnL);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(pnl),
                    if (_switching)
                      LinearProgressIndicator(
                        minHeight: 2,
                        color: OcColors.primary,
                      ),
                    _tabBar(positions.length, pendings.length),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: tab == 2
                          ? _historySummary(_filteredDeals)
                          : _accountSummary(live),
                    ),
                    if (tab == 2) _historyToolbar(),
                  ],
                );
              },
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: const ClampingScrollPhysics(),
                children: [
                  _PositionsList(
                    active: widget.active,
                    onOpen: (p) => _openPositionSheet(p),
                  ),
                  _PendingList(
                    active: widget.active,
                    onOpen: (o) => _openPendingSheet(o),
                  ),
                  _HistoryList(
                    loading: _histLoading,
                    deals: _filteredDeals,
                    expanded: _expanded,
                    onToggle: (id) {
                      setState(() {
                        if (!_expanded.add(id)) _expanded.remove(id);
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(double pnl) {
    final acct = tradingService.session?.accountNumber.trim();
    final showCloseAll =
        _tabs.index == 0 && tradingService.positions.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => ShellScope.of(context).openTab(3),
            icon: _FourDots(size: 18),
          ),
          Expanded(
            child: InkWell(
              onTap: _switching ? null : () => _showAccountSheet(),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${formatMoney(pnl)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: pnl >= 0 ? OcColors.profit : OcColors.loss,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      OcBadge(
                        label: tradingService.isActiveAccountDemo
                            ? 'DEMO'
                            : 'LIVE',
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          (acct != null && acct.isNotEmpty) ? acct : '—',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: OcColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(
                        OcIcons.chevronDown,
                        size: 16,
                        color: OcColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (showCloseAll)
            Material(
              color: OcColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _closeAllPositions,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Close All',
                    style: TextStyle(
                      color: OcColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAccountSheet() async {
    if (tradingService.hasUserPortal) {
      try {
        await tradingService.refreshLinkedAccounts();
      } catch (_) {}
      if (!mounted) return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OcColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: tradingService,
          builder: (ctx, _) {
            final session = tradingService.session;
            final sessionNum = session?.accountNumber.trim() ?? '';
            final sessionId = session?.accountId.trim() ?? '';
            final accounts = tradingService.linkedAccounts
                .where((a) => a.accountNumber.trim().isNotEmpty)
                .toList();
            final rows = accounts.isNotEmpty
                ? accounts
                : [
                    if (session != null && sessionNum.isNotEmpty)
                      LinkedTradingAccount(
                        id: session.accountId,
                        accountNumber: session.accountNumber,
                        accountType: tradingService.isActiveAccountDemo
                            ? 'demo'
                            : 'live',
                        balance: tradingService.account.balance,
                        equity: tradingService.account.equity,
                        isPrimary: true,
                      ),
                  ];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Select Account',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(OcIcons.x),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final a in rows)
                      _TradeAccountTile(
                        account: a,
                        active: (sessionId.isNotEmpty && a.id == sessionId) ||
                            (sessionNum.isNotEmpty &&
                                a.accountNumber.trim() == sessionNum),
                        onTap: () async {
                          final isActive =
                              (sessionId.isNotEmpty && a.id == sessionId) ||
                                  (sessionNum.isNotEmpty &&
                                      a.accountNumber.trim() == sessionNum);
                          if (isActive) {
                            Navigator.pop(ctx);
                            return;
                          }
                          Navigator.pop(ctx);
                          setState(() => _switching = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            if (a.id.isNotEmpty &&
                                tradingService.hasUserPortal) {
                              await tradingService.activateLinkedAccount(a.id);
                            } else if (tradingService.fpAccounts.any(
                              (f) =>
                                  f.accountNumber == a.accountNumber &&
                                  f.password.isNotEmpty,
                            )) {
                              final fp = tradingService.fpAccounts.firstWhere(
                                (f) => f.accountNumber == a.accountNumber,
                              );
                              await tradingService.login(
                                fp.accountNumber,
                                fp.password,
                              );
                            }
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  e
                                      .toString()
                                      .replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) setState(() => _switching = false);
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _closeAllPositions() async {
    final positions = tradingService.positions.values.toList();
    if (positions.isEmpty) return;
    final ids = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OcColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _CloseAllSheet(positions: positions),
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    var anyOk = false;
    var anyErr = false;
    for (final id in ids) {
      try {
        await tradingService.closePosition(id);
        anyOk = true;
      } catch (_) {
        anyErr = true;
      }
    }
    if (anyOk) {
      unawaited(TradeSound.ok());
    } else if (anyErr) {
      unawaited(TradeSound.error());
    }
  }

  Widget _tabBar(int marketN, int pendingN) {
    Widget badge(int n) => Container(
          margin: EdgeInsets.only(left: 4),
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: OcColors.primaryMuted,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: OcColors.primary,
              height: 1,
            ),
          ),
        );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE6E6EA), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabs,
        labelColor: OcColors.text,
        unselectedLabelColor: const Color(0xFF9A9AA3),
        indicatorColor: OcColors.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [const Text('Market'), badge(marketN)],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [const Text('Pending'), badge(pendingN)],
            ),
          ),
          const Tab(text: 'History'),
        ],
      ),
    );
  }

  Widget _accountSummary(LiveAccount live) {
    return _SummaryCard(
      rows: [
        ('Balance', formatMoney(live.balance)),
        ('Credit', '0.00'),
        ('Equity', formatMoney(live.equity)),
        ('Margin', formatMoney(live.usedMargin)),
        ('Free Margin', formatMoney(live.freeMargin)),
        (
          'Margin Level (%)',
          live.marginLevel > 0 ? live.marginLevel.toStringAsFixed(2) : '0.00',
        ),
      ],
    );
  }

  Widget _historySummary(List<_HistDeal> deals) {
    var profit = 0.0, deposit = 0.0, withdrawal = 0.0, swap = 0.0, comm = 0.0;
    for (final d in deals) {
      if (d.isBalance) {
        d.profit >= 0 ? deposit += d.profit : withdrawal += -d.profit;
      } else {
        profit += d.profit;
        swap += d.swap;
        comm += d.commission;
      }
    }
    final balance = profit + deposit - withdrawal + swap + comm;
    return _SummaryCard(
      rows: [
        ('Profit', formatMoney(profit)),
        ('Deposit', formatMoney(deposit)),
        ('Withdrawal', formatMoney(withdrawal)),
        ('Swap', formatMoney(swap)),
        ('Commission', formatMoney(comm)),
        ('Balance', formatMoney(balance)),
      ],
    );
  }

  Widget _historyToolbar() {
    Widget btn(IconData icon, VoidCallback onTap) => Material(
          color: OcColors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, size: 20, color: OcColors.textSecondary),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: OcColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            btn(OcIcons.calendar, () => _openFilterSheet()),
            const SizedBox(width: 8),
            btn(OcIcons.slidersHorizontal, () => _openDirectionSheet()),
            const SizedBox(width: 8),
            btn(OcIcons.arrowUpDown, () {}),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final picked = await showModalBottomSheet<_HistPeriod>(
      context: context,
      backgroundColor: OcColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _FilterHistorySheet(selected: _period),
    );
    if (picked == null || !mounted) return;
    setState(() => _period = picked);
    await _loadHistory();
  }

  Future<void> _openDirectionSheet() async {
    final picked = await showModalBottomSheet<_Direction>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _DirectionSheet(selected: _direction),
    );
    if (picked == null || !mounted) return;
    setState(() => _direction = picked);
  }

  Future<void> _openPendingSheet(PendingOrder o) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _PendingDetailSheet(
        order: o,
        onCancel: () async {
          final id = o.ticket?.toString() ?? o.orderId;
          final ok = await showDialog<bool>(
            context: ctx,
            builder: (dCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Cancel order?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              content: Text(
                'Cancel ${o.orderType.replaceAll('_', ' ').toLowerCase()} '
                '${o.volume.toStringAsFixed(2)} ${o.symbol}'
                '${id.isNotEmpty ? ' (#$id)' : ''}?',
                style: TextStyle(
                  color: OcColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: Text(
                    'Keep',
                    style: TextStyle(
                      color: OcColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: Text(
                    'Cancel Order',
                    style: TextStyle(
                      color: OcColors.loss,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (ok != true) return;
          if (ctx.mounted) Navigator.pop(ctx);
          try {
            await tradingService.cancelPending(o.orderId);
            unawaited(TradeSound.ok());
          } catch (e) {
            unawaited(TradeSound.error());
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
            );
          }
        },
        onModify: () {
          Navigator.pop(ctx);
          // Edit existing pending — do NOT open place-new (that created a 2nd order).
          OceanaPendingOrderPage.openModify(context, o);
        },
        onNewOrder: () {
          Navigator.pop(ctx);
          OceanaPendingOrderPage.open(
            context,
            symbol: o.symbol,
            volume: o.volume,
          );
        },
        onChart: () {
          Navigator.pop(ctx);
          ShellScope.of(context).openChart(o.symbol);
        },
      ),
    );
  }

  Future<void> _openPositionSheet(LivePosition p) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _PositionDetailSheet(
        position: p,
        onClose: () {
          Navigator.pop(ctx);
          OceanaCloseModifyPage.open(
            context,
            p,
            mode: OceanaPositionPageMode.close,
          );
        },
        onModify: () {
          Navigator.pop(ctx);
          OceanaCloseModifyPage.openModify(context, p);
        },
        onNewOrder: () {
          Navigator.pop(ctx);
          OceanaPendingOrderPage.open(
            context,
            symbol: p.symbol,
            volume: p.volume,
          );
        },
        onChart: () {
          Navigator.pop(ctx);
          ShellScope.of(context).openChart(p.symbol);
        },
      ),
    );
  }
}

/* ---------------- models / enums ---------------- */

enum _HistPeriod { today, week, month, custom }

extension on _HistPeriod {
  String get label => switch (this) {
        _HistPeriod.today => 'Today',
        _HistPeriod.week => 'Last Week',
        _HistPeriod.month => 'Last Month',
        _HistPeriod.custom => 'Custom',
      };

  DateTimeRange? get range {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return switch (this) {
      _HistPeriod.today => DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: end,
        ),
      _HistPeriod.week => DateTimeRange(
          start: DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 7)),
          end: end,
        ),
      _HistPeriod.month => DateTimeRange(
          start: DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 30)),
          end: end,
        ),
      _HistPeriod.custom => null,
    };
  }
}

enum _Direction { all, buy, sell }

class _HistDeal {
  const _HistDeal({
    required this.id,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.openPrice,
    required this.closePrice,
    required this.profit,
    required this.swap,
    required this.commission,
    required this.openTime,
    required this.closeTime,
    required this.isBalance,
    this.stopLoss,
    this.takeProfit,
    this.ticket,
  });

  final String id;
  final String symbol;
  final String side;
  final double volume;
  final double openPrice;
  final double closePrice;
  final double profit;
  final double swap;
  final double commission;
  final DateTime? openTime;
  final DateTime? closeTime;
  final bool isBalance;
  final double? stopLoss;
  final double? takeProfit;
  final String? ticket;

  bool get isBuy => side.toUpperCase().contains('BUY');

  static double _d(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

  static DateTime? _t(dynamic v) {
    if (v == null) return null;
    if (v is int) {
      // seconds vs ms
      final ms = v < 20000000000 ? v * 1000 : v;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.tryParse('$v');
  }

  static _HistDeal? fromClosedPosition(Map<String, dynamic> j) {
    if (j['isBalanceEntry'] == true ||
        '${j['type'] ?? ''}'.toUpperCase() == 'BALANCE') {
      return null;
    }
    final symbol = '${j['symbol'] ?? ''}'.trim();
    if (symbol.isEmpty) return null;
    final side = '${j['side'] ?? j['type'] ?? 'BUY'}'.toUpperCase();
    final ticket = '${j['ticket'] ?? j['orderId'] ?? j['positionId'] ?? ''}';
    return _HistDeal(
      id: 'pos-${j['positionId'] ?? ticket}$symbol${j['closeTime'] ?? ''}',
      symbol: symbol,
      side: side.contains('SELL') ? 'SELL' : 'BUY',
      volume: _d(j['qty'] ?? j['volume']),
      openPrice: _d(j['openPrice'] ?? j['priceOpen']),
      closePrice: _d(j['closePrice'] ?? j['priceClose'] ?? j['currentPrice']),
      profit: _d(j['grossProfit'] ?? j['profitLoss'] ?? j['profit']),
      swap: _d(j['swap']),
      commission: _d(j['commission']),
      openTime: _t(j['openTime']),
      closeTime: _t(j['closeTime'] ?? j['updatedAt']),
      isBalance: false,
      stopLoss: _d(j['stopLoss']) == 0 ? null : _d(j['stopLoss']),
      takeProfit: _d(j['takeProfit']) == 0 ? null : _d(j['takeProfit']),
      ticket: ticket.isEmpty ? null : ticket,
    );
  }
}

/* ---------------- shared UI ---------------- */

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: OcColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (final r in rows) _DotRow(label: r.$1, value: r.$2),
        ],
      ),
    );
  }
}

class _DotRow extends StatelessWidget {
  const _DotRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final emphasize = label == 'Profit' || label == 'Balance';
    final style = TextStyle(
      fontSize: 13,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
      color: OcColors.text,
      height: 1.25,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, style: style, maxLines: 1, softWrap: false),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: SizedBox(
              height: 13,
              child: CustomPaint(painter: _DotsPainter()),
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = OcColors.primaryMuted;
    const gap = 7.0;
    const r = 1.0;
    final y = size.height - r - 1;
    for (var x = r; x <= size.width - r; x += gap) {
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FourDots extends StatelessWidget {
  _FourDots({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    const gap = 3.0;
    final d = (size - gap) / 2;
    Widget dot() => Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            color: OcColors.text,
            shape: BoxShape.circle,
          ),
        );
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
        ],
      ),
    );
  }
}

String _fmtTs(DateTime? t, {bool dashes = false}) {
  if (t == null) return '—';
  final y = t.year.toString().padLeft(4, '0');
  final m = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  final ss = t.second.toString().padLeft(2, '0');
  final sep = dashes ? '-' : '.';
  return '$y$sep$m$sep$d $hh:$mm:$ss';
}

String _fmtPrice(double v, {String? symbol}) {
  if (v <= 0) return '—';
  final s = (symbol ?? '').toUpperCase();
  final digits = digitsFor(s.isEmpty ? 'EURUSD' : s, v);
  return v.toStringAsFixed(digits);
}

BoxDecoration _cardDeco(BorderRadius radius) => BoxDecoration(
      color: OcColors.surface,
      borderRadius: radius,
      border: Border.all(color: OcColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: OcColors.isDark ? 0.35 : 0.06),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
    );

/* ---------------- lists ---------------- */

class _PositionsList extends StatefulWidget {
  const _PositionsList({required this.active, required this.onOpen});
  final bool active;
  final ValueChanged<LivePosition> onOpen;

  @override
  State<_PositionsList> createState() => _PositionsListState();
}

class _PositionsListState extends State<_PositionsList>
    with AutomaticKeepAliveClientMixin {
  String _stamp = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _stamp = _posStamp();
    tradingService.addListener(_onTick);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onTick);
    super.dispose();
  }

  String _posStamp() {
    final buf = StringBuffer();
    for (final p in tradingService.positions.values) {
      buf.write(
        '${p.positionId}:${p.currentPrice}:${p.floatingPnL}|',
      );
    }
    return buf.toString();
  }

  void _onTick() {
    if (!mounted || !widget.active) return;
    final next = _posStamp();
    if (next == _stamp) return;
    _stamp = next;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final positions = tradingService.positions.values.toList();
    if (positions.isEmpty) {
      return Center(
        child: Text(
          'No open positions',
          style: TextStyle(color: OcColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: positions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = positions[i];
        final q = tradingService.quoteFor(p.symbol);
        final cur = q?.hasPrice == true
            ? (p.isBuy ? q!.bid : q!.ask)
            : p.currentPrice;
        return RepaintBoundary(
          child: InkWell(
            onTap: () => widget.onOpen(p),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: _cardDeco(BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              p.symbol,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: OcColors.text,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '${p.isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: p.isBuy ? OcColors.ask : OcColors.bid,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          '${_fmtPrice(p.openPrice, symbol: p.symbol)} -> ${_fmtPrice(cur, symbol: p.symbol)}',
                          style: TextStyle(
                            color: OcColors.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${formatMoney(p.floatingPnL)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: p.floatingPnL >= 0
                          ? OcColors.profit
                          : OcColors.loss,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PendingList extends StatefulWidget {
  const _PendingList({required this.active, required this.onOpen});
  final bool active;
  final ValueChanged<PendingOrder> onOpen;

  @override
  State<_PendingList> createState() => _PendingListState();
}

class _PendingListState extends State<_PendingList>
    with AutomaticKeepAliveClientMixin {
  String _stamp = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _stamp = _pendStamp();
    tradingService.addListener(_onTick);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onTick);
    super.dispose();
  }

  String _pendStamp() {
    final buf = StringBuffer();
    for (final o in tradingService.pendings.values) {
      buf.write('${o.orderId}:${o.currentPrice}:${o.price}|');
    }
    return buf.toString();
  }

  void _onTick() {
    if (!mounted || !widget.active) return;
    final next = _pendStamp();
    if (next == _stamp) return;
    _stamp = next;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pendings = tradingService.pendings.values.toList();
    if (pendings.isEmpty) {
      return Center(
        child: Text(
          'No pending orders',
          style: TextStyle(color: OcColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: pendings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final o = pendings[i];
        final q = tradingService.quoteFor(o.symbol);
        final cur = o.currentPrice ??
            (q != null && q.hasPrice ? (o.isBuy ? q.ask : q.bid) : 0);
        return RepaintBoundary(
          child: InkWell(
            onTap: () => widget.onOpen(o),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: _cardDeco(BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              o.symbol,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                height: 1.15,
                                color: OcColors.text,
                              ),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '${o.isBuy ? 'buy' : 'sell'} ${o.volume.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: o.isBuy ? OcColors.ask : OcColors.bid,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${_fmtPrice(o.price, symbol: o.symbol)} -> ${_fmtPrice(cur, symbol: o.symbol)}',
                          style: TextStyle(
                            color: OcColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'placed',
                    style: TextStyle(
                      color: OcColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  _HistoryList({
    required this.loading,
    required this.deals,
    required this.expanded,
    required this.onToggle,
  });

  final bool loading;
  final List<_HistDeal> deals;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (loading && deals.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    if (deals.isEmpty) {
      return Center(
        child: Text('No history', style: TextStyle(color: OcColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: deals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final d = deals[i];
        final open = expanded.contains(d.id);
        final sl = d.stopLoss == null
            ? '0.00'
            : _fmtPrice(d.stopLoss!, symbol: d.symbol);
        final tp = d.takeProfit == null
            ? '0.00'
            : _fmtPrice(d.takeProfit!, symbol: d.symbol);
        return InkWell(
          onTap: () => onToggle(d.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: _cardDeco(BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1: symbol + side/vol ........ close time
                Row(
                  children: [
                    Text(
                      d.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${d.isBuy ? 'buy' : 'sell'} ${d.volume.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: d.isBuy ? OcColors.ask : OcColors.bid,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        height: 1.15,
                      ),
                    ),
                    Spacer(),
                    Text(
                      _fmtTs(d.closeTime),
                      style: TextStyle(
                        color: OcColors.textMuted,
                        fontSize: 10.5,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      open ? OcIcons.chevronUp : OcIcons.chevronDown,
                      size: 14,
                      color: OcColors.textMuted,
                    ),
                  ],
                ),
                SizedBox(height: 4),
                // Row 2: open -> close ................ $pnl
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_fmtPrice(d.openPrice, symbol: d.symbol)} -> ${_fmtPrice(d.closePrice, symbol: d.symbol)}',
                        style: TextStyle(
                          color: OcColors.textMuted,
                          fontSize: 11,
                          height: 1.15,
                        ),
                      ),
                    ),
                    Text(
                      '\$${formatMoney(d.profit)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        height: 1.15,
                        color:
                            d.profit >= 0 ? OcColors.profit : OcColors.loss,
                      ),
                    ),
                    const SizedBox(width: 16), // align under chevron column
                  ],
                ),
                if (open) ...[
                  const SizedBox(height: 8),
                  const Divider(
                    height: 1,
                    thickness: 0.7,
                    color: Color(0xFFE6E6EA),
                  ),
                  const SizedBox(height: 6),
                  // SS grid: S/L|T/P, Open|Close, Swap|Commission, ID|Duration
                  _histDetailGrid([
                    ('S/L', sl),
                    ('T/P', tp),
                    ('Open', _fmtTs(d.openTime, dashes: true)),
                    ('Close', _fmtTs(d.closeTime, dashes: true)),
                    ('Swap', formatMoney(d.swap)),
                    ('Commission', formatMoney(d.commission)),
                    (
                      'ID',
                      d.ticket == null || d.ticket!.isEmpty
                          ? '—'
                          : '#${d.ticket}'
                    ),
                    ('Duration', _duration(d.openTime, d.closeTime)),
                  ]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String _duration(DateTime? a, DateTime? b) {
    if (a == null || b == null) return '—';
    final d = b.difference(a);
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    if (days > 0) return '${days}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// Two-column detail: grey label + dark value (Tenax SS).
  Widget _histDetailGrid(List<(String, String)> cells) {
    final labelStyle = TextStyle(
      fontSize: 10.5,
      color: OcColors.textSecondary,
      height: 1.3,
      fontWeight: FontWeight.w400,
    );
    final valueStyle = TextStyle(
      fontSize: 10.5,
      color: OcColors.text,
      height: 1.3,
      fontWeight: FontWeight.w600,
    );
    Widget cell(String label, String value) => Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$label: ', style: labelStyle),
              TextSpan(text: value, style: valueStyle),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    return Column(
      children: [
        for (var i = 0; i < cells.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < cells.length ? 5 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cell(cells[i].$1, cells[i].$2)),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < cells.length
                      ? cell(cells[i + 1].$1, cells[i + 1].$2)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/* ---------------- sheets ---------------- */

class _FilterHistorySheet extends StatelessWidget {
  const _FilterHistorySheet({required this.selected});
  final _HistPeriod selected;

  @override
  Widget build(BuildContext context) {
    var current = selected;
    return StatefulBuilder(
      builder: (context, setLocal) {
        Widget chip(_HistPeriod p) {
          final on = current == p;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: on ? OcColors.primary : OcColors.surface,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setLocal(() => current = p),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: on ? OcColors.primary : OcColors.borderStrong,
                      ),
                    ),
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: on ? Colors.white : OcColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OcColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filter History',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(OcIcons.x, color: OcColors.text),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    chip(_HistPeriod.today),
                    chip(_HistPeriod.week),
                    chip(_HistPeriod.month),
                    chip(_HistPeriod.custom),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(context, _HistPeriod.today),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OcColors.text,
                          side: BorderSide(color: OcColors.borderStrong),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Reset All',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, current),
                        style: FilledButton.styleFrom(
                          backgroundColor: OcColors.primary,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply Filter',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DirectionSheet extends StatelessWidget {
  const _DirectionSheet({required this.selected});
  final _Direction selected;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, _Direction d) {
      final on = selected == d;
      return InkWell(
        onTap: () => Navigator.pop(context, d),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                on ? OcIcons.radioChecked : OcIcons.radioUnchecked,
                size: 22,
                color: on ? OcColors.primary : OcColors.borderStrong,
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: OcColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Direction',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          row('All', _Direction.all),
          row('Buy', _Direction.buy),
          row('Sell', _Direction.sell),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PendingDetailSheet extends StatelessWidget {
  const _PendingDetailSheet({
    required this.order,
    required this.onCancel,
    required this.onModify,
    required this.onNewOrder,
    required this.onChart,
  });

  final PendingOrder order;
  final VoidCallback onCancel;
  final VoidCallback onModify;
  final VoidCallback onNewOrder;
  final VoidCallback onChart;

  @override
  Widget build(BuildContext context) {
    final q = tradingService.quoteFor(order.symbol);
    final cur = order.currentPrice ??
        (q != null && q.hasPrice ? (order.isBuy ? q.ask : q.bid) : 0);
    final id = order.ticket?.toString() ?? order.orderId;
    final sideColor = order.isBuy ? OcColors.ask : OcColors.bid;
    final meta = const TextStyle(
      color: Color(0xFF8A8A93),
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFD0D0D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SymbolFlagTile(symbol: order.symbol, size: 36),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.symbol,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: OcColors.text,
                              height: 1.15,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Pending',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Color(0xFF8A8A93),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Buy left — Order|Current right (scale if needed).
                      Row(
                        children: [
                          Icon(
                            order.isBuy
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            size: 16,
                            color: sideColor,
                          ),
                          Text(
                            '${order.isBuy ? 'Buy' : 'Sell'} ${order.volume.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF8A8A93),
                              fontWeight: FontWeight.w500,
                              fontSize: 11.5,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Order: ${_fmtPrice(order.price, symbol: order.symbol)} | Current: ${_fmtPrice(cur, symbol: order.symbol)}',
                                maxLines: 1,
                                softWrap: false,
                                style: meta,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Meta rows share the same left edge as symbol/Buy (after flag).
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'SL: ${order.stopLoss == null || order.stopLoss! <= 0 ? '-' : _fmtPrice(order.stopLoss!, symbol: order.symbol)}  TP: ${order.takeProfit == null || order.takeProfit! <= 0 ? '-' : _fmtPrice(order.takeProfit!, symbol: order.symbol)}',
                                  style: meta,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Open: ${_fmtTs(order.createdAt, dashes: true)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: meta,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('ID: $id', style: meta),
                              const SizedBox(height: 1),
                              Text('Swap: 0.00', style: meta),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Divider(height: 1, thickness: 0.7, color: Color(0xFFE6E6EA)),
            _action('Cancel Order', onCancel),
            _action('Modify Order', onModify),
            _action('New Order', onNewOrder),
            _action('Chart', onChart),
            SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
            color: OcColors.text,
          ),
        ),
      ),
    );
  }
}

class _PositionDetailSheet extends StatelessWidget {
  const _PositionDetailSheet({
    required this.position,
    required this.onClose,
    required this.onModify,
    required this.onNewOrder,
    required this.onChart,
  });

  final LivePosition position;
  final VoidCallback onClose;
  final VoidCallback onModify;
  final VoidCallback onNewOrder;
  final VoidCallback onChart;

  @override
  Widget build(BuildContext context) {
    final p = position;
    final q = tradingService.quoteFor(p.symbol);
    final cur = q?.hasPrice == true
        ? (p.isBuy ? q!.bid : q!.ask)
        : p.currentPrice;
    final sideColor = p.isBuy ? OcColors.ask : OcColors.bid;
    final id = p.ticket?.toString() ?? p.positionId;
    final sl = p.stopLoss == null || p.stopLoss! <= 0
        ? '-'
        : _fmtPrice(p.stopLoss!, symbol: p.symbol);
    final tp = p.takeProfit == null || p.takeProfit! <= 0
        ? '-'
        : _fmtPrice(p.takeProfit!, symbol: p.symbol);
    const meta = TextStyle(
      color: Color(0xFF8A8A93),
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFD0D0D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SymbolFlagTile(symbol: p.symbol, size: 36),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.symbol,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: OcColors.text,
                              height: 1.15,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '\$${formatMoney(p.floatingPnL)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: p.floatingPnL >= 0
                                  ? OcColors.profit
                                  : OcColors.loss,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            p.isBuy
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            size: 16,
                            color: sideColor,
                          ),
                          Text(
                            '${p.isBuy ? 'Buy' : 'Sell'} ${p.volume.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF8A8A93),
                              fontWeight: FontWeight.w500,
                              fontSize: 11.5,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_fmtPrice(p.openPrice, symbol: p.symbol)} → ${_fmtPrice(cur, symbol: p.symbol)}',
                                maxLines: 1,
                                softWrap: false,
                                style: meta,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('SL: $sl  TP: $tp', style: meta),
                                const SizedBox(height: 1),
                                Text(
                                  'Open: ${_fmtTs(p.openTime, dashes: true)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: meta,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('ID: $id', style: meta),
                              const SizedBox(height: 1),
                              Text(
                                'Swap: ${formatMoney(p.swap)}',
                                style: meta,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Divider(height: 1, thickness: 0.7, color: Color(0xFFE6E6EA)),
            _tile('Close Position', onClose),
            _tile('Modify Position', onModify),
            _tile('New Order', onNewOrder),
            _tile('Chart', onChart),
            SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
            color: OcColors.text,
          ),
        ),
      ),
    );
  }
}

enum _CloseAllFilter { all, profitable, losing, long, short }

class _CloseAllSheet extends StatefulWidget {
  const _CloseAllSheet({required this.positions});
  final List<LivePosition> positions;

  @override
  State<_CloseAllSheet> createState() => _CloseAllSheetState();
}

class _CloseAllSheetState extends State<_CloseAllSheet> {
  _CloseAllFilter _filter = _CloseAllFilter.all;

  List<LivePosition> _for(_CloseAllFilter f) {
    final list = widget.positions;
    return switch (f) {
      _CloseAllFilter.all => list,
      _CloseAllFilter.profitable =>
        list.where((p) => p.floatingPnL > 0).toList(),
      _CloseAllFilter.losing => list.where((p) => p.floatingPnL < 0).toList(),
      _CloseAllFilter.long => list.where((p) => p.isBuy).toList(),
      _CloseAllFilter.short => list.where((p) => !p.isBuy).toList(),
    };
  }

  double _sum(List<LivePosition> list) =>
      list.fold<double>(0, (s, p) => s + p.floatingPnL);

  String _moneyLabel(List<LivePosition> list) {
    if (list.isEmpty) return '—';
    return '\$${formatMoney(_sum(list))}';
  }

  Color _moneyColor(List<LivePosition> list) {
    if (list.isEmpty) return OcColors.textMuted;
    final v = _sum(list);
    if (v > 0) return OcColors.profit;
    if (v < 0) return OcColors.loss;
    return OcColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _for(_filter);
    final selectedPnl = _sum(selected);
    final confirmLabel = selected.isEmpty
        ? 'Confirm'
        : selectedPnl >= 0
            ? 'Confirm (+\$${formatMoney(selectedPnl)})'
            : 'Confirm (\$${formatMoney(selectedPnl)})';
    final confirmBg =
        selectedPnl >= 0 ? OcColors.profit : OcColors.loss;

    Widget row(_CloseAllFilter f, String label) {
      final list = _for(f);
      final on = _filter == f;
      return InkWell(
        onTap: () => setState(() => _filter = f),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: OcColors.text,
                  ),
                ),
              ),
              Text(
                _moneyLabel(list),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: _moneyColor(list),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                on ? OcIcons.radioChecked : OcIcons.radioUnchecked,
                size: 22,
                color: on ? OcColors.primary : OcColors.borderStrong,
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 8, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFFD0D0D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Which positions would you like to close at market prices?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.3,
                  color: OcColors.text,
                ),
              ),
            ),
            row(_CloseAllFilter.all, 'All currently open'),
            row(_CloseAllFilter.profitable, 'All profitable'),
            row(_CloseAllFilter.losing, 'All losing'),
            row(_CloseAllFilter.long, 'All Long'),
            row(_CloseAllFilter.short, 'All Short'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OcColors.primary,
                          side: BorderSide(
                            color: OcColors.primary,
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(
                                  context,
                                  [
                                    for (final p in selected) p.positionId,
                                  ],
                                ),
                        style: FilledButton.styleFrom(
                          backgroundColor: confirmBg,
                          disabledBackgroundColor:
                              confirmBg.withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
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
}

class _TradeAccountTile extends StatelessWidget {
  const _TradeAccountTile({
    required this.account,
    required this.active,
    required this.onTap,
  });

  final LinkedTradingAccount account;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bal = account.equity > 0 ? account.equity : account.balance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: OcColors.bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: account.isDemo
                        ? OcColors.primarySoft
                        : OcColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    OcIcons.wallet,
                    color: account.isDemo ? OcColors.primary : Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            account.planName.trim().isNotEmpty
                                ? account.planName.trim()
                                : (account.isDemo ? 'Demo' : 'Live'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          if (active) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: OcColors.depositBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: OcColors.depositFg,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${account.isDemo ? 'Demo' : 'Live'} · ${account.accountNumber}',
                        style: TextStyle(
                          color: OcColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${formatMoney(bal)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: OcColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  active ? OcIcons.radioChecked : OcIcons.radioUnchecked,
                  color: active ? OcColors.primary : OcColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

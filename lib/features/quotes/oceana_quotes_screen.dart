import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/format.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/quote_price.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import 'oceana_add_symbols_page.dart';
import 'quote_data.dart';
import 'symbol_flags.dart';

class OceanaQuotesScreen extends StatefulWidget {
  const OceanaQuotesScreen({super.key, this.active = true});

  final bool active;

  @override
  State<OceanaQuotesScreen> createState() => _OceanaQuotesScreenState();
}

class _OceanaQuotesScreenState extends State<OceanaQuotesScreen> {
  String _sort = 'Default';
  List<String>? _localOrder;
  bool _switching = false;
  String _listStamp = '';

  String get _sortLabel => switch (_sort) {
        'Symbol A-Z' => 'Symbol A-Z',
        'Symbol Z-A' => 'Symbol Z-A',
        _ => 'By Default',
      };

  @override
  void initState() {
    super.initState();
    _listStamp = _codesStamp();
    tradingService.addListener(_onStructure);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onStructure);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OceanaQuotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _listStamp = _codesStamp();
      setState(() {});
    }
  }

  /// Only rebuild the list shell when symbols / account / sort change —
  /// NOT on every market tick (that was freezing scroll).
  String _codesStamp() =>
      '${tradingService.accountKey}|${tradingService.watchlist.map((w) => w.code).join(',')}|$_sort|${_localOrder?.join(',')}|${tradingService.linkedAccounts.length}';

  void _onStructure() {
    if (!mounted || !widget.active) return;
    final next = _codesStamp();
    if (next == _listStamp) return;
    _listStamp = next;
    setState(() {});
  }

  List<String> _orderedCodes() {
    final codes = tradingService.watchlist.map((w) => w.code).toList();
    if (_sort == 'Symbol A-Z') {
      codes.sort();
      return codes;
    }
    if (_sort == 'Symbol Z-A') {
      codes.sort((a, b) => b.compareTo(a));
      return codes;
    }
    if (_localOrder != null) {
      final set = codes.toSet();
      return [
        for (final c in _localOrder!)
          if (set.contains(c)) c,
        for (final c in codes)
          if (!_localOrder!.contains(c)) c,
      ];
    }
    return codes;
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final codes = _orderedCodes();
    if (newIndex > oldIndex) newIndex -= 1;
    final item = codes.removeAt(oldIndex);
    codes.insert(newIndex, item);
    setState(() {
      _sort = 'Default';
      _localOrder = codes;
      _listStamp = _codesStamp();
    });
    try {
      await tradingService.reorderWatchlist(codes);
    } catch (_) {}
  }

  Future<void> _openAdd() async {
    await OceanaAddSymbolsPage.show(context);
    if (mounted) setState(() => _listStamp = _codesStamp());
  }

  @override
  Widget build(BuildContext context) {
    final codes = _orderedCodes();

    return Scaffold(
      backgroundColor: OcColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LiveHeader(
              active: widget.active,
              onApps: () => ShellScope.of(context).openTab(3),
              onAccount: () => _showAccountSheet(context),
              onAdd: _openAdd,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Watchlist',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: OcColors.text,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Material(
                    color: OcColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => _showSortSheet(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sortLabel,
                              style: TextStyle(
                                color: OcColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              OcIcons.chevronDown,
                              size: 18,
                              color: OcColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: codes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No symbols in watchlist',
                            style: TextStyle(
                              color: OcColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _openAdd,
                            icon: const Icon(OcIcons.plus),
                            label: const Text('Add instruments'),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                      buildDefaultDragHandles: false,
                      // Keep a few off-screen rows warm for smoother flings.
                      cacheExtent: 480,
                      physics: const ClampingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: codes.length,
                      onReorder: _onReorder,
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 1,
                          color: OcColors.surface,
                          child: child,
                        );
                      },
                      itemBuilder: (context, i) {
                        final code = codes[i];
                        return _LiveQuoteRow(
                          key: ValueKey(code),
                          index: i,
                          symbol: code,
                          active: widget.active,
                          onOpen: () =>
                              ShellScope.of(context).openChart(code),
                          onDelete: () =>
                              tradingService.removeWatchlist(code),
                        );
                      },
                    ),
            ),
            if (_switching)
              LinearProgressIndicator(
                minHeight: 2,
                color: OcColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        Widget row({
          required IconData icon,
          required String label,
          required String value,
        }) {
          final on = _sort == value;
          return InkWell(
            onTap: () {
              setState(() {
                _sort = value;
                if (value != 'Default') _localOrder = null;
              });
              Navigator.pop(ctx);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(icon, color: OcColors.textSecondary, size: 22),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OcColors.text,
                      ),
                    ),
                  ),
                  if (on)
                    Icon(
                      OcIcons.checkCircle2,
                      color: OcColors.primary,
                      size: 22,
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
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OcColors.borderStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              row(
                icon: OcIcons.list,
                label: 'Default',
                value: 'Default',
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              row(
                icon: OcIcons.sortAz,
                label: 'Symbol A-Z',
                value: 'Symbol A-Z',
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              row(
                icon: OcIcons.sortAz,
                label: 'Symbol Z-A',
                value: 'Symbol Z-A',
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAccountSheet(BuildContext context) async {
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
            // Only this portal user's linked accounts — never leftover FP cards.
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
                      _AccountTile(
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
                                  e.toString().replaceFirst('Exception: ', ''),
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
}

class _LiveHeader extends StatefulWidget {
  const _LiveHeader({
    required this.active,
    required this.onApps,
    required this.onAccount,
    required this.onAdd,
  });

  final bool active;
  final VoidCallback onApps;
  final VoidCallback onAccount;
  final VoidCallback onAdd;

  @override
  State<_LiveHeader> createState() => _LiveHeaderState();
}

class _LiveHeaderState extends State<_LiveHeader> {
  String _stamp = '';

  @override
  void initState() {
    super.initState();
    _stamp = _readStamp();
    tradingService.addListener(_onTick);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onTick);
    super.dispose();
  }

  String _readStamp() {
    final live = tradingService.account;
    final pnl = tradingService.positions.values.fold<double>(
      0,
      (s, p) => s + p.floatingPnL,
    );
    return '${tradingService.accountKey}|$pnl|${live.equity}|${live.balance}|${tradingService.isActiveAccountDemo}';
  }

  void _onTick() {
    if (!mounted || !widget.active) return;
    final next = _readStamp();
    if (next == _stamp) return;
    _stamp = next;
    setState(() {});
  }

  String _accountNumber() {
    final session = tradingService.session;
    final fromSession = session?.accountNumber.trim() ?? '';
    if (fromSession.isNotEmpty) return fromSession;
    final id = session?.accountId.trim() ?? '';
    if (id.isNotEmpty) {
      for (final a in tradingService.linkedAccounts) {
        if (a.id == id && a.accountNumber.isNotEmpty) return a.accountNumber;
      }
    }
    for (final a in tradingService.linkedAccounts) {
      if (a.isPrimary && a.accountNumber.isNotEmpty) return a.accountNumber;
    }
    if (tradingService.linkedAccounts.isNotEmpty) {
      final n = tradingService.linkedAccounts.first.accountNumber;
      if (n.isNotEmpty) return n;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final live = tradingService.account;
    final posPnl = tradingService.positions.values.fold<double>(
      0,
      (s, p) => s + p.floatingPnL,
    );
    final pnl = tradingService.positions.isNotEmpty
        ? posPnl
        : (live.equity > 0 ? live.equity - live.balance : 0.0);
    final isDemo = tradingService.isActiveAccountDemo;
    final accountNumber = _accountNumber();
    final pnlText = pnl >= 0
        ? '\$${formatMoney(pnl)}'
        : '-\$${formatMoney(pnl.abs())}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 2),
            child: IconButton(
              onPressed: widget.onApps,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              icon: _FourDotsIcon(size: 18, color: OcColors.text),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: widget.onAccount,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pnlText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: pnl >= 0 ? OcColors.profit : OcColors.loss,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: OcColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isDemo ? 'DEMO' : 'LIVE',
                            style: TextStyle(
                              color: OcColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            accountNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: OcColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        Icon(
                          OcIcons.chevronDown,
                          size: 18,
                          color: OcColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: OcColors.primarySoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onAdd,
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(OcIcons.plus, color: OcColors.primary, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveQuoteRow extends StatefulWidget {
  const _LiveQuoteRow({
    super.key,
    required this.index,
    required this.symbol,
    required this.active,
    required this.onOpen,
    required this.onDelete,
  });

  final int index;
  final String symbol;
  final bool active;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_LiveQuoteRow> createState() => _LiveQuoteRowState();
}

class _LiveQuoteRowState extends State<_LiveQuoteRow> {
  String _stamp = '';
  Quote? _quote;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _quote = displayQuoteFor(widget.symbol);
    _stamp = _quoteStamp(_quote);
    tradingService.addListener(_onTick);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onTick);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _LiveQuoteRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      _quote = displayQuoteFor(widget.symbol);
      _stamp = _quoteStamp(_quote);
    }
  }

  String _quoteStamp(Quote? q) {
    if (q == null) return '';
    return '${q.bidHead}${q.bidTail}|${q.askHead}${q.askTail}|${q.time}|${q.spread}|${q.low}|${q.high}|${q.inactive}';
  }

  void _onTick() {
    if (!mounted || !widget.active) return;
    // Coalesce multiple notifies into one frame — keeps scroll butter-smooth.
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !widget.active) return;
      final q = displayQuoteFor(widget.symbol);
      final next = _quoteStamp(q);
      if (next == _stamp) return;
      _stamp = next;
      setState(() => _quote = q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    final inactive = q?.inactive == true;
    final bidColor = inactive ? OcColors.textMuted : OcColors.bid;
    final askColor = inactive ? OcColors.textMuted : OcColors.ask;
    final time = q?.time ?? '--:--:--';
    final spread = q?.spread ?? '0';
    final low = q?.low ?? '0';
    final high = q?.high ?? '0';
    final bidHead = q?.bidHead ?? '0';
    final bidTail = q?.bidTail ?? '';
    final askHead = q?.askHead ?? '0';
    final askTail = q?.askTail ?? '';

    return Dismissible(
      key: ValueKey('dismiss_${widget.symbol}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: OcColors.danger,
        padding: EdgeInsets.only(right: 22),
        child: Icon(OcIcons.trash2, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: Material(
        color: OcColors.surface,
        child: InkWell(
          onTap: widget.onOpen,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: OcColors.border.withValues(alpha: 0.55),
                  width: 0.7,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(6, 10, 12, 10),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      OcIcons.gripVertical,
                      size: 20,
                      color: OcColors.textMuted,
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OcColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SymbolFlagPair(symbol: widget.symbol, size: 34),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.symbol,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: OcColors.text,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: OcColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Image.asset(
                            'assets/icons/quote_mark.png',
                            width: 9,
                            height: 8,
                            fit: BoxFit.contain,
                            color: OcColors.textMuted,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                          SizedBox(width: 3),
                          Text(
                            spread,
                            style: TextStyle(
                              fontSize: 10,
                              color: OcColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    QuotePrice(
                      head: bidHead,
                      tail: bidTail,
                      color: bidColor,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'L: $low',
                      style: TextStyle(
                        fontSize: 9,
                        color: OcColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    QuotePrice(
                      head: askHead,
                      tail: askTail,
                      color: askColor,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'H: $high',
                      style: TextStyle(
                        fontSize: 9,
                        color: OcColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 2×2 circular dots (not square tiles, no circle background).
class _FourDotsIcon extends StatelessWidget {
  const _FourDotsIcon({this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? OcColors.text;
    final dot = size * 0.28;
    final gap = size * 0.16;
    Widget circle() => Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [circle(), SizedBox(width: gap), circle()],
          ),
          SizedBox(height: gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [circle(), SizedBox(width: gap), circle()],
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
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
                SizedBox(width: 12),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          if (active) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
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
                      SizedBox(height: 2),
                      Text(
                        '${account.isDemo ? 'Demo' : 'Live'} · ${account.accountNumber}',
                        style: TextStyle(
                          color: OcColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                      SizedBox(height: 2),
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

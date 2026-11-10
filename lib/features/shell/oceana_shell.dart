import 'package:flutter/material.dart';

import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_bottom_nav.dart';
import '../auth/login_page.dart';
import '../charts/oceana_charts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../more/more_screen.dart';
import '../quotes/oceana_quotes_screen.dart';
import '../trade/oceana_trade_screen.dart';

/// New client shell — Quote / Chart / Trade / Dashboard / More.
class OceanaShell extends StatefulWidget {
  const OceanaShell({super.key});

  @override
  State<OceanaShell> createState() => _OceanaShellState();
}

class _OceanaShellState extends State<OceanaShell> {
  final _shell = ShellController();
  final _built = <int>{};
  bool _welcomeShown = false;
  bool _hadAccount = false;
  bool _welcomeCheckRunning = false;
  String _authStamp = '';

  static const _tabs = OcNavTab.values;

  OcNavTab get _current => _tabs[_shell.tab.clamp(0, _tabs.length - 1)];

  String _stamp() =>
      '${tradingService.accountKey}|${tradingService.hasUserPortal}|'
      '${tradingService.isLoggedIn}|${tradingService.mqLoggedIn}';

  @override
  void initState() {
    super.initState();
    _authStamp = _stamp();
    _hadAccount = tradingService.hasAnyAccount;
    _shell.addListener(_onShell);
    tradingService.addListener(_onTrade);
    _built.add(_shell.tab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());
  }

  @override
  void dispose() {
    _shell.removeListener(_onShell);
    tradingService.removeListener(_onTrade);
    _shell.dispose();
    super.dispose();
  }

  void _onShell() {
    _built.add(_shell.tab);
    setState(() {});
  }

  void _onTrade() {
    // Do NOT rebuild the whole shell on every price tick.
    final next = _stamp();
    final has = tradingService.hasAnyAccount;
    if (_hadAccount && !has) {
      // Explicit logout → show Login again.
      _welcomeShown = false;
    }
    _hadAccount = has;
    if (next != _authStamp) {
      _authStamp = next;
      if (mounted) setState(() {});
    }
    _maybeWelcome();
  }

  Future<void> _maybeWelcome() async {
    if (_welcomeCheckRunning) return;
    _welcomeCheckRunning = true;
    try {
      await tradingService.whenLocalRestored;
      if (!mounted) return;

      if (tradingService.isLoggedIn || tradingService.mqLoggedIn) {
        _welcomeShown = false;
        _hadAccount = true;
        return;
      }

      // Portal JWT still around (cold start) — try activate once; if it
      // fails or user logged out, fall through to Login.
      if (tradingService.hasUserPortal && !tradingService.loggedOutByUser) {
        if (_welcomeShown) return;
        _welcomeShown = true;
        try {
          await tradingService.activatePrimaryAccount();
        } catch (_) {}
        if (tradingService.isLoggedIn || tradingService.mqLoggedIn) {
          _hadAccount = true;
          if (mounted) setState(() {});
          return;
        }
        // Activate failed — clear flag so Login can show below.
        _welcomeShown = false;
      }

      if (_welcomeShown) return;
      _welcomeShown = true;
      // Oceana white-label: skip Find Broker / Welcome — open Login directly.
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PopScope(
            canPop: false,
            child: LoginPage(
              onAuthenticated: () {
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
      );
      // After auth gate closes, allow re-open only if still logged out.
      if (!tradingService.hasAnyAccount) {
        _welcomeShown = false;
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());
        }
      }
    } finally {
      _welcomeCheckRunning = false;
    }
  }

  Widget _pageFor(int index) {
    final active = _shell.tab == index;
    // TickerMode stops animations on hidden tabs; RepaintBoundary isolates paint.
    return TickerMode(
      enabled: active,
      child: RepaintBoundary(
        child: switch (index) {
          0 => OceanaQuotesScreen(active: active),
          1 => OceanaChartsScreen(
              key: ValueKey(_shell.chartSymbol),
              symbol: _shell.chartSymbol,
              active: active,
            ),
          2 => OceanaTradeScreen(active: active),
          3 => DashboardScreen(active: active),
          4 => MoreScreen(active: active),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      controller: _shell,
      child: Scaffold(
        backgroundColor: OcColors.bg,
        extendBody: true,
        body: Padding(
          // Floating pill overlays body — keep page content above it.
          padding: EdgeInsets.only(bottom: OcBottomNav.bodyClearance(context)),
          // IndexedStack = instant tab switch (no heavy PageView slide of
          // WebView/lists). State of each tab is preserved.
          child: IndexedStack(
            index: _shell.tab,
            sizing: StackFit.expand,
            children: [
              for (var i = 0; i < _tabs.length; i++)
                _built.contains(i) ? _pageFor(i) : const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: OcBottomNav(
          current: _current,
          onSelect: (tab) => _shell.openTab(tab.index),
        ),
      ),
    );
  }
}

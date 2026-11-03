import 'package:flutter/material.dart';

import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_bottom_nav.dart';
import '../auth/welcome_page.dart';
import '../brokers/broker_search_page.dart';
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
    if (next != _authStamp) {
      _authStamp = next;
      if (mounted) setState(() {});
    }
    _maybeWelcome();
  }

  void _maybeWelcome() {
    if (tradingService.isLoggedIn || tradingService.mqLoggedIn) {
      _welcomeShown = false;
      return;
    }
    if (_welcomeShown) return;

    if (tradingService.hasUserPortal) {
      _welcomeShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          if (!tradingService.isLoggedIn) {
            await tradingService.activatePrimaryAccount();
          }
        } catch (_) {
          // Portal session without a tradable account — stay on shell.
        }
        if (mounted) setState(() {});
      });
      return;
    }

    _welcomeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const BrokerSearchPage(),
        ),
      );
      if (!mounted) return;
      if (!tradingService.isLoggedIn && !tradingService.hasUserPortal) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WelcomePage(
              onAuthenticated: () {
                if (mounted) setState(() {});
              },
            ),
          ),
        );
      }
    });
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

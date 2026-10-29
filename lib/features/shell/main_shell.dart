import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_bottom_nav.dart';
import '../charts/charts_screen.dart';
import '../history/history_screen.dart';
import '../messages/messages_screen.dart';
import '../news/news_screen.dart';
import '../quotes/quotes_screen.dart';
import '../trade/trade_screen.dart';
import 'app_drawer.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _controller = ShellController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _lastLoggedIn = tradingService.hasAnyAccount;
  String _lastAccountKey = tradingService.accountKey;

  /// Sirf visit kiye tabs build — WebView/charts startup pe nahi.
  final Set<int> _builtTabs = {0};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    tradingService.addListener(_onService);
  }

  void _rebuild() {
    _builtTabs.add(_controller.tab);
    if (mounted) setState(() {});
  }

  /// Live ticks har second kai baar aate hain - shell ko un pe rebuild
  /// nahi karna, sirf login/logout / account-switch pe refresh.
  /// Har screen apna live data khud sunti hai.
  void _onService() {
    final now = tradingService.hasAnyAccount;
    final key = tradingService.accountKey;
    final accountChanged = key != _lastAccountKey;
    if (now != _lastLoggedIn || accountChanged) {
      _lastLoggedIn = now;
      if (accountChanged) {
        _lastAccountKey = key;
        final wl = tradingService.watchlist;
        if (wl.isNotEmpty) {
          _controller.chartSymbol = wl.first.code;
        }
      }
      _rebuild();
    }
  }

  @override
  void dispose() {
    tradingService.removeListener(_onService);
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  Widget _tab(int i) {
    switch (i) {
      case 0:
        return QuotesScreen(onMenu: _openDrawer);
      case 1:
        return ChartsScreen(
          onMenu: _openDrawer,
          symbol: _controller.chartSymbol,
        );
      case 2:
        return TradeScreen(onMenu: _openDrawer);
      case 3:
        return HistoryScreen(onMenu: _openDrawer);
      case 4:
        return MessagesScreen(onMenu: _openDrawer);
      case 5:
        return NewsScreen(onMenu: _openDrawer);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      controller: _controller,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: MtColors.white,
        drawer: const AppDrawer(),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _controller.tab,
            children: [
              for (var i = 0; i < 6; i++)
                _builtTabs.contains(i) ? _tab(i) : const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: MtBottomNav(
          index: _controller.tab,
          onChanged: _controller.openTab,
        ),
      ),
    );
  }
}

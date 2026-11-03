import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/trading_service.dart';

/// Rebuilds only while [active] — prevents IndexedStack off-tabs from
/// rebuilding on every market tick (major hang fix).
///
/// Multiple notifies in one frame are coalesced into a single setState.
class OcSvcScope extends StatefulWidget {
  const OcSvcScope({
    super.key,
    required this.active,
    required this.builder,
    this.sessionOnly = false,
  });

  final bool active;
  final bool sessionOnly;
  final Widget Function(BuildContext context) builder;

  @override
  State<OcSvcScope> createState() => _OcSvcScopeState();
}

class _OcSvcScopeState extends State<OcSvcScope> {
  String _sessionStamp = '';
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _sessionStamp = _stamp();
    tradingService.addListener(_onSvc);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onSvc);
    super.dispose();
  }

  String _stamp() =>
      '${tradingService.accountKey}|${tradingService.hasUserPortal}|'
      '${tradingService.fpAccounts.length}|${tradingService.account.balance}|'
      '${tradingService.linkedAccounts.length}|${tradingService.positions.length}|'
      '${tradingService.pendings.length}';

  void _onSvc() {
    if (!mounted || !widget.active) return;
    if (widget.sessionOnly) {
      final next = _stamp();
      if (next == _sessionStamp) return;
      _sessionStamp = next;
    }
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !widget.active) return;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant OcSvcScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _sessionStamp = _stamp();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

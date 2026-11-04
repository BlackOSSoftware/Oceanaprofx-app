import 'package:flutter/material.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

/// Choose account type carousel — loads broker plans, SS layout, Oceana brand.
class OceanaChooseAccountPage extends StatefulWidget {
  const OceanaChooseAccountPage({super.key, this.isDemo = false});

  final bool isDemo;

  static Future<void> open(BuildContext context, {bool isDemo = false}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OceanaChooseAccountPage(isDemo: isDemo),
      ),
    );
  }

  @override
  State<OceanaChooseAccountPage> createState() =>
      _OceanaChooseAccountPageState();
}

class _OceanaChooseAccountPageState extends State<OceanaChooseAccountPage> {
  final _page = PageController(viewportFraction: 0.9);
  int _index = 0;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<_Plan> _plans = const [];
  final _demoBalance = TextEditingController(text: '25000');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _page.dispose();
    _demoBalance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await tradingService.fetchAccountPlans();
      final filtered = <_Plan>[
        for (final m in raw)
          if (_matchesType(m)) _Plan.fromJson(m),
      ];
      if (!mounted) return;
      setState(() {
        _plans = filtered;
        _loading = false;
        _index = 0;
        if (filtered.isEmpty && !tradingService.hasUserPortal) {
          _error =
              'Sign in with email to load ${widget.isDemo ? 'demo' : 'live'} plans';
        } else if (filtered.isEmpty) {
          _error = widget.isDemo
              ? 'No demo plans for this broker yet'
              : 'No live plans for this broker yet';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = const [];
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  bool _matchesType(Map<String, dynamic> m) {
    final demo = m['is_demo_allowed'] == true;
    return widget.isDemo ? demo : !demo;
  }

  Future<void> _open(_Plan plan) async {
    if (_busy) return;
    if (plan.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid plan — pull to refresh')),
      );
      return;
    }

    if (widget.isDemo) {
      final ok = await _showDemoBalanceDialog();
      if (ok != true || !mounted) return;
      final amount = double.tryParse(_demoBalance.text.trim());
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid demo opening balance.'),
          ),
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final created = await tradingService.createPortalAccount(
        accountPlanId: plan.id,
        accountType: widget.isDemo ? 'demo' : 'live',
        openingBalance: widget.isDemo
            ? double.tryParse(_demoBalance.text.trim())
            : null,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _showCreatedDialog(created, plan);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<bool?> _showDemoBalanceDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demo Opening Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the opening balance for your demo account.',
              style: TextStyle(color: OcColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _demoBalance,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Enter demo amount',
                suffixText: 'USD',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: OcColors.primary),
            child: const Text('Confirm & Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatedDialog(
    Map<String, dynamic> created,
    _Plan plan,
  ) async {
    String v(String k, [String fallback = '—']) {
      final t = '${created[k] ?? ''}'.trim();
      return t.isEmpty ? fallback : t;
    }

    final levRaw = created['leverage'];
    final lev = levRaw is num
        ? (levRaw == 0 ? 'Unlimited' : '1:${levRaw.toInt()}')
        : v('leverage');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(OcIcons.checkCircle2, color: OcColors.depositFg),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Account Created',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cred('Account Number', v('account_number')),
              _cred(
                'Account Type',
                v('account_type', widget.isDemo ? 'demo' : 'live'),
              ),
              _cred('Plan Name', v('plan_name', plan.name)),
              _cred('Leverage', lev),
              _cred('Trade Password', v('trade_password')),
              _cred('Watch Password', v('watch_password')),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Please save these credentials. They will not be shown again.',
                  style: TextStyle(
                    color: OcColors.loss,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: OcColors.primary),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  Widget _cred(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OcColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OcColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: OcColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
        ],
      ),
    );
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
          onPressed: () => Navigator.pop(context),
          icon: Icon(OcIcons.arrowBack, color: OcColors.text),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Text(
              'Choose your account',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: OcColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                "Choose an account type you'd like to start trading with",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OcColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: OcColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _plans.isEmpty
                      ? Center(
                          child: Text(
                            widget.isDemo
                                ? 'No demo plans available'
                                : 'No live plans available',
                            style: TextStyle(
                              color: OcColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : PageView.builder(
                          controller: _page,
                          itemCount: _plans.length,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemBuilder: (context, i) {
                            return Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(6, 4, 6, 8),
                                child: _PlanCard(
                                  plan: _plans[i],
                                  selected: i == _index,
                                  busy: _busy && i == _index,
                                  onOpen: () => _open(_plans[i]),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (!_loading && _plans.length > 1) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _plans.length; i++)
                    Container(
                      width: i == _index ? 16 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _index
                            ? OcColors.primary
                            : OcColors.borderStrong,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Plan {
  const _Plan({
    required this.id,
    required this.name,
    required this.spread,
    required this.instruments,
    required this.minDeposit,
    required this.leverage,
    required this.marginCall,
    required this.stopOut,
  });

  final String id;
  final String name;
  final String spread;
  final String instruments;
  final String minDeposit;
  final String leverage;
  final String marginCall;
  final String stopOut;

  factory _Plan.fromJson(Map<String, dynamic> j) {
    final lev = j['max_leverage'] ?? j['maxLeverage'] ?? j['leverage'];
    final levText = (lev is num && lev > 0) ? '1:${lev.toInt()}' : 'Unlimited';
    final spread = j['spreadPips'] ?? j['spread_pips'];
    final minDep = j['minDeposit'] ?? j['min_deposit'];
    final guidance = '${j['guidance'] ?? ''}'.trim();
    final rawId = j['_id'] ?? j['id'] ?? '';
    final id = rawId is Map
        ? '${rawId['\$oid'] ?? rawId['oid'] ?? rawId['_id'] ?? ''}'
        : '$rawId';
    return _Plan(
      id: id.trim(),
      name: '${j['name'] ?? 'Plan'}',
      spread: spread is num ? '$spread' : '—',
      instruments: guidance.isNotEmpty
          ? guidance
          : '+300 Instruments. Forex, Metals, Indices…',
      minDeposit: minDep is num ? minDep.toStringAsFixed(2) : '0.00',
      leverage: levText,
      marginCall: '${j['marginCall'] ?? j['margin_call'] ?? '—'}',
      stopOut: '${j['stopOut'] ?? j['stop_out'] ?? '30'}',
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onOpen,
    this.busy = false,
  });

  final _Plan plan;
  final bool selected;
  final VoidCallback onOpen;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Spread from', plan.spread),
      ('Instruments', plan.instruments),
      ('Min deposit', plan.minDeposit),
      ('Maximum leverage', plan.leverage),
      ('Margin call', plan.marginCall),
      ('Stop Out level', plan.stopOut),
    ];

    return Material(
      color: OcColors.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? OcColors.primary : OcColors.borderStrong,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              plan.name,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: OcColors.text,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: _DashLine(),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      rows[i].$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: OcColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: i == 1
                            ? OcColors.textSecondary
                            : OcColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: busy ? null : onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: OcColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      OcColors.primary.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  busy ? 'Creating…' : 'Open Account',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashLine extends StatelessWidget {
  const _DashLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const dash = 4.0;
        const gap = 3.0;
        final n = (c.maxWidth / (dash + gap)).floor().clamp(1, 200);
        return Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              Container(
                width: dash,
                height: 1,
                color: OcColors.borderStrong,
              ),
              if (i < n - 1) const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

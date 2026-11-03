import 'package:flutter/material.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

/// Open Account — Trade-Portal flow: Live/Demo → plan → confirm → credentials.
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
  late bool _isDemo;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<_Plan> _plans = const [];
  _Plan? _selected;
  final _demoBalance = TextEditingController(text: '25000');

  @override
  void initState() {
    super.initState();
    _isDemo = widget.isDemo;
    _load();
  }

  @override
  void dispose() {
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
        _selected = filtered.length == 1 ? filtered.first : null;
        if (filtered.isEmpty && !tradingService.hasUserPortal) {
          _error =
              'Sign in with email to load ${_isDemo ? 'demo' : 'live'} plans';
        } else if (filtered.isEmpty) {
          _error = _isDemo
              ? 'No plans available for demo account.'
              : 'No plans available for live account.';
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
    return _isDemo ? demo : !demo;
  }

  Future<void> _continue() async {
    final plan = _selected;
    if (plan == null) {
      setState(() => _error = 'Please select an account plan.');
      return;
    }
    if (plan.id.isEmpty) {
      setState(() => _error = 'Invalid plan — pull to refresh.');
      return;
    }
    setState(() => _error = null);

    if (_isDemo) {
      final ok = await _showDemoBalanceDialog();
      if (ok != true || !mounted) return;
      final amount = double.tryParse(_demoBalance.text.trim());
      if (amount == null || amount <= 0) {
        setState(() => _error = 'Please enter a valid demo opening balance.');
        return;
      }
      await _create();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create trading account?'),
        content: Text(
          'You are about to create a live ${plan.name} account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: OcColors.primary),
            child: Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _create();
  }

  Future<bool?> _showDemoBalanceDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Demo Opening Balance'),
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

  Future<void> _create() async {
    final plan = _selected;
    if (plan == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await tradingService.createPortalAccount(
        accountPlanId: plan.id,
        accountType: _isDemo ? 'demo' : 'live',
        openingBalance:
            _isDemo ? double.tryParse(_demoBalance.text.trim()) : null,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _showCreatedDialog(created, plan);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = '$e'.replaceFirst('Exception: ', '');
      setState(() {
        _busy = false;
        _error = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
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
            SizedBox(width: 8),
            Expanded(
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
                v('account_type', _isDemo ? 'demo' : 'live'),
              ),
              _cred('Plan Name', v('plan_name', plan.name)),
              _cred('Currency', v('currency', plan.currency)),
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
            child: Text('Okay'),
          ),
        ],
      ),
    );
  }

  Widget _cred(String label, String value) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
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
    final step = _selected == null ? 2 : 3;
    return Scaffold(
      backgroundColor: OcColors.bg,
      appBar: AppBar(
        backgroundColor: OcColors.bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(OcIcons.arrowBack, color: OcColors.text),
        ),
        title: const Text(
          'Open Account',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OcColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(OcIcons.wallet, color: OcColors.primary, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Open Account',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Select account type, choose your plan, and continue to create a new trading account.',
                              style: TextStyle(
                                color: OcColors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                _steps(step),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: OcColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP 1: CHOOSE ACCOUNT TYPE',
                        style: TextStyle(
                          color: OcColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _typeBtn(
                              label: 'Live Account',
                              selected: !_isDemo,
                              onTap: () {
                                if (!_isDemo) return;
                                setState(() {
                                  _isDemo = false;
                                  _selected = null;
                                });
                                _load();
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _typeBtn(
                              label: 'Demo Account',
                              selected: _isDemo,
                              onTap: () {
                                if (_isDemo) return;
                                setState(() {
                                  _isDemo = true;
                                  _selected = null;
                                });
                                _load();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'STEP 2: SELECT YOUR PLAN',
                  style: TextStyle(
                    color: OcColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_plans.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: OcColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: OcColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Text(
                      _error ?? 'No plans available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: OcColors.textSecondary),
                    ),
                  )
                else
                  for (final p in _plans) ...[
                    _PlanCard(
                      plan: p,
                      selected: _selected?.id == p.id,
                      onSelect: () => setState(() => _selected = p),
                    ),
                    SizedBox(height: 10),
                  ],
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OcColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP 3: REVIEW BEFORE CONTINUE',
                        style: TextStyle(
                          color: OcColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _mini(
                              'Account Type',
                              _isDemo ? 'Demo' : 'Live',
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _mini(
                              'Selected Plan',
                              _selected?.name ?? 'Not selected',
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _mini(
                              'Min Deposit',
                              _selected == null
                                  ? '--'
                                  : '${_selected!.minDeposit} USD',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Continue ke baad confirmation milega, phir account create hoga.',
                        style: TextStyle(
                          color: OcColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null && _plans.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: OcColors.loss,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 72),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: (_selected == null || _busy) ? null : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: OcColors.primary,
                    disabledBackgroundColor:
                        OcColors.primary.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _busy ? 'Creating…' : 'Continue',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _steps(int step) {
    Widget item(int i, String title, String desc, {required bool active}) {
      final done = i < step || (i == 2 && _selected != null) || i == 1;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? OcColors.primarySoft : OcColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? OcColors.primary : OcColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done
                          ? OcColors.depositBg
                          : (active ? OcColors.primary : OcColors.bg),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: done
                            ? OcColors.depositFg
                            : (active ? Colors.white : OcColors.textMuted),
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: OcColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: OcColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        item(1, 'Choose Type', 'Live or demo', active: true),
        const SizedBox(width: 6),
        item(2, 'Select Plan', 'Pick one plan', active: step == 2),
        const SizedBox(width: 6),
        item(3, 'Create', 'Review & confirm', active: step == 3),
      ],
    );
  }

  Widget _typeBtn({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? OcColors.primary : OcColors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : OcColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OcColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: OcColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Plan {
  const _Plan({
    required this.id,
    required this.name,
    required this.minDeposit,
    required this.spread,
    required this.referral,
    required this.leverage,
    required this.commission,
    required this.guidance,
    required this.currency,
  });

  final String id;
  final String name;
  final String minDeposit;
  final String spread;
  final String referral;
  final String leverage;
  final String commission;
  final String guidance;
  final String currency;

  factory _Plan.fromJson(Map<String, dynamic> j) {
    final lev = j['max_leverage'] ?? j['maxLeverage'] ?? j['leverage'];
    final maxLev = (lev is num && lev > 0) ? lev.toInt() : 0;
    final levText = maxLev == 0 ? 'Unlimited' : '1:$maxLev';
    final spread = j['spreadPips'] ?? j['spread_pips'];
    final minDep = j['minDeposit'] ?? j['min_deposit'];
    final referral = j['referral_reward_amount'] ?? j['referralRewardAmount'];
    final commission = j['commission_per_lot'] ?? j['commissionPerLot'];
    final currency = '${j['currency'] ?? 'USD'}'.trim();
    final cVal = commission is num ? commission.toDouble() : 0.0;
    final rawId = j['_id'] ?? j['id'] ?? '';
    final id = rawId is Map
        ? '${rawId['\$oid'] ?? rawId['oid'] ?? rawId['_id'] ?? ''}'
        : '$rawId';
    return _Plan(
      id: id.trim(),
      name: '${j['name'] ?? 'Plan'}',
      minDeposit: minDep is num ? '$minDep' : '0',
      spread: spread is num ? 'From $spread pips' : 'From — pips',
      referral: referral is num ? '\$ $referral' : '\$ 0',
      leverage: levText,
      commission: cVal > 0 ? '$cVal USD / lot' : 'No commission',
      guidance: '${j['guidance'] ?? ''}'.trim(),
      currency: currency.isEmpty ? 'USD' : currency,
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onSelect,
  });

  final _Plan plan;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OcColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? OcColors.primary : OcColors.borderStrong,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  selected ? OcIcons.checkCircle2 : OcIcons.radioUnchecked,
                  color: selected ? OcColors.primary : OcColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            if (plan.guidance.isNotEmpty) ...[
              SizedBox(height: 6),
              Text(
                plan.guidance,
                style: TextStyle(
                  color: OcColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _meta('Min deposit', '${plan.minDeposit} USD'),
                _meta('Spread', plan.spread),
                _meta('Referral', plan.referral),
                _meta('Leverage', plan.leverage),
                _meta('Commission', plan.commission),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OcColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: OcColors.textMuted, fontSize: 10.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

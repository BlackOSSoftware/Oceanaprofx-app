import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_badge.dart';
import '../../ui/widgets/oc_svc_scope.dart';
import '../more/oceana_transaction_history_page.dart';
import 'oceana_change_leverage_page.dart';
import 'oceana_change_password_dialog.dart';
import 'oceana_choose_account_page.dart';
import 'oceana_internal_transfer_page.dart';

/// Dashboard — Tenax SS cards / sheets, Oceana brand `#1414C7`.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.active = true});

  final bool active;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshAccounts();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _refreshAccounts();
    }
  }

  Future<void> _refreshAccounts() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (tradingService.hasUserPortal) {
        await tradingService.refreshLinkedAccounts();
      }
    } catch (_) {
      // Keep last known list.
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  /// Portal linked accounts (live+demo) + local saved logins not already listed.
  List<_DashAccount> _buildRows() {
    final session = tradingService.session;
    final sessionNum = session?.accountNumber.trim() ?? '';
    final liveEquity = tradingService.account.equity > 0
        ? tradingService.account.equity
        : tradingService.account.balance;
    final seen = <String>{};
    final rows = <_DashAccount>[];

    void add(_DashAccount row) {
      final key = row.accountNumber.trim();
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      rows.add(row);
    }

    // Prefer portal accounts so newly opened Live accounts show up.
    final linked = [...tradingService.linkedAccounts]
      ..sort((a, b) {
        if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
        return a.accountNumber.compareTo(b.accountNumber);
      });
    for (final a in linked) {
      final active = sessionNum.isNotEmpty && a.accountNumber.trim() == sessionNum;
      add(
        _DashAccount(
          id: a.id,
          accountNumber: a.accountNumber,
          isDemo: a.isDemo,
          planLabel: a.planName.isNotEmpty
              ? a.planName
              : (a.isDemo ? 'Demo' : 'Standard'),
          equity: active
              ? liveEquity
              : (a.equity > 0 ? a.equity : a.balance),
          isActive: active,
          fromPortal: true,
        ),
      );
    }

    // Active trade session not in linked list.
    if (session != null && sessionNum.isNotEmpty && !seen.contains(sessionNum)) {
      add(
        _DashAccount(
          id: '',
          accountNumber: sessionNum,
          isDemo: tradingService.isActiveAccountDemo,
          planLabel: tradingService.isActiveAccountDemo ? 'Demo' : 'Standard',
          equity: liveEquity,
          isActive: true,
          fromPortal: false,
        ),
      );
    }

    // Local saved FP logins (password switch) not already shown.
    for (final s in tradingService.fpAccounts) {
      add(
        _DashAccount(
          id: '',
          accountNumber: s.accountNumber,
          isDemo: s.isDemo,
          planLabel: s.isDemo ? 'Demo' : 'Standard',
          equity: s.balance,
          isActive: sessionNum.isNotEmpty && s.accountNumber.trim() == sessionNum,
          fromPortal: false,
          savedPassword: s.password,
        ),
      );
    }

    // Active first, then Live, then Demo.
    rows.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      if (a.isDemo != b.isDemo) return a.isDemo ? 1 : -1;
      return a.accountNumber.compareTo(b.accountNumber);
    });
    return rows;
  }

  Future<void> _switchAccount(
    _DashAccount row, {
    bool openTrade = false,
  }) async {
    try {
      if (row.isActive) {
        if (openTrade) ShellScope.of(context).openTab(2);
        return;
      }
      if (row.fromPortal && row.id.isNotEmpty) {
        await tradingService.activateLinkedAccount(row.id);
      } else if (row.savedPassword != null && row.savedPassword!.isNotEmpty) {
        await tradingService.login(row.accountNumber, row.savedPassword!);
      } else {
        _toast(context, 'Cannot switch — re-login required');
        return;
      }
      if (!mounted) return;
      if (openTrade) {
        ShellScope.of(context).openTab(2);
      } else {
        _toast(context, 'Switched to ${row.accountNumber}');
      }
    } catch (e) {
      if (!mounted) return;
      _toast(context, '$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return OcSvcScope(
      active: widget.active,
      sessionOnly: true,
      builder: (context) {
        final rows = _buildRows();

        return Scaffold(
          backgroundColor: OcColors.bg,
          appBar: AppBar(
            backgroundColor: OcColors.bg,
            title: const Text(
              'Dashboard',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                tooltip: 'Transfer',
                onPressed: () => OceanaInternalTransferPage.open(context),
                icon: const Icon(OcIcons.wallet, color: OcColors.primary),
              ),
              IconButton(
                tooltip: 'Open Account',
                onPressed: () => _showOpenAccountSheet(context),
                icon: const Icon(OcIcons.plusSquare, color: OcColors.primary),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshAccounts,
            color: OcColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                if (rows.isEmpty) _EmptyAccounts(),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _AccountCard(
                    accountNumber: rows[i].accountNumber,
                    isDemo: rows[i].isDemo,
                    planLabel: rows[i].planLabel,
                    equity: rows[i].equity,
                    isActive: rows[i].isActive,
                    showWithdraw: !rows[i].isDemo,
                    onTrade: () => _switchAccount(rows[i], openTrade: true),
                    onSwitch: () =>
                        _switchAccount(rows[i], openTrade: true),
                    onDetails: rows[i].isActive
                        ? () => _showAccountDetailSheet(context)
                        : () => _showInactiveAccountSheet(context, rows[i]),
                    onMore: () => _showMoreMenu(
                      context,
                      accountNumber: rows[i].accountNumber,
                      isDemo: rows[i].isDemo,
                    ),
                    onDeposit: () => _openPortalUrl(
                      'https://user.oceanaprofx.com/dashboard/payments/deposit',
                    ),
                    onWithdraw: () => _openPortalUrl(
                      'https://user.oceanaprofx.com/dashboard/payments/withdraw',
                    ),
                    onSettings: () => _showMoreMenu(
                      context,
                      accountNumber: rows[i].accountNumber,
                      isDemo: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

}

class _DashAccount {
  const _DashAccount({
    required this.id,
    required this.accountNumber,
    required this.isDemo,
    required this.planLabel,
    required this.equity,
    required this.isActive,
    required this.fromPortal,
    this.savedPassword,
  });

  final String id;
  final String accountNumber;
  final bool isDemo;
  final String planLabel;
  final double equity;
  final bool isActive;
  final bool fromPortal;
  final String? savedPassword;
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> _openPortalUrl(String url) async {
  await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
}

void _showOpenAccountSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Widget item(String label, Color color, VoidCallback onTap) => Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  // Wait for sheet dismiss before pushing plans page.
                  await Future<void>.delayed(const Duration(milliseconds: 180));
                  if (!context.mounted) return;
                  onTap();
                },
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            );
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 12),
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
                SizedBox(height: 16),
                Text(
                  'Open Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Open a trading account to get superior trading conditions any strategy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: OcColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                item(
                  'Live',
                  OcColors.primary,
                  () async {
                    await OceanaChooseAccountPage.open(context, isDemo: false);
                    if (context.mounted) {
                      // Trigger dashboard refresh via service notify.
                      await tradingService.refreshLinkedAccounts();
                    }
                  },
                ),
                item(
                  'Demo',
                  OcColors.text,
                  () async {
                    await OceanaChooseAccountPage.open(context, isDemo: true);
                    if (context.mounted) {
                      await tradingService.refreshLinkedAccounts();
                    }
                  },
                ),
                item('Cancel', const Color(0xFFD1432A), () {}),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

void _showMoreMenu(
  BuildContext context, {
  required String accountNumber,
  required bool isDemo,
}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Widget row(IconData icon, String label, VoidCallback onTap) => InkWell(
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, color: OcColors.primary, size: 22),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: OcColors.text,
                        ),
                      ),
                    ),
                    Icon(
                      OcIcons.chevronRight,
                      size: 18,
                      color: OcColors.textMuted,
                    ),
                  ],
                ),
              ),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D0D6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                // Trade-Portal: internal transfer is Live → Live only.
                if (!isDemo)
                  row(
                    OcIcons.arrowLeftRight,
                    'Transfer',
                    () => OceanaInternalTransferPage.open(context),
                  ),
                if (!isDemo)
                  row(
                    OcIcons.coins,
                    'Bonus',
                    () => _toast(context, 'Bonus coming soon'),
                  ),
                row(
                  OcIcons.history,
                  'History',
                  () => OceanaTransactionHistoryPage.open(context),
                ),
                row(
                  OcIcons.lock,
                  'Change Password',
                  () => showOceanaChangePasswordDialog(
                    context,
                    accountNumber: accountNumber,
                  ),
                ),
                row(
                  OcIcons.trendingUp,
                  'Leverage',
                  () => OceanaChangeLeveragePage.open(
                    context,
                    accountNumber: accountNumber,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFFD1432A),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

void _showInactiveAccountSheet(BuildContext context, _DashAccount row) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFFF9F9FB),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D0D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  row.accountNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                OcBadge(
                  label: row.isDemo ? 'Demo' : 'Live',
                  filled: !row.isDemo,
                ),
                const Spacer(),
                Text(
                  '\$${formatMoney(row.equity)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                row.planLabel,
                style: TextStyle(color: OcColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Caller opens trade via card actions.
                },
                style: FilledButton.styleFrom(
                  backgroundColor: OcColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showAccountDetailSheet(BuildContext context) {
    final s = tradingService.session;
    if (s == null) return;
    final live = tradingService.account;
    final equity = live.equity > 0 ? live.equity : live.balance;
    final pnl = tradingService.positions.values.fold<double>(
      0,
      (sum, p) => sum + p.floatingPnL,
    );
    final isDemo = tradingService.isActiveAccountDemo;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF9F9FB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            16 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              s.accountNumber,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(width: 8),
                            OcBadge(label: isDemo ? 'Demo' : 'Live'),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            OcBadge(
                              label: s.brokerDisplayName.isNotEmpty
                                  ? s.brokerDisplayName
                                  : 'Oceana',
                              filled: false,
                            ),
                            SizedBox(width: 8),
                            Text(
                              isDemo ? 'Demo' : 'Standard',
                              style: TextStyle(
                                color: OcColors.textSecondary,
                                fontWeight: FontWeight.w500,
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
                      Text(
                        'Equity',
                        style: TextStyle(
                          fontSize: 11,
                          color: OcColors.textMuted,
                        ),
                      ),
                      Text(
                        '\$${formatMoney(equity)} USD',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _kv('Balance', formatMoney(live.balance)),
              _kv('Equity', formatMoney(equity)),
              _kv('Live P/L', '\$${formatMoney(pnl)} USD'),
              _kv('Margin', '\$${formatMoney(live.usedMargin)} USD'),
              _kv('Free Margin', '\$${formatMoney(live.freeMargin)} USD'),
              _kv(
                'Margin Level (%)',
                live.marginLevel > 0
                    ? '${live.marginLevel.toStringAsFixed(2)}%'
                    : '—',
              ),
              _kv('Max. Leverage', '1:500'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SoftAction(
                      label: 'Deposit',
                      icon: OcIcons.arrowDownCircle,
                      bg: OcColors.depositBg,
                      fg: OcColors.depositFg,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openPortalUrl(
                          'https://user.oceanaprofx.com/dashboard/payments/deposit',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SoftAction(
                      label: 'Withdraw',
                      icon: OcIcons.arrowUpRight,
                      bg: OcColors.withdrawBg,
                      fg: OcColors.withdrawFg,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openPortalUrl(
                          'https://user.oceanaprofx.com/dashboard/payments/withdraw',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SoftAction(
                      label: 'Transfer',
                      icon: OcIcons.arrowLeftRight,
                      bg: OcColors.transferBg,
                      fg: OcColors.transferFg,
                      onTap: () {
                        Navigator.pop(ctx);
                        OceanaInternalTransferPage.open(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

Widget _kv(String k, String v) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: TextStyle(
              color: OcColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: OcColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _EmptyAccounts extends StatelessWidget {
  _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: OcColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OcColors.border),
      ),
      child: Column(
        children: [
          Icon(OcIcons.wallet, size: 40, color: OcColors.primary),
          SizedBox(height: 12),
          Text(
            'No trading account yet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Open a Live or Demo account to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: OcColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: () => _showOpenAccountSheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: OcColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Open Account',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.accountNumber,
    required this.isDemo,
    required this.planLabel,
    required this.equity,
    required this.isActive,
    required this.showWithdraw,
    required this.onTrade,
    required this.onSwitch,
    required this.onMore,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onSettings,
    this.onDetails,
  });

  final String accountNumber;
  final bool isDemo;
  final String planLabel;
  final double equity;
  final bool isActive;
  final bool showWithdraw;
  final VoidCallback onTrade;
  final VoidCallback onSwitch;
  final VoidCallback onMore;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onSettings;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    // SS: Live top badge = solid; Demo top badge = soft tint.
    final topBadge = OcBadge(
      label: isDemo ? 'Demo' : 'Live',
      filled: !isDemo,
      compact: true,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: isActive ? OcColors.primarySoft.withValues(alpha: 0.35) : OcColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? OcColors.primary : OcColors.border,
          width: isActive ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            accountNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              height: 1.15,
                              color: OcColors.text,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        topBadge,
                        if (isActive) ...[
                          SizedBox(width: 5),
                          OcBadge(
                            label: 'Active',
                            filled: true,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        OcBadge(
                          label: isDemo ? 'Demo' : 'Live',
                          filled: false,
                          compact: true,
                        ),
                        SizedBox(width: 6),
                        Text(
                          planLabel,
                          style: TextStyle(
                            color: OcColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 11.5,
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
                  Text(
                    'Equity',
                    style: TextStyle(
                      fontSize: 10,
                      color: OcColors.textMuted,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${formatMoney(equity)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1.1,
                          color: OcColors.text,
                        ),
                      ),
                      SizedBox(width: 3),
                      InkWell(
                        onTap: onDetails,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            OcIcons.info,
                            size: 14,
                            color: OcColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _IconTile(
                icon: OcIcons.candlestickChart,
                bg: OcColors.primarySoft,
                fg: OcColors.primary,
                onTap: onTrade,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SoftAction(
                  label: 'Deposit',
                  icon: OcIcons.arrowDownCircle,
                  bg: OcColors.depositBg,
                  fg: OcColors.depositFg,
                  onTap: onDeposit,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: showWithdraw
                    ? _SoftAction(
                        label: 'Withdraw',
                        icon: OcIcons.arrowUpRight,
                        bg: OcColors.withdrawBg,
                        fg: OcColors.withdrawFg,
                        onTap: onWithdraw,
                      )
                    : _SoftAction(
                        label: 'Settings',
                        icon: OcIcons.settings,
                        bg: OcColors.primarySoft,
                        fg: OcColors.primary,
                        onTap: onSettings,
                      ),
              ),
              const SizedBox(width: 6),
              _IconTile(
                icon: OcIcons.network,
                bg: OcColors.primarySoft,
                fg: OcColors.primary,
                onTap: onMore,
              ),
            ],
          ),
          // Inactive only — active account pe Switch to Trade nahi.
          if (!isActive) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: onSwitch,
                icon: const Icon(OcIcons.arrowLeftRight, size: 15),
                label: const Text(
                  'Switch to Trade',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OcColors.primary,
                  side: const BorderSide(color: OcColors.primary, width: 1.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: fg, size: 17),
      ),
    );
  }
}

class _SoftAction extends StatelessWidget {
  const _SoftAction({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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

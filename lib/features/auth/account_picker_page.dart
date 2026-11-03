import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_badge.dart';
import '../../ui/widgets/oc_primary_button.dart';
import 'welcome_page.dart';

/// After email login: pick which trading account to activate.
class AccountPickerPage extends StatefulWidget {
  const AccountPickerPage({super.key, this.onActivated});

  final VoidCallback? onActivated;

  @override
  State<AccountPickerPage> createState() => _AccountPickerPageState();
}

class _AccountPickerPageState extends State<AccountPickerPage> {
  bool _loading = false;
  String? _activatingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await tradingService.refreshLinkedAccounts();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activate(LinkedTradingAccount account) async {
    if (account.id.isEmpty) {
      setState(() => _error = 'Invalid account id');
      return;
    }
    setState(() {
      _activatingId = account.id;
      _error = null;
    });
    try {
      await tradingService.activateLinkedAccount(account.id);
      if (!mounted) return;
      widget.onActivated?.call();
      // Prefer closing whole auth stack if we can; else just pop picker.
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _activatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = tradingService.linkedAccounts;
    final live = accounts.where((a) => a.isLive).toList();
    final demo = accounts.where((a) => a.isDemo).toList();

    return Scaffold(
      backgroundColor: OcColors.bg,
      appBar: AppBar(
        title: Text('Select Account'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: Icon(OcIcons.refreshCw, color: OcColors.primary),
          ),
        ],
      ),
      body: _loading && accounts.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  tradingService.userPortal?.email ?? '',
                  style: TextStyle(
                    color: OcColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose a live or demo account to trade',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_error != null) ...[
                  SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: OcColors.danger),
                  ),
                ],
                if (accounts.isEmpty) ...[
                  SizedBox(height: 40),
                  Icon(
                    OcIcons.wallet,
                    size: 48,
                    color: OcColors.primary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No trading accounts on this email yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: OcColors.textSecondary),
                  ),
                ],
                if (live.isNotEmpty) ...[
                  SizedBox(height: 20),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OcColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  for (final a in live) _card(a),
                ],
                if (demo.isNotEmpty) ...[
                  SizedBox(height: 20),
                  Text(
                    'DEMO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OcColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final a in demo) _card(a),
                ],
              ],
            ),
    );
  }

  Widget _card(LinkedTradingAccount a) {
    final busy = _activatingId == a.id;
    final equity = a.equity > 0 ? a.equity : a.balance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: OcColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: busy ? null : () => _activate(a),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OcColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            a.accountNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OcBadge(label: a.isDemo ? 'Demo' : 'Live'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.planName.isNotEmpty ? a.planName : a.accountType,
                        style: TextStyle(color: OcColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${formatMoney(equity)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        OcIcons.chevronRight,
                        color: OcColors.primary,
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

/// Settings: switch / add portal email login (not trading accounts).
Future<void> showSwitchLinkedAccountsSheet(BuildContext context) async {
  if (!tradingService.hasUserPortal) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in with email to switch accounts')),
    );
    return;
  }
  if (!context.mounted) return;

  final email = tradingService.userPortal?.email.trim() ?? '';
  final profileName =
      '${tradingService.userProfile?['name'] ?? ''}'.trim();
  final sessionName = tradingService.session?.name.trim() ?? '';
  final name = profileName.isNotEmpty
      ? profileName
      : (sessionName.isNotEmpty
          ? sessionName
          : (email.isNotEmpty ? email.split('@').first : 'User'));

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: OcColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Switch Account',
                  style: TextStyle(
                    fontSize: 18,
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
            _SwitchAccountTile(
              name: name,
              email: email,
              selected: true,
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
            OcPrimaryButton(
              label: 'Add New +',
              onPressed: () async {
                Navigator.pop(ctx);
                await tradingService.logout();
                if (!context.mounted) return;
                // Push on top of shell (do not remove shell) — after
                // login, popUntil(isFirst) returns to OceanaShell.
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WelcomePage(),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _SwitchAccountTile extends StatelessWidget {
  _SwitchAccountTile({
    required this.name,
    required this.email,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String email;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: OcColors.primarySoft,
              child: Icon(OcIcons.user, color: OcColors.primary, size: 26),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: OcColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(
                OcIcons.checkCircle2,
                color: OcColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

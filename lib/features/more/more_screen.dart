import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/push_notifications.dart';
import '../../core/theme_controller.dart';
import '../../core/trading_service.dart';
import '../../features/auth/account_picker_page.dart';
import '../../features/auth/welcome_page.dart';
import '../../features/dashboard/oceana_internal_transfer_page.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_svc_scope.dart';
import '../auth/oceana_forgot_password.dart';
import 'oceana_notifications_page.dart';
import 'oceana_profile_edit_page.dart';
import 'oceana_support_page.dart';
import 'oceana_transaction_history_page.dart';
import 'oceana_verify_account_page.dart';
import 'oceana_verify_progress.dart';

/// More / Settings — Tenax SS layout, Oceana brand `#1414C7`.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, this.active = true});

  final bool active;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _oneClick = true;
  bool _notificationsOn = true;
  int _notifUnread = 0;
  String _version = '1.1.1';
  OceanaVerifyProgress _verify = OceanaVerifyProgress.from(
    profile: null,
    kyc: null,
  );

  @override
  void initState() {
    super.initState();
    _notificationsOn = PushNotifications.enabled;
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    _loadVerify();
    _loadNotifCount();
  }

  @override
  void didUpdateWidget(covariant MoreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _loadNotifCount();
    }
  }

  Future<void> _loadVerify() async {
    if (!tradingService.hasUserPortal) return;
    try {
      await Future.wait([
        tradingService.fetchUserProfile(force: true),
        tradingService.fetchMyKyc(force: true),
      ]);
      if (!mounted) return;
      setState(() {
        _verify = OceanaVerifyProgress.from(
          profile: tradingService.userProfile,
          kyc: tradingService.myKyc,
        );
      });
    } catch (_) {}
  }

  Future<void> _loadNotifCount() async {
    if (!tradingService.hasUserPortal) {
      if (mounted) setState(() => _notifUnread = 0);
      return;
    }
    try {
      final n = await tradingService.fetchNotificationUnreadCount();
      if (mounted) setState(() => _notifUnread = n);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await OceanaNotificationsPage.open(context);
    if (mounted) await _loadNotifCount();
  }

  @override
  Widget build(BuildContext context) {
    return OcSvcScope(
      active: widget.active,
      sessionOnly: true,
      builder: (context) {
        final session = tradingService.session;
        final portalEmail = tradingService.userPortal?.email ?? '';
        final name = (session?.name.isNotEmpty == true)
            ? session!.name
            : (session?.accountNumber ??
                (portalEmail.isNotEmpty ? portalEmail : 'Guest'));

        return Scaffold(
          backgroundColor: OcColors.bg,
          appBar: AppBar(
            backgroundColor: OcColors.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: OcColors.text,
              ),
            ),
            actions: [
              IconButton(
                onPressed: _openNotifications,
                tooltip: 'Notifications',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(OcIcons.bell, color: OcColors.primary, size: 21),
                    if (_notifUnread > 0)
                      Positioned(
                        right: -5,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: OcColors.danger,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _notifUnread > 99 ? '99+' : '$_notifUnread',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  await OceanaProfileEditPage.open(context);
                  if (mounted) await _loadVerify();
                },
                icon: const Icon(OcIcons.pencil, color: OcColors.primary, size: 20),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _ProfileRow(
                name: name,
                email: portalEmail.isNotEmpty
                    ? portalEmail
                    : (session != null
                        ? 'Account ${session.accountNumber}'
                        : 'Not signed in'),
                emailVerified: _verify.emailDone,
                onTap: () => showSwitchLinkedAccountsSheet(context),
              ),
              if (!_verify.fullyVerified) ...[
                const SizedBox(height: 14),
                _VerifyCard(
                  progress: _verify,
                  onTap: () async {
                    await OceanaVerifyAccountPage.open(context);
                    if (mounted) await _loadVerify();
                  },
                ),
              ],
              const SizedBox(height: 16),
              _QuickActions(
                onDeposit: () => _openPortalUrl(
                  'https://user.oceanaprofx.com/dashboard/payments/deposit',
                ),
                onWithdraw: () => _openPortalUrl(
                  'https://user.oceanaprofx.com/dashboard/payments/withdraw',
                ),
                onTransfer: () => OceanaInternalTransferPage.open(context),
                onHistory: () => OceanaTransactionHistoryPage.open(context),
              ),
              const SizedBox(height: 16),
              _MenuCard(
                children: [
                  _MenuTile(
                    icon: OcIcons.circleDollarSign,
                    title: 'Finance',
                    onTap: () => OceanaTransactionHistoryPage.open(context),
                  ),
                  _MenuTile(
                    icon: OcIcons.layoutDashboard,
                    title: 'IB Dashboard',
                    comingSoon: true,
                    onTap: () {},
                  ),
                  _MenuTile(
                    icon: OcIcons.arrowLeftRight,
                    title: 'Copy Trading',
                    comingSoon: true,
                    onTap: () {},
                  ),
                  _MenuTile(
                    icon: OcIcons.users,
                    title: 'PAMM',
                    comingSoon: true,
                    onTap: () {},
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MenuCard(
                children: [
                  _ToggleTile(
                    icon: OcIcons.bell,
                    title: 'Push alerts',
                    value: _notificationsOn,
                    onChanged: (v) async {
                      setState(() => _notificationsOn = v);
                      await PushNotifications.setEnabled(v);
                      if (mounted) {
                        setState(
                          () => _notificationsOn = PushNotifications.enabled,
                        );
                      }
                    },
                  ),
                  _ToggleTile(
                    icon: OcIcons.hand,
                    title: 'One Click Trading',
                    value: _oneClick,
                    onChanged: (v) => setState(() => _oneClick = v),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MenuCard(
                children: [
                  _MenuTile(
                    icon: OcIcons.bell,
                    title: 'Notifications',
                    badge: _notifUnread > 0
                        ? (_notifUnread > 99 ? '99+' : '$_notifUnread')
                        : null,
                    onTap: _openNotifications,
                  ),
                  _MenuTile(
                    icon: OcIcons.headphones,
                    title: 'Support Tickets',
                    onTap: () => OceanaSupportPage.open(context),
                  ),
                  _MenuTile(
                    icon: OcIcons.palette,
                    title: 'Theme',
                    onTap: () => _openThemeSheet(context),
                  ),
                  _MenuTile(
                    icon: OcIcons.lock,
                    title: 'Change Password',
                    onTap: () {
                      final email = tradingService.userPortal?.email ??
                          '${tradingService.userProfile?['email'] ?? ''}';
                      openForgotPasswordFlow(
                        context,
                        initialEmail: email,
                        confirmOnly: true,
                      );
                    },
                  ),
                  _MenuTile(
                    icon: OcIcons.userX,
                    title: 'Delete Account',
                    onTap: () => _openDeleteAccountSheet(context),
                  ),
                  _MenuTile(
                    icon: OcIcons.logOut,
                    title: 'Logout',
                    titleColor: OcColors.danger,
                    onTap: () async {
                      await tradingService.logout();
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WelcomePage(),
                        ),
                      );
                    },
                    showDivider: false,
                  ),
                ],
              ),
              SizedBox(height: 18),
              Center(
                child: Text(
                  'Version $_version',
                  style: TextStyle(
                    color: OcColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPortalUrl(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openDeleteAccountSheet(BuildContext context) {
    const email = 'info@oceanaprofx.com';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: OcColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(OcIcons.x),
                  ),
                ],
              ),
              Text(
                'To delete your account, please contact our support team by email.',
                style: TextStyle(
                  color: OcColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: OcColors.primarySoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(OcIcons.megaphone, color: OcColors.primary, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(
                          color: OcColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: email,
                      queryParameters: {
                        'subject': 'Account deletion request',
                      },
                    );
                    await launchUrl(uri);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: OcColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Contact Support',
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

  void _openThemeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: mtDarkMode,
          builder: (_, _) {
            final isDark = mtDarkMode.value;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: OcColors.text,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Choose your preferred theme',
                              style: TextStyle(
                                color: OcColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(OcIcons.x),
                      ),
                    ],
                  ),
                  _ThemeOption(
                    icon: OcIcons.settings2,
                    label: 'System Default',
                    selected: false,
                    onTap: () {},
                  ),
                  _ThemeOption(
                    icon: OcIcons.sun,
                    label: 'Light',
                    selected: !isDark,
                    onTap: () {
                      setMtDarkMode(false);
                      Navigator.pop(ctx);
                    },
                  ),
                  _ThemeOption(
                    icon: OcIcons.moon,
                    label: 'Dark',
                    selected: isDark,
                    onTap: () {
                      setMtDarkMode(true);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/* ---------------- profile (SS: no border card) ---------------- */

class _ProfileRow extends StatelessWidget {
  _ProfileRow({
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.onTap,
  });

  final String name;
  final String email;
  final bool emailVerified;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: OcColors.primarySoft,
              child: Icon(OcIcons.user, color: OcColors.primary, size: 30),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: OcColors.text,
                          ),
                        ),
                      ),
                      if (emailVerified) ...[
                        SizedBox(width: 5),
                        Icon(
                          OcIcons.badgeCheck,
                          size: 15,
                          color: OcColors.depositFg,
                        ),
                      ],
                    ],
                  ),
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
                  if (!emailVerified && email.contains('@')) ...[
                    SizedBox(height: 2),
                    Text(
                      'Email not verified',
                      style: TextStyle(
                        color: OcColors.loss,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: OcColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                OcIcons.chevronDown,
                size: 18,
                color: OcColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- verify (SS: soft lavender card) ---------------- */

class _VerifyCard extends StatelessWidget {
  _VerifyCard({required this.progress, required this.onTap});

  final OceanaVerifyProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = progress.percent.clamp(0, 100);
    final subtitle = progress.fullyVerified
        ? 'Your account is fully verified'
        : progress.kycPending
            ? 'KYC pending — under review'
            : progress.kycRejected
                ? 'KYC rejected — resubmit required'
                : 'Complete verification to unlock all app features';
    return Material(
      color: OcColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Verify your account',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: OcColors.text,
                      ),
                    ),
                  ),
                  if (progress.kycPending || progress.kycRejected)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: progress.kycPending
                            ? const Color(0xFFFFF3CD)
                            : OcColors.withdrawBg,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        progress.kycPending ? 'Pending' : 'Rejected',
                        style: TextStyle(
                          color: progress.kycPending
                              ? const Color(0xFFB78103)
                              : OcColors.withdrawFg,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
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
              SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: OcColors.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$pct% completed',
                style: TextStyle(
                  color: OcColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 5,
                  backgroundColor: OcColors.primaryMuted.withValues(alpha: 0.35),
                  color: OcColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- quick actions ---------------- */

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onDeposit,
    required this.onWithdraw,
    required this.onTransfer,
    required this.onHistory,
  });

  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onTransfer;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required IconData icon,
      required String label,
      required Color bg,
      required Color fg,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: fg, size: 22),
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: OcColors.text,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(
          icon: OcIcons.arrowDownToLine,
          label: 'Deposit',
          bg: OcColors.depositBg,
          fg: OcColors.depositFg,
          onTap: onDeposit,
        ),
        const SizedBox(width: 10),
        tile(
          icon: OcIcons.arrowUpRight,
          label: 'Withdraw',
          bg: const Color(0xFFFFF3E0),
          fg: const Color(0xFFE65100),
          onTap: onWithdraw,
        ),
        const SizedBox(width: 10),
        tile(
          icon: OcIcons.arrowLeftRight,
          label: 'Transfer',
          bg: const Color(0xFFE3F2FD),
          fg: const Color(0xFF1565C0),
          onTap: onTransfer,
        ),
        const SizedBox(width: 10),
        tile(
          icon: OcIcons.history,
          label: 'History',
          bg: OcColors.historyBg,
          fg: OcColors.primary,
          onTap: onHistory,
        ),
      ],
    );
  }
}

/* ---------------- menu cards ---------------- */

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OcColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: OcColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.showDivider = true,
    this.comingSoon = false,
    this.badge,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? titleColor;
  final bool showDivider;
  final bool comingSoon;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: comingSoon ? null : onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: OcColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: OcColors.primary, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: titleColor ?? OcColors.text,
                    ),
                  ),
                ),
                if (comingSoon)
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: OcColors.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: OcColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  )
                else ...[
                  if (badge != null) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: OcColors.danger,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  Icon(
                    OcIcons.chevronRight,
                    size: 16,
                    color: OcColors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.7,
            indent: 62,
            endIndent: 14,
            color: OcColors.border,
          ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: OcColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: OcColors.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: OcColors.text,
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                activeTrackColor: OcColors.primary,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.7,
            indent: 62,
            endIndent: 14,
            color: OcColors.border,
          ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: OcColors.primarySoft,
        child: Icon(icon, color: OcColors.primary, size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: OcColors.text,
        ),
      ),
      trailing: Icon(
        selected ? OcIcons.checkCircle2 : OcIcons.circle,
        color: selected ? OcColors.primary : OcColors.textMuted,
      ),
    );
  }
}

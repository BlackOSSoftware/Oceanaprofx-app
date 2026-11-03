import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../auth/oceana_verify_email_page.dart';
import 'oceana_profile_edit_page.dart';
import 'oceana_verify_progress.dart';

/// Verify your account — checklist + live % from Trade-Portal rules.
class OceanaVerifyAccountPage extends StatefulWidget {
  const OceanaVerifyAccountPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OceanaVerifyAccountPage()),
    );
  }

  @override
  State<OceanaVerifyAccountPage> createState() =>
      _OceanaVerifyAccountPageState();
}

class _OceanaVerifyAccountPageState extends State<OceanaVerifyAccountPage> {
  bool _loading = true;
  String? _error;
  OceanaVerifyProgress _progress = OceanaVerifyProgress.from(
    profile: null,
    kyc: null,
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([
        tradingService.fetchUserProfile(force: true),
        tradingService.fetchMyKyc(force: true),
      ]);
      if (!mounted) return;
      setState(() {
        _progress = OceanaVerifyProgress.from(
          profile: tradingService.userProfile,
          kyc: tradingService.myKyc,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
        _progress = OceanaVerifyProgress.from(
          profile: tradingService.userProfile,
          kyc: tradingService.myKyc,
        );
      });
    }
  }

  Future<void> _openProfile() async {
    await OceanaProfileEditPage.open(context);
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openEmailVerify() async {
    final email = '${tradingService.userProfile?['email'] ?? ''}'.trim().isNotEmpty
        ? '${tradingService.userProfile?['email']}'.trim()
        : (tradingService.userPortal?.email ?? '');
    await OceanaVerifyEmailPage.open(context, email: email);
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openKyc() async {
    await launchUrl(
      Uri.parse('https://user.oceanaprofx.com/dashboard/kyc'),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    return Scaffold(
      backgroundColor: OcColors.bg,
      appBar: AppBar(
        backgroundColor: OcColors.bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(OcIcons.arrowBack, color: OcColors.text),
        ),
        title: const Text(
          'Verify your account',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: OcColors.primary,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: OcColors.loss,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: OcColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullyVerified
                              ? 'Account fully verified'
                              : p.kycPending
                                  ? 'KYC under review — finish remaining steps'
                                  : p.kycRejected
                                      ? 'KYC rejected — please resubmit'
                                      : 'Complete verification to unlock all app features',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: OcColors.text,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '${p.percent}% completed',
                          style: TextStyle(
                            color: OcColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: p.percent / 100,
                            minHeight: 6,
                            backgroundColor: OcColors.primaryMuted.withValues(
                              alpha: 0.35,
                            ),
                            color: OcColors.primary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${p.doneCount}/5 steps done',
                          style: TextStyle(
                            color: OcColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _step(
                    title: p.emailDone
                        ? 'Email verified'
                        : 'Email not verified',
                    subtitle: p.emailDone
                        ? 'Your login email is confirmed'
                        : 'Verify your email on the portal',
                    state: p.emailDone
                        ? _StepState.verified
                        : _StepState.todo,
                    onTap: p.emailDone ? null : _openEmailVerify,
                  ),
                  _step(
                    title: 'Phone number',
                    subtitle: p.phoneDone ? 'Added' : 'Add your phone number',
                    state: p.phoneDone
                        ? _StepState.verified
                        : _StepState.todo,
                    onTap: _openProfile,
                  ),
                  _step(
                    title: 'Personal details',
                    subtitle: p.personalDone
                        ? 'Date of birth & gender set'
                        : 'Add date of birth and gender',
                    state: p.personalDone
                        ? _StepState.verified
                        : _StepState.todo,
                    onTap: _openProfile,
                  ),
                  _step(
                    title: 'Address',
                    subtitle: p.addressDone
                        ? 'Address on file'
                        : 'Add address, city and country',
                    state: p.addressDone
                        ? _StepState.verified
                        : _StepState.todo,
                    onTap: _openProfile,
                  ),
                  _step(
                    title: 'Identity (KYC)',
                    subtitle: switch (p.kycStatus) {
                      'VERIFIED' => 'Identity verified',
                      'PENDING' => 'Pending — documents under review',
                      'REJECTED' => 'Rejected — resubmit documents',
                      _ => 'Complete identity verification',
                    },
                    state: switch (p.kycStatus) {
                      'VERIFIED' => _StepState.verified,
                      'PENDING' => _StepState.pending,
                      'REJECTED' => _StepState.rejected,
                      _ => _StepState.todo,
                    },
                    onTap: p.kycVerified ? null : _openKyc,
                    showDivider: false,
                  ),
                  const SizedBox(height: 20),
                  if (!p.personalDone || !p.addressDone || !p.phoneDone)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _openProfile,
                        style: FilledButton.styleFrom(
                          backgroundColor: OcColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Complete profile',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  if (p.personalDone &&
                      p.addressDone &&
                      p.phoneDone &&
                      p.kycStatus != 'VERIFIED' &&
                      p.kycStatus != 'PENDING') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _openKyc,
                        style: FilledButton.styleFrom(
                          backgroundColor: OcColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Start KYC verification',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                  if (p.kycStatus == 'PENDING' || p.kycStatus == 'REJECTED') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _openKyc,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OcColors.primary,
                          side: const BorderSide(color: OcColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          p.kycStatus == 'PENDING'
                              ? 'View KYC status'
                              : 'Resubmit KYC',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _step({
    required String title,
    required String subtitle,
    required _StepState state,
    required VoidCallback? onTap,
    bool showDivider = true,
  }) {
    final Color bg;
    final Color fg;
    final IconData icon;
    switch (state) {
      case _StepState.verified:
        bg = OcColors.depositBg;
        fg = OcColors.depositFg;
        icon = OcIcons.check;
      case _StepState.pending:
        bg = const Color(0xFFFFF3CD);
        fg = const Color(0xFFB78103);
        icon = OcIcons.history;
      case _StepState.rejected:
        bg = OcColors.withdrawBg;
        fg = OcColors.withdrawFg;
        icon = OcIcons.xCircle;
      case _StepState.todo:
        bg = OcColors.primarySoft;
        fg = OcColors.primary;
        icon = OcIcons.chevronRight;
    }

    return Column(
      children: [
        Material(
          color: OcColors.surface,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: OcColors.text,
                                ),
                              ),
                            ),
                            if (state == _StepState.pending ||
                                state == _StepState.rejected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  state == _StepState.pending
                                      ? 'Pending'
                                      : 'Rejected',
                                  style: TextStyle(
                                    color: fg,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: OcColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
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
        ),
        if (showDivider) Divider(height: 1, color: OcColors.border),
      ],
    );
  }
}

enum _StepState { verified, pending, rejected, todo }

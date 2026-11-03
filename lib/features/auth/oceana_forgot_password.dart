import 'package:flutter/material.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_primary_button.dart';

/// Send reset-password email via backend — polished confirm → send → success.
Future<void> openForgotPasswordFlow(
  BuildContext context, {
  String initialEmail = '',
  bool confirmOnly = false,
}) async {
  var email = initialEmail.trim().toLowerCase();

  // Login / free entry: always show editable email sheet (prefill OK).
  // confirmOnly (e.g. Change Password): skip edit, use given email.
  if (!confirmOnly) {
    email = await _askEmailSheet(context, email) ?? '';
    if (email.isEmpty || !context.mounted) return;
  }

  if (email.isEmpty || !email.contains('@')) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No email found on this account')),
    );
    return;
  }

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: OcColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ResetLinkSheet(email: email),
  );
}

class _ResetLinkSheet extends StatefulWidget {
  const _ResetLinkSheet({required this.email});

  final String email;

  @override
  State<_ResetLinkSheet> createState() => _ResetLinkSheetState();
}

enum _ResetStep { confirm, sending, success, error }

class _ResetLinkSheetState extends State<_ResetLinkSheet> {
  _ResetStep _step = _ResetStep.confirm;
  String _message = 'Reset link sent to your email successfully';
  String? _error;

  Future<void> _send() async {
    setState(() {
      _step = _ResetStep.sending;
      _error = null;
    });
    try {
      final msg = await tradingService.forgotPassword(widget.email);
      if (!mounted) return;
      setState(() {
        _step = _ResetStep.success;
        _message = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _ResetStep.error;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            switch (_step) {
              _ResetStep.confirm => _confirmBody(),
              _ResetStep.sending => _sendingBody(),
              _ResetStep.success => _successBody(),
              _ResetStep.error => _errorBody(),
            },
          ],
        ),
      ),
    );
  }

  Widget _confirmBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: OcColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                OcIcons.lock,
                color: OcColors.primary,
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset password',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "We'll email a secure link to reset your password.",
                    style: TextStyle(
                      color: OcColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(OcIcons.x, size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OcColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OcColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: OcColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  OcIcons.user,
                  color: OcColors.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEND TO',
                      style: TextStyle(
                        color: OcColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      widget.email,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Text(
          "The link expires in 30 minutes. Check spam if you don't see it.",
          style: TextStyle(
            color: OcColors.textMuted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OcColors.text,
                  side: BorderSide(color: OcColors.borderStrong),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: FilledButton(
                onPressed: _send,
                style: FilledButton.styleFrom(
                  backgroundColor: OcColors.primary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Send link',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sendingBody() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: OcColors.primary,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Sending reset link…',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          SizedBox(height: 6),
          Text(
            'Please wait a moment',
            style: TextStyle(color: OcColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _successBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: OcColors.depositBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              OcIcons.checkCircle2,
              color: OcColors.depositFg,
              size: 28,
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Link sent successfully',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        SizedBox(height: 8),
        Text(
          _message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: OcColors.textSecondary,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            color: OcColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: OcColors.primary,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _errorBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              OcIcons.x,
              color: OcColors.loss,
              size: 26,
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          "Couldn't send email",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        SizedBox(height: 8),
        Text(
          _error ?? 'Something went wrong. Please try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: OcColors.textSecondary,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _send,
                style: FilledButton.styleFrom(
                  backgroundColor: OcColors.primary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<String?> _askEmailSheet(BuildContext context, String initial) async {
  final emailCtrl = TextEditingController(text: initial);
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: OcColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              16 +
                  MediaQuery.paddingOf(ctx).bottom +
                  MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D0D6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: OcColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        OcIcons.lock,
                        color: OcColors.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Forgot password',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(OcIcons.x, size: 20),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Enter the email linked to your account.',
                  style: TextStyle(
                    color: OcColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    hintText: 'Registered email',
                    filled: true,
                    fillColor: OcColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: OcColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: OcColors.border),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: OcColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OcPrimaryButton(
                  label: 'Continue',
                  onPressed: () {
                    final v = emailCtrl.text.trim();
                    if (v.isEmpty || !v.contains('@')) {
                      setModal(() => error = 'Please enter a valid email');
                      return;
                    }
                    Navigator.pop(ctx, v);
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
  emailCtrl.dispose();
  return result?.trim().toLowerCase();
}

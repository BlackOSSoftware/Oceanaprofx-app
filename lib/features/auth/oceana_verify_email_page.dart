import 'package:flutter/material.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_brand_mark.dart';
import '../../ui/widgets/oc_primary_button.dart';

/// Trade-Portal login → verify step: resend verification email.
class OceanaVerifyEmailPage extends StatefulWidget {
  const OceanaVerifyEmailPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  static Future<void> open(BuildContext context, {String email = ''}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OceanaVerifyEmailPage(initialEmail: email),
      ),
    );
  }

  @override
  State<OceanaVerifyEmailPage> createState() => _OceanaVerifyEmailPageState();
}

class _OceanaVerifyEmailPageState extends State<OceanaVerifyEmailPage> {
  late final TextEditingController _email;
  bool _loading = false;
  bool _sent = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await tradingService.resendVerifyEmail(_email.text);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
        _success = 'Verification email sent successfully';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email.text.trim();
    return Scaffold(
      backgroundColor: OcColors.surface,
      appBar: AppBar(
        backgroundColor: OcColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(OcIcons.arrowBack, color: OcColors.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: OcBrandMark(size: 64)),
              SizedBox(height: 24),
              Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: OcColors.text,
                ),
              ),
              SizedBox(height: 10),
              Text(
                _sent
                    ? 'A verification link has been sent to'
                    : "Please verify your email first. We'll send a confirmation link to your inbox.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OcColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              if (_sent && email.isNotEmpty) ...[
                SizedBox(height: 10),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check your inbox and click the link to activate your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: OcColors.textMuted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (!_sent) ...[
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Email address',
                  ),
                ),
                if (_error != null) ...[
                  SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: OcColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: 18),
                OcPrimaryButton(
                  label: 'Send verification email',
                  loading: _loading,
                  onPressed: _send,
                ),
              ] else ...[
                if (_success != null) ...[
                  Text(
                    _success!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: OcColors.depositFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                OcPrimaryButton(
                  label: 'Go to Login',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _sent = false);
                          _send();
                        },
                  child: const Text(
                    'Resend email',
                    style: TextStyle(
                      color: OcColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

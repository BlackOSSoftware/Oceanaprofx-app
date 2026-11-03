import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/push_notifications.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_brand_mark.dart';
import '../../ui/widgets/oc_primary_button.dart';
import 'oceana_forgot_password.dart';
import 'oceana_verify_email_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onAuthenticated});

  final VoidCallback? onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  static final _signupUri = Uri.parse('https://user.oceanaprofx.com/signup');

  Future<void> _openRegister() async {
    await launchUrl(_signupUri, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    _prefillSaved();
  }

  Future<void> _prefillSaved() async {
    final saved = await tradingService.savedEmailLogin();
    if (!mounted || saved == null) return;
    _email.text = saved.email;
    _password.text = saved.password;
    setState(() {});
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await tradingService.loginWithEmail(
        _email.text.trim(),
        _password.text,
      );
      // Bind FCM token to this portal user (best-effort).
      unawaited(PushNotifications.syncTokenWithBackend());
      if (!mounted) return;
      if (tradingService.isLoggedIn) {
        widget.onAuthenticated?.call();
        // Clear Welcome/Login/Broker stack — stay on main shell.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on EmailNotVerifiedException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your email first')),
      );
      await OceanaVerifyEmailPage.open(context, email: e.email);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OcColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, 20, 28, 20 + viewInsets),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      Center(child: OcBrandMark(size: 72)),
                      const SizedBox(height: 28),
                      Text(
                        'Hi, Welcome! 👋',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: OcColors.text,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(hintText: 'Email'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        onSubmitted: (_) => _submit(),
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          hintText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? OcIcons.eyeOff : OcIcons.eye,
                              size: 20,
                              color: OcColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => openForgotPasswordFlow(
                            context,
                            initialEmail: _email.text.trim(),
                            confirmOnly: false,
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: OcColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: OcColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      OcPrimaryButton(
                        label: 'Login',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: OcColors.textSecondary,
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: "Don't have an account "),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: _openRegister,
                                  child: const Text(
                                    'Register',
                                    style: TextStyle(
                                      color: OcColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const LoginPage({super.key, this.onAuthenticated, this.initialEmail});

  final VoidCallback? onAuthenticated;
  final String? initialEmail;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
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
    final seed = widget.initialEmail?.trim() ?? '';
    if (seed.isNotEmpty) _email.text = seed;
    // Prefill email only — leave password empty so Google Password Manager
    // can offer / save credentials (pre-filling password blocks the save prompt).
    _prefillEmail();
  }

  Future<void> _prefillEmail() async {
    final seed = widget.initialEmail?.trim().toLowerCase() ?? '';
    if (seed.isNotEmpty) {
      if (mounted) {
        _email.text = seed;
        setState(() {});
      }
      return;
    }
    final saved = await tradingService.savedEmailLogin();
    if (!mounted || saved == null) return;
    _email.text = saved.email;
    setState(() {});
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await tradingService.loginWithEmail(
        _email.text.trim(),
        _password.text,
      );
      // Ask Google / iOS Password Manager to save this login.
      TextInput.finishAutofillContext(shouldSave: true);
      // Bind FCM token to this portal user (best-effort).
      unawaited(PushNotifications.syncTokenWithBackend());
      if (!mounted) return;
      if (tradingService.isLoggedIn) {
        widget.onAuthenticated?.call();
        // Clear Welcome/Login/Broker stack — stay on main shell.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on EmailNotVerifiedException catch (e) {
      TextInput.finishAutofillContext(shouldSave: false);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your email first')),
      );
      await OceanaVerifyEmailPage.open(context, email: e.email);
    } catch (e) {
      TextInput.finishAutofillContext(shouldSave: false);
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
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 2),
                        const Center(
                          child: OcBrandMark(height: 96, maxWidth: 280),
                        ),
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
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          decoration: const InputDecoration(hintText: 'Email'),
                          onEditingComplete: () =>
                              _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.visiblePassword,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
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
                                    child: Text(
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
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/trading_service.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_brand_mark.dart';
import '../../ui/widgets/oc_primary_button.dart';
import '../brokers/broker_search_page.dart';
import 'login_page.dart';

class WelcomePage extends StatelessWidget {
  WelcomePage({super.key, this.onAuthenticated});

  final VoidCallback? onAuthenticated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OcColors.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Spacer(flex: 2),
              OcBrandMark(size: 88),
              SizedBox(height: 28),
              Text(
                'All your Trade.\nOne secure place',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: OcColors.text,
                ),
              ),
              const Spacer(flex: 2),
              OcPrimaryButton(
                label: 'Get Started',
                onPressed: () async {
                  final ok = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => LoginPage(
                        onAuthenticated: onAuthenticated,
                      ),
                    ),
                  );
                  if ((ok == true || tradingService.isLoggedIn) &&
                      context.mounted) {
                    onAuthenticated?.call();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
              const SizedBox(height: 12),
              OcOutlinedButton(
                label: 'Create Account',
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://user.oceanaprofx.com/signup'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              SizedBox(height: 18),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => BrokerSearchPage(),
                    ),
                  );
                },
                child: Text(
                  'Back to search',
                  style: TextStyle(
                    color: OcColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Spacer(),
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: OcColors.textMuted,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'By continuing you accept our '),
                      TextSpan(
                        text: 'Terms & Condition',
                        style: TextStyle(
                          color: OcColors.primary.withValues(alpha: 0.85),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: OcColors.primary.withValues(alpha: 0.85),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'oceana_choose_account_page.dart';

/// Deprecated entry — Trade-Portal flow lives on [OceanaChooseAccountPage].
class OceanaCreateAccountPage extends StatelessWidget {
  const OceanaCreateAccountPage({
    super.key,
    required this.planId,
    required this.planName,
    required this.isDemo,
    this.maxLeverage = 500,
    this.currency = 'USD',
  });

  final String planId;
  final String planName;
  final bool isDemo;
  final int maxLeverage;
  final String currency;

  static Future<bool?> open(
    BuildContext context, {
    required String planId,
    required String planName,
    required bool isDemo,
    int maxLeverage = 500,
    String currency = 'USD',
  }) async {
    await OceanaChooseAccountPage.open(context, isDemo: isDemo);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return OceanaChooseAccountPage(isDemo: isDemo);
  }
}

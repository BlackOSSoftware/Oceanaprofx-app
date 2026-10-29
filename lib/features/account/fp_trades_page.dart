import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import 'mq_widgets.dart';

/// FP Trades broker screen (Brokers list se). "Login to an account"
/// form MetaTrader style ka hai, lekin login asal FP Trades API
/// (/v1/account-auth/login) se hota hai - successful login par
/// asal trading session banta hai, WebSocket connect hota hai aur
/// trades isi account se server par jate hain.
class FpTradesPage extends StatefulWidget {
  const FpTradesPage({super.key, this.initial, this.brokerDisplayName});

  /// Manage Accounts ke saved card se khola ho to login pehle se bhara.
  final SavedFpAccount? initial;

  /// Brokers list se aaya display name (FpTrades / Oceana Pro FX).
  final String? brokerDisplayName;

  @override
  State<FpTradesPage> createState() => _FpTradesPageState();
}

class _FpTradesPageState extends State<FpTradesPage> {
  // Cosmetic only (login API broker se resolve karta hai).
  late String _server =
      (widget.initial?.isDemo ?? false) ? 'Demo' : 'Live';
  bool _savePassword = true;
  bool _busy = false;
  late final _loginCtrl = TextEditingController(
    text: widget.initial?.accountNumber ?? '',
  );
  late final _passCtrl = TextEditingController(
    text: widget.initial?.password ?? '',
  );

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signIn() async {
    // Spaces hatao; AC with/without dono login() khud try karega.
    final login = _loginCtrl.text.trim().replaceAll(' ', '');
    final pass = _passCtrl.text;
    if (login.isEmpty || pass.isEmpty) {
      _snack('Enter login and password');
      return;
    }
    setState(() => _busy = true);
    try {
      // FP Trades API login - asal session + live WebSocket.
      await tradingService.login(login, pass, savePassword: _savePassword);
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) _snack(ApiConfig.userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgot() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MtColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text(
          'Forgot password?',
          style: TextStyle(fontSize: 20, color: MtColors.text),
        ),
        content: Text(
          'Please contact your broker support to reset your account password.',
          style: TextStyle(fontSize: 15, color: MtColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Skip',
              style: TextStyle(color: mqBlue, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MtColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header: back arrow + title.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back,
                      size: 24,
                      color: MtColors.text,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Login to an account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: MtColors.text,
                    ),
                  ),
                ],
              ),
            ),
            // Broker row.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  FpLogo(
                    size: 40,
                    brokerDisplayName:
                        (widget.brokerDisplayName ?? '').trim().isNotEmpty
                        ? widget.brokerDisplayName!.trim()
                        : (widget.initial?.brokerDisplayName ?? ''),
                    brokerCode: widget.initial?.brokerCode ?? '',
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _server,
                        style: TextStyle(fontSize: 17, color: MtColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (widget.brokerDisplayName ?? '').trim().isNotEmpty
                            ? widget.brokerDisplayName!.trim()
                            : (widget.initial?.brandLabel ??
                                ApiConfig.publicServerLabel),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: MtColors.line,
              indent: 16,
              endIndent: 16,
            ),
            MqFieldRow(
              label: 'Login',
              controller: _loginCtrl,
              hint: 'Account number',
            ),
            MqFieldRow(label: 'Password', controller: _passCtrl, obscure: true),
            Builder(
              builder: (rowCtx) => MqDropdownRow(
                label: 'Server',
                value: _server,
                onTap: () async {
                  final v = await showMqMenu(rowCtx, const [
                    'Live',
                    'Demo',
                  ]);
                  if (v != null) setState(() => _server = v);
                },
              ),
            ),
            // Save password (neeche divider nahi).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Save password',
                      style: TextStyle(fontSize: 16, color: MtColors.icon),
                    ),
                  ),
                  Checkbox(
                    value: _savePassword,
                    activeColor: mqBlue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) =>
                        setState(() => _savePassword = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _forgot,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: mqBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const Spacer(),
            // SIGN IN - neeche fixed bada pill button.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _signIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: mqBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SIGN IN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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

/// Broker logo (FpTrades / Oceana assets). Defaults to FpTrades.
class FpLogo extends StatelessWidget {
  const FpLogo({
    super.key,
    required this.size,
    this.brokerCode = '',
    this.brokerDisplayName = '',
  });

  final double size;
  final String brokerCode;
  final String brokerDisplayName;

  static String assetPath({
    String brokerCode = '',
    String brokerDisplayName = '',
  }) {
    final c = brokerCode.trim().toUpperCase();
    final n = brokerDisplayName.trim().toLowerCase();
    if (c.contains('OCEANA') || n.contains('oceana')) {
      return 'assets/icons/brokers/oceana.png';
    }
    return 'assets/icons/brokers/fptrades.png';
  }

  @override
  Widget build(BuildContext context) {
    final path = assetPath(
      brokerCode: brokerCode,
      brokerDisplayName: brokerDisplayName,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFF0A4D8C),
          alignment: Alignment.center,
          child: Text(
            'FP',
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

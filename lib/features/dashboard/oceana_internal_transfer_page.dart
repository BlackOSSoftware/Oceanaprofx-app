import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_badge.dart';

/// Internal Transfer — Trade-Portal rules: Live → Live only, balance + validation.
class OceanaInternalTransferPage extends StatefulWidget {
  const OceanaInternalTransferPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OceanaInternalTransferPage()),
    );
  }

  @override
  State<OceanaInternalTransferPage> createState() =>
      _OceanaInternalTransferPageState();
}

class _OceanaInternalTransferPageState
    extends State<OceanaInternalTransferPage> {
  static const _fieldR = 12.0;
  static const _line = Color(0xFFD0D0D6);
  static const _minAmount = 10.0;
  static const _maxAmount = 50000.0;

  LinkedTradingAccount? _from;
  LinkedTradingAccount? _to;
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _loading = true;

  List<LinkedTradingAccount> get _liveAccounts {
    final list = tradingService.linkedAccounts
        .where((a) => a.isLive && a.id.isNotEmpty && a.status == 'active')
        .toList()
      ..sort((a, b) => a.accountNumber.compareTo(b.accountNumber));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (tradingService.hasUserPortal) {
        await tradingService.refreshLinkedAccounts();
      }
    } catch (_) {}
    if (!mounted) return;
    final list = _liveAccounts;
    setState(() {
      _loading = false;
      if (list.isNotEmpty) _from = list.first;
      if (list.length > 1) _to = list[1];
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  String _title(LinkedTradingAccount a) {
    final plan = a.planName.trim().isEmpty ? 'Live' : a.planName.trim();
    return '${a.accountNumber} · $plan';
  }

  String _balanceLabel(LinkedTradingAccount a) =>
      '\$${formatMoney(a.balance)}';

  Future<void> _pick(bool from) async {
    final list = _liveAccounts;
    if (list.isEmpty) return;
    final current = from ? _from : _to;
    final picked = await showModalBottomSheet<LinkedTradingAccount>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            Text(
              from ? 'Transfer From' : 'Transfer to',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Live accounts only',
              style: TextStyle(
                color: OcColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final a = list[i];
                  final selected = current?.id == a.id;
                  return ListTile(
                    onTap: () => Navigator.pop(ctx, a),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.accountNumber,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        OcBadge(label: 'Live', filled: true),
                      ],
                    ),
                    subtitle: Text(
                      '${a.planName.trim().isEmpty ? 'Standard' : a.planName} · ${_balanceLabel(a)}',
                      style: TextStyle(
                        color: OcColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: selected
                        ? Icon(OcIcons.check, color: OcColors.primary)
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _error = null;
      if (from) {
        _from = picked;
        if (_to?.id == picked.id) {
          final others = list.where((e) => e.id != picked.id).toList();
          _to = others.isEmpty ? null : others.first;
        }
      } else {
        _to = picked;
        if (_from?.id == picked.id) {
          final others = list.where((e) => e.id != picked.id).toList();
          _from = others.isEmpty ? null : others.first;
        }
      }
    });
  }

  String? _validate(double amount) {
    if (_from == null || _to == null) return 'All fields are required.';
    if (_from!.id == _to!.id) {
      return 'From and To accounts cannot be the same.';
    }
    if (amount <= 0) return 'Amount must be greater than zero.';
    final rounded = double.parse(amount.toStringAsFixed(2));
    if (rounded < _minAmount) return 'Minimum \$${_minAmount.toStringAsFixed(0)}.';
    if (rounded > _maxAmount) {
      return 'Maximum \$${_maxAmount.toStringAsFixed(0)}.';
    }
    if (rounded > _from!.balance) return 'Insufficient balance.';
    return null;
  }

  Future<void> _submit() async {
    final raw = _amountCtrl.text.trim();
    if (_from == null || _to == null || raw.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (raw.contains('.') && raw.split('.').last.length > 2) {
      setState(() => _error = 'Max 2 decimal places allowed.');
      return;
    }
    final amount = double.tryParse(raw);
    if (amount == null) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    final err = _validate(amount);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await tradingService.createInternalTransfer(
        fromAccountId: _from!.id,
        toAccountId: _to!.id,
        amount: double.parse(amount.toStringAsFixed(2)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer of \$${formatMoney(amount)} completed',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = _liveAccounts;
    return Scaffold(
      backgroundColor: OcColors.surface,
      appBar: AppBar(
        backgroundColor: OcColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(OcIcons.arrowBack, color: OcColors.text),
        ),
        title: Text(
          'Internal Transfer',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: OcColors.text,
          ),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : live.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No live accounts found.\nOpen a live account to transfer funds.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: OcColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Only live accounts can transfer between each other.',
                                style: TextStyle(
                                  color: OcColors.textMuted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 12),
                              _accountField(
                                hint: 'Transfer From',
                                account: _from,
                                onTap: () => _pick(true),
                              ),
                              SizedBox(height: 14),
                              _accountField(
                                hint: 'Transfer to',
                                account: _to,
                                onTap: () => _pick(false),
                              ),
                              SizedBox(height: 14),
                              _amountField(),
                              if (_from != null) ...[
                                SizedBox(height: 6),
                                Text(
                                  'Available: ${_balanceLabel(_from!)}',
                                  style: TextStyle(
                                    color: OcColors.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              _commentField(),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: OcColors.loss,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: (_busy || _error != null) ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: OcColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              _busy ? 'Transferring…' : 'Transfer Now',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
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

  Widget _accountField({
    required String hint,
    required LinkedTradingAccount? account,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_fieldR),
      child: Container(
        constraints: BoxConstraints(minHeight: 56),
        padding: EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_fieldR),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Expanded(
              child: account == null
                  ? Text(
                      hint,
                      style: TextStyle(
                        color: OcColors.placeholder,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _title(account),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: OcColors.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            OcBadge(label: 'Live', filled: true),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          _balanceLabel(account),
                          style: TextStyle(
                            color: OcColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
            ),
            Icon(OcIcons.chevronDown, size: 18, color: OcColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _onAmountChanged(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    final amount = double.tryParse(text);
    if (amount == null) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    String? err;
    if (amount <= 0) {
      err = 'Amount must be greater than zero.';
    } else if (amount < _minAmount) {
      err = 'Minimum \$${_minAmount.toStringAsFixed(0)}.';
    } else if (amount > _maxAmount) {
      err = 'Maximum \$${_maxAmount.toStringAsFixed(0)}.';
    } else if (_from != null && amount > _from!.balance) {
      err = 'Insufficient balance.';
    }
    setState(() => _error = err);
  }

  Widget _amountField() {
    return TextField(
      controller: _amountCtrl,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_AmountInputFormatter()],
      onChanged: _onAmountChanged,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Amount',
        hintText: '0.00',
        hintStyle: TextStyle(
          color: OcColors.placeholder,
          fontWeight: FontWeight.w500,
        ),
        prefixText: '\$ ',
        prefixStyle: TextStyle(
          color: OcColors.text,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        labelStyle: TextStyle(
          color: OcColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldR),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldR),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldR),
          borderSide: BorderSide(color: OcColors.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _commentField() {
    return TextField(
      controller: _commentCtrl,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Comment (optional)',
        hintStyle: TextStyle(color: OcColors.placeholder),
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldR),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldR),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldR),
          borderSide: BorderSide(color: OcColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

/// Blocks `00005`, multiple dots, and >2 decimal places.
class _AmountInputFormatter extends TextInputFormatter {
  const _AmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(',', '').trim();
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    if (text == '.') {
      text = '0.';
    }
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return oldValue;
    }
    if ('.'.allMatches(text).length > 1) {
      return oldValue;
    }

    String intPart;
    String? decPart;
    if (text.contains('.')) {
      final parts = text.split('.');
      intPart = parts[0];
      decPart = parts.length > 1 ? parts[1] : '';
      if (decPart.length > 2) return oldValue;
    } else {
      intPart = text;
      decPart = null;
    }

    // Strip leading zeros: 0005 → 5, keep single 0 / 0.xx
    if (intPart.length > 1) {
      intPart = intPart.replaceFirst(RegExp(r'^0+'), '');
      if (intPart.isEmpty) intPart = '0';
    }

    final next = decPart == null ? intPart : '$intPart.$decPart';
    return TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}

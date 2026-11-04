import 'package:flutter/material.dart';

import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

/// Change Leverage — SS layout, Oceana brand.
class OceanaChangeLeveragePage extends StatefulWidget {
  const OceanaChangeLeveragePage({
    super.key,
    required this.accountNumber,
    this.initial = '1:500',
  });

  final String accountNumber;
  final String initial;

  static Future<void> open(
    BuildContext context, {
    required String accountNumber,
    String initial = '1:500',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OceanaChangeLeveragePage(
          accountNumber: accountNumber,
          initial: initial,
        ),
      ),
    );
  }

  @override
  State<OceanaChangeLeveragePage> createState() =>
      _OceanaChangeLeveragePageState();
}

class _OceanaChangeLeveragePageState extends State<OceanaChangeLeveragePage> {
  static const _options = ['1:100', '1:150', '1:200', '1:300', '1:400', '1:500'];
  late String _leverage = widget.initial;
  bool _busy = false;

  Future<void> _pick() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFFF5F5F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select Leverage',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(OcIcons.x, size: 20),
                      ),
                    ],
                  ),
                ),
                for (final o in _options)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, o),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: o == _leverage
                            ? OcColors.primarySoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              o,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: o == _leverage
                                    ? OcColors.primary
                                    : OcColors.text,
                              ),
                            ),
                          ),
                          if (o == _leverage)
                            Icon(
                              OcIcons.check,
                              size: 18,
                              color: OcColors.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _leverage = picked);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await Future<void>.delayed(Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Leverage changed to $_leverage')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'Change Leverage',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: OcColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: OcColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        OcIcons.user,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Account: ${widget.accountNumber}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22),
              Text(
                'Select Leverage',
                style: TextStyle(
                  color: OcColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: _pick,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OcColors.borderStrong),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _leverage,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Icon(
                        OcIcons.chevronDown,
                        size: 18,
                        color: OcColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: OcColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _busy ? 'Saving…' : 'Change Leverage',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

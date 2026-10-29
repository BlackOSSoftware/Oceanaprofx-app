import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import 'fp_trades_page.dart';
import 'metaquotes_page.dart';

/// Brokers screen shown after tapping "Add Trading Account":
/// search field + MetaQuotes + live brokers from `/v1/brokers/public`.
class BrokersPage extends StatefulWidget {
  const BrokersPage({super.key});

  @override
  State<BrokersPage> createState() => _BrokersPageState();
}

class _BrokersPageState extends State<BrokersPage> {
  String _query = '';
  List<PublicBroker> _brokers = const [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load([String q = '']) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await tradingService.searchPublicBrokers(q: q);
      if (!mounted) return;
      setState(() {
        _brokers = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiConfigSafe.message(e);
        _loading = false;
        _brokers = const [];
      });
    }
  }

  void _onQueryChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _load(v);
    });
  }

  bool get _showMetaQuotes {
    final q = _query.trim().toLowerCase();
    return q.isEmpty || 'metaquotes ltd.'.contains(q) || 'metaquotes'.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MtColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back,
                      size: 26,
                      color: MtColors.text,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Brokers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: MtColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Scan',
                    onPressed: () {},
                    icon: Image.asset(
                      'assets/icons/qr_code.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.search, size: 28, color: MtColors.icon),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      onChanged: _onQueryChanged,
                      style: TextStyle(fontSize: 18, color: MtColors.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Find broker',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: MtColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: MtColors.line),
            if (_loading)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (_showMetaQuotes) ...[
                    _BrokerTile(
                      leading: Image.asset(
                        'assets/icons/mt5_logo.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                      ),
                      title: 'MetaQuotes Ltd.',
                      subtitle: 'MetaQuotes',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MetaQuotesPage(),
                        ),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: MtColors.line),
                  ],
                  for (final b in _brokers) ...[
                    _BrokerTile(
                      leading: FpLogo(
                        size: 42,
                        brokerCode: b.code,
                        brokerDisplayName: b.displayName,
                      ),
                      title: b.displayName,
                      subtitle: b.subtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FpTradesPage(
                            brokerDisplayName: b.displayName,
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: MtColors.line),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: MtColors.textSecondary,
                        ),
                      ),
                    )
                  else if (!_loading &&
                      _brokers.isEmpty &&
                      !_showMetaQuotes)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Text(
                        'No brokers match “$_query”',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: MtColors.textSecondary,
                        ),
                      ),
                    )
                  else if (!_loading && _brokers.isEmpty && _query.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.manage_search,
                            size: 120,
                            color: MtColors.line,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Use search to find a company',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              color: MtColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'This application may feature brokerage companies which\n'
                            'may not be regulated in your country. Exercise caution and\n'
                            'responsibility before opening an account with any brokerage\n'
                            'company.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: MtColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFFF2F2F2),
              padding: EdgeInsets.only(
                top: 18,
                bottom: 18 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Text(
                "CAN'T FIND YOUR BROKER?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MtColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avoid importing api_config just for one scrub helper here.
abstract final class ApiConfigSafe {
  static String message(Object e) {
    final s = '$e'.trim();
    if (s.isEmpty) return 'Unable to load brokers';
    return s.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class _BrokerTile extends StatelessWidget {
  const _BrokerTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: MtColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 15, color: MtColors.accent),
                  ),
                ],
              ),
            ),
            Icon(Icons.info_outline, size: 26, color: MtColors.icon),
          ],
        ),
      ),
    );
  }
}

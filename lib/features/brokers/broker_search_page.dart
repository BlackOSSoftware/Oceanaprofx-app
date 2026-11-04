import 'package:flutter/material.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_primary_button.dart';
import '../auth/welcome_page.dart';

class BrokerSearchPage extends StatefulWidget {
  const BrokerSearchPage({super.key});

  @override
  State<BrokerSearchPage> createState() => _BrokerSearchPageState();
}

class _BrokerSearchPageState extends State<BrokerSearchPage> {
  final _query = TextEditingController();
  List<PublicBroker> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final text = q.trim();
    if (text.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await tradingService.searchPublicBrokers(q: text);
      if (!mounted) return;
      setState(() => _results = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _contactSupport() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Contact Support',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Please contact our support team to add your broker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: TextStyle(
                color: OcColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openWelcome() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WelcomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empty = _query.text.trim().isEmpty && _results.isEmpty;

    return Scaffold(
      backgroundColor: OcColors.bg,
      appBar: AppBar(
        backgroundColor: OcColors.bg,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(OcIcons.chevronLeft),
        ),
        title: const Text('Broker'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Find broker...',
                prefixIcon: Icon(
                  OcIcons.search,
                  color: OcColors.textMuted,
                ),
                filled: true,
                fillColor: OcColors.surface,
              ),
            ),
          ),
          Expanded(
            child: empty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Spacer(),
                        Icon(
                          OcIcons.listFilter,
                          size: 72,
                          color: OcColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Use search to find a company',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OcColors.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Be careful: some companies may not be regulated. '
                          'Oceana may not possess complete and updated information '
                          'about every broker. Always verify licensing yourself.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: OcColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              'No brokers found',
                              style: TextStyle(
                                color: OcColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final b = _results[i];
                              return Material(
                                color: OcColors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: OcColors.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: ColoredBox(
                                      color: const Color(0xFFF5F5F7),
                                      child: Image.asset(
                                        'assets/brand/oceana_mark_v3.png',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    b.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(b.subtitle),
                                  onTap: _openWelcome,
                                ),
                              );
                            },
                          ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: OcPrimaryButton(
              label: "Can't Find Your Broker?",
              onPressed: _contactSupport,
            ),
          ),
        ],
      ),
    );
  }
}

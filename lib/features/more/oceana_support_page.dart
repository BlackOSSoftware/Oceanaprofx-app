import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

/// Support Center — Trade-Portal Raise a Ticket UI.
class OceanaSupportPage extends StatefulWidget {
  const OceanaSupportPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OceanaSupportPage()),
    );
  }

  @override
  State<OceanaSupportPage> createState() => _OceanaSupportPageState();
}

class _OceanaSupportPageState extends State<OceanaSupportPage> {
  static const _issues = <(String, String)>[
    ('deposit', 'Deposit issue'),
    ('withdraw', 'Withdrawal issue'),
    ('trading', 'Trading issue'),
    ('other', 'Other issue'),
  ];

  String? _issue;
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_issue == null || _issue!.isEmpty) {
      setState(() => _error = 'Please select issue type.');
      return;
    }
    final msg = _message.text.trim();
    if (msg.isEmpty) {
      setState(() => _error = 'Please enter issue description.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      Map<String, dynamic> profile = tradingService.userProfile ?? {};
      if (tradingService.hasUserPortal && profile.isEmpty) {
        try {
          profile = await tradingService.fetchUserProfile(force: true);
        } catch (_) {}
      }

      final name = '${profile['name'] ?? ''}'.trim().isNotEmpty
          ? '${profile['name']}'.trim()
          : (tradingService.session?.name.trim().isNotEmpty == true
              ? tradingService.session!.name.trim()
              : 'User');
      final email = '${profile['email'] ?? ''}'.trim().isNotEmpty
          ? '${profile['email']}'.trim()
          : (tradingService.userPortal?.email ?? '');
      final phone = '${profile['phone'] ?? ''}'.trim();

      if (email.isEmpty || phone.isEmpty) {
        setState(() {
          _busy = false;
          _error =
              'Profile data missing. Please update phone/email in Verify account first.';
        });
        return;
      }

      final title = _issues
          .firstWhere((e) => e.$1 == _issue, orElse: () => ('', 'Support issue'))
          .$2;

      await tradingService.createSupportInquiry(
        name: name,
        email: email,
        phone: phone,
        title: title,
        description: msg,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket submitted successfully.')),
      );
      setState(() {
        _busy = false;
        _issue = null;
        _message.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _email() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@oceanaprofx.com',
      queryParameters: {'subject': 'Support request'},
    );
    await launchUrl(uri);
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
          'Support Center',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'Need help? Contact us or raise a support ticket.',
            style: TextStyle(
              color: OcColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          _contactCard(
            icon: OcIcons.megaphone,
            iconBg: const Color(0xFFE3F2FD),
            iconFg: const Color(0xFF1565C0),
            title: 'Email Support',
            body: "We'll respond within 24 hours.",
            actionLabel: 'Email us →',
            onAction: _email,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            decoration: BoxDecoration(
              color: OcColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OcColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(OcIcons.info, color: OcColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Raise a Ticket',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: OcColors.text,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                InkWell(
                  onTap: () => _pickIssue(),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Issue Type',
                      labelStyle: TextStyle(
                        color: OcColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: Icon(
                        OcIcons.chevronDown,
                        size: 18,
                        color: OcColors.textMuted,
                      ),
                    ),
                    child: Text(
                      _issue == null
                          ? 'Select issue'
                          : _issues
                              .firstWhere(
                                (e) => e.$1 == _issue,
                                orElse: () => ('', 'Select issue'),
                              )
                              .$2,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _issue == null
                            ? OcColors.placeholder
                            : OcColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _message,
                  maxLines: 5,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Explain your issue in detail...',
                    hintStyle: TextStyle(color: OcColors.placeholder),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: OcColors.loss,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: OcColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(OcIcons.share2, size: 16),
                    label: Text(
                      _busy ? 'Submitting…' : 'Submit Ticket',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _tip(
            'Before submitting',
            'Select the correct issue type and include your account number in the message for faster resolution.',
          ),
          const SizedBox(height: 8),
          _tip(
            'Response time',
            'Tickets are usually reviewed within 1–12 hours depending on volume.',
          ),
          const SizedBox(height: 8),
          _tip(
            'Priority cases',
            'Withdrawal and trading issues are handled with high priority.',
          ),
        ],
      ),
    );
  }

  Future<void> _pickIssue() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Select Issue Type',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final i in _issues)
              ListTile(
                title: Text(
                  i.$2,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: _issue == i.$1
                    ? const Icon(OcIcons.check, color: OcColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, i.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _issue = picked;
      _error = null;
    });
  }

  Widget _contactCard({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconFg, size: 20),
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: OcColors.textSecondary,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: OcColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tip(String title, String body) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcColors.primarySoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
          SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: OcColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

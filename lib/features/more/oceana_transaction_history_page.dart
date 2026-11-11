import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

enum _Period { allTime, today, lastWeek, thisMonth, custom }

enum _TxFilter { all, deposit, withdrawal, transfer, other }

/// Transaction History — Deposit / Withdrawal / Internal Transfer (Tenax SS).
class OceanaTransactionHistoryPage extends StatefulWidget {
  const OceanaTransactionHistoryPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OceanaTransactionHistoryPage()),
    );
  }

  @override
  State<OceanaTransactionHistoryPage> createState() =>
      _OceanaTransactionHistoryPageState();
}

class _OceanaTransactionHistoryPageState
    extends State<OceanaTransactionHistoryPage> {
  static const _moneyTypes = {
    'DEPOSIT',
    'WITHDRAWAL',
    'INTERNAL_TRANSFER_IN',
    'INTERNAL_TRANSFER_OUT',
    'BONUS_MANUAL',
    'BONUS',
    'BONUS_CREDIT_IN',
    'BONUS_CREDIT_OUT',
    'TRADABLE_FUND',
  };

  static const _otherTypes = {
    'BONUS_MANUAL',
    'BONUS',
    'BONUS_CREDIT_IN',
    'BONUS_CREDIT_OUT',
    'TRADABLE_FUND',
  };

  _Period _period = _Period.allTime;
  _TxFilter _filter = _TxFilter.all;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _loading = true;
  String? _error;
  List<_TxItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime?, DateTime?) _dateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      _Period.allTime => (null, null),
      _Period.today => (today, today),
      _Period.lastWeek => (today.subtract(const Duration(days: 7)), today),
      _Period.thisMonth => (DateTime(today.year, today.month, 1), today),
      _Period.custom => (
          _customStart == null
              ? null
              : DateTime(_customStart!.year, _customStart!.month, _customStart!.day),
          _customEnd == null
              ? null
              : DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day),
        ),
    };
  }

  String? _ymd(DateTime? d) {
    if (d == null) return null;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!tradingService.hasUserPortal) {
        throw ApiException('Sign in with email to view transaction history');
      }
      try {
        await tradingService.refreshLinkedAccounts();
      } catch (_) {}
      final (from, to) = _dateRange();
      final apiType = switch (_filter) {
        _TxFilter.deposit => 'DEPOSIT',
        _TxFilter.withdrawal => 'WITHDRAWAL',
        _TxFilter.transfer || _TxFilter.all || _TxFilter.other => null,
      };

      List<Map<String, dynamic>> rows;
      if (_filter == _TxFilter.transfer) {
        final a = await tradingService.fetchTransactions(
          page: 1,
          limit: 100,
          type: 'INTERNAL_TRANSFER_IN',
          fromDate: _ymd(from),
          toDate: _ymd(to),
        );
        final b = await tradingService.fetchTransactions(
          page: 1,
          limit: 100,
          type: 'INTERNAL_TRANSFER_OUT',
          fromDate: _ymd(from),
          toDate: _ymd(to),
        );
        rows = [...a.data, ...b.data];
        rows.sort((x, y) {
          final ax = DateTime.tryParse('${x['createdAt'] ?? ''}') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bx = DateTime.tryParse('${y['createdAt'] ?? ''}') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bx.compareTo(ax);
        });
      } else {
        final res = await tradingService.fetchTransactions(
          page: 1,
          limit: 100,
          type: apiType,
          fromDate: _ymd(from),
          toDate: _ymd(to),
        );
        rows = res.data;
      }

      final linkedById = <String, String>{
        for (final a in tradingService.linkedAccounts)
          if (a.id.isNotEmpty && a.accountNumber.trim().isNotEmpty)
            a.id: a.accountNumber.trim(),
      };
      final allowTypes =
          _filter == _TxFilter.other ? _otherTypes : _moneyTypes;
      final items = <_TxItem>[
        for (final j in rows)
          if (allowTypes.contains('${j['type'] ?? ''}'.toUpperCase()))
            _TxItem.fromJson(j, linkedById: linkedById),
      ];
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
        _items = [];
      });
    }
  }

  Future<void> _pickCustomDate({required bool start}) async {
    final now = DateTime.now();
    final initial = start
        ? (_customStart ?? now)
        : (_customEnd ?? _customStart ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: OcColors.primary,
              onPrimary: Colors.white,
              surface: OcColors.surface,
              onSurface: OcColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _customStart = picked;
        if (_customEnd != null && _customEnd!.isBefore(picked)) {
          _customEnd = picked;
        }
      } else {
        _customEnd = picked;
        if (_customStart != null && _customStart!.isAfter(picked)) {
          _customStart = picked;
        }
      }
    });
    await _load();
  }

  Future<void> _openTypeSheet() async {
    final picked = await showModalBottomSheet<_TxFilter>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        Widget row(_TxFilter f, String label) {
          final on = _filter == f;
          return InkWell(
            onTap: () => Navigator.pop(ctx, f),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              color: on ? OcColors.primarySoft : Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: on ? OcColors.primary : OcColors.text,
                      ),
                    ),
                  ),
                  if (on)
                    Icon(OcIcons.check, color: OcColors.primary, size: 18),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Select Transaction Type',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              row(_TxFilter.all, 'All'),
              row(_TxFilter.deposit, 'Deposit'),
              row(_TxFilter.withdrawal, 'Withdrawal'),
              row(_TxFilter.transfer, 'Transfer'),
              row(_TxFilter.other, 'Other'),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _filter = picked);
    await _load();
  }

  String get _filterLabel => switch (_filter) {
        _TxFilter.all => 'All',
        _TxFilter.deposit => 'Deposit',
        _TxFilter.withdrawal => 'Withdrawal',
        _TxFilter.transfer => 'Transfer',
        _TxFilter.other => 'Other',
      };

  String _periodLabel(_Period p) => switch (p) {
        _Period.allTime => 'All Time',
        _Period.today => 'Today',
        _Period.lastWeek => 'Last week',
        _Period.thisMonth => 'This month',
        _Period.custom => 'Custom',
      };

  String _dateBtnLabel(DateTime? d, String placeholder) {
    if (d == null) return placeholder;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OcColors.surface,
      appBar: AppBar(
        backgroundColor: OcColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(OcIcons.arrowBack, color: OcColors.text),
        ),
        title: Text(
          'Transaction History',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: OcColors.text,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                _periodBox(),
                if (_period == _Period.custom) ...[
                  SizedBox(height: 10),
                  _customDatesBox(),
                ],
                SizedBox(height: 10),
                _typeField(),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: OcColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Text(
                              'No transactions found',
                              style: TextStyle(
                                color: OcColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: OcColors.primary,
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _TxCard(item: _items[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _periodBox() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcColors.primaryMuted, width: 1.2),
      ),
      child: Column(
        children: [
          for (final p in _Period.values) ...[
            if (p != _Period.values.first)
              const Divider(height: 1, color: Color(0xFFE8E8F0)),
            InkWell(
              onTap: () async {
                setState(() => _period = p);
                if (p != _Period.custom) await _load();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _periodLabel(p),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: _period == p
                              ? OcColors.primary
                              : OcColors.text,
                        ),
                      ),
                    ),
                    if (_period == p)
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
        ],
      ),
    );
  }

  Widget _customDatesBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcColors.primaryMuted, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Start Date:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _pickCustomDate(start: true),
                style: TextButton.styleFrom(
                  foregroundColor: OcColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: Text(
                  _dateBtnLabel(_customStart, 'Select start date'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'End Date:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _pickCustomDate(start: false),
                style: TextButton.styleFrom(
                  foregroundColor: OcColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: Text(
                  _dateBtnLabel(_customEnd, 'Select end date'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeField() {
    return InkWell(
      onTap: _openTypeSheet,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Transaction Type',
          labelStyle: TextStyle(
            color: OcColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: OcColors.primary, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: OcColors.primary, width: 1.2),
          ),
          suffixIcon: Icon(
            OcIcons.chevronDown,
            size: 18,
            color: OcColors.textMuted,
          ),
        ),
        child: Text(
          _filterLabel,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}

class _TxItem {
  const _TxItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.accountNumber,
    required this.referenceCode,
    required this.remark,
  });

  final String id;
  final String type;
  final double amount;
  final String status;
  final DateTime? createdAt;
  final String accountNumber;
  final String referenceCode;
  final String remark;

  bool get isCredit =>
      type == 'DEPOSIT' ||
      type == 'INTERNAL_TRANSFER_IN' ||
      type == 'BONUS_MANUAL' ||
      type == 'BONUS' ||
      type == 'BONUS_CREDIT_IN' ||
      type == 'TRADABLE_FUND';

  String get title => switch (type) {
        'DEPOSIT' => 'Deposit',
        'WITHDRAWAL' => 'Withdrawal',
        'INTERNAL_TRANSFER_IN' => 'Transfer In',
        'INTERNAL_TRANSFER_OUT' => 'Transfer Out',
        'BONUS_MANUAL' || 'BONUS' || 'BONUS_CREDIT_IN' => 'Bonus Credit',
        'BONUS_CREDIT_OUT' => 'Bonus Debit',
        'TRADABLE_FUND' => 'Fund Transfer',
        _ => type,
      };

  String get statusLabel {
    final s = status.toUpperCase();
    if (s == 'SUCCESS') return 'Approved';
    if (s == 'FAILED') return 'Rejected';
    if (s == 'PENDING') return 'Pending';
    return status;
  }

  factory _TxItem.fromJson(
    Map<String, dynamic> j, {
    Map<String, String> linkedById = const {},
  }) {
    final type = '${j['type'] ?? ''}'.toUpperCase();
    final id = '${j['_id'] ?? j['id'] ?? ''}';
    final ref = '${j['referenceId'] ?? ''}'.trim();
    final short = (ref.isNotEmpty ? ref : id);
    final codeTail = short.length <= 4
        ? short
        : short.substring(short.length - 4).toUpperCase();
    final prefix = switch (type) {
      'DEPOSIT' => 'DEP',
      'WITHDRAWAL' => 'WDR',
      'INTERNAL_TRANSFER_IN' => 'TIN',
      'INTERNAL_TRANSFER_OUT' => 'TOUT',
      'BONUS_MANUAL' || 'BONUS' || 'BONUS_CREDIT_IN' => 'BNS',
      'BONUS_CREDIT_OUT' => 'BND',
      'TRADABLE_FUND' => 'FND',
      _ => 'TXN',
    };

    var accountNumber = '${j['accountNumber'] ?? ''}'.trim();
    if (accountNumber.isEmpty) {
      final acc = j['account'];
      if (acc is Map) {
        accountNumber =
            '${acc['account_number'] ?? acc['accountNumber'] ?? ''}'.trim();
      }
    }
    if (accountNumber.isEmpty) {
      final accountId = '${j['accountId'] ?? j['account'] ?? ''}'.trim();
      accountNumber = linkedById[accountId] ?? '';
    }

    return _TxItem(
      id: id,
      type: type,
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      status: '${j['status'] ?? 'SUCCESS'}',
      createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}'),
      accountNumber: accountNumber,
      referenceCode: '$prefix-$codeTail',
      remark: '${j['remark'] ?? ''}'.trim(),
    );
  }
}

class _TxCard extends StatelessWidget {
  const _TxCard({required this.item});
  final _TxItem item;

  Color get _accent => item.isCredit ? OcColors.profit : OcColors.loss;
  Color get _soft =>
      item.isCredit ? OcColors.depositBg : OcColors.withdrawBg;

  IconData get _icon => switch (item.type) {
        'DEPOSIT' => OcIcons.arrowDownToLine,
        'WITHDRAWAL' => OcIcons.arrowUpRight,
        'INTERNAL_TRANSFER_IN' => OcIcons.arrowLeftRight,
        'INTERNAL_TRANSFER_OUT' => OcIcons.arrowLeftRight,
        'BONUS_MANUAL' ||
        'BONUS' ||
        'BONUS_CREDIT_IN' ||
        'BONUS_CREDIT_OUT' =>
          OcIcons.badgeCheck,
        'TRADABLE_FUND' => OcIcons.wallet,
        _ => OcIcons.circleDollarSign,
      };

  String _when(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${d.day} ${months[d.month - 1]}, $hour12:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: OcColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _soft,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: _accent, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.referenceCode,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: OcColors.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      item.accountNumber.isNotEmpty
                          ? '${item.title} · ${item.accountNumber}'
                          : item.title,
                      style: TextStyle(
                        color: OcColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${formatMoney(item.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: _accent,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _when(item.createdAt),
                    style: TextStyle(
                      color: OcColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(item.statusLabel, outline: _accent),
                    if (item.remark.isNotEmpty)
                      _chip(item.remark, outline: OcColors.borderStrong),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(OcIcons.download, size: 18, color: OcColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {required Color outline}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outline.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        softWrap: false,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: outline == OcColors.borderStrong
              ? OcColors.textSecondary
              : outline,
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import 'symbol_flags.dart';

/// Add instruments — bottom sheet matching Tenax screenshot.
class OceanaAddSymbolsPage extends StatefulWidget {
  const OceanaAddSymbolsPage({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final h = mq.size.height;
        final topInset = mq.padding.top;
        final keyboard = mq.viewInsets.bottom;
        // Fixed sheet height — keyboard must not crush the list.
        final openTop = topInset + h * 0.10;
        final sheetH = h - openTop;
        // ModalBottomSheet adds viewInsets as bottom padding; pull top
        // up by the same amount so height stays constant while typing.
        final top = (openTop - keyboard).clamp(0.0, openTop);
        return Padding(
          padding: EdgeInsets.only(top: top),
          child: SizedBox(
            height: sheetH,
            child: MediaQuery.removeViewInsets(
              removeBottom: true,
              context: ctx,
              child: const OceanaAddSymbolsPage(),
            ),
          ),
        );
      },
    );
  }

  @override
  State<OceanaAddSymbolsPage> createState() => _OceanaAddSymbolsPageState();
}

class _OceanaAddSymbolsPageState extends State<OceanaAddSymbolsPage> {
  /// UI label → backend segment (segments API uses INDICES, not INDEX).
  static const _chips = <(String, String)>[
    ('All', ''),
    ('Currency', 'FOREX'),
    ('Metals', 'METAL'),
    ('Indices', 'INDICES'),
    ('Energies', 'ENERGY'),
  ];

  final _ctrl = TextEditingController();
  final _forced = <String, bool>{};
  String _chip = 'All';
  String _query = '';
  List<WatchSymbol> _items = const [];
  bool _busy = true;
  Timer? _debounce;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() => _busy = true);
    try {
      List<WatchSymbol> next;
      if (_query.isNotEmpty) {
        next = await tradingService.searchInstruments(_query);
      } else {
        final seg = _chips.firstWhere((c) => c.$1 == _chip).$2;
        if (seg.isEmpty) {
          final parts = await Future.wait([
            tradingService.segmentInstruments('FOREX'),
            tradingService.segmentInstruments('METAL'),
            tradingService.segmentInstruments('INDICES'),
            tradingService.segmentInstruments('ENERGY'),
          ]);
          final seen = <String>{};
          next = [
            for (final list in parts)
              for (final w in list)
                if (seen.add(w.code)) w,
          ];
        } else {
          next = await tradingService.segmentInstruments(seg);
        }
      }
      next = List.of(next)..sort((a, b) => a.code.compareTo(b.code));
      if (!mounted || seq != _seq) return;
      setState(() => _items = next);
    } catch (_) {
      if (mounted && seq == _seq) setState(() => _items = const []);
    } finally {
      if (mounted && seq == _seq) setState(() => _busy = false);
    }
  }

  void _onQuery(String v) {
    _query = v.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _load);
  }

  bool _isAdded(WatchSymbol w) {
    final f = _forced[w.code];
    if (f != null) return f;
    if (w.isAdded) return true;
    return tradingService.watchlist.any((x) => x.code == w.code);
  }

  void _flipLocal(WatchSymbol w, bool toAdded) {
    _forced[w.code] = toAdded;
    setState(() {
      _items = [
        for (final x in _items)
          x.code == w.code
              ? WatchSymbol(
                  code: x.code,
                  name: x.name,
                  segment: x.segment,
                  isAdded: toAdded,
                )
              : x,
      ];
    });
  }

  Future<void> _toggle(WatchSymbol w) async {
    final added = _isAdded(w);
    _flipLocal(w, !added);
    try {
      if (added) {
        await tradingService.removeWatchlist(w.code);
      } else {
        await tradingService.addWatchlist(w.code, w.name);
        tradingService.subscribe(w.code);
      }
      unawaited(tradingService.refreshWatchlist());
    } catch (e) {
      if (!mounted) return;
      _flipLocal(w, added);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiConfig.userFacingError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: OcColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFFD0D0D6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          // Back + clean search (screenshot: no heavy grey box).
          Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    OcIcons.arrowBack,
                    color: OcColors.text,
                    size: 22,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onChanged: _onQuery,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: OcColors.text,
                    ),
                    cursorColor: OcColors.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      hintText: 'Search instruments...',
                      hintStyle: TextStyle(
                        color: Color(0xFFB0B0B8),
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _ctrl.clear();
                      _onQuery('');
                    },
                    icon: Icon(
                      OcIcons.x,
                      size: 18,
                      color: OcColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          // Slim filter chips — tight vertical padding.
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final label = _chips[i].$1;
                final on = _chip == label;
                return GestureDetector(
                  onTap: () {
                    if (_chip == label) return;
                    setState(() => _chip = label);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? OcColors.primary : OcColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: OcColors.primary,
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: on ? Colors.white : OcColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: _busy
                ? Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          'No instruments found',
                          style: TextStyle(color: OcColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          thickness: 0.6,
                          color: OcColors.border,
                        ),
                        itemBuilder: (context, i) {
                          final w = _items[i];
                          final added = _isAdded(w);
                          return InkWell(
                            onTap: () => _toggle(w),
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 11),
                              child: Row(
                                children: [
                                  SymbolFlagTile(symbol: w.code, size: 42),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          w.code,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: OcColors.text,
                                            height: 1.15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          segmentLabel(w.segment),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF9A9AA3),
                                            fontWeight: FontWeight.w400,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Screenshot: empty grey ring + / filled brand ✓
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: added
                                          ? OcColors.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: added
                                            ? OcColors.primary
                                            : const Color(0xFFC8C8CE),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      added ? Icons.check_rounded : Icons.add,
                                      size: added ? 15 : 16,
                                      color: added
                                          ? Colors.white
                                          : const Color(0xFF9A9AA3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

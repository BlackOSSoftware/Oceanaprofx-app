import 'package:flutter/material.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../quotes/symbol_flags.dart';

/// Chart symbol picker — SS UI: search + flag + name only (no bid/ask).
class OceanaSymbolPickerPage extends StatefulWidget {
  const OceanaSymbolPickerPage({
    super.key,
    required this.selected,
  });

  final String selected;

  static Future<String?> open(
    BuildContext context, {
    required String selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Avoid animating the chart/WebView route under the sheet.
      enableDrag: true,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => OceanaSymbolPickerPage(selected: selected),
    );
  }

  @override
  State<OceanaSymbolPickerPage> createState() => _OceanaSymbolPickerPageState();
}

class _OceanaSymbolPickerPageState extends State<OceanaSymbolPickerPage> {
  final _search = TextEditingController();
  late final List<String> _all;
  double? _sheetH;
  String _query = '';
  List<String> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _all = [for (final w in tradingService.watchlist) w.code];
    _filtered = _all;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture once — keyboard viewInsets must not resize this sheet.
    _sheetH ??= MediaQuery.sizeOf(context).height * 0.78;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    final q = v.trim().toLowerCase();
    if (q == _query) return;
    _query = q;
    final next = q.isEmpty
        ? _all
        : [for (final c in _all) if (c.toLowerCase().contains(q)) c];
    setState(() => _filtered = next);
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard opens without resizing the list (stops jank over WebView).
    final codes = _filtered;

    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: SizedBox(
        height: _sheetH ?? MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: OcColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      OcIcons.arrowBack,
                      color: OcColors.text,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      autofocus: false,
                      onChanged: _onQuery,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: OcColors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search instruments...',
                        hintStyle: TextStyle(
                          color: OcColors.placeholder,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: OcColors.border),
            Expanded(
              child: codes.isEmpty
                  ? Center(
                      child: Text(
                        'No symbols found',
                        style: TextStyle(
                          color: OcColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: codes.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 0.7,
                        color: OcColors.border,
                      ),
                      itemBuilder: (context, i) {
                        final code = codes[i];
                        return InkWell(
                          onTap: () => Navigator.pop(context, code),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: OcColors.primarySoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SymbolFlagPair(
                                    symbol: code,
                                    size: 34,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Text(
                                  code,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: OcColors.text,
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
      ),
    );
  }
}

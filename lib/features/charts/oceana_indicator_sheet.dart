import 'package:flutter/material.dart';

import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import 'chart_indicators.dart';

/// TradingView-style Indicators panel — search + toggle list over chart.
Future<void> showOceanaIndicatorsSheet(
  BuildContext context, {
  required Set<String> activeIds,
  required ValueChanged<Set<String>> onChanged,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Indicators',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, a1, a2) {
      return _IndicatorsOverlay(
        activeIds: {...activeIds},
        onChanged: onChanged,
      );
    },
  );
}

class _IndicatorsOverlay extends StatefulWidget {
  const _IndicatorsOverlay({
    required this.activeIds,
    required this.onChanged,
  });

  final Set<String> activeIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_IndicatorsOverlay> createState() => _IndicatorsOverlayState();
}

class _IndicatorsOverlayState extends State<_IndicatorsOverlay> {
  late final Set<String> _active = {...widget.activeIds};
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ChartIndicator> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return ChartIndicator.catalog;
    return [
      for (final i in ChartIndicator.catalog)
        if (i.label.toLowerCase().contains(q) ||
            i.subtitle.toLowerCase().contains(q) ||
            i.study.toLowerCase().contains(q))
          i,
    ];
  }

  void _toggle(ChartIndicator ind) {
    setState(() {
      if (_active.contains(ind.id)) {
        _active.remove(ind.id);
      } else {
        _active.add(ind.id);
      }
    });
    widget.onChanged({..._active});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 100, 10, 0),
          child: Material(
            color: OcColors.surface,
            elevation: 10,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: size.height * 0.5,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Indicators',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: OcColors.text,
                            ),
                          ),
                        ),
                        if (_active.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() => _active.clear());
                              widget.onChanged({});
                            },
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                color: OcColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(OcIcons.x, size: 22),
                          color: OcColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(
                          color: OcColors.placeholder,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(
                          OcIcons.search,
                          size: 20,
                          color: OcColors.textMuted,
                        ),
                        filled: true,
                        fillColor: OcColors.bg,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'SCRIPT NAME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: OcColors.textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final ind = _filtered[i];
                        final on = _active.contains(ind.id);
                        return InkWell(
                          onTap: () => _toggle(ind),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ind.label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: on
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: on
                                              ? OcColors.primary
                                              : OcColors.text,
                                        ),
                                      ),
                                      if (ind.subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          ind.subtitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: OcColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (on)
                                  Icon(
                                    OcIcons.check,
                                    size: 18,
                                    color: OcColors.primary,
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
          ),
        ),
      ),
    );
  }
}

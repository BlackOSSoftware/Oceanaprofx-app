import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import 'chart_indicators.dart';

/// Indicators panel — add multiple MAs, edit length/colour per instance.
Future<void> showOceanaIndicatorsSheet(
  BuildContext context, {
  required List<ChartIndicatorConfig> active,
  required ValueChanged<List<ChartIndicatorConfig>> onChanged,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Indicators',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, a1, a2) {
      return _IndicatorsOverlay(
        active: [for (final c in active) c.copy()],
        onChanged: onChanged,
      );
    },
  );
}

class _IndicatorsOverlay extends StatefulWidget {
  const _IndicatorsOverlay({
    required this.active,
    required this.onChanged,
  });

  final List<ChartIndicatorConfig> active;
  final ValueChanged<List<ChartIndicatorConfig>> onChanged;

  @override
  State<_IndicatorsOverlay> createState() => _IndicatorsOverlayState();
}

class _IndicatorsOverlayState extends State<_IndicatorsOverlay> {
  late final List<ChartIndicatorConfig> _active = [...widget.active];
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
            i.type.toLowerCase().contains(q))
          i,
    ];
  }

  void _emit() => widget.onChanged([for (final c in _active) c.copy()]);

  void _add(ChartIndicator kind) {
    final existing = _active.where((c) => c.type == kind.type).toList();
    if (!kind.allowMultiple && existing.isNotEmpty) {
      _openSettings(existing.first);
      return;
    }
    final cfg = ChartIndicatorConfig.create(kind, existing: _active);
    setState(() => _active.add(cfg));
    _emit();
    _openSettings(cfg);
  }

  void _remove(ChartIndicatorConfig cfg) {
    setState(() => _active.removeWhere((c) => c.instanceId == cfg.instanceId));
    _emit();
  }

  Future<void> _openSettings(ChartIndicatorConfig cfg) async {
    final edited = await showModalBottomSheet<ChartIndicatorConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _IndicatorSettingsSheet(config: cfg.copy()),
    );
    if (edited == null || !mounted) return;
    setState(() {
      final i = _active.indexWhere((c) => c.instanceId == edited.instanceId);
      if (i >= 0) {
        _active[i] = edited;
      } else {
        _active.add(edited);
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 88, 10, 0),
          child: Material(
            color: OcColors.surface,
            elevation: 10,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: size.height * 0.58,
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
                              _emit();
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
                  if (_active.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        'ACTIVE (${_active.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OcColors.textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _active.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final cfg = _active[i];
                          return Material(
                            color: OcColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _openSettings(cfg),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _parseColor(cfg.color),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cfg.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: OcColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _remove(cfg),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      icon: Icon(
                                        OcIcons.x,
                                        size: 16,
                                        color: OcColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
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
                      'ADD INDICATOR',
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
                        final count =
                            _active.where((c) => c.type == ind.type).length;
                        return InkWell(
                          onTap: () => _add(ind),
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
                                          fontWeight: count > 0
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: count > 0
                                              ? OcColors.primary
                                              : OcColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ind.allowMultiple
                                            ? '${ind.subtitle} · tap to add'
                                            : (count > 0
                                                ? 'Tap to edit settings'
                                                : ind.subtitle),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: OcColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (count > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: OcColors.primarySoft,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      ind.allowMultiple ? '×$count' : 'ON',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: OcColors.primary,
                                      ),
                                    ),
                                  )
                                else
                                  Icon(
                                    OcIcons.plus,
                                    size: 18,
                                    color: OcColors.textMuted,
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

Color _parseColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  if (v == null) return OcColors.primary;
  return Color(v);
}

class _IndicatorSettingsSheet extends StatefulWidget {
  const _IndicatorSettingsSheet({required this.config});
  final ChartIndicatorConfig config;

  @override
  State<_IndicatorSettingsSheet> createState() =>
      _IndicatorSettingsSheetState();
}

class _IndicatorSettingsSheetState extends State<_IndicatorSettingsSheet> {
  late final ChartIndicatorConfig _cfg = widget.config;
  late final TextEditingController _len =
      TextEditingController(text: '${_cfg.length}');
  late final TextEditingController _len2 =
      TextEditingController(text: '${_cfg.length2}');
  late final TextEditingController _len3 =
      TextEditingController(text: '${_cfg.length3}');
  late final TextEditingController _mult =
      TextEditingController(text: _cfg.mult.toString());

  @override
  void dispose() {
    _len.dispose();
    _len2.dispose();
    _len3.dispose();
    _mult.dispose();
    super.dispose();
  }

  int _readInt(TextEditingController c, int fallback) {
    final v = int.tryParse(c.text.trim());
    if (v == null || v < 1) return fallback;
    return v.clamp(1, 500);
  }

  double _readDouble(TextEditingController c, double fallback) {
    final v = double.tryParse(c.text.trim());
    if (v == null || v <= 0) return fallback;
    return v.clamp(0.1, 10);
  }

  void _save() {
    _cfg.length = _readInt(_len, _cfg.length);
    _cfg.length2 = _readInt(_len2, _cfg.length2);
    _cfg.length3 = _readInt(_len3, _cfg.length3);
    _cfg.mult = _readDouble(_mult, _cfg.mult);
    Navigator.pop(context, _cfg);
  }

  Widget _numField({
    required String label,
    required TextEditingController controller,
    bool decimal = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OcColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: decimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: [
              if (decimal)
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              else
                FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              filled: true,
              fillColor: OcColors.bg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: OcColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: OcColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(String label, String value, ValueChanged<String> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: OcColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in ChartIndicator.palette)
              GestureDetector(
                onTap: () => setState(() => onPick(p)),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _parseColor(p),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: value.toUpperCase() == p.toUpperCase()
                          ? OcColors.text
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = _cfg.type;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: OcColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Settings · ${_cfg.label}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: OcColors.text,
            ),
          ),
          const SizedBox(height: 14),
          if (type == 'sma' ||
              type == 'ema' ||
              type == 'rsi' ||
              type == 'atr' ||
              type == 'mom' ||
              type == 'cci' ||
              type == 'willr' ||
              type == 'bb')
            Row(
              children: [
                _numField(label: 'Length', controller: _len),
                if (type == 'bb') ...[
                  const SizedBox(width: 10),
                  _numField(label: 'StdDev', controller: _mult, decimal: true),
                ],
              ],
            ),
          if (type == 'macd') ...[
            Row(
              children: [
                _numField(label: 'Fast', controller: _len),
                const SizedBox(width: 10),
                _numField(label: 'Slow', controller: _len2),
                const SizedBox(width: 10),
                _numField(label: 'Signal', controller: _len3),
              ],
            ),
          ],
          if (type == 'stoch') ...[
            Row(
              children: [
                _numField(label: '%K Length', controller: _len),
                const SizedBox(width: 10),
                _numField(label: '%D Smooth', controller: _len3),
              ],
            ),
          ],
          if (type == 'ao') ...[
            Row(
              children: [
                _numField(label: 'Fast SMA', controller: _len),
                const SizedBox(width: 10),
                _numField(label: 'Slow SMA', controller: _len2),
              ],
            ),
          ],
          if (type != 'vol' && type != 'ao') ...[
            const SizedBox(height: 14),
            _colorRow(
              type == 'bb'
                  ? 'Mid colour'
                  : (type == 'macd' || type == 'stoch'
                      ? 'Line 1 colour'
                      : 'Line colour'),
              _cfg.color,
              (c) => _cfg.color = c,
            ),
          ],
          if (type == 'bb' || type == 'macd' || type == 'stoch') ...[
            const SizedBox(height: 12),
            _colorRow(
              type == 'bb' ? 'Band colour' : 'Line 2 colour',
              _cfg.color2,
              (c) => _cfg.color2 = c,
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _save,
            child: const Text('Apply'),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

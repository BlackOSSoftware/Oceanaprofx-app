import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/trade_sound.dart';
import 'chart_painter.dart';

/// MT5-style trade result strip: light red band, left "EURUSD Buy 0.04",
/// right "Market closed" in bold red.
void showMarketClosedBanner(
  BuildContext context, {
  required String symbol,
  required String side,
  required double volume,
}) {
  final sideLabel = side.toUpperCase().startsWith('S') ? 'Sell' : 'Buy';
  final sideColor = sideLabel == 'Buy'
      ? const Color(0xFF168BE1)
      : chartDownColor;
  final lots = volume == volume.roundToDouble()
      ? '${volume.toInt()}'
      : volume.toStringAsFixed(2);

  unawaited(TradeSound.error());

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 3),
      content: Material(
        color: const Color(0xFFFFF0F0),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFE8A0A0), width: 1),
              bottom: BorderSide(color: Color(0xFFE8A0A0), width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      color: MtColors.text,
                      height: 1.2,
                    ),
                    children: [
                      TextSpan(text: '$symbol '),
                      TextSpan(
                        text: sideLabel,
                        style: TextStyle(
                          color: sideColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(text: ' $lots'),
                    ],
                  ),
                ),
              ),
              const Text(
                'Market closed',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC62828),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

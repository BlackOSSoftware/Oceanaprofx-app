import 'package:flutter/material.dart';

/// Oceana Pro FX brand mark (replaces MT5 / TX placeholder).
class OcBrandMark extends StatelessWidget {
  const OcBrandMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Image.asset(
        'assets/brand/oceana_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFF001529),
          alignment: Alignment.center,
          child: Text(
            'O',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

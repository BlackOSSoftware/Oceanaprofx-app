import 'package:flutter/material.dart';

/// Oceana brand lockup (wave + wordmark). Always [BoxFit.contain] so
/// the full logo shows — never crop like a square app-icon.
class OcBrandMark extends StatelessWidget {
  const OcBrandMark({
    super.key,
    double? size,
    double? height,
    this.maxWidth = 260,
  }) : height = height ?? size ?? 72;

  /// Logo height. Prefer this (or legacy [size]) — width follows aspect.
  final double height;

  /// Max width so the full wordmark fits on phone screens.
  final double maxWidth;

  static const _asset = 'assets/brand/oceana_logo_v3.png';

  @override
  Widget build(BuildContext context) {
    final padV = height * 0.12;
    final padH = height * 0.18;
    final radius = height * 0.16;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Soft white plate — logo stays readable on dark theme.
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Image.asset(
          _asset,
          height: height,
          width: maxWidth,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            height: height,
            width: height,
            child: Center(
              child: Text(
                'O',
                style: TextStyle(
                  color: const Color(0xFF1414C7),
                  fontSize: height * 0.42,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

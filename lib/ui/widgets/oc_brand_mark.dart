import 'package:flutter/material.dart';

/// Oceana brand mark — full wave wordmark (`oceana_logo_v3.png`).
///
/// App drawer / launcher uses the circular emblem separately (Android mipmaps).
class OcBrandMark extends StatelessWidget {
  const OcBrandMark({
    super.key,
    double? size,
    double? height,
    this.maxWidth = 260,
    this.borderRadius = 14,
  }) : height = height ?? size ?? 72;

  /// Logo height. Prefer this (or legacy [size]) — width follows aspect.
  final double height;

  /// Max width so the full wordmark fits on phone screens.
  final double maxWidth;

  /// Visible corner radius on the logo image (clips the PNG’s white plate).
  final double borderRadius;

  static const _logoAsset = 'assets/brand/oceana_logo_v3.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: maxWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          _logoAsset,
          height: height,
          width: maxWidth,
          // cover so white PNG fills the rounded rect (contain left
          // transparent letterbox → radius looked invisible).
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: const Color(0xFFF5F5F7),
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

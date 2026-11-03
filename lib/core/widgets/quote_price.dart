import 'package:flutter/material.dart';

class QuotePrice extends StatelessWidget {
  const QuotePrice({
    super.key,
    required this.head,
    required this.tail,
    required this.color,
  });

  final String head;
  final String tail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final big = head.length >= 2 ? head.substring(head.length - 2) : head;
    final prefix = head.length >= 2 ? head.substring(0, head.length - 2) : '';
    const family = 'Roboto Condensed';

    // Screenshot ratio: prefix medium, last-2 pips ~1.45× + bold, tail tiny superscript.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (prefix.isNotEmpty)
              Text(
                prefix,
                style: TextStyle(
                  fontFamily: family,
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            Text(
              big,
              style: TextStyle(
                fontFamily: family,
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
        Transform.translate(
          offset: const Offset(0.5, -1),
          child: Text(
            tail,
            style: TextStyle(
              fontFamily: family,
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

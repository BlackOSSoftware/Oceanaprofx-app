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
    // Last digit of the main price slightly larger; rest stay big & readable.
    final big = head.isNotEmpty ? head.substring(head.length - 1) : '';
    final prefix = head.length > 1 ? head.substring(0, head.length - 1) : '';
    const family = 'Roboto Condensed';

    // Quote row prices — larger readable bid/ask (restored after chart rewrite).
    const baseSize = 20.0;
    const lastSize = 23.0;
    const tailSize = 12.5;

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
                  fontSize: baseSize,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            if (big.isNotEmpty)
              Text(
                big,
                style: TextStyle(
                  fontFamily: family,
                  color: color,
                  fontSize: lastSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
          ],
        ),
        if (tail.isNotEmpty)
          Transform.translate(
            offset: const Offset(0.5, -1),
            child: Text(
              tail,
              style: TextStyle(
                fontFamily: family,
                color: color,
                fontSize: tailSize,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}

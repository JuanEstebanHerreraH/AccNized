import 'package:flutter/material.dart';
import '../models/label.dart';

class LabelChip extends StatelessWidget {
  final Label label;
  final bool small;

  const LabelChip({super.key, required this.label, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = label.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 6 : 8,
            height: small ? 6 : 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: small ? 4 : 6),
          Text(
            label.name,
            style: TextStyle(
              fontSize: small ? 11 : 13,
              color: color.withAlpha(220),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

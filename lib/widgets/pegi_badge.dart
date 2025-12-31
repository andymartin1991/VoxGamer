import 'package:flutter/material.dart';

class PegiBadge extends StatelessWidget {
  final int age;
  final double size;
  final bool showLabel;

  const PegiBadge({super.key, required this.age, this.size = 30.0, this.showLabel = true});

  Color _getPegiColor(int age) {
    if (age >= 18) return const Color(0xFFD32F2F); // Red
    if (age >= 12) return const Color(0xFFF57C00); // Orange
    if (age >= 7) return const Color(0xFF388E3C);  // Green
    if (age >= 3) return const Color(0xFF388E3C);  // Green
    return const Color(0xFF388E3C); // TP (0) Green
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPegiColor(age);
    final fontSize = size * 0.45; // Proporcional al tamaño

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 1))
            ],
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
          ),
          child: Text(
            age == 0 ? "TP" : "$age",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              shadows: const [Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 2)],
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          const Text("PEGI", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}

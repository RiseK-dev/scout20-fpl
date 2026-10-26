import 'package:flutter/material.dart';
import '../models/player_model.dart';

class FdrBadge extends StatelessWidget {
  final UpcomingFixture fixture;

  const FdrBadge({super.key, required this.fixture});

  Color _getFdrBgColor(int fdr) {
    switch (fdr) {
      case 1:
        return const Color(0xFF007A33); // Dark Green
      case 2:
        return const Color(0xFF00FF87); // Light Green
      case 3:
        return const Color(0xFFE7E7E7); // Grey
      case 4:
        return const Color(0xFFFF2882); // Pink/Red
      case 5:
        return const Color(0xFF80072D); // Dark Red
      default:
        return Colors.grey;
    }
  }

  Color _getFdrTextColor(int fdr) {
    switch (fdr) {
      case 2:
      case 3:
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getFdrBgColor(fixture.fdr);
    final textColor = _getFdrTextColor(fixture.fdr);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        fixture.displayLabel,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

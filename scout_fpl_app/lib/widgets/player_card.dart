import 'package:flutter/material.dart';
import '../models/player_model.dart';
import 'fdr_badge.dart';

class PlayerCard extends StatelessWidget {
  final PlayerRecommendation player;
  final int rank;
  final VoidCallback onTap;

  const PlayerCard({
    super.key,
    required this.player,
    required this.rank,
    required this.onTap,
  });

  Color _getPositionColor(String pos) {
    switch (pos.toUpperCase()) {
      case 'GKP':
      case 'KEEPER':
        return Colors.amber.shade800;
      case 'DEF':
      case 'FORSVAR':
        return Colors.blue.shade700;
      case 'MID':
      case 'MIDTBANE':
        return Colors.teal.shade700;
      case 'FWD':
      case 'SPISS':
        return Colors.deepOrange.shade700;
      default:
        return Colors.purple.shade700;
    }
  }

  String _getPositionEnglish(String pos) {
    switch (pos.toUpperCase()) {
      case 'GKP':
        return 'Goalkeeper';
      case 'DEF':
        return 'Defender';
      case 'MID':
        return 'Midfielder';
      case 'FWD':
        return 'Forward';
      default:
        return pos;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Spillerens etternavn
    final lastName = player.secondName.isNotEmpty ? player.secondName : player.webName;
    
    // 2. Position on the pitch
    final positionLabel = _getPositionEnglish(player.position);
    final posColor = _getPositionColor(player.position);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hovedrad: Rangering -> 1. Etternavn -> 2. Posisjon -> 3. Antatt poeng
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Rangering-badge (#1, #2...)
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank <= 3 ? const Color(0xFF38003C) : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: rank <= 3 ? const Color(0xFF00FF87) : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 1. Player's last name first (+ club)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${player.teamName} (${player.teamShort})',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Position on the pitch next
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: posColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      positionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 3. Antatt poeng til slutt
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38003C), Color(0xFF5A0060)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38003C).withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'PROJECTED PTS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          player.projectedExpectedPoints.round().toString(),
                          style: const TextStyle(
                            color: Color(0xFF00FF87),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Badges for DGW, Most Transferred In, Set Pieces
              if (player.isDoubleGameweek || player.isMostTransferredIn || player.isPenaltyTaker || player.isFreekickTaker || player.isCornerTaker) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (player.isDoubleGameweek)
                      _setPieceBadge('⚡ DOUBLE GAMEWEEK (2 matches!)', Colors.amber.shade900),
                    if (player.isMostTransferredIn)
                      _setPieceBadge('🔥 Most Transferred In!', Colors.deepOrange.shade800),
                    if (player.isPenaltyTaker)
                      _setPieceBadge('🎯 Penalties (1st choice)', Colors.red.shade800),
                    if (player.isFreekickTaker)
                      _setPieceBadge('📐 Direct Free Kicks', Colors.indigo.shade800),
                    if (player.isCornerTaker)
                      _setPieceBadge('⛳ Corners', Colors.teal.shade800),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Detaljert statistikkrad: Pris, Form, Neste GW, Total, Score
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('PRICE', '£${player.price.toStringAsFixed(1)}m'),
                  _statItem('FORM', player.form.toStringAsFixed(1)),
                  _statItem('NEXT GW', '${player.expectedPointsNext.toStringAsFixed(1)} pts'),
                  _statItem('TOTAL', '${player.totalPoints} pts'),
                  _statItem('SCOUT SCORE', player.bestBuyScore.toStringAsFixed(1)),
                ],
              ),

              const SizedBox(height: 10),

              // Neste kamper
              Row(
                children: [
                  Text(
                    'Upcoming Fixtures: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: player.upcomingFixtures
                          .map((fx) => FdrBadge(fixture: fx))
                          .toList(),
                    ),
                  ),
                ],
              ),

              // Reason / Why buy
              if (player.whyBuy.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF87).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00FF87).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: Color(0xFF007A33),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          player.whyBuy,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF005A25),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _setPieceBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

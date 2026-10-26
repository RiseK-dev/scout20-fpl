class UpcomingFixture {
  final int event;
  final String opponent;
  final bool isHome;
  final int fdr;

  UpcomingFixture({
    required this.event,
    required this.opponent,
    required this.isHome,
    required this.fdr,
  });

  factory UpcomingFixture.fromJson(Map<String, dynamic> json) {
    return UpcomingFixture(
      event: json['event'] ?? 0,
      opponent: json['opponent'] ?? 'OPP',
      isHome: json['is_home'] ?? true,
      fdr: json['fdr'] ?? 3,
    );
  }

  String get displayLabel => '$opponent (${isHome ? "H" : "A"})';
}

class PlayerRecommendation {
  final int id;
  final String webName;
  final String firstName;
  final String secondName;
  final String position;
  final String teamShort;
  final String teamName;
  final double price;
  final int totalPoints;
  final double form;
  final double pointsPerGame;
  final double selectedByPercent;
  final double expectedPointsNext;
  final double projectedExpectedPoints;
  final bool isPenaltyTaker;
  final bool isFreekickTaker;
  final bool isCornerTaker;
  final bool isMostTransferredIn;
  final bool isDoubleGameweek;
  final int? chanceOfPlaying;
  final String news;
  final double bestBuyScore;
  final String whyBuy;
  final List<UpcomingFixture> upcomingFixtures;
  final String photoUrl;

  PlayerRecommendation({
    required this.id,
    required this.webName,
    required this.firstName,
    required this.secondName,
    required this.position,
    required this.teamShort,
    required this.teamName,
    required this.price,
    required this.totalPoints,
    required this.form,
    required this.pointsPerGame,
    required this.selectedByPercent,
    required this.expectedPointsNext,
    required this.projectedExpectedPoints,
    this.isPenaltyTaker = false,
    this.isFreekickTaker = false,
    this.isCornerTaker = false,
    this.isMostTransferredIn = false,
    this.isDoubleGameweek = false,
    this.chanceOfPlaying,
    required this.news,
    required this.bestBuyScore,
    required this.whyBuy,
    required this.upcomingFixtures,
    required this.photoUrl,
  });

  factory PlayerRecommendation.fromJson(Map<String, dynamic> json) {
    var fxList = json['upcoming_fixtures'] as List? ?? [];
    List<UpcomingFixture> fixtures =
        fxList.map((f) => UpcomingFixture.fromJson(f)).toList();

    return PlayerRecommendation(
      id: json['id'] ?? 0,
      webName: json['web_name'] ?? 'Player',
      firstName: json['first_name'] ?? '',
      secondName: json['second_name'] ?? '',
      position: json['position'] ?? 'UNK',
      teamShort: json['team_short'] ?? 'TEAM',
      teamName: json['team_name'] ?? 'Team',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      totalPoints: json['total_points'] ?? 0,
      form: (json['form'] as num?)?.toDouble() ?? 0.0,
      pointsPerGame: (json['points_per_game'] as num?)?.toDouble() ?? 0.0,
      selectedByPercent: (json['selected_by_percent'] as num?)?.toDouble() ?? 0.0,
      expectedPointsNext: (json['expected_points_next'] as num?)?.toDouble() ?? 0.0,
      projectedExpectedPoints: (json['projected_expected_points'] as num?)?.toDouble() ??
          (json['expected_points_next'] as num?)?.toDouble() ?? 0.0,
      isPenaltyTaker: json['is_penalty_taker'] ?? false,
      isFreekickTaker: json['is_freekick_taker'] ?? false,
      isCornerTaker: json['is_corner_taker'] ?? false,
      isMostTransferredIn: json['is_most_transferred_in'] ?? false,
      isDoubleGameweek: json['is_double_gameweek'] ?? false,
      chanceOfPlaying: json['chance_of_playing'],
      news: json['news'] ?? '',
      bestBuyScore: (json['best_buy_score'] as num?)?.toDouble() ?? 0.0,
      whyBuy: json['why_buy'] ?? '',
      upcomingFixtures: fixtures,
      photoUrl: json['photo_url'] ?? '',
    );
  }
}

class GameweekOverview {
  final int currentGameweek;
  final String gameweekName;
  final String? deadlineTime;
  final int totalFplPlayers;

  GameweekOverview({
    required this.currentGameweek,
    required this.gameweekName,
    this.deadlineTime,
    required this.totalFplPlayers,
  });

  factory GameweekOverview.fromJson(Map<String, dynamic> json) {
    return GameweekOverview(
      currentGameweek: json['currentGameweek'] ?? json['current_gameweek'] ?? 1,
      gameweekName: json['gameweekName'] ?? json['gameweek_name'] ?? 'GW1',
      deadlineTime: json['deadlineTime'] ?? json['deadline_time'],
      totalFplPlayers: json['totalFplPlayers'] ?? json['total_fpl_players'] ?? 0,
    );
  }
}

/// Play-style bias applied when a weakened bot samples candidate moves.
enum BotStyle {
  balanced('Balanced'),
  aggressive('Aggressive'),
  solid('Solid'),
  chaotic('Chaotic');

  const BotStyle(this.label);
  final String label;
}

/// A local bot. Bots below Stockfish's 1320 floor use our error injection
/// (MultiPV sampling + random moves); others use `UCI_Elo`. See ANALYSIS.md §2.
class BotProfile {
  const BotProfile({
    required this.id,
    required this.name,
    required this.elo,
    required this.style,
    required this.blurb,
    required this.colorValue,
    required this.movetimeCap,
    this.depth,
    this.multiPv = 1,
    this.temperature = 0,
    this.randomMoveRate = 0,
    this.uciElo,
    this.fullStrength = false,
  });

  final String id;
  final String name;
  final int elo;
  final BotStyle style;
  final String blurb;

  /// Avatar color (ARGB) so the domain layer stays free of Flutter.
  final int colorValue;

  final Duration movetimeCap;
  final int? depth;
  final int multiPv;

  /// Softmax temperature in centipawns; 0 disables sampling.
  final double temperature;

  /// Probability of playing a uniformly random legal move.
  final double randomMoveRate;

  /// Target for Stockfish's `UCI_LimitStrength`.
  final int? uciElo;

  final bool fullStrength;

  bool get usesInjection => temperature > 0;

  /// Bots below this rating pause briefly so they feel human and premoves
  /// stay usable.
  bool get humanizedDelay => elo < 1600;

  String get ratingTag => fullStrength ? 'MAX' : '$elo';

  static const all = <BotProfile>[
    BotProfile(
      id: 'pebble', name: 'Pebble', elo: 100, style: BotStyle.chaotic,
      blurb: 'Just learned how the pieces move. Mostly.',
      colorValue: 0xFF8BC34A, movetimeCap: Duration(milliseconds: 200),
      depth: 1, multiPv: 8, temperature: 500, randomMoveRate: 0.55,
    ),
    BotProfile(
      id: 'sprout', name: 'Sprout', elo: 250, style: BotStyle.balanced,
      blurb: 'Happy to trade, happier to leave pieces hanging.',
      colorValue: 0xFF66BB6A, movetimeCap: Duration(milliseconds: 200),
      depth: 1, multiPv: 8, temperature: 350, randomMoveRate: 0.40,
    ),
    BotProfile(
      id: 'rook_rookie', name: 'Rookie Ray', elo: 400, style: BotStyle.aggressive,
      blurb: 'Loves checks. Every check. Always.',
      colorValue: 0xFF26A69A, movetimeCap: Duration(milliseconds: 250),
      depth: 2, multiPv: 6, temperature: 250, randomMoveRate: 0.28,
    ),
    BotProfile(
      id: 'mila', name: 'Mila', elo: 600, style: BotStyle.solid,
      blurb: 'Keeps pieces protected and waits for you to slip.',
      colorValue: 0xFF29B6F6, movetimeCap: Duration(milliseconds: 300),
      depth: 3, multiPv: 5, temperature: 170, randomMoveRate: 0.18,
    ),
    BotProfile(
      id: 'tariq', name: 'Tariq', elo: 800, style: BotStyle.aggressive,
      blurb: 'Goes for the king early and often.',
      colorValue: 0xFF42A5F5, movetimeCap: Duration(milliseconds: 300),
      depth: 4, multiPv: 5, temperature: 120, randomMoveRate: 0.11,
    ),
    BotProfile(
      id: 'june', name: 'June', elo: 1000, style: BotStyle.balanced,
      blurb: 'Knows her openings, still drops the odd tactic.',
      colorValue: 0xFF5C6BC0, movetimeCap: Duration(milliseconds: 400),
      depth: 5, multiPv: 4, temperature: 80, randomMoveRate: 0.06,
    ),
    BotProfile(
      id: 'oskar', name: 'Oskar', elo: 1200, style: BotStyle.solid,
      blurb: 'Club regular. Punishes loose pieces.',
      colorValue: 0xFF7E57C2, movetimeCap: Duration(milliseconds: 400),
      depth: 6, multiPv: 4, temperature: 50, randomMoveRate: 0.03,
    ),
    BotProfile(
      id: 'amara', name: 'Amara', elo: 1400, style: BotStyle.balanced,
      blurb: 'Solid fundamentals, sharp in the middlegame.',
      colorValue: 0xFFAB47BC, movetimeCap: Duration(milliseconds: 500),
      uciElo: 1400,
    ),
    BotProfile(
      id: 'viktor', name: 'Viktor', elo: 1600, style: BotStyle.aggressive,
      blurb: 'Gambits first, questions later.',
      colorValue: 0xFFEC407A, movetimeCap: Duration(milliseconds: 600),
      uciElo: 1600,
    ),
    BotProfile(
      id: 'lena', name: 'Lena', elo: 1800, style: BotStyle.solid,
      blurb: 'Grinds small edges into won endgames.',
      colorValue: 0xFFEF5350, movetimeCap: Duration(milliseconds: 700),
      uciElo: 1800,
    ),
    BotProfile(
      id: 'kwame', name: 'Kwame', elo: 2000, style: BotStyle.balanced,
      blurb: 'Expert strength. Rarely gives you a second chance.',
      colorValue: 0xFFFF7043, movetimeCap: Duration(milliseconds: 800),
      uciElo: 2000,
    ),
    BotProfile(
      id: 'sofia', name: 'Sofia', elo: 2200, style: BotStyle.aggressive,
      blurb: 'Master-level attacker with deep calculation.',
      colorValue: 0xFFFFA726, movetimeCap: Duration(milliseconds: 1000),
      uciElo: 2200,
    ),
    BotProfile(
      id: 'ivo', name: 'Iron Ivo', elo: 2500, style: BotStyle.solid,
      blurb: 'International-master precision.',
      colorValue: 0xFF8D6E63, movetimeCap: Duration(milliseconds: 1200),
      uciElo: 2500,
    ),
    BotProfile(
      id: 'grandmaster', name: 'The Grandmaster', elo: 2850,
      style: BotStyle.balanced,
      blurb: 'Elite grandmaster level. Zero mercy.',
      colorValue: 0xFF546E7A, movetimeCap: Duration(milliseconds: 1500),
      uciElo: 2850,
    ),
    BotProfile(
      id: 'engine', name: 'Max Engine', elo: 3500, style: BotStyle.balanced,
      blurb: 'Unrestricted engine. Good luck.',
      colorValue: 0xFF263238, movetimeCap: Duration(milliseconds: 2000),
      fullStrength: true,
    ),
  ];
}

// Xăm hường - game controller (turns, bots, end of game).
// Depends on xam_huong_engine.dart. Pure Dart, no Flutter.

import 'dart:math';
import 'xam_huong_engine.dart';

class Player {
  final String name;
  final bool isBot;
  final Map<Tile, int> tiles = {for (final t in Tile.values) t: 0};

  Player(this.name, {this.isBot = false});

  int get score =>
      tiles.entries.fold(0, (s, e) => s + e.key.points * e.value);

  void add(Map<Tile, int> got) {
    got.forEach((t, n) => tiles[t] = tiles[t]! + n);
  }

  Map<Tile, int> clear() {
    final old = Map<Tile, int>.from(tiles);
    for (final t in Tile.values) {
      tiles[t] = 0;
    }
    return old;
  }
}

class TurnOutcome {
  final Player player;
  final RollResult roll;
  final Award award;
  final bool tookEverythingFromOthers; // Lục Phú Hường
  const TurnOutcome(this.player, this.roll, this.award,
      {this.tookEverythingFromOthers = false});
}

class XamHuongGame {
  final List<Player> players;
  final Bank bank = Bank();
  final Random _rng;

  int current = 0;
  bool gameOver = false;

  /// Turns in a row where nobody took a tile while only a high tile is left.
  int _failedTurns = 0;

  XamHuongGame(this.players, {Random? rng}) : _rng = rng ?? Random() {
    assert(players.length >= 2 && players.length <= 12);
  }

  Player get currentPlayer => players[current];

  int get failedRounds => _failedTurns ~/ players.length;

  /// Giảm giá is available after all players failed for 3 rounds.
  bool get canDiscount => bank.onlyHighTileLeft && failedRounds >= 3;

  bool discount() {
    if (!canDiscount) return false;
    _failedTurns = 0;
    return bank.discount();
  }

  /// Players below this many points lose (192 / number of players).
  int get loseThreshold => 192 ~/ players.length;

  List<Player> get losers =>
      players.where((p) => p.score < loseThreshold).toList();

  List<Player> get winners {
    final best = players.map((p) => p.score).reduce(max);
    return players.where((p) => p.score == best).toList();
  }

  /// The current player rolls. Bots also decide on Giảm giá automatically.
  TurnOutcome playTurn() {
    assert(!gameOver);
    final p = currentPlayer;
    if (p.isBot && canDiscount) discount();

    final roll = evaluateRoll(rollDice(_rng));
    var award = const Award({}, false);
    var tookFromOthers = false;

    if (roll.winEverything) {
      for (final other in players) {
        if (other != p) p.add(other.clear());
      }
      award = bank.takeAll();
      p.add(award.tiles);
      tookFromOthers = true;
    } else if (roll.winAllRemaining) {
      award = bank.takeAll();
      p.add(award.tiles);
    } else if (roll.tiles.isNotEmpty) {
      award = bank.award(roll.tiles);
      p.add(award.tiles);
    }

    if (bank.onlyHighTileLeft && award.tiles.isEmpty) {
      _failedTurns++;
    } else {
      _failedTurns = 0;
    }

    if (award.gameOver || bank.isEmpty) gameOver = true;
    current = (current + 1) % players.length;
    return TurnOutcome(p, roll, award, tookEverythingFromOthers: tookFromOthers);
  }
}

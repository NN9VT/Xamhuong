// Xăm hường - game engine (pure Dart, no Flutter dependency).
// Put this in lib/game/ so the UI and tests can both import it.

import 'dart:math';

enum Tile {
  trangAnh(32, 1, 'Trạng Nguyên'),
  trangEm(16, 2, 'Thám Hoa / Bảng Nhãn'),
  tamHuong(8, 4, 'Tam Hường'),
  tuTu(4, 8, 'Tứ Tự'),
  nhiHuong(2, 16, 'Nhị Hường'),
  nhatHuong(1, 32, 'Nhất Hường');

  const Tile(this.points, this.initialCount, this.label);
  final int points;
  final int initialCount;
  final String label;
}

class RollResult {
  final List<int> dice;
  final List<String> names; // combo names to show in the UI
  final List<Tile> tiles; // tiles earned (before stock check)
  final bool winAllRemaining; // Lục Phú
  final bool winEverything; // Lục Phú Hường

  const RollResult(
    this.dice,
    this.names,
    this.tiles, {
    this.winAllRemaining = false,
    this.winEverything = false,
  });

  int get points => tiles.fold(0, (s, t) => s + t.points);
}

List<int> rollDice([Random? rng]) {
  final r = rng ?? Random();
  return List.generate(6, (_) => r.nextInt(6) + 1);
}

/// Faces 1 and 4 are red.
bool isRed(int face) => face == 1 || face == 4;

RollResult evaluateRoll(List<int> dice) {
  assert(dice.length == 6);
  final c = List<int>.filled(7, 0);
  for (final d in dice) {
    c[d]++;
  }
  final fours = c[4];

  RollResult result(List<String> names, List<Tile> tiles) =>
      RollResult(dice, names, tiles);

  // Instant wins
  if (fours == 6) {
    return RollResult(dice, ['Lục Phú Hường'], [], winEverything: true);
  }
  for (var f = 1; f <= 6; f++) {
    if (f != 4 && c[f] == 6) {
      return RollResult(dice, ['Lục Phú'], [], winAllRemaining: true);
    }
  }

  // Many red 4s
  if (fours == 5) {
    return result(['Ngũ Hường'], [Tile.trangAnh, Tile.trangEm, Tile.trangEm]);
  }
  if (fours == 4) {
    return result(['Bốn mặt 4'], [Tile.trangAnh]);
  }
  if (fours == 3) {
    if (dice.where((d) => d != 4).toSet().length == 1) {
      return result(['Tam Hường Phân Song'], [Tile.tamHuong, Tile.trangEm]);
    }
    return result(['Tam Hường'], [Tile.tamHuong]);
  }

  // Same faces (not 4)
  for (var f = 1; f <= 6; f++) {
    if (f == 4) continue;
    if (c[f] == 5) {
      return result(['Ngũ Tử'], [Tile.trangAnh]);
    }
    if (c[f] == 4) {
      final rest = dice.where((d) => d != f).toList();
      if (rest[0] + rest[1] == f) {
        // Tứ Tự Cáp replaces the Tứ Tự tile and gives nothing else.
        if (rest[0] == rest[1]) {
          return result(['Tứ Tự Cáp Chính'], [Tile.trangEm, Tile.tamHuong]);
        }
        return result(['Tứ Tự Cáp Xiên'], [Tile.trangEm]);
      }
      return result(
        ['Tứ Tự', if (fours == 1) 'Nhất Hường', if (fours == 2) 'Nhị Hường'],
        [
          Tile.tuTu,
          if (fours == 1) Tile.nhatHuong,
          if (fours == 2) Tile.nhiHuong,
        ],
      );
    }
  }

  // Patterns: each gives only 1 Trạng em, no extra Hường tiles.
  bool every(List<int> faces, int n) => faces.every((f) => c[f] == n);
  final triples = [for (var f = 1; f <= 6; f++) if (c[f] == 3) f];
  if (triples.length == 2) return result(['Phân Song'], [Tile.trangEm]);
  if (every([1, 2, 3], 2)) return result(['Nhất Nhì Xa'], [Tile.trangEm]);
  if (every([4, 5, 6], 2)) return result(['Tứ Ngũ Lục'], [Tile.trangEm]);
  if (every([1, 2, 3, 4, 5, 6], 1)) return result(['Suốt'], [Tile.trangEm]);

  // Plain red 4s
  if (fours == 1) return result(['Nhất Hường'], [Tile.nhatHuong]);
  if (fours == 2) return result(['Nhị Hường'], [Tile.nhiHuong]);
  return result([], []);
}

class Award {
  final Map<Tile, int> tiles;
  final bool gameOver;
  const Award(this.tiles, this.gameOver);

  int get points => tiles.entries.fold(0, (s, e) => s + e.key.points * e.value);
}

/// The tiles left on the table ("sạp").
class Bank {
  final Map<Tile, int> stock = {
    for (final t in Tile.values) t: t.initialCount,
  };

  int get totalPoints =>
      stock.entries.fold(0, (s, e) => s + e.key.points * e.value);

  bool get isEmpty => totalPoints == 0;

  /// Exactly one tile left, worth Trạng em or more (Giảm giá can apply).
  bool get onlyHighTileLeft {
    final left = stock.entries.where((e) => e.value > 0).toList();
    return left.length == 1 &&
        left.first.value == 1 &&
        left.first.key.points >= Tile.trangEm.points;
  }

  /// "Giảm giá": call after all players failed for 3 rounds.
  /// The last tile drops one tier (Trạng em -> Tam Hường).
  bool discount() {
    if (!onlyHighTileLeft) return false;
    final t = stock.entries.firstWhere((e) => e.value > 0).key;
    stock[t] = 0;
    stock[Tile.values[t.index + 1]] = 1;
    return true;
  }

  /// Everything left on the table (Lục Phú, or when stock can't cover a win).
  Award takeAll() {
    final got = <Tile, int>{};
    for (final t in Tile.values) {
      if (stock[t]! > 0) got[t] = stock[t]!;
      stock[t] = 0;
    }
    return Award(got, true);
  }

  /// Give the tiles a roll earned. Missing tiles are converted to smaller
  /// ones of equal points. If the stock can't cover it, take all and end.
  Award award(List<Tile> wanted) {
    final needed = wanted.fold(0, (s, t) => s + t.points);
    if (totalPoints <= needed) return takeAll();

    final got = <Tile, int>{};
    void take(Tile t) {
      stock[t] = stock[t]! - 1;
      got[t] = (got[t] ?? 0) + 1;
    }

    var deficit = 0;
    for (final t in wanted) {
      if (stock[t]! > 0) {
        take(t);
      } else {
        deficit += t.points;
      }
    }
    // Convert the missing points, largest tiles first.
    for (final t in Tile.values) {
      while (deficit >= t.points && stock[t]! > 0) {
        take(t);
        deficit -= t.points;
      }
    }
    return Award(got, isEmpty);
  }
}

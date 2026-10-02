// Xăm hường - game engine (pure Dart, no Flutter dependency).

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

/// Trạng Nguyên can be held as "trạng đỏ" (Tứ Hường, Ngũ Hường) or
/// "trạng đen" (Ngũ Tử). Only the same colour can steal it, and only with
/// a higher rank.
enum TrangKind { red, black }

class Trang {
  final TrangKind kind;
  final int rank;
  final String label;
  const Trang(this.kind, this.rank, this.label);

  /// Ngũ Hường (rank 100+) can steal from red and black alike.
  bool get beatsAnyColor => rank >= 100;
}

class RollResult {
  final List<int> dice;
  final List<String> names; // combo names to show in the UI
  final List<Tile> tiles; // tiles earned (before stock check)
  final bool winAllRemaining; // Lục Phú
  final bool winEverything; // Lục Phú Hường
  final Trang? trang; // set when the roll gives a Trạng Nguyên
  final bool stealsTrangEm; // Ngũ Hường also takes Bảng Nhãn from players

  const RollResult(
    this.dice,
    this.names,
    this.tiles, {
    this.winAllRemaining = false,
    this.winEverything = false,
    this.trang,
    this.stealsTrangEm = false,
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

  RollResult result(List<String> names, List<Tile> tiles,
          {Trang? trang, bool stealsTrangEm = false}) =>
      RollResult(dice, names, tiles,
          trang: trang, stealsTrangEm: stealsTrangEm);

  // Instant wins
  if (fours == 6) {
    return RollResult(dice, ['Lục Phú Hường'], [], winEverything: true);
  }
  for (var f = 1; f <= 6; f++) {
    if (f != 4 && c[f] == 6) {
      return RollResult(dice, ['Lục Phú'], [], winAllRemaining: true);
    }
  }

  // Ngũ Hường: last die is the "tuổi", a 1 is Đại Ấn (highest)
  if (fours == 5) {
    final other = dice.firstWhere((d) => d != 4);
    final daiAn = other == 1;
    final name = daiAn ? 'Ngũ Hường Đại Ấn' : 'Ngũ Hường $other tuổi';
    return result(
      [name],
      [Tile.trangAnh, Tile.trangEm, Tile.trangEm],
      trang: Trang(TrangKind.red, 100 + (daiAn ? 7 : other), name),
      stealsTrangEm: true,
    );
  }

  // Tứ Hường: Cáp Chính (2,2) > Cáp Xiên (1,3) > plain, by "tuổi" = sum
  if (fours == 4) {
    final rest = dice.where((d) => d != 4).toList();
    final sum = rest[0] + rest[1];
    String name;
    int rank;
    if (rest[0] == 2 && rest[1] == 2) {
      name = 'Tứ Hường Cáp Chính';
      rank = 30;
    } else if (sum == 4) {
      name = 'Tứ Hường Cáp Xiên';
      rank = 20;
    } else {
      name = 'Tứ Hường $sum tuổi';
      rank = sum;
    }
    return result([name], [Tile.trangAnh],
        trang: Trang(TrangKind.red, rank, name));
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
      final other = dice.firstWhere((d) => d != f);
      final daiAn = other == 4;
      final name = daiAn ? 'Ngũ Tử Đại Ấn' : 'Ngũ Tử $other tuổi';
      return result([name], [Tile.trangAnh],
          trang: Trang(TrangKind.black, daiAn ? 7 : other, name));
    }
    if (c[f] == 4) {
      final rest = dice.where((d) => d != f).toList();
      final sum = rest[0] + rest[1];
      // Tứ Tự Cáp: the other two dice add up to the face (plus 1,1,1,1,5,6).
      if (sum == f || (f == 1 && sum == 11)) {
        return result(['Tứ Tự Cáp'], [Tile.trangEm]);
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

  /// Exactly one tile left and it is Trạng Nguyên (Giảm giá can start).
  bool get onlyTrangAnhLeft =>
      stock[Tile.trangAnh] == 1 &&
      Tile.values.every((t) => t == Tile.trangAnh || stock[t] == 0);

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
    if (needed > 0 && totalPoints <= needed) return takeAll();

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

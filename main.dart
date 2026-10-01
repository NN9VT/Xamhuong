import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'xam_huong_engine.dart';
import 'xam_huong_game.dart';

void main() => runApp(const XamHuongApp());

class XamHuongApp extends StatelessWidget {
  const XamHuongApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Xăm Hường',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB71C1C),
            brightness: Brightness.dark,
          ),
        ),
        home: const SetupScreen(),
      );
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  double bots = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Xăm Hường',
                    style:
                        TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Trò chơi dân gian gieo 6 xí ngầu'),
                const SizedBox(height: 32),
                Text('Số bot: ${bots.round()} (tổng ${bots.round() + 1} người chơi)'),
                Slider(
                  value: bots,
                  min: 1,
                  max: 11,
                  divisions: 10,
                  label: '${bots.round()}',
                  onChanged: (v) => setState(() => bots = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GameScreen(bots: bots.round()),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text('Bắt đầu chơi', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  final int bots;
  const GameScreen({super.key, required this.bots});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _rng = Random();
  final _clinks = List.generate(3, (_) => AudioPlayer());
  final _sfx = AudioPlayer();
  int _clinkIdx = 0;

  late XamHuongGame game;
  List<int> faces = [1, 2, 3, 4, 5, 6];
  List<double> angles = List.filled(6, 0.0);
  bool rolling = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  @override
  void dispose() {
    for (final p in _clinks) {
      p.dispose();
    }
    _sfx.dispose();
    super.dispose();
  }

  void _newGame() {
    game = XamHuongGame([
      Player('Bạn'),
      for (var i = 1; i <= widget.bots; i++) Player('Bot $i', isBot: true),
    ]);
    faces = [1, 2, 3, 4, 5, 6];
    angles = List.filled(6, 0.0);
    rolling = false;
    message = 'Tới lượt bạn, bấm Gieo!';
  }

  void _clink() {
    final p = _clinks[_clinkIdx++ % _clinks.length];
    p.play(AssetSource('sounds/clink.wav'));
  }

  Future<void> _takeTurn() async {
    if (rolling || game.gameOver) return;
    setState(() {
      rolling = true;
      message = '${game.currentPlayer.name} đang gieo...';
    });
    for (var i = 0; i < 9; i++) {
      _clink();
      setState(() {
        faces = List.generate(6, (_) => _rng.nextInt(6) + 1);
        angles = List.generate(6, (_) => (_rng.nextDouble() - 0.5) * 1.2);
      });
      await Future.delayed(const Duration(milliseconds: 130));
      if (!mounted) return;
    }
    final out = game.playTurn();
    final names =
        out.roll.names.isEmpty ? 'không trúng gì' : out.roll.names.join(' + ');
    final got = out.award.tiles.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.value}× ${e.key.label}')
        .join(', ');
    setState(() {
      faces = out.roll.dice;
      angles = List.filled(6, 0.0);
      rolling = false;
      message = '${out.player.name}: $names${got.isEmpty ? '' : '\n→ $got'}';
    });
    if (game.gameOver) {
      _endGame();
      return;
    }
    if (game.currentPlayer.isBot) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) _takeTurn();
    }
  }

  void _discount() {
    if (game.discount()) {
      setState(() => message = 'Giảm giá! Thẻ cuối trên sạp được hạ một bậc.');
    }
  }

  void _endGame() {
    final me = game.players.first;
    final won = game.winners.contains(me);
    final lost = game.losers.contains(me);
    _sfx.play(AssetSource(lost ? 'sounds/lose.wav' : 'sounds/win.wav'));
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(won
            ? '🎉 Bạn thắng!'
            : lost
                ? 'Bạn thua rồi'
                : 'Bạn không thua!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dưới ${game.loseThreshold} điểm là thua'),
            const SizedBox(height: 8),
            for (final p in game.players)
              Text(
                  '${p.name}: ${p.score} điểm${game.losers.contains(p) ? ' (thua)' : ''}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(_newGame);
            },
            child: const Text('Chơi lại'),
          ),
        ],
      ),
    );
  }

  String _tilesText(Player p) {
    final s = p.tiles.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.value}× ${e.key.label}')
        .join(', ');
    return s.isEmpty ? 'Chưa có thẻ' : s;
  }

  Widget _bowl() => Container(
        width: 270,
        height: 270,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFF5F5F5), Color(0xFFBCAAA4)],
          ),
          border: Border.all(color: const Color(0xFF5D4037), width: 8),
        ),
        child: Center(
          child: SizedBox(
            width: 176,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < 6; i++)
                  Transform.rotate(angle: angles[i], child: DieFace(faces[i])),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final myTurn = !rolling && !game.gameOver && !game.currentPlayer.isBot;
    return Scaffold(
      appBar: AppBar(title: const Text('Xăm Hường')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (final t in Tile.values)
                    Chip(
                      label: Text(
                          '${t.label} (${t.points}đ) ×${game.bank.stock[t]}',
                          style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _bowl(),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: myTurn ? _takeTurn : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: Text('Gieo', style: TextStyle(fontSize: 20)),
                ),
              ),
              if (myTurn && game.canDiscount) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _discount,
                  child: const Text('Giảm giá thẻ cuối'),
                ),
              ],
              const SizedBox(height: 12),
              for (final p in game.players)
                Card(
                  color: p == game.currentPlayer && !game.gameOver
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    dense: true,
                    title: Text(p.name),
                    subtitle: Text(_tilesText(p)),
                    trailing: Text('${p.score} điểm',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DieFace extends StatelessWidget {
  final int value;
  const DieFace(this.value, {super.key});

  // Pip positions on a 3x3 grid (row-major, 0..8).
  static const _pips = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final color = isRed(value) ? Colors.red.shade700 : Colors.black87;
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black38)],
      ),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          9,
          (i) => _pips[value]!.contains(i)
              ? Center(
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                )
              : const SizedBox(),
        ),
      ),
    );
  }
}

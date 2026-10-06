import 'package:flutter/material.dart';

import '../../../engine/move_quality.dart';
import '../move_record.dart';

/// Post-game review: per-move accuracy line for the human plus the full
/// move list with verdict chips. Pure custom painting — no chart package.
class ReviewScreen extends StatelessWidget {
  final List<MoveRecord> moves;
  final String botName;

  const ReviewScreen({super.key, required this.moves, required this.botName});

  static double scoreOf(MoveVerdict? v) => switch (v) {
        MoveVerdict.brilliant => 100,
        MoveVerdict.book => 95,
        MoveVerdict.good => 90,
        MoveVerdict.inaccuracy => 62,
        MoveVerdict.mistake => 42,
        MoveVerdict.blunder => 18,
        null => 85,
      };

  List<double> get _humanSeries {
    final s = <double>[];
    for (final m in moves) {
      if (m.byHuman) s.add(scoreOf(m.verdict));
    }
    return s;
  }

  int get accuracy {
    final s = _humanSeries;
    if (s.isEmpty) return 0;
    return (s.reduce((a, b) => a + b) / s.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final series = _humanSeries;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Review',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD0DDE8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Your accuracy',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$accuracy%',
                      style: const TextStyle(
                        color: Color(0xFF16865B),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 110,
                  child: CustomPaint(
                    size: const Size(double.infinity, 110),
                    painter: _AccuracyPainter(series),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Per-move accuracy — dips are inaccuracies, mistakes and blunders.',
                  style: TextStyle(color: Color(0xFF667085), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._moveRows(),
        ],
      ),
    );
  }

  List<Widget> _moveRows() {
    final rows = <Widget>[];
    var moveNo = 0;
    for (var i = 0; i < moves.length; i++) {
      final m = moves[i];
      if (m.byHuman) moveNo++;
      rows.add(Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E8F0)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                m.byHuman ? '$moveNo.' : '…',
                style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                m.label,
                style: TextStyle(
                  color: m.byHuman ? const Color(0xFF0F172A) : const Color(0xFF475467),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              m.byHuman ? 'You' : botName,
              style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 11),
            ),
            if (m.byHuman && m.verdict != null) ...[
              const SizedBox(width: 8),
              _verdictChip(m.verdict!),
            ],
          ],
        ),
      ));
    }
    return rows;
  }

  Widget _verdictChip(MoveVerdict v) {
    final color = switch (v) {
      MoveVerdict.brilliant => const Color(0xFF26A69A),
      MoveVerdict.book => const Color(0xFF98A2B3),
      MoveVerdict.good => const Color(0xFF16865B),
      MoveVerdict.inaccuracy => const Color(0xFFC98A08),
      MoveVerdict.mistake => const Color(0xFFE0762B),
      MoveVerdict.blunder => const Color(0xFFC4474F),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        v.label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _AccuracyPainter extends CustomPainter {
  final List<double> series;

  _AccuracyPainter(this.series);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid lines at 25/50/75/100.
    final grid = Paint()
      ..color = const Color(0xFFE4E9F0)
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = size.height - f * (size.height - 8) - 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (series.length < 2) {
      final p = Paint()
        ..color = const Color(0xFF0B63CE)
        ..strokeWidth = 2.5;
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
      return;
    }
    final step = size.width / (series.length - 1);
    final path = Path();
    final dot = Paint()..color = const Color(0xFF0B63CE);
    for (var i = 0; i < series.length; i++) {
      final x = i * step;
      final y = size.height - (series[i] / 100) * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = (i - 1) * step;
        final py =
            size.height - (series[i - 1] / 100) * (size.height - 8) - 4;
        final mx = (px + x) / 2;
        path.cubicTo(mx, py, mx, y, x, y);
      }
      canvas.drawCircle(Offset(x, y), 2.4, dot);
    }
    final line = Paint()
      ..color = const Color(0xFF0B63CE)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_AccuracyPainter old) => old.series != series;
}

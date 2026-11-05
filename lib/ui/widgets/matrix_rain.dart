import 'dart:math';

import 'package:flutter/material.dart';

/// Chuva de caracteres do tema Matrix. Leve: poucas colunas, um Ticker só.
class MatrixRain extends StatefulWidget {
  const MatrixRain({super.key, this.opacity = .35});
  final double opacity;

  @override
  State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  final _rng = Random(7);
  final _drops = <double>[];
  final _speeds = <double>[];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _RainPainter(this, widget.opacity),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.s, this.opacity);
  final _MatrixRainState s;
  final double opacity;

  static const _glyphs = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄ01234589JABUTICABA#*+<>';
  static const _cell = 16.0;

  /// Glifos já diagramados, por (glifo, posição no rastro, opacidade).
  static final _cache = <int, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / _cell).ceil();
    while (s._drops.length < cols) {
      s._drops.add(s._rng.nextDouble() * size.height / _cell);
      s._speeds.add(.25 + s._rng.nextDouble() * .6);
    }
    final rows = (size.height / _cell).ceil();
    for (var x = 0; x < cols; x++) {
      s._drops[x] += s._speeds[x];
      if (s._drops[x] > rows + 12) s._drops[x] = -s._rng.nextInt(20).toDouble();
      final head = s._drops[x].floor();
      for (var k = 0; k < 12; k++) {
        final y = head - k;
        if (y < 0 || y > rows) continue;
        final g = (x * 7 + y * 13 + head) % _glyphs.length;
        final tp = _cache.putIfAbsent(
          g * 100 + k + (opacity * 1000).round() * 10000,
          () {
            final alpha = (k == 0 ? 1.0 : (1 - k / 12) * .7) * opacity;
            return TextPainter(
              text: TextSpan(
                text: _glyphs[g],
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 18,
                  color:
                      (k == 0
                              ? const Color(0xFFD7FFE0)
                              : const Color(0xFF39FF6A))
                          .withValues(alpha: alpha),
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
          },
        );
        tp.paint(canvas, Offset(x * _cell, y * _cell));
      }
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => true;
}

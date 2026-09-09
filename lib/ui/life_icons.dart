import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

enum LifeGlyph {
  today,
  goals,
  tasks,
  calendar,
  more,
  spaces,
  sparkle,
  settings,
  file,
}

class LifeMark extends StatelessWidget {
  const LifeMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _LifeMarkPainter(
      color: context.appText,
      accent: Theme.of(context).colorScheme.primary,
    ),
  );
}

class _LifeMarkPainter extends CustomPainter {
  const _LifeMarkPainter({required this.color, required this.accent});
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glow = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    line.strokeWidth = 2.6 * s;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(12 * s, 12 * s), radius: 8.2 * s),
      -.05,
      math.pi * 1.72,
      false,
      line,
    );
    canvas.drawCircle(Offset(18.7 * s, 5.3 * s), 2.15 * s, glow);
  }

  @override
  bool shouldRepaint(covariant _LifeMarkPainter oldDelegate) =>
      color != oldDelegate.color || accent != oldDelegate.accent;
}

class LifeGlyphIcon extends StatelessWidget {
  const LifeGlyphIcon(
    this.glyph, {
    super.key,
    this.size = 22,
    this.color,
    this.selected = false,
  });

  final LifeGlyph glyph;
  final double size;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _LifeGlyphPainter(
      glyph: glyph,
      color: color ?? context.appMuted,
      accent: Theme.of(context).colorScheme.primary,
      selected: selected,
    ),
  );
}

class _LifeGlyphPainter extends CustomPainter {
  const _LifeGlyphPainter({
    required this.glyph,
    required this.color,
    required this.accent,
    required this.selected,
  });

  final LifeGlyph glyph;
  final Color color;
  final Color accent;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (selected ? 1.9 : 1.65) * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset p(double x, double y) => Offset(x * scale, y * scale);
    RRect rr(double l, double t, double r, double b, double radius) =>
        RRect.fromRectAndRadius(
          Rect.fromLTRB(l * scale, t * scale, r * scale, b * scale),
          Radius.circular(radius * scale),
        );

    switch (glyph) {
      case LifeGlyph.goals:
        final rect = Rect.fromCircle(center: p(12, 12), radius: 8 * scale);
        canvas.drawArc(rect, -.52, 1.52, false, paint);
        canvas.drawArc(rect, 1.28, 1.62, false, paint);
        canvas.drawArc(rect, 3.2, 1.35, false, paint);
        canvas.drawCircle(p(18.6, 17.8), 1.35 * scale, Paint()..color = accent);
      case LifeGlyph.today:
        canvas.drawRRect(rr(4, 5.5, 20, 20, 2.8), paint);
        canvas.drawLine(p(4, 10), p(20, 10), paint);
        canvas.drawLine(p(8, 3.8), p(8, 7), paint);
        canvas.drawLine(p(16, 3.8), p(16, 7), paint);
        canvas.drawCircle(p(12, 15), 1.35 * scale, Paint()..color = accent);
      case LifeGlyph.tasks:
        canvas.drawCircle(
          p(12, 12),
          8 * scale,
          selected ? (Paint()..color = accent) : paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8 * scale, 12 * scale)
            ..lineTo(11 * scale, 15 * scale)
            ..lineTo(17 * scale, 9 * scale),
          selected
              ? (Paint()
                  ..color = const Color(0xFF192024)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.6 * scale
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round)
              : paint,
        );
      case LifeGlyph.calendar:
        canvas.drawRRect(rr(4, 5.5, 20, 20, 2.8), paint);
        canvas.drawLine(p(4, 10), p(20, 10), paint);
        canvas.drawLine(p(8, 3.8), p(8, 7), paint);
        canvas.drawLine(p(16, 3.8), p(16, 7), paint);
        for (final point in [
          p(8, 14),
          p(12, 14),
          p(16, 14),
          p(8, 17),
          p(12, 17),
          p(16, 17),
        ]) {
          canvas.drawCircle(point, .65 * scale, Paint()..color = color);
        }
      case LifeGlyph.more:
        for (final x in [7.0, 12.0, 17.0]) {
          canvas.drawCircle(p(x, 12), 1.25 * scale, Paint()..color = color);
        }
      case LifeGlyph.spaces:
        canvas.drawCircle(p(9, 9), 3 * scale, paint);
        canvas.drawCircle(p(16.5, 10), 2.3 * scale, paint);
        canvas.drawArc(
          Rect.fromLTRB(3 * scale, 13 * scale, 15 * scale, 22 * scale),
          math.pi,
          math.pi,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromLTRB(12 * scale, 14 * scale, 22 * scale, 21 * scale),
          math.pi,
          math.pi,
          false,
          paint,
        );
      case LifeGlyph.sparkle:
        canvas.drawPath(
          Path()
            ..moveTo(12 * scale, 3 * scale)
            ..lineTo(13.8 * scale, 9.8 * scale)
            ..lineTo(21 * scale, 12 * scale)
            ..lineTo(13.8 * scale, 14.2 * scale)
            ..lineTo(12 * scale, 21 * scale)
            ..lineTo(10.2 * scale, 14.2 * scale)
            ..lineTo(3 * scale, 12 * scale)
            ..lineTo(10.2 * scale, 9.8 * scale)
            ..close(),
          paint,
        );
      case LifeGlyph.settings:
        canvas.drawCircle(p(12, 12), 3 * scale, paint);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            p(12 + 6 * math.cos(a), 12 + 6 * math.sin(a)),
            p(12 + 8 * math.cos(a), 12 + 8 * math.sin(a)),
            paint,
          );
        }
      case LifeGlyph.file:
        canvas.drawPath(
          Path()
            ..moveTo(6 * scale, 3 * scale)
            ..lineTo(15 * scale, 3 * scale)
            ..lineTo(19 * scale, 7 * scale)
            ..lineTo(19 * scale, 21 * scale)
            ..lineTo(6 * scale, 21 * scale)
            ..close()
            ..moveTo(15 * scale, 3 * scale)
            ..lineTo(15 * scale, 7 * scale)
            ..lineTo(19 * scale, 7 * scale),
          paint,
        );
        canvas.drawLine(p(9, 12), p(16, 12), paint);
        canvas.drawLine(p(9, 16), p(15, 16), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LifeGlyphPainter oldDelegate) =>
      glyph != oldDelegate.glyph ||
      color != oldDelegate.color ||
      accent != oldDelegate.accent ||
      selected != oldDelegate.selected;
}

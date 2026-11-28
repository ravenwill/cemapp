import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fundo global liso (cor da superfície de página).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.background,
        child: child,
      );
}

/// Cartão de superfície (nome mantido por compatibilidade).
/// Com [onTap], ganha ripple e um leve "afundar" ao pressionar.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.color,
    this.radius = 16,
    this.blur = 0,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double radius;
  final double blur;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    Widget body = Material(
      type: MaterialType.transparency,
      child: widget.onTap == null
          ? widget.child
          : InkWell(
              borderRadius: r,
              onTap: widget.onTap,
              onHighlightChanged: (v) => setState(() => _down = v),
              child: widget.child,
            ),
    );
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      clipBehavior: widget.clipBehavior,
      decoration: BoxDecoration(
        borderRadius: r,
        color: widget.color ?? AppColors.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.dark
            ? null
            : const [
                BoxShadow(
                    color: Color(0x0D0F1D2E), offset: Offset(0, 1), blurRadius: 3),
              ],
      ),
      child: body,
    );
    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: widget.onTap == null
          ? box
          : AnimatedScale(
              scale: _down ? .985 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: box,
            ),
    );
  }
}

/// Barra inferior colada na base, com linha fina no topo.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(top: false, child: child),
      );
}

/// Selo da CEM: círculo preto com os anéis brancos desenhados à mão.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96, this.background = Colors.black, this.stroke = Colors.white});
  final double size;
  final Color background;
  final Color stroke;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MarkPainter(background, stroke)),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.bg, this.stroke);
  final Color bg;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    if (bg.a > 0) canvas.drawCircle(s.center(Offset.zero), w / 2, Paint()..color = bg);
    final p = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    void oval(double cx, double cy, double ow, double oh, double rot) {
      canvas.save();
      canvas.translate(w * cx, w * cy);
      canvas.rotate(rot);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: w * ow, height: w * oh), p);
      canvas.restore();
    }

    oval(0.50, 0.52, 0.80, 0.72, -0.03 * math.pi);
    oval(0.50, 0.50, 0.80, 0.70, 0.04 * math.pi);
    oval(0.53, 0.50, 0.53, 0.60, 0);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.bg != bg || old.stroke != stroke;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'glass.dart';
import 'ui.dart';

/// Fonte condensada usada na versao "site" (desktop).
TextStyle siteFont(double size, FontWeight w,
        {Color? color, double spacing = 0, double? height}) =>
    GoogleFonts.barlowCondensed(
        fontSize: size,
        fontWeight: w,
        color: color ?? AppColors.siteInk,
        letterSpacing: spacing,
        height: height);

/// Hero de site: palavra em caixa, titulo em tres pesos, texto, botoes em
/// pilula e uma foto em arco com decoracao geometrica fina.
class SiteHero extends StatelessWidget {
  const SiteHero({
    super.key,
    required this.tag,
    required this.light,
    required this.bold,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.imageUrl,
  });
  final String tag;
  final String light;
  final String bold;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final big = (c.maxWidth / 1120 * 88).clamp(52.0, 88.0).toDouble();
        final ink = AppColors.siteInk;
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 640,
            color: AppColors.siteBg,
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _DecoPainter(ink))),
              Positioned(
                  top: 0,
                  left: 0,
                  child: Container(width: c.maxWidth * .36, height: 12, color: ink)),
              Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(width: c.maxWidth * .24, height: 44, color: ink)),
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 40, 40, 56),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: AppColors.siteAccent,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                          child: Text(tag,
                              style: siteFont(big * .7, FontWeight.w800,
                                  color: AppColors.siteOnAccent, height: 1.15)),
                        ),
                        const SizedBox(height: 14),
                        Text(light,
                            style: siteFont(big * 1.05, FontWeight.w300,
                                spacing: 2, height: 1.0)),
                        Text(bold,
                            style: siteFont(big * 1.05, FontWeight.w800, height: 1.0)),
                        const SizedBox(height: 22),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Text(body,
                              style: siteFont(19, FontWeight.w400,
                                  spacing: .8, height: 1.5)),
                        ),
                        const SizedBox(height: 28),
                        Wrap(spacing: 14, runSpacing: 12, children: [
                          _Pill(label: primaryLabel, onTap: onPrimary, filled: true),
                          if (secondaryLabel != null && onSecondary != null)
                            _Pill(
                                label: secondaryLabel!,
                                onTap: onSecondary!,
                                filled: false),
                        ]),
                      ],
                    ),
                  ),
                  Expanded(flex: 5, child: _Arch(imageUrl: imageUrl)),
                ]),
              ),
            ]),
          ),
        );
      });
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, required this.filled});
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.siteInk;
    return Material(
      color: filled ? AppColors.siteAccent : Colors.transparent,
      shape: StadiumBorder(
          side: filled ? BorderSide.none : BorderSide(color: ink, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 58,
          constraints: const BoxConstraints(minWidth: 190),
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Center(
            widthFactor: 1,
            child: Text(label,
                style: siteFont(22, FontWeight.w600,
                    color: filled ? AppColors.siteOnAccent : ink, spacing: .5)),
          ),
        ),
      ),
    );
  }
}

class _Arch extends StatelessWidget {
  const _Arch({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final aw = math.min(c.maxWidth * .8, 400.0);
        final ah = math.min(aw * 1.28, 500.0);
        final r = Radius.circular(aw / 2);
        final hasImg = imageUrl != null && imageUrl!.isNotEmpty;
        return Center(
          child: SizedBox(
            width: aw + 70,
            height: ah + 40,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                right: -6,
                top: 44,
                child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.siteAccent)),
              ),
              Positioned(
                left: -14,
                bottom: 70,
                child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xCCD8A27E))),
              ),
              Positioned(
                left: 8,
                top: 0,
                child: Container(
                  width: aw + 28,
                  height: ah + 28,
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: AppColors.siteInk.withValues(alpha: .8)),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(aw / 2 + 14),
                        topRight: Radius.circular(aw / 2 + 14)),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                top: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(topLeft: r, topRight: r),
                  child: SizedBox(
                    width: aw,
                    height: ah,
                    child: hasImg
                        ? Image.network(imageUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallback())
                        : _fallback(),
                  ),
                ),
              ),
            ]),
          ),
        );
      });

  Widget _fallback() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.dark
                  ? const [Color(0xFF4A3B2F), Color(0xFF2E241D)]
                  : [AppColors.siteAccent, AppColors.siteInk]),
        ),
        alignment: Alignment.center,
        child: const BrandMark(size: 120, background: Colors.transparent, stroke: Color(0xFFFDF0E4)),
      );
}

class _DecoPainter extends CustomPainter {
  _DecoPainter(this.ink);
  final Color ink;

  void _spark(Canvas c, Offset o, double r, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    c.drawPath(path, p);
  }

  void _burst(Canvas c, Offset o, double r0, double r1, int n, Paint p) {
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      c.drawLine(o + Offset(math.cos(a), math.sin(a)) * r0,
          o + Offset(math.cos(a), math.sin(a)) * r1, p);
    }
  }

  void _dots(Canvas c, Offset o, int cols, int rows, double gap, Paint p) {
    for (var x = 0; x < cols; x++) {
      for (var y = 0; y < rows; y++) {
        c.drawCircle(o + Offset(x * gap, y * gap), 1.8, p);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size s) {
    Offset p(double x, double y) => Offset(s.width * x, s.height * y);
    final line = Paint()
      ..color = ink.withValues(alpha: .75)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = ink;
    final peach = Paint()..color = const Color(0xFFD8A27E);

    _spark(canvas, p(.30, .13), 24, fill);
    _spark(canvas, p(.245, .085), 11, peach);
    _burst(canvas, p(.505, .30), 8, 64, 20, line);
    _dots(canvas, p(.45, .05), 1, 5, 12, fill);
    _dots(canvas, p(.58, .72), 2, 4, 14, fill);
    _dots(canvas, p(.36, .90), 5, 2, 14, fill);
    _spark(canvas, p(.555, .83), 20, fill);
    _spark(canvas, p(.505, .86), 9, fill);
    canvas.drawLine(p(.60, .96), p(.68, .80), line);
    canvas.drawLine(p(.50, .42), p(.585, .58), line);
    canvas.drawLine(p(.31, .955), p(.52, .955), line);
    _spark(canvas, p(.965, .17), 14, fill);
    _burst(canvas, p(.975, .80), 6, 40, 14, Paint()
      ..color = const Color(0xFFD8A27E)
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _DecoPainter old) => old.ink != ink;
}

/// Botao redondo discreto com icone (Instagram etc.).
class SiteSocialDot extends StatelessWidget {
  const SiteSocialDot(
      {super.key, required this.icon, required this.url, required this.label});
  final IconData icon;
  final String url;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            shape: CircleBorder(
                side: BorderSide(
                    color: AppColors.siteInk.withValues(alpha: .16))),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication),
              child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon, size: 18, color: AppColors.siteInk)),
            ),
          ),
        ),
      );
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

const kEase = Curves.easeOutCubic;

bool _reduced(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;

// ───────────────────────────── Loading: shimmer + bones ─────────────────────

/// Faixa de brilho que atravessa todos os [Bone] filhos de uma vez.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return widget.child;
    final hi = AppColors.dark
        ? Colors.white.withValues(alpha: .07)
        : Colors.white.withValues(alpha: .75);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) {
          final dx = (_c.value * 2.4 - .7) * r.width;
          return LinearGradient(
            colors: [Colors.transparent, hi, Colors.transparent],
            stops: const [0, .5, 1],
            transform: _Slide(dx),
          ).createShader(Rect.fromLTWH(0, 0, r.width * .6, r.height));
        },
        child: child,
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.dx);
  final double dx;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

class Bone extends StatelessWidget {
  const Bone({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Esqueleto de lista de cartões (linha com avatar + duas linhas de texto).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.height = 72});
  final int count;
  final double height;
  @override
  Widget build(BuildContext context) => Shimmer(
        child: Column(children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      const Bone(width: 44, height: 44, radius: 12),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Bone(
                                width: 120 + (i % 3) * 36.0,
                                height: 13),
                            const SizedBox(height: 9),
                            const Bone(width: 80, height: 11),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// Troca suave entre esqueleto e conteúdo.
class LoadSwitch extends StatelessWidget {
  const LoadSwitch(
      {super.key,
      required this.loading,
      required this.skeleton,
      required this.child});
  final bool loading;
  final Widget skeleton;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: kEase,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (cur, prev) => Stack(
          alignment: Alignment.topCenter,
          children: [...prev, if (cur != null) cur],
        ),
        child: loading
            ? KeyedSubtree(key: const ValueKey('sk'), child: skeleton)
            : KeyedSubtree(key: const ValueKey('ct'), child: child),
      );
}

// ───────────────────────────── Motion ───────────────────────────────────────

/// Entrada escalonada: sobe 14px e aparece. [index] define o atraso.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 460));
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(Duration(milliseconds: 40 * math.min(widget.index, 9)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return widget.child;
    final a = CurvedAnimation(parent: _c, curve: kEase);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(a),
        child: widget.child,
      ),
    );
  }
}

/// Anima de 0 até [value] (contadores, valores em R$).
class CountUp extends StatelessWidget {
  const CountUp(
      {super.key, required this.value, required this.builder, this.ms = 700});
  final double value;
  final int ms;
  final Widget Function(double v) builder;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: Duration(milliseconds: _reduced(context) ? 0 : ms),
        curve: kEase,
        builder: (_, v, __) => builder(v),
      );
}

// ───────────────────────────── Building blocks ──────────────────────────────

/// Cabeçalho de página: título + ações (tema e perfil). Sem sobretítulo.
class PageHeader extends StatelessWidget {
  const PageHeader(
      {super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final desk = MediaQuery.sizeOf(context).width >= 1024;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, desk ? 36 : 20, 0, desk ? 24 : 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: (desk ? t.headlineMedium : t.headlineSmall)?.copyWith(
                    fontWeight: FontWeight.w800, letterSpacing: -.4)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: t.bodyMedium
                      ?.copyWith(color: AppColors.mutedForeground, height: 1.4)),
            ],
          ]),
        ),
        for (final a in actions) ...[const SizedBox(width: 10), a],
      ]),
    );
  }
}

/// Botão quadrado arredondado que alterna claro/escuro com troca de ícone.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});
  @override
  Widget build(BuildContext context) => GlassCard(
        radius: 12,
        child: SizedBox(
          width: 42,
          height: 42,
          child: IconButton(
            tooltip: AppColors.dark ? 'Modo claro' : 'Modo escuro',
            onPressed: ThemeController.instance.toggle,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (c, a) => RotationTransition(
                  turns: Tween(begin: .75, end: 1.0).animate(a),
                  child: FadeTransition(opacity: a, child: c)),
              child: Icon(
                AppColors.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                key: ValueKey(AppColors.dark),
                size: 20,
              ),
            ),
          ),
        ),
      );
}

const _avatarHues = [0xFF2B6CA3, 0xFF7A4B4B, 0xFF4B6B4F, 0xFF3F5E8C, 0xFF6B4B7A, 0xFF3F6B6B];

String initialsOf(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 40});
  final String name;
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final hue = Color(_avatarHues[name.hashCode.abs() % _avatarHues.length]);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hue,
        shape: BoxShape.circle,
        image: url == null
            ? null
            : DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover),
      ),
      child: url == null
          ? Text(initialsOf(name),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: size * .36,
                  fontWeight: FontWeight.w700))
          : null,
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label,
      {super.key, this.fg, this.bg, this.icon, this.dense = false});
  final String label;
  final Color? fg;
  final Color? bg;
  final IconData? icon;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final c = fg ?? AppColors.secondary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: bg ?? AppColors.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
        Text(label,
            style: TextStyle(
                color: c,
                fontSize: dense ? 12.5 : 13,
                fontWeight: FontWeight.w700,
                letterSpacing: .1)),
      ]),
    );
  }
}

/// Bloco de data (DIA + MÊS), usado em listas de eventos.
class DateBlock extends StatelessWidget {
  const DateBlock(this.d, {super.key, this.size = 48, this.highlight = false});
  final DateTime d;
  final double size;
  final bool highlight;
  static const meses = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primarySoft : AppColors.navySoft,
          borderRadius: BorderRadius.circular(12),
          border: highlight
              ? Border.all(color: AppColors.primary.withAlpha(140))
              : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${d.day}',
              style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 17,
                  height: 1.1,
                  fontWeight: FontWeight.w800)),
          Text(meses[d.month - 1],
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.message,
      this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
              color: AppColors.navySoft, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: AppColors.mutedForeground, size: 26),
        ),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!,
              textAlign: TextAlign.center,
              style: t.bodyMedium
                  ?.copyWith(color: AppColors.mutedForeground, height: 1.45)),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Não deu para carregar',
        message: message,
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar de novo')),
      );
}

String two(int n) => n.toString().padLeft(2, '0');

const diasSemana = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
const mesesLongo = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
];

String relDay(DateTime d) {
  final hoje = DateTime.now();
  final dias = DateTime(d.year, d.month, d.day)
      .difference(DateTime(hoje.year, hoje.month, hoje.day))
      .inDays;
  if (dias == 0) return 'Hoje';
  if (dias == 1) return 'Amanhã';
  if (dias == -1) return 'Ontem';
  if (dias > 1) return 'Em $dias dias';
  return 'Há ${-dias} dias';
}

String ago(DateTime d) {
  final s = DateTime.now().difference(d);
  if (s.inMinutes < 1) return 'agora';
  if (s.inMinutes < 60) return 'há ${s.inMinutes} min';
  if (s.inHours < 24) return 'há ${s.inHours} h';
  if (s.inDays < 7) return 'há ${s.inDays} d';
  return '${two(d.day)}/${two(d.month)}';
}

String brl(num v) =>
    'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

/// Folha modal padrão para formulários.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: builder(c),
      ),
    );

void toast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
}

/// Lista de abas lazy: cada aba só é construída ao ser aberta e fica viva.
class LazyTabs extends StatefulWidget {
  const LazyTabs({super.key, required this.index, required this.builders});
  final int index;
  final List<WidgetBuilder> builders;
  @override
  State<LazyTabs> createState() => _LazyTabsState();
}

class _LazyTabsState extends State<LazyTabs> {
  final _seen = <int>{};
  @override
  Widget build(BuildContext context) {
    _seen.add(widget.index);
    return Stack(children: [
      for (var i = 0; i < widget.builders.length; i++)
        Offstage(
          offstage: i != widget.index,
          child: TickerMode(
            enabled: i == widget.index,
            child: _seen.contains(i)
                ? _FadeIn(
                    active: i == widget.index, child: widget.builders[i](context))
                : const SizedBox.shrink(),
          ),
        ),
    ]);
  }
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  @override
  void initState() {
    super.initState();
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(covariant _FadeIn old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: kEase);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .015), end: Offset.zero).animate(a),
        child: widget.child,
      ),
    );
  }
}

/// Abas em pílula com indicador deslizante.
class SegTabs extends StatelessWidget {
  const SegTabs(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / n;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: kEase,
            left: index * w,
            width: w,
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withAlpha(110)),
                boxShadow: AppColors.dark
                    ? null
                    : const [
                        BoxShadow(
                            color: Color(0x140F1D2E),
                            offset: Offset(0, 1),
                            blurRadius: 3)
                      ],
              ),
            ),
          ),
          Row(children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onChanged(i),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                          fontSize: 14,
                          fontWeight: i == index ? FontWeight.w700 : FontWeight.w600,
                          color: i == index
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                        ),
                        child: Text(labels[i]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}


/// Converte erros técnicos em mensagens curtas e acionáveis em português.
String friendlyError(Object e) {
  final s = '$e'.toLowerCase();
  if (s.contains('socket') ||
      s.contains('network') ||
      s.contains('failed host') ||
      s.contains('clientexception') ||
      s.contains('failed to fetch')) {
    return 'Sem conexão. Verifique a internet e tente de novo.';
  }
  if (s.contains('permission') ||
      s.contains('row-level') ||
      s.contains('42501') ||
      s.contains('403')) {
    return 'Você não tem permissão para fazer isso.';
  }
  return 'Algo deu errado. Tente de novo em instantes.';
}

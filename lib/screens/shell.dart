import 'package:flutter/material.dart';

import '../core/permissions.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/site_hero.dart';
import '../widgets/ui.dart';
import 'admin_screen.dart';
import 'agenda_screen.dart';
import 'avisos_screen.dart';
import 'home_screen.dart';
import 'louvor_screen.dart';
import 'biblia_screen.dart';
import 'midia_screen.dart';
import 'perfil_screen.dart';
import 'public_home.dart';
import 'oracao_screen.dart';
import 'yakisoba_screen.dart';

/// Casca do app: o menu mostra só o que o usuário tem permissão de ver.
/// Celular: barra inferior. Tela larga: menu lateral.
/// As páginas são criadas só na primeira visita e mantidas vivas.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.session});
  final AppSession session;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Feature? _current;
  final _visited = <Feature?>{null};
  final _pages = <Feature?, Widget>{};

  void _goTo(Feature? f) {
    setState(() {
      _current = f;
      _visited.add(f);
    });
  }

  Widget _build(Feature? f) {
    switch (f) {
      case null:
        return HomeScreen(session: widget.session, onOpen: _goTo);
      case Feature.igreja:
        return PublicHome(session: widget.session);
      case Feature.biblia:
        return const BibliaScreen(embedded: true);
      case Feature.eventos:
      case Feature.mensagens:
      case Feature.devocional:
      case Feature.aovivo:
        return publicModulePage(f!);
      case Feature.midia:
        return MidiaScreen(session: widget.session);
      case Feature.louvor:
        return const LouvorScreen();
      case Feature.agenda:
        return const AgendaScreen();
      case Feature.avisos:
        return const AvisosScreen();
      case Feature.yakisoba:
        return YakisobaScreen(session: widget.session);
      case Feature.oracao:
        return OracaoScreen(session: widget.session);
      case Feature.admin:
        return AdminScreen(session: widget.session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user!;
    final items = <Feature?>[null, ...Feature.values.where(user.can)];
    if (!items.contains(_current)) _current = null;

    final dests = [
      for (final f in items)
        _Dest(f, f?.label ?? 'Início', f?.icon ?? Icons.home_outlined,
            f?.selectedIcon ?? Icons.home),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 1024;

    final stack = Stack(children: [
      for (final f in items)
        Offstage(
          offstage: f != _current,
          child: TickerMode(
            enabled: f == _current,
            child: _visited.contains(f)
                ? _PageHost(
                    active: f == _current,
                    child: _pages.putIfAbsent(f, () => _build(f)),
                  )
                : const SizedBox.shrink(),
          ),
        ),
    ]);

    final body = SessionScope(session: widget.session, child: stack);

    if (wide) {
      return Scaffold(
        body: Column(children: [
          _WebBar(
              dests: dests,
              current: _current,
              onTap: _goTo,
              session: widget.session),
          Expanded(child: body),
        ]),
      );
    }

    final overflow = dests.length > 5;
    final main = overflow ? dests.take(4).toList() : dests;
    final rest = overflow ? dests.skip(4).toList() : <_Dest>[];
    final restSelected = rest.any((d) => d.f == _current);

    return Scaffold(
      body: body,
      bottomNavigationBar: GlassBar(
        child: Row(children: [
          for (final d in main)
            Expanded(
              child: _NavItem(
                dest: d,
                selected: d.f == _current,
                onTap: () => _goTo(d.f),
              ),
            ),
          if (overflow)
            Expanded(
              child: _NavItem(
                dest: _Dest(null, 'Mais', Icons.more_horiz, Icons.more_horiz),
                selected: restSelected,
                onTap: () => _more(rest),
              ),
            ),
        ]),
      ),
    );
  }

  void _more(List<_Dest> rest) {
    showAppSheet(context, (c) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final d in rest)
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Icon(d.f == _current ? d.selected : d.icon,
                    color: d.f == _current
                        ? AppColors.primary
                        : AppColors.secondary),
                title: Text(d.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                selected: d.f == _current,
                selectedTileColor: AppColors.navySoft,
                onTap: () {
                  Navigator.of(c).pop();
                  _goTo(d.f);
                },
              ),
          ]),
        ),
      );
    });
  }
}

class _Dest {
  _Dest(this.f, this.label, this.icon, this.selected);
  final Feature? f;
  final String label;
  final IconData icon;
  final IconData selected;
}

/// Mantém a página viva e faz um fade curto sempre que ela volta ao primeiro plano.
class _PageHost extends StatefulWidget {
  const _PageHost({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<_PageHost> createState() => _PageHostState();
}

class _PageHostState extends State<_PageHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(covariant _PageHost old) {
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
        position:
            Tween(begin: const Offset(0, .012), end: Offset.zero).animate(a),
        child: widget.child,
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.dests, required this.current, required this.onTap});
  final List<_Dest> dests;
  final Feature? current;
  final ValueChanged<Feature?> onTap;

  @override
  Widget build(BuildContext context) => Container(
        width: 112,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 20),
            const BrandMark(size: 46),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final d in dests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _RailItem(
                          dest: d, selected: d.f == current, onTap: () => onTap(d.f)),
                    ),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.dest, required this.selected, required this.onTap});
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: dest.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: kEase,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.navySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? dest.selected : dest.icon,
                  key: ValueKey(selected),
                  size: 24,
                  color: selected ? AppColors.primary : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 5),
              Text(dest.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.foreground
                          : AppColors.mutedForeground)),
            ]),
          ),
        ),
      );
}

/// Item da barra inferior: pílula suave atrás do ícone quando selecionado.
class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.dest, required this.selected, required this.onTap});
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = selected ? AppColors.primary : AppColors.mutedForeground;
    return Semantics(
      button: true,
      selected: selected,
      label: dest.label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 62,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: kEase,
              width: selected ? 56 : 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(selected ? dest.selected : dest.icon, color: c, size: 23),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                  color: selected ? AppColors.foreground : AppColors.mutedForeground,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
              child: Text(dest.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Barra de navegacao de site (desktop): marca, links em fonte condensada,
/// Instagram, tema e perfil. O que nao cabe vai para o menu "Mais".
class _WebBar extends StatelessWidget {
  const _WebBar(
      {required this.dests,
      required this.current,
      required this.onTap,
      required this.session});
  final List<_Dest> dests;
  final Feature? current;
  final ValueChanged<Feature?> onTap;
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final maxInline = w >= 1400 ? 9 : (w >= 1200 ? 7 : 5);
    final inline = dests.take(maxInline).toList();
    final rest = dests.skip(maxInline).toList();
    final restSelected = rest.any((d) => d.f == current);
    final u = session.user!;
    return Material(
      color: AppColors.background,
      child: Container(
        height: 76,
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1168),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(null),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      const BrandMark(size: 40),
                      const SizedBox(width: 10),
                      Text('CEM PERU\u00cdBE',
                          style: siteFont(26, FontWeight.w800, spacing: .5)),
                    ]),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Row(children: [
                    for (final d in inline)
                      _WebLink(
                          label: d.label,
                          selected: d.f == current,
                          onTap: () => onTap(d.f)),
                    if (rest.isNotEmpty)
                      PopupMenuButton<Feature?>(
                        tooltip: 'Mais',
                        color: AppColors.card,
                        onSelected: onTap,
                        itemBuilder: (_) => [
                          for (final d in rest)
                            PopupMenuItem<Feature?>(
                              value: d.f,
                              child: Row(children: [
                                Icon(d.icon,
                                    size: 20,
                                    color: d.f == current
                                        ? AppColors.primary
                                        : AppColors.secondary),
                                const SizedBox(width: 12),
                                Text(d.label,
                                    style: siteFont(18, FontWeight.w500,
                                        spacing: .5)),
                              ]),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Mais',
                                style: siteFont(
                                    19,
                                    restSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    spacing: .6,
                                    color: restSelected
                                        ? AppColors.primary
                                        : AppColors.siteInk)),
                            Icon(Icons.expand_more,
                                size: 18, color: AppColors.siteInk),
                          ]),
                        ),
                      ),
                  ]),
                ),
                const SiteSocialDot(
                    icon: Icons.photo_camera_outlined,
                    url: 'https://www.instagram.com/cemchurchperuibe/',
                    label: 'Instagram'),
                const SizedBox(width: 14),
                const ThemeToggle(),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'Meu perfil',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PerfilScreen(session: session))),
                    child: Avatar(name: u.name, url: u.avatarUrl, size: 40),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebLink extends StatelessWidget {
  const _WebLink(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  maxLines: 1,
                  style: siteFont(
                      19, selected ? FontWeight.w700 : FontWeight.w500,
                      spacing: .6)),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: kEase,
                height: 3,
                width: selected ? 24 : 0,
                decoration: BoxDecoration(
                    color: AppColors.siteAccent,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ]),
          ),
        ),
      );
}
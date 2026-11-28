import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/permissions.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/section.dart';
import '../widgets/site_hero.dart';
import '../widgets/ui.dart';

final _db = Supabase.instance.client;

/// Início: próximo culto, pedido de yakisoba aberto, agenda, avisos e aniversários.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session, required this.onOpen});
  final AppSession session;
  final ValueChanged<Feature?> onOpen;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _avisos = [];
  List<Map<String, dynamic>> _aniv = [];
  Map<String, dynamic>? _yaki;
  bool _loading = true;

  AppUser get _u => widget.session.user!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T> _safe<T>(Future<T> f, T fallback) async {
    try {
      return await f;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _load() async {
    final limit =
        DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String();
    final res = await Future.wait([
      _safe<List>(
          _db
              .from('church_events')
              .select()
              .gte('starts_at', limit)
              .order('starts_at', ascending: true)
              .limit(200),
          []),
      _safe<List>(
          _db
              .from('announcements')
              .select('title,body,tag,created_at')
              .order('created_at', ascending: false)
              .limit(3),
          []),
      _safe<List>(
          _db.from('profiles').select('name,birthday,avatar_url').not('birthday', 'is', null),
          []),
      _safe<List>(
          _db
              .from('yakisoba_campaigns')
              .select()
              .eq('status', 'aberta')
              .gt('order_deadline', DateTime.now().toUtc().toIso8601String())
              .order('sale_date')
              .limit(1),
          []),
    ]);
    // mais próximos primeiro; início mostra só o próximo culto + 3 encontros
    _events = (List<Map<String, dynamic>>.from(res[0])
          ..sort((a, b) => DateTime.parse(a['starts_at'])
              .compareTo(DateTime.parse(b['starts_at']))))
        .take(4)
        .toList();
    _avisos = List<Map<String, dynamic>>.from(res[1]);
    final m = DateTime.now().month;
    _aniv = List<Map<String, dynamic>>.from(res[2])
        .where((p) => DateTime.parse(p['birthday']).month == m)
        .toList()
      ..sort((a, b) => DateTime.parse(a['birthday'])
          .day
          .compareTo(DateTime.parse(b['birthday']).day));
    final y = res[3];
    _yaki = y.isEmpty ? null : Map<String, dynamic>.from(y.first);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = _u;
    final first = user.name.split(' ').first;
    final pad = hPad(context);
    final desk = MediaQuery.sizeOf(context).width >= 1024;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, desk ? 24 : 0, pad, 32),
          children: [
            if (!desk)
              PageHeader(
                title: 'Paz do Senhor, $first',
                actions: const [HeaderActions()],
              ),
            LoadSwitch(
              loading: _loading,
              skeleton: const _HomeSkeleton(),
              child: _content(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppUser user) {
    var i = 0;
    Widget r(Widget w) => Reveal(index: i++, child: w);
    final quick = <Widget>[
      if (user.can(Feature.louvor))
        ActionTile(
            icon: Feature.louvor.icon,
            label: 'Louvor',
            subtitle: 'Escalas, equipe e repertório',
            onTap: () => widget.onOpen(Feature.louvor)),
      if (user.can(Feature.yakisoba))
        ActionTile(
            icon: Feature.yakisoba.icon,
            label: 'Yakisoba',
            subtitle: 'Peça o da próxima venda',
            onTap: () => widget.onOpen(Feature.yakisoba)),
      if (user.can(Feature.oracao))
        ActionTile(
            icon: Feature.oracao.icon,
            label: 'Oração',
            subtitle: 'Pedidos e intercessão',
            onTap: () => widget.onOpen(Feature.oracao)),
      ActionTile(
          icon: Feature.eventos.icon,
          label: 'Eventos',
          subtitle: 'Pr\u00f3ximos encontros',
          onTap: () => widget.onOpen(Feature.eventos)),
      ActionTile(
          icon: Feature.mensagens.icon,
          label: 'Mensagens',
          subtitle: 'Cultos e pregações',
          onTap: () => widget.onOpen(Feature.mensagens)),
      ActionTile(
          icon: Feature.devocional.icon,
          label: 'Devocional',
          subtitle: 'Palavra do dia',
          onTap: () => widget.onOpen(Feature.devocional)),
      ActionTile(
          icon: Feature.aovivo.icon,
          label: 'Ao vivo',
          subtitle: 'Transmissão no YouTube',
          onTap: () => widget.onOpen(Feature.aovivo)),
      ActionTile(
          icon: Feature.biblia.icon,
          label: 'B\u00edblia',
          subtitle: 'ARC, com busca',
          onTap: () => widget.onOpen(Feature.biblia)),
      if (user.can(Feature.agenda))
        ActionTile(
            icon: Feature.agenda.icon,
            label: 'Agenda',
            subtitle: 'Cultos e eventos',
            onTap: () => widget.onOpen(Feature.agenda)),
    ];
    final desk0 = MediaQuery.sizeOf(context).width >= 1024;
    final heroW = <Widget>[r(desk0 ? _siteHero(user) : _hero())];
    final yakiW = <Widget>[
      if (_yaki != null && user.can(Feature.yakisoba)) ...[
        const SizedBox(height: 14),
        r(_yakiBanner(_yaki!)),
      ],
    ];
    final eventsW = <Widget>[
      if (_events.length > 1) ...[
        r(SectionTitle('Próximos encontros',
            trailing: user.can(Feature.agenda)
                ? TextButton(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.primary),
                    onPressed: () => widget.onOpen(Feature.agenda),
                    child: const Text('Ver agenda'))
                : null)),
        r(GlassCard(
          child: Column(children: [
            for (var k = 1; k < _events.length; k++) ...[
              if (k > 1) Divider(height: 1, color: AppColors.border),
              _eventRow(_events[k]),
            ],
          ]),
        )),
      ],
    ];
    final avisosW = <Widget>[
      r(SectionTitle('Avisos recentes',
          trailing: user.can(Feature.avisos)
              ? TextButton(
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero),
                  onPressed: () => widget.onOpen(Feature.avisos),
                  child: const Text('Ver todos'))
              : null)),
      if (_avisos.isEmpty)
        r(const GlassCard(
            child: EmptyState(
                icon: Icons.campaign_outlined, title: 'Nenhum aviso por enquanto')))
      else
        for (final a in _avisos) r(_aviso(a)),
    ];
    final anivW = <Widget>[
      r(SectionTitle('Aniversariantes do mês',
          trailing: Text(mesesLongo[DateTime.now().month - 1],
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.mutedForeground)))),
      if (_aniv.isEmpty)
        r(SizedBox(
            width: double.infinity,
            child: GlassCard(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.navySoft,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.cake_outlined,
                      color: AppColors.mutedForeground, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Sem aniversariantes cadastrados este mês',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ))))
      else
        r(Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in _aniv) _bday(p),
        ])),
    ];
    final quickW = <Widget>[
      if (quick.isNotEmpty) ...[
        r(const SectionTitle('Acesso rápido')),
        r(GridView.extent(
          maxCrossAxisExtent: 220,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: quick,
        )),
      ],
    ];
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    if (!desktop) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...heroW, ...yakiW, ...eventsW, ...avisosW, ...anivW, ...quickW,
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...heroW,
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [...eventsW, ...avisosW]),
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 2,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [...yakiW, ...anivW]),
        ),
      ]),
      ...quickW,
    ]);
  }

  Widget _siteHero(AppUser user) {
    final e = _events.isEmpty ? null : _events.first;
    final d = e == null ? null : DateTime.parse(e['starts_at']).toLocal();
    final first = user.name.split(' ').first;
    final body = e == null
        ? 'Paz do Senhor, $first! Nenhum culto agendado por enquanto.'
        : 'Paz do Senhor, $first! Pr\u00f3ximo culto: ${e['title']} \u00b7 ${diasSemana[d!.weekday - 1]}, ${d.day} de ${mesesLongo[d.month - 1]} \u00b7 ${two(d.hour)}h${two(d.minute)} (${relDay(d).toLowerCase()}).';
    final agenda = user.can(Feature.agenda);
    return SiteHero(
      tag: 'CEM PERU\u00cdBE',
      light: 'ENCONTRO',
      bold: 'COM CRISTO',
      body: body,
      primaryLabel: agenda ? 'Ver agenda' : 'Ver eventos',
      onPrimary: () =>
          widget.onOpen(agenda ? Feature.agenda : Feature.eventos),
      secondaryLabel: 'Ao vivo',
      onSecondary: () => widget.onOpen(Feature.aovivo),
    );
  }

  Widget _hero() {    final t = Theme.of(context).textTheme;
    final e = _events.isEmpty ? null : _events.first;
    final d = e == null ? null : DateTime.parse(e['starts_at']).toLocal();
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.dark ? const Color(0xFF173A5A) : const Color(0xFF1B3D61), AppColors.navyDeep],
        ),
        boxShadow: AppColors.dark
            ? null
            : const [
                BoxShadow(
                    color: Color(0x330F233A), offset: Offset(0, 10), blurRadius: 24),
              ],
      ),
      child: Stack(children: [
        Positioned(
          top: -54,
          right: -40,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .06)),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 1024 ? 48 : 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('PRÓXIMO CULTO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1)),
            ),
            const SizedBox(height: 16),
            if (e == null)
              Text('Nenhum culto agendado',
                  style: t.titleLarge?.copyWith(color: Colors.white))
            else ...[
              Text(e['title'],
                  style: (MediaQuery.sizeOf(context).width >= 1024 ? t.displaySmall : t.headlineSmall)?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3)),
              const SizedBox(height: 6),
              Text(
                  '${diasSemana[d!.weekday - 1]}, ${d.day} de ${mesesLongo[d.month - 1]} · ${two(d.hour)}h${two(d.minute)}',
                  style: t.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .88))),
              if (e['location'] != null) ...[
                const SizedBox(height: 3),
                Text('${e['location']}',
                    style: t.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: .7))),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(999)),
                child: Text(relDay(d),
                    style: const TextStyle(
                        color: Color(0xFF0F233A),
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _yakiBanner(Map<String, dynamic> c) {
    final t = Theme.of(context).textTheme;
    final sale = DateTime.parse(c['sale_date']);
    final dl = DateTime.parse(c['order_deadline']).toLocal();
    final price = (c['price'] as num).toDouble();
    return GlassCard(
      color: AppColors.primarySoft,
      onTap: () => widget.onOpen(Feature.yakisoba),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.ramen_dining, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pedidos de yakisoba abertos',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                  'Retirada ${diasSemana[sale.weekday - 1].toLowerCase()}, ${two(sale.day)}/${two(sale.month)} · pedidos até ${two(dl.day)}/${two(dl.month)} · ${brl(price)}',
                  style: t.bodySmall?.copyWith(
                      color: AppColors.secondary, height: 1.35)),
            ]),
          ),
          Icon(Icons.chevron_right, color: AppColors.primary),
        ]),
      ),
    );
  }

  Widget _eventRow(Map<String, dynamic> e) {
    final t = Theme.of(context).textTheme;
    final d = DateTime.parse(e['starts_at']).toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        DateBlock(d),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e['title'],
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
                '${diasSemana[d.weekday - 1]} · ${two(d.hour)}h${two(d.minute)}${e['location'] != null ? ' · ${e['location']}' : ''}',
                style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
          ]),
        ),
        Text(relDay(d),
            style: t.labelMedium?.copyWith(color: AppColors.mutedForeground)),
      ]),
    );
  }

  Widget _aviso(Map<String, dynamic> a) {
    final t = Theme.of(context).textTheme;
    final d = DateTime.parse(a['created_at']).toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Pill('${a['tag'] ?? 'Geral'}',
                  fg: AppColors.primary, bg: AppColors.primarySoft, dense: true),
              const Spacer(),
              Text(ago(d),
                  style: t.labelMedium?.copyWith(color: AppColors.mutedForeground)),
            ]),
            const SizedBox(height: 10),
            Text(a['title'] ?? '',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (a['body'] != null) ...[
              const SizedBox(height: 4),
              Text(a['body'],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                      color: AppColors.secondary, height: 1.45)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _bday(Map<String, dynamic> p) {
    final t = Theme.of(context).textTheme;
    final name = '${p['name'] ?? ''}';
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Avatar(name: name, url: p['avatar_url'], size: 30),
        const SizedBox(width: 8),
        Text(name.split(' ').first, style: t.bodyMedium),
        const SizedBox(width: 8),
        Text('${DateTime.parse(p['birthday']).day}',
            style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => Shimmer(
        child: Column(children: [
          Container(
            height: 168,
            decoration: BoxDecoration(
                color: AppColors.muted, borderRadius: BorderRadius.circular(22)),
          ),
          const SizedBox(height: 28),
          const Align(alignment: Alignment.centerLeft, child: Bone(width: 150, height: 12)),
          const SizedBox(height: 16),
          const SkeletonList(count: 4, height: 66),
        ]),
      );
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/section.dart';
import '../widgets/site_hero.dart';
import '../widgets/ui.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final from = DateTime.now().subtract(const Duration(hours: 4)).toUtc().toIso8601String();
      final r = await Supabase.instance.client
          .from('church_events')
          .select()
          .gte('starts_at', from)
          .order('starts_at');
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(r)
            ..sort((a, b) => DateTime.parse(a['starts_at'])
                .compareTo(DateTime.parse(b['starts_at'])));
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => AgendaView(
        items: _items,
        loading: _loading,
        error: _error,
        onRefresh: _load,
        header: const [HeaderActions()],
      );
}

/// Corpo da Agenda, separado dos dados para poder ser exibido com qualquer lista.
/// Celular: cartões agrupados por mês. Desktop (>= 1024): o próximo encontro em
/// destaque no painel areia do site e, abaixo, cada mês como uma linha do tempo
/// com o nome do mês à esquerda e os encontros à direita.
class AgendaView extends StatelessWidget {
  const AgendaView({
    super.key,
    required this.items,
    this.loading = false,
    this.error,
    required this.onRefresh,
    this.header = const [],
  });
  final List<Map<String, dynamic>> items;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final pad = hPad(context);
    final desk = MediaQuery.sizeOf(context).width >= 1024;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, desk ? 64 : 40),
          children: [
            PageHeader(
              title: 'Agenda',
              subtitle: 'Cultos, ensaios e encontros da igreja.',
              actions: header,
            ),
            LoadSwitch(
              loading: loading,
              skeleton: const SkeletonList(count: 5, height: 78),
              child: error != null
                  ? ErrorState(message: error!, onRetry: onRefresh)
                  : items.isEmpty
                      ? const EmptyState(
                          icon: Icons.event_outlined,
                          title: 'Nada agendado',
                          message: 'Quando houver novos encontros, eles aparecem aqui.')
                      : desk
                          ? _DeskAgenda(items: items)
                          : _MobileAgenda(items: items),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _at(Map<String, dynamic> e) => DateTime.parse(e['starts_at']).toLocal();

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Agrupa os encontros por mês, preservando a ordem.
Map<DateTime, List<Map<String, dynamic>>> _byMonth(List<Map<String, dynamic>> items) {
  final g = <DateTime, List<Map<String, dynamic>>>{};
  for (final e in items) {
    final d = _at(e);
    g.putIfAbsent(DateTime(d.year, d.month), () => []).add(e);
  }
  return g;
}

String _meta(Map<String, dynamic> e) {
  final d = _at(e);
  final loc = (e['location'] as String?)?.trim();
  return [
    diasSemana[d.weekday - 1],
    '${two(d.hour)}h${two(d.minute)}',
    if (loc != null && loc.isNotEmpty) loc,
  ].join(' · ');
}

// ───────────────────────── Celular ─────────────────────────

class _MobileAgenda extends StatelessWidget {
  const _MobileAgenda({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    var idx = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in _byMonth(items).entries) ...[
          SectionTitle('${mesesLongo[g.key.month - 1]} ${g.key.year}'),
          for (final e in g.value)
            Reveal(index: idx++, child: _card(t, e)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _card(TextTheme t, Map<String, dynamic> e) {
    final d = _at(e);
    final desc = e['description'] as String?;
    final hoje = relDay(d) == 'Hoje';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DateBlock(d, highlight: hoje),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e['title']}',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_meta(e),
                    style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc, style: t.bodySmall?.copyWith(height: 1.4)),
                ],
              ]),
            ),
            hoje
                ? Pill('Hoje',
                    dense: true, fg: AppColors.primary, bg: AppColors.primarySoft)
                : Pill(relDay(d), dense: true),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Desktop ─────────────────────────

class _DeskAgenda extends StatelessWidget {
  const _DeskAgenda({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final next = items.first;
    final rest = items.skip(1).toList();
    final months = _byMonth(rest).entries.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _NextPanel(e: next),
      for (var i = 0; i < months.length; i++) ...[
        SizedBox(height: i == 0 ? 48 : 40),
        _MonthBlock(month: months[i].key, items: months[i].value),
      ],
    ]);
  }
}

/// O próximo encontro, no painel areia do hero do site.
class _NextPanel extends StatelessWidget {
  const _NextPanel({required this.e});
  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.siteInk;
    final d = _at(e);
    final rel = relDay(d);
    final desc = (e['description'] as String?)?.trim() ?? '';
    final loc = (e['location'] as String?)?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
      decoration: BoxDecoration(
        color: AppColors.siteBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Data grande, no idioma do site.
        SizedBox(
          width: 148,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d.day}',
                style: siteFont(88, FontWeight.w800, height: .9)),
            Text(mesesLongo[d.month - 1].toUpperCase(),
                style: siteFont(24, FontWeight.w300, spacing: 2, height: 1.1)),
          ]),
        ),
        Container(
            width: 1, height: 112, color: ink.withValues(alpha: .25)),
        const SizedBox(width: 40),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e['title']}'.toUpperCase(),
                style: siteFont(48, FontWeight.w800, height: 1.0)),
            const SizedBox(height: 12),
            Text(
              [
                rel,
                '${diasSemana[d.weekday - 1]}, ${two(d.hour)}h${two(d.minute)}',
                if (loc.isNotEmpty) loc,
              ].join(' · '),
              style: siteFont(22, FontWeight.w400,
                  color: ink.withValues(alpha: .85), spacing: .4),
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(desc,
                    style: TextStyle(
                        fontSize: 15, height: 1.5, color: ink.withValues(alpha: .8))),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Um mês: nome à esquerda, encontros em linhas com fio entre elas.
class _MonthBlock extends StatelessWidget {
  const _MonthBlock({required this.month, required this.items});
  final DateTime month;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.only(top: 12, right: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_cap(mesesLongo[month.month - 1]),
                style: siteFont(36, FontWeight.w600,
                    color: AppColors.foreground, height: 1)),
            if (month.year != now.year)
              Text('${month.year}',
                  style: siteFont(20, FontWeight.w400,
                      color: AppColors.mutedForeground)),
            const SizedBox(height: 4),
            Text(items.length == 1 ? '1 encontro' : '${items.length} encontros',
                style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
          ]),
        ),
      ),
      Expanded(
        child: Column(children: [
          for (var i = 0; i < items.length; i++)
            _Row(e: items[i], first: i == 0),
        ]),
      ),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.e, required this.first});
  final Map<String, dynamic> e;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = _at(e);
    final rel = relDay(d);
    final soon = rel == 'Hoje' || rel == 'Amanhã';
    final desc = (e['description'] as String?)?.trim() ?? '';
    final line = BorderSide(color: AppColors.border);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: first ? line : BorderSide.none, bottom: line),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        DateBlock(d, size: 52, highlight: soon),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e['title']}',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(_meta(e),
                style: t.bodyMedium?.copyWith(color: AppColors.mutedForeground)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(desc, style: t.bodyMedium?.copyWith(height: 1.4)),
            ],
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 120,
          child: Text(rel,
              textAlign: TextAlign.right,
              style: t.bodyMedium?.copyWith(
                  color: soon ? AppColors.primary : AppColors.mutedForeground,
                  fontWeight: soon ? FontWeight.w700 : FontWeight.w500)),
        ),
      ]),
    );
  }
}

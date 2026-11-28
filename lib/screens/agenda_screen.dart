import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/section.dart';
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
  Widget build(BuildContext context) {
    final pad = hPad(context);
    final t = Theme.of(context).textTheme;
    // agrupa por mês
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final e in _items) {
      final d = DateTime.parse(e['starts_at']).toLocal();
      groups.putIfAbsent('${mesesLongo[d.month - 1]} ${d.year}', () => []).add(e);
    }
    var idx = 0;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
          children: [
            const PageHeader(
              title: 'Agenda',
              subtitle: 'Cultos, ensaios e encontros da igreja.',
              actions: [HeaderActions()],
            ),
            LoadSwitch(
              loading: _loading,
              skeleton: const SkeletonList(count: 5, height: 78),
              child: _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : _items.isEmpty
                      ? const EmptyState(
                          icon: Icons.event_outlined,
                          title: 'Nada agendado',
                          message: 'Quando houver novos encontros, eles aparecem aqui.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final g in groups.entries) ...[
                              SectionTitle(g.key),
                              for (final e in g.value)
                                Reveal(
                                  index: idx++,
                                  child: _row(t, e),
                                ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(TextTheme t, Map<String, dynamic> e) {
    final d = DateTime.parse(e['starts_at']).toLocal();
    final loc = e['location'] as String?;
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
                Text(
                  '${diasSemana[d.weekday - 1]} · ${two(d.hour)}h${two(d.minute)}${loc != null ? ' · $loc' : ''}',
                  style: t.bodySmall?.copyWith(color: AppColors.mutedForeground),
                ),
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

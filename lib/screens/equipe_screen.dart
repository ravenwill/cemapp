import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/ui.dart';
import 'indisponibilidade_screen.dart';

final _db = Supabase.instance.client;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _br(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
DateTime _parse(String s) => DateTime.parse(s);

/// Aba "Equipe": quem está disponível primeiro, funções e conta no app.
class EquipeView extends StatefulWidget {
  const EquipeView({super.key});
  @override
  State<EquipeView> createState() => _EquipeViewState();
}

class _EquipeViewState extends State<EquipeView> {
  List<Map<String, dynamic>> _people = [];
  final Map<String, Set<String>> _off = {}; // person_id -> {yyyy-MM-dd}
  DateTime _ref = DateTime.now();
  bool _manage = false;
  String? _mine;
  bool _loading = true;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _db.from('ministry_people').select().order('name');
      final acc = await loadMyAccess();
      _manage = acc.manage;
      _mine = acc.personId;
      final today = DateTime.now();
      final since = _iso(DateTime(today.year, today.month, today.day));
      Map<String, Set<String>> off = {};
      try {
        final u = await _db
            .from('person_unavailability')
            .select('person_id,day')
            .gte('day', since);
        for (final e in List<Map<String, dynamic>>.from(u)) {
          (off['${e['person_id']}'] ??= {}).add('${e['day']}');
        }
      } catch (_) {}
      DateTime? next;
      try {
        final s = await _db
            .from('schedules')
            .select('starts_at')
            .gte('starts_at', DateTime.now().toUtc().toIso8601String())
            .order('starts_at')
            .limit(1);
        if (s.isNotEmpty) next = DateTime.parse('${s.first['starts_at']}').toLocal();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _people = List<Map<String, dynamic>>.from(r);
          _off
            ..clear()
            ..addAll(off);
          if (_loading && next != null) _ref = next;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  bool _isOff(Map<String, dynamic> p, [DateTime? d]) =>
      (_off['${p['id']}'] ?? const <String>{}).contains(_iso(d ?? _ref));

  List<Map<String, dynamic>> get _filtered {
    final q = _q.trim().toLowerCase();
    final l = q.isEmpty
        ? [..._people]
        : _people.where((p) {
            final roles = (p['roles'] as List? ?? []).join(' ');
            return '${p['name']} $roles'.toLowerCase().contains(q);
          }).toList();
    // disponíveis primeiro (ordem por nome preservada)
    return [...l.where((p) => !_isOff(p)), ...l.where((p) => _isOff(p))];
  }

  Future<void> _pickRef() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _ref.isBefore(now) ? now : _ref,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _ref = d);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = _filtered;
    final livres = _people.where((p) => !_isOff(p)).length;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (!_loading && _error == null && _people.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.event_busy),
                label: const Text('Cadastrar indisponibilidade'),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const IndisponibilidadeScreen()));
                  _load();
                },
              ),
            ),
            const SizedBox(height: 12),
            _refCard(t, livres),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Buscar pessoa ou função',
                prefixIcon: Icon(Icons.search, color: AppColors.mutedForeground),
              ),
            ),
            const SizedBox(height: 12),
          ],
          LoadSwitch(
            loading: _loading,
            skeleton: const SkeletonList(count: 6),
            child: _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _people.isEmpty
                    ? const EmptyState(
                        icon: Icons.groups_outlined,
                        title: 'Nenhuma pessoa cadastrada')
                    : list.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off,
                            title: 'Nada encontrado',
                            message: 'Ninguém para "$_q".')
                        : Column(children: [
                            for (var i = 0; i < list.length; i++)
                              Reveal(index: i, child: _row(t, list[i])),
                          ]),
          ),
        ],
      ),
    );
  }

  String _refLabel() {
    final r = relDay(_ref);
    if (r == 'Hoje') return 'hoje';
    if (r == 'Amanhã') return 'amanhã';
    return 'em ${_br(_ref)}';
  }

  Widget _refCard(TextTheme t, int livres) {
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickRef,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(Icons.event_available, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Quem está livre ${_refLabel()}',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    _people.length == livres
                        ? 'Todos os $livres estão livres'
                        : '$livres livres · ${_people.length - livres} indisponíveis',
                    style: t.bodyMedium?.copyWith(color: AppColors.secondary)),
              ]),
            ),
            OutlinedButton.icon(
              onPressed: _pickRef,
              icon: const Icon(Icons.edit_calendar, size: 18),
              label: const Text('Trocar data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withAlpha(120)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(TextTheme t, Map<String, dynamic> p) {
    final roles = (p['roles'] as List? ?? []).map((e) => '$e').toList();
    final linked = p['user_id'] != null;
    final off = _isOff(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPerson(p),
          child: Opacity(
            opacity: off ? 0.72 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Avatar(name: p['name'], url: p['avatar_url'], size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['name'],
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(roles.isEmpty ? 'Sem função' : roles.join(' · '),
                        style: t.bodyMedium?.copyWith(
                            color: AppColors.secondary, fontWeight: FontWeight.w500)),
                    if (linked || p['is_admin'] == true) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (linked)
                          Pill('Tem conta no app',
                              fg: AppColors.success,
                              bg: AppColors.successSoft,
                              dense: true),
                        if (p['is_admin'] == true)
                          Pill('Admin',
                              fg: AppColors.primary,
                              bg: AppColors.primarySoft,
                              dense: true),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(width: 8),
                if (off)
                  Pill('Indisponível',
                      fg: AppColors.destructive,
                      bg: AppColors.destructive.withAlpha(30),
                      icon: Icons.event_busy,
                      dense: true),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setOff(Map<String, dynamic> p, DateTime d, bool off) async {
    final id = '${p['id']}';
    final iso = _iso(d);
    try {
      if (off) {
        await _db
            .from('person_unavailability')
            .upsert({'person_id': id, 'day': iso}, onConflict: 'person_id,day');
        (_off[id] ??= {}).add(iso);
      } else {
        await _db
            .from('person_unavailability')
            .delete()
            .eq('person_id', id)
            .eq('day', iso);
        _off[id]?.remove(iso);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  Future<void> _openPerson(Map<String, dynamic> p) async {
    if (!_manage && '${p['id']}' != _mine) {
      toast(context, 'Você só edita a sua própria disponibilidade.');
      return;
    }
    await showAppSheet<void>(context, (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        final t = Theme.of(ctx).textTheme;
        final days = ((_off['${p['id']}'] ?? <String>{}).toList()..sort());
        final offRef = _isOff(p);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['name']}',
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Datas em que não pode servir',
                    style: t.bodyMedium?.copyWith(color: AppColors.secondary)),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: offRef,
                  title: Text('Indisponível em ${_br(_ref)}',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  onChanged: (v) async {
                    await _setOff(p, _ref, v);
                    setS(() {});
                  },
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Marcar outra data'),
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: now,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (d != null) {
                      await _setOff(p, d, true);
                      setS(() {});
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (days.isEmpty)
                  Text('Nenhuma data marcada.',
                      style: t.bodyMedium?.copyWith(color: AppColors.mutedForeground))
                else
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in days)
                      InputChip(
                        label: Text(_br(_parse(s))),
                        onDeleted: () async {
                          await _setOff(p, _parse(s), false);
                          setS(() {});
                        },
                      ),
                  ]),
              ]),
        );
      });
    });
    if (mounted) setState(() {});
  }
}

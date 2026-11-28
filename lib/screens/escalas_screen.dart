import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';
import '../widgets/header_actions.dart' show SessionScope;
import 'escala_editor_screen.dart';
import 'perfil_screen.dart' show roleIcon;
import 'repertorio_screen.dart';

final _db = Supabase.instance.client;

const _select = 'id,title,starts_at,'
    'schedule_members(user_id,person_id,status,role_id,roles(name),profiles(name,avatar_url),ministry_people(name,avatar_url)),'
    'schedule_songs(position,key,song_versions(id,name,key,original_key,bpm,duration_seconds,chords,notes,songs(id,title,artist)))';

Future<List<Map<String, dynamic>>> loadSchedules() async {
  try {
    final r = await _db.from('schedules').select(_select).order('starts_at');
    return List<Map<String, dynamic>>.from(r);
  } catch (_) {
    // banco ainda sem a migração de equipe sem conta
    final r = await _db
        .from('schedules')
        .select(_select
            .replaceFirst(',person_id', '')
            .replaceFirst(',role_id', '')
            .replaceFirst(',ministry_people(name,avatar_url)', ''))
        .order('starts_at');
    return List<Map<String, dynamic>>.from(r);
  }
}

String fmtDate(String iso) {
  final d = DateTime.parse(iso).toLocal();
  const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  return '${dias[d.weekday - 1]} ${two(d.day)}/${two(d.month)} • ${two(d.hour)}:${two(d.minute)}';
}

Map<String, dynamic>? myMembership(Map<String, dynamic> s) {
  final uid = _db.auth.currentUser?.id;
  for (final m in (s['schedule_members'] as List? ?? [])) {
    if (m['user_id'] == uid) return Map<String, dynamic>.from(m);
  }
  return null;
}

Future<void> setStatus(String scheduleId, String status) async {
  await _db
      .from('schedule_members')
      .update({'status': status})
      .eq('schedule_id', scheduleId)
      .eq('user_id', _db.auth.currentUser!.id);
}

Pill statusPill(String st) {
  switch (st) {
    case 'confirmado':
      return Pill('Confirmado',
          fg: AppColors.success, bg: AppColors.successSoft, icon: Icons.check, dense: true);
    case 'recusado':
      return Pill('Recusado',
          fg: AppColors.destructive, bg: AppColors.destructiveSoft, dense: true);
    default:
      return Pill('Pendente',
          fg: AppColors.warning, bg: AppColors.warningSoft, dense: true);
  }
}

/// Aba "Escalas": cartões-resumo; "Abrir escala" mostra equipe e músicas.
class EscalasView extends StatefulWidget {
  const EscalasView({super.key});
  @override
  State<EscalasView> createState() => _EscalasViewState();
}

class _EscalasViewState extends State<EscalasView> {
  List<Map<String, dynamic>> _next = [];
  List<Map<String, dynamic>> _past = [];
  bool _showPast = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await loadSchedules();
      final limit = DateTime.now().subtract(const Duration(hours: 3));
      final next = r
          .where((s) => DateTime.parse(s['starts_at']).toLocal().isAfter(limit))
          .toList();
      final past = r.where((s) => !next.contains(s)).toList().reversed.toList();
      if (mounted) {
        setState(() {
          _next = next;
          _past = past;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar as escalas. Puxe para atualizar ou tente de novo.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const EscalaEditorScreen()));
    if (ok == true) _load();
  }

  Widget _body(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final manage = SessionScope.of(context).user?.canManage == true;
    Widget card(Map<String, dynamic> s, int i) => Reveal(
        index: i, child: _Card(s: s, onChanged: _load, canManage: manage));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_next.isEmpty)
        SizedBox(
          width: double.infinity,
          child: GlassCard(
            child: EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nenhuma escala futura',
              message: manage
                  ? 'Toque em "Nova escala" para montar a próxima.'
                  : 'Quando a liderança publicar a próxima escala, ela aparece aqui.',
            ),
          ),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('PRÓXIMA ESCALA',
              style: t.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8)),
        ),
        card(_next.first, 0),
        if (_next.length > 1) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text('DEPOIS',
                style: t.labelMedium?.copyWith(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8)),
          ),
          for (var i = 1; i < _next.length; i++) card(_next[i], i),
        ],
      ],
      if (_past.isNotEmpty) ...[
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _showPast = !_showPast),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(
                child: Text('Anteriores (${_past.length})',
                    style: t.titleSmall?.copyWith(
                        color: AppColors.secondary, fontWeight: FontWeight.w700)),
              ),
              Icon(_showPast ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.mutedForeground),
            ]),
          ),
        ),
        if (_showPast)
          for (var i = 0; i < _past.length; i++) card(_past[i], i),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (SessionScope.of(context).user?.canManage == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova escala'),
                ),
              ),
            LoadSwitch(
              loading: _loading,
              skeleton: const SkeletonList(count: 3, height: 150),
              child: _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : (_next.isEmpty && _past.isEmpty)
                      ? const EmptyState(
                          icon: Icons.event_busy_outlined,
                          title: 'Nenhuma escala ainda')
                      : _body(context),
            ),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.s, required this.onChanged, this.canManage = false});
  final bool canManage;
  final Map<String, dynamic> s;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = DateTime.parse(s['starts_at']).toLocal();
    final members = List<Map<String, dynamic>>.from(s['schedule_members'] ?? []);
    final nSongs = (s['schedule_songs'] as List? ?? []).length;
    final roles = <String>[
      for (final m in members)
        if ((m['roles'] as Map?)?['name'] != null) m['roles']['name'] as String
    ].toSet().toList();
    final me = myMembership(s);
    final now = DateTime.now();
    final past = d.isBefore(now.subtract(const Duration(hours: 3)));
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: past ? .72 : 1,
        child: GlassCard(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                DateBlock(d),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['title'],
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        '${diasSemana[d.weekday - 1]}, ${d.day} de ${mesesLongo[d.month - 1]} · ${two(d.hour)}h${two(d.minute)}',
                        style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (isToday)
                    Pill('Hoje',
                        dense: true, fg: AppColors.primary, bg: AppColors.primarySoft),
                  if (past && !isToday) Pill('Passada', dense: true),
                  if (me != null && !past) ...[
                    if (isToday) const SizedBox(height: 6),
                    statusPill('${me['status'] ?? 'pendente'}'),
                  ],
                ]),
              ]),
              if (roles.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(roles.join(' · '),
                    style: t.bodyMedium?.copyWith(
                        color: AppColors.secondary, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Text(
                      '${members.length} ${members.length == 1 ? 'pessoa escalada' : 'pessoas escaladas'} · $nSongs ${nSongs == 1 ? 'música' : 'músicas'}',
                      style: t.bodySmall?.copyWith(color: AppColors.secondary)),
                ),
                Text('Abrir escala',
                    style: t.labelLarge?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EscalaDetailScreen(s: s, canManage: canManage)));
    onChanged();
  }
}

class EscalaDetailScreen extends StatefulWidget {
  const EscalaDetailScreen({super.key, required this.s, this.canManage = false});
  final bool canManage;
  final Map<String, dynamic> s;
  @override
  State<EscalaDetailScreen> createState() => _EscalaDetailScreenState();
}

class _EscalaDetailScreenState extends State<EscalaDetailScreen> {
  late String? _status = myMembership(widget.s)?['status'] as String?;

  Future<void> _set(String st) async {
    final old = _status;
    setState(() => _status = st);
    try {
      await setStatus(widget.s['id'], st);
      if (mounted) toast(context, st == 'confirmado' ? 'Presença confirmada' : 'Resposta registrada');
    } catch (e) {
      if (mounted) {
        setState(() => _status = old);
        toast(context, 'Não foi possível salvar. ${friendlyError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = widget.s;
    final d = DateTime.parse(s['starts_at']).toLocal();
    final members = List<Map<String, dynamic>>.from(s['schedule_members'] ?? []);
    final songs = List<Map<String, dynamic>>.from(s['schedule_songs'] ?? [])
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    final pad = hPad(context);
    return Scaffold(
      appBar: AppBar(title: Text(s['title']), actions: [
        if (widget.canManage)
          IconButton(
            tooltip: 'Editar escala',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => EscalaEditorScreen(initial: s)));
              if (ok == true && context.mounted) Navigator.of(context).pop();
            },
          ),
      ]),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, 4, pad, 32),
        children: [
          Text(
              '${diasSemana[d.weekday - 1]}, ${d.day} de ${mesesLongo[d.month - 1]} · ${two(d.hour)}h${two(d.minute)}',
              style: t.bodyMedium?.copyWith(color: AppColors.mutedForeground)),
          if (_status != null) ...[
            const SizedBox(height: 16),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                    child: Text('Sua presença',
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (_status == 'confirmado')
                    TextButton(
                        onPressed: () => _set('recusado'),
                        child: const Text('Não posso'))
                  else ...[
                    OutlinedButton(
                        onPressed: () => _set('recusado'),
                        child: const Text('Não posso')),
                    const SizedBox(width: 8),
                    FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () => _set('confirmado'),
                        child: const Text('Confirmar')),
                  ],
                  if (_status == 'confirmado') statusPill('confirmado'),
                ]),
              ),
            ),
          ],
          const SectionTitle('Equipe'),
          GlassCard(
            child: Column(children: [
              for (var i = 0; i < members.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.border),
                _member(t, members[i], i == 0 ? null : null),
              ],
              if (members.isEmpty)
                const EmptyState(
                    icon: Icons.groups_outlined, title: 'Ninguém escalado ainda'),
            ]),
          ),
          const SectionTitle('Músicas'),
          GlassCard(
            child: Column(children: [
              for (var i = 0; i < songs.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.border),
                _song(context, t, songs, i),
              ],
              if (songs.isEmpty)
                const EmptyState(
                    icon: Icons.library_music_outlined,
                    title: 'Nenhuma música no repertório do dia'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _member(TextTheme t, Map<String, dynamic> m, Object? _) {
    final p = (m['profiles'] ?? m['ministry_people']) as Map?;
    final name = (p?['name'] ?? 'Sem nome') as String;
    final role = (m['roles'] as Map?)?['name'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Avatar(name: name, url: p?['avatar_url'] as String?, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(roleIcon(role), size: 14, color: AppColors.mutedForeground),
              const SizedBox(width: 4),
              Text(role ?? 'Sem função',
                  style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
            ]),
          ]),
        ),
        statusPill(m['status'] as String? ?? 'pendente'),
      ]),
    );
  }

  Map<String, dynamic> _asSong(Map<String, dynamic> ss) {
    final v = Map<String, dynamic>.from(ss['song_versions']);
    final song = Map<String, dynamic>.from(v['songs']);
    return {
      'id': song['id'],
      'title': song['title'],
      'artist': song['artist'],
      'song_versions': [
        {
          'id': v['id'],
          'name': v['name'],
          'key': v['key'],
          'original_key': v['original_key'],
          'sel_key': ss['key'],
          'bpm': v['bpm'],
          'duration_seconds': v['duration_seconds'],
          'chords': v['chords'],
          'notes': v['notes']
        }
      ]
    };
  }

  Widget _song(BuildContext context, TextTheme t, List<Map<String, dynamic>> all, int idx) {
    final v = Map<String, dynamic>.from(all[idx]['song_versions']);
    final song = Map<String, dynamic>.from(v['songs']);
    return InkWell(
      onTap: () {
        final list = all.map(_asSong).toList();
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                SongDetailScreen(song: list[idx], playlist: list, index: idx)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(9)),
            child: Text('${idx + 1}',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song['title'] ?? '',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(song['artist'] ?? '',
                  style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
            ]),
          ),
          if ((all[idx]['key'] ?? v['key']) != null)
            Pill('${all[idx]['key'] ?? v['key']}',
                fg: AppColors.foreground, bg: AppColors.navySoft),
        ]),
      ),
    );
  }
}

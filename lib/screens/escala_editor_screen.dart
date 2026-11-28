import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';

final _db = Supabase.instance.client;

/// Criador/editor de escalas (líderes e Master): data, equipe com função e músicas na ordem.
class EscalaEditorScreen extends StatefulWidget {
  const EscalaEditorScreen({super.key, this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<EscalaEditorScreen> createState() => _EscalaEditorScreenState();
}

class _EscalaEditorScreenState extends State<EscalaEditorScreen> {
  final _title = TextEditingController(text: 'Culto de Domingo');
  DateTime _date = _nextSunday();
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  bool _titleTouched = false;
  bool _dirty = false;
  String _search = '';
  String? _roleFilter;
  bool _showHint = false;
  String? _lastLabel; // ex.: "19/11"

  Future<void> _loadHintAndLast() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final seen = sp.getBool('escala_hint_seen') ?? false;
      if (!seen) await sp.setBool('escala_hint_seen', true);
      final r = await _db
          .from('schedules')
          .select('starts_at')
          .lte('starts_at', DateTime.now().toUtc().toIso8601String())
          .order('starts_at', ascending: false)
          .limit(1);
      String? lbl;
      if (r.isNotEmpty) {
        final d = DateTime.parse(r.first['starts_at']).toLocal();
        lbl = '${two(d.day)}/${two(d.month)}';
      }
      if (mounted) setState(() { _showHint = !seen; _lastLabel = lbl; });
    } catch (_) {}
  }

  static DateTime _nextSunday() {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    final add = (DateTime.sunday - d.weekday) % 7;
    return d.add(Duration(days: add == 0 && n.hour >= 19 ? 7 : add));
  }

  String _autoTitle(DateTime d) => switch (d.weekday) {
        DateTime.sunday => 'Culto de Domingo',
        DateTime.thursday => 'Culto de Oração',
        _ => 'Escala',
      };

  String _friendly(Object e) {
    final s = '$e'.toLowerCase();
    if (s.contains('socket') || s.contains('network') || s.contains('failed host') || s.contains('clientexception')) {
      return 'Sem conexão. Verifique a internet e tente de novo.';
    }
    if (s.contains('permission') || s.contains('row-level') || s.contains('42501') || s.contains('403')) {
      return 'Você não tem permissão para fazer isso.';
    }
    return 'Algo deu errado. Tente de novo em instantes.';
  }

  List<Map<String, dynamic>> _people = [];
  Set<String> _busy = {}; // pessoas indisponíveis na data da escala

  Future<void> _loadBusy() async {
    try {
      final d = _date;
      final iso =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final r = await _db
          .from('person_unavailability')
          .select('person_id')
          .eq('day', iso);
      if (mounted) {
        setState(() =>
            _busy = {for (final e in List.from(r)) '${(e as Map)['person_id']}'});
      }
    } catch (_) {}
  }
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _songs = []; // todas as versões disponíveis
  // pessoa -> função escolhida (presente = selecionada)
  final Map<String, String> _picked = {};
  final Map<String, String> _status = {}; // preserva status ao editar
  final List<Map<String, dynamic>> _chosen = []; // versões na ordem
  String? _ministryId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _load();
    if (!_editing) _loadHintAndLast();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String _key(Map<String, dynamic> p) => '${p['id']}';

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        _db.from('ministry_people').select('id,ministry_id,name,avatar_url,user_id,roles').order('name'),
        _db.from('roles').select('id,name,ministry_id'),
        _db.from('song_versions').select('id,name,key,original_key,songs(id,title,artist)'),
      ]);
      _people = List<Map<String, dynamic>>.from(res[0]);
      _roles = List<Map<String, dynamic>>.from(res[1]);
      _songs = List<Map<String, dynamic>>.from(res[2])
        ..sort((a, b) => '${a['songs']?['title']}'
            .toLowerCase()
            .compareTo('${b['songs']?['title']}'.toLowerCase()));
      _ministryId = _people.isNotEmpty ? _people.first['ministry_id'] as String? : null;

      final s = widget.initial;
      if (s != null) {
        _title.text = s['title'] as String;
        final d = DateTime.parse(s['starts_at']).toLocal();
        _date = DateTime(d.year, d.month, d.day);
        _time = TimeOfDay(hour: d.hour, minute: d.minute);
        for (final m in (s['schedule_members'] as List? ?? [])) {
          final pid = _personFor(m);
          if (pid == null) continue;
          _picked[pid] = ((m['roles'] as Map?)?['name'] as String?) ?? '';
          _status[pid] = (m['status'] as String?) ?? 'pendente';
        }
        final ss = List<Map<String, dynamic>>.from(s['schedule_songs'] ?? [])
          ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
        for (final x in ss) {
          final vid = (x['song_versions'] as Map)['id'];
          final v = _songs.where((e) => e['id'] == vid);
          if (v.isNotEmpty) _chosen.add({...v.first, 'sel_key': x['key']});
        }
      }
      await _loadBusy();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = _friendly(e); _loading = false; });
    }
  }

  String? _personFor(Map m) {
    final pid = m['person_id'];
    if (pid != null) return '$pid';
    final uid = m['user_id'];
    for (final p in _people) {
      if (p['user_id'] == uid) return _key(p);
    }
    return null;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (c, child) => MediaQuery(
        // Força o layout vertical (evita o painel lateral que corta o título).
        data: MediaQuery.of(c).copyWith(size: const Size(480, 900)),
        child: child ?? const SizedBox(),
      ),
    );
    if (d != null) {
      setState(() {
        _date = d;
        _dirty = true;
        if (!_titleTouched && !_editing) _title.text = _autoTitle(d);
      });
      _loadBusy();
    }
  }

  Future<void> _copyLast() async {
    try {
      final r = await _db
          .from('schedules')
          .select(
              'id,title,schedule_members(user_id,person_id,roles(name)),schedule_songs(position,key,song_versions(id))')
          .lte('starts_at', DateTime.now().toUtc().toIso8601String())
          .order('starts_at', ascending: false)
          .limit(1);
      if (r.isEmpty) {
        if (mounted) toast(context, 'Ainda não há escala anterior para copiar');
        return;
      }
      final s = r.first;
      setState(() {
        _picked.clear();
        _chosen.clear();
        for (final m in (s['schedule_members'] as List? ?? [])) {
          final pid = _personFor(m);
          if (pid == null) continue;
          _picked[pid] = ((m['roles'] as Map?)?['name'] as String?) ?? '';
        }
        final ss = List<Map<String, dynamic>>.from(s['schedule_songs'] ?? [])
          ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
        for (final x in ss) {
          final vid = (x['song_versions'] as Map?)?['id'];
          final v = _songs.where((e) => e['id'] == vid);
          if (v.isNotEmpty) _chosen.add({...v.first, 'sel_key': x['key']});
        }
        _dirty = true;
      });
      if (mounted) toast(context, 'Equipe e músicas copiadas de "${s['title']}"');
    } catch (e) {
      if (mounted) toast(context, _friendly(e));
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('Você tem alterações que ainda não foram salvas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuar editando')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Descartar')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() { _time = t; _dirty = true; });
  }

  Future<void> _addSong() async {
    final v = await showAppSheet<Map<String, dynamic>>(
        context, (_) => _SongPicker(all: _songs, chosen: _chosen));
    if (v != null) setState(() { _chosen.add({...v, 'sel_key': null}); _dirty = true; });
  }

  static const _allKeys = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B',
    'Cm', 'C#m', 'Dm', 'Ebm', 'Em', 'Fm', 'F#m', 'Gm', 'G#m', 'Am', 'Bbm', 'Bm',
  ];

  Future<void> _pickKey(int i) async {
    final it = _chosen[i];
    final church = it['key'] as String?;
    final orig = it['original_key'] as String?;
    final cur = (it['sel_key'] as String?) ?? church;
    final res = await showAppSheet<String>(context, (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tom nesta escala',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              '${it['songs']?['title'] ?? ''}\nIgreja: ${church ?? '-'} · Original: ${orig ?? '-'}',
              style: t.bodyMedium?.copyWith(color: AppColors.secondary)),
          const SizedBox(height: 14),
          if (church != null)
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: Text('Usar o tom da igreja ($church)')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in _allKeys)
              ChoiceChip(
                label: Text(k),
                selected: cur == k,
                showCheckmark: false,
                selectedColor: AppColors.primarySoft,
                onSelected: (_) => Navigator.pop(ctx, k),
              ),
          ]),
        ]),
      );
    });
    if (res == null) return;
    setState(() {
      _chosen[i] = {..._chosen[i], 'sel_key': res.isEmpty ? null : res};
      _dirty = true;
    });
  }

  Future<String?> _roleId(String name) async {
    if (name.isEmpty) return null;
    for (final r in _roles) {
      if ('${r['name']}'.toLowerCase() == name.toLowerCase()) return r['id'] as String;
    }
    final ins = await _db
        .from('roles')
        .insert({'ministry_id': _ministryId, 'name': name})
        .select('id')
        .single();
    _roles.add({'id': ins['id'], 'name': name, 'ministry_id': _ministryId});
    return ins['id'] as String;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'Dê um nome para a escala');
      return;
    }
    if (_picked.isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Escala sem equipe'),
          content: const Text('Nenhuma pessoa foi escolhida. Criar mesmo assim?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Criar assim mesmo')),
          ],
        ),
      );
      if (go != true) return;
    }
    if (_picked.isNotEmpty) {
      final have = _picked.values.map((e) => e.toLowerCase()).toSet();
      final known = _roles.map((r) => '${r['name']}').toSet();
      final missing = ['Ministro', 'Vocalista', 'Bateria']
          .where((r) => known.any((k) => k.toLowerCase() == r.toLowerCase()))
          .where((r) => !have.contains(r.toLowerCase()))
          .toList();
      if (missing.isNotEmpty) {
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Falta alguém na escala'),
            content: Text('Ninguém escolhido para: ${missing.join(', ')}. Criar mesmo assim?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Criar assim mesmo')),
            ],
          ),
        );
        if (go != true) return;
      }
    }
    setState(() => _saving = true);
    try {
      final at = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final row = {
        'ministry_id': _ministryId,
        'title': _title.text.trim(),
        'starts_at': at.toUtc().toIso8601String(),
      };
      String id;
      if (_editing) {
        id = widget.initial!['id'] as String;
        await _db.from('schedules').update(row).eq('id', id);
        await _db.from('schedule_members').delete().eq('schedule_id', id);
        await _db.from('schedule_songs').delete().eq('schedule_id', id);
      } else {
        final r = await _db.from('schedules').insert(row).select('id').single();
        id = r['id'] as String;
      }
      final members = <Map<String, dynamic>>[];
      for (final p in _people) {
        final k = _key(p);
        if (!_picked.containsKey(k)) continue;
        final roleId = await _roleId(_picked[k]!);
        members.add({
          'schedule_id': id,
          if (p['user_id'] != null) 'user_id': p['user_id'] else 'person_id': p['id'],
          'role_id': roleId,
          'status': _status[k] ?? 'pendente',
        });
      }
      if (members.isNotEmpty) await _db.from('schedule_members').insert(members);
      if (_chosen.isNotEmpty) {
        await _db.from('schedule_songs').insert([
          for (var i = 0; i < _chosen.length; i++)
            {
              'schedule_id': id,
              'version_id': _chosen[i]['id'],
              'position': i + 1,
              if (_chosen[i]['sel_key'] != null) 'key': _chosen[i]['sel_key'],
            },
        ]);
      }
      if (mounted) {
        _dirty = false;
        toast(context, _editing ? 'Escala atualizada' : 'Escala criada');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, 'Não foi possível salvar. ${_friendly(e)}');
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir escala?'),
        content: const Text('A equipe e as músicas desta escala serão removidas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final id = widget.initial!['id'];
      await _db.from('schedule_members').delete().eq('schedule_id', id);
      await _db.from('schedule_songs').delete().eq('schedule_id', id);
      await _db.from('schedules').delete().eq('id', id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) toast(context, 'Não foi possível excluir. ${_friendly(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = hPad(context);
    final q = _search.trim().toLowerCase();
    final visible = _people.where((p) {
      if (q.isNotEmpty && !'${p['name']}'.toLowerCase().contains(q)) return false;
      if (_roleFilter != null) {
        final rs = List<String>.from(p['roles'] ?? []).map((e) => e.toLowerCase());
        if (!rs.contains(_roleFilter!.toLowerCase())) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final pa = _picked.containsKey(_key(a)) ? 0 : 1;
        final pb = _picked.containsKey(_key(b)) ? 0 : 1;
        return pa != pb ? pa.compareTo(pb) : 0;
      });
    final filterRoles = {
      for (final p in _people) ...List<String>.from(p['roles'] ?? []),
    }.toList()
      ..sort();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar escala' : 'Nova escala'),
        actions: [
          if (_editing)
            IconButton(
                tooltip: 'Excluir escala',
                onPressed: _delete,
                icon: Icon(Icons.delete_outline, color: AppColors.destructive)),
        ],
      ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_editing ? 'Salvar alterações' : 'Criar escala'),
                ),
              ),
            ),
      body: _loading
          ? const Padding(padding: EdgeInsets.all(20), child: SkeletonList(count: 4, height: 90))
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : ListView(
                  padding: EdgeInsets.fromLTRB(pad, 4, pad, 24),
                  children: [
                    if (!_editing) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withAlpha(120)),
                        ),
                        onPressed: _copyLast,
                        icon: const Icon(Icons.copy_all_outlined, size: 18),
                        label: Text(_lastLabel == null
                            ? 'Copiar equipe e músicas da última escala'
                            : 'Copiar da última escala ($_lastLabel)'),
                      ),
                      if (_showHint)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          child: Text(
                            'Dica: copie e ajuste só o que mudou. Os filtros por função ajudam a achar quem toca.',
                            style: t.bodySmall
                                ?.copyWith(color: AppColors.mutedForeground, fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {
                        _titleTouched = true;
                        _dirty = true;
                      }),
                      decoration: const InputDecoration(labelText: 'Nome da escala'),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: _fieldBtn(context),
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined, size: 18),
                          label: Text(
                              '${diasSemana[_date.weekday - 1]}, ${two(_date.day)}/${two(_date.month)}/${_date.year}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: _fieldBtn(context),
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text('${two(_time.hour)}h${two(_time.minute)}'),
                      ),
                    ]),
                    SectionTitle('Equipe (${_picked.length})'),
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                          hintText: 'Buscar pessoa',
                          prefixIcon:
                              Icon(Icons.search, color: AppColors.mutedForeground)),
                    ),
                    if (filterRoles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Filtrar por função',
                          style: t.labelMedium?.copyWith(color: AppColors.mutedForeground)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final r in filterRoles)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(r),
                                  selected: _roleFilter == r,
                                  onSelected: (v) =>
                                      setState(() => _roleFilter = v ? r : null),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    GlassCard(
                      child: Column(children: [
                        for (var i = 0; i < visible.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: AppColors.border),
                          _personRow(t, visible[i]),
                        ],
                        if (_people.isNotEmpty && visible.isEmpty)
                          const EmptyState(
                              icon: Icons.search_off, title: 'Ninguém encontrado'),
                        if (_people.isEmpty)
                          const EmptyState(
                              icon: Icons.groups_outlined,
                              title: 'Cadastre a equipe na aba Equipe'),
                      ]),
                    ),
                    SectionTitle('Músicas (${_chosen.length})'),
                    GlassCard(
                      child: Column(children: [
                        if (_chosen.isNotEmpty)
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorder: (a, b) => setState(() {
                              if (b > a) b--;
                              _chosen.insert(b, _chosen.removeAt(a));
                              _dirty = true;
                            }),
                            children: [
                              for (var i = 0; i < _chosen.length; i++)
                                ListTile(
                                  key: ValueKey('${_chosen[i]['id']}-$i'),
                                  leading: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: AppColors.primarySoft,
                                    child: Text('${i + 1}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  title: Text('${_chosen[i]['songs']?['title']}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                      '${_chosen[i]['songs']?['artist'] ?? ''}${_chosen[i]['original_key'] != null ? ' \u00B7 Original ${_chosen[i]['original_key']}' : ''}'),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    ActionChip(
                                      tooltip: 'Escolher o tom desta escala',
                                      avatar: const Icon(Icons.music_note, size: 16),
                                      label: Text('Tom ${_chosen[i]['sel_key'] ?? _chosen[i]['key'] ?? '-'}'),
                                      onPressed: () => _pickKey(i),
                                    ),
                                    IconButton(
                                        tooltip: 'Remover',
                                        onPressed: () => setState(() { _chosen.removeAt(i); _dirty = true; }),
                                        icon: const Icon(Icons.close, size: 20)),
                                    ReorderableDragStartListener(
                                        index: i,
                                        child: Icon(Icons.drag_handle,
                                            color: AppColors.mutedForeground)),
                                  ]),
                                ),
                            ],
                          ),
                        ListTile(
                          onTap: _addSong,
                          leading: Icon(Icons.add_circle_outline, color: AppColors.primary),
                          title: Text('Adicionar música',
                              style: TextStyle(
                                  color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ],
                ),
    ));
  }

  ButtonStyle _fieldBtn(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.styleFrom(
      backgroundColor: dark ? Theme.of(context).cardColor : Colors.white,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      side: BorderSide(color: AppColors.border),
    );
  }

  Widget _personRow(TextTheme t, Map<String, dynamic> p) {
    final k = _key(p);
    final on = _picked.containsKey(k);
    final roles = List<String>.from(p['roles'] ?? []);
    final all = {...roles, ..._roles.map((r) => '${r['name']}')}.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        Checkbox(
          value: on,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() {
            _dirty = true;
            if (v == true) {
              _picked[k] = roles.isNotEmpty ? roles.first : '';
            } else {
              _picked.remove(k);
            }
          }),
        ),
        Avatar(name: '${p['name']}', url: p['avatar_url'] as String?, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p['name']}',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (_busy.contains(k))
                Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 3),
                  child: Pill('Indisponível nesta data',
                      fg: AppColors.destructive,
                      bg: AppColors.destructive.withAlpha(30),
                      icon: Icons.event_busy,
                      dense: true),
                ),
              if (roles.isNotEmpty)
                Text(roles.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(190))),
            ],
          ),
        ),
        if (on)
          PopupMenuButton<String>(
            tooltip: 'Função',
            onSelected: (v) => setState(() {
              _picked[k] = v;
              _dirty = true;
            }),
            itemBuilder: (_) => [
              for (final r in all) PopupMenuItem(value: r, child: Text(r)),
            ],
            child: Pill(_picked[k]!.isEmpty ? 'Escolher função' : _picked[k]!,
                icon: Icons.expand_more, dense: true),
          ),
        const SizedBox(width: 6),
      ]),
    );
  }
}

class _SongPicker extends StatefulWidget {
  const _SongPicker({required this.all, required this.chosen});
  final List<Map<String, dynamic>> all;
  final List<Map<String, dynamic>> chosen;
  @override
  State<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends State<_SongPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.all.where((v) {
      final s = '${v['songs']?['title']} ${v['songs']?['artist']}'.toLowerCase();
      return s.contains(_q.toLowerCase());
    }).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * .7,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
                hintText: 'Buscar música ou artista',
                prefixIcon: Icon(Icons.search, color: AppColors.mutedForeground)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final v = list[i];
              final added = widget.chosen.any((c) => c['id'] == v['id']);
              return ListTile(
                title: Text('${v['songs']?['title']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${v['songs']?['artist'] ?? ''}'),
                trailing: added
                    ? Icon(Icons.check, color: AppColors.success)
                    : (v['key'] != null ? Pill('${v['key']}', dense: true) : null),
                onTap: () => Navigator.pop(context, v),
              );
            },
          ),
        ),
      ]),
    );
  }
}

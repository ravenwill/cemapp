import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';

final _db = Supabase.instance.client;

/// Quem é a pessoa do usuário logado e se ele pode editar a de outros
/// (Master ou admin do ministério).
Future<({String? personId, bool manage})> loadMyAccess() async {
  final me = _db.auth.currentUser?.id;
  if (me == null) return (personId: null, manage: false);
  var manage = false;
  String? pid;
  try {
    final p = await _db.from('profiles').select('is_master').eq('id', me).single();
    manage = p['is_master'] == true;
  } catch (_) {}
  try {
    final r = await _db
        .from('ministry_people')
        .select('id,is_admin')
        .eq('user_id', me)
        .limit(1);
    if (r.isNotEmpty) {
      pid = '${r.first['id']}';
      if (r.first['is_admin'] == true) manage = true;
    }
  } catch (_) {}
  return (personId: pid, manage: manage);
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _br(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Tela para cadastrar e consultar indisponibilidades (datas em que a pessoa não pode servir).
class IndisponibilidadeScreen extends StatefulWidget {
  const IndisponibilidadeScreen({super.key});
  @override
  State<IndisponibilidadeScreen> createState() => _IndisponibilidadeScreenState();
}

class _IndisponibilidadeScreenState extends State<IndisponibilidadeScreen> {
  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _items = [];
  String? _personId;
  String? _mine;
  bool _manage = false;
  late DateTime _from;
  late DateTime _to;
  final _reason = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _from = DateTime(n.year, n.month, n.day);
    _to = _from;
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await _db.from('ministry_people').select('id,name,user_id').order('name');
      final people = List<Map<String, dynamic>>.from(p);
      final today = DateTime.now();
      final u = await _db
          .from('person_unavailability')
          .select('id,person_id,day,reason')
          .gte('day', _iso(DateTime(today.year, today.month, today.day)))
          .order('day');
      final acc = await loadMyAccess();
      if (mounted) {
        setState(() {
          _people = people;
          _items = List<Map<String, dynamic>>.from(u);
          _manage = acc.manage;
          _mine = acc.personId;
          _personId ??= acc.personId;
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

  String _nameOf(String id) {
    for (final p in _people) {
      if ('${p['id']}' == id) return '${p['name']}';
    }
    return 'Pessoa';
  }

  Future<void> _pick(bool from) async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: first,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d == null) return;
    setState(() {
      if (from) {
        _from = d;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = d.isBefore(_from) ? _from : d;
      }
    });
  }

  Future<void> _save() async {
    if (!_manage) _personId = _mine;
    if (_personId == null) {
      toast(context, 'Escolha a pessoa.');
      return;
    }
    final days = _to.difference(_from).inDays + 1;
    if (days > 120) {
      toast(context, 'Período muito longo. Use até 120 dias por vez.');
      return;
    }
    setState(() => _saving = true);
    try {
      final reason = _reason.text.trim();
      final rows = [
        for (var i = 0; i < days; i++)
          {
            'person_id': _personId,
            'day': _iso(_from.add(Duration(days: i))),
            if (reason.isNotEmpty) 'reason': reason,
          }
      ];
      await _db.from('person_unavailability').upsert(rows, onConflict: 'person_id,day');
      _reason.clear();
      await _load();
      if (mounted) {
        toast(context, days == 1
            ? 'Indisponibilidade salva.'
            : 'Indisponível por $days dias.');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> it) async {
    try {
      await _db.from('person_unavailability').delete().eq('id', it['id']);
      await _load();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Indisponibilidades')),
      body: SafeArea(
        child: _error != null
            ? ListView(children: [ErrorState(message: _error!, onRetry: _load)])
            : ListView(
                padding: EdgeInsets.fromLTRB(hPad(context), 8, hPad(context), 32),
                children: [
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Nova indisponibilidade',
                            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        if (!_loading && !_manage && _mine == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                                'Sua conta ainda não está vinculada à equipe. Peça a um admin para vincular.',
                                style: t.bodyMedium?.copyWith(color: AppColors.secondary)),
                          ),
                        DropdownButtonFormField<String>(
                          value: _personId,
                          isExpanded: true,
                          decoration: InputDecoration(
                              labelText: 'Pessoa',
                              helperText: _manage
                                  ? null
                                  : 'Você marca apenas a sua própria indisponibilidade.'),
                          items: [
                            for (final p in _people)
                              DropdownMenuItem(
                                  value: '${p['id']}', child: Text('${p['name']}')),
                          ],
                          onChanged:
                              _manage ? (v) => setState(() => _personId = v) : null,
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _dateBtn('De', _from, () => _pick(true))),
                          const SizedBox(width: 12),
                          Expanded(child: _dateBtn('Até', _to, () => _pick(false))),
                        ]),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reason,
                          maxLength: 80,
                          decoration: const InputDecoration(
                              labelText: 'Motivo (opcional)',
                              hintText: 'Ex.: viagem, trabalho'),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                (_saving || (!_manage && _mine == null)) ? null : _save,
                            icon: const Icon(Icons.event_busy),
                            label: Text(_saving ? 'Salvando…' : 'Salvar indisponibilidade'),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Marcadas',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_loading)
                    const SkeletonList(count: 3)
                  else if (_items.isEmpty)
                    const EmptyState(
                        icon: Icons.event_available,
                        title: 'Ninguém marcou indisponibilidade')
                  else
                    for (final it in _items) _itemRow(t, it),
                ],
              ),
      ),
    );
  }

  Widget _dateBtn(String label, DateTime d, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.centerLeft),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(fontSize: 12.5, color: AppColors.secondary)),
        const SizedBox(height: 3),
        Text(_br(d), style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _itemRow(TextTheme t, Map<String, dynamic> it) {
    final d = DateTime.parse('${it['day']}');
    final reason = '${it['reason'] ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(children: [
            DateBlock(d, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nameOf('${it['person_id']}'),
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(reason.isEmpty ? relDay(d) : '${relDay(d)} · $reason',
                    style: t.bodyMedium?.copyWith(color: AppColors.secondary)),
              ]),
            ),
            if (_manage || '${it['person_id']}' == _mine)
              IconButton(
                tooltip: 'Remover',
                icon: Icon(Icons.close, color: AppColors.mutedForeground),
                onPressed: () => _remove(it),
              ),
          ]),
        ),
      ),
    );
  }
}

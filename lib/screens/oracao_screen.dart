import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/permissions.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';

final _db = Supabase.instance.client;

const _cats = <String, (String, IconData)>{
  'saude': ('Saúde', Icons.favorite_border),
  'familia': ('Família', Icons.home_outlined),
  'trabalho': ('Trabalho', Icons.work_outline),
  'gratidao': ('Gratidão', Icons.celebration_outlined),
  'outros': ('Outros', Icons.chat_bubble_outline),
};

/// Mural de pedidos de oração: peça, ore pelos outros e acompanhe respostas.
class OracaoScreen extends StatefulWidget {
  const OracaoScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<OracaoScreen> createState() => _OracaoScreenState();
}

class _OracaoScreenState extends State<OracaoScreen> {
  List<Map<String, dynamic>> _items = [];
  String _filter = 'todos';
  bool _loading = true;
  String? _error;

  AppUser get _u => widget.session.user!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _db
          .from('prayer_wall')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(r);
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

  List<Map<String, dynamic>> get _shown => _items.where((p) {
        if (_filter == 'todos') return true;
        if (_filter == 'meus') return p['mine'] == true;
        return p['category'] == _filter;
      }).toList();

  Future<void> _new() async {
    final r = await showAppSheet<Map<String, dynamic>>(
        context, (_) => const _NewPrayerSheet());
    if (r == null) return;
    try {
      await _db.from('prayer_requests').insert({...r, 'author_name': _u.name});
      if (mounted) {
        toast(context, r['visibility'] == 'lideranca'
            ? 'Pedido enviado à liderança'
            : 'Pedido publicado. A igreja vai orar com você.');
      }
      await _load();
    } catch (e) {
      if (mounted) toast(context, 'Não foi possível enviar. ${friendlyError(e)}');
    }
  }

  Future<void> _pray(Map<String, dynamic> p) async {
    final was = p['i_prayed'] == true;
    setState(() {
      p['i_prayed'] = !was;
      p['prayed_count'] = (p['prayed_count'] as int) + (was ? -1 : 1);
    });
    try {
      if (was) {
        await _db
            .from('prayer_interactions')
            .delete()
            .eq('request_id', p['id'])
            .eq('user_id', _u.id);
      } else {
        await _db.from('prayer_interactions').insert({'request_id': p['id']});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          p['i_prayed'] = was;
          p['prayed_count'] = (p['prayed_count'] as int) + (was ? 1 : -1);
        });
        toast(context, 'Não foi possível registrar. ${friendlyError(e)}');
      }
    }
  }

  Future<void> _answered(Map<String, dynamic> p) async {
    final next = p['status'] == 'respondido' ? 'aberto' : 'respondido';
    try {
      await _db.from('prayer_requests').update({'status': next}).eq('id', p['id']);
      setState(() => p['status'] = next);
      if (mounted && next == 'respondido') toast(context, 'Glória a Deus! Marcado como respondido.');
    } catch (e) {
      if (mounted) toast(context, 'Não foi possível salvar. ${friendlyError(e)}');
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir pedido?'),
        content: const Text('Essa ação não pode ser desfeita.'),
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
      await _db.from('prayer_requests').delete().eq('id', p['id']);
      setState(() => _items.remove(p));
    } catch (e) {
      if (mounted) toast(context, 'Não foi possível excluir. ${friendlyError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = hPad(context);
    final list = _shown;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
          children: [
            const PageHeader(
              title: 'Oração',
              subtitle: 'Compartilhe o que está no seu coração. A igreja ora com você.',
              actions: [HeaderActions()],
            ),
            FilledButton.icon(
              onPressed: _new,
              icon: const Icon(Icons.add),
              label: const Text('Novo pedido de oração'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('todos', 'Todos'),
                  _chip('meus', 'Meus pedidos'),
                  for (final e in _cats.entries.where((e) => e.key != 'outros'))
                    _chip(e.key, e.value.$1),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LoadSwitch(
              loading: _loading,
              skeleton: Shimmer(
                child: Column(children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                ]),
              ),
              child: _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : list.isEmpty
                      ? EmptyState(
                          icon: Icons.volunteer_activism_outlined,
                          title: _filter == 'meus'
                              ? 'Você ainda não fez pedidos'
                              : 'Nenhum pedido por aqui',
                          message: 'Toque em "Novo pedido de oração" para compartilhar.')
                      : Column(children: [
                          for (var i = 0; i < list.length; i++)
                            Reveal(
                              key: ValueKey('${list[i]['id']}$_filter'),
                              index: i,
                              child: _card(list[i]),
                            ),
                        ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String key, String label) {
    final sel = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        showCheckmark: false,
        selectedColor: AppColors.primarySoft,
        backgroundColor: AppColors.card,
        side: BorderSide(color: sel ? AppColors.primary : AppColors.border),
        labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: sel ? AppColors.primary : AppColors.secondary),
        onSelected: (_) => setState(() => _filter = key),
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final t = Theme.of(context).textTheme;
    final anon = p['author_name'] == null;
    final name = anon ? 'Anônimo' : '${p['author_name']}';
    final cat = _cats['${p['category']}'] ?? _cats['outros']!;
    final mine = p['mine'] == true;
    final answered = p['status'] == 'respondido';
    final prayed = p['i_prayed'] == true;
    final count = p['prayed_count'] as int;
    final canManage = mine || _u.isMaster;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              anon
                  ? Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: AppColors.navySoft, shape: BoxShape.circle),
                      child: Icon(Icons.person_outline,
                          size: 20, color: AppColors.mutedForeground))
                  : Avatar(name: name, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(mine && !anon ? '$name (você)' : name,
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(ago(DateTime.parse(p['created_at']).toLocal()),
                      style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
                ]),
              ),
              Pill(cat.$1, icon: cat.$2, dense: true),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  icon: Icon(Icons.more_vert, size: 20, color: AppColors.mutedForeground),
                  onSelected: (v) => v == 'resp' ? _answered(p) : _delete(p),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'resp',
                        child: Text(answered ? 'Reabrir pedido' : 'Marcar como respondido')),
                    const PopupMenuItem(value: 'del', child: Text('Excluir')),
                  ],
                )
              else
                const SizedBox(width: 8),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 8),
              child: Text('${p['body']}',
                  style: t.bodyMedium?.copyWith(height: 1.5)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _PrayButton(prayed: prayed, count: count, onTap: () => _pray(p)),
              const Spacer(),
              if (p['visibility'] == 'lideranca')
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pill('Só liderança',
                      icon: Icons.lock_outline, dense: true),
                ),
              if (answered)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pill('Respondido',
                      fg: AppColors.success,
                      bg: AppColors.successSoft,
                      icon: Icons.check,
                      dense: true),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _PrayButton extends StatelessWidget {
  const _PrayButton({required this.prayed, required this.count, required this.onTap});
  final bool prayed;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = prayed ? AppColors.primary : AppColors.secondary;
    return Semantics(
      button: true,
      toggled: prayed,
      label: 'Orei por este pedido',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: kEase,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: prayed ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: prayed ? AppColors.primary : AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (ch, a) =>
                  ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: ch),
              child: Icon(
                prayed ? Icons.volunteer_activism : Icons.volunteer_activism_outlined,
                key: ValueKey(prayed),
                size: 18,
                color: c,
              ),
            ),
            const SizedBox(width: 8),
            Text(prayed ? 'Orei' : 'Orar',
                style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (ch, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                      position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(a),
                      child: ch)),
              child: Text('$count',
                  key: ValueKey(count),
                  style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NewPrayerSheet extends StatefulWidget {
  const _NewPrayerSheet();
  @override
  State<_NewPrayerSheet> createState() => _NewPrayerSheetState();
}

class _NewPrayerSheetState extends State<_NewPrayerSheet> {
  final _body = TextEditingController();
  String _cat = 'outros';
  bool _anon = false;
  bool _leaders = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Novo pedido de oração',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            autofocus: true,
            minLines: 4,
            maxLines: 7,
            maxLength: 600,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                hintText: 'Pelo que você quer que a igreja ore?'),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in _cats.entries)
              ChoiceChip(
                avatar: Icon(e.value.$2,
                    size: 16,
                    color: _cat == e.key ? AppColors.primary : AppColors.secondary),
                label: Text(e.value.$1),
                selected: _cat == e.key,
                showCheckmark: false,
                selectedColor: AppColors.primarySoft,
                side: BorderSide(
                    color: _cat == e.key ? AppColors.primary : Colors.transparent),
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _cat == e.key ? AppColors.primary : AppColors.foreground),
                onSelected: (_) => setState(() => _cat = e.key),
              ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _anon,
            onChanged: (v) => setState(() => _anon = v),
            title: const Text('Não mostrar meu nome'),
            subtitle: const Text('Aparece como "Anônimo" para os irmãos.'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _leaders,
            onChanged: (v) => setState(() => _leaders = v),
            title: const Text('Só a liderança pode ver'),
            subtitle: const Text('Não aparece no mural da igreja.'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _body.text.trim().length < 3
                ? null
                : () => Navigator.pop(context, {
                      'body': _body.text.trim(),
                      'category': _cat,
                      'is_anonymous': _anon,
                      'visibility': _leaders ? 'lideranca' : 'publico',
                    }),
            child: const Text('Enviar pedido'),
          ),
        ]),
      ),
    );
  }
}

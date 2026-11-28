import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';

class AvisosScreen extends StatefulWidget {
  const AvisosScreen({super.key});
  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  Set<String> _read = {}; // ids de avisos já abertos neste aparelho

  Future<void> _markRead(String id) async {
    if (_read.contains(id)) return;
    setState(() => _read = {..._read, id});
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('avisos_read_ids', _read.toList());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Supabase.instance.client
          .from('announcements')
          .select('id,title,body,tag,created_at')
          .order('created_at', ascending: false);
      // "Novo" = aviso ainda não tocado. Na primeira vez, tudo o que já existe
      // conta como lido, para não marcar o histórico inteiro.
      final sp = await SharedPreferences.getInstance();
      final stored = sp.getStringList('avisos_read_ids');
      if (stored == null) {
        _read = {for (final a in r) '${a['id']}'};
        await sp.setStringList('avisos_read_ids', _read.toList());
      } else {
        _read = stored.toSet();
      }
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(r);
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
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
          children: [
            const PageHeader(
              title: 'Avisos',
              subtitle: 'Comunicados da liderança para a igreja.',
              actions: [HeaderActions()],
            ),
            LoadSwitch(
              loading: _loading,
              skeleton: const SkeletonList(count: 4, height: 110),
              child: _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : _items.isEmpty
                      ? const EmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'Sem avisos por enquanto',
                          message: 'Os comunicados da igreja aparecem aqui.')
                      : Column(children: [
                          for (var i = 0; i < _items.length; i++)
                            Reveal(index: i, child: _card(t, _items[i])),
                        ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(TextTheme t, Map<String, dynamic> a) {
    final d = DateTime.parse(a['created_at']).toLocal();
    final tag = (a['tag'] as String?) ?? 'Geral';
    final id = '${a['id']}';
    final isNew = !_read.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isNew ? () => _markRead(id) : null,
        child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Pill(tag, dense: true),
              if (isNew) ...[
                const SizedBox(width: 6),
                Pill('Novo',
                    dense: true, fg: AppColors.primary, bg: AppColors.primarySoft),
              ],
              const Spacer(),
              Text(ago(d),
                  style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
            ]),
            const SizedBox(height: 10),
            Text('${a['title']}',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            if (a['body'] != null) ...[
              const SizedBox(height: 6),
              Text('${a['body']}', style: t.bodyMedium?.copyWith(height: 1.5)),
            ],
          ]),
        ),
        ),
      ),
    );
  }
}

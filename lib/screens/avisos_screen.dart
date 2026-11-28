import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/section.dart';
import '../widgets/site_hero.dart';
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
  Widget build(BuildContext context) => AvisosView(
        items: _items,
        loading: _loading,
        error: _error,
        read: _read,
        onRead: _markRead,
        onRefresh: _load,
        header: const [HeaderActions()],
      );
}

/// Corpo de Avisos, separado dos dados. Celular: cartões. Desktop (>= 1024): o
/// aviso mais recente no painel areia do site e os anteriores numa lista com fio.
class AvisosView extends StatelessWidget {
  const AvisosView({
    super.key,
    required this.items,
    this.loading = false,
    this.error,
    this.read = const {},
    required this.onRead,
    required this.onRefresh,
    this.header = const [],
  });
  final List<Map<String, dynamic>> items;
  final bool loading;
  final String? error;
  final Set<String> read;
  final void Function(String id) onRead;
  final Future<void> Function() onRefresh;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final pad = hPad(context);
    final t = Theme.of(context).textTheme;
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
              title: 'Avisos',
              subtitle: 'Comunicados da liderança para a igreja.',
              actions: header,
            ),
            LoadSwitch(
              loading: loading,
              skeleton: const SkeletonList(count: 4, height: 110),
              child: error != null
                  ? ErrorState(message: error!, onRetry: onRefresh)
                  : items.isEmpty
                      ? const EmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'Sem avisos por enquanto',
                          message: 'Os comunicados da igreja aparecem aqui.')
                      : desk
                          ? _desk()
                          : Column(children: [
                              for (var i = 0; i < items.length; i++)
                                Reveal(index: i, child: _card(t, items[i])),
                            ]),
            ),
          ],
        ),
      ),
    );
  }

  bool _isNew(Map<String, dynamic> a) => !read.contains('${a['id']}');

  Widget _card(TextTheme t, Map<String, dynamic> a) {
    final d = _date(a);
    final tag = (a['tag'] as String?) ?? 'Geral';
    final id = '${a['id']}';
    final isNew = _isNew(a);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isNew ? () => onRead(id) : null,
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

  Widget _desk() {
    final rest = items.skip(1).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _LatestPanel(a: items.first, isNew: _isNew(items.first), onRead: onRead),
      if (rest.isNotEmpty) ...[
        const SizedBox(height: 48),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Anteriores',
                    style: siteFont(36, FontWeight.w600,
                        color: AppColors.foreground, height: 1)),
                const SizedBox(height: 4),
                Text(rest.length == 1 ? '1 aviso' : '${rest.length} avisos',
                    style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
              ]),
            ),
          ),
          Expanded(
            child: Column(children: [
              for (var i = 0; i < rest.length; i++)
                _Row(a: rest[i], first: i == 0, isNew: _isNew(rest[i]), onRead: onRead),
            ]),
          ),
        ]),
      ],
    ]);
  }
}

DateTime _date(Map<String, dynamic> a) => DateTime.parse(a['created_at']).toLocal();

/// O aviso mais recente, no painel areia do hero do site.
class _LatestPanel extends StatelessWidget {
  const _LatestPanel({required this.a, required this.isNew, required this.onRead});
  final Map<String, dynamic> a;
  final bool isNew;
  final void Function(String id) onRead;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.siteInk;
    final d = _date(a);
    final tag = (a['tag'] as String?)?.trim();
    final body = (a['body'] as String?)?.trim() ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isNew ? () => onRead('${a['id']}') : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
        decoration: BoxDecoration(
          color: AppColors.siteBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 148,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d.day}', style: siteFont(88, FontWeight.w800, height: .9)),
              Text(mesesLongo[d.month - 1].toUpperCase(),
                  style: siteFont(24, FontWeight.w300, spacing: 2, height: 1.1)),
            ]),
          ),
          Container(width: 1, height: 112, color: ink.withValues(alpha: .25)),
          const SizedBox(width: 40),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['title']}'.toUpperCase(),
                  style: siteFont(44, FontWeight.w800, height: 1.0)),
              const SizedBox(height: 12),
              Text(
                [
                  if (isNew) 'Novo',
                  if (tag != null && tag.isNotEmpty) tag,
                  ago(d),
                ].join(' · '),
                style: siteFont(22, FontWeight.w400,
                    color: ink.withValues(alpha: .85), spacing: .4),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Text(body,
                      style: TextStyle(
                          fontSize: 16, height: 1.55, color: ink.withValues(alpha: .85))),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.a, required this.first, required this.isNew, required this.onRead});
  final Map<String, dynamic> a;
  final bool first;
  final bool isNew;
  final void Function(String id) onRead;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = _date(a);
    final tag = (a['tag'] as String?)?.trim();
    final body = (a['body'] as String?)?.trim() ?? '';
    final line = BorderSide(color: AppColors.border);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isNew ? () => onRead('${a['id']}') : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(top: first ? line : BorderSide.none, bottom: line),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 112,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d.day} ${mesesLongo[d.month - 1].substring(0, 3)}',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (tag != null && tag.isNotEmpty)
                Text(tag,
                    style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['title']}',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(body,
                    style: t.bodyMedium?.copyWith(
                        height: 1.5, color: AppColors.mutedForeground)),
              ],
            ]),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 72,
            child: isNew
                ? Text('Novo',
                    textAlign: TextAlign.right,
                    style: t.bodyMedium?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700))
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

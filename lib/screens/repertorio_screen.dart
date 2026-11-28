import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/chordpro.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';

final _db = Supabase.instance.client;

const _songSelect =
    'id,title,artist,classification,song_versions(id,name,key,original_key,bpm,duration_seconds,chords,notes)';

/// Aba "Repertório": busca por título/artista, tom da música e cifra.
class RepertorioView extends StatefulWidget {
  const RepertorioView({super.key});
  @override
  State<RepertorioView> createState() => _RepertorioViewState();
}

class _RepertorioViewState extends State<RepertorioView> {
  List<Map<String, dynamic>> _songs = [];
  String _q = '';
  int _sort = 0; // 0 A→Z · 1 Tom · 2 Mais recentes
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _norm(Object? v) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    var s = '$v'.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s;
  }

  String? _keyOf(Map<String, dynamic> s) {
    final vs = List.from(s['song_versions'] ?? []);
    return vs.isEmpty ? null : (vs.first as Map)['key'] as String?;
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> l) {
    int byTitle(Map<String, dynamic> a, Map<String, dynamic> b) =>
        _norm(a['title']).compareTo(_norm(b['title']));
    final out = [...l];
    switch (_sort) {
      case 1:
        out.sort((a, b) {
          final ka = _keyOf(a), kb = _keyOf(b);
          if (ka == null && kb != null) return 1;
          if (kb == null && ka != null) return -1;
          final c = (ka ?? '').compareTo(kb ?? '');
          return c != 0 ? c : byTitle(a, b);
        });
      case 2:
        out.sort((a, b) {
          final c = '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}');
          return c != 0 ? c : byTitle(a, b);
        });
      default:
        out.sort(byTitle);
    }
    return out;
  }

  Future<void> _load() async {
    try {
      List r;
      try {
        r = await _db
            .from('songs')
            .select('$_songSelect,created_at')
            .order('title');
      } catch (_) {
        // banco sem created_at: carrega sem a ordenação por recentes
        r = await _db.from('songs').select(_songSelect).order('title');
      }
      if (mounted) {
        setState(() {
          _songs = List<Map<String, dynamic>>.from(r);
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = _q.toLowerCase();
    final list = _sorted(_songs
        .where((s) =>
            q.isEmpty ||
            '${s['title']} ${s['artist']}'.toLowerCase().contains(q))
        .toList());
    return Column(children: [
      TextField(
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(
          hintText: 'Buscar por título ou artista',
          prefixIcon: Icon(Icons.search, color: AppColors.mutedForeground),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: _loading
              ? ListView(children: const [SkeletonList(count: 7, height: 64)])
              : _error != null
                  ? ListView(children: [ErrorState(message: _error!, onRetry: _load)])
                  : list.isEmpty
                      ? ListView(children: [
                          EmptyState(
                              icon: Icons.search_off,
                              title: 'Nada encontrado',
                              message: _q.isEmpty
                                  ? 'Cadastre músicas para montar o repertório.'
                                  : 'Nenhuma música para "$_q".')
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 32),
                          itemCount: list.length,
                          itemBuilder: (_, i) => Reveal(
                            index: i < 8 ? i : 0,
                            child: _row(t, list[i]),
                          ),
                        ),
        ),
      ),
    ]);
  }

  Widget _row(TextTheme t, Map<String, dynamic> s) {
    final vs = List.from(s['song_versions'] ?? []);
    final v = vs.isEmpty ? null : vs.first as Map;
    final hasChords = v != null && (v['chords'] ?? '').toString().isNotEmpty;
    final key = v?['key'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => SongDetailScreen(song: s))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppColors.navySoft, borderRadius: BorderRadius.circular(12)),
              child: Text(key ?? '–',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(s['artist'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
              ]),
            ),
            if (hasChords)
              Pill('Cifra',
                  fg: AppColors.primary,
                  bg: AppColors.primarySoft,
                  icon: Icons.queue_music,
                  dense: true),
          ]),
        ),
      ),
    );
  }
}

class SongDetailScreen extends StatefulWidget {
  const SongDetailScreen(
      {super.key, required this.song, this.playlist, this.index = 0});
  final Map<String, dynamic> song;
  final List<Map<String, dynamic>>? playlist;
  final int index;
  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  late int _i = widget.index;
  late Map<String, dynamic> _song =
      widget.playlist != null ? widget.playlist![widget.index] : widget.song;
  int _semitones = 0;
  bool _editing = false;
  SheetMode _mode = SheetMode.cifra;
  List<Map<String, dynamic>> _links = [];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  Map<String, dynamic>? get _v {
    final vs = List.from(_song['song_versions'] ?? []);
    return vs.isEmpty ? null : Map<String, dynamic>.from(vs.first as Map);
  }

  String get _chords => (_v?['chords'] ?? '').toString();

  // Tom escolhido para a escala (sel_key) em relação ao tom da igreja (key).
  int _initialSemis(Map<String, dynamic> s) {
    final vs = List.from(s['song_versions'] ?? []);
    if (vs.isEmpty) return 0;
    final v = vs.first as Map;
    final sel = v['sel_key'] as String?, church = v['key'] as String?;
    return (sel == null || church == null) ? 0 : semitonesBetween(church, sel);
  }

  // Nome do tom exibido: parte do tom escolhido na escala (ou do da igreja)
  // e aplica só o que o usuário transpôs a mais.
  String _tomLabel(String church) {
    final vs = List.from(_song['song_versions'] ?? []);
    final sel = vs.isEmpty ? null : (vs.first as Map)['sel_key'] as String?;
    final base = sel ?? church;
    return transposeChord(base, _semitones - _initialSemis(_song));
  }

  @override
  void initState() {
    super.initState();
    _semitones = _initialSemis(_song);
    _loadLinks();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadLinks() async {
    try {
      final r = await _db.from('song_links').select().eq('song_id', _song['id']);
      if (mounted) setState(() => _links = List<Map<String, dynamic>>.from(r));
    } catch (_) {}
  }

  void _go(int d) {
    final pl = widget.playlist;
    if (pl == null) return;
    final n = _i + d;
    if (n < 0 || n >= pl.length) return;
    setState(() {
      _i = n;
      _song = pl[n];
      _semitones = _initialSemis(pl[n]);
      _editing = false;
      _links = [];
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    _loadLinks();
  }

  Future<void> _saveChords() async {
    final v = _v;
    if (v == null) return;
    try {
      await _db
          .from('song_versions')
          .update({'chords': _ctrl.text}).eq('id', v['id']);
      setState(() {
        final vs = List.from(_song['song_versions']);
        vs[0] = {...Map<String, dynamic>.from(vs[0] as Map), 'chords': _ctrl.text};
        _song = {..._song, 'song_versions': vs};
        _editing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível salvar. ${friendlyError(e)}')));
      }
    }
  }

  String _dur(int? s) {
    if (s == null) return '';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _open(String url) async {
    final u = Uri.tryParse(url);
    if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = _v;
    final key = v?['key'] as String?;
    final cifraLink = _links.where((l) => l['kind'] == 'cifra').toList();
    final q = Uri.encodeComponent('${_song['title'] ?? ''} ${_song['artist'] ?? ''}');
    final pad = hPad(context);
    return Scaffold(
      bottomNavigationBar: widget.playlist == null ? null : _playlistBar(t),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
          children: [
            Row(children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Voltar'),
                style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Mais opções',
                icon: const Icon(Icons.more_vert),
                onSelected: (a) {
                  if (a == 'yt') {
                    _open('https://www.youtube.com/results?search_query=$q');
                  } else if (a == 'sp') {
                    _open('https://open.spotify.com/search/$q');
                  } else if (a == 'edit') {
                    setState(() {
                      _ctrl.text = _chords;
                      _editing = true;
                    });
                  } else if (a == 'add') {
                    setState(() {
                      _ctrl.text = '';
                      _editing = true;
                    });
                  } else if (a.startsWith('l:')) {
                    _open(a.substring(2));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'yt',
                      child: ListTile(
                          dense: true,
                          leading: Icon(Icons.play_circle_outline),
                          title: Text('Buscar no YouTube'))),
                  const PopupMenuItem(
                      value: 'sp',
                      child: ListTile(
                          dense: true,
                          leading: Icon(Icons.graphic_eq),
                          title: Text('Buscar no Spotify'))),
                  for (final l in _links)
                    PopupMenuItem(
                        value: 'l:${l['url']}',
                        child: ListTile(
                            dense: true,
                            leading: Icon(_linkIcon(l['kind'])),
                            title: Text(_linkLabel(l['kind'])))),
                  if (_v != null) const PopupMenuDivider(),
                  if (_v != null && _chords.isNotEmpty)
                    const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                            dense: true,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar'))),
                  if (_v != null)
                    const PopupMenuItem(
                        value: 'add',
                        child: ListTile(
                            dense: true,
                            leading: Icon(Icons.add),
                            title: Text('Adicionar cifra'))),
                ],
              ),
            ]),
            Text(_song['title'] ?? '',
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(_song['artist'] ?? '',
                style: t.bodyMedium?.copyWith(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (key != null) Pill('Tom ${_tomLabel(key)}', dense: true),
              if (key != null && _semitones % 12 != 0)
                Pill('Igreja $key', dense: true),
              if (_v?['original_key'] != null)
                Pill('Original ${_v?['original_key']}', dense: true),
              if (v?['bpm'] != null) Pill('${v!['bpm']} BPM', dense: true),
              if (v?['duration_seconds'] != null)
                Pill(_dur(v!['duration_seconds'] as int?), dense: true),
            ]),
            const SizedBox(height: 16),
            if (_editing) GlassCard(child: Padding(padding: const EdgeInsets.all(16), child: _editor(t))) else _viewer(t, cifraLink),
          ],
        ),
      ),
    );
  }

  IconData _linkIcon(String k) => switch (k) {
        'letra' => Icons.lyrics_outlined,
        'cifra' => Icons.queue_music,
        'audio' => Icons.headphones,
        'video' => Icons.play_circle_outline,
        _ => Icons.link,
      };

  String _linkLabel(String k) => switch (k) {
        'letra' => 'Letra',
        'cifra' => 'Cifra',
        'audio' => 'Áudio',
        'video' => 'Vídeo',
        _ => 'Link',
      };

  Widget _viewer(TextTheme t, List<Map<String, dynamic>> cifraLink) {
    if (_chords.isEmpty) {
      return GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Esta música ainda não tem cifra no app.',
                style: t.titleMedium?.copyWith(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _v == null
                  ? null
                  : () => setState(() {
                        _ctrl.text = '';
                        _editing = true;
                      }),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar cifra'),
            ),
            if (cifraLink.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _open(cifraLink.first['url']),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir cifra externa'),
              ),
            ],
          ]),
        ),
      );
    }
    final keyNow = _v?['key'] as String?;
    const order = [SheetMode.cifra, SheetMode.letra, SheetMode.smart];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 12,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.muted, borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  tooltip: 'Abaixar meio tom',
                  onPressed: () => setState(() => _semitones--),
                  icon: const Icon(Icons.remove, size: 18)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('TOM',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedForeground)),
                Text(keyNow != null ? _tomLabel(keyNow) : (_semitones == 0 ? '—' : '${_semitones > 0 ? '+' : ''}$_semitones'),
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ]),
              IconButton(
                  tooltip: 'Subir meio tom',
                  onPressed: () => setState(() => _semitones++),
                  icon: const Icon(Icons.add, size: 18)),
            ]),
          ),
          SizedBox(
            width: 260,
            child: SegTabs(
              labels: const ['Cifra', 'Letra', 'Smart'],
              index: order.indexOf(_mode),
              onChanged: (i) => setState(() => _mode = order[i]),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (_mode == SheetMode.smart)
        ChordSheet(source: _chords, semitones: _semitones, mode: _mode)
      else
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _mode == SheetMode.letra
                ? ChordSheet(source: _chords, mode: _mode)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ChordSheet(source: _chords, semitones: _semitones, mode: _mode),
                  ),
          ),
        ),
    ]);
  }

  Widget _editor(TextTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Use ChordPro: acordes entre colchetes, ex.: [G]Santo é o [D]Senhor. '
          'Seções com {comment: Refrão}.',
          style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
      const SizedBox(height: 10),
      TextField(
        controller: _ctrl,
        maxLines: 18,
        style: const TextStyle(fontFamily: 'Courier New', fontSize: 14),
        decoration: const InputDecoration(),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('Cancelar'))),
        const SizedBox(width: 10),
        Expanded(
            child: FilledButton(
                onPressed: _saveChords, child: const Text('Salvar'))),
      ]),
    ]);
  }

  Widget _playlistBar(TextTheme t) {
    final n = widget.playlist!.length;
    return GlassBar(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(
                tooltip: 'Música anterior',
                onPressed: _i > 0 ? () => _go(-1) : null,
                icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text('Música: ${_i + 1} de $n',
                  textAlign: TextAlign.center,
                  style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            IconButton(
                tooltip: 'Próxima música',
                onPressed: _i < n - 1 ? () => _go(1) : null,
                icon: const Icon(Icons.chevron_right)),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              for (var k = 0; k < n; k++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: k <= _i
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: .18),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

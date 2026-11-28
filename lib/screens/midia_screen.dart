import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/permissions.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Painel de Mídia: notícias, ao vivo, mensagens e devocionais.
/// O Master também edita os textos do site.
class MidiaScreen extends StatefulWidget {
  const MidiaScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<MidiaScreen> createState() => _MidiaScreenState();
}

class _MidiaScreenState extends State<MidiaScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pad = hPad(context);
    final master = widget.session.user?.isMaster == true;
    final tabs = <(String, Widget)>[
      (
        'Notícias',
        const _Crud(
          key: ValueKey('news'),
          table: 'news',
          titleKey: 'title',
          subKey: 'summary',
          order: 'published_at',
          fields: [
            _F('title', 'Título', req: true),
            _F('summary', 'Resumo (aparece no carrossel)'),
            _F('body', 'Texto completo', lines: 6),
            _F('image_url', 'Link da foto (https://…)'),
            _F('link_url', 'Link “Saiba mais” (opcional)'),
            _F('position', 'Ordem (0 = primeiro)', number: true),
          ],
          hasPublished: true,
        )
      ),
      ('Ao vivo', const _LiveForm()),
      (
        'Mensagens',
        const _Crud(
          key: ValueKey('sermons'),
          table: 'sermons',
          titleKey: 'title',
          subKey: 'preacher',
          order: 'preached_on',
          fields: [
            _F('title', 'Título', req: true),
            _F('preacher', 'Pregador(a)'),
            _F('youtube_url', 'Link do YouTube'),
            _F('summary', 'Resumo', lines: 4),
            _F('preached_on', 'Data', date: true),
          ],
          hasPublished: true,
        )
      ),
      (
        'Devocional',
        const _Crud(
          key: ValueKey('devotionals'),
          table: 'devotionals',
          titleKey: 'title',
          subKey: 'verse_ref',
          order: 'publish_on',
          fields: [
            _F('title', 'Título', req: true),
            _F('verse_ref', 'Referência (ex.: Salmo 23:1)'),
            _F('verse_text', 'Texto do versículo', lines: 3),
            _F('body', 'Reflexão', lines: 8, req: true),
            _F('author', 'Autor(a)'),
            _F('publish_on', 'Publicar em', date: true),
          ],
          hasPublished: true,
        )
      ),
      if (master) ('Site', const _SiteForm()),
    ];
    if (_tab >= tabs.length) _tab = 0;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
        children: [
          const PageHeader(
            title: 'Mídia',
            subtitle: 'Conteúdo que aparece na página inicial.',
            actions: [HeaderActions()],
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < tabs.length; i++)
              ChoiceChip(
                label: Text(tabs[i].$1),
                selected: i == _tab,
                onSelected: (_) => setState(() => _tab = i),
              ),
          ]),
          const SizedBox(height: 16),
          tabs[_tab].$2,
        ],
      ),
    );
  }
}

class _F {
  const _F(this.key, this.label,
      {this.lines = 1, this.date = false, this.req = false, this.number = false});
  final String key;
  final String label;
  final int lines;
  final bool date;
  final bool req;
  final bool number;
}

class _Crud extends StatefulWidget {
  const _Crud({
    super.key,
    required this.table,
    required this.titleKey,
    required this.subKey,
    required this.order,
    required this.fields,
    this.hasPublished = false,
  });
  final String table, titleKey, subKey, order;
  final List<_F> fields;
  final bool hasPublished;
  @override
  State<_Crud> createState() => _CrudState();
}

class _CrudState extends State<_Crud> {
  List<Map<String, dynamic>>? _rows;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _db
          .from(widget.table)
          .select()
          .order(widget.order, ascending: false);
      if (mounted) {
        setState(() {
          _rows = r.cast<Map<String, dynamic>>();
          _err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = friendlyError(e));
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final ok = await showAppSheet<bool>(
        context, (c) => _FormSheet(crud: widget, row: row));
    if (ok == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir?'),
        content: Text('“${row[widget.titleKey]}” será removido. Isso não pode ser desfeito.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _db.from(widget.table).delete().eq('id', row['id']);
      _load();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_err != null) return ErrorState(message: _err!, onRetry: _load);
    if (_rows == null) return const SkeletonList(count: 3, height: 70);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Novo')),
      ),
      const SizedBox(height: 12),
      if (_rows!.isEmpty)
        const EmptyState(icon: Icons.inbox_outlined, title: 'Nada cadastrado ainda'),
      for (final r in _rows!)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            onTap: () => _edit(r),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r[widget.titleKey]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    if ('${r[widget.subKey] ?? ''}'.isNotEmpty)
                      Text('${r[widget.subKey]}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
                  ]),
                ),
                if (widget.hasPublished && r['published'] != true)
                  const Pill('Rascunho', dense: true),
                IconButton(
                    tooltip: 'Excluir',
                    onPressed: () => _delete(r),
                    icon: Icon(Icons.delete_outline, color: AppColors.destructive)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _FormSheet extends StatefulWidget {
  const _FormSheet({required this.crud, this.row});
  final _Crud crud;
  final Map<String, dynamic>? row;
  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  late final Map<String, TextEditingController> _c = {
    for (final f in widget.crud.fields)
      f.key: TextEditingController(text: '${widget.row?[f.key] ?? (f.date ? DateTime.now().toIso8601String().substring(0, 10) : '')}'),
  };
  late bool _pub = widget.row?['published'] ?? true;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 1024 * 1024) {
      setState(() => _err = 'Foto maior que 1 MB. Reduza e tente de novo.');
      return;
    }
    setState(() { _busy = true; _err = null; });
    try {
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _db.storage.from('news').uploadBinary(name, bytes,
          fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg'));
      _c['image_url']!.text = _db.storage.from('news').getPublicUrl(name);
      setState(() => _busy = false);
    } catch (e) {
      setState(() { _busy = false; _err = friendlyError(e); });
    }
  }

  Future<void> _save() async {
    final data = <String, dynamic>{};
    for (final f in widget.crud.fields) {
      final v = _c[f.key]!.text.trim();
      if (f.req && v.isEmpty) {
        setState(() => _err = 'Preencha “${f.label}”.');
        return;
      }
      if (f.number) {
        data[f.key] = int.tryParse(v) ?? 0;
      } else {
        data[f.key] = v.isEmpty ? null : v;
      }
    }
    if (widget.crud.hasPublished) data['published'] = _pub;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final q = _db.from(widget.crud.table);
      if (widget.row == null) {
        await q.insert(data);
      } else {
        await q.update(data).eq('id', widget.row!['id']);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _busy = false;
        _err = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.row == null ? 'Novo' : 'Editar',
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        for (final f in widget.crud.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _c[f.key],
              readOnly: f.date,
              minLines: f.lines,
              maxLines: f.lines,
              keyboardType: f.number ? TextInputType.number : null,
              decoration: InputDecoration(
                  labelText: f.label + (f.req ? ' *' : ''),
                  suffixIcon: f.date ? const Icon(Icons.calendar_today, size: 18) : null),
              onTap: f.date
                  ? () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(_c[f.key]!.text) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        _c[f.key]!.text = d.toIso8601String().substring(0, 10);
                      }
                    }
                  : null,
            ),
          ),
        if (widget.crud.table == 'news')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
                onPressed: _busy ? null : _pickImage,
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: const Text('Enviar foto (até 1 MB)')),
          ),
        if (widget.crud.hasPublished)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Publicado'),
            subtitle: const Text('Desligado = rascunho, ninguém vê.'),
            value: _pub,
            onChanged: (v) => setState(() => _pub = v),
          ),
        if (_err != null)
          Text(_err!, style: t.bodySmall?.copyWith(color: AppColors.destructive)),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Salvando…' : 'Salvar')),
      ]),
    );
  }
}

class _LiveForm extends StatefulWidget {
  const _LiveForm();
  @override
  State<_LiveForm> createState() => _LiveFormState();
}

class _LiveFormState extends State<_LiveForm> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  bool _live = false, _loaded = false, _busy = false;

  @override
  void initState() {
    super.initState();
    _db.from('live_settings').select().maybeSingle().then((r) {
      if (!mounted) return;
      setState(() {
        _url.text = (r?['youtube_url'] as String?) ?? '';
        _title.text = (r?['title'] as String?) ?? '';
        _live = r?['is_live'] == true;
        _loaded = true;
      });
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _db.from('live_settings').update({
        'youtube_url': _url.text.trim().isEmpty ? null : _url.text.trim(),
        'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
        'is_live': _live,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', 1);
      if (mounted) toast(context, 'Salvo!');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SkeletonList(count: 2, height: 70);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
          controller: _url,
          decoration: const InputDecoration(labelText: 'Link do YouTube (ao vivo ou canal)')),
      const SizedBox(height: 12),
      TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Título (ex.: Culto de domingo)')),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Estamos ao vivo agora'),
        subtitle: const Text('Liga o destaque “Ao vivo” na página inicial.'),
        value: _live,
        onChanged: (v) => setState(() => _live = v),
      ),
      const SizedBox(height: 8),
      FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Salvando…' : 'Salvar')),
    ]);
  }
}

class _SiteForm extends StatefulWidget {
  const _SiteForm();
  @override
  State<_SiteForm> createState() => _SiteFormState();
}

class _SiteFormState extends State<_SiteForm> {
  static const _fields = <(String, String, int)>[
    ('about_text', 'Sobre nós', 6),
    ('address', 'Endereço', 2),
    ('maps_url', 'Link do mapa', 1),
    ('service_times', 'Horários (separe com | )', 2),
    ('instagram_url', 'Instagram', 1),
    ('whatsapp_url', 'WhatsApp (link wa.me/…; vazio = oculto)', 1),
  ];
  final _c = {for (final f in _fields) f.$1: TextEditingController()};
  bool _loaded = false, _busy = false;

  @override
  void initState() {
    super.initState();
    _db.from('site_settings').select().then((r) {
      if (!mounted) return;
      for (final s in r) {
        _c[s['key']]?.text = (s['value'] as String?) ?? '';
      }
      setState(() => _loaded = true);
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _db.from('site_settings').upsert([
        for (final f in _fields) {'key': f.$1, 'value': _c[f.$1]!.text.trim()},
      ]);
      if (mounted) toast(context, 'Salvo!');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SkeletonList(count: 3, height: 70);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in _fields)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _c[f.$1],
            minLines: f.$3,
            maxLines: f.$3,
            decoration: InputDecoration(labelText: f.$2),
          ),
        ),
      FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Salvando…' : 'Salvar')),
    ]);
  }
}

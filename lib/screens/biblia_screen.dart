import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';

const _nomes = [
  'Gênesis', 'Êxodo', 'Levítico', 'Números', 'Deuteronômio', 'Josué', 'Juízes',
  'Rute', '1 Samuel', '2 Samuel', '1 Reis', '2 Reis', '1 Crônicas',
  '2 Crônicas', 'Esdras', 'Neemias', 'Ester', 'Jó', 'Salmos', 'Provérbios',
  'Eclesiastes', 'Cantares', 'Isaías', 'Jeremias', 'Lamentações', 'Ezequiel',
  'Daniel', 'Oseias', 'Joel', 'Amós', 'Obadias', 'Jonas', 'Miqueias', 'Naum',
  'Habacuque', 'Sofonias', 'Ageu', 'Zacarias', 'Malaquias', 'Mateus', 'Marcos',
  'Lucas', 'João', 'Atos', 'Romanos', '1 Coríntios', '2 Coríntios', 'Gálatas',
  'Efésios', 'Filipenses', 'Colossenses', '1 Tessalonicenses',
  '2 Tessalonicenses', '1 Timóteo', '2 Timóteo', 'Tito', 'Filemom', 'Hebreus',
  'Tiago', '1 Pedro', '2 Pedro', '1 João', '2 João', '3 João', 'Judas',
  'Apocalipse',
];

class _Bible {
  _Bible(this.books);
  final List<List<List<String>>> books; // livro -> capítulo -> versículos
  static _Bible? _cache;
  static Future<_Bible> load() async {
    if (_cache != null) return _cache!;
    final raw = jsonDecode(await rootBundle.loadString('assets/biblia_arc.json'))
        as List;
    _cache = _Bible([
      for (final b in raw)
        [
          for (final c in (b['chapters'] as List))
            [for (final v in (c as List)) v as String]
        ]
    ]);
    return _cache!;
  }
}

/// Bíblia Almeida Revista e Corrigida (domínio público), dentro do app.
class BibliaScreen extends StatefulWidget {
  const BibliaScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<BibliaScreen> createState() => _BibliaScreenState();
}

class _BibliaScreenState extends State<BibliaScreen> {
  late final Future<_Bible> _f = _Bible.load();
  int? _book;
  int? _chap;
  double _size = 17;
  final _q = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final s = p.getDouble('bible_size');
      if (s != null && mounted) setState(() => _size = s);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _setSize(double v) {
    setState(() => _size = v.clamp(14, 28));
    SharedPreferences.getInstance().then((p) => p.setDouble('bible_size', _size));
  }

  void _back() {
    if (_chap != null) {
      setState(() => _chap = null);
    } else if (_book != null) {
      setState(() => _book = null);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = hPad(context);
    return PopScope(
      canPop: _book == null && _query.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_query.isNotEmpty) {
            _q.clear();
            setState(() => _query = '');
          } else {
            _back();
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<_Bible>(
            future: _f,
            builder: (c, s) {
              if (s.hasError) {
                return const ErrorState(message: 'Não foi possível abrir a Bíblia.');
              }
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final b = s.data!;
              return ListView(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      if (!(widget.embedded && _book == null))
                        TextButton.icon(
                          onPressed: _back,
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: Text(_book == null ? 'Voltar' : 'Livros')),
                      const Spacer(),
                      if (_chap != null) ...[
                        IconButton(
                            tooltip: 'Diminuir letra',
                            onPressed: () => _setSize(_size - 1),
                            icon: const Icon(Icons.text_decrease)),
                        IconButton(
                            tooltip: 'Aumentar letra',
                            onPressed: () => _setSize(_size + 1),
                            icon: const Icon(Icons.text_increase)),
                      ],
                    ]),
                  ),
                  if (_chap != null)
                    _reader(b)
                  else if (_book != null)
                    _chapters(b)
                  else
                    _books(b),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _books(_Bible b) {
    final t = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    Widget grid(int from, int to) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = from; i < to; i++)
            ActionChip(
              label: Text(_nomes[i]),
              onPressed: () => setState(() {
                _book = i;
                _chap = null;
              }),
            ),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(
          title: 'Bíblia', subtitle: 'Almeida Revista e Corrigida (ARC)'),
      TextField(
        controller: _q,
        decoration: InputDecoration(
          hintText: 'Buscar palavra ou versículo…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _q.clear();
                    setState(() => _query = '');
                  }),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      if (q.length >= 3) ..._search(b, q, t) else ...[
        const SectionTitle('Antigo Testamento'),
        grid(0, 39),
        const SectionTitle('Novo Testamento'),
        grid(39, 66),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => launchUrl(
              Uri.parse('https://www.bible.com/pt/versions/129'),
              mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Ler na NVI no YouVersion'),
        ),
      ],
    ]);
  }

  List<Widget> _search(_Bible b, String q, TextTheme t) {
    final out = <Widget>[];
    for (var bi = 0; bi < b.books.length && out.length < 40; bi++) {
      for (var ci = 0; ci < b.books[bi].length && out.length < 40; ci++) {
        final vs = b.books[bi][ci];
        for (var vi = 0; vi < vs.length && out.length < 40; vi++) {
          if (vs[vi].toLowerCase().contains(q)) {
            out.add(Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlassCard(
                onTap: () => setState(() {
                  _book = bi;
                  _chap = ci;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_nomes[bi]} ${ci + 1}:${vi + 1}',
                            style: t.labelLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(vs[vi], style: t.bodyMedium),
                      ]),
                ),
              ),
            ));
          }
        }
      }
    }
    if (out.isEmpty) {
      return [
        const EmptyState(icon: Icons.search_off, title: 'Nada encontrado')
      ];
    }
    return [const SizedBox(height: 4), ...out];
  }

  Widget _chapters(_Bible b) {
    final n = b.books[_book!].length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title: _nomes[_book!], subtitle: '$n capítulos'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < n; i++)
          SizedBox(
            width: 56,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => setState(() => _chap = i),
              child: Text('${i + 1}'),
            ),
          ),
      ]),
    ]);
  }

  Widget _reader(_Bible b) {
    final t = Theme.of(context).textTheme;
    final vs = b.books[_book!][_chap!];
    final hasPrev = _chap! > 0 || _book! > 0;
    final hasNext = _chap! < b.books[_book!].length - 1 || _book! < 65;
    void step(int d) => setState(() {
          var bk = _book!, ch = _chap! + d;
          if (ch < 0) {
            bk--;
            ch = b.books[bk].length - 1;
          } else if (ch >= b.books[bk].length) {
            bk++;
            ch = 0;
          }
          _book = bk;
          _chap = ch;
        });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title: '${_nomes[_book!]} ${_chap! + 1}'),
      for (var i = 0; i < vs.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: '${i + 1}  ',
                style: TextStyle(
                    fontSize: _size * .7,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
            TextSpan(text: vs[i]),
          ]), style: t.bodyLarge?.copyWith(fontSize: _size, height: 1.55)),
        ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: hasPrev ? () => step(-1) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'))),
        const SizedBox(width: 10),
        Expanded(
            child: FilledButton.icon(
                onPressed: hasNext ? () => step(1) : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Próximo'))),
      ]),
    ]);
  }
}

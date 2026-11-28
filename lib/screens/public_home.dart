import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/permissions.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/section.dart';
import '../widgets/site_hero.dart';
import '../widgets/ui.dart';
import 'biblia_screen.dart';
import 'login_screen.dart';

SupabaseClient get _db => Supabase.instance.client;

Future<void> _open(String? url) async {
  if (url == null || url.trim().isEmpty) return;
  await launchUrl(Uri.parse(url.trim()), mode: LaunchMode.externalApplication);
}

/// Carrega algo uma vez e mostra esqueleto / erro com "tentar de novo".
class _Async<T> extends StatefulWidget {
  const _Async({required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T) builder;
  @override
  State<_Async<T>> createState() => _AsyncState<T>();
}

class _AsyncState<T> extends State<_Async<T>> {
  late Future<T> _f = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (c, s) {
          if (s.hasError) {
            return ErrorState(
                message: friendlyError(s.error!),
                onRetry: () => setState(() => _f = widget.load()));
          }
          if (!s.hasData) return const SkeletonList(count: 3, height: 90);
          return widget.builder(c, s.data as T);
        },
      );
}

/// Início sem login: abre o app para qualquer pessoa.
class PublicShell extends StatefulWidget {
  const PublicShell({super.key, required this.session});
  final AppSession session;
  @override
  State<PublicShell> createState() => _PublicShellState();
}

class _PublicShellState extends State<PublicShell> {
  bool _login = false;
  @override
  Widget build(BuildContext context) {
    if (_login) {
      return LoginScreen(
          session: widget.session, onBack: () => setState(() => _login = false));
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PublicHome(session: widget.session, onLogin: () => setState(() => _login = true)),
      ),
    );
  }
}

class _HomeData {
  _HomeData(this.settings, this.news, this.live, this.campaign);
  final Map<String, String> settings;
  final List<Map<String, dynamic>> news;
  final Map<String, dynamic>? live;
  final Map<String, dynamic>? campaign;
}

Future<_HomeData> _loadHome() async {
  final r = await Future.wait<dynamic>([
    _db.from('site_settings').select(),
    _db
        .from('news')
        .select()
        .eq('published', true)
        .order('position')
        .order('published_at', ascending: false)
        .limit(8),
    _db.from('live_settings').select().maybeSingle(),
    _db
        .from('yakisoba_campaigns')
        .select()
        .eq('status', 'aberta')
        .gt('order_deadline', DateTime.now().toUtc().toIso8601String())
        .order('sale_date')
        .limit(1),
  ]);
  final settings = {
    for (final s in (r[0] as List)) s['key'] as String: (s['value'] as String?) ?? ''
  };
  final camps = (r[3] as List).cast<Map<String, dynamic>>();
  return _HomeData(
    settings,
    (r[1] as List).cast<Map<String, dynamic>>(),
    r[2] as Map<String, dynamic>?,
    camps.isEmpty ? null : camps.first,
  );
}

class PublicHome extends StatelessWidget {
  const PublicHome({super.key, required this.session, this.onLogin});
  final AppSession session;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final pad = hPad(context);
    final t = Theme.of(context).textTheme;
    final desk = MediaQuery.sizeOf(context).width >= 1024;
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
      children: [
        if (desk && onLogin == null) const SizedBox(height: 24)
        else if (desk) _PublicWebBar(onLogin: onLogin) else Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Row(children: [
            const BrandMark(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text('CEM Peruíbe',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const ThemeToggle(),
            if (onLogin != null) ...[
              const SizedBox(width: 8),
              FilledButton.tonal(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: onLogin, child: const Text('Entrar')),
            ],
          ]),
        ),
        _Async<_HomeData>(
          load: _loadHome,
          builder: (c, d) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!desk) _MobileIntro(settings: d.settings, live: d.live),
              if (desk)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SiteHero(
                    tag: 'CEM PERUÍBE',
                    light: 'ENCONTRO',
                    bold: 'COM CRISTO',
                    body: _heroBody(d.settings),
                    primaryLabel: 'Ver eventos',
                    onPrimary: () => _openSub(c, 'Eventos', const _EventosList()),
                    secondaryLabel:
                        _isLive(d.live) ? 'Assistir ao vivo' : 'Como chegar',
                    onSecondary: () => _isLive(d.live)
                        ? _open(d.live!['youtube_url'] as String?)
                        : _openMaps(d.settings),
                    imageUrl: d.settings['hero_image_url'],
                  ),
                ),              if (d.live != null &&
                  d.live!['is_live'] == true &&
                  (d.live!['youtube_url'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _LiveBanner(live: d.live!),
                ),
              if (d.news.isNotEmpty) ...[
                const SectionTitle('Notícias'),
                _NewsCarousel(items: d.news),
              ],
              const SectionTitle('Acesso rápido'),
              const _QuickTiles(),
              if (d.campaign != null) ...[
                const SectionTitle('Dia de Yakisoba'),
                _YakisobaCard(campaign: d.campaign!, session: session),
              ],
              if (desk || (d.settings['about_text'] ?? '').isNotEmpty) ...[
                const SectionTitle('Sobre nós'),
                _About(settings: d.settings, contact: desk),
              ],
              const SizedBox(height: 24),
              _Footer(settings: d.settings),
            ],
          ),
        ),
      ],
    );
  }
}

/// Paginas dos modulos publicos, para usar dentro do menu de quem esta logado.
Widget publicModulePage(Feature f) {
  final (title, child) = switch (f) {
    Feature.eventos => ('Eventos', const _EventosList()),
    Feature.mensagens => ('Mensagens', const _MensagensList()),
    Feature.devocional => ('Devocional', const _DevocionalList()),
    _ => ('Ao vivo', const _AoVivo()),
  };
  return Builder(builder: (context) {
    final pad = hPad(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
        children: [PageHeader(title: title), child],
      ),
    );
  });
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.live});
  final Map<String, dynamic> live;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      color: AppColors.primarySoft,
      onTap: () => _open(live['youtube_url'] as String?),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.sensors, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ao vivo agora',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text((live['title'] as String?)?.isNotEmpty == true
                  ? live['title'] as String
                  : 'Toque para assistir no YouTube'),
            ]),
          ),
          Icon(Icons.open_in_new, color: AppColors.primary),
        ]),
      ),
    );
  }
}

class _NewsCarousel extends StatefulWidget {
  const _NewsCarousel({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  State<_NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<_NewsCarousel> {
  final _c = PageController();
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!_c.hasClients) return;
        _c.animateToPage((_i + 1) % widget.items.length,
            duration: const Duration(milliseconds: 450), curve: kEase);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Column(children: [
      SizedBox(
        height: wide ? 300 : 210,
        child: PageView.builder(
          controller: _c,
          itemCount: widget.items.length,
          onPageChanged: (v) => setState(() => _i = v),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _NewsSlide(item: widget.items[i]),
          ),
        ),
      ),
      if (widget.items.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < widget.items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _i ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _i ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ]),
        ),
    ]);
  }
}

class _NewsSlide extends StatelessWidget {
  const _NewsSlide({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final img = item['image_url'] as String?;
    return GlassCard(
      radius: 20,
      onTap: () => showAppSheet(context, (c) => _NewsSheet(item: item)),
      child: Stack(fit: StackFit.expand, children: [
        if (img != null && img.isNotEmpty)
          Image.network(img,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppColors.navySoft))
        else
          Container(color: AppColors.navySoft),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: .78)],
              stops: const [.35, 1],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item['title'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                if ((item['summary'] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(item['summary'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(color: Colors.white70)),
                  ),
              ]),
        ),
      ]),
    );
  }
}

class _NewsSheet extends StatelessWidget {
  const _NewsSheet({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final link = item['link_url'] as String?;
    final img = item['image_url'] as String?;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (img != null && img.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(img,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ),
        Text(item['title'] as String,
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(((item['body'] as String?)?.isNotEmpty == true
                ? item['body']
                : item['summary'] ?? '') as String,
            style: t.bodyMedium?.copyWith(height: 1.5)),
        if (link != null && link.isNotEmpty) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: () => _open(link),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Saiba mais')),
        ],
      ]),
    );
  }
}

class _QuickTiles extends StatelessWidget {
  const _QuickTiles();
  @override
  Widget build(BuildContext context) {
    void go(String title, Widget page) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => _SubPage(title: title, child: page)));
    final tiles = <(IconData, String, VoidCallback)>[
      (Icons.event_outlined, 'Eventos', () => go('Eventos', const _EventosList())),
      (Icons.play_circle_outline, 'Mensagens',
          () => go('Mensagens', const _MensagensList())),
      (Icons.auto_stories_outlined, 'Devocional',
          () => go('Devocional', const _DevocionalList())),
      (Icons.sensors, 'Ao vivo', () => go('Ao vivo', const _AoVivo())),
      (Icons.menu_book_outlined, 'Bíblia', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BibliaScreen()))),
    ];
    Widget tile((IconData, String, VoidCallback) x, {double vpad = 16}) => GlassCard(
          onTap: x.$3,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: vpad),
            child: Column(children: [
              Icon(x.$1, color: AppColors.primary, size: 26),
              const SizedBox(height: 8),
              Text(x.$2,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    return LayoutBuilder(builder: (context, c) {
      // Largo: uma linha só, ocupando toda a largura.
      if (c.maxWidth >= 700) {
        return Row(children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: tile(tiles[i], vpad: 20)),
          ],
        ]);
      }
      final w = (c.maxWidth - 20) / 3;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final x in tiles) SizedBox(width: w, child: tile(x)),
      ]);
    });
  }
}

class _YakisobaCard extends StatelessWidget {
  const _YakisobaCard({required this.campaign, required this.session});
  final Map<String, dynamic> campaign;
  final AppSession session;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sale = DateTime.parse(campaign['sale_date'] as String);
    final dl = DateTime.parse(campaign['order_deadline'] as String).toLocal();
    final flavors = (campaign['flavors'] as List).cast<String>();
    return GlassCard(
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.ramen_dining, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Yakisoba dia ${two(sale.day)}/${two(sale.month)}',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Pill(brl(campaign['price'] as num)),
          ]),
          const SizedBox(height: 8),
          Text('Sabores: ${flavors.join(', ')}',
              style: t.bodyMedium?.copyWith(color: AppColors.mutedForeground)),
          Text(
              'Pedidos até ${two(dl.day)}/${two(dl.month)} às ${two(dl.hour)}:${two(dl.minute)}',
              style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
          if ((campaign['pickup_info'] as String?)?.isNotEmpty == true)
            Text('Retirada: ${campaign['pickup_info']}',
                style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => showAppSheet(
                context, (c) => _OrderSheet(campaign: campaign, session: session)),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Peça aqui'),
          ),
        ]),
      ),
    );
  }
}

class _OrderSheet extends StatefulWidget {
  const _OrderSheet({required this.campaign, required this.session});
  final Map<String, dynamic> campaign;
  final AppSession session;
  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  late final _name = TextEditingController(text: widget.session.user?.name ?? '');
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  late String _flavor = (widget.campaign['flavors'] as List).first as String;
  int _qty = 1;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await _db.rpc('place_yakisoba_order', params: {
        'p_campaign': widget.campaign['id'],
        'p_name': _name.text,
        'p_phone': _phone.text,
        'p_flavor': _flavor,
        'p_qty': _qty,
        'p_notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      toast(context, 'Pedido enviado! Combine o pagamento na retirada.');
    } catch (e) {
      setState(() {
        _busy = false;
        _err = e is PostgrestException && e.code == 'P0001'
            ? e.message
            : friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final flavors = (widget.campaign['flavors'] as List).cast<String>();
    final total = (widget.campaign['price'] as num) * _qty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Fazer pedido',
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Seu nome')),
        const SizedBox(height: 12),
        TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Telefone com DDD', hintText: '(13) 99999-9999')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _flavor,
          decoration: const InputDecoration(labelText: 'Sabor'),
          items: [
            for (final f in flavors) DropdownMenuItem(value: f, child: Text(f))
          ],
          onChanged: (v) => setState(() => _flavor = v ?? _flavor),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('Quantidade', style: t.bodyLarge)),
          IconButton.outlined(
              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
              icon: const Icon(Icons.remove)),
          SizedBox(
              width: 44,
              child: Text('$_qty',
                  textAlign: TextAlign.center, style: t.titleMedium)),
          IconButton.outlined(
              onPressed: _qty < 50 ? () => setState(() => _qty++) : null,
              icon: const Icon(Icons.add)),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Observação (opcional)')),
        if (_err != null) ...[
          const SizedBox(height: 12),
          Text(_err!, style: t.bodySmall?.copyWith(color: AppColors.destructive)),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: Text(_busy ? 'Enviando…' : 'Enviar pedido • ${brl(total)}'),
        ),
      ]),
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.settings, this.contact = true});
  final Map<String, String> settings;
  final bool contact;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final about = settings['about_text'] ?? '';
    final times = (settings['service_times'] ?? '')
        .split('|')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final address = settings['address'] ?? '';
    return GlassCard(
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (about.isNotEmpty) ...[
            Text(about, style: t.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 16),
          ],
          if (contact && times.isNotEmpty) ...[
            Text('Cultos', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final x in times)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(Icons.schedule, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(x),
                ]),
              ),
            const SizedBox(height: 12),
          ],
          if (contact && address.isNotEmpty) ...[
            Text('Endereço',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(address),
            if ((settings['maps_url'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                    onPressed: () => _open(settings['maps_url']),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Abrir no mapa')),
              ),
          ],
        ]),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.settings});
  final Map<String, String> settings;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ig = settings['instagram_url'] ?? '';
    final wa = settings['whatsapp_url'] ?? '';
    return Column(children: [
      Wrap(spacing: 10, children: [
        if (ig.isNotEmpty)
          OutlinedButton.icon(
              onPressed: () => _open(ig),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Instagram')),
        if (wa.isNotEmpty)
          OutlinedButton.icon(
              onPressed: () => _open(wa),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('WhatsApp')),
      ]),
      const SizedBox(height: 14),
      Text('CEM Church Peruíbe',
          style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
    ]);
  }
}

// ───────────────────────── Páginas internas ─────────────────────────

class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final pad = hPad(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Voltar')),
              ),
            ),
            PageHeader(title: title),
            child,
          ],
        ),
      ),
    );
  }
}

class _EventosList extends StatelessWidget {
  const _EventosList();
  @override
  Widget build(BuildContext context) => _Async<List<Map<String, dynamic>>>(
        load: () async => (await _db
                .from('church_events')
                .select()
                .gte('starts_at',
                    DateTime.now().subtract(const Duration(hours: 6)).toUtc().toIso8601String())
                .order('starts_at')
                .limit(40))
            .cast<Map<String, dynamic>>(),
        builder: (c, list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.event_outlined,
                title: 'Nenhum evento por enquanto',
                message: 'Quando houver novidades, elas aparecem aqui.');
          }
          return Column(children: [
            for (var i = 0; i < list.length; i++)
              Reveal(index: i, child: _EventTile(e: list[i])),
          ]);
        },
      );
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.e});
  final Map<String, dynamic> e;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = DateTime.parse(e['starts_at'] as String).toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(two(d.day),
                    style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
                Text(mesesLongo[d.month - 1].substring(0, 3).toUpperCase(),
                    style: t.labelSmall?.copyWith(color: AppColors.primary)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e['title'] as String,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                    '${two(d.hour)}:${two(d.minute)}${(e['location'] as String?)?.isNotEmpty == true ? ' • ${e['location']}' : ''}',
                    style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
                if ((e['description'] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(e['description'] as String, style: t.bodySmall),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MensagensList extends StatelessWidget {
  const _MensagensList();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _Async<List<Map<String, dynamic>>>(
      load: () async => (await _db
              .from('sermons')
              .select()
              .eq('published', true)
              .order('preached_on', ascending: false)
              .limit(50))
          .cast<Map<String, dynamic>>(),
      builder: (c, list) {
        if (list.isEmpty) {
          return const EmptyState(
              icon: Icons.play_circle_outline,
              title: 'Ainda não há mensagens',
              message: 'Os resumos e vídeos dos cultos aparecem aqui.');
        }
        return Column(children: [
          for (var i = 0; i < list.length; i++)
            Reveal(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () {
                    final u = list[i]['youtube_url'] as String?;
                    if (u != null && u.isNotEmpty) {
                      _open(u);
                    } else {
                      showAppSheet(
                          c,
                          (_) => Padding(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(list[i]['title'] as String,
                                          style: t.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 10),
                                      Text((list[i]['summary'] as String?) ?? ''),
                                    ]),
                              ));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(
                          (list[i]['youtube_url'] as String?)?.isNotEmpty == true
                              ? Icons.play_circle_fill
                              : Icons.notes,
                          color: AppColors.primary,
                          size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(list[i]['title'] as String,
                                  style: t.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              Text(
                                  [
                                    if ((list[i]['preacher'] as String?)?.isNotEmpty ==
                                        true)
                                      list[i]['preacher'],
                                    () {
                                      final d = DateTime.parse(
                                          list[i]['preached_on'] as String);
                                      return '${two(d.day)}/${two(d.month)}/${d.year}';
                                    }(),
                                  ].join(' • '),
                                  style: t.bodySmall?.copyWith(
                                      color: AppColors.mutedForeground)),
                              if ((list[i]['summary'] as String?)?.isNotEmpty ==
                                  true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(list[i]['summary'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.bodySmall),
                                ),
                            ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

class _DevocionalList extends StatelessWidget {
  const _DevocionalList();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _Async<List<Map<String, dynamic>>>(
      load: () async => (await _db
              .from('devotionals')
              .select()
              .eq('published', true)
              .lte('publish_on', DateTime.now().toIso8601String().substring(0, 10))
              .order('publish_on', ascending: false)
              .limit(30))
          .cast<Map<String, dynamic>>(),
      builder: (c, list) {
        if (list.isEmpty) {
          return const EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'Nenhum devocional ainda',
              message: 'Volte em breve.');
        }
        return Column(children: [
          for (var i = 0; i < list.length; i++)
            Reveal(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(list[i]['title'] as String,
                              style: t.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          if ((list[i]['verse_ref'] as String?)?.isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 8),
                            Text(
                                '${list[i]['verse_text'] ?? ''}\n— ${list[i]['verse_ref']}',
                                style: t.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.primary)),
                          ],
                          const SizedBox(height: 10),
                          Text(list[i]['body'] as String,
                              style: t.bodyMedium?.copyWith(height: 1.5)),
                          if ((list[i]['author'] as String?)?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(list[i]['author'] as String,
                                  style: t.bodySmall?.copyWith(
                                      color: AppColors.mutedForeground)),
                            ),
                        ]),
                  ),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

class _AoVivo extends StatelessWidget {
  const _AoVivo();
  @override
  Widget build(BuildContext context) => _Async<Map<String, dynamic>?>(
        load: () async => await _db.from('live_settings').select().maybeSingle(),
        builder: (c, live) {
          final url = (live?['youtube_url'] as String?) ?? '';
          final on = live?['is_live'] == true && url.isNotEmpty;
          return EmptyState(
            icon: on ? Icons.sensors : Icons.videocam_off_outlined,
            title: on ? 'Estamos ao vivo!' : 'Sem transmissão agora',
            message: on
                ? ((live?['title'] as String?) ?? 'Toque para assistir no YouTube.')
                : 'Nos cultos de quinta e domingo transmitimos pelo YouTube.',
            action: url.isEmpty
                ? null
                : FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => _open(url),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(on ? 'Assistir agora' : 'Abrir canal / último vídeo')),
          );
        },
      );
}

void _openSub(BuildContext c, String title, Widget page) => Navigator.of(c)
    .push(MaterialPageRoute(builder: (_) => _SubPage(title: title, child: page)));

/// Barra de site para visitante no desktop.
class _PublicWebBar extends StatelessWidget {
  const _PublicWebBar({this.onLogin});
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    Widget link(String label, VoidCallback onTap) => TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
              foregroundColor: AppColors.siteInk,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: Text(label, style: siteFont(19, FontWeight.w500)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Row(children: [
        const BrandMark(size: 40),
        const SizedBox(width: 12),
        Text('CEM PERU\u00cdBE', style: siteFont(24, FontWeight.w600, spacing: .4)),
        const Spacer(),
        link('Eventos', () => _openSub(context, 'Eventos', const _EventosList())),
        link('Mensagens',
            () => _openSub(context, 'Mensagens', const _MensagensList())),
        link('Devocional',
            () => _openSub(context, 'Devocional', const _DevocionalList())),
        link('Ao vivo', () => _openSub(context, 'Ao vivo', const _AoVivo())),
        link(
            'B\u00edblia',
            () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BibliaScreen()))),
        const SizedBox(width: 16),
        const SiteSocialDot(
            icon: Icons.photo_camera_outlined,
            url: 'https://www.instagram.com/cemchurchperuibe/',
            label: 'Instagram'),
        const SizedBox(width: 10),
        const ThemeToggle(),
        if (onLogin != null) ...[
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20)),
            onPressed: onLogin,
            child: Text('Entrar',
                style: siteFont(19, FontWeight.w500,
                    color: AppColors.siteOnAccent)),
          ),
        ],
      ]),
    );
  }
}

// ───────────── Culto e endereço (dados de site_settings) ─────────────

bool _isLive(Map<String, dynamic>? live) =>
    live != null &&
    live['is_live'] == true &&
    (live['youtube_url'] as String?)?.isNotEmpty == true;

List<String> _serviceTimes(Map<String, String> s) => (s['service_times'] ?? '')
    .split('|')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

Future<void> _openMaps(Map<String, String> s) {
  final url = s['maps_url'] ?? '';
  if (url.isNotEmpty) return _open(url);
  final a = s['address'] ?? '';
  return _open('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(a)}');
}

/// Texto do hero a partir dos horários e do endereço cadastrados.
String _heroBody(Map<String, String> s) {
  final times = _serviceTimes(s).map((t) {
    final i = t.indexOf(',');
    if (i <= 0) return t;
    final day = t.substring(0, i);
    return '${day.endsWith('s') ? day : '${day}s'}${t.substring(i)}';
  }).toList();
  final parts = (s['address'] ?? '').split(' - ');
  var addr = parts.first.trim();
  if (parts.length > 1 && parts[1].contains(',')) {
    addr = '$addr, ${parts[1].split(',').last.trim()}';
  }
  if (times.isEmpty && addr.isEmpty) {
    return 'Quintas, 20h às 21h30 · Domingos, 19h às 21h · Av. Padre Anchieta, 3793, Peruíbe.';
  }
  return '${[...times, if (addr.isNotEmpty) addr].join(' · ')}.';
}

const _weekdays = {
  'segunda': 1, 'terça': 2, 'terca': 2, 'quarta': 3, 'quinta': 4,
  'sexta': 5, 'sábado': 6, 'sabado': 6, 'domingo': 7,
};

/// Índice do próximo culto e o rótulo ("Agora", "Hoje", "Amanhã", "Próximo").
(int, String)? _nextService(List<String> times, DateTime now) {
  int? best;
  DateTime? bestAt;
  for (var i = 0; i < times.length; i++) {
    final low = times[i].toLowerCase();
    final day = _weekdays[low.split(RegExp(r'[,\s-]')).first];
    final m = RegExp(r'(\d{1,2})h(\d{2})?').firstMatch(low);
    if (day == null || m == null) continue;
    final ahead = (day - now.weekday + 7) % 7;
    var at = DateTime(now.year, now.month, now.day + ahead,
        int.parse(m.group(1)!), int.tryParse(m.group(2) ?? '') ?? 0);
    // Culto que começou há menos de 2h ainda conta como "agora".
    if (at.isBefore(now.subtract(const Duration(hours: 2)))) {
      at = at.add(const Duration(days: 7));
    }
    if (bestAt == null || at.isBefore(bestAt)) {
      best = i;
      bestAt = at;
    }
  }
  if (best == null || bestAt == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(bestAt.year, bestAt.month, bestAt.day).difference(today).inDays;
  final label = !bestAt.isAfter(now)
      ? 'Agora'
      : days == 0
          ? 'Hoje'
          : days == 1
              ? 'Amanhã'
              : 'Próximo';
  return (best, label);
}

/// Abertura da home no celular: o tema da igreja, quando é o culto e onde.
class _MobileIntro extends StatelessWidget {
  const _MobileIntro({required this.settings, this.live});
  final Map<String, String> settings;
  final Map<String, dynamic>? live;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.siteInk;
    final times = _serviceTimes(settings);
    final next = _nextService(times, DateTime.now());
    final address = settings['address'] ?? '';
    final liveNow = _isLive(live);
    final body = TextStyle(fontSize: 15, height: 1.4, color: ink);
    // Mesma pílula do hero do site.
    const btnShape = StadiumBorder();
    Widget line(IconData icon, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: ink.withValues(alpha: .8)),
            ),
            const SizedBox(width: 10),
            Expanded(child: child),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.siteBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ENCONTRO',
            style: siteFont(44, FontWeight.w300, spacing: 1.5, height: 1)),
        Text('COM CRISTO', style: siteFont(44, FontWeight.w800, height: 1.05)),
        const SizedBox(height: 20),
        for (var i = 0; i < times.length; i++)
          line(
            Icons.schedule,
            Row(children: [
              Expanded(
                child: Text(times[i],
                    style: body.copyWith(
                        fontWeight: next?.$1 == i ? FontWeight.w700 : FontWeight.w400)),
              ),
              if (next?.$1 == i)
                Text(next!.$2,
                    style: siteFont(16, FontWeight.w600,
                        color: ink.withValues(alpha: .75), spacing: .4)),
            ]),
          ),
        if (address.isNotEmpty)
          line(Icons.place_outlined, Text(address, style: body)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.siteAccent,
                  foregroundColor: AppColors.siteOnAccent,
                  minimumSize: const Size(0, 48),
                  shape: btnShape),
              onPressed: liveNow
                  ? () => _open(live!['youtube_url'] as String?)
                  : () => _openMaps(settings),
              child: Text(liveNow ? 'Assistir ao vivo' : 'Como chegar',
                  style: siteFont(19, FontWeight.w600,
                      color: AppColors.siteOnAccent)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  minimumSize: const Size(0, 48),
                  side: BorderSide(color: ink.withValues(alpha: .6)),
                  shape: btnShape),
              onPressed: liveNow
                  ? () => _openMaps(settings)
                  : () => _openSub(context, 'Eventos', const _EventosList()),
              child: Text(liveNow ? 'Como chegar' : 'Ver eventos',
                  style: siteFont(19, FontWeight.w600, color: ink)),
            ),
          ),
        ]),
      ]),
    );
  }
}

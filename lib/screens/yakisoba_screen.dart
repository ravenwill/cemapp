import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/permissions.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';

final _db = Supabase.instance.client;

DateTime _lastFriday(int y, int m) {
  var d = DateTime(y, m + 1, 0);
  while (d.weekday != DateTime.friday) {
    d = d.subtract(const Duration(days: 1));
  }
  return d;
}

/// Próxima "última sexta do mês" a partir de hoje.
DateTime nextSaleDate() {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  var d = _lastFriday(n.year, n.month);
  if (d.isBefore(today)) d = _lastFriday(n.year, n.month + 1);
  return d;
}

String _fmtShort(DateTime d) => '${two(d.day)}/${two(d.month)}';
String _fmtLong(DateTime d) =>
    '${diasSemana[d.weekday - 1]}, ${d.day} de ${mesesLongo[d.month - 1]}';

/// Venda mensal de yakisoba: o pedido abre perto da data (última sexta do mês).
class YakisobaScreen extends StatefulWidget {
  const YakisobaScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<YakisobaScreen> createState() => _YakisobaScreenState();
}

class _YakisobaScreenState extends State<YakisobaScreen> {
  Map<String, dynamic>? _camp;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  AppUser get _u => widget.session.user!;
  bool get _master => _u.isMaster;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cs = List<Map<String, dynamic>>.from(await _db
          .from('yakisoba_campaigns')
          .select()
          .order('sale_date', ascending: false)
          .limit(8));
      Map<String, dynamic>? cur;
      for (final c in cs) {
        if (c['status'] != 'entregue') {
          cur = c;
          break;
        }
      }
      var orders = <Map<String, dynamic>>[];
      if (cur != null) {
        orders = List<Map<String, dynamic>>.from(await _db
            .from('yakisoba_orders')
            .select()
            .eq('campaign_id', cur['id'])
            .order('created_at', ascending: false));
      }
      if (mounted) {
        setState(() {
          _camp = cur;
          _history = cs.where((c) => c['status'] == 'entregue').toList();
          _orders = orders;
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

  bool get _open {
    final c = _camp;
    if (c == null || c['status'] != 'aberta') return false;
    return DateTime.parse(c['order_deadline']).isAfter(DateTime.now());
  }

  double get _price => ((_camp?['price'] ?? 0) as num).toDouble();
  List<Map<String, dynamic>> get _active =>
      _orders.where((o) => o['status'] != 'cancelado').toList();
  List<Map<String, dynamic>> get _mine =>
      _orders.where((o) => o['user_id'] == _u.id).toList();

  Future<void> _run(Future<void> Function() f, {String? ok}) async {
    try {
      await f();
      if (ok != null && mounted) toast(context, ok);
      await _load();
    } catch (e) {
      if (mounted) toast(context, 'Não foi possível concluir. ${friendlyError(e)}');
    }
  }

  Future<void> _newOrder() async {
    final c = _camp!;
    final r = await showAppSheet<Map<String, dynamic>>(
        context,
        (_) => _OrderSheet(
            flavors: List<String>.from(c['flavors'] as List),
            price: _price,
            defaultName: _u.name,
            canForOthers: _master));
    if (r == null) return;
    await _run(() async {
      await _db.from('yakisoba_orders').insert({
        'campaign_id': c['id'],
        ...r,
        if (r['for_other'] == true) 'user_id': null,
      }..remove('for_other'));
    }, ok: 'Pedido registrado');
  }

  Future<void> _newCampaign() async {
    final r = await showAppSheet<Map<String, dynamic>>(
        context, (_) => const _CampaignSheet());
    if (r == null) return;
    await _run(() => _db.from('yakisoba_campaigns').insert(r),
        ok: 'Pedidos abertos');
  }

  Future<void> _cancel(Map<String, dynamic> o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancelar pedido?'),
        content: Text('${o['quantity']}× ${o['flavor']} será removido.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Manter')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cancelar pedido')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _db.from('yakisoba_orders').delete().eq('id', o['id']),
        ok: 'Pedido cancelado');
  }

  Future<void> _setOrder(Map<String, dynamic> o, Map<String, dynamic> patch) async {
    setState(() => o.addAll(patch));
    try {
      await _db.from('yakisoba_orders').update(patch).eq('id', o['id']);
    } catch (e) {
      if (mounted) toast(context, 'Não foi possível salvar. ${friendlyError(e)}');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = hPad(context);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
          children: [
            const PageHeader(
              title: 'Yakisoba',
              subtitle: 'Venda mensal da igreja, sempre na última sexta do mês',
              actions: [HeaderActions()],
            ),
            LoadSwitch(
              loading: _loading,
              skeleton: Shimmer(
                  child: Column(children: [
                Container(
                    height: 210,
                    decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(20))),
                const SizedBox(height: 28),
                const SkeletonList(count: 2),
              ])),
              child: _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : _body(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    var i = 0;
    Widget r(Widget w) => Reveal(index: i++, child: w);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      r(_camp == null ? _noCampaign() : _campaignCard()),
      if (_camp != null) ...[
        r(SectionTitle(_master ? 'Meus pedidos' : 'Seus pedidos')),
        r(_myOrders()),
      ],
      if (_master && _camp != null) ...[
        r(const SectionTitle('Painel da liderança')),
        r(_summary()),
        const SizedBox(height: 14),
        r(_allOrders()),
        const SizedBox(height: 14),
        r(_controls()),
      ],
      if (_history.isNotEmpty) ...[
        r(const SectionTitle('Vendas anteriores')),
        r(GlassCard(
          child: Column(children: [
            for (var k = 0; k < _history.length; k++) ...[
              if (k > 0) Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  DateBlock(DateTime.parse(_history[k]['sale_date'])),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(_fmtLong(DateTime.parse(_history[k]['sale_date'])),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Pill('Entregue',
                      fg: AppColors.success, bg: AppColors.successSoft, dense: true),
                ]),
              ),
            ],
          ]),
        )),
      ],
    ]);
  }

  Widget _noCampaign() {
    final t = Theme.of(context).textTheme;
    final next = nextSaleDate();
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            DateBlock(next, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Próxima venda prevista',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(_fmtLong(next),
                    style: t.bodyMedium?.copyWith(color: AppColors.mutedForeground)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Text(
              'Os pedidos ainda não foram abertos. Assim que a liderança abrir, você poderá pedir aqui e acompanhar o seu pedido.',
              style: t.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.45)),
          if (_master) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _newCampaign,
              icon: const Icon(Icons.add),
              label: Text('Abrir pedidos para ${_fmtShort(next)}'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _campaignCard() {
    final t = Theme.of(context).textTheme;
    final c = _camp!;
    final sale = DateTime.parse(c['sale_date']);
    final dl = DateTime.parse(c['order_deadline']).toLocal();
    final open = _open;
    final left = dl.difference(DateTime.now());
    final leftTxt = left.inDays >= 1
        ? 'faltam ${left.inDays} ${left.inDays == 1 ? 'dia' : 'dias'}'
        : left.inHours >= 1
            ? 'faltam ${left.inHours} h'
            : 'termina em instantes';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: .25)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(open ? 'Pedidos abertos' : 'Pedidos encerrados',
              fg: open ? AppColors.success : AppColors.warning,
              bg: open ? AppColors.successSoft : AppColors.warningSoft,
              icon: open ? Icons.lock_open : Icons.lock_outline),
          const Spacer(),
          if (open)
            Text(leftTxt,
                style: t.labelLarge?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        Text(_fmtLong(sale),
            style: t.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3)),
        const SizedBox(height: 4),
        CountUp(
          value: _price,
          builder: (v) => Text('${brl(v)} por porção',
              style: t.titleMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final f in (c['flavors'] as List))
            Pill('$f', fg: AppColors.foreground, bg: AppColors.card),
        ]),
        const SizedBox(height: 14),
        _info(Icons.schedule, 'Pedidos até ${_fmtLong(dl).toLowerCase()}, ${two(dl.hour)}h${two(dl.minute)}'),
        if (c['pickup_info'] != null) ...[
          const SizedBox(height: 6),
          _info(Icons.place_outlined, '${c['pickup_info']}'),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: open ? _newOrder : null,
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(open ? 'Fazer pedido' : 'Pedidos encerrados'),
        ),
      ]),
    );
  }

  Widget _info(IconData i, String s) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 17, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(s,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.secondary, height: 1.35))),
        ],
      );

  Pill _statusPill(Map<String, dynamic> o) {
    if (o['status'] == 'cancelado') {
      return Pill('Cancelado', fg: AppColors.destructive, bg: AppColors.destructiveSoft, dense: true);
    }
    if (o['status'] == 'entregue') {
      return Pill('Entregue', fg: AppColors.success, bg: AppColors.successSoft, dense: true, icon: Icons.check);
    }
    if (o['paid'] == true) {
      return Pill('Pago', fg: AppColors.success, bg: AppColors.successSoft, dense: true, icon: Icons.check);
    }
    return Pill('A pagar', fg: AppColors.warning, bg: AppColors.warningSoft, dense: true);
  }

  Widget _myOrders() {
    final t = Theme.of(context).textTheme;
    final mine = _mine;
    if (mine.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: GlassCard(
          child: EmptyState(
            icon: Icons.ramen_dining_outlined,
            title: 'Você ainda não fez pedido',
            message: _open
                ? 'Toque em "Fazer pedido" para escolher o sabor e a quantidade.'
                : null,
          ),
        ),
      );
    }
    final total = mine
        .where((o) => o['status'] != 'cancelado')
        .fold<double>(0, (s, o) => s + (o['quantity'] as int) * _price);
    final due = mine
        .where((o) => o['status'] != 'cancelado' && o['paid'] != true)
        .fold<double>(0, (s, o) => s + (o['quantity'] as int) * _price);
    return GlassCard(
      child: Column(children: [
        for (var k = 0; k < mine.length; k++) ...[
          if (k > 0) Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.navySoft,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${mine[k]['quantity']}×',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${mine[k]['flavor']}',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                      '${brl((mine[k]['quantity'] as int) * _price)}${mine[k]['notes'] != null ? ' · ${mine[k]['notes']}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
                ]),
              ),
              _statusPill(mine[k]),
              if (mine[k]['status'] == 'pedido' && mine[k]['paid'] != true && _open)
                IconButton(
                  tooltip: 'Cancelar pedido',
                  onPressed: () => _cancel(mine[k]),
                  icon: Icon(Icons.close, size: 20, color: AppColors.mutedForeground),
                )
              else
                const SizedBox(width: 8),
            ]),
          ),
        ],
        Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Text('Total do pedido',
                  style: t.bodyMedium?.copyWith(color: AppColors.secondary)),
            ),
            Text(brl(total),
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        ),
        if (due > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${brl(due)} a pagar na retirada, ou combine com a liderança.',
                    style: t.bodySmall?.copyWith(color: AppColors.secondary)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _summary() {
    final t = Theme.of(context).textTheme;
    final act = _active;
    final qty = act.fold<int>(0, (s, o) => s + (o['quantity'] as int));
    final paid = act
        .where((o) => o['paid'] == true)
        .fold<double>(0, (s, o) => s + (o['quantity'] as int) * _price);
    final byFlavor = <String, int>{};
    for (final o in act) {
      byFlavor['${o['flavor']}'] =
          (byFlavor['${o['flavor']}'] ?? 0) + (o['quantity'] as int);
    }
    final maxQ = byFlavor.values.fold<int>(1, (a, b) => b > a ? b : a);
    Widget stat(String label, Widget value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: t.labelMedium?.copyWith(color: AppColors.mutedForeground)),
            const SizedBox(height: 4),
            value,
          ]),
        );
    final big = t.titleLarge?.copyWith(fontWeight: FontWeight.w800);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            stat('Porções',
                CountUp(value: qty.toDouble(), builder: (v) => Text('${v.round()}', style: big))),
            stat('Previsto',
                CountUp(value: qty * _price, builder: (v) => Text(brl(v), style: big))),
            stat('Recebido',
                CountUp(value: paid, builder: (v) => Text(brl(v), style: big))),
          ]),
          if (byFlavor.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (final e in byFlavor.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(
                      width: 96,
                      child: Text(e.key,
                          style: t.bodySmall?.copyWith(color: AppColors.secondary))),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: e.value / maxQ),
                      duration: const Duration(milliseconds: 700),
                      curve: kEase,
                      builder: (_, v, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          backgroundColor: AppColors.muted,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                      width: 34,
                      child: Text('${e.value}',
                          textAlign: TextAlign.right,
                          style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800))),
                ]),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _allOrders() {
    final t = Theme.of(context).textTheme;
    if (_orders.isEmpty) {
      return const GlassCard(
          child: EmptyState(icon: Icons.inbox_outlined, title: 'Nenhum pedido ainda'));
    }
    return GlassCard(
      child: Column(children: [
        for (var k = 0; k < _orders.length; k++) ...[
          if (k > 0) Divider(height: 1, color: AppColors.border),
          _masterRow(t, _orders[k]),
        ],
      ]),
    );
  }

  Widget _masterRow(TextTheme t, Map<String, dynamic> o) {
    final cancelled = o['status'] == 'cancelado';
    return Opacity(
      opacity: cancelled ? .5 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
        child: Row(children: [
          Avatar(name: '${o['customer_name']}', size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${o['customer_name']}',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text('${o['quantity']}× ${o['flavor']} · ${brl((o['quantity'] as int) * _price)}',
                  style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
            ]),
          ),
          if (!cancelled) ...[
            FilterChip(
              label: const Text('Pago'),
              selected: o['paid'] == true,
              showCheckmark: false,
              avatar: o['paid'] == true ? const Icon(Icons.check, size: 16) : null,
              selectedColor: AppColors.successSoft,
              labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: o['paid'] == true ? AppColors.success : AppColors.secondary),
              onSelected: (v) => _setOrder(o, {'paid': v}),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais',
              icon: Icon(Icons.more_vert, size: 20, color: AppColors.mutedForeground),
              onSelected: (v) {
                if (v == 'entregue') _setOrder(o, {'status': 'entregue'});
                if (v == 'pedido') _setOrder(o, {'status': 'pedido'});
                if (v == 'cancelar') _setOrder(o, {'status': 'cancelado'});
              },
              itemBuilder: (_) => [
                if (o['status'] != 'entregue')
                  const PopupMenuItem(value: 'entregue', child: Text('Marcar como entregue')),
                if (o['status'] == 'entregue')
                  const PopupMenuItem(value: 'pedido', child: Text('Voltar para pedido')),
                const PopupMenuItem(value: 'cancelar', child: Text('Cancelar pedido')),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Pill('Cancelado', fg: AppColors.destructive, bg: AppColors.destructiveSoft, dense: true),
            ),
        ]),
      ),
    );
  }

  Widget _controls() {
    final c = _camp!;
    final aberta = c['status'] == 'aberta';
    return Wrap(spacing: 10, runSpacing: 10, children: [
      OutlinedButton.icon(
        onPressed: _open ? _newOrder : null,
        icon: const Icon(Icons.person_add_alt, size: 18),
        label: const Text('Pedido para outra pessoa'),
      ),
      OutlinedButton.icon(
        onPressed: () => _run(() => _db
            .from('yakisoba_campaigns')
            .update({'status': aberta ? 'encerrada' : 'aberta'}).eq('id', c['id'])),
        icon: Icon(aberta ? Icons.lock_outline : Icons.lock_open, size: 18),
        label: Text(aberta ? 'Encerrar pedidos' : 'Reabrir pedidos'),
      ),
      OutlinedButton.icon(
        onPressed: () => _run(
            () => _db.from('yakisoba_campaigns').update({'status': 'entregue'}).eq('id', c['id']),
            ok: 'Venda concluída'),
        icon: const Icon(Icons.done_all, size: 18),
        label: const Text('Concluir venda'),
      ),
    ]);
  }
}

// ───────────────────────────── Folhas de formulário ────────────────────────

class _OrderSheet extends StatefulWidget {
  const _OrderSheet(
      {required this.flavors,
      required this.price,
      required this.defaultName,
      required this.canForOthers});
  final List<String> flavors;
  final double price;
  final String defaultName;
  final bool canForOthers;
  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  late String _flavor = widget.flavors.first;
  int _qty = 1;
  bool _other = false;
  late final _name = TextEditingController(text: widget.defaultName);
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Fazer pedido',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Text('Sabor', style: t.labelLarge?.copyWith(color: AppColors.secondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in widget.flavors)
              ChoiceChip(
                label: Text(f),
                selected: _flavor == f,
                showCheckmark: false,
                selectedColor: AppColors.primarySoft,
                side: BorderSide(
                    color: _flavor == f ? AppColors.primary : Colors.transparent),
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _flavor == f ? AppColors.primary : AppColors.foreground),
                onSelected: (_) => setState(() => _flavor = f),
              ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: Text('Quantidade',
                  style: t.labelLarge?.copyWith(color: AppColors.secondary)),
            ),
            IconButton.outlined(
              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
              icon: const Icon(Icons.remove),
              tooltip: 'Diminuir',
            ),
            SizedBox(
              width: 48,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Text('$_qty',
                    key: ValueKey(_qty),
                    textAlign: TextAlign.center,
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
            IconButton.outlined(
              onPressed: _qty < 20 ? () => setState(() => _qty++) : null,
              icon: const Icon(Icons.add),
              tooltip: 'Aumentar',
            ),
          ]),
          const SizedBox(height: 18),
          if (widget.canForOthers)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _other,
              onChanged: (v) => setState(() {
                _other = v;
                _name.text = v ? '' : widget.defaultName;
              }),
              title: const Text('Pedido para outra pessoa'),
            ),
          TextField(
            controller: _name,
            readOnly: widget.canForOthers ? !_other : false,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLength: 80,
            decoration: const InputDecoration(
                labelText: 'Observação (opcional)', hintText: 'Ex.: sem cebola'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text('Total',
                  style: t.bodyMedium?.copyWith(color: AppColors.secondary)),
            ),
            Text(brl(_qty * widget.price),
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, {
                'customer_name': name,
                'flavor': _flavor,
                'quantity': _qty,
                if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
                'for_other': _other,
              });
            },
            child: const Text('Confirmar pedido'),
          ),
        ]),
      ),
    );
  }
}

class _CampaignSheet extends StatefulWidget {
  const _CampaignSheet();
  @override
  State<_CampaignSheet> createState() => _CampaignSheetState();
}

class _CampaignSheetState extends State<_CampaignSheet> {
  late DateTime _sale = nextSaleDate();
  late DateTime _deadline =
      DateTime(_sale.year, _sale.month, _sale.day - 2, 21);
  final _price = TextEditingController(text: '25,00');
  final _pickup = TextEditingController(text: 'Retirada no salão, a partir das 17h');

  @override
  void dispose() {
    _price.dispose();
    _pickup.dispose();
    super.dispose();
  }

  Future<void> _pickSale() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _sale,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 120)));
    if (d != null) {
      setState(() {
        _sale = d;
        _deadline = DateTime(d.year, d.month, d.day - 2, 21);
      });
    }
  }

  Future<void> _pickDeadline() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _deadline.isBefore(DateTime.now()) ? DateTime.now() : _deadline,
        firstDate: DateTime.now(),
        lastDate: _sale);
    if (d != null) setState(() => _deadline = DateTime(d.year, d.month, d.day, 21));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Abrir pedidos de yakisoba',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Por padrão é a última sexta do mês, com pedidos até 2 dias antes.',
              style: t.bodyMedium?.copyWith(color: AppColors.mutedForeground)),
          const SizedBox(height: 18),
          _tile(Icons.event, 'Dia da venda', _fmtLong(_sale), _pickSale),
          const SizedBox(height: 10),
          _tile(Icons.schedule, 'Pedidos até',
              '${_fmtShort(_deadline)} às 21h', _pickDeadline),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Preço por porção (R\$)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pickup,
            decoration: const InputDecoration(labelText: 'Retirada / entrega'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              final p = double.tryParse(_price.text.replaceAll(',', '.')) ?? 25;
              Navigator.pop(context, {
                'sale_date':
                    '${_sale.year}-${two(_sale.month)}-${two(_sale.day)}',
                'order_deadline': _deadline.toUtc().toIso8601String(),
                'price': p,
                'pickup_info': _pickup.text.trim().isEmpty ? null : _pickup.text.trim(),
              });
            },
            child: const Text('Abrir pedidos'),
          ),
        ]),
      ),
    );
  }

  Widget _tile(IconData i, String label, String value, VoidCallback onTap) =>
      GlassCard(
        onTap: onTap,
        radius: 12,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(i, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.mutedForeground)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
            Icon(Icons.edit_outlined, size: 18, color: AppColors.mutedForeground),
          ]),
        ),
      );
}

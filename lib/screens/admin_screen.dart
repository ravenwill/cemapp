import 'package:flutter/material.dart';

import '../core/permissions.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/header_actions.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';

/// Administração: o Master libera quais módulos cada pessoa enxerga.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = hPad(context);
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final members = session.members;
          return ListView(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
            children: [
              const PageHeader(
                title: 'Administração',
                subtitle: 'Escolha o que cada pessoa pode ver no app.',
                actions: [HeaderActions()],
              ),
              if (session.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(session.error!,
                      style: t.bodySmall?.copyWith(color: AppColors.destructive)),
                ),
              if (members.isEmpty)
                const SkeletonList(count: 3, height: 120)
              else
                for (var i = 0; i < members.length; i++)
                  Reveal(index: i, child: _card(context, t, members[i])),
            ],
          );
        },
      ),
    );
  }

  /// Aplica a mudança e avisa com opção de desfazer.
  Future<void> _toggle(BuildContext context, AppUser u, Feature f, bool on) async {
    final m = ScaffoldMessenger.of(context);
    final first = u.name.trim().split(' ').first;
    await session.toggle(u, f, on);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(on
          ? '${f.label} liberado para $first'
          : '${f.label} removido de $first'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () => session.toggle(u, f, !on),
      ),
    ));
  }

  Widget _card(BuildContext context, TextTheme t, AppUser u) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(name: u.name, url: u.avatarUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name,
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(u.email,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
                ]),
              ),
              u.isMaster
                  ? Pill('Master',
                      fg: AppColors.primary,
                      bg: AppColors.primarySoft,
                      icon: Icons.shield,
                      dense: true)
                  : const Pill('Membro', dense: true),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in Feature.values.where((f) => f.assignable))
                if (u.isMaster)
                  // Master sempre tem tudo: pílula estática, sem aparência de desabilitado.
                  Pill(f.label,
                      fg: AppColors.primary,
                      bg: AppColors.primarySoft,
                      icon: Icons.check_circle)
                else
                  FilterChip(
                  avatar: Icon(u.can(f) ? Icons.check_circle : f.icon,
                      size: 17,
                      color: u.can(f) ? AppColors.primary : AppColors.mutedForeground),
                  label: Text(f.label),
                  selected: u.can(f),
                  showCheckmark: false,
                  selectedColor: AppColors.primarySoft,
                  backgroundColor: AppColors.card,
                  side: BorderSide(
                      color: u.can(f) ? AppColors.primary : AppColors.border),
                  labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: u.can(f) ? AppColors.primary : AppColors.secondary),
                  onSelected: (v) => _toggle(context, u, f, v),
                ),
            ]),
            if (u.isMaster)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Master sempre tem acesso a tudo.',
                    style: t.bodySmall?.copyWith(color: AppColors.mutedForeground)),
              ),
          ]),
        ),
      ),
    );
  }
}

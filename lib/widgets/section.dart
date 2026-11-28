import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

/// Margem lateral: 20 no celular; centraliza o conteúdo em até 720px em telas
/// largas e em até 920px em telas grandes de desktop.
double hPad(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final maxContent = w >= 1200 ? 1120.0 : (w >= 1024 ? 960.0 : 720.0);
  return math.max(20.0, (w - maxContent) / 2);
}

/// Título de seção: rótulo pequeno com linha fina embaixo.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 32, 0, 12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: AppColors.foreground)),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 8),
          Divider(height: 1, color: AppColors.border),
        ]),
      );
}

/// Tile de ação em grade, com ícone em quadrado suave.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = color ?? AppColors.primary;
    return GlassCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c, size: 22),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(
                        color: AppColors.mutedForeground, height: 1.3)),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

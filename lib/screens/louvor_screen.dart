import 'package:flutter/material.dart';

import '../widgets/header_actions.dart';
import '../widgets/section.dart';
import '../widgets/ui.dart';
import 'equipe_screen.dart';
import 'escalas_screen.dart';
import 'repertorio_screen.dart';

/// Louvor: Escalas, Equipe e Repertório em abas (cada aba carrega ao abrir).
class LouvorScreen extends StatefulWidget {
  const LouvorScreen({super.key});
  @override
  State<LouvorScreen> createState() => _LouvorScreenState();
}

class _LouvorScreenState extends State<LouvorScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pad = hPad(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        child: Column(children: [
          const PageHeader(
            title: 'Louvor',
            subtitle: 'Ministério de louvor da CEM Peruíbe',
            actions: [HeaderActions()],
          ),
          SegTabs(
            labels: const ['Escalas', 'Equipe', 'Repertório'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LazyTabs(index: _tab, builders: [
              (_) => const EscalasView(),
              (_) => const EquipeView(),
              (_) => const RepertorioView(),
            ]),
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/permissions.dart';
import '../screens/perfil_screen.dart';
import 'ui.dart';

/// Disponibiliza a sessão para as páginas dentro do Shell.
class SessionScope extends InheritedWidget {
  const SessionScope({super.key, required this.session, required super.child});
  final AppSession session;

  static AppSession of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<SessionScope>()!.session;

  @override
  bool updateShouldNotify(SessionScope old) => old.session != session;
}

/// Ações do topo de cada página: alternar tema + perfil.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 1024) return const SizedBox.shrink();
    final session = SessionScope.of(context);
    final u = session.user!;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const ThemeToggle(),
      const SizedBox(width: 10),
      Semantics(
        button: true,
        label: 'Meu perfil',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PerfilScreen(session: session))),
          child: Avatar(name: u.name, url: u.avatarUrl, size: 42),
        ),
      ),
    ]);
  }
}

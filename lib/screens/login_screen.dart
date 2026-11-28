import 'package:flutter/material.dart';

import '../core/permissions.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.session, this.onBack});
  final AppSession session;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(children: [
          Positioned(top: 8, right: 12, child: const ThemeToggle()),
          if (onBack != null)
            Positioned(top: 8, left: 8, child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Voltar'))),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Reveal(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const BrandMark(size: 92),
                    const SizedBox(height: 20),
                    Text('CEM Peruíbe',
                        style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Sua igreja, conectada.',
                        style: t.bodyLarge?.copyWith(color: AppColors.mutedForeground)),
                    const SizedBox(height: 32),
                    GlassCard(
                      radius: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Entrar',
                                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                                'Use sua conta Google. O que você vê depende das permissões liberadas pela liderança.',
                                style: t.bodyMedium
                                    ?.copyWith(color: AppColors.mutedForeground)),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: session.signInWithGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 30),
                              label: const Text('Continuar com Google'),
                            ),
                            if (session.error != null) ...[
                              const SizedBox(height: 16),
                              Text(session.error!,
                                  style: t.bodySmall
                                      ?.copyWith(color: AppColors.destructive)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

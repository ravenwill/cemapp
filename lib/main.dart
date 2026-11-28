import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/permissions.dart';
import 'core/supabase_config.dart';
import 'screens/public_home.dart';
import 'screens/shell.dart';
import 'theme/app_theme.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  runApp(const CemApp());
}

class CemApp extends StatefulWidget {
  const CemApp({super.key});

  @override
  State<CemApp> createState() => _CemAppState();
}

class _CemAppState extends State<CemApp> with WidgetsBindingObserver {
  final session = AppSession();

  bool _isDesk() {
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    return v.physicalSize.width / v.devicePixelRatio >= 1024;
  }

  @override
  void didChangeMetrics() {
    final d = _isDesk();
    if (d != AppColors.warm) {
      AppColors.warm = d;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppColors.warm = _isDesk();
    session.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) => MaterialApp(
          // A chave refaz a árvore inteira ao trocar claro/escuro.
          key: ValueKey('${AppColors.dark}-${AppColors.warm}'),
          title: 'CEMAPP',
          debugShowCheckedModeBanner: false,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.build(),
          builder: (context, child) =>
              AppBackground(child: child ?? const SizedBox()),
          home: ListenableBuilder(
            listenable: session,
            builder: (context, child) {
              if (session.loading) return const _Splash();
              return session.user == null
                  ? PublicShell(session: session)
                  : Shell(key: ValueKey(session.user!.id), session: session);
            },
          ),
        ),
      );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .85, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (_, v, child) =>
                Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: v, child: child)),
            child: const BrandMark(size: 84),
          ),
        ),
      );
}

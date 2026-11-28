import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paleta CEM: tinta azul-marinho + cobre. Duas versões (clara e escura)
/// lidas pelo mesmo nome; troque [AppColors.dark] e reconstrua a árvore.
class AppColors {
  static bool dark = true;
  /// Desktop (>=1024px) no tema claro: paleta quente de site.
  static bool warm = false;
  static Color _w(int light, int dk, int wm) => Color(dark ? dk : wm);
  static Color _p(int light, int dk) => Color(dark ? dk : light);

  // Superfícies
  static Color get background => _w(0xFFF4F6F9, 0xFF1A1613, 0xFFFDF0E4);
  static Color get surface => _w(0xFFFFFFFF, 0xFF211B17, 0xFFF7E7D6);
  static Color get card => _w(0xFFFFFFFF, 0xFF2A221C, 0xFFFFF9F2);
  static Color get muted => _w(0xFFE9EDF3, 0xFF372D25, 0xFFEBD6C1);
  static Color get border => _w(0xFFDDE3EC, 0xFF4A3B2F, 0xFFDCC3A9);

  // Texto
  static Color get foreground => _w(0xFF0F1D2E, 0xFFFDF0E4, 0xFF2A2927);
  static Color get secondary => _w(0xFF3D4C5F, 0xFFDCC3A9, 0xFF4A4038);
  static Color get mutedForeground => _w(0xFF55657A, 0xFFB8A491, 0xFF6B5B4E);

  // Destaque (cobre)
  static Color get primary => _w(0xFFB4530A, 0xFFE3C9B0, 0xFF6F5B4D);
  static Color get onPrimary => _w(0xFFFFFFFF, 0xFF2A2927, 0xFFFFFFFF);
  static Color get accent => primary;
  static Color get primarySoft => _w(0xFFFBE9DA, 0xFF3B2F26, 0xFFEAD5C0);

  // Tinta (hero, avatares, seleção forte)
  static Color get navy => _w(0xFF16324F, 0xFF7A6455, 0xFF6F5B4D);
  static Color get navyDeep => _w(0xFF0F233A, 0xFF120E0B, 0xFF2A2927);
  static Color get navySoft => _w(0xFFE4EBF4, 0xFF30261F, 0xFFEAD5C0);
  static Color get onNavy => const Color(0xFFFFFFFF);

  // Semânticas
  static Color get success => _p(0xFF1E7A4D, 0xFF5FD39A);
  static Color get successSoft => _p(0xFFE3F4EB, 0xFF12301F);
  static Color get warning => _p(0xFF8A5A00, 0xFFF0C060);
  static Color get warningSoft => _p(0xFFFDF0D5, 0xFF3A2C0E);
  static Color get destructive => _p(0xFFB3261E, 0xFFFF8A80);
  static Color get destructiveSoft => _p(0xFFFBE4E1, 0xFF3A1816);

  // Versao "site" (desktop): hero e barra
  static Color get siteBg => dark ? const Color(0xFF241C17) : const Color(0xFFE3C9B0);
  static Color get siteInk => dark ? const Color(0xFFFDF0E4) : const Color(0xFF2A2927);
  static Color get siteAccent => dark ? primary : const Color(0xFF6F5B4D);
  static Color get siteOnAccent => dark ? onPrimary : const Color(0xFFFFFFFF);

  // Compatibilidade com nomes antigos
  static Color get brown => primarySoft;
  static Color get brownLight => primary;
}

/// Guarda e persiste a escolha claro/escuro.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  bool get dark => AppColors.dark;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getBool('dark_v2');
    final vw = ui.PlatformDispatcher.instance.views.first;
    final desk = vw.physicalSize.width / vw.devicePixelRatio >= 1024;
    AppColors.dark = v ??
        (desk ? false : ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark);
  }

  Future<void> setDark(bool v) async {
    if (AppColors.dark == v) return;
    AppColors.dark = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('dark_v2', v);
    } catch (_) {}
  }

  Future<void> toggle() => setDark(!AppColors.dark);
}

/// Transição entre telas: fade curto com leve subida.
class _FadeUpTransitions extends PageTransitionsBuilder {
  const _FadeUpTransitions();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondary, Widget child) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .025), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}

class AppTheme {
  static ThemeData build() {
    final dk = AppColors.dark;
    final brightness = dk ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.navy,
      onSecondary: AppColors.onNavy,
      error: AppColors.destructive,
      onError: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.foreground,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      surfaceContainerHighest: AppColors.muted,
    );

    final base = ThemeData(brightness: brightness);
    final family = GoogleFonts.plusJakartaSans().fontFamily;
    final text = base.textTheme.apply(
      fontFamily: family,
      bodyColor: AppColors.foreground,
      displayColor: AppColors.foreground,
    );

    RoundedRectangleBorder r(double v) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(v));
    OutlineInputBorder input(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: family,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.surface,
      textTheme: text,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: AppColors.primary.withValues(alpha: .06),
      focusColor: AppColors.primary.withValues(alpha: .14),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _FadeUpTransitions(),
        TargetPlatform.iOS: _FadeUpTransitions(),
        TargetPlatform.windows: _FadeUpTransitions(),
        TargetPlatform.macOS: _FadeUpTransitions(),
        TargetPlatform.linux: _FadeUpTransitions(),
        TargetPlatform.fuchsia: _FadeUpTransitions(),
      }),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: .28),
        selectionHandleColor: AppColors.primary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(8),
        thumbColor: WidgetStatePropertyAll(
            AppColors.mutedForeground.withValues(alpha: .35)),
      ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: AppColors.primary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.2),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: r(12),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: AppColors.foreground,
          side: BorderSide(color: AppColors.border),
          shape: r(12),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.foreground),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.muted,
        selectedColor: AppColors.navy,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge?.copyWith(color: AppColors.foreground),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(r(10)),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.card
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.foreground
                  : AppColors.mutedForeground),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: TextStyle(color: AppColors.mutedForeground),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: input(AppColors.border),
        enabledBorder: input(AppColors.border),
        focusedBorder: input(AppColors.primary, 1.6),
        errorBorder: input(AppColors.destructive),
        focusedErrorBorder: input(AppColors.destructive, 1.6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: r(20),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.card,
        modalBackgroundColor: AppColors.card,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dk ? AppColors.muted : AppColors.navyDeep,
        contentTextStyle: TextStyle(
            color: dk ? AppColors.foreground : Colors.white,
            fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: r(12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.onPrimary
                : AppColors.mutedForeground),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted),
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.navyDeep,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, space: 1),
    );
  }
}

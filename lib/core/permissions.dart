import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Funções (módulos) que o usuário Master pode liberar para cada pessoa.
/// O `key` é o valor gravado na tabela `user_features`.
enum Feature {
  igreja('igreja', 'Igreja', Icons.church_outlined, Icons.church),
  louvor('louvor', 'Louvor', Icons.music_note_outlined, Icons.music_note),
  agenda('agenda', 'Agenda', Icons.calendar_month_outlined, Icons.calendar_month),
  avisos('avisos', 'Avisos', Icons.campaign_outlined, Icons.campaign),
  yakisoba('yakisoba', 'Yakisoba', Icons.ramen_dining_outlined, Icons.ramen_dining),
  oracao('oracao', 'Oração', Icons.volunteer_activism_outlined,
      Icons.volunteer_activism),
  biblia('biblia', 'B\u00edblia', Icons.menu_book_outlined, Icons.menu_book),
  eventos('eventos', 'Eventos', Icons.event_outlined, Icons.event),
  mensagens('mensagens', 'Mensagens', Icons.play_circle_outline, Icons.play_circle),
  devocional('devocional', 'Devocional', Icons.auto_stories_outlined, Icons.auto_stories),
  aovivo('aovivo', 'Ao vivo', Icons.sensors, Icons.sensors),
  midia('midia', 'M\u00eddia', Icons.perm_media_outlined, Icons.perm_media),
  admin('admin', 'Admin', Icons.shield_outlined, Icons.shield);
  const Feature(this.key, this.label, this.icon, this.selectedIcon);
  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Se o Master pode liberar este modulo para alguem.
  /// Modulos abertos a todos que entraram (nao dependem de liberacao).
  bool get isOpen => const {igreja, biblia, eventos, mensagens, devocional, aovivo}.contains(this);
  bool get assignable => !isOpen;

  static Feature? fromKey(String k) {
    for (final f in values) {
      if (f.key == k) return f;
    }
    return null;
  }
}

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.isMaster = false,
    Set<Feature>? features,
  }) : features = features ?? {};

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isMaster;
  final Set<Feature> features;
  /// Líder do ministério de louvor (pode criar e editar escalas).
  bool isLeader = false;

  bool get canManage => isMaster || isLeader;
  bool can(Feature f) => f.isOpen || isMaster || features.contains(f);
}

/// Sessão real: Supabase Auth (Google) + perfil e permissões do banco.
class AppSession extends ChangeNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  AppUser? _user;
  AppUser? get user => _user;

  bool loading = true;
  String? error;
  List<AppUser> members = [];
  StreamSubscription<AuthState>? _sub;

  Future<void> init() async {
    _sub = _db.auth.onAuthStateChange.listen((_) => _refresh());
    await _refresh();
  }

  Future<void> _refresh() async {
    final authUser = _db.auth.currentUser;
    if (authUser == null) {
      _user = null;
      members = [];
      loading = false;
      notifyListeners();
      return;
    }
    try {
      final p =
          await _db.from('profiles').select().eq('id', authUser.id).single();
      final f = await _db
          .from('user_features')
          .select('feature')
          .eq('user_id', authUser.id);
      _user = _fromRow(p, f);
      try {
        final lm = await _db
            .from('ministry_members')
            .select('is_leader')
            .eq('user_id', authUser.id);
        _user!.isLeader = lm.any((r) => r['is_leader'] == true);
      } catch (_) {}
      error = null;
      if (_user!.isMaster) await loadMembers();
    } catch (e) {
      error = 'Não foi possível carregar seu perfil: $e';
    }
    loading = false;
    notifyListeners();
  }

  AppUser _fromRow(Map<String, dynamic> p, List<dynamic> feats) => AppUser(
        id: p['id'] as String,
        name: (p['name'] as String?) ?? (p['email'] as String? ?? ''),
        email: (p['email'] as String?) ?? '',
        avatarUrl: p['avatar_url'] as String?,
        isMaster: p['is_master'] == true,
        features: {
          for (final r in feats)
            if (Feature.fromKey((r as Map)['feature'] as String) != null)
              Feature.fromKey(r['feature'] as String)!,
        },
      );

  Future<void> loadMembers() async {
    final profiles = await _db.from('profiles').select().order('name');
    final feats = await _db.from('user_features').select();
    members = [
      for (final p in profiles)
        _fromRow(
          p,
          feats.where((r) => r['user_id'] == p['id']).toList(),
        ),
    ];
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    await _db.auth.signInWithOAuth(
      OAuthProvider.google,
      // Web: volta para a própria página. Celular: link profundo do app.
      redirectTo: kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : 'br.org.cem.cemapp://login-callback',
    );
  }

  Future<void> signOut() => _db.auth.signOut();

  /// Só o Master consegue gravar (RLS). Atualiza a tela na hora.
  Future<void> toggle(AppUser u, Feature f, bool on) async {
    try {
      if (on) {
        await _db
            .from('user_features')
            .upsert({'user_id': u.id, 'feature': f.key});
        u.features.add(f);
      } else {
        await _db
            .from('user_features')
            .delete()
            .eq('user_id', u.id)
            .eq('feature', f.key);
        u.features.remove(f);
      }
      notifyListeners();
    } catch (e) {
      error = 'Não foi possível salvar a permissão: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}



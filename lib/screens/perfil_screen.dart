import 'package:flutter/material.dart';
import '../widgets/ui.dart' show friendlyError;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/permissions.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/section.dart';

final _db = Supabase.instance.client;

IconData roleIcon(String? r) {
  final n = (r ?? '').toLowerCase();
  if (n.contains('vocal')) return Icons.mic;
  if (n.contains('ministro')) return Icons.record_voice_over;
  if (n.contains('viol') || n.contains('guitar')) return Icons.music_note;
  if (n.contains('baixo')) return Icons.graphic_eq;
  if (n.contains('bater')) return Icons.album;
  if (n.contains('tecl')) return Icons.piano;
  if (n.contains('mesa') || n.contains('som')) return Icons.tune;
  return Icons.person;
}

String fmtBirthday(String? iso) {
  if (iso == null) return 'Não informada';
  final d = DateTime.parse(iso);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  String? _birthday;
  List<String> _roles = [];
  bool _loading = true;

  AppUser get _u => widget.session.user!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _db
          .from('profiles')
          .select('birthday')
          .eq('id', _u.id)
          .single();
      _birthday = p['birthday'] as String?;
      final r = await _db
          .from('ministry_people')
          .select('roles')
          .eq('user_id', _u.id);
      final set = <String>{};
      for (final row in r) {
        set.addAll(List<String>.from(row['roles'] ?? []));
      }
      _roles = set.toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate:
          _birthday != null ? DateTime.parse(_birthday!) : DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (d == null) return;
    final iso =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      await _db.from('profiles').update({'birthday': iso}).eq('id', _u.id);
      setState(() => _birthday = iso);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível salvar. ${friendlyError(e)}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final u = _u;
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad(context), 8, hPad(context), 32),
        children: [
          GlassCard(
            radius: 28,
            color: AppColors.primary.withValues(alpha: .12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      u.avatarUrl != null ? NetworkImage(u.avatarUrl!) : null,
                  child: u.avatarUrl == null
                      ? Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w800))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(u.name,
                    textAlign: TextAlign.center,
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(u.email,
                    style: t.bodyMedium
                        ?.copyWith(color: AppColors.mutedForeground)),
                if (u.isMaster) ...[
                  const SizedBox(height: 10),
                  Chip(
                    label: Text('Master',
                        style: TextStyle(
                            color: AppColors.primary, fontWeight: FontWeight.w800)),
                    backgroundColor: AppColors.primarySoft,
                    side: BorderSide(color: AppColors.primary.withAlpha(90)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Permissões'),
                subtitle: Text(u.isMaster
                    ? 'Todos os módulos'
                    : (u.features.isEmpty
                        ? 'Nenhum módulo liberado'
                        : Feature.values
                            .where((f) => f.assignable)
                            .where(u.features.contains)
                            .map((f) => f.label)
                            .join(' · '))),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Data de nascimento'),
                subtitle: Text(_loading ? '...' : fmtBirthday(_birthday)),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: _pickBirthday,
              ),
            ]),
          ),
          SectionTitle('Funções (${_roles.length})'),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _roles.isEmpty
                  ? Text(
                      _loading
                          ? '...'
                          : 'Nenhuma função vinculada ainda. O administrador '
                              'liga seu e-mail à equipe.',
                      style: t.bodyMedium
                          ?.copyWith(color: AppColors.mutedForeground))
                  : Wrap(
                      spacing: 20,
                      runSpacing: 16,
                      children: [
                        for (final r in _roles)
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: .16),
                              child: Icon(roleIcon(r),
                                  color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(height: 6),
                            Text(r, style: t.bodySmall),
                          ]),
                      ],
                    ),
            ),
          ),
          const SectionTitle('Contas vinculadas'),
          GlassCard(
            child: ListTile(
              leading: const Icon(Icons.g_mobiledata, size: 32),
              title: const Text('Login com Google'),
              subtitle: Text(u.email),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive),
            onPressed: () {
              Navigator.of(context).pop();
              widget.session.signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';

class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final classesAsync = user != null
        ? ref.watch(classesProvider(user.uid))
        : const AsyncValue<List>.loading();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scholaro',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                  if (user?.email != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        user!.displayName ?? user.email ?? '',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.8)),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Classes ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('CLASSES',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.2)),
            ),
            classesAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox(),
              data: (classes) => classes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text('No classes yet',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : Column(
                      children: classes
                          .map((cls) => ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  child: Text(
                                    cls.name.isNotEmpty
                                        ? cls.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                title: Text(cls.name),
                                subtitle: Text('${cls.studentCount} students',
                                    style: const TextStyle(fontSize: 11)),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.go(
                                    '/teacher/class/${cls.teacherId}/${cls.id}/detail',
                                    extra: cls.name,
                                  );
                                },
                              ))
                          .toList(),
                    ),
            ),

            const Divider(),

            // ── Reports ──
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Reports'),
              onTap: () {
                Navigator.of(context).pop();
                _showReportsDialog(context, ref, user?.uid ?? '');
              },
            ),

            const Spacer(),
            const Divider(),

            // ── Theme Toggle ──
            Builder(builder: (context) {
              final themeMode = ref.watch(themeModeProvider);
              final isDark = themeMode == ThemeMode.dark;
              return SwitchListTile(
                secondary: Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                ),
                title: Text(isDark ? 'Dark Mode' : 'Light Mode'),
                value: isDark,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggle(),
              );
            }),

            // ── Logout ──
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReportsDialog(BuildContext context, WidgetRef ref, String teacherId) {
    if (teacherId.isEmpty) return;
    final classesAsync = ref.read(classesProvider(teacherId));
    final classes = classesAsync.value ?? [];
    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No classes to export')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select class to export'),
        children: classes
            .map((cls) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go(
                      '/teacher/class/${cls.teacherId}/${cls.id}/export',
                      extra: cls.name,
                    );
                  },
                  child: Text(cls.name),
                ))
            .toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(studentSessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (session) {
        final studentId = session['studentId'];
        final classId = session['classId'];
        final teacherId = session['teacherId'];

        if (studentId == null || classId == null || teacherId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final themeMode = ref.watch(themeModeProvider);
        final isDark = themeMode == ThemeMode.dark;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Dashboard'),
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                onPressed: () =>
                    ref.read(themeModeProvider.notifier).toggle(),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/');
                },
              ),
            ],
          ),
          body: GridView.count(
            padding: const EdgeInsets.all(24),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _DashCard(
                icon: Icons.assignment,
                label: 'Homework',
                color: Colors.blue,
                onTap: () => context.push(
                    '/student/homework/$teacherId/$classId/$studentId'),
              ),
              _DashCard(
                icon: Icons.star,
                label: 'Participation',
                color: Colors.orange,
                onTap: () => context.push(
                    '/student/participation/$teacherId/$classId/$studentId'),
              ),
              _DashCard(
                icon: Icons.quiz,
                label: 'Quizzes',
                color: Colors.green,
                onTap: () => context.push(
                    '/student/quizzes/$teacherId/$classId/$studentId'),
              ),
              _DashCard(
                icon: Icons.folder_open,
                label: 'Portfolio',
                color: Colors.purple,
                onTap: () => context.push(
                    '/student/portfolio/$teacherId/$classId/$studentId'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DashCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

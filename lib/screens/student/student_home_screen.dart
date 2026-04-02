import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../widgets/scholaro_logo.dart';

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
        final roleAsync = ref.watch(currentRoleProvider);
        final isMonitor = roleAsync.value == 'homework_monitor';

        final params = ClassParams(teacherId: teacherId, classId: classId);
        final studentsAsync = ref.watch(studentsFutureProvider(params));
        final classesAsync = ref.watch(classesProvider(teacherId));

        final studentName = studentsAsync.value
            ?.where((s) => s.id == studentId)
            .map((s) => s.fullName)
            .firstOrNull ?? '';
        final className = classesAsync.value
            ?.where((c) => c.id == classId)
            .map((c) => c.name)
            .firstOrNull ?? '';

        return Scaffold(
          appBar: AppBar(
            title: const ScholaroLogo(iconSize: 28, horizontal: true),
            actions: [
              if (isMonitor)
                IconButton(
                  icon: const Icon(Icons.rate_review_outlined),
                  tooltip: 'Switch to Monitor View',
                  onPressed: () {
                    ref.invalidate(monitorSessionProvider);
                    context.go('/monitor/home');
                  },
                ),
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
          body: Column(
            children: [
              // ── Student info header ─────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        studentName.isNotEmpty
                            ? studentName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (className.isNotEmpty)
                            Text(
                              className,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Dashboard grid ──────────────────────────────────────
              Expanded(
                child: GridView.count(
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClassDetailScreen extends StatelessWidget {
  final String teacherId;
  final String classId;
  final String className;

  const ClassDetailScreen({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    final sections = [
      _Section('Students', Icons.people_outline, Colors.blue,
          '/teacher/class/$teacherId/$classId/students'),
      _Section('Homework', Icons.assignment_outlined, Colors.green,
          '/teacher/class/$teacherId/$classId/homework'),
      _Section('Participation', Icons.record_voice_over_outlined, Colors.orange,
          '/teacher/class/$teacherId/$classId/participation'),
      _Section('Quizzes', Icons.quiz_outlined, Colors.purple,
          '/teacher/class/$teacherId/$classId/quizzes'),
      _Section('Portfolio', Icons.photo_library_outlined, Colors.teal,
          '/teacher/class/$teacherId/$classId/portfolio'),
      _Section('Random Pick', Icons.casino_outlined, Colors.red,
          '/teacher/class/$teacherId/$classId/random'),
      _Section('Export PDF', Icons.picture_as_pdf_outlined, Colors.brown,
          '/teacher/class/$teacherId/$classId/export'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(className),
        leading: BackButton(
            onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () => context.go('/teacher/home'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: sections.length,
          itemBuilder: (ctx, i) {
            final s = sections[i];
            return Card(
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push(s.route, extra: className),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(s.icon, size: 48, color: s.color),
                      const SizedBox(height: 12),
                      Text(
                        s.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Section {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _Section(this.label, this.icon, this.color, this.route);
}

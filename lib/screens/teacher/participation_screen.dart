import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/participation_model.dart';
import '../../models/student_model.dart';
import '../../widgets/student_avatar.dart';
class ParticipationScreen extends ConsumerWidget {
  final String teacherId;
  final String classId;
  final String className;

  const ParticipationScreen({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ClassParams(teacherId: teacherId, classId: classId);
    final studentsAsync = ref.watch(studentsProvider(params));
    final partAsync = ref.watch(participationProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text('$className – Participation'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () => context.go('/teacher/home'),
          ),
        ],
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (students) => partAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (entries) => _buildList(context, ref, students, entries),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<StudentModel> students,
    List<ParticipationEntry> entries,
  ) {
    final countMap = {
      for (var s in students)
        s.id: entries.where((e) => e.studentId == s.id).length
    };
    final maxCount = countMap.values.isEmpty
        ? 0
        : countMap.values.reduce((a, b) => a > b ? a : b);

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: students.length,
      itemBuilder: (_, i) {
        final s = students[i];
        final count = countMap[s.id] ?? 0;
        final pct = maxCount == 0 ? 0.0 : (count / maxCount) * 100;
        final studentEntries =
            entries.where((e) => e.studentId == s.id).toList()
              ..sort((a, b) => b.date.compareTo(a.date));

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            leading: StudentAvatar(
                photoUrl: s.photoUrl, name: s.fullName, radius: 18, tappable: true),
            title: Text(s.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Row(children: [
              Text('$count +'
                  '  •  '),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pct >= 70
                      ? Colors.green
                      : pct >= 40
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ]),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  tooltip: 'Give participation +',
                  onPressed: () => _addParticipation(ref, s.id),
                ),
                const Icon(Icons.expand_more),
              ],
            ),
            children: studentEntries.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No participation recorded',
                          style: TextStyle(color: Colors.grey)),
                    )
                  ]
                : studentEntries
                    .map((entry) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.add, color: Colors.green),
                          title: Text(
                              DateFormat('dd MMM yyyy – HH:mm')
                                  .format(entry.date),
                              style: const TextStyle(fontSize: 13)),
                          subtitle: entry.note.isNotEmpty
                              ? Text(entry.note,
                                  style: const TextStyle(fontSize: 12))
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 18),
                            onPressed: () => _deleteEntry(ref, entry.id),
                          ),
                        ))
                    .toList(),
          ),
        );
      },
    );
  }

  Future<void> _addParticipation(WidgetRef ref, String studentId) async {
    final fs = ref.read(firestoreServiceProvider);
    await fs.addParticipation(ParticipationEntry(
      id: fs.generateId(),
      studentId: studentId,
      classId: classId,
      teacherId: teacherId,
      note: '',
      date: DateTime.now(),
    ));
  }

  Future<void> _deleteEntry(WidgetRef ref, String entryId) async {
    await ref
        .read(firestoreServiceProvider)
        .deleteParticipation(teacherId, classId, entryId);
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';

class StudentParticipationView extends ConsumerWidget {
  final String teacherId;
  final String classId;
  final String studentId;

  const StudentParticipationView({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ClassParams(teacherId: teacherId, classId: classId);
    final studentsAsync = ref.watch(studentsProvider(params));
    final partAsync = ref.watch(participationProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Participation'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: partAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allEntries) => studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (students) {
            final myEntries = allEntries
                .where((e) => e.studentId == studentId)
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            // Calculate percentage based on class max
            final countMap = {
              for (var s in students)
                s.id:
                    allEntries.where((e) => e.studentId == s.id).length
            };
            final maxCount = countMap.values.isEmpty
                ? 0
                : countMap.values.reduce((a, b) => a > b ? a : b);
            final myCount = myEntries.length;
            final pct = maxCount == 0
                ? 0.0
                : (myCount / maxCount) * 100;

            return Column(
              children: [
                // Summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Text('Participation Score',
                          style: TextStyle(fontSize: 16)),
                      Text('$myCount participations'),
                      Text('Class max: $maxCount',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),

                // Entry list
                Expanded(
                  child: myEntries.isEmpty
                      ? const Center(
                          child: Text('No participation recorded yet',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: myEntries.length,
                          itemBuilder: (_, i) {
                            final e = myEntries[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.orange,
                                child: Icon(Icons.add,
                                    color: Colors.white, size: 18),
                              ),
                              title: Text(DateFormat('dd MMMM yyyy – HH:mm')
                                  .format(e.date)),
                              subtitle: e.note.isNotEmpty
                                  ? Text(e.note)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

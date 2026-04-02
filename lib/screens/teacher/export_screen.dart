import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/pdf_export_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String classId;
  final String className;

  const ExportScreen({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.className,
  });

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String? _loadingKey;
  bool _fontsReady = false;

  @override
  void initState() {
    super.initState();
    // Pre-load Google Fonts in the background.
    // On success: fonts are cached → first export won't be blank.
    // On error/timeout: we still unlock buttons (user may retry if export fails).
    PdfExportService.warmUp()
        .timeout(const Duration(seconds: 8))
        .catchError((_) {})
        .whenComplete(() {
      if (mounted) setState(() => _fontsReady = true);
    });
  }

  Future<void> _run(String key, Future<void> Function() task) async {
    setState(() => _loadingKey = key);
    try {
      await task();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('PDF ready'),
            ]),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingKey = null);
    }
  }

  ClassParams get _params =>
      ClassParams(teacherId: widget.teacherId, classId: widget.classId);

  Future<void> _exportHomework() => _run('hw', () async {
        final students    = ref.read(studentsProvider(_params)).value ?? [];
        final assignments = ref.read(homeworkAssignmentsProvider(_params)).value ?? [];
        final grades      = ref.read(homeworkGradesProvider(_params)).value ?? [];
        await ref.read(pdfExportServiceProvider).exportHomework(
          className: widget.className,
          students: students,
          assignments: assignments,
          grades: grades,
        );
      });

  Future<void> _exportParticipation() => _run('part', () async {
        final students = ref.read(studentsProvider(_params)).value ?? [];
        final entries  = ref.read(participationProvider(_params)).value ?? [];
        await ref.read(pdfExportServiceProvider).exportParticipation(
          className: widget.className,
          students: students,
          entries: entries,
        );
      });

  Future<void> _exportQuizzes() => _run('quiz', () async {
        final students = ref.read(studentsProvider(_params)).value ?? [];
        final quizzes  = ref.read(quizzesProvider(_params)).value ?? [];
        final scores   = ref.read(quizScoresProvider(_params)).value ?? [];
        await ref.read(pdfExportServiceProvider).exportQuizzes(
          className: widget.className,
          students: students,
          quizzes: quizzes,
          scores: scores,
        );
      });

  Future<void> _exportAll() => _run('all', () async {
        final students      = ref.read(studentsProvider(_params)).value ?? [];
        final assignments   = ref.read(homeworkAssignmentsProvider(_params)).value ?? [];
        final hwGrades      = ref.read(homeworkGradesProvider(_params)).value ?? [];
        final participation = ref.read(participationProvider(_params)).value ?? [];
        final quizzes       = ref.read(quizzesProvider(_params)).value ?? [];
        final quizScores    = ref.read(quizScoresProvider(_params)).value ?? [];
        await ref.read(pdfExportServiceProvider).exportAllScales(
          className: widget.className,
          students: students,
          assignments: assignments,
          hwGrades: hwGrades,
          participation: participation,
          quizzes: quizzes,
          quizScores: quizScores,
        );
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} – Download Report'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/teacher/home'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reports are generated as PDF. '
                    'On Android the share sheet opens; '
                    'on Windows you are prompted to choose a save location.',
                    style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _ExportCard(
            cardKey: 'hw',
            icon: Icons.assignment_outlined,
            title: 'Homework Tracker',
            subtitle: 'All assignments, grades and completion percentages',
            color: Colors.blue,
            isLoading: _loadingKey == 'hw' || !_fontsReady,
            onTap: _loadingKey == null && _fontsReady ? _exportHomework : null,
          ),
          const SizedBox(height: 12),
          _ExportCard(
            cardKey: 'part',
            icon: Icons.star_outline,
            title: 'Participation Tracker',
            subtitle: 'Student participation count and percentage',
            color: Colors.amber,
            isLoading: _loadingKey == 'part' || !_fontsReady,
            onTap: _loadingKey == null && _fontsReady ? _exportParticipation : null,
          ),
          const SizedBox(height: 12),
          _ExportCard(
            cardKey: 'quiz',
            icon: Icons.quiz_outlined,
            title: 'Quiz / Exam Results',
            subtitle: 'All quiz scores and averages',
            color: Colors.purple,
            isLoading: _loadingKey == 'quiz' || !_fontsReady,
            onTap: _loadingKey == null && _fontsReady ? _exportQuizzes : null,
          ),
          const SizedBox(height: 12),
          _ExportCard(
            cardKey: 'all',
            icon: Icons.layers_outlined,
            title: 'All Scales (Combined)',
            subtitle: 'Homework + Participation + Quiz in one PDF',
            color: Colors.teal,
            isLoading: _loadingKey == 'all' || !_fontsReady,
            onTap: _loadingKey == null && _fontsReady ? _exportAll : null,
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final String cardKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ExportCard({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? color.withValues(alpha: 0.15)
        : color.withValues(alpha: 0.08);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trailing: spinner or download icon
              SizedBox(
                width: 28,
                height: 28,
                child: isLoading
                    ? CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(color),
                      )
                    : Icon(Icons.download_outlined, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

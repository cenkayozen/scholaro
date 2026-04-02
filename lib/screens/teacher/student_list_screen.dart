import 'package:cross_file/cross_file.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/providers.dart';
import '../../models/student_model.dart';
import '../../models/homework_assignment_model.dart';
import '../../services/pdf_import_service.dart';
import '../../utils/username_generator.dart';
import '../../widgets/student_avatar.dart';
class StudentListScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String classId;
  final String className;

  const StudentListScreen({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.className,
  });

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  bool _importing = false;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected(List<StudentModel> allStudents) async {
    final toDelete =
        allStudents.where((s) => _selectedIds.contains(s.id)).toList();
    if (toDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Delete Students'),
        ]),
        content: Text(
            '${toDelete.length} students will be deleted.\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final fs = ref.read(firestoreServiceProvider);
    for (final s in toDelete) {
      await fs.deleteStudent(s);
    }

    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });

    final params =
        ClassParams(teacherId: widget.teacherId, classId: widget.classId);
    ref.invalidate(studentsFutureProvider(params));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${toDelete.length} students deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final params =
        ClassParams(teacherId: widget.teacherId, classId: widget.classId);
    final studentsAsync = ref.watch(studentsFutureProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} students selected')
            : Text('${widget.className} – Students'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: _toggleSelectionMode,
              )
            : BackButton(onPressed: () => context.pop()),
        actions: [
          if (_selectionMode) ...[
            if (_selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete selected',
                onPressed: () {
                  final students = studentsAsync.value ?? [];
                  _deleteSelected(students);
                },
              ),
            // Select all
            studentsAsync.when(
              data: (students) => IconButton(
                icon: Icon(
                  _selectedIds.length == students.length
                      ? Icons.deselect
                      : Icons.select_all,
                ),
                tooltip: _selectedIds.length == students.length
                    ? 'Deselect all'
                    : 'Select all',
                onPressed: () {
                  setState(() {
                    if (_selectedIds.length == students.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(students.map((s) => s.id));
                    }
                  });
                },
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ] else if (_importing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                final params = ClassParams(
                    teacherId: widget.teacherId, classId: widget.classId);
                ref.invalidate(studentsFutureProvider(params));
              },
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import from PDF',
              onPressed: _importFromPdf,
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Add manually',
              onPressed: () => _showAddStudentDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.checklist_outlined),
              tooltip: 'Multi-select / delete',
              onPressed: _toggleSelectionMode,
            ),
            IconButton(
              icon: const Icon(Icons.sort_outlined),
              tooltip: 'Reorder students',
              onPressed: () {
                final students = ref
                    .read(studentsFutureProvider(ClassParams(
                        teacherId: widget.teacherId, classId: widget.classId)))
                    .value;
                if (students != null) _manageStudents(context, ref, students);
              },
            ),
          ],
          if (!_selectionMode)
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
        data: (students) => students.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No students yet.\nUpload a PDF or add students manually.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: students.length,
                itemBuilder: (_, i) => _StudentTile(
                  student: students[i],
                  teacherId: widget.teacherId,
                  classId: widget.classId,
                  selectionMode: _selectionMode,
                  selected: _selectedIds.contains(students[i].id),
                  onToggleSelect: () => _toggleSelect(students[i].id),
                ),
              ),
      ),
    );
  }

  Future<void> _importFromPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // always read bytes; avoids dart:io on web
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    setState(() => _importing = true);
    try {
      final service = ref.read(pdfImportServiceProvider);
      var parsed = await service.importStudentsFromBytes(bytes);

      if (!mounted) return;

      if (parsed.isEmpty) {
        // Fall back to manual raw-text editor
        final rawText = await service.extractRawTextFromBytes(bytes);
        if (!mounted) return;
        final manualText = await showDialog<String>(
          context: context,
          builder: (ctx) => _RawTextEditorDialog(rawText: rawText),
        );
        if (manualText == null || manualText.trim().isEmpty) return;
        parsed = service.parseText(manualText);
      }

      if (parsed.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not detect student records. '
              'Make sure each line has a school number and full name.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // How many students have photos extracted
      final photoCount = parsed.where((s) => s.photo != null).length;
      debugPrint('PDF import: ${parsed.length} students, $photoCount with photos');

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _ImportPreviewDialog(results: parsed),
      );
      if (confirmed != true) return;

      final fs = ref.read(firestoreServiceProvider);
      int saved = 0;

      final storage = ref.read(storageServiceProvider);

      for (final p in parsed) {
        try {
          final id = fs.generateId();
          final username = UsernameGenerator.generateUsername(p.fullName);
          final password = UsernameGenerator.generatePassword();
          final email = '$id@student.gradeapp.internal';

          // Upload photo extracted from PDF (if any)
          String photoUrl = '';
          if (p.photo != null && p.photo!.isNotEmpty) {
            try {
              photoUrl = await storage.uploadStudentPhotoBytes(
                teacherId: widget.teacherId,
                classId: widget.classId,
                studentId: id,
                bytes: p.photo!,
              );
            } catch (e) {
              debugPrint('Photo upload failed for ${p.fullName}: $e');
            }
          }

          final student = StudentModel(
            id: id,
            fullName: p.fullName,
            schoolNumber: p.schoolNumber,
            photoUrl: photoUrl,
            username: username,
            password: password,
            firebaseEmail: email,
            classId: widget.classId,
            teacherId: widget.teacherId,
            createdAt: DateTime.now(),
          );

          // Save student document
          await fs.firestoreInstance
              .collection('teachers')
              .doc(widget.teacherId)
              .collection('classes')
              .doc(widget.classId)
              .collection('students')
              .doc(id)
              .set(student.toMap());

          // Save student account lookup
          await fs.firestoreInstance
              .collection('studentAccounts')
              .doc(username)
              .set({
            'username': username,
            'password': password,
            'firebaseEmail': email,
            'studentId': id,
            'classId': widget.classId,
            'teacherId': widget.teacherId,
          });

          saved++;
        } catch (e) {
          debugPrint('Failed to save ${p.fullName}: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Error saving ${p.fullName}: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 6)));
          }
        }
      }

      // Update studentCount on the class document
      await fs.firestoreInstance
          .collection('teachers')
          .doc(widget.teacherId)
          .collection('classes')
          .doc(widget.classId)
          .update({'studentCount': saved});

      if (mounted) {
        // Force refresh after import
        final params = ClassParams(
            teacherId: widget.teacherId, classId: widget.classId);
        ref.invalidate(studentsFutureProvider(params));

        final uploadedPhotos =
            parsed.where((s) => s.photo != null).length;
        final msg = uploadedPhotos > 0
            ? '$saved students imported · $uploadedPhotos photos uploaded'
            : '$saved students imported (no photos found in PDF)';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _manageStudents(
    BuildContext context,
    WidgetRef ref,
    List<StudentModel> students,
  ) async {
    final local = List<StudentModel>.from(students);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    const Text('Reorder Students',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: local.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    setState(() {
                      final item = local.removeAt(oldIndex);
                      local.insert(newIndex, item);
                    });
                    await ref
                        .read(firestoreServiceProvider)
                        .reorderStudents(
                            widget.teacherId, widget.classId, local);
                    ref.invalidate(studentsFutureProvider(ClassParams(
                        teacherId: widget.teacherId,
                        classId: widget.classId)));
                  },
                  itemBuilder: (_, i) {
                    final s = local[i];
                    return ListTile(
                      key: ValueKey(s.id),
                      leading: StudentAvatar(
                          photoUrl: s.photoUrl,
                          name: s.fullName,
                          radius: 18,
                          tappable: true),
                      title: Text(s.fullName),
                      subtitle: Text('No: ${s.schoolNumber}'),
                      trailing:
                          const Icon(Icons.drag_handle, color: Colors.grey),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddStudentDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final noCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noCtrl,
              decoration: const InputDecoration(
                labelText: 'School Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (confirmed != true ||
        nameCtrl.text.trim().isEmpty ||
        noCtrl.text.trim().isEmpty) return;

    final fs = ref.read(firestoreServiceProvider);
    final id = fs.generateId();
    final username = UsernameGenerator.generateUsername(nameCtrl.text.trim());
    final password = UsernameGenerator.generatePassword();
    final email = '$id@student.gradeapp.internal';

    await fs.saveStudent(StudentModel(
      id: id,
      fullName: nameCtrl.text.trim(),
      schoolNumber: noCtrl.text.trim(),
      photoUrl: '',
      username: username,
      password: password,
      firebaseEmail: email,
      classId: widget.classId,
      teacherId: widget.teacherId,
      createdAt: DateTime.now(),
    ));
  }
}

class _StudentTile extends ConsumerWidget {
  final StudentModel student;
  final String teacherId;
  final String classId;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelect;

  const _StudentTile({
    required this.student,
    required this.teacherId,
    required this.classId,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
          : null,
      child: ListTile(
        onTap: selectionMode ? onToggleSelect : null,
        leading: selectionMode
            ? Checkbox(
                value: selected,
                onChanged: (_) => onToggleSelect?.call(),
                activeColor: const Color(0xFF1565C0),
              )
            : StudentAvatar(
                photoUrl: student.photoUrl,
                name: student.fullName,
                tappable: true),
        title: Text(student.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No: ${student.schoolNumber}  •  User: ${student.username}'),
            if (student.isHomeworkMonitor)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('HW Monitor',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        trailing: selectionMode
            ? null
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'monitor':
                      _manageMonitorRole(context, ref);
                      break;
                    case 'photo':
                      _updatePhoto(context, ref);
                      break;
                    case 'credentials':
                      _showCredentials(context, ref);
                      break;
                    case 'delete':
                      _deleteStudent(context, ref);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'monitor',
                    child: Row(children: [
                      Icon(Icons.rate_review_outlined,
                          size: 18,
                          color: student.isHomeworkMonitor
                              ? const Color(0xFF1565C0)
                              : null),
                      const SizedBox(width: 10),
                      Text(student.isHomeworkMonitor
                          ? 'Monitor Role (On)'
                          : 'Monitor Role'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'photo',
                    child: Row(children: [
                      Icon(Icons.photo_camera, size: 18),
                      SizedBox(width: 10),
                      Text('Update Photo'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'credentials',
                    child: Row(children: [
                      Icon(Icons.key, size: 18),
                      SizedBox(width: 10),
                      Text('Login Credentials'),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Sil', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _updatePhoto(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Photo Source'),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              child: const Text('Take Photo')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              child: const Text('Choose from Gallery')),
        ],
      ),
    );
    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;

    final storage = ref.read(storageServiceProvider);
    final url = await storage.uploadStudentPhoto(
      teacherId: teacherId,
      classId: classId,
      studentId: student.id,
      file: XFile(picked.path),
    );
    await ref.read(firestoreServiceProvider).updateStudentPhoto(student, url);
  }

  Future<void> _deleteStudent(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Student'),
          ],
        ),
        content: Text(
          '${student.fullName} will be deleted.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(firestoreServiceProvider).deleteStudent(student);
    ref.invalidate(studentsFutureProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.fullName} deleted.')),
      );
    }
  }

  Future<void> _manageMonitorRole(BuildContext context, WidgetRef ref) async {
    // Fetch current assignments for this class
    final params = ClassParams(teacherId: teacherId, classId: classId);
    final assignments =
        await ref.read(firestoreServiceProvider).fetchHomeworkAssignments(teacherId, classId);

    if (!context.mounted) return;

    bool isMonitor = student.isHomeworkMonitor;
    final selected = Set<String>.from(student.monitorAssignmentIds);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.rate_review_outlined,
                  color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('${student.fullName} – Monitor Role')),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    value: isMonitor,
                    onChanged: (v) => setState(() => isMonitor = v),
                    title: const Text('Homework Monitor'),
                    subtitle: const Text(
                        'Allows this student to grade assignments'),
                    activeColor: const Color(0xFF1565C0),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isMonitor) ...[
                    const Divider(),
                    const Text('Assigned Homework',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text(
                        'Select which assignments this monitor can grade:',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    if (assignments.isEmpty)
                      const Text('No assignments yet.',
                          style: TextStyle(color: Colors.grey))
                    else
                      ...assignments.map((a) => CheckboxListTile(
                            value: selected.contains(a.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                selected.add(a.id);
                              } else {
                                selected.remove(a.id);
                              }
                            }),
                            title: Text(a.title,
                                style: const TextStyle(fontSize: 13)),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: const Color(0xFF1565C0),
                          )),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await ref.read(firestoreServiceProvider).setStudentMonitorRole(
          teacherId,
          classId,
          student.id,
          isMonitor: isMonitor,
          assignmentIds: isMonitor ? selected.toList() : [],
        );

    // Refresh students list
    ref.invalidate(studentsFutureProvider(params));
  }

  Future<void> _showCredentials(BuildContext context, WidgetRef ref) async {
    final userCtrl = TextEditingController(text: student.username);
    final passCtrl = TextEditingController(text: student.password);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${student.fullName} – Login Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share these credentials with the student.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(firestoreServiceProvider)
                  .updateStudentCredentials(
                    student: student,
                    oldUsername: student.username,
                    newUsername: userCtrl.text.trim(),
                    newPassword: passCtrl.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ── Raw Text Editor (shown when auto-parse fails) ─────────────────────────────

class _RawTextEditorDialog extends StatefulWidget {
  final String rawText;
  const _RawTextEditorDialog({required this.rawText});

  @override
  State<_RawTextEditorDialog> createState() => _RawTextEditorDialogState();
}

class _RawTextEditorDialogState extends State<_RawTextEditorDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.rawText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit PDF Text'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The PDF was read but no students were detected automatically.\n'
              'Edit the text below so each line follows this format:\n\n'
              '  12345  Ad Soyad\n'
              '  12346  Ad Soyad\n\n'
              'Then press "Parse & Import".',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '12345  Ali Veli\n12346  Fatma Demir',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Parse & Import'),
        ),
      ],
    );
  }
}

// ── Import Preview ─────────────────────────────────────────────────────────────

class _ImportPreviewDialog extends StatelessWidget {
  final List<PdfImportResult> results;
  const _ImportPreviewDialog({required this.results});

  @override
  Widget build(BuildContext context) {
    final photoCount = results.where((s) => s.photo != null).length;
    return AlertDialog(
      title: Text('${results.length} students found'),
      content: SizedBox(
        width: 400,
        height: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo extraction status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: photoCount > 0
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    photoCount > 0
                        ? Icons.photo_camera
                        : Icons.photo_camera_outlined,
                    size: 18,
                    color: photoCount > 0
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    photoCount > 0
                        ? '$photoCount photos extracted from PDF'
                        : 'No photos found in PDF',
                    style: TextStyle(
                      fontSize: 13,
                      color: photoCount > 0
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  leading: results[i].photo != null
                      ? ClipOval(
                          child: Image.memory(
                            results[i].photo!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => CircleAvatar(
                              radius: 16,
                              child: Text('${i + 1}',
                                  style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 16,
                          child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 11)),
                        ),
                  title: Text(results[i].fullName),
                  subtitle: Text('No: ${results[i].schoolNumber}'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import All')),
      ],
    );
  }
}

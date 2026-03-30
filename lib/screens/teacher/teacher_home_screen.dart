import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../providers/providers.dart';
import '../../models/class_model.dart';
import '../../widgets/scholaro_logo.dart';

// ── Class colour palette ──────────────────────────────────────────────────────
// 10 distinct Material colours; index = class position in the list.
const _kClassPalette = [
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.red,
  Colors.cyan,
  Colors.pink,
  Colors.teal,
  Colors.indigo,
  Colors.amber,
];

/// Returns background + foreground colours for a class at [index].
({Color bg, Color fg}) classColorAt(int index, bool isDark) {
  final mc = _kClassPalette[index % _kClassPalette.length];
  return isDark
      ? (bg: mc.shade800, fg: mc.shade100)
      : (bg: mc.shade100, fg: mc.shade800);
}

class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  static const _dayKeys = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday'
  ];
  static const _periods = [1, 2, 3, 4, 5, 6, 7, 8];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => context.go('/'));
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final teacherId = user.uid;
        final scheduleAsync = ref.watch(scheduleProvider(teacherId));
        final classesAsync = ref.watch(classesProvider(teacherId));

        final sidebar = _SideBar(
          teacherId: teacherId,
          userEmail: user.email ?? user.displayName ?? '',
          classesAsync: classesAsync,
        );

        final scheduleContent = classesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (classes) => scheduleAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (schedule) =>
                _buildSchedule(context, ref, teacherId, classes, schedule),
          ),
        );

        final isWide = MediaQuery.of(context).size.width >= 600;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final exit = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Çıkış'),
                content: const Text(
                    'Uygulamadan çıkmak istediğinizden emin misiniz?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Hayır'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Evet'),
                  ),
                ],
              ),
            );
            if (exit == true) SystemNavigator.pop();
          },
          child: isWide
              // ── Wide screen: permanent sidebar ──────────────────────────
              ? Scaffold(
                  body: SafeArea(
                    child: Row(
                      children: [
                        sidebar,
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(child: scheduleContent),
                      ],
                    ),
                  ),
                )
              // ── Narrow screen (phone): drawer ────────────────────────────
              : Scaffold(
                  appBar: AppBar(
                    title: const ScholaroLogo(iconSize: 32, horizontal: true),
                  ),
                  drawer: Drawer(child: sidebar),
                  body: scheduleContent,
                ),
        );
      },
    );
  }

  Widget _buildSchedule(
    BuildContext context,
    WidgetRef ref,
    String teacherId,
    List classes,
    Map<String, String> schedule,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Weekly Schedule',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: _ScheduleTable(
              teacherId: teacherId,
              classes: classes,
              schedule: schedule,
              days: _days,
              dayKeys: _dayKeys,
              periods: _periods,
              onUpdate: (key, classId) => ref
                  .read(firestoreServiceProvider)
                  .updateScheduleEntry(teacherId, key, classId),
              onTapClass: (cls) => context.push(
                '/teacher/class/${cls.teacherId}/${cls.id}/detail',
                extra: cls.name,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permanent sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _SideBar extends ConsumerStatefulWidget {
  final String teacherId;
  final String userEmail;
  final AsyncValue<List> classesAsync;

  const _SideBar({
    required this.teacherId,
    required this.userEmail,
    required this.classesAsync,
  });

  @override
  ConsumerState<_SideBar> createState() => _SideBarState();
}

class _SideBarState extends ConsumerState<_SideBar> {
  bool _classesExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 230,
      child: Container(
        color: colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ScholaroLogo(
                    iconSize: 36,
                    horizontal: true,
                    light: true,
                  ),
                  if (widget.userEmail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 2),
                      child: Text(
                        widget.userEmail,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            // ── Classes section header ───────────────────────────────────
            InkWell(
              onTap: () =>
                  setState(() => _classesExpanded = !_classesExpanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.school_outlined,
                        size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CLASSES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Icon(
                      _classesExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            // ── Classes list (expanded) ──────────────────────────────────
            if (_classesExpanded)
              Expanded(
                child: Column(
                  children: [
                    // New Class button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Class'),
                          onPressed: () => _createClass(context),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    // Class list
                    Expanded(
                      child: widget.classesAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) => const SizedBox(),
                        data: (classes) => classes.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No classes yet.\nCreate your first class!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                itemCount: classes.length,
                                itemBuilder: (ctx, i) {
                                  final cls = classes[i];
                                  final isDark =
                                      Theme.of(context).brightness ==
                                          Brightness.dark;
                                  final c = classColorAt(i, isDark);
                                  return _ClassTile(
                                    cls: cls,
                                    onDelete: () =>
                                        _deleteClass(context, cls),
                                    accentBg: c.bg,
                                    accentFg: c.fg,
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!_classesExpanded) const Spacer(),

            const Divider(height: 1),

            // ── Reports ──────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Reports'),
              onTap: () => _showReports(context),
            ),

            // ── Theme Toggle ─────────────────────────────────────────────
            Consumer(builder: (context, ref, _) {
              final themeMode = ref.watch(themeModeProvider);
              final isDark = themeMode == ThemeMode.dark;
              return SwitchListTile(
                secondary: Icon(
                  isDark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
                title: Text(isDark ? 'Dark Mode' : 'Light Mode'),
                value: isDark,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggle(),
              );
            }),

            // ── Logout ───────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
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

  Future<void> _createClass(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Class'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Class name (e.g. 10-A, Grade 5)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    final fs = ref.read(firestoreServiceProvider);
    await fs.createClass(ClassModel(
      id: const Uuid().v4(),
      name: ctrl.text.trim(),
      teacherId: widget.teacherId,
      studentCount: 0,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _deleteClass(BuildContext context, ClassModel cls) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
            'Delete "${cls.name}"? All student data will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(firestoreServiceProvider)
        .deleteClass(widget.teacherId, cls.id);
  }

  void _showReports(BuildContext context) {
    final classes = widget.classesAsync.value ?? [];
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
                    context.push(
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

// ─────────────────────────────────────────────────────────────────────────────
// Class tile in sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _ClassTile extends StatelessWidget {
  final dynamic cls;
  final VoidCallback onDelete;
  final Color? accentBg;
  final Color? accentFg;

  const _ClassTile({
    required this.cls,
    required this.onDelete,
    this.accentBg,
    this.accentFg,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarBg = accentBg ?? colorScheme.primaryContainer;
    final avatarFg = accentFg ?? colorScheme.onPrimaryContainer;
    return ListTile(
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: avatarBg,
        child: Text(
          (cls.name as String).isNotEmpty
              ? (cls.name as String)[0].toUpperCase()
              : '?',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: avatarFg),
        ),
      ),
      title: Text(cls.name as String,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text('${cls.studentCount} students',
          style: const TextStyle(fontSize: 11)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
        onPressed: onDelete,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: 'Delete class',
      ),
      onTap: () => context.push(
        '/teacher/class/${cls.teacherId}/${cls.id}/detail',
        extra: cls.name as String,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule table (unchanged from before)
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleTable extends StatelessWidget {
  final String teacherId;
  final List classes;
  final Map<String, String> schedule;
  final List<String> days;
  final List<String> dayKeys;
  final List<int> periods;
  final void Function(String key, String classId) onUpdate;
  final void Function(dynamic cls) onTapClass;

  const _ScheduleTable({
    required this.teacherId,
    required this.classes,
    required this.schedule,
    required this.days,
    required this.dayKeys,
    required this.periods,
    required this.onUpdate,
    required this.onTapClass,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.primaryContainer;
    final isDark = theme.brightness == Brightness.dark;

    // Build classId → colour mapping (index = order in classes list)
    final classColors = <String, ({Color bg, Color fg})>{};
    for (var i = 0; i < classes.length; i++) {
      classColors[classes[i].id as String] = classColorAt(i, isDark);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const periodWidth = 36.0;
        final cellWidth = (totalWidth - periodWidth) / days.length;

        return Table(
          defaultColumnWidth: FixedColumnWidth(cellWidth),
          columnWidths: {0: const FixedColumnWidth(periodWidth)},
          border: TableBorder.all(
            color: theme.colorScheme.outlineVariant,
            width: 1,
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            // Header row
            TableRow(
              decoration: BoxDecoration(color: headerColor),
              children: [
                _headerCell('#'),
                ...days.map((d) => _headerCell(d)),
              ],
            ),
            // Data rows
            ...periods.map((period) {
              return TableRow(
                children: [
                  Container(
                    height: 48,
                    alignment: Alignment.center,
                    color: headerColor.withValues(alpha: 0.5),
                    child: Text(
                      '$period',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  ...dayKeys.map((dayKey) {
                    final key = '${dayKey}_$period';
                    final classId = schedule[key] ?? '';
                    dynamic assignedClass;
                    try {
                      assignedClass =
                          classes.firstWhere((c) => c.id == classId);
                    } catch (_) {
                      assignedClass = null;
                    }
                    final colors = assignedClass != null
                        ? classColors[assignedClass.id as String]
                        : null;
                    return _ScheduleCell(
                      assignedClass: assignedClass,
                      classes: classes,
                      onSelect: (selectedClassId) =>
                          onUpdate(key, selectedClassId),
                      onTap: assignedClass != null
                          ? () => onTapClass(assignedClass)
                          : null,
                      cellBg: colors?.bg,
                      cellFg: colors?.fg,
                    );
                  }),
                ],
              );
            }),
          ],
        );
      },
    );
  }

  Widget _headerCell(String text) {
    return Container(
      height: 36,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  final dynamic assignedClass;
  final List classes;
  final void Function(String classId) onSelect;
  final VoidCallback? onTap;
  final Color? cellBg;
  final Color? cellFg;

  const _ScheduleCell({
    required this.assignedClass,
    required this.classes,
    required this.onSelect,
    this.onTap,
    this.cellBg,
    this.cellFg,
  });

  @override
  Widget build(BuildContext context) {
    final hasClass = assignedClass != null;
    final bg = hasClass
        ? (cellBg ?? Theme.of(context).colorScheme.primaryContainer)
        : Colors.transparent;

    return GestureDetector(
      // Boş hücre → doğrudan picker aç
      // Dolu hücre → seçenekler dialog (sınıfa git / değiştir)
      onTap: () => hasClass ? _showOptions(context) : _showPicker(context),
      onLongPress: () => _showPicker(context),
      child: Container(
        height: 48,
        color: bg,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: hasClass
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    assignedClass.name as String,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cellFg,
                    ),
                  ),
                ],
              )
            : Text(
                '—',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                ),
              ),
      ),
    );
  }

  // Dolu hücre için: sınıfa git ya da değiştir
  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                assignedClass.name as String,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Go to class'),
              onTap: () {
                Navigator.pop(ctx);
                if (onTap != null) onTap!();
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.indigo),
              title: const Text('Change / Remove'),
              onTap: () {
                Navigator.pop(ctx);
                _showPicker(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
        0,
        0,
      ),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        PopupMenuItem<String>(
          value: '',
          child: Row(children: [
            const Icon(Icons.remove_circle_outline,
                size: 18, color: Colors.grey),
            const SizedBox(width: 10),
            Text('Empty',
                style: TextStyle(color: Colors.grey.shade600)),
          ]),
        ),
        const PopupMenuDivider(),
        ...classes.map((cls) => PopupMenuItem<String>(
              value: cls.id as String,
              child: Row(children: [
                CircleAvatar(
                  radius: 12,
                  child: Text(
                    (cls.name as String).isNotEmpty
                        ? (cls.name as String)[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(width: 10),
                Text(cls.name as String),
              ]),
            )),
      ],
    ).then((selected) {
      if (selected != null) onSelect(selected);
    });
  }
}

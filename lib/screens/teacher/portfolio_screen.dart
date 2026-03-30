import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/providers.dart';
import '../../models/student_model.dart';
import '../../models/portfolio_item_model.dart';
import '../../widgets/student_avatar.dart';
import '../../utils/portfolio_download_helper.dart';

class PortfolioScreen extends ConsumerWidget {
  final String teacherId;
  final String classId;
  final String className;

  const PortfolioScreen({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ClassParams(teacherId: teacherId, classId: classId);
    final studentsAsync = ref.watch(studentsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text('$className – Portfolio'),
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
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (students) => ListView.builder(
          itemCount: students.length,
          itemBuilder: (_, i) => _StudentPortfolioTile(
            student: students[i],
            teacherId: teacherId,
            classId: classId,
          ),
        ),
      ),
    );
  }
}

// ── Per-student tile (stateful for selection mode) ─────────────────────────
class _StudentPortfolioTile extends ConsumerStatefulWidget {
  final StudentModel student;
  final String teacherId;
  final String classId;

  const _StudentPortfolioTile({
    required this.student,
    required this.teacherId,
    required this.classId,
  });

  @override
  ConsumerState<_StudentPortfolioTile> createState() =>
      _StudentPortfolioTileState();
}

class _StudentPortfolioTileState
    extends ConsumerState<_StudentPortfolioTile> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() => setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(portfolioProvider(PortfolioParams(
      teacherId: widget.teacherId,
      classId: widget.classId,
      studentId: widget.student.id,
    )));

    final allItems = portfolioAsync.valueOrNull ?? [];
    final selectedItems =
        allItems.where((i) => _selectedIds.contains(i.id)).toList();
    final name =
        widget.student.fullName.replaceAll(' ', '_');

    return ExpansionTile(
      leading: StudentAvatar(
          photoUrl: widget.student.photoUrl,
          name: widget.student.fullName,
          radius: 18),
      title: Text(widget.student.fullName),
      subtitle: portfolioAsync.when(
        data: (it) => Text('${it.length} dosya'),
        loading: () => const Text('Yükleniyor...'),
        error: (_, __) => const Text('Hata'),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.photo_camera),
              tooltip: 'Fotoğraf çek',
              onPressed: () =>
                  _upload(context, ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Dosya yükle',
              onPressed: () => _uploadFile(context),
            ),
            if (allItems.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: 'Seç',
                onPressed: () =>
                    setState(() => _selectionMode = true),
              ),
            _buildDownloadMenu(context, allItems, name),
          ] else ...[
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == allItems.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(allItems.map((e) => e.id));
                  }
                });
              },
              child: Text(_selectedIds.length == allItems.length
                  ? 'Seçimi Kaldır'
                  : 'Tümünü Seç'),
            ),
            if (selectedItems.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'PDF indir',
                onPressed: () => PortfolioDownloadHelper.downloadAllAsPdf(
                    context, selectedItems,
                    pdfName: name),
              ),
              IconButton(
                icon: const Icon(Icons.folder_zip),
                tooltip: 'ZIP indir',
                onPressed: () => PortfolioDownloadHelper.downloadAllAsZip(
                    context, selectedItems,
                    zipName: name),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'İptal',
              onPressed: _exitSelection,
            ),
          ],
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        portfolioAsync.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator()),
          error: (e, _) => Text('Hata: $e'),
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Henüz portfolyo öğesi yok',
                      style: TextStyle(color: Colors.grey)),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _PortfolioItemCard(
                    item: items[i],
                    selectionMode: _selectionMode,
                    selected: _selectedIds.contains(items[i].id),
                    onToggle: () => _toggleSelection(items[i].id),
                    onDelete: () => _deleteItem(items[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDownloadMenu(BuildContext context,
      List<PortfolioItem> items, String name) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Tümünü indir',
      enabled: items.isNotEmpty,
      onSelected: (value) {
        if (value == 'pdf') {
          PortfolioDownloadHelper.downloadAllAsPdf(context, items,
              pdfName: name);
        } else {
          PortfolioDownloadHelper.downloadAllAsZip(context, items,
              zipName: name);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'pdf',
          child: Row(children: [
            Icon(Icons.picture_as_pdf),
            SizedBox(width: 8),
            Text('Tümünü PDF indir'),
          ]),
        ),
        PopupMenuItem(
          value: 'zip',
          child: Row(children: [
            Icon(Icons.folder_zip),
            SizedBox(width: 8),
            Text('Tümünü ZIP indir'),
          ]),
        ),
      ],
    );
  }

  Future<void> _upload(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    await _saveFile(
        File(picked.path), 'image', picked.path.split('/').last);
  }

  Future<void> _uploadFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    final ext = f.extension?.toLowerCase() ?? '';
    final fileType = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)
        ? 'image'
        : ext == 'pdf'
            ? 'pdf'
            : 'other';
    await _saveFile(File(f.path!), fileType, f.name);
  }

  Future<void> _saveFile(
      File file, String fileType, String fileName) async {
    final fs = ref.read(firestoreServiceProvider);
    final storage = ref.read(storageServiceProvider);
    final id = fs.generateId();
    final url = await storage.uploadPortfolioItem(
      teacherId: widget.teacherId,
      classId: widget.classId,
      studentId: widget.student.id,
      itemId: id,
      file: file,
    );
    await fs.addPortfolioItem(PortfolioItem(
      id: id,
      studentId: widget.student.id,
      classId: widget.classId,
      teacherId: widget.teacherId,
      fileUrl: url,
      fileType: fileType,
      fileName: fileName,
      uploadedAt: DateTime.now(),
    ));
  }

  Future<void> _deleteItem(PortfolioItem item) async {
    await ref.read(storageServiceProvider).deleteFile(item.fileUrl);
    await ref
        .read(firestoreServiceProvider)
        .deletePortfolioItem(widget.teacherId, widget.classId, item.id);
  }
}

// ── Single item card ───────────────────────────────────────────────────────
class _PortfolioItemCard extends StatelessWidget {
  final PortfolioItem item;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _PortfolioItemCard({
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selectionMode ? onToggle : () => _openItem(context),
      onLongPress: selectionMode
          ? null
          : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sil'),
                  content: Text('"${item.fileName}" silinsin mi?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('İptal')),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sil')),
                  ],
                ),
              );
              if (confirm == true) onDelete();
            },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.fileType == 'image'
                ? CachedNetworkImage(
                    imageUrl: item.fileUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.fileType == 'pdf'
                              ? Icons.picture_as_pdf
                              : Icons.insert_drive_file,
                          size: 32,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            item.fileName,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          // Selection overlay
          if (selectionMode)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: selected
                    ? Colors.blue.withOpacity(0.35)
                    : Colors.transparent,
                border: Border.all(
                  color:
                      selected ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          if (selectionMode)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? Colors.blue : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Icon(
                  selected ? Icons.check : null,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          // Download button (only when not in selection mode)
          if (!selectionMode)
            Positioned(
              bottom: 4,
              right: 4,
              child: _DownloadIconButton(item: item),
            ),
        ],
      ),
    );
  }

  void _openItem(BuildContext context) {
    if (item.fileType == 'image') {
      showDialog(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: item.fileUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator()),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: Row(
                  children: [
                    _DownloadIconButton(
                        item: item, iconColor: Colors.white),
                    IconButton(
                      icon:
                          const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      PortfolioDownloadHelper.download(context, item);
    }
  }
}

// ── Download icon button ───────────────────────────────────────────────────
class _DownloadIconButton extends StatefulWidget {
  final PortfolioItem item;
  final Color iconColor;

  const _DownloadIconButton({
    required this.item,
    this.iconColor = Colors.white,
  });

  @override
  State<_DownloadIconButton> createState() => _DownloadIconButtonState();
}

class _DownloadIconButtonState extends State<_DownloadIconButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: _loading
          ? const SizedBox(
              width: 32,
              height: 32,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          : IconButton(
              iconSize: 18,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: Icon(Icons.download, color: widget.iconColor),
              onPressed: () async {
                setState(() => _loading = true);
                await PortfolioDownloadHelper.download(
                    context, widget.item);
                if (mounted) setState(() => _loading = false);
              },
            ),
    );
  }
}

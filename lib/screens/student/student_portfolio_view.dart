import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/portfolio_item_model.dart';
import '../../utils/portfolio_download_helper.dart';

class StudentPortfolioView extends ConsumerStatefulWidget {
  final String teacherId;
  final String classId;
  final String studentId;

  const StudentPortfolioView({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.studentId,
  });

  @override
  ConsumerState<StudentPortfolioView> createState() =>
      _StudentPortfolioViewState();
}

class _StudentPortfolioViewState
    extends ConsumerState<StudentPortfolioView> {
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
      studentId: widget.studentId,
    )));

    final allItems = portfolioAsync.valueOrNull ?? [];
    final selectedItems =
        allItems.where((i) => _selectedIds.contains(i.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} seçildi')
            : const Text('My Portfolio'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              )
            : BackButton(onPressed: () => context.pop()),
        actions: [
          if (_selectionMode) ...[
            TextButton(
              onPressed: allItems.isEmpty
                  ? null
                  : () {
                      setState(() {
                        if (_selectedIds.length == allItems.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds
                              .addAll(allItems.map((e) => e.id));
                        }
                      });
                    },
              child: Text(
                  _selectedIds.length == allItems.length
                      ? 'Seçimi Kaldır'
                      : 'Tümünü Seç',
                  style: const TextStyle(color: Colors.white)),
            ),
            if (selectedItems.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'PDF indir',
                onPressed: () =>
                    PortfolioDownloadHelper.downloadAllAsPdf(
                        context, selectedItems,
                        pdfName: 'portfolio_secilen'),
              ),
              IconButton(
                icon: const Icon(Icons.folder_zip),
                tooltip: 'ZIP indir',
                onPressed: () =>
                    PortfolioDownloadHelper.downloadAllAsZip(
                        context, selectedItems,
                        zipName: 'portfolio_secilen'),
              ),
            ],
          ] else if (allItems.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Seç',
              onPressed: () =>
                  setState(() => _selectionMode = true),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              tooltip: 'Tümünü indir',
              onSelected: (value) {
                if (value == 'pdf') {
                  PortfolioDownloadHelper.downloadAllAsPdf(
                      context, allItems,
                      pdfName: 'portfolio');
                } else {
                  PortfolioDownloadHelper.downloadAllAsZip(
                      context, allItems,
                      zipName: 'portfolio');
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
            ),
          ],
        ],
      ),
      body: portfolioAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No portfolio items yet',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _PortfolioCard(
                  item: items[i],
                  selectionMode: _selectionMode,
                  selected: _selectedIds.contains(items[i].id),
                  onToggle: () => _toggleSelection(items[i].id),
                ),
              ),
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final PortfolioItem item;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggle;

  const _PortfolioCard({
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selectionMode ? onToggle : () => _openItem(context),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: item.fileType == 'image'
                      ? CachedNetworkImage(
                          imageUrl: item.fileUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 48),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: Icon(
                            item.fileType == 'pdf'
                                ? Icons.picture_as_pdf
                                : Icons.insert_drive_file,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fileName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(item.uploadedAt),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Selection overlay
            if (selectionMode)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: selected
                        ? Colors.blue.withOpacity(0.35)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? Colors.blue
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            if (selectionMode)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? Colors.blue : Colors.white,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Icon(
                    selected ? Icons.check : null,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            // Download button (only when not selecting)
            if (!selectionMode)
              Positioned(
                bottom: 36,
                right: 4,
                child: _DownloadIconButton(item: item),
              ),
          ],
        ),
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
                      icon: const Icon(Icons.close,
                          color: Colors.white),
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

class _DownloadIconButton extends StatefulWidget {
  final PortfolioItem item;
  final Color iconColor;

  const _DownloadIconButton({
    required this.item,
    this.iconColor = Colors.white,
  });

  @override
  State<_DownloadIconButton> createState() =>
      _DownloadIconButtonState();
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

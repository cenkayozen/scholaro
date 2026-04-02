import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/student_model.dart';
import '../../widgets/student_avatar.dart';

class RandomSelectorScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String classId;
  final String className;

  const RandomSelectorScreen({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.className,
  });

  @override
  ConsumerState<RandomSelectorScreen> createState() =>
      _RandomSelectorScreenState();
}

class _RandomSelectorScreenState extends ConsumerState<RandomSelectorScreen> {
  // State: which student IDs have been picked, and who was last selected
  final Set<String> _pickedIds = {};
  StudentModel? _selected;
  bool _spinning = false;
  FlutterTts? _tts;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final tts = FlutterTts();
    // Try Turkish first; fall back to English if not installed
    final langs = await tts.getLanguages as List?;
    final hasTurkish = langs?.any((l) =>
            l.toString().toLowerCase().contains('tr')) ??
        false;
    if (hasTurkish) {
      await tts.setLanguage('tr-TR');
    } else {
      await tts.setLanguage('en-US');
    }
    await tts.setVolume(1.0);
    await tts.setSpeechRate(0.45);
    await tts.setPitch(1.0);
    if (mounted) setState(() => _tts = tts);
  }

  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }

  // pool is purely computed — no mutation during build
  List<StudentModel> _pool(List<StudentModel> all) =>
      all.where((s) => !_pickedIds.contains(s.id)).toList();

  Future<void> _pick(List<StudentModel> all) async {
    final pool = _pool(all);
    if (pool.isEmpty) return;
    setState(() => _spinning = true);
    await Future.delayed(const Duration(milliseconds: 700));
    final picked = pool[Random().nextInt(pool.length)];
    setState(() {
      _selected = picked;
      _pickedIds.add(picked.id);
      _spinning = false;
    });
    if (_tts != null) {
      await _tts!.speak(picked.fullName);
    }
  }

  void _reset() {
    setState(() {
      _pickedIds.clear();
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = ClassParams(
        teacherId: widget.teacherId, classId: widget.classId);
    final studentsAsync = ref.watch(studentsFutureProvider(params));

    return ExcludeSemantics(
      child: Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} – Random Picker'),
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
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.red, fontSize: 16)),
        ),
        data: (all) {
          // pool is computed purely — no state mutation here
          final pool = _pool(all);
          final remaining = pool.length;
          final selected = all.length - remaining;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ── Stats ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('Remaining', '$remaining', Colors.blue),
                    _stat('Selected', '$selected', Colors.orange),
                    _stat('Total', '${all.length}', Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 24),

                // ── Display ──────────────────────────────────────────
                SizedBox(
                  height: 260,
                  child: Center(child: _buildDisplay()),
                ),

                const SizedBox(height: 24),

                // ── Buttons ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                    FilledButton.icon(
                      // Override the global theme that forces double.infinity width
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(140, 48),
                      ),
                      onPressed: pool.isEmpty || _spinning
                          ? null
                          : () => _pick(all),
                      icon: const Icon(Icons.shuffle),
                      label: Text(pool.isEmpty
                          ? 'All selected'
                          : 'Pick Random'),
                    ),
                  ],
                ),

                // ── Remaining chip list ──────────────────────────────
                if (pool.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Remaining ($remaining):',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: pool
                        .map((s) => Chip(
                              label: Text(s.fullName,
                                  style: const TextStyle(fontSize: 12)),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ));
  }

  Widget _buildDisplay() {
    if (_spinning) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(strokeWidth: 6)),
          SizedBox(height: 16),
          Text('Selecting...', style: TextStyle(fontSize: 18)),
        ],
      );
    }
    if (_selected == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shuffle, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Press the button to randomly\nselect a student',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudentAvatar(
            photoUrl: _selected!.photoUrl,
            name: _selected!.fullName,
            radius: 56),
        const SizedBox(height: 16),
        Text(_selected!.fullName,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('No: ${_selected!.schoolNumber}',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        if (_tts != null) ...[
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => _tts!.speak(_selected!.fullName),
          ),
        ],
      ],
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ],
      );
}

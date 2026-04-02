import 'package:flutter/material.dart';

// ½+ uses a lighter green so it's visually distinct from full +
const kMarkColors = {
  'plus':     Color(0xFF2E7D32), // dark green
  'halfPlus': Color(0xFF66BB6A), // medium green (lighter than plus)
  'minus':    Colors.red,
  'absent':   Colors.orange,
  'exempt':   Colors.blueGrey,
  '':         Colors.grey,
};

const kMarkLabels = {
  'plus':     '+',
  'halfPlus': '½+', // fallback string — UI uses custom painter
  'minus':    '−',
  'absent':   'A',
  'exempt':   'E',
  '':         '?',
};

const _kAllMarks = ['plus', 'halfPlus', 'minus', 'absent', 'exempt', ''];

// ── Half-plus custom symbol ─────────────────────────────────────────────────
// Draws "+" with the bottom vertical stroke removed.
class HalfPlusSymbol extends StatelessWidget {
  final double size;
  final Color color;

  const HalfPlusSymbol({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HalfPlusPainter(color),
    );
  }
}

class _HalfPlusPainter extends CustomPainter {
  final Color color;
  _HalfPlusPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.square;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Horizontal bar (full width)
    canvas.drawLine(
        Offset(size.width * 0.12, cy), Offset(size.width * 0.88, cy), paint);
    // Top half of vertical bar only (from top to center — bottom is cut)
    canvas.drawLine(Offset(cx, size.height * 0.12), Offset(cx, cy), paint);
  }

  @override
  bool shouldRepaint(_HalfPlusPainter old) => old.color != color;
}

// ── Mark content helper ─────────────────────────────────────────────────────
// Returns either a Text widget or the HalfPlusSymbol for halfPlus.
Widget markContent(String mark, {required double fontSize, required Color color}) {
  if (mark == 'halfPlus') {
    return HalfPlusSymbol(size: fontSize * 1.3, color: color);
  }
  return Text(
    kMarkLabels[mark] ?? '?',
    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: fontSize),
  );
}

/// Tapping opens a popup menu showing all 5 options at once.
class GradeMarkButton extends StatelessWidget {
  final String mark; // '' means unset
  final ValueChanged<String> onChanged;
  final double size;

  const GradeMarkButton({
    super.key,
    required this.mark,
    required this.onChanged,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final color = kMarkColors[mark] ?? Colors.grey;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: markContent(mark, fontSize: size * 0.38, color: color),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final RelativeRect position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height + 4,
      offset.dx + box.size.width,
      offset.dy + box.size.height + 4,
    );

    showMenu<String>(
      context: context,
      position: position,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: _kAllMarks.map((m) {
        final c = kMarkColors[m]!;
        final isSelected = m == mark;
        return PopupMenuItem<String>(
          value: m,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: isSelected
                ? BoxDecoration(
                    color: c.withOpacity(0.12),
                    border: Border(left: BorderSide(color: c, width: 3)),
                  )
                : null,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    border: Border.all(color: c, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: markContent(m, fontSize: 13, color: c),
                ),
                const SizedBox(width: 12),
                Text(
                  markDescription(m),
                  style: TextStyle(
                    color: isSelected ? c : null,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Icon(Icons.check, color: c, size: 18),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) onChanged(selected);
    });
  }

  static String markDescription(String m) {
    return switch (m) {
      'plus'     => 'Done (+)',
      'halfPlus' => 'Partial (half +)',
      'minus'    => 'Not done (−)',
      'absent'   => 'Absent (A)',
      'exempt'   => 'Exempt (E)',
      _          => m,
    };
  }
}

/// Read-only colored badge for student view
class GradeMarkBadge extends StatelessWidget {
  final String mark;
  const GradeMarkBadge({super.key, required this.mark});

  @override
  Widget build(BuildContext context) {
    final color = kMarkColors[mark] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: markContent(mark, fontSize: 14, color: color),
    );
  }
}

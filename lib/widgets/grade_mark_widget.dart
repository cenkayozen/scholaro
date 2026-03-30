import 'package:flutter/material.dart';

const kMarkColors = {
  'plus': Colors.green,
  'halfPlus': Colors.lightGreen,
  'minus': Colors.red,
  'absent': Colors.orange,
  'exempt': Colors.blueGrey,
  '': Colors.grey,
};

const kMarkLabels = {
  'plus': '+',
  'halfPlus': '½+',
  'minus': '−',
  'absent': 'A',
  'exempt': 'E',
  '': '?',
};

const _kAllMarks = ['plus', 'halfPlus', 'minus', 'absent', 'exempt', ''];

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
    final label = kMarkLabels[mark] ?? '?';

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
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
          ),
        ),
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
        final l = kMarkLabels[m]!;
        final isSelected = m == mark;
        return PopupMenuItem<String>(
          value: m,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: isSelected
                ? BoxDecoration(
                    color: c.withOpacity(0.12),
                    border: Border(
                      left: BorderSide(color: c, width: 3),
                    ),
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
                  child: Text(
                    l,
                    style: TextStyle(
                      color: c,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  markDescription(m),
                  style: TextStyle(
                    color: isSelected ? c : null,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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
      'plus' => 'Done (+)',
      'halfPlus' => 'Partial (½+)',
      'minus' => 'Not done (−)',
      'absent' => 'Absent (A)',
      'exempt' => 'Exempt (E)',
      _ => m,
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
    final label = kMarkLabels[mark] ?? '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

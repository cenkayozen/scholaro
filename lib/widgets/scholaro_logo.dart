import 'package:flutter/material.dart';

/// Scholaro brand logo: icon mark + "Scholaro" wordmark.
///
/// [iconSize] controls the icon square size; text scales proportionally.
/// [horizontal] = true  →  icon left, text right
/// [horizontal] = false →  icon top, text below
/// [light] = true uses white text + icon (for dark backgrounds)
class ScholaroLogo extends StatelessWidget {
  final double iconSize;
  final bool horizontal;
  final bool light;

  const ScholaroLogo({
    super.key,
    this.iconSize = 48,
    this.horizontal = true,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final mark = _IconMark(size: iconSize);
    final gap = iconSize * 0.28;
    final nameFontSize = iconSize * 0.52;
    final tagFontSize = iconSize * 0.22;

    final textCol = light ? Colors.white : const Color(0xFF1565C0);
    final tagCol = light
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF1565C0).withValues(alpha: 0.65);

    final wordmark = Column(
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Scholaro',
          style: TextStyle(
            fontSize: nameFontSize,
            fontWeight: FontWeight.w800,
            color: textCol,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        Text(
          'Grade & Portfolio Tracker',
          style: TextStyle(
            fontSize: tagFontSize,
            fontWeight: FontWeight.w400,
            color: tagCol,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );

    if (horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [mark, SizedBox(width: gap), wordmark],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [mark, SizedBox(height: gap), wordmark],
      );
    }
  }
}

/// The square icon mark only (no text).
class _IconMark extends StatelessWidget {
  final double size;
  const _IconMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.35),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Graduation cap icon
          Icon(
            Icons.school_rounded,
            size: size * 0.60,
            color: Colors.white,
          ),
          // Subtle gold accent dot (top-right corner, like a tassel button)
          Positioned(
            top: size * 0.14,
            right: size * 0.14,
            child: Container(
              width: size * 0.12,
              height: size * 0.12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD600),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD600).withValues(alpha: 0.5),
                    blurRadius: size * 0.05,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

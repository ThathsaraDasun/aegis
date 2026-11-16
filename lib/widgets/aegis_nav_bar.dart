import 'package:flutter/material.dart';

/// One side item of [AegisNavBar].
class AegisNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Index of the screen this item opens.
  final int index;

  const AegisNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}

/// Floating bottom navigation bar with a curved notch and a raised centre
/// button, styled with the Aegis blue palette.
class AegisNavBar extends StatelessWidget {
  /// Index of the selected screen.
  final int currentIndex;

  /// Called with the screen index of the tapped item.
  final ValueChanged<int> onTap;

  /// Items shown left of the centre button.
  final List<AegisNavItem> leftItems;

  /// Items shown right of the centre button.
  final List<AegisNavItem> rightItems;

  /// The raised centre button.
  final AegisNavItem centerItem;

  const AegisNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.leftItems,
    required this.rightItems,
    required this.centerItem,
  });

  static const Color _azure = Color(0xFF007FFF);
  static const Color _dodger = Color(0xFF1E90FF);
  static const Color _sky = Color(0xFF66CCFF);
  static const Color _muted = Color(0xFF9AA6B8);

  static const double _barHeight = 68;
  static const double _overhang = 34; // how far the centre button rises
  static const double _button = 58;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final centerSelected = currentIndex == centerItem.index;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 12),
      child: SizedBox(
        height: _barHeight + _overhang,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _NotchedBarPainter(top: _overhang)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight,
              child: Row(
                children: [
                  for (final item in leftItems) _buildItem(context, item),
                  const SizedBox(width: _button + 28),
                  for (final item in rightItems) _buildItem(context, item),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Semantics(
                button: true,
                selected: centerSelected,
                label: centerItem.label,
                child: Tooltip(
                  message: centerItem.label,
                  child: GestureDetector(
                    onTap: () => onTap(centerItem.index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _button,
                      height: _button,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_azure, _dodger],
                        ),
                        border: Border.all(
                          color: centerSelected ? _sky : Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _azure.withValues(alpha: 0.40),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        centerSelected
                            ? centerItem.activeIcon
                            : centerItem.icon,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, AegisNavItem item) {
    final selected = currentIndex == item.index;
    final color = selected ? _azure : _muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkResponse(
          onTap: () => onTap(item.index),
          radius: 32,
          highlightColor: Colors.transparent,
          splashColor: _azure.withValues(alpha: 0.10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  key: ValueKey(selected),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style:
                    (Theme.of(context).textTheme.labelSmall ??
                            const TextStyle())
                        .copyWith(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: 0,
                        ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the white rounded bar with a smooth dip under the centre button.
class _NotchedBarPainter extends CustomPainter {
  final double top;
  const _NotchedBarPainter({required this.top});

  static const double _radius = 24;
  static const double _notchHalfWidth = 52;
  static const double _notchDepth = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final path = Path()
      ..moveTo(0, top + _radius)
      ..quadraticBezierTo(0, top, _radius, top)
      ..lineTo(cx - _notchHalfWidth, top)
      ..cubicTo(
        cx - _notchHalfWidth + 22,
        top,
        cx - 30,
        top + _notchDepth,
        cx,
        top + _notchDepth,
      )
      ..cubicTo(
        cx + 30,
        top + _notchDepth,
        cx + _notchHalfWidth - 22,
        top,
        cx + _notchHalfWidth,
        top,
      )
      ..lineTo(w - _radius, top)
      ..quadraticBezierTo(w, top, w, top + _radius)
      ..lineTo(w, h - _radius)
      ..quadraticBezierTo(w, h, w - _radius, h)
      ..lineTo(_radius, h)
      ..quadraticBezierTo(0, h, 0, h - _radius)
      ..close();

    canvas.drawShadow(path, const Color(0xFF007FFF), 10, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter oldDelegate) =>
      oldDelegate.top != top;
}

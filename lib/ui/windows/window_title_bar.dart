import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({
    super.key,
    required this.title,
    required this.icon,
    required this.onMinimize,
    required this.onClose,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AetherColors.titleBarBase,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AetherGlass.windowRadius),
          topRight: Radius.circular(AetherGlass.windowRadius),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: AetherColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AetherColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
          _TitleBarButton(
            icon: Icons.minimize,
            onTap: onMinimize,
            color: AetherColors.accentYellow,
          ),
          const SizedBox(width: 4),
          _TitleBarButton(
            icon: Icons.close,
            onTap: onClose,
            color: AetherColors.accentRed,
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover
                ? widget.color
                : widget.color.withOpacity(0.5),
          ),
          child: _hover
              ? Icon(widget.icon, size: 10, color: AetherColors.background)
              : null,
        ),
      ),
    );
  }
}

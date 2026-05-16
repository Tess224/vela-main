// lib/widgets/vela_bottom_nav.dart — Bottom navigation matching prototype.
// 5 tabs: Home, Signals, Session (center FAB), Goals, Profile.

import 'package:flutter/material.dart';

class VelaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const VelaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEB000000),
        border: Border(
          top: BorderSide(color: Color(0x0FFFFFFF), width: 1),
        ),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 14, left: 12, right: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.show_chart,
            activeIcon: Icons.show_chart,
            label: 'Signals',
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _SessionButton(onTap: () => onTap(2)),
          _NavItem(
            icon: Icons.flag_outlined,
            activeIcon: Icons.flag,
            label: 'Goals',
            isActive: currentIndex == 3,
            onTap: () => onTap(3),
          ),
          _NavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
            isActive: currentIndex == 4,
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFC9A6FF) : const Color(0xFF4A5168);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9,
                letterSpacing: 1.0,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SessionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Transform.translate(
            offset: const Offset(0, -12),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFC9A6FF), Color(0xFF9B7FE0)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9B7FE0).withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Color(0xFF0A0010), size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
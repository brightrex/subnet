import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BottomNavItem {
  final IconData icon;
  final String label;
  const BottomNavItem({required this.icon, required this.label});
}

class BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<BottomNavItem> items;

  const BottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPad > 0 ? 8 : 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceBase.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.borderSubtle, width: 0.6),
                boxShadow: const [
                  BoxShadow(color: Color(0x88000000), blurRadius: 28, offset: Offset(0, 14)),
                ],
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: onChanged,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final item in items)
                    NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.icon),
                      label: item.label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

/// Responsive navigation shell providing persistent navigation across the 6 primary functional areas:
/// Overview, Keywords, Analysis, SERP Audit, Search Engines, and Settings.
class NavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? AppColors.darkBackground : AppColors.surfacePrimary;
    final borderCol = isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle;
    final indicatorCol = isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary;
    final selectedIconColor = isDark ? const Color(0xFF60A5FA) : AppColors.accent;

    final isWide = MediaQuery.of(context).size.width >= 640;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onTap,
              backgroundColor: navBg,
              indicatorColor: indicatorCol,
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: selectedIconColor),
                  label: const Text('Overview'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.key_outlined),
                  selectedIcon: Icon(Icons.key, color: selectedIconColor),
                  label: const Text('Keywords'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights, color: selectedIconColor),
                  label: const Text('Analysis'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.playlist_add_check_outlined),
                  selectedIcon: Icon(Icons.playlist_add_check, color: selectedIconColor),
                  label: const Text('SERP Audit'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub, color: selectedIconColor),
                  label: const Text('Engines'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings, color: selectedIconColor),
                  label: const Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(color: borderCol, width: 1.0),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          backgroundColor: navBg,
          elevation: 0,
          indicatorColor: indicatorCol,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined, size: 20),
              selectedIcon: Icon(Icons.dashboard, size: 20, color: selectedIconColor),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: const Icon(Icons.key_outlined, size: 20),
              selectedIcon: Icon(Icons.key, size: 20, color: selectedIconColor),
              label: 'Keywords',
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined, size: 20),
              selectedIcon: Icon(Icons.insights, size: 20, color: selectedIconColor),
              label: 'Analysis',
            ),
            NavigationDestination(
              icon: const Icon(Icons.playlist_add_check_outlined, size: 20),
              selectedIcon: Icon(Icons.playlist_add_check, size: 20, color: selectedIconColor),
              label: 'SERP Audit',
            ),
            NavigationDestination(
              icon: const Icon(Icons.hub_outlined, size: 20),
              selectedIcon: Icon(Icons.hub, size: 20, color: selectedIconColor),
              label: 'Engines',
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined, size: 20),
              selectedIcon: Icon(Icons.settings, size: 20, color: selectedIconColor),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
